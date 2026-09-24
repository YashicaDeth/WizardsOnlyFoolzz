extends Node

## Visual check harness. Headless runs prove a scene has no runtime errors but
## render nothing, so look work cannot be verified that way. This loads a scene,
## lets it settle, and writes one PNG.
##
## Usage:
##   Godot --path game res://tests/capture_scene.tscn -- \
##       --scene=res://rift_derby.tscn --out=P:/GameDev/Temp/look.png --frames=120

func _ready() -> void:
	var scene_path := "res://rift_derby.tscn"
	var out_path := "P:/GameDev/Temp/capture.png"
	var settle_frames := 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--frames="):
			settle_frames = int(argument.trim_prefix("--frames="))

	var archive_subject := ""
	var trigger := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			archive_subject = argument.trim_prefix("--archive=")
		elif argument.begins_with("--trigger="):
			trigger = argument.trim_prefix("--trigger=")

	var packed := load(scene_path)
	if packed == null:
		print("CAPTURE_FAILED: could not load ", scene_path)
		get_tree().quit(1)
		return
	var scene: Node = packed.instantiate()
	add_child(scene)

	if not archive_subject.is_empty():
		await get_tree().process_frame
		var archive: Node = scene.get_node_or_null("HUD/CharacterArchive")
		if archive == null:
			print("CAPTURE_FAILED: no HUD/CharacterArchive in ", scene_path)
			get_tree().quit(1)
			return
		# The host scene re-asserts archive visibility from panel_mode every frame,
		# so opening the control alone is undone on the next tick.
		if "panel_mode" in scene:
			scene.set("panel_mode", "tree")
		archive.open_archive(archive_subject)

	# Procedural noise textures and the sky resolve over several frames; capturing
	# immediately yields an untextured, unlit frame that misrepresents the look.
	#
	# The clock is pinned while that happens, and this is not a nicety. Settling
	# is counted in *frames*, and a heavy scene spends real seconds on each one
	# while it generates a region and compiles shaders. `WorldClock` advances at
	# one game-minute per real second, so a 240-frame settle on the Hunt Grounds
	# took about three and a half real minutes and moved the world three and a
	# half *hours* — 16:30 walked to 19:52, and the shot came back at dusk with
	# the sun down at 0.35 energy. Every long capture of a live scene has been
	# photographing a later time of day than the one it was asked for, and a
	# capture that quietly ages the world is worse than no capture: it produces
	# confident, wrong conclusions about how the game looks.
	# Pinned to a *known* hour rather than to whatever the world happens to hold.
	# `world_minute` persists between runs, so a run of captures walks it forward
	# and every shot lands later in the day than the one before it — which is how
	# the Hunt Grounds came back at 19:52 and got written up as a lighting bug.
	# A capture that is not reproducible cannot be evidence of anything.
	var pinned := WorldClock.OPENING_MINUTE
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hour="):
			pinned = float(argument.trim_prefix("--hour=")) * 60.0
	for _index in settle_frames:
		WorldHistory.world_minute = pinned
		await get_tree().process_frame
	WorldHistory.world_minute = pinned

	# Effects that play out over time are fired late, then given frames to reach
	# the moment worth photographing.
	if trigger in ["resolution", "execution"]:
		scene._spawn_encounter_actor({"instance_id": "capture_downed", "kind": "hostile"}, scene.player + Vector3(0, 0, 2))
		var actor: Dictionary = scene.encounter_actors.back()
		actor.node.position = scene.player + Vector3(0, 0, 2)
		WorldHistory.update_subject(actor.subject_id, {"bond": 25})
		for hit in 7:
			actor.rig.hit("torso", 30, 10, "blunt")
		scene._open_resolution(actor)
		if trigger == "execution":
			scene.resolution_ui._choose(0)
		for hold in 20:
			await get_tree().process_frame
	elif trigger in ["map", "map_walked"]:
		# Walk a route first so the survey has something charted to show; a fresh
		# save would otherwise photograph an honestly, but uselessly, blank sheet.
		if trigger == "map_walked":
			# A route from the start out to the Ossuary district, so the sheet
			# shows charted ground against unsurveyed ground rather than a blank.
			var start := Vector3(0, 1.5, 19)
			var finish := Vector3(135, 1.5, 0)
			for step in 120:
				var walk: Vector3 = start.lerp(finish, float(step) / 119.0)
				scene.player = walk
				scene.living_map.observe(walk, 1.9)
		scene._toggle_panel("map")
		for _hold in 6:
			await get_tree().process_frame
	elif trigger == "bruise":
		# Beat a body without opening it, so the shot shows bruising rather than
		# blood: the stage that used to be invisible.
		scene.yaw = 2.7
		for step in 30:
			scene.player_body.position = scene.player_body.position + Vector3(-0.42, 0, -0.2)
			scene.player = scene.player_body.position + Vector3.UP * 0.6
			await get_tree().physics_frame
		var stand: Vector3 = scene.player + Vector3(sin(scene.yaw), 0, cos(scene.yaw)) * 3.0
		stand.y = scene.player.y
		scene._spawn_encounter_actor({"instance_id": "bruise_probe", "kind": "hostile"}, stand)
		var subject: Dictionary = scene.encounter_actors.back()
		subject.node.position = stand
		subject.rig.gore = false
		await get_tree().physics_frame
		for blow in 3:
			subject.rig.hit("left_arm", 20.0, 8.0, "blunt")
			subject.rig.hit("torso", 26.0, 10.0, "blunt")
			subject.rig.hit("head", 9.0, 6.0, "blunt")
		for _hold in 20:
			await get_tree().physics_frame
	elif trigger == "gore":
		# Stand a body in front of the camera and open it up, then let the blood
		# fall so the shot shows what the floor looks like after a fight.
		scene.yaw = 2.7
		for step in 30:
			scene.player_body.position = scene.player_body.position + Vector3(-0.42, 0, -0.2)
			scene.player = scene.player_body.position + Vector3.UP * 0.6
			await get_tree().physics_frame
		var at: Vector3 = scene.player + Vector3(sin(scene.yaw), 0, cos(scene.yaw)) * 3.4
		at.y = scene.player.y
		scene._spawn_encounter_actor({"instance_id": "gore_probe", "kind": "hostile"}, at)
		var victim: Dictionary = scene.encounter_actors.back()
		victim.node.position = at
		await get_tree().physics_frame
		for blow in 14:
			victim.rig.hit("torso" if blow % 2 == 0 else "left_arm", 26.0, 14.0, "cut")
			for settle in 12:
				await get_tree().physics_frame
		for _hold in 30:
			await get_tree().physics_frame
	elif trigger == "lock":
		scene.yaw = 2.7
		for step in 40:
			scene.player_body.position = scene.player_body.position + Vector3(-0.42, 0, -0.2)
			scene.player = scene.player_body.position + Vector3.UP * 0.6
			await get_tree().physics_frame
		var ahead: Vector3 = scene.player + Vector3(sin(scene.yaw), -0.6, cos(scene.yaw)) * 5.0
		scene._spawn_encounter_actor({"instance_id": "lock_probe", "kind": "hostile"}, ahead)
		scene.encounter_actors.back().node.position = ahead
		scene._toggle_lock()
		for _hold in 40:
			await get_tree().physics_frame
		for _draw_hold in 6:
			await get_tree().process_frame
	elif trigger == "swing":
		# Third person: a real dodge (ash), then a real committed swing, shot
		# a few frames in so the trail, cable and smear are drawn from the
		# weapon's actual motion against the Hunt's own light and fog.
		# Open ground first (the lock trigger's walk): at the spawn a wall pulls
		# the third-person camera back into the eye.
		scene.yaw = 2.7
		for step in 40:
			scene.player_body.position = scene.player_body.position + Vector3(-0.42, 0, -0.2)
			scene.player = scene.player_body.position + Vector3.UP * 0.6
			await get_tree().physics_frame
		scene.third_person = true
		# The blend runs on physics frames; wait until the camera has really
		# pulled back, or the shot is first person.
		for _settle in 180:
			await get_tree().physics_frame
			if scene.perspective_blend >= 0.99:
				break
		scene._dodge()
		for _step in 6:
			await get_tree().physics_frame
		scene._attack(true)
		# SWING_FRAMES picks the instant of the swing to photograph.
		var swing_frames := int(OS.get_environment("SWING_FRAMES")) if OS.get_environment("SWING_FRAMES") != "" else 9
		for _swing in swing_frames:
			# Thrown the way a player throws it: a hard mouse sweep across the
			# swing, which is what LimbMomentum reads as commitment. A scripted
			# attack with no look motion has commitment 0 and draws the faintest
			# possible trail -- invisible in the Hunt's light.
			scene._look_delta = Vector2(-38.0, 6.0)
			await get_tree().physics_frame
		await get_tree().process_frame
	elif trigger == "reel":
		# A short played sequence for a video: open ground, third person, two
		# hostiles, lock on, then dodge-and-swing exchanges thrown with real
		# mouse sweeps, alternating direction like a player would.
		scene.yaw = 2.7
		for step in 40:
			scene.player_body.position = scene.player_body.position + Vector3(-0.42, 0, -0.2)
			scene.player = scene.player_body.position + Vector3.UP * 0.6
			await get_tree().physics_frame
		scene.third_person = true
		for _settle in 90:
			await get_tree().physics_frame
		var fwd := Vector3(sin(scene.yaw), 0, cos(scene.yaw))
		var right := Vector3(fwd.z, 0, -fwd.x)
		for i in 2:
			var at: Vector3 = scene.player + fwd * 4.0 + right * (1.4 if i == 0 else -1.6) + Vector3.DOWN * 0.6
			scene._spawn_encounter_actor({"instance_id": "reel_%d" % i, "kind": "hostile"}, at)
			scene.encounter_actors.back().node.position = at
		for _look in 30:
			await get_tree().physics_frame
		scene._toggle_lock()
		for exchange in 4:
			# One dodge in two: five straight ones drained stamina (the last
			# blow was refused) and carried the hunter into a building.
			if exchange % 2 == 1:
				scene._dodge()
				for _step in 8:
					await get_tree().physics_frame
			scene._attack(exchange % 2 == 0)
			var sweep := Vector2(-38.0 if exchange % 2 == 0 else 38.0, 6.0)
			for _swing in 12:
				scene._look_delta = sweep
				await get_tree().physics_frame
			for _recover in 40:
				await get_tree().physics_frame
		for _hold in 45:
			await get_tree().physics_frame
	elif trigger == "holdtool":
		# The arcade's breach tool, in hand, as picking it up leaves it.
		LabSurface.hold_in_view(scene.camera, scene.weapon_visual)
		for _hold in 10:
			await get_tree().process_frame
	elif trigger == "threat":
		# Three enemies winding up around the player -- behind and due, to the
		# left mid-swing, ahead-right just starting -- so the ThreatCompass
		# arcs are seen against the real HUD's edge instruments.
		var fwd := Vector3(sin(scene.yaw), 0, cos(scene.yaw))
		var right := Vector3(fwd.z, 0, -fwd.x)
		for _hold in 20:
			scene.threat_compass.report("behind", scene.player - fwd * 4.0, 0.95)
			scene.threat_compass.report("left", scene.player - right * 4.0, 0.5)
			scene.threat_compass.report("ahead_right", scene.player + (fwd + right) * 3.0, 0.15)
			await get_tree().process_frame
	elif trigger == "walk":
		# Move off the spawn so the shot is the travelling camera, not the
		# vehicle the player has just climbed out of.
		scene.yaw = 2.7
		for step in 60:
			scene.player_body.position = scene.player_body.position + Vector3(-0.42, 0, -0.2)
			scene.player = scene.player_body.position + Vector3.UP * 0.6
			await get_tree().physics_frame
		for _hold in 10:
			await get_tree().process_frame
	elif trigger == "vat_aisle":
		# P4.3. Skips straight past the locked submerged/voiding/floor beats
		# into the walkable aisle itself, standing near the door end, so a
		# change to AISLE_LENGTH or the bay dressing can be looked at without
		# waiting out ~13s of cutscene per capture.
		scene.phase = "aisle"
		scene.can_move = true
		scene._on_intake_filed({})
		var aisle_len: float = scene.get("AISLE_LENGTH")
		scene.player.position = Vector3(0.0, 1.62, -aisle_len + 4.0)
		scene.yaw = PI
		scene.player.rotation.y = scene.yaw
		for _hold in 10:
			await get_tree().process_frame
	elif trigger == "killcam":
		var cam: Node = scene.get_node_or_null("HUD/KillCam")
		if cam != null:
			cam.trigger("DERBY DRIVER", "torso", Vector3(-1, 0, 0), "FRONT END THROUGH THE CAB")
			for _hold in 48:
				await get_tree().process_frame
	elif trigger == "handheld":
		var device: Node = scene.get_node_or_null("HUD/Handheld")
		if device != null:
			device.open_device()
			device.set_mode("WIRE")
			for _hold in 60:
				await get_tree().process_frame
	elif trigger == "radio":
		var device: Node = scene.get_node_or_null("HUD/Handheld")
		if device != null:
			device.open_device()
			device.set_mode("RADIO")
			# Held long enough for a real audio device to actually mix and
			# for the spectrum analyzer to have real samples to report on —
			# a dummy/headless driver never processes DSP at all, which is
			# exactly why this needed a real capture rather than a number
			# printed from a headless run.
			for _hold in 90:
				await get_tree().process_frame
	elif trigger == "altered":
		# E6/E8. Forced directly rather than routed through a real substance
		# or meditation session, which need input this harness does not drive.
		scene.player_rig.anatomy.consciousness = 30.0
		scene._update_altered_perception()
		for _hold in 6:
			await get_tree().process_frame
	elif trigger == "portrait_art":
		var portrait: GPUParticles3D = preload("res://systems/particle_portrait.gd").new()
		add_child(portrait)
		portrait.position = Vector3(0, 1.6, -2.5)
		portrait.set_source_from_art("body", 22, 56, 56)
		portrait.set_dial("spread", 1.6)
		portrait.set_dial("depth_scale", 0.4)
		var cam := Camera3D.new()
		add_child(cam)
		cam.position = Vector3(0, 1.6, 0)
		cam.look_at(portrait.position, Vector3.UP)
		cam.current = true
		for _hold in 20:
			await get_tree().process_frame
	elif trigger == "portrait_spirit":
		# Third person and held: a first-person camera sits essentially
		# inside the cloud's own origin (it is centred on the player's own
		# body) and _update_camera() resets any manual override every
		# physics frame regardless, the same lesson AS3.4's capture needed.
		var target: Node3D = scene.player_rig
		scene.third_person = true
		var portrait: GPUParticles3D = preload("res://systems/particle_portrait.gd").new()
		scene.add_child(portrait)
		portrait.global_position = target.global_position
		portrait.set_dial("spread", 1.8)
		portrait.set_dial("depth_scale", 0.5)
		portrait.set_dial("glitch", 0.05)
		portrait.follow_node(target, 64, 64, Vector2i(256, 256))
		for _hold in 60:
			scene._update_camera()
			await get_tree().process_frame
	elif trigger == "glitch_spider":
		scene.glitch_spider.trigger(scene.player + Vector3(0, 0.3, -3), scene.player, scene.psychedelic)
		for _hold in 6:
			await get_tree().process_frame
	elif trigger == "storm":
		# AS4. Force the chaos-magick level up directly rather than waiting on
		# a ritual, then force a strike so the shot lands mid-crawl instead of
		# on whatever random tick the storm's own clock would have picked.
		WorldHistory.chaos_magick_level = 0.95
		WorldHistory.chaos_magick_at_minute = WorldClock.minutes()
		WorldClock.set_hour(1.0)
		scene._update_day_night()
		var storm: Node3D = scene.storm_weather
		storm._process(0.1)
		storm._strike(storm.severity())
		if "--red" in OS.get_cmdline_user_args():
			storm._crawler_material.set_shader_parameter("red", true)
		for _hold in 6:
			storm._process(0.05)
			await get_tree().process_frame
	elif trigger == "night":
		# AS2. Forced rather than waited for — a real night is 24 real minutes
		# away at the default clock rate, per world_clock.gd.
		WorldClock.set_hour(2.0)
		scene._update_day_night()
		for _hold in 4:
			await get_tree().process_frame
	elif trigger == "clothing":
		# AS3.4. Third-person so the coat itself is actually in frame — first
		# person never sees the torso at all.
		scene.third_person = true
		Clothing.wear("player", "lead_vest")
		scene.hunter_appearance.sync_from_clothing()
		for _hold in 60:
			scene._update_camera()
			await get_tree().process_frame
	elif trigger == "lamp":
		# AS1.1. Raised by hand rather than by key so the shot is deterministic:
		# `raised` is a blended value, and holding the real key for an exact
		# number of frames would make the brightness depend on frame timing.
		scene.handheld.raised = 1.0
		scene.handheld.battery = 1.0
		for _hold in 4:
			await get_tree().process_frame
	elif trigger == "psychedelic":
		# FINAL_V.md §16. Several dials at once, at a strength nobody would
		# call subtle, so the shot proves the rig actually changes the frame
		# rather than merely failing to crash.
		var rig: Node = scene.get_node_or_null("HUD/Psychedelic")
		if rig != null:
			# Every dial at once, at a strength nobody would call subtle, so one
			# capture proves the whole shader — feedback included, the one
			# effect that previously hit a same-frame GPU texture hazard.
			rig.set_dial("kaleidoscope_segments", 5.0)
			rig.set_dial("chromatic_offset", 0.006)
			rig.set_dial("displacement_strength", 0.03)
			rig.set_dial("lut_strength", 0.4)
			rig.set_dial("feedback_strength", 0.45)
			rig.set_dial("feedback_zoom", 1.05)
			rig.set_dial("feedback_spin", 0.3)
			for _hold in 20:
				await get_tree().process_frame
	elif trigger == "unlock":
		# M1.5 proof. Satisfies `third_person_unlocked()`'s two real conditions
		# directly through WorldHistory — a melee hit landed, and a subject the
		# world already rated dangerous put down — rather than staging a full
		# fight, then lets the per-second poll in `_physics_process` catch it.
		WorldHistory.record_event("melee_body_hit", {"target": "capture_boss", "body_zone": "torso", "damage": 20, "location": "ashbloom_bone_yard"})
		WorldHistory.register_subject("capture_boss", {"name": "Capture Boss", "elo": 1200})
		WorldHistory.record_event("npc_resolution", {"subject_id": "capture_boss", "outcome": "execute", "actor": "player"})
		for _hold in 90:
			await get_tree().physics_frame
	elif trigger == "keys":
		scene.keys_card.toggle()
		for _hold in 6:
			await get_tree().process_frame
	elif trigger == "arsenal":
		scene.third_person = true
		scene._equip_weapon(1)
		var forward := Vector3(sin(scene.yaw), 0, cos(scene.yaw)).normalized()
		scene.player_body.position = Vector3(175, 0.9, 125)
		scene.player = scene.player_body.position + Vector3.UP * 0.6
		scene._spawn_encounter_actor({"instance_id": "capture_armed", "kind": "hostile", "summary": "weapons proof"}, scene.player + forward * 7.0)
		var actor: Dictionary = scene.encounter_actors.back()
		actor.node.position = scene.player + forward * 7.0 - Vector3.UP * 0.5
		scene._update_camera()
		scene.camera.global_position = scene.player - forward * 3.2 + Vector3.UP * 0.8
		scene.camera.look_at(scene.player + Vector3.UP * 0.3)
		for _hold in 30:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	if error != OK:
		print("CAPTURE_FAILED: save_png returned ", error)
		get_tree().quit(1)
		return
	print("shot at hour %.2f (%s), daylight %.3f" % [
		WorldClock.hour(), WorldClock.phase(), WorldClock.daylight()])
	print("CAPTURED: ", out_path, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
