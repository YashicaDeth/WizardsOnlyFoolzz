extends Node

## A3.1. "Every surface A built is judged again after dark, not just dimmed."
##
## Nothing in section A has ever been looked at in the dark — every v2 fix was
## checked in daylight. This photographs the same standing shot at four hours so
## the fall-off from noon to deep night can be read as a sequence rather than
## guessed at, plus the handheld lamp on and off at the darkest hour, since the
## lamp is the one light the player carries and AS1.1 makes it the thing v3's
## warping is supposed to act on.

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
	# Standing where the authored sodium lamps actually are, not out in the
	# procedural districts, so the shot contains the light the world has.
	hunt.player_body.position = Vector3(-6.0, 0.9, -4.0)
	hunt.yaw = 0.6
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	for _settle in 10:
		await get_tree().physics_frame

	for hour: float in [12.0, 19.5, 21.0, 1.0]:
		WorldClock.set_hour(hour)
		hunt._update_day_night()
		for _tick in 6:
			await get_tree().physics_frame
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/night_%02d.png" % [out_dir, int(hour)])
		print("HOUR ", hour, " daylight=", WorldClock.daylight(), " sun=", hunt.sun.light_energy)

	# The lamp, at the darkest hour, on and off.
	WorldClock.set_hour(1.0)
	hunt._update_day_night()
	hunt.handheld.toggle_device()
	for _tick in 30:
		await get_tree().physics_frame
	print("TORCH=", hunt.handheld.torch_active(), " lamp_energy=", hunt.handheld_lamp.light_energy, " visible=", hunt.handheld_lamp.visible)
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/night_lamp.png" % out_dir)

	# Shut again: raising the handheld lights the way and puts its own panel over
	# the whole frame, so the pair below would otherwise be two photographs of the
	# World Index.
	hunt.handheld.toggle_device()
	for _tick in 10:
		await get_tree().physics_frame
	# A3.2. The lamps' warp, off and on, from the same paused frame at the darkest
	# hour. A single shot cannot show a displacement — the pair can, and pausing is
	# what stops `_update_day_night` putting the dial straight back up between the
	# two exposures.
	hunt.yaw = 0.0
	hunt.pitch = 0.4
	for _tick in 6:
		await get_tree().physics_frame
	get_tree().paused = true
	for exposure: Array in [["off", 0.0], ["on", 1.0]]:
		LightWarp.set_all(hunt, float(exposure[1]))
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/warp_%s.png" % [out_dir, exposure[0]])
	get_tree().paused = false
	print("WARP_SHELLS=", get_tree().get_nodes_in_group(LightWarp.GROUP).size())
	print("CAPTURE_DONE")
	get_tree().quit()
