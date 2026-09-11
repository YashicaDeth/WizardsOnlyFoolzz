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
	for _index in settle_frames:
		await get_tree().process_frame

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
	print("CAPTURED: ", out_path, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
