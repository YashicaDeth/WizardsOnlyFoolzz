extends Node

## The lab as the player stands in it after the breakout: the decant room
## looking at the floor and down the aisle, and Lower Works from its entry.
## For judging overall lighting and finding the floor light glitch.
## Run windowed: ... res://tests/lab_look_capture.tscn -- --out=DIR

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
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	for _frame in 140:
		vat._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	for shot in [["decant_aisle", 0.0, 0.0], ["decant_floor", 0.0, -0.75], ["decant_station", 1.35, -0.2], ["decant_back", PI, -0.25]]:
		vat.yaw = float(shot[1])
		vat.pitch = float(shot[2])
		vat._physics_process(1.0 / 30.0)
		await _hold(6)
		await _capture("%s/lab_%s.png" % [out_dir, str(shot[0])])
	vat.queue_free()
	await _hold(2)
	var city = load("res://buried_city.tscn").instantiate()
	add_child(city)
	city.set_physics_process(false)
	await _hold(30)
	await _capture("%s/lab_lower_works.png" % out_dir)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
