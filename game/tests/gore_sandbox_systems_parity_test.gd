extends Node

## The range shows what the gore systems do, so it has to have them.
##
## Greg: *"make the gore sandbox have all the main game changes"*. It had none
## of the ones built since it was written -- `SkullBurst`, `Cavity`,
## `KillShot`, `KillCam` and `ClothingShell` were all wired into the Hunt and
## none of them reached the one scene built to look at gore. That is the wrong
## way round: the range is where you find out what a weapon does.
##
## Counting `preload` lines would not prove anything, so this drives each one
## the way the sandbox drives it and checks what changed on the body.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func snapshot_of(dead: bool, ruptured: Array) -> Dictionary:
	var organs := {}
	for organ_id in BaselineHuman.ORGAN_LAYOUT:
		organs[organ_id] = {"ruptured": ruptured.has(organ_id)}
	return {"dead": dead, "organs": organs}


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo: Node = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("-- the bodies are dressed --")
	var bodies: Array = demo.get("bodies")
	check(not bodies.is_empty(), "the range still stands its bodies up (%d)" % bodies.size())
	var dressed := 0
	var motley := 0
	for entry: Dictionary in bodies:
		var rig := entry.get("rig") as BaselineHuman
		if rig == null or not is_instance_valid(rig):
			continue
		var wardrobe: Dictionary = rig.get("wardrobe")
		if not wardrobe.is_empty():
			dressed += 1
		if str(wardrobe.get("style", "")) == "jester":
			motley += 1
	check(dressed == bodies.size(), "every one of them wears something (%d of %d)" % [dressed, bodies.size()])
	# A round into a bare rig skips the cloth layer, which is the sandbox
	# teaching a damage number the game does not use.
	check(motley > 0, "and some of them wear the humiliation rig (%d)" % motley)

	print("-- there is a rifle to earn the camera with --")
	var pickups: Array = demo.get("weapon_pickups")
	var has_rifle := false
	for pickup: Dictionary in pickups:
		if str(pickup.get("weapon", "")) == "sniper":
			has_rifle = true
	check(has_rifle, "the rack carries the rifle, which is not in SLOT_ORDER")
	check(demo.get("kill_cam") != null, "and the sandbox owns a kill camera")

	print("-- the same hands the world puts on the same weapons --")
	# `hunter_arsenal._build_weapon_model()` mounts `build_humiliation_hand()`
	# on every Hunt weapon, and a `HeldGear` instance built bare `_flesh` ones,
	# so the range showed pink hands where the world shows the rig gloves.
	var bare_hand := HeldGear.build_hand(1)
	var rig_hand := HeldGear.build_humiliation_hand(1)
	check(not rig_hand.scale.is_equal_approx(bare_hand.scale), "the rig glove is not the same object as a bare hand")
	var gear := demo.get("view_gear") as Node3D
	check(gear != null and is_instance_valid(gear), "the range holds its gear")
	check(bool(gear.get("gloved")), "and asks for the gloves rather than bare flesh")
	var held_right := gear.get("right_hand") as Node3D
	check(held_right != null and is_instance_valid(held_right), "which built a right hand")
	if held_right != null and is_instance_valid(held_right):
		check(held_right.scale.is_equal_approx(rig_hand.scale), "and it is the rig glove, not the bare one")
	bare_hand.queue_free()
	rig_hand.queue_free()

	print("-- a body can be opened by hand --")
	var subject := (bodies[0] as Dictionary).get("rig") as BaselineHuman
	check(not Cavity.is_open(subject, "torso"), "a body on the range starts shut")
	# Stand over it, the way the key expects.
	demo.set("eye", subject.global_position + Vector3(0.0, 1.6, 1.2))
	demo.call("_open_nearest_body")
	check(Cavity.is_open(subject, "torso"), "standing over one and opening it works")
	var loose_wall := false
	for chunk in GoreChunks.live:
		if is_instance_valid(chunk) and bool(GoreChunks.identify(chunk).get("whole_wall", false)):
			loose_wall = true
	check(loose_wall, "and the wall that came away is a real piece on the floor")

	print("-- out of reach is refused --")
	var far_subject := (bodies[1] as Dictionary).get("rig") as BaselineHuman
	demo.set("eye", far_subject.global_position + Vector3(0.0, 1.6, 40.0))
	demo.call("_open_nearest_body")
	check(not Cavity.is_open(far_subject, "torso"), "a body across the room is not opened from where you stand")

	print("-- a rifle round through the brain --")
	var victim := (bodies[2] as Dictionary).get("rig") as BaselineHuman
	check(not Cavity.is_open(victim, "head"), "the head starts shut")
	demo.call("_try_finisher", victim, "sniper", "head", Vector3(0, 0, -1), 78.0, "ballistic")
	# `_try_finisher` reads the live rig, and nothing has killed this one, so
	# the refusal is the correct answer and the one worth pinning.
	check(not Cavity.is_open(victim, "head"), "does nothing to somebody still standing")

	var finished := (bodies[3] as Dictionary).get("rig") as BaselineHuman
	# Kill it the way a rifle does, through the head.
	var head_part := finished.parts.get("head") as Node3D
	finished.hit_at(head_part.global_position, 300.0, 40.0, "ballistic", Vector3(0, 0, -1))
	await get_tree().physics_frame
	var lethal: Dictionary = finished.snapshot()
	check(bool(lethal.get("dead", false)), "a rifle round to the head kills")
	check(bool(((lethal.get("organs", {}) as Dictionary).get("brain", {}) as Dictionary).get("ruptured", false)), "and ruptures the brain, which is what makes it a head shot")
	demo.call("_try_finisher", finished, "sniper", "head", Vector3(0, 0, -1), 78.0, "ballistic")
	check(Cavity.is_open(finished, "head"), "and then the cranium comes off in the sandbox too")

	demo.queue_free()
	print("GORE_SANDBOX_SYSTEMS_PARITY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
