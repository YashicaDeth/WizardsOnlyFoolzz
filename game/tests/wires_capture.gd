extends Node

## Visual proof for the wires beat: hanging in the drained tank looking at a
## wire under END ALL SUFFERING, and GET REVENGE after the last one is out.
## Run windowed: ... res://tests/wires_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	vat.set_physics_process(false)
	await get_tree().process_frame
	vat.intake.filed.emit(vat.intake.sheet.apply_to_world())
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	var cable: Node3D = vat.umbilicals[1]
	var aim: Vector3 = ((cable.get_child(3) as Node3D).global_position - vat.camera.global_position).normalized()
	vat.yaw = atan2(-aim.x, -aim.z)
	vat.pitch = asin(aim.y)
	for _frame in 20:
		vat._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	await _capture("%s/wires_end_all_suffering.png" % out_dir)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	for _frame in 12:
		vat._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	await _capture("%s/wires_get_revenge.png" % out_dir)
	get_tree().quit()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
