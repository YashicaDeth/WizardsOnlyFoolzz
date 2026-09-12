extends Node

## Windowed-only visual check for the demo build: the interface, at night,
## with the blood veil and the psychedelic rig both live. Before the HUD was
## ordered these two painted over every panel; this is how you look at it.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	for _settle in 20:
		await get_tree().physics_frame

	# Deep night, so the warp dial is as far up as the day/night curve ever
	# pushes it, and blood on the lens as if something just landed.
	WorldClock.set_hour(1.0)
	hunt._update_day_night()
	hunt.blood_veil.call("splash", 1.0, Vector2(700, 300))
	for _tick in 6:
		await get_tree().physics_frame

	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/demo_world_night.png" % out_dir)

	hunt._toggle_panel("index")
	for _tick in 10:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/demo_index.png" % out_dir)

	hunt._toggle_panel("index")
	hunt._toggle_panel("map")
	for _tick in 10:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/demo_map.png" % out_dir)

	hunt._toggle_panel("map")
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	hunt._equip_weapon(0)
	for _tick in 20:
		await get_tree().physics_frame
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/demo_weapon.png" % out_dir)

	print("CAPTURE_DONE engaged=", hunt.psychedelic.call("_is_engaged"))
	get_tree().quit()
