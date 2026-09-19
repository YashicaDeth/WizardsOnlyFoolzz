extends Node

## AF6.2. Fire one real Ballistics round across a measured lane into one real
## BaselineHuman. The range must report the flight and the wound produced by
## that same arrival, rather than decorating a mannequin with parallel stats.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo: Node3D = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame

	# Clear every other target out of the lane and stand one production body
	# sixteen metres from the muzzle. Its collision areas and anatomy stay live.
	var bodies: Array = demo.get("bodies")
	for index in bodies.size():
		var entry: Dictionary = bodies[index]
		var holder := entry.get("holder") as Node3D
		holder.global_position = Vector3(40.0 + float(index), 0.9, 0.0)
	var target: Dictionary = bodies[0]
	var target_holder := target.get("holder") as Node3D
	target_holder.global_position = Vector3(0.0, 0.9, -16.0)
	var rig := target.get("rig") as BaselineHuman
	await get_tree().physics_frame

	var start := Vector3(0.0, 1.35, 0.0)
	var aim_at: Vector3 = (rig.parts["torso"] as Node3D).global_position
	var serial := 6002
	var seen := {}
	seen[serial] = start
	demo.set("_seen", seen)
	var guns := demo.get("ballistics") as Ballistics
	guns.fire(start, start.direction_to(aim_at), "pistol", 0.0, 1, "range_test", {
		"source": "gore_demo",
		"shot": serial,
		"weapon": "sidearm",
		"damage": 24.0,
		"impulse": 18.0,
		"damage_type": "ballistic",
	})
	check(guns.rounds.size() == 1, "the measured shot begins as a live round in the lane")
	var waited := 0
	while (demo.get("last_shot_readout") as Dictionary).is_empty() and waited < 120:
		await get_tree().physics_frame
		waited += 1

	var readout: Dictionary = demo.get("last_shot_readout")
	check(not readout.is_empty(), "the real body receives the travelling round")
	check(float(readout.get("distance", 0.0)) > 15.0, "the range reports its measured real distance")
	check(int(readout.get("travel_ms", 0)) > 0, "the range reports Ballistics' simulated travel time")
	check(float(readout.get("drop_cm", 0.0)) > 0.0, "the range reports physical drop below the muzzle ray")
	check(float(readout.get("energy_pct", 1.0)) < 1.0, "the range reports energy lost to live drag")
	var penetration := str(readout.get("penetration", ""))
	check(penetration.begins_with("LODGED") or penetration == "THROUGH",
		"the same arrival reports how far it penetrated the body")
	var struck_zone := str(readout.get("zone", ""))
	var struck_wounds: Array = rig.wound_marks.get(struck_zone, []) as Array
	check(not struck_wounds.is_empty(), "and that penetration read is backed by a wound on the real struck zone")

	print("GORE_RANGE_BALLISTICS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
