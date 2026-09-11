extends Node

## Photographs the front end. The warning card is shown once per install, so
## this clears the acknowledgement first to guarantee the shot.

func _ready() -> void:
	var out_path := "P:/GameDev/Temp/front_door.png"
	var skip_card := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument == "--menu":
			skip_card = true
	WorldHistory.register_subject("settings", {})
	WorldHistory.update_subject("settings", {"violence_acknowledged": "yes" if skip_card else "no"})
	var menu = load("res://country_town_menu.tscn").instantiate()
	add_child(menu)
	for _settle in 110:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", out_path, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
