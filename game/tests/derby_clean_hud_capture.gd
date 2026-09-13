extends Node

## I0 visual proof: show the actual derby scene with a damaged player skiff and
## verify that the rejected permanent overlays were not instantiated.

func _ready() -> void:
	var out_path := "res://captures/g0_derby_clean_hud.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var derby = load("res://rift_derby.tscn").instantiate()
	add_child(derby)
	await get_tree().physics_frame
	derby.leaving = true
	derby.round_state = "active"
	derby.boat.integrity = 38
	derby._update_player_damage_visual(Vector3(1.0, 0.0, -0.4).normalized())
	derby._update_hud()
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hud = derby.get_node("HUD")
	var interface = hud.get_node("DynamicInterface")
	var rejected_nodes_absent := hud.get_node_or_null("CabScreens") == null and hud.get_node_or_null("DamagePortrait") == null
	var no_permanent_readouts: bool = interface.has_method("has_permanent_readouts") and not bool(interface.call("has_permanent_readouts"))
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	print("HUD_REJECTION: nodes_absent=", rejected_nodes_absent, " readouts_absent=", no_permanent_readouts)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", out_path)
	get_tree().quit(0 if error == OK and rejected_nodes_absent and no_permanent_readouts else 1)
