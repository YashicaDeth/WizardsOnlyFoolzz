extends Node

## C9.1/C9.2 `v9`. Paired rear views of the same serial: nearly sound, then
## battered by located impacts. The comparison has to be read from the object,
## because the rear deliberately prints no condition percentage.

const HANDHELD := preload("res://systems/handheld_device.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	device.open_device()
	device.turn_override = true
	for _frame in 45:
		await get_tree().process_frame
	device.set_process(false)
	device.condition = 0.94
	device.impacts.clear()
	device.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var sound_path := "%s/c9_1_v9_jester_back.png" % out_dir
	get_viewport().get_texture().get_image().save_png(sound_path)
	print("CAPTURED: ", sound_path)

	device.condition = 0.21
	device.impacts = [
		{"at": Vector2(0.18, 0.25), "severity": 0.22},
		{"at": Vector2(0.72, 0.68), "severity": 0.31},
		{"at": Vector2(0.46, 0.44), "severity": 0.18},
	]
	device.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var battered_path := "%s/c9_2_v9_battered_shell.png" % out_dir
	get_viewport().get_texture().get_image().save_png(battered_path)
	print("CAPTURED: ", battered_path)
	get_tree().quit()
