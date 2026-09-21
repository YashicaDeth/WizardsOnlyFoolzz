extends Node

## The long shot, and the plate it earns.
##
## `KillCam` has been a Sniper-Elite-style X-ray finisher since it was written
## -- slow motion, ribs failing in a wave, organs rupturing in sequence off the
## real `AnatomyComponent` snapshot. Two things were missing rather than broken:
## there was no rifle in the arsenal to earn it, and a head hit fell into the
## branch that clears every fragment, so the shot with the least survivable
## anatomy behind it produced the emptiest picture.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("-- there is a rifle, and it is a rifle --")
	var sniper: Dictionary = HunterArsenal.WEAPONS.get("sniper", {})
	check(not sniper.is_empty(), "the arsenal has a sniper")
	# Deliberately not in SLOT_ORDER. A rifle that reaches across the bone yard
	# is something you come into possession of, exactly as `facility_sidearm`
	# is, and the hunter's own loadout stays the three the game was built on.
	check(not HunterArsenal.SLOT_ORDER.has("sniper"), "it is acquired, not issued at spawn")
	check(HunterArsenal.SLOT_ORDER.size() == 3, "so the hunter still has three modelled slots")
	var sidearm: Dictionary = HunterArsenal.WEAPONS.sidearm
	check(float(sniper.range) > float(sidearm.range) * 2.0, "it reaches further than the sidearm (%.0fm)" % float(sniper.range))
	check(float(sniper.spread) < float(sidearm.spread), "and is tighter (%.4f)" % float(sniper.spread))
	check(float(sniper.cooldown) > float(sidearm.cooldown) * 3.0, "and you pay for a miss (%.2fs)" % float(sniper.cooldown))
	# The whole justification for the camera firing. The brain holds 18 points
	# and the sidearm's 24 already reaches it, so 78 has to be past argument.
	check(float(sniper.damage) >= 70.0, "a clean hit is not survivable (%.0f)" % float(sniper.damage))

	print("-- a head hit takes the skull with it --")
	var cam := KillCam.new()
	add_child(cam)
	var snapshot := {"organs": {"brain": {"ruptured": true}, "heart": {"ruptured": false}}}
	cam.trigger("SUBJECT", "head", Vector3.LEFT, "SNIPER", snapshot)
	check(cam.active, "the camera fires")
	check(not cam.fragments.is_empty(), "the skull comes apart (%d fragments)" % cam.fragments.size())
	var eyes := 0
	var brain_ruptured := false
	var heart_ruptured := false
	for rupture in cam.ruptures:
		var entry: Dictionary = rupture
		if str(entry.get("id", "")) == "eye":
			eyes += 1
		if str(entry.get("id", "")) == "brain":
			brain_ruptured = bool(entry.get("ruptured", false))
		if str(entry.get("id", "")) == "heart":
			heart_ruptured = bool(entry.get("ruptured", false))
	check(eyes == 2, "and both orbits go (%d)" % eyes)
	check(brain_ruptured, "the brain ruptures, because the snapshot says it did")
	# The plate is allowed to draw ribs the body does not model. It is not
	# allowed to claim an organ failed when the anatomy says it held.
	check(not heart_ruptured, "the heart does not, because the snapshot says it held")
	check(absf(Engine.time_scale - KillCam.SLOW_SCALE) < 0.001, "the world is in slow motion (%.2f)" % Engine.time_scale)
	cam.cancel()
	check(absf(Engine.time_scale - 1.0) < 0.001, "and comes back out of it")

	print("-- a torso hit still breaks ribs --")
	cam.trigger("SUBJECT", "torso", Vector3.RIGHT, "SNIPER", snapshot)
	check(not cam.fragments.is_empty(), "the ribs still fail (%d fragments)" % cam.fragments.size())
	var torso_eyes := 0
	for rupture in cam.ruptures:
		if str((rupture as Dictionary).get("id", "")) == "eye":
			torso_eyes += 1
	check(torso_eyes == 0, "and nothing happens to the eyes of a man shot in the chest")
	cam.cancel()

	print("-- an arm is not a finisher --")
	cam.trigger("SUBJECT", "left_arm", Vector3.LEFT, "SNIPER", snapshot)
	check(cam.fragments.is_empty(), "a limb hit draws no skeleton coming apart")
	cam.cancel()
	check(absf(Engine.time_scale - 1.0) < 0.001, "time is left where it was found")

	print("SNIPER_KILLCAM_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
