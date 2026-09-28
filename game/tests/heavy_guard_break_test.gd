extends Node

## Greg, 28 September: middle mouse in the Hunt. Tap = a heavy swing; hold =
## a guard break that knocks the guard open or throws them. Lock-on is Z.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func mouse(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_MIDDLE
	event.pressed = pressed
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for i in 10:
		await get_tree().physics_frame
	hunt._equip_weapon(0)
	var lock_before: String = hunt.lock_target
	hunt._unhandled_input(mouse(true))
	hunt._unhandled_input(mouse(false))
	check(not hunt.pending_attack.is_empty() and bool(hunt.pending_attack.get("heavy", false)), "a tap of middle mouse is a heavy swing")
	check(hunt.lock_target == lock_before, "and it no longer toggles lock-on (that is Z)")

	check(hunt.encounter_actors.size() > 0, "someone to shove")
	var actor: Dictionary = hunt.encounter_actors[0]
	var node: Node3D = actor.node
	var forward: Vector3 = -hunt.camera.global_transform.basis.z
	forward.y = 0.0
	node.global_position = hunt.player + forward.normalized() * 1.5
	hunt.stamina = 100.0
	check(hunt.guard_break("break") == "break", "holding shoves them")
	check(str(actor.state) == "staggered" and float(actor.stagger_remaining) > 1.0, "a break staggers them (a free hit)")
	check(hunt.stamina <= 80.0, "and costs stamina")
	actor.state = "hunting"
	node.global_position = hunt.player + forward.normalized() * 1.5
	check(hunt.guard_break("throw") == "throw" and str(actor.state) == "staggered", "a throw puts them down longer")
	hunt.stamina = 5.0
	check(hunt.guard_break() == "", "too winded, nothing happens")
	check(WorldHistory.event_count("guard_break") == 2, "each shove is on the record")

	print("HEAVY_GUARD_BREAK_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
