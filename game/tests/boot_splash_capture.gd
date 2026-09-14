extends Node

## Visual check for the presentation slate: CellOutz Inc., Allusions to
## Grandeur presents, then the real WizardsOnlyFoolz mark pouring in.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp/boot_splash"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var splash = load("res://boot_splash.tscn").instantiate()
	add_child(splash)
	await get_tree().process_frame

	var moments := [
		{"name": "celloutz", "at": 1.2},
		{"name": "grandeur_transition", "at": 2.5},
		{"name": "grandeur", "at": 3.6},
		{"name": "mark_pouring", "at": 6.2},
		{"name": "mark_full", "at": 8.5},
	]
	var elapsed := 0.0
	for moment in moments:
		var target: float = moment.at
		while elapsed < target:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out_dir, moment.name]
		var error := image.save_png(path)
		print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
	get_tree().quit()
