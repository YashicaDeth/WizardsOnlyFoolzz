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
	# A capture that cannot be written is not a capture. Godot will not create
	# the directory, and this harness used to print CAPTURED either way, which
	# is how a run can report three frames and leave nothing on disk.
	DirAccess.make_dir_recursive_absolute(out_dir)

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

	hunt._mirror.cycle_mode()
	for _frame in 10:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var depth := get_viewport().get_texture().get_image()
	depth.save_png("%s/black_mirror_depth.png" % out_dir)
	print("CAPTURED: %s/black_mirror_depth.png" % out_dir)

	# The case the environment fix is about: the phone lowered and raised again
	# with the depth camera still selected. Nothing resets the mode, so this is
	# ordinary play, and before the fix the night grade came back with it and
	# was applied to a depth image that is meant to be neither graded nor
	# tonemapped.
	hunt._toggle_black_mirror()
	hunt._toggle_black_mirror()
	for _frame in 10:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var depth_raised_again := get_viewport().get_texture().get_image()
	var again_error := depth_raised_again.save_png("%s/black_mirror_depth_raised_again.png" % out_dir)
	print("CAPTURED: " if again_error == OK else "CAPTURE_FAILED: ", "%s/black_mirror_depth_raised_again.png" % out_dir)

	tree.quit(0 if again_error == OK else 1)
