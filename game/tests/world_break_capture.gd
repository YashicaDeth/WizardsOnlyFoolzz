extends Node

## The Hunt's breakable yard before and after: a streetlight shot to hanging,
## a barricade cut apart into fragments on the ground. Run: ... -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _frame in 60:
		WorldHistory.world_minute = WorldClock.OPENING_MINUTE
		await get_tree().process_frame
	hunt.set_physics_process(false)
	hunt.get_node("HUD").visible = false
	var eye := Camera3D.new()
	add_child(eye)
	eye.fov = 62.0
	eye.current = true
	var views := [["barricade", Vector3(14.8, 1.9, 8.2), Vector3(12.0, 0.7, 11.5)], ["light", Vector3(14.0, 1.9, 7.0), Vector3(10.5, 2.6, 4.0)]]
	for view in views:
		eye.global_position = view[1]
		eye.look_at(view[2], Vector3.UP)
		await _hold(6)
		await _capture("%s/yard_%s_before.png" % [out_dir, str(view[0])])
	var light: Node3D = hunt.breakables[0]
	for shot in 5:
		hunt._on_round_hit({"collider": light, "position": light.global_position + Vector3(0, 4.0, 0), "direction": Vector3(-1, 0, -0.3).normalized(), "calibre": "pistol", "energy": 1.0, "shooter": "player", "payload": {"damage": 24.0, "weapon": "sidearm"}})
	var barricade: Node3D = hunt.breakables[2]
	for blow in 3:
		hunt._on_round_hit({"collider": barricade, "position": barricade.global_position, "direction": Vector3(-0.4, 0, 1).normalized(), "calibre": "buck", "energy": 1.0, "shooter": "player", "payload": {"damage": 30.0, "weapon": "shotgun"}})
	for _frame in 50:
		WorldHistory.world_minute = WorldClock.OPENING_MINUTE
		await get_tree().physics_frame
	for view in views:
		eye.global_position = view[1]
		eye.look_at(view[2], Vector3.UP)
		await _hold(4)
		await _capture("%s/yard_%s_after.png" % [out_dir, str(view[0])])
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
