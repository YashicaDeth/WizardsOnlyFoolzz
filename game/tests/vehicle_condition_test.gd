extends Node

## V1.1. A car is a thing with a condition, not a state you are in. Before this
## fix `rift_derby.gd` tracked the player's hull as its own bare `var integrity`
## — reset to 100 every time the encounter script itself reset — while every AI
## wrecker carried the same fact as loose `set_meta("integrity", ...)` on the
## node. Neither one belonged to the car. This proves the condition now lives on
## `ArcadeVehicle` itself: two vehicle instances hold it independently, the
## rival's authored max survives being read back off the object, and the
## encounter script's `boat`/`targets` are the same chassis type as everything
## else that carries this.

const ArcadeVehicleScript := preload("res://systems/arcade_vehicle.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- unit level: the object carries its own condition -------------------
	var a := ArcadeVehicleScript.new()
	var b := ArcadeVehicleScript.new()
	check(a.integrity == 100 and a.max_integrity == 100, "a fresh chassis starts at full, undamaged condition")

	a.set_max_integrity(160)
	check(a.integrity == 160 and a.max_integrity == 160, "an authored max (the rival's 160) resets current condition to match")
	check(b.integrity == 100, "raising one vehicle's max never touches a second vehicle's condition")

	var after := a.apply_damage(40)
	check(after == 120 and a.integrity == 120, "apply_damage returns and stores the same post-hit number")
	check(b.integrity == 100, "damaging one vehicle leaves an unrelated one untouched")
	check(is_equal_approx(a.condition_fraction(), 120.0 / 160.0), "condition_fraction reads against this vehicle's own max, not a flat 100")
	check(not a.is_wrecked(), "still standing above zero")

	a.apply_damage(1000)
	check(a.integrity == 0, "damage clamps at zero rather than going negative")
	check(a.is_wrecked(), "is_wrecked flips once condition bottoms out")
	check(b.integrity == 100 and not b.is_wrecked(), "the second vehicle never moved")

	var c := ArcadeVehicleScript.new()
	c.apply_damage(-999)
	check(c.integrity == 100, "a negative damage amount cannot heal a car through this path")

	a.free()
	b.free()
	c.free()

	# --- integration level: the encounter script's own cars agree -----------
	var tree := get_tree()
	await tree.process_frame
	var derby: Node = load("res://rift_derby.tscn").instantiate()
	tree.root.add_child(derby)
	derby.leaving = true
	await tree.physics_frame
	await tree.physics_frame

	check(derby.boat is ArcadeVehicleScript, "the player's car is the same chassis class as the test above")
	check(derby.targets.size() > 0, "wreckers spawned")
	var rival: Node = null
	var grunt: Node = null
	for target in derby.targets:
		if bool(target.get_meta("is_rival", false)):
			rival = target
		elif grunt == null:
			grunt = target
	check(rival != null and rival is ArcadeVehicleScript, "the rival wrecker is a real ArcadeVehicle, not a bag of metadata")
	check(rival.max_integrity == 160, "the rival's tougher chassis is authored on the object itself (160), matching the old set_meta value")
	check(grunt != null and grunt.max_integrity == 100, "an ordinary wrecker keeps the ordinary max")

	var boat_before: int = derby.boat.integrity
	var grunt_before: int = grunt.integrity
	grunt.apply_damage(30)
	check(derby.boat.integrity == boat_before, "damaging a wrecker never bleeds into the player's own condition")
	check(grunt.integrity == grunt_before - 30, "and the wrecker's own condition actually moved")

	derby.queue_free()
	await tree.process_frame
	_report()


func _report() -> void:
	if failures.is_empty():
		print("vehicle condition: clean")
		get_tree().quit(0)
	else:
		print("vehicle condition FAILURES: ", failures)
		get_tree().quit(1)
