extends Node

## Visual proof for vertebra 5: the D-section gate and its guard, from up the
## aisle, from behind him, and after the gate lifts.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var opening = load("res://vat_chamber.tscn").instantiate()
	add_child(opening)
	await _hold(5)
	opening.intake.sheet.randomise()
	opening.intake._finish_filing()
	opening.clock = 9.1
	opening._breach()
	opening.phase = "aisle"
	opening.can_move = true
	opening.subtitle.text = ""
	opening.fade.color.a = 0.0
	opening.submerge_tint.color.a = 0.0
	var gate = opening.checkpoint

	var post: Vector3 = gate.guard.global_position
	# Up the aisle, crouched between the last tanks, looking at him.
	_look(opening, gate.global_position + Vector3(-2.2, 0, 7.5), post, -0.12)
	opening.camera.position.y = opening.STANDING_EYE_OFFSET - 0.55
	await _settle(opening)
	await _capture("%s/checkpoint_aisle.png" % out_dir)

	# Behind him, close, between him and his own gate, looking at his back.
	_look(opening, post + Vector3(-0.3, 0, -1.0), post + Vector3(0, 0, 3.0), -0.2)
	await _settle(opening)
	await _capture("%s/checkpoint_behind_guard.png" % out_dir)

	# He goes down, the hand goes on the glass, the gate lifts.
	gate.strike()
	gate._strike_cooldown = 0.0
	_look(opening, post + Vector3(-1.3, 0, 1.2), gate.guard.global_position, -0.55)
	await _settle(opening)
	await _capture("%s/checkpoint_guard_down.png" % out_dir)
	gate.interact()
	gate.take_arm()
	_place(opening, gate.global_position + Vector3(2.3, 0, 1.7), -0.1)
	gate.interact()
	await _hold(70)
	_place(opening, gate.global_position + Vector3(0.4, 0, 5.0), -0.05)
	await _settle(opening)
	await _capture("%s/checkpoint_open.png" % out_dir)
	get_tree().quit()


func _look(opening, at: Vector3, target: Vector3, pitch: float) -> void:
	var toward := target - at
	_place(opening, at, pitch, atan2(-toward.x, -toward.z))


func _place(opening, at: Vector3, pitch: float, yaw := 0.0) -> void:
	opening.player.global_position = at + Vector3(0, opening.BODY_HALF_HEIGHT, 0)
	opening.yaw = yaw
	opening.pitch = pitch
	opening.player.rotation.y = yaw
	opening.camera.rotation = Vector3(pitch, 0, 0)


func _settle(opening) -> void:
	for _frame in 8:
		opening._update_hud()
		await get_tree().process_frame


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
