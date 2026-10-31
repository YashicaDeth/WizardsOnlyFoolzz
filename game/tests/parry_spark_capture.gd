extends Node

## A timed parry in the real Hunt, HUD and all, first person then third, a
## couple of frames and a few frames after the bind.
## Run (not headless): ... res://tests/parry_spark_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await _hold(90)
	for view in ["first", "third"]:
		hunt.third_person = view == "third"
		await _hold(40)
		hunt.guarding = true
		hunt.guard_side = BladeRead.LEFT
		hunt.guard_raised = 0.05
		hunt.guard_absorb(20.0, Vector3.INF, BladeRead.LEFT)
		await _hold(2)
		await _capture("%s/parry_%s_a.png" % [out_dir, view])
		await _hold(5)
		await _capture("%s/parry_%s_b.png" % [out_dir, view])
		hunt.guarding = false
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
