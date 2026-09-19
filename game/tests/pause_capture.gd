extends Node

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp/g1"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	var scene: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(scene)
	for _settle in 70:
		await get_tree().process_frame
	var gate := get_node_or_null("/root/PauseGate")
	gate.open_gate()
	for _rise in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/pause_root.png" % out_dir)
	print("CAPTURED: %s/pause_root.png" % out_dir)
	gate.page = "settings"
	gate.highlighted = 1
	gate._build_rows()
	for _hold in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	image = get_viewport().get_texture().get_image()
	image.save_png("%s/pause_settings.png" % out_dir)
	print("CAPTURED: %s/pause_settings.png" % out_dir)
	gate.page = "controls"
	gate.highlighted = 0
	gate._build_rows()
	for _hold in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	image = get_viewport().get_texture().get_image()
	image.save_png("%s/pause_controls.png" % out_dir)
	print("CAPTURED: %s/pause_controls.png" % out_dir)
	gate.close()
	get_tree().quit()
