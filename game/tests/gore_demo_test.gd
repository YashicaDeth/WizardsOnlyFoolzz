extends Node

## The gore sandbox has to survive being aimed at, not just being opened.
##
## Everything here covers something that was silently broken rather than
## something that might break later, which is the reason it is a test and not a
## look: rounds went through people, because `Ballistics` traces with
## `collide_with_areas = false` and every hitbox on a rig is an `Area3D`; a
## blast resolved six hits at one shared point and so only ever landed on the
## torso; a blast could not dismember at all, because `blunt` is not in
## `BaselineHuman.SEVERING_DAMAGE`; and the X-ray called a method that does not
## exist, behind a `has_method` guard that swallowed it. None of the four threw.

const DEMO := preload("res://gore_demo.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	await tree.process_frame

	var demo = DEMO.instantiate()
	tree.root.add_child(demo)
	tree.current_scene = demo
	await tree.physics_frame
	await tree.physics_frame

	check(demo.bodies.size() == 7, "seven bodies stand up")
	var rig := (demo.bodies[0] as Dictionary)["rig"] as BaselineHuman
	check(rig != null and is_instance_valid(rig), "and the first of them is a real rig")

	# ---- a shot finds a body at all. Every hitbox is an `Area3D`, so a trace
	# that does not ask for areas passes through everybody in the room.
	var stand := rig.global_position
	var level := Vector3(0.0, stand.y + 1.12, stand.z)
	var chest := demo._trace_body(level, Vector3.RIGHT)
	check(not chest.is_empty(), "a shot down the room finds the body in it")
	check(chest.get("rig") == rig, "and finds the right one")
	check(str(chest.get("zone", "")) == "torso", "at chest height it is the chest")

	# ---- and it finds the part that was aimed at, rather than the nearest
	# zone to one shared point in space.
	var skull := demo._trace_body(Vector3(0.0, stand.y + 1.62, stand.z), Vector3.RIGHT)
	check(str(skull.get("zone", "")) == "head", "aimed higher it is the head")

	# ---- a blast dismembers. `shear` inside the band, which is the whole
	# difference between an explosion and a shove.
	var second := (demo.bodies[1] as Dictionary)["rig"] as BaselineHuman
	var before := second.severed.size()
	demo._explode(second.global_position + Vector3(0, 1.0, 0), 92.0)
	await tree.physics_frame
	check(second.severed.size() > before, "a blast at your feet takes limbs off")
	check(demo.severed_total > 0, "and the room counts them")
	check(second.zone_health("torso") < AnatomyComponent.DEFAULT_ZONES["torso"].health,
		"and the torso is not untouched while the arms leave")
	check(GoreChunks.live_count() > 0, "there is something on the floor afterwards")

	# ---- what came off is not armour for whoever is still standing. Loose gore
	# is a `RigidBody3D` on the same layer as the walls, so a single ray stops
	# dead on the first gib between you and the target.
	var blocker: RigidBody3D = null
	for chunk in GoreChunks.live:
		if is_instance_valid(chunk) and chunk is RigidBody3D:
			blocker = chunk as RigidBody3D
			break
	if blocker != null:
		blocker.freeze = true
		blocker.global_position = Vector3(stand.x * 0.5, stand.y + 1.12, stand.z)
		await tree.physics_frame
		var through := demo._trace_body(level, Vector3.RIGHT)
		check(not through.is_empty() and through.get("rig") == rig,
			"a gib in the way is not armour")
	else:
		check(false, "a blast leaves chunks to test against")

	# ---- the trigger reaches the anatomy, not the wall behind it.
	var head_before := rig.zone_health("head")
	demo.yaw = -PI * 0.5
	demo.pitch = 0.0
	demo.eye = Vector3(0.0, 1.68, stand.z)
	await tree.physics_frame
	var spent_before: int = demo.spent
	demo._fire()
	check(demo.spent == spent_before + 1, "pulling the trigger spends a round")
	check(rig.zone_health("head") < head_before, "and the round lands on the body, not the wall")

	# ---- the X-ray is two calls, and neither of them is `set_xray`.
	demo._set_xray(true)
	var revealed := false
	for organ_id in second.organ_parts:
		var organ := second.organ_parts[organ_id] as Node3D
		if organ != null and is_instance_valid(organ) and organ.visible:
			revealed = true
			break
	check(revealed, "the X-ray actually opens a body up")
	demo._set_xray(false)
	var still_open := false
	for organ_id in second.organ_parts:
		var organ := second.organ_parts[organ_id] as Node3D
		if organ != null and is_instance_valid(organ) and organ.visible:
			still_open = true
			break
	check(not still_open, "and closes it again")

	# ---- contact stops the clock, briefly, and gives it back without being
	# asked. A hitstop timed on the clock it is bending never ends on time.
	demo.hitstop = 0.4
	await tree.physics_frame
	check(Engine.time_scale < 0.5, "contact freezes the clock")
	var waited := 0
	while Engine.time_scale < 0.99 and waited < 40:
		await tree.physics_frame
		waited += 1
	check(Engine.time_scale > 0.99, "and the clock comes back on its own")

	# ---- and leaving does not take the slow motion out of the scene with you.
	demo.slowed = 1.0
	await tree.physics_frame
	check(Engine.time_scale < 0.5, "held slow motion slows the world")
	tree.current_scene = null
	demo.free()
	check(is_equal_approx(Engine.time_scale, 1.0), "and it stays in the room you left it in")

	if failures.is_empty():
		print("gore demo: playable")
		tree.quit(0)
	else:
		print("gore demo FAILURES: ", failures)
		tree.quit(1)
