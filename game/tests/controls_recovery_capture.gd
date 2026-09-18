extends Node

var out_dir := "res://captures"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 30:
		await get_tree().process_frame

	# The production F1 surface, one legible leaf at a time.
	hunt.keys_card.toggle()
	hunt.keys_card.shown = 1.0
	hunt.keys_card.queue_redraw()
	await _capture("controls_movement_combat.png")
	hunt.keys_card.change_page(1)
	await _capture("controls_hands_interfaces.png")
	hunt.keys_card.close()
	hunt.keys_card.shown = 0.0
	hunt.keys_card.queue_redraw()
	await get_tree().process_frame

	# First contact immediately makes F real; photograph the actual camera/body
	# switch rather than a standalone model viewer.
	hunt.player = Vector3(90, 1.5, 90)
	hunt.player_body.position = Vector3(90, 0.9, 90)
	hunt.camera_ready = false
	WorldHistory.record_event("melee_body_hit", {"target": "capture_contact", "location": hunt.HUNT_LOCATION})
	var switch := InputEventKey.new()
	switch.keycode = KEY_F
	switch.pressed = true
	hunt._unhandled_input(switch)
	hunt.perspective_blend = 1.0
	hunt._update_camera()
	for _settle in 45:
		await get_tree().process_frame
	await _capture("third_person_after_first_contact.png")

	# One real actor under the reticle, one real grapple state and the controls
	# written where the player is already looking during the hold.
	for existing: Dictionary in hunt.encounter_actors:
		if is_instance_valid(existing.get("node")):
			existing.node.queue_free()
	hunt.encounter_actors.clear()
	hunt.third_person = false
	hunt.perspective_blend = 0.0
	hunt.body_motion.set_perspective(true)
	hunt.player = Vector3(0, 1.5, 19)
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.yaw = PI
	var actor: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "grapple_capture", "kind": "hostile",
		"display_name": "Pike Murrain", "role": "Rig mechanic",
	}, hunt.player + Vector3(0, -0.6, -2.0))
	hunt._start_grapple()
	hunt.grapple_advantage = 0.28
	hunt.grapple_pushing_override = false
	hunt.grapple_drag_override = Vector2.ZERO
	hunt._update_grapple(0.01)
	hunt.grapple_drag_override = null
	hunt.set_physics_process(false)
	hunt._update_camera()
	hunt._update_hud()
	for _settle in 6:
		await get_tree().process_frame
	await _capture("grapple_clinch_controls.png")
	actor.node.queue_free()
	get_tree().quit()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s" % [out_dir, file_name]
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_FAILED %s (%s)" % [path, error_string(error)])
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
