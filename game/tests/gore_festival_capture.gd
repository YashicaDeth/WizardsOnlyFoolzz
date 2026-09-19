extends Node

## Visual proof for AP1.4/P10.5. The harness freezes the production colosseum
## during the press beat; it does not build a separate showcase scene.


func _ready() -> void:
	var out_path := "res://captures/p10_5_gore_festival.png"
	var stage := "before"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--stage="):
			stage = argument.trim_prefix("--stage=")
	get_window().size = Vector2i(1280, 720)
	var derby := (load("res://underground_colosseum.tscn") as PackedScene).instantiate()
	add_child(derby)
	await get_tree().physics_frame
	derby.set_physics_process(false)
	derby._set_gore_festival_pose(2.85 if stage == "after" else 0.65)
	derby.mode_label.visible = true
	derby.mode_label.text = "GORE FESTIVAL // LOT 0C-7 // THREE SLABS" if stage == "after" else "GORE FESTIVAL // LOT 0C-7 // PRESSING"
	derby._update_camera(1.0)
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", out_path)
	get_tree().quit(0 if error == OK else 1)
