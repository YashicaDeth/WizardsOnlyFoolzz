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

	# A4.1. Standing on the ground sixty metres out from the western settlement at
	# 01:00 — the range somebody would actually be steering from. The standing
	# shots say what one lamp does; this says whether there is light anywhere
	# people live, and whether it is worth walking toward.
	hunt.player_body.position = Vector3(-150, 2.0, 62)
	hunt.yaw = PI
	hunt.pitch = 0.02
	for _tick in 2:
		await get_tree().physics_frame
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/region_night.png" % out_dir)
	print("NIGHT_LIGHTS=", hunt.night_lights.size())

	# A4.2. The handheld beam, off and on, from the same paused frame. The panel
	# is faded out for the photograph only: raising the device is what lights the
	# torch (`is_lit()` is `raised > 0.5`), and the device draws its screen over
	# the frame, so both shots would otherwise be of the World Index again.
	hunt.handheld.toggle_device()
	hunt.yaw = PI
	hunt.pitch = -0.06
	for _tick in 30:
		await get_tree().physics_frame
	hunt.handheld.modulate.a = 0.0
	get_tree().paused = true
	for exposure: Array in [["off", 0.0], ["on", 1.0]]:
		hunt.handheld_warp.set_amount(float(exposure[1]))
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/torch_%s.png" % [out_dir, exposure[0]])
	get_tree().paused = false
	# A6.1 / A6.2. Looking up, which nothing in this harness had ever done: the
	# break sits well above the horizon and every previous shot was framed at
	# eye level, where the only sky in frame is the strip the fog eats.
	# The device is left raised by the torch pair above and its panel covers the
	# frame, so it is faded rather than toggled: toggling it here photographed
	# the World Index with a corner of sky around it.
	hunt.handheld.modulate.a = 0.0
	hunt.player_body.position = Vector3(-6, 0.9, -4)
	# Aimed at the break rather than at the sky and hoping. The fracture covers
	# well under a percent of the dome by design, so a fixed heading photographs
	# an intact sky and proves nothing; this reads the map the shader samples,
	# finds the most broken texel in it, and turns the player to face it.
	var fracture := WorldLook.firmament().get_image()
	var best := 0.0
	var best_yaw := 0.6
	var best_pitch := 0.8
	for y in fracture.get_height():
		for x in fracture.get_width():
			var amount := fracture.get_pixel(x, y).r
			if amount > best:
				best = amount
				# Inverse of the shader's equirect mapping.
				best_yaw = (float(x) / float(fracture.get_width()) - 0.5) * TAU
				best_pitch = PI * 0.5 - float(y) / float(fracture.get_height()) * PI
	print("BREAK_AT yaw=%.2f pitch=%.2f strength=%.2f" % [best_yaw, best_pitch, best])
	hunt.yaw = best_yaw
	hunt.pitch = best_pitch
	for hour: float in [12.0, 1.0]:
		WorldClock.set_hour(hour)
		hunt._update_day_night()
		for _tick in 8:
			await get_tree().physics_frame
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/sky_%02d.png" % [out_dir, int(hour)])

	print("TORCH_LIT=", hunt.handheld.torch_active(), " BEAM=", hunt.handheld_lamp.light_energy)
	print("WARP_SHELLS=", get_tree().get_nodes_in_group(LightWarp.GROUP).size())
	# A7.1 / A7.2. Whoever is up at the hour, photographed from underneath, and
	# then looked at long enough for the world to write it down.
	for hour: float in [13.0, 2.0]:
		WorldClock.set_hour(hour)
		hunt._update_day_night()
		var present := Gods.up_now(WorldClock.hour())
		if present.is_empty():
			print("NO_GODS_AT ", hour)
			continue
		var body: Dictionary = present[present.size() - 1]
		var toward := Gods.direction(body)
		hunt.yaw = atan2(toward.x, toward.z)
		hunt.pitch = asin(toward.y)
		# Long enough to cross SIGHTING_SECONDS, since the whole point of A7.2
		# is that a glance while running does not count.
		for _tick in 130:
			await get_tree().process_frame
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/gods_%02d.png" % [out_dir, int(hour)])
		print("GODS_AT %02d up=%d facing=%s seen=%d" % [
			int(hour), present.size(), body["name"], WorldHistory.event_count("god_seen"),
		])
	print("CAPTURE_DONE")
	get_tree().quit()
