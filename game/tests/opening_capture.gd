extends Node

## Visual proof for G6. Captures the pre-form laboratory, the live 3D body form,
## submerged wake, and the tank voiding from the actual playable scene.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var opening = load("res://vat_chamber.tscn").instantiate()
	add_child(opening)
	await _hold(30)
	await _capture("%s/opening_intake.png" % out_dir)
	# The room has a short beat before the paperwork arrives. Capture the form
	# separately so a review cannot accidentally approve only the prelude.
	await _hold(90)
	await _capture("%s/opening_intake_form.png" % out_dir)

	var state: Dictionary = opening.intake.sheet.apply_to_world()
	opening.intake.filed.emit(state)

	# Filing now opens the examiner's departure rather than the vat sequence.
	# Captured mid-walk and again with the panel shut, because "he leaves before
	# the escape begins" is a claim about two frames, not about a flag.
	await _hold(100)
	await _capture("%s/opening_departure.png" % out_dir)
	# Caught on the seal itself rather than after the phase ends -- by then the
	# head has turned back to the tank and the door is out of frame, which is
	# exactly the mistake this capture exists to catch.
	while opening.phase == "departure" and opening.departure_clock < 3.70:
		await get_tree().process_frame
	await _capture("%s/opening_staff_door_sealed.png" % out_dir)
	while opening.phase == "departure":
		await get_tree().process_frame

	await _hold(45)
	await _capture("%s/opening_submerged.png" % out_dir)

	opening.clock = 4.2
	opening.phase = "voiding"
	for _frame in 24:
		opening._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	await _capture("%s/opening_voiding.png" % out_dir)

	# The attributed ownership beat, captured as it actually reads on screen
	# rather than assumed correct because the string is right.
	opening.clock = 7.5
	opening._update_beats()
	await get_tree().process_frame
	await _capture("%s/opening_celloutz_reframe.png" % out_dir)
	opening.clock = 9.1
	opening.phase = "aisle"
	opening.can_move = true
	# The objective is gated on the tank having actually broken, not on movement
	# alone, so a capture that only grants control now truthfully shows nothing.
	if not opening.breakout_complete:
		opening._breach()
		opening.phase = "aisle"
		opening.can_move = true
	opening._update_beats()
	opening.subtitle.text = ""
	# Breaking the tank directly skips the wires; in play GET REVENGE has
	# already replaced the END ALL SUFFERING card by now.
	if opening.mission_card != null and opening.mission_card.playing:
		opening.mission_card.skip()
	# And the title fades while you get up off the floor, which this skips.
	opening.title.visible = false
	opening._update_hud()
	await get_tree().process_frame
	await _capture("%s/opening_escape_objective.png" % out_dir)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)

