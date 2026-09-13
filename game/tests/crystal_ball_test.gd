extends Node3D

## B5.1 / B5.2. A crystal ball carried in the arm or the pocket and functional,
## and hardware you can see in the limb it is installed in.

var failures: Array[String] = []


func check(condition: bool, described: String) -> void:
	if not condition:
		failures.append(described)
	print("%s %s" % ["  ok" if condition else "FAIL", described])


func _ready() -> void:
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("ball_bearer", {"flesh": Color("7a6350"), "gore": false})

	# Nothing installed: no reading at all, which is not the same as a reading
	# that says nothing.
	check(CrystalBall.reading(rig.anatomy).is_empty(), "no ball, no reading")
	check(CrystalBall.speak(rig.anatomy) == "", "and nothing to say")

	rig.anatomy.install_part("left_arm", {"name": "scrying ball"})
	rig._refresh_zone("left_arm")
	await get_tree().process_frame

	# B5.2. It is visible in the limb it went into.
	var arm := rig.parts.get("left_arm") as Node3D
	var hardware := arm.get_node_or_null("InstalledHardware")
	check(hardware != null, "the ball is visible in the arm it was installed in")
	if hardware != null:
		check(str(hardware.get_meta("installed", "")) == "scrying ball", "and it is that piece of hardware, not a generic lump")

	# B5.1. Functional, off state the world actually keeps.
	WorldClock.set_hour(2.0)
	var seen: Dictionary = CrystalBall.reading(rig.anatomy)
	check(not seen.is_empty(), "a bearer gets a reading")
	check(seen.has("gods_up") and (seen.gods_up as Array).size() > 0, "it sees who is up at two in the morning (%s)" % [seen.get("gods_up", [])])
	var quiet := str(seen.get("storm", ""))
	for _ritual in 8:
		WorldHistory.record_event("ritual_completed", {"source": "crystal ball test"})
	var charged: Dictionary = CrystalBall.reading(rig.anatomy)
	check(float(charged.charge) > float(seen.charge), "the charge it reads follows the world (%.2f to %.2f)" % [float(seen.charge), float(charged.charge)])
	check(str(charged.storm) != quiet, "and the words change with it (%s to %s)" % [quiet, str(charged.storm)])
	check(CrystalBall.speak(rig.anatomy).length() > 0, "it has something to say out loud")

	# Pulled out: it stops being visible and stops reading.
	rig.anatomy.pull_part("left_arm", true)
	rig._refresh_zone("left_arm")
	await get_tree().process_frame
	check(arm.get_node_or_null("InstalledHardware") == null, "pulled hardware leaves the limb")
	check(CrystalBall.reading(rig.anatomy).is_empty(), "and stops reading")

	print("CRYSTAL_BALL_TEST_RESULT failures=", failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
