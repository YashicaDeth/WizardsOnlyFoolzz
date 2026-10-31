extends Node

## Visual proof for the second route out: the hatch in the Lower Works floor,
## then the old drains' gallery, cistern and the outfall grate onto daylight.
## Run windowed: ... res://tests/old_drains_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	var city = load("res://buried_city.tscn").instantiate()
	add_child(city)
	city.set_physics_process(false)
	city.player.global_position = city.DRAIN_AT + Vector3(-1.2, 1.0, 4.2)
	city.yaw = 0.25
	city.pitch = -0.45
	city._physics_process(1.0 / 30.0)
	await _hold(12)
	await _capture("%s/drains_hatch.png" % out_dir)
	city.queue_free()
	await _hold(2)

	var drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	drains.set_physics_process(false)
	for shot in [["drains_gallery", Vector3(0.0, 1.0, 1.0), 0.0], ["drains_cistern", Vector3(0.0, 1.0, drains.CISTERN_Z - 1.0), -0.12], ["drains_outfall", Vector3(0.0, 1.0, drains.OUTFALL_Z - 6.0), 0.0]]:
		drains.player.global_position = shot[1]
		drains.pitch = float(shot[2])
		drains._physics_process(1.0 / 30.0)
		await _hold(10)
		await _capture("%s/%s.png" % [out_dir, str(shot[0])])
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
