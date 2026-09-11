extends Node

## Photographs the seam cover mid-travel. It sits on an autoloaded CanvasLayer
## that outlives the scene swap, so this holds it open rather than letting the
## travel finish.

func _ready() -> void:
	var out_path := "P:/GameDev/Temp/interstitial.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	Interstitial.hold_open("walking out into the ashbloom expanse")
	# Let the fade complete and the specimen turn to a readable angle.
	for _frame in 130:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", out_path, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
