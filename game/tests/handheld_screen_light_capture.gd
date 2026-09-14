extends Node

## C4.2 `v4`. Same held object with a live and dead screen. No Hunt scene is
## loaded, so any illumination on the hand can only come from the handheld's
## own screen-luminance path rather than its camera-mounted world beam.

const HANDHELD := preload("res://systems/handheld_device.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor",
		"status": "awake", "memory": "The light belongs to the glass.",
	})
	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	device.open_device()
	device.set_mode("INDEX")
	for _frame in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var lit_path := "%s/c4_2_screen_lit_hand.png" % out_dir
	get_viewport().get_texture().get_image().save_png(lit_path)
	print("CAPTURED: ", lit_path, " luminance=", device.screen_luminance())

	device.set_process(false)
	device.battery = 0.0
	device.backlight = 0.0
	device.queue_redraw()
	device._overlay.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dead_path := "%s/c4_2_screen_dead_hand.png" % out_dir
	get_viewport().get_texture().get_image().save_png(dead_path)
	print("CAPTURED: ", dead_path, " luminance=", device.screen_luminance())
	get_tree().quit()
