extends Node

## The fighting sandbox as Greg opens it (psy_lab): the readout, a parry on a
## sparring partner's blow, and its cleaver on the floor.
## Run (not headless): ... res://tests/fight_sandbox_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var lab = load("res://psy_lab.tscn").instantiate()
	add_child(lab)
	for _i in 30:
		await get_tree().process_frame
	var demo = lab.demo
	demo._set_enemies_enabled(true)
	var armed: Dictionary = demo.bodies[1]
	(armed.holder as Node3D).global_position = demo.eye + Vector3(0.0, -0.78, -1.5)
	demo.guarding = true
	demo.guard_aim = Vector2(-1, 0)
	demo.guard_held = 0.05
	armed["swing"] = BladeRead.LEFT
	demo._enemy_strike(armed, armed.holder)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("%s/fight_parry.png" % out_dir)
	for _i in 40:
		await get_tree().process_frame
	demo.pitch = -0.5
	await _capture("%s/fight_dropped.png" % out_dir)
	get_tree().quit()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
