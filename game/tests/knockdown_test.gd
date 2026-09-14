extends Node

## Greg: *"CAN YOU FIX THE KNOCKDOWN ISSUE"*, about the gore sandbox.
##
## The machinery all appears to be there. `AnatomyComponent.go_down()` fires
## when a critical zone reaches zero health or when consciousness runs out, and
## `BaselineHuman._on_went_down()` tips the rig over. `grep` for "downed" in
## `gore_demo.gd` returns nothing, but it does not need to: both paths live
## inside the anatomy the sandbox bodies already carry.
##
## So rather than read further, this drives it. Stand the sandbox up, hit a body
## the way the sandbox hits it, and watch three things that each fail
## differently:
##
##   1. does `anatomy.downed` ever become true,
##   2. does the rig actually *tip* when it does,
##   3. does the anatomy tick at all — because if `_process` is not running,
##      nothing bleeds, consciousness never falls, and the whole second route
##      to a knockdown is dead while looking perfectly healthy in source.

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
	var demo: Node = load("res://gore_demo.tscn").instantiate()
	tree.root.add_child(demo)
	tree.current_scene = demo
	for _settle in 90:
		await tree.process_frame

	var bodies: Array = demo.get("bodies")
	check(bodies.size() > 0, "the sandbox stood bodies up")
	if bodies.is_empty():
		tree.quit(1)
		return

	var rig = bodies[0]["rig"]
	var anatomy = rig.anatomy
	check(anatomy != null, "the body has an anatomy")
	check(anatomy.is_inside_tree(), "the anatomy is in the tree, so its _process can run")

	# Does it tick? Blood should fall on its own once something is bleeding.
	var blood_before: float = anatomy.blood_remaining
	rig.hit("torso", 30.0, 10.0, "cut", "", Vector3.FORWARD)
	for _settle in 60:
		await tree.process_frame
	var blood_after: float = anatomy.blood_remaining
	print("blood %.1f -> %.1f over 60 frames (bleed_rate %.3f)" % [
		blood_before, blood_after, anatomy.bleed_rate])
	check(blood_after < blood_before, "the anatomy actually ticks — a cut body loses blood over time")

	var rot_before: float = rig.rotation.x
	print("rotation.x before: %.3f  downed=%s consciousness=%.1f" % [
		rot_before, str(anatomy.downed), anatomy.consciousness])

	# Now hit it the way a player would until it should be down. The head is a
	# critical zone, so this is the fast route rather than waiting on bleed-out.
	for blow in 12:
		if anatomy.dead or anatomy.downed:
			break
		rig.hit("head", 40.0, 12.0, "blunt", "", Vector3.FORWARD)
		for _settle in 4:
			await tree.process_frame

	for _settle in 30:
		await tree.process_frame

	print("after blows: downed=%s dead=%s consciousness=%.1f rotation.x=%.3f" % [
		str(anatomy.downed), str(anatomy.dead), anatomy.consciousness, rig.rotation.x])

	check(anatomy.downed or anatomy.dead, "hitting a body enough puts it down or kills it")
	if anatomy.downed and not anatomy.dead:
		check(absf(rig.rotation.x - rot_before) > 0.5,
			"a downed body visibly tips over instead of standing there")

	# Look at it. Whether it *reads* as a collapse is not something the flags
	# can answer — `downed=true` and a tipped rig are both true of a body that
	# has fallen through the floor or pivoted like a felled tree.
	var cam := Camera3D.new()
	demo.add_child(cam)
	cam.global_position = rig.global_position + Vector3(0.0, 1.6, 3.4)
	cam.look_at(rig.global_position + Vector3(0, 0.4, 0), Vector3.UP)
	cam.current = true
	for _settle in 6:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png("P:/GameDev/Temp/knockdown.png")
	print("CAPTURED: P:/GameDev/Temp/knockdown.png")
	print("body world y=%.3f  rig y=%.3f  rot=%s" % [
		rig.global_position.y, rig.position.y, str(rig.rotation)])

	if failures.is_empty():
		print("knockdown: fine")
		tree.quit(0)
	else:
		print("knockdown FAILURES: ", failures)
		tree.quit(1)
