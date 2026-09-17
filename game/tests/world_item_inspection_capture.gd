extends Node

## I9 visual proof: a pickup remains visibly on the shared station while its
## live geometry is presented in the same bottom-right reliquary as held gear.

func _ready() -> void:
	var out_path := "res://captures/world_item_inspection.png"
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
	var first: Dictionary = (hunt.substance_station.pickups() as Array)[0]
	var source := first["node"] as Node3D
	var station_at: Vector3 = hunt.substance_station.global_position
	hunt.player_body.global_position = station_at + Vector3(0.0, 0.9, 2.05)
	hunt.player = hunt.player_body.global_position + Vector3.UP * 0.6
	hunt.yaw = PI
	hunt.pitch = -0.25
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	hunt._update_camera()
	# Select this exact live object for a deterministic proof rather than relying
	# on which neighbouring packet wins an equal-distance comparison.
	hunt.inspected_world_item = {
		"source": source,
		"item_id": str(first["id"]),
		"kind": str(first["kind"]),
		"label": str(first["label"]),
		"detail": str(first.get("form", "ground")),
	}
	hunt.inspect_held = true
	hunt.prompt.text = "%s // INSPECT // RELEASE I TO LOWER" % str(first["label"])
	hunt._update_day_night()
	hunt._update_hud()
	for _settle in 45:
		hunt._update_held_reliquary()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out_path)
	print("WORLD_ITEM_INSPECTION_CAPTURE_RESULT path=", out_path, " result=", result)
	get_tree().quit(0 if result == OK else 1)
