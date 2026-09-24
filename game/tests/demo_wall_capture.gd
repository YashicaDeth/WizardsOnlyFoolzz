extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out_path := "P:/GameDev/Temp/lane4_demo_wall.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	# A sample run, so the card's record column has something to show.
	WorldHistory.clear_history()
	FacilityRoutes.ensure()
	WorldHistory.amend_subject(FacilityRoutes.SUBJECT, {"completed_routes": [FacilityRoutes.ROUTE_HEAT_ELEVATOR]})
	for kind in ["player_died", "npc_killed", "npc_killed", "npc_killed", "bingyanga_released", "bingyanga_released", "growing_floor_vat_smashed", "growing_floor_vat_smashed", "blood_move"]:
		WorldHistory.record_event(kind, {})
	WorldHistory.record_event("world_object_struck", {"broke": true})
	var wall := DemoWall.new()
	add_child(wall)
	wall.open_wall()
	# This harness needs frames to reach the renderer; demo_wall_test separately
	# proves that production open_wall() leaves the game paused beneath it.
	get_tree().paused = false
	for _frame in 50:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out_path)
	print("shot at hour %.2f (%s), daylight %.3f" % [WorldClock.hour(), WorldClock.phase(), WorldClock.daylight()])
	print("CAPTURED: " if result == OK else "CAPTURE_FAILED: ", out_path)
	get_tree().paused = false
	get_tree().quit(0 if result == OK else 1)
