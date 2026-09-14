extends Node

## C4.1 `v4`. A paired frame at the same place and hour. The handheld UI is
## transparent only for the exposure so the comparison can show what its real
## 3D light does to the world instead of photographing the INDEX page twice.


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _frame in 24:
		await get_tree().physics_frame

	WorldClock.set_hour(1.0)
	hunt._update_day_night()
	hunt.player_body.position = Vector3(-150.0, 2.0, 62.0)
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	hunt.yaw = PI
	hunt.pitch = -0.06
	for _frame in 12:
		await get_tree().physics_frame
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	var off_path := "%s/c4_1_handheld_light_off.png" % out_dir
	get_viewport().get_texture().get_image().save_png(off_path)
	print("CAPTURED: ", off_path)

	hunt.handheld.battery = 1.0
	hunt.handheld.open_device()
	hunt.handheld.raised = 1.0
	hunt.handheld.modulate.a = 0.0
	for _frame in 12:
		await get_tree().physics_frame
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	var on_path := "%s/c4_1_handheld_light_on.png" % out_dir
	get_viewport().get_texture().get_image().save_png(on_path)
	print("CAPTURED: ", on_path, " energy=", hunt.handheld_lamp.light_energy)
	get_tree().quit()
