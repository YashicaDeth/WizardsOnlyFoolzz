extends Node

## Where the examiner's workstation stands in the Growing Floor (Greg: "the
## doctor's placement being in the middle of the vat, move it somewhere more
## realistic"). Three views: from the tank as the intake opens, from high
## behind the tank over the room, and from the aisle looking back.
## Run: ... res://tests/station_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await _hold(170)
	await _capture("%s/station_from_tank.png" % out_dir)
	vat.intake.visible = false
	vat.fade.color.a = 0.0
	vat.submerge_tint.color.a = 0.0
	var eye := Camera3D.new()
	add_child(eye)
	eye.fov = 70.0
	eye.current = true
	for view in [["station_overview", Vector3(-1.5, 3.9, 3.2), Vector3(1.6, 0.8, -1.6)], ["station_from_aisle", Vector3(-0.6, 1.7, -6.5), Vector3(1.8, 1.1, -0.8)]]:
		eye.global_position = view[1]
		eye.look_at(view[2], Vector3.UP)
		await _hold(4)
		await _capture("%s/%s.png" % [out_dir, str(view[0])])
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
