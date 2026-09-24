extends Node

## F10.4 visual evidence. Loads the real Hunt, returns a saved rival through the
## production seam, then frames that same live encounter body close enough to
## judge the replacement arm rather than relying on a checklist sentence.


func _ready() -> void:
	var out_path := "res://captures/hunt_rival_return.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	WorldHistory.world_minute = 12.0 * WorldClock.MINUTES_PER_HOUR
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt.set_physics_process(false)

	var subject_id := "return_capture_actor"
	WorldHistory.register_subject(subject_id, {
		"name": "Road Knife Returned", "kind": "person", "role": "TOLL KNIFE",
		"elo": 1170, "status": "escaped", "is_rival": true,
		"rival_adaptation": {
			"kind": "prosthetic", "zone": "left_arm",
			"item": "industrial torque arm", "response": "replaces the limb the player took",
		},
		"anatomy_state": {
			"zones": {"left_arm": {"health": 0.0}}, "organs": {},
			"severed": ["left_arm"], "wounds": [], "cybernetics": [],
		},
	})
	if not hunt._spawn_returning_rival():
		push_error("CAPTURE_FAILED returning rival did not enter the live Hunt")
		get_tree().quit(1)
		return
	var actor: Dictionary = hunt.encounter_actors.filter(func(candidate: Dictionary):
		return str(candidate.get("subject_id", "")) == subject_id)[0]
	actor["disposition"] = "neutral"
	actor.node.global_position = hunt.player + Vector3(0.0, -0.5, -3.15)
	actor.node.look_at(hunt.player, Vector3.UP)

	hunt.yaw = PI
	hunt.pitch = -0.02
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	hunt._update_camera()
	hunt._update_day_night()
	hunt.prompt.text = "THE ROAD KNIFE CAME BACK // LEFT ARM REPLACED WITH INDUSTRIAL TORQUE"
	hunt._update_hud()
	for _settle in 45:
		await get_tree().process_frame
		hunt._update_camera()
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out_path)
	print("HUNT_RIVAL_RETURN_CAPTURE_RESULT path=", out_path, " result=", result)
	get_tree().quit(0 if result == OK else 1)
