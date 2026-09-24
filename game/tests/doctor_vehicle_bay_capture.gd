extends Node

## Visual proof for the third way out: the doctor by his car looking real, the
## hologram reveal, two moments of his 3D call (the lift, the helicopter) and
## the open ramp. Run windowed:
##   ... res://tests/doctor_vehicle_bay_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "anatomy": {"cybernetics": []}})
	var bay = load("res://doctor_vehicle_bay.tscn").instantiate()
	add_child(bay)
	bay.set_physics_process(false)
	# 1. Walking up on him: a man in a stained coat by a black car.
	_stand(bay, bay.DOCTOR_AT + Vector3(-0.4, 0, 3.2), -0.08, -0.06)
	await _hold(14)
	await _capture("%s/bay_doctor_real.png" % out_dir)
	# 1b. Closer, on his face.
	_stand(bay, bay.DOCTOR_AT + Vector3(0.0, 0, 1.6), 0.0, 0.02)
	await _hold(6)
	await _capture("%s/bay_doctor_close.png" % out_dir)
	# 2. The blow goes through: hologram light and the screen splitting.
	bay.strike()
	bay.step(0.35)
	_stand(bay, bay.DOCTOR_AT + Vector3(-0.2, 0, 2.6), -0.04, -0.1)
	await _hold(6)
	await _capture("%s/bay_reveal.png" % out_dir)
	# 3. The call: the lift car in the shaft, then the helicopter lifting off.
	bay.step(bay.REVEAL_SECONDS)
	bay.holo_call.set_process(false)
	bay.holo_call.seek(3.6)
	await _hold(8)
	await _capture("%s/bay_call_lift.png" % out_dir)
	bay.holo_call.seek(12.6)
	await _hold(8)
	await _capture("%s/bay_call_helicopter.png" % out_dir)
	# 4. The call ends, the ramp shutter rolls up, daylight at the top.
	bay.holo_call.skip()
	for _i in 60:
		bay.step(0.1)
	bay.mission_card.skip()
	_stand(bay, Vector3(0.0, 0, -6.0), 0.0, 0.08)
	await _hold(8)
	await _capture("%s/bay_ramp.png" % out_dir)
	get_tree().quit()


func _stand(bay, at: Vector3, yaw: float, pitch: float) -> void:
	bay.player.global_position = at + Vector3(0, 0.9, 0)
	bay.yaw = yaw
	bay.pitch = pitch
	bay.player.rotation.y = yaw
	bay.camera.rotation = Vector3(pitch, 0, 0)
	bay._update_hud()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
