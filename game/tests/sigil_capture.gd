extends Node

func _ready() -> void:
	var out_path := "P:/GameDev/Temp/sigil.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	var layer := CanvasLayer.new()
	add_child(layer)
	var sigil = preload("res://systems/natal_sigil.gd").new()
	layer.add_child(sigil)
	sigil.configure({"year": 1996, "month": 8, "day": 14, "hour": 9, "name": "GREG"})
	sigil.open_chart()
	for _settle in 120:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", out_path, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
