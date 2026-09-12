extends Node

## The held weapon, in the scene the player actually sees it in. A capture in a
## studio proves the geometry; only the hunt proves the mount.

const HUNT := preload("res://bone_yard_hunt.tscn")

var hunt


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(90.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	await tree.process_frame

	hunt = HUNT.instantiate()
	tree.root.add_child(hunt)
	tree.current_scene = hunt
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for _frame in 40:
		await tree.process_frame

	var arsenal = hunt.get("arsenal")
	for slot in [1, 2, 3]:
		if arsenal != null:
			arsenal.select_slot(slot)
		for _settle in 12:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/hunt_weapon_%d.png" % [out_dir, slot]
		print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
	tree.quit(0)
