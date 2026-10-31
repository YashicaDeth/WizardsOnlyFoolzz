extends Node

## Captures the intake form on each page, so D3's clipboard and D7's mirror can
## be reviewed rather than described.

const INTAKE := preload("res://systems/vat_intake.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	WorldHistory.clear_history()

	var layer := CanvasLayer.new()
	add_child(layer)
	var intake: Control = INTAKE.new()
	layer.add_child(intake)
	await get_tree().process_frame
	intake.sheet.birth = {"year": 2007, "month": 1, "day": 11, "hour": 2, "minute": 30}
	intake.sheet.race = "roadborn"
	intake.sheet.toggle_trait("hospital_strength")
	intake.sheet.toggle_trait("the_tube_stayed_in")
	intake.sheet.modifiers.append("neuralace")

	# Past the fade-in, with a question on the table and a thought in the air,
	# so every panel of the first-launch layout (2026-09-24) is in the shot.
	intake.elapsed = 6.0
	intake.touched_pages = {0: true, 1: true}
	var pages := {"route": 0, "race": 1, "traits": 2, "face": 3, "body": 4, "schedule": 5}
	for label in pages:
		intake.page = int(pages[label])
		intake.row = 1
		intake.handler_says = "Any pain? One blink yes, two no. Doesn't change anything, it's just a box."
		intake.handler_life = 30.0
		intake.doctor_life = 0.0
		intake.answers = ["BLINK ONCE", "BLINK TWICE", "STARE"]
		intake.thought = "Where is the second tank going?"
		intake.thought_life = 5.0
		intake.transcript = "WROTE: YES"
		intake.transcript_life = 3.0
		for _settle in 90:
			await get_tree().process_frame
		intake.transcript_life = 3.0
		intake.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/intake_%s.png" % [out_dir, label]
		if image.save_png(path) != OK:
			print("CAPTURE_FAILED ", path)
			get_tree().quit(1)
			return
		print("CAPTURED: ", path)
	get_tree().quit()
