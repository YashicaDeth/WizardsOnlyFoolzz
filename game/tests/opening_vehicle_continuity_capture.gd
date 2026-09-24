extends Node

## Visual evidence for the two vehicle seams in the production opening: the
## first frame already occupies the cab, and a won heat exits through physical
## camera travel rather than cutting directly to the Ringmaster or Hunt.

var out_dir := "P:/GameDev/Temp"


func _shot(name: String) -> void:
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED " if result == OK else "CAPTURE_FAILED ", path)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var derby = load("res://underground_colosseum.tscn").instantiate()
	add_child(derby)
	await get_tree().physics_frame
	derby.set_physics_process(false)
	derby._update_hud()
	await _shot("opening_vehicle_arrival_cab")

	derby.round_state = "active"
	derby._begin_climbing_out()
	derby._update_hud()
	await _shot("opening_vehicle_exit_refused")

	derby.round_state = "won"
	derby._begin_climbing_out()
	derby._update_climb_out(0.58)
	derby._update_hud()
	await _shot("opening_vehicle_exit_midway")
	derby._update_climb_out(0.62)
	derby._update_hud()
	await _shot("opening_vehicle_exit_standing")
	get_tree().quit()
