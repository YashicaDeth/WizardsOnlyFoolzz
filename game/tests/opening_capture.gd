extends Node

## Visual proof for G6. Captures the three authored opening states from the
## actual playable scene: handler intake, submerged wake, the tank voiding,\n## hanging in the wires, and the last one torn out.

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

	var state: Dictionary = opening.intake.sheet.apply_to_world()
	opening.intake.filed.emit(state)
	await _hold(45)
	await _capture("%s/opening_submerged.png" % out_dir)

	# Only this script's own steps move the opening from here, so a slow
	# renderer's catch-up physics ticks cannot run it past the beat captured.
	opening.set_physics_process(false)
	opening.clock = 6.2
	opening.phase = "voiding"
	for _frame in 24:
		opening._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	await _capture("%s/opening_voiding.png" % out_dir)

	# K3.2. The CellOutz reframe beat, captured as it actually reads on
	# screen rather than assumed correct because the string is right.
	opening.clock = 16.6
	opening._update_beats()
	await get_tree().process_frame
	await _capture("%s/opening_celloutz_reframe.png" % out_dir)

	# Hanging in the drained tank, looking up at a wire under END ALL SUFFERING.
	opening._begin_wired()
	var cable: Node3D = opening.umbilicals[0]
	var to_link: Vector3 = ((cable.get_child(4) as Node3D).global_position - opening.camera.global_position).normalized()
	opening.yaw = atan2(-to_link.x, -to_link.z)
	opening.pitch = asin(to_link.y)
	for _frame in 20:
		opening._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	await _capture("%s/opening_wired.png" % out_dir)

	while not opening.umbilicals.is_empty():
		cable = opening.umbilicals[0]
		for _tug in opening.WIRE_TUGS:
			opening._tug_wire(cable)
	for _frame in 12:
		opening._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	await _capture("%s/opening_get_revenge.png" % out_dir)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)

