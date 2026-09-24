extends Node

## Agent 1 brief. Naked eye vs the lens, at night, side by side in one image
## — the claim is specifically that the world stays dark and only the lens
## amplifies, so this has to be seen rather than only asserted numerically.

const HUNT := preload("res://bone_yard_hunt.tscn")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	await tree.process_frame

	var hunt = HUNT.instantiate()
	tree.root.add_child(hunt)
	tree.current_scene = hunt
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	WorldClock.set_hour(1.5)
	for _frame in 40:
		await tree.process_frame

	await RenderingServer.frame_post_draw
	var naked_eye := get_viewport().get_texture().get_image()
	naked_eye.save_png("%s/black_mirror_naked_eye.png" % out_dir)
	print("CAPTURED: %s/black_mirror_naked_eye.png" % out_dir)

	# The save may hold a dropped phone; the shot needs it in hand.
	if hunt.dropped_handheld != null:
		hunt.dropped_handheld.queue_free()
		hunt.dropped_handheld = null
	hunt.handheld.possessed = true
	hunt._toggle_black_mirror()
	for _frame in 10:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var through_lens := get_viewport().get_texture().get_image()
	through_lens.save_png("%s/black_mirror_through_lens.png" % out_dir)
	print("CAPTURED: %s/black_mirror_through_lens.png" % out_dir)

	tree.quit()
