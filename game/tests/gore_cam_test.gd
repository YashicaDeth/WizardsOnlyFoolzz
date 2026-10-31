extends Node
## Walkthrough 2: a derby driver's death is a slow-motion shot of the real
## body in the cab, not the X-ray card. `-- --shot` also saves a frame of it.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	var tree := get_tree()
	await tree.process_frame
	var derby: Node = load("res://rift_derby.tscn").instantiate()
	tree.root.add_child(derby)
	tree.current_scene = derby
	for _settle in 60:
		await tree.process_frame
	var target: Node3D = null
	for candidate: Node3D in derby.targets:
		if candidate.get_node_or_null("DriverRig") != null and not bool(candidate.get_meta("is_rival", false)):
			target = candidate
			break
	check(target != null, "a derby car with a driver in the cab")
	if target == null:
		_done()
		return
	var driver: BaselineHuman = target.get_node("DriverRig")
	var field_camera := get_viewport().get_camera_3d()
	derby._crush_driver(target, "gore_cam_test_driver", Vector3.LEFT, true)
	var cam: GoreCam = derby.gore_cam
	check(cam.active and get_viewport().get_camera_3d() == cam.camera, "the kill cuts to a camera of its own")
	check(Engine.time_scale < 0.5, "in slow motion (%.2f)" % Engine.time_scale)
	check(not derby.get_node("HUD").visible, "with the dash put away, as a cutscene")
	await tree.process_frame
	var to_body := driver.head_anchor.global_position - cam.camera.global_position
	check(-cam.camera.global_transform.basis.z.dot(to_body.normalized()) > 0.95, "looking at the driver's real body in the cab")
	check(to_body.length() < 5.0, "close enough to see it (%.1f m)" % to_body.length())
	if "--shot" in OS.get_cmdline_user_args():
		for _f in 8:
			await tree.process_frame
		get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/gore_cam.png")
	cam.clock = GoreCam.DURATION
	await tree.process_frame
	await tree.process_frame
	check(not cam.active and get_viewport().get_camera_3d() == field_camera, "then hands the view back")
	check(is_equal_approx(Engine.time_scale, 1.0), "and the world back to full speed")
	check(derby.get_node("HUD").visible, "and the dash back")
	_done()


func _done() -> void:
	Engine.time_scale = 1.0
	print("GORE_CAM_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
