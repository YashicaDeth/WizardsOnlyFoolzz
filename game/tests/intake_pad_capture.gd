extends Node

## Visual proof for intake-29: the NEURAL INTAKE on a PS4 pad (bigger tabs,
## focus band, control strip in pad buttons), the think-out-loud presets on
## the pad keyboard, and the same form on the keyboard for comparison.
## Run windowed: render_one.cmd intake_pad_capture --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	InputProfile.device_family_override = "ps4"
	InputProfile.set_device_preference(true)
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	# Past any load-in, until the form has faded in.
	if vat.load_in != null:
		vat.load_in.queue_free()
		vat.load_in = null
		vat.intake.process_mode = Node.PROCESS_MODE_INHERIT
	var intake = vat.intake
	intake.elapsed = intake.FORM_REVEAL_AT + 1.0
	await _hold(40)
	intake.answers = ["BLINK ONCE", "BLINK TWICE", "STARE"]
	intake.handler_says = "Can you read the form from in there? Blink."
	intake.handler_life = 30.0
	intake.revealed = 60.0
	await _hold(6)
	await _capture("%s/intake_pad_route.png" % out_dir)
	intake.answers = []
	intake.page = 4
	intake.row = 2
	await _hold(40)
	await _capture("%s/intake_pad_body.png" % out_dir)
	intake.page = 1
	intake.row = 1
	intake.touched_pages = {0: true, 1: true, 2: true}
	await _hold(40)
	await _capture("%s/intake_pad_race.png" % out_dir)
	intake._open_pad_keyboard("", "THINK OUT LOUD", intake.think_presets(), intake._think, 40)
	await _hold(6)
	await _capture("%s/intake_pad_think.png" % out_dir)
	intake.pad_keyboard.queue_free()
	await _hold(2)
	InputProfile.device_family_override = ""
	InputProfile.set_device_preference(false)
	await _hold(8)
	await _capture("%s/intake_keyboard_race.png" % out_dir)
	get_tree().quit()


func _hold(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
