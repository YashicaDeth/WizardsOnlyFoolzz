extends Node

## E2.1/E2.4 visual check. A grid of generated seals — plain, forming,
## corrupted and burning — so the vocabulary can actually be looked at rather
## than trusted from the geometry test alone.

const CellOutzType := preload("res://systems/celloutz_type.gd")

var seeds: Array = [1, 7, 11, 23, 42, 61]


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.set_script(preload("res://tests/seal_gallery_canvas.gd"))
	canvas.seal_seeds = seeds
	layer.add_child(canvas)
	await get_tree().process_frame
	canvas.queue_redraw()
	for _settle in 3:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/seal_gallery.png" % out_dir
	var error := image.save_png(path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
	get_tree().quit(0 if error == OK else 1)
