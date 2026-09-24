extends Node

## Visual evidence for the held pulmonary reliquary in the real field HUD.

func _ready() -> void:
	var out_dir := "res://captures"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = -0.04
	for draw in 12:
		hunt.player_rig.anatomy.inhale_smoke(1.2, 0.34 + float(draw % 3) * 0.18, "spliff" if draw % 2 == 0 else "joint")
	hunt.smoke_lung_fill = 0.76
	hunt.smoke_cough = 0.42
	hunt.smoke_drawing = true
	hunt.pulmonary_held = true

	for _settle in 32:
		hunt._update_hud()
		await get_tree().process_frame
	hunt.field_interface.rotate_pulmonary(Vector2(34, -13))
	hunt.field_interface.zoom_pulmonary(1.08)
	for _settle in 8:
		hunt._update_hud()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var path := "%s/pulmonary_reliquary.png" % out_dir
	if shot.save_png(path) != OK:
		print("CAPTURE_FAILED ", path)
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
	get_tree().quit()
