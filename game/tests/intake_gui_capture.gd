extends Node

## Visual proof for the intake GUI pass (Greg, 24 September): a tab printing
## in, his line typing with a cursor under a faded transcript, blink-icon
## answers, and the stat gauges flashing a change.
## Run windowed: ... res://tests/intake_gui_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await _hold(130)
	var intake = vat.intake
	intake.said_history = ["Hold still. The tube goes where it goes.", "Any pain? One blink yes, two no."] as Array[String]
	intake.answers = ["BLINK ONCE", "BLINK TWICE", "STARE"]
	intake.handler_says = "Can you read the form from in there? Blink."
	intake.handler_life = 30.0
	intake.revealed = 20.0
	intake.page = 1
	await _hold(3)
	intake.page_print = 0.45
	intake.set_process(false)
	intake.queue_redraw()
	await _hold(2)
	await _capture("%s/intake_printing.png" % out_dir)
	intake.set_process(true)
	await _hold(40)
	intake.sheet.race = "roadborn" if intake.sheet.race != "roadborn" else "soft_rot"
	await _hold(8)
	await _capture("%s/intake_gauges.png" % out_dir)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
