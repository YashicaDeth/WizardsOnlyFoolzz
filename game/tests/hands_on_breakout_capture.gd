extends Node

## Visual proof for the hands-on breakout: the cord, the cracked glass, on
## your knees while the implant boots the HUD, the HUD up, and standing up
## facing his door under GET REVENGE.
## Run windowed: ... res://tests/hands_on_breakout_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	vat.hands_on_breakout = true
	add_child(vat)
	vat.set_physics_process(false)
	await get_tree().process_frame
	if vat.load_in != null:
		vat.load_in.skip()
		for _frame in 3:
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
	await _run(vat, 0.6)
	await _capture("%s/bo_1_cord.png" % out_dir)
	for _pull in vat.CORD_TUGS:
		vat.tug_cord()
	vat.yaw = 0.0
	await _run(vat, 0.5)
	vat.strike_glass()
	vat.strike_glass()
	await _run(vat, 0.4)
	await _capture("%s/bo_2_cracked.png" % out_dir)
	vat.strike_glass()
	await _run(vat, 1.0)
	await _capture("%s/bo_3_knees_booting.png" % out_dir)
	await _run(vat, 2.0)
	await _capture("%s/bo_4_hud_up.png" % out_dir)
	vat.get_up()
	await _run(vat, vat.RISE_SECONDS + 0.4)
	await _capture("%s/bo_5_get_revenge.png" % out_dir)
	get_tree().quit()


func _run(vat, seconds: float) -> void:
	for _frame in int(seconds * 30.0):
		vat._physics_process(1.0 / 30.0)
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
