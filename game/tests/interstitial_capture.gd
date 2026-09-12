extends Node

## Photographs the seam cover mid-travel. It sits on an autoloaded CanvasLayer
## that outlives the scene swap, so this holds it open rather than letting the
## travel finish.

func _ready() -> void:
	var out_path := "P:/GameDev/Temp/interstitial.png"
	var stay_open := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument == "--stay":
			stay_open = true
	await Interstitial.hold_open("walking out into the ashbloom expanse")
	# The fade has completed; a handful of rendered frames lets the scan settle
	# without making the capture harness wait through a full turntable cycle.
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", out_path, " ", image.get_width(), "x", image.get_height())
	if stay_open:
		return
	get_tree().quit()
