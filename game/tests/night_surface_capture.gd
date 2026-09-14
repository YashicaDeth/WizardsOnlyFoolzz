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
	# A8.1 / A8.2. The spirit, seen from outside the body — intact first, then
	# with the body actually taken apart rather than the dial turned by hand,
	# since the claim is that the flame reads the anatomy.
	WorldClock.set_hour(1.0)
	hunt._update_day_night()
	hunt.third_person = true
	hunt.body_motion.set_perspective(false)
	hunt.player_body.position = Vector3(-6, 0.9, -4)
	hunt.yaw = 0.6
	hunt.pitch = 0.0
	for _tick in 24:
		await get_tree().physics_frame
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/flame_intact.png" % out_dir)
	print("FLAME_INTACT condition=%.2f" % hunt.player_rig.anatomy.combat_ratio())

	for zone: String in ["left_arm", "right_arm", "torso", "left_leg", "head"]:
		hunt.player_rig.hit(zone, 55.0, 0.0, "blunt")
	for _tick in 16:
		await get_tree().physics_frame
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/flame_showing.png" % out_dir)
	print("FLAME_WRECKED condition=%.2f" % hunt.player_rig.anatomy.combat_ratio())

	# Control. The first melt build smeared half the frame and the obvious
	# suspect was the shell, so the shell comes off and the same frame is shot
	# again: whatever survives this was never A8.2's doing.
	var shell := hunt.flame.get_node_or_null("FlameMelt") as MeshInstance3D
	if shell != null:
		shell.visible = false
	for _tick in 8:
		await get_tree().physics_frame
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/flame_nomelt.png" % out_dir)
	if shell != null:
		shell.visible = true

	# A8.2, isolated. The wrecked body against open sky rather than against a
	# lit wreck pile: the first attempt at this shot framed a rusted heap that
	# is soft and warm on its own, and the melt could not be told from it — a
	# control frame with the shell hidden proved the smear was the scenery.
	hunt.pitch = 0.32
	for _tick in 10:
		await get_tree().physics_frame
	get_tree().paused = true
	for exposure: Array in [["off", false], ["on", true]]:
		if shell != null:
			shell.visible = bool(exposure[1])
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/melt_%s.png" % [out_dir, exposure[0]])
	get_tree().paused = false

	# A9.1 / A9.2. The air, calm and then at storm severity, from the same spot
	# under the gate lamp — the one place a mote is lit well enough to be seen,
	# which is the entire argument for lighting them rather than making them
	# glow on their own.
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	hunt.player_body.position = Vector3(-6, 0.9, -10)
	hunt.yaw = 0.0
	hunt.pitch = 0.28
	WorldClock.set_hour(1.0)
	hunt._update_day_night()
	# Raised through the world rather than by setting the dial: `_update_air()`
	# reads `WorldWeather.contamination()` every physics frame, so anything
	# written straight onto the node is gone by the next one — which is the
	# system being right. Eight completed rituals is what a storm costs.
	for shot: String in ["calm", "storm"]:
		if shot == "storm":
			for _ritual in 8:
				WorldHistory.record_event("ritual_completed", {"source": "A9.2 capture"})
		hunt.air.restart()
		for _tick in 90:
			await get_tree().physics_frame
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/air_%s.png" % [out_dir, shot])
		print("AIR %s chaos=%.2f severity=%.2f ratio=%.2f" % [
			shot, WorldHistory.chaos_magick(), hunt.air.severity(), hunt.air.amount_ratio,
		])

	# A10.1 / A10.15. Framed by finding a bill rather than by guessing where one
	# is: one building in three carries one, and the generator decides which.
	var posted: Node3D = null
	for building: Node3D in hunt.generated_world.generated_buildings:
		if building.get_node_or_null("PostedBill") != null:
			posted = building
			break
	if posted == null:
		print("NO_BILLS")
	else:
		var bill := posted.get_node("PostedBill") as Node3D
		var face := bill.global_position
		WorldClock.set_hour(12.0)
		hunt._update_day_night()
		for _tick in 6:
			await get_tree().physics_frame
		# The camera is placed directly rather than by walking the player there.
		# Teleporting a physics body into a district drops it, pushes it out of
		# whatever it landed inside and leaves it metres from where it was put,
		# so two attempts at this shot photographed the skyline instead. Nothing
		# else in the harness needs the player moved for it, and this is the one
		# frame that is about looking at a specific object.
		# Paused before the camera is placed, because `_physics_process` calls
		# `_update_camera()` sixty times a second and will have put the camera
		# back where the player is standing before the frame is drawn.
		get_tree().paused = true
		hunt.camera.global_position = face + Vector3(0.75, 0.45, 3.1)
		hunt.camera.look_at(face, Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/posted_bill.png" % out_dir)
		get_tree().paused = false
		var billed := 0
		for building: Node3D in hunt.generated_world.generated_buildings:
			if building.get_node_or_null("PostedBill") != null:
				billed += 1
		print("BILLS %d of %d buildings" % [billed, hunt.generated_world.generated_buildings.size()])

	# A10.3. The same wall at noon and at one in the morning, with the emission
	# the surface itself carries read straight off a material rather than
	# inferred from a picture.
	var sample: StandardMaterial3D = WorldLook.surface(Color("3d1c11"), "rust", 5)
	for hour: float in [12.0, 1.0]:
		WorldClock.set_hour(hour)
		hunt._update_day_night()
		for _tick in 4:
			await get_tree().physics_frame
		print("MATERIAL_HOUR %02d glow=%.3f" % [int(hour), sample.emission_energy_multiplier])

	# A10.14. What each of this pass's systems costs, measured rather than
	# asserted, at the hour they all run at once: 01:00, with eleven lamps lit,
	# their warp shells up, the air at full severity, the gods in the sky and
	# the player burning.
	#
	# Toggled one at a time and restored in between, not stacked. The first
	# build of this disabled each system on top of the last and reported a
	# scene that got *slower* as things were switched off, which is what a
	# cumulative measurement of a noisy monitor looks like.
	WorldClock.set_hour(1.0)
	hunt._update_day_night()
	hunt.player_body.position = Vector3(-6, 0.9, -4)
	for _tick in 30:
		await get_tree().physics_frame

	var budget := {}
	for pass_name: String in ["all", "no_air", "no_warp", "no_flame", "all_again"]:
		hunt.air.visible = pass_name != "no_air"
		for warp_shell in get_tree().get_nodes_in_group(LightWarp.GROUP):
			(warp_shell as Node3D).visible = pass_name != "no_warp"
		var burning := hunt.flame.get_node_or_null("FlameMelt") as Node3D
		if burning != null:
			burning.visible = pass_name != "no_flame"
		# Long settle: the first frames after a visibility change are spent
		# rebuilding what was switched off and are not what it costs to run.
		for _settle in 45:
			await get_tree().process_frame
		var total := 0.0
		for _sample in 150:
			await get_tree().process_frame
			total += Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		budget[pass_name] = snappedf(total / 150.0 * 1000.0, 0.01)
	print("BUDGET_MS %s" % [budget])
	print("DRAW_CALLS %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	# A10.6. Three square metres of this world at arm's length, chosen to be
	# ordinary rather than photogenic: a wreck face, the ground somebody walks
	# on, and a district wall. Paused for the same reason the bill shot is —
	# `_update_camera()` puts the camera back sixty times a second.
	WorldClock.set_hour(12.0)
	hunt._update_day_night()
	for _tick in 8:
		await get_tree().physics_frame
	get_tree().paused = true
	var square_metres := {
		"wreck": [Vector3(-6.0, 1.4, -14.0), Vector3(-6.0, 1.4, -17.0)],
		"ground": [Vector3(-6.0, 1.1, -4.0), Vector3(-6.0, 0.0, -4.6)],
		"wall": [Vector3(-150.0, 1.6, -119.0), Vector3(-150.0, 1.6, -122.0)],
	}
	for surface_name: String in square_metres:
		var placement: Array = square_metres[surface_name]
		hunt.camera.global_position = placement[0]
		hunt.camera.look_at(placement[1], Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/metre_%s.png" % [out_dir, surface_name])
	get_tree().paused = false

	# B2.1. Damage the rig by a path that does *not* report itself — `hit()`
	# straight on the anatomy, which is what every future system that changes a
	# body will look like — and see whether the chart the player is reading
	# catches up. Before this, `anatomy_state` only ever moved when
	# `_take_damage()` wrote it, so the answer was no.
	if not hunt.handheld.is_open:
		hunt.handheld.toggle_device()
	for _tick in 20:
		await get_tree().physics_frame
	var before: Dictionary = (WorldHistory.subject("player").get("anatomy_state", {}) as Dictionary)
	var before_hash := hash(before)
	hunt.player_rig.hit("left_arm", 34.0, 0.0, "blunt")
	for _tick in 60:
		await get_tree().physics_frame
	var after: Dictionary = (WorldHistory.subject("player").get("anatomy_state", {}) as Dictionary)
	print("BODY_RECORD open=%s changed=%s empty_before=%s" % [
		hunt.handheld.is_open, hash(after) != before_hash, before.is_empty(),
	])
	hunt.handheld.toggle_device()
	for _tick in 20:
		await get_tree().physics_frame
	var closed_hash := hash((WorldHistory.subject("player").get("anatomy_state", {}) as Dictionary))
	hunt.player_rig.hit("right_arm", 34.0, 0.0, "blunt")
	for _tick in 60:
		await get_tree().physics_frame
	print("BODY_RECORD_CLOSED still=%s" % [
		hash((WorldHistory.subject("player").get("anatomy_state", {}) as Dictionary)) == closed_hash,
	])

	print("CAPTURE_DONE")
	get_tree().quit()
