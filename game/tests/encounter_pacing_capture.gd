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

	# Put one real production actor in the player's view and freeze only the
	# simulation after perception has entered the reaction state. The body,
	# identity plate, HUD and prompt are the same ones gameplay uses.
	for existing: Dictionary in hunt.encounter_actors:
		if is_instance_valid(existing.get("node")):
			existing.node.queue_free()
	hunt.encounter_actors.clear()
	hunt.player = Vector3(0, 1.5, 19)
	hunt.player_body.position = Vector3(0, 0.9, 19)
	var actor: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "reaction_capture", "kind": "hostile",
		"display_name": "Pike Murrain", "role": "Rig mechanic",
	}, hunt.player + Vector3(0, -0.6, -8.0))
	actor["tracking_player"] = true
	actor["notice_remaining"] = hunt.ENCOUNTER_NOTICE_SECONDS
	actor["state"] = "noticing"
	hunt.prompt.text = "PIKE MURRAIN SPOTS YOU // MOVE, DRAW, OR BREAK SIGHT"
	hunt._update_camera()
	hunt._update_hud()
	hunt.set_physics_process(false)
	for _settle in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/encounter_reaction_window.png" % out_dir
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_FAILED %s (%s)" % [path, error_string(error)])
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
	get_tree().quit()
