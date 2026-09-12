extends Node

## C5.6 v3. Three distinct impacts, at three distinct corners of the screen,
## each cracking the glass where it actually landed rather than all three
## sharing the one authored origin.

const HANDHELD := preload("res://systems/handheld_device.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	device.open_device()
	device.set_mode("RADIO")
	device.condition = 0.55
	device.impacts.clear()
	device.take_wear(0.01, "top-left impact", Vector2(0.18, 0.15))
	device.take_wear(0.01, "bottom-right impact", Vector2(0.82, 0.85))
	device.take_wear(0.01, "centre impact", Vector2(0.5, 0.5))

	for _settle in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/handheld_impact_cracks.png" % out_dir
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)
	get_tree().quit()
