extends Node

## AF1.4. The last honest gap this segment named: the magazine swap was true
## underneath (magazine_test.gd) but nothing showed it leaving. This rides
## the same `reload_remaining` timer `state().reload_ratio` already exposed —
## it cannot drift out of sync with the real reload because it reads the one
## timer that governs both.

const ARSENAL := preload("res://systems/hunter_arsenal.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("reload_visual_test")
	var arsenal: Node = ARSENAL.new()
	add_child(arsenal)
	arsenal.configure(rig)

	# The sword carries no magazine at all — the reload visual must be a
	# no-op for it rather than an error over a node that does not exist.
	arsenal.select_slot(0)
	arsenal.tick(0.1)
	check(not arsenal._magazine_nodes.has("sword"), "the sword has no magazine node to find")

	arsenal.select_slot(2) # sidearm: reload 1.3s
	var magazine: Node3D = arsenal._magazine_nodes.get("sidearm")
	check(magazine != null, "the sidearm model was built with a node named \"magazine\"")
	var rest: Vector3 = arsenal._magazine_rest.get("sidearm")
	check(magazine.visible and magazine.position.is_equal_approx(rest), "at rest, seated and visible")

	arsenal.begin_attack() # loaded 10 -> 9, so a reload has something to do
	arsenal.tick(0.30) # clears the sidearm's 0.28s cooldown
	check(arsenal.reload(), "reload accepted with the magazine short one round")

	arsenal.tick(0.05) # ~4% into a 1.3s reload
	check(magazine.visible, "the old magazine is still in frame the instant the swap begins")
	check(magazine.position.distance_to(rest) > 0.0001, "and already moving clear of the well")

	arsenal.tick(0.60) # ~50% in
	check(not magazine.visible, "the well itself reads empty at the swap's midpoint — the part nothing showed before this")

	arsenal.tick(0.65) # finishes the 1.3s reload
	check(int(arsenal.ammo.sidearm.loaded) == 10, "the mechanical swap completed as before")
	check(magazine.visible and magazine.position.is_equal_approx(rest), "and the fresh magazine is seated back at rest")

	if failures.is_empty():
		print("reload visual: the magazine actually leaves, and you can see the well empty")
		get_tree().quit(0)
	else:
		print("reload visual FAILURES: ", failures)
		get_tree().quit(1)
