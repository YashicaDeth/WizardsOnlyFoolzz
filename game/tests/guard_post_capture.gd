extends Node

## Visual proof for AX route beat 5: Hollis at the D-section door as the
## player first sees him, up close with the ram, and the door after coercion.
## Run windowed: ... res://tests/guard_post_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	# Only this script moves the arcade, so a slow renderer's catch-up
	# physics ticks cannot walk the scene past the frame being captured.
	arcade.set_physics_process(false)
	var post: FacilityGuardPost = arcade.guard_post
	arcade.player.global_position = Vector3(0.6, 1.0, post.global_position.z + 9.0)
	await _hold(30)
	await _capture("%s/guard_post_approach.png" % out_dir)

	arcade.weapon_taken = true
	LabSurface.hold_in_view(arcade.camera, arcade.weapon_visual)
	arcade.weapon_label.visible = false
	arcade.player.global_position = post.guard.global_position + Vector3(-0.4, 1.0, 1.9)
	arcade.yaw = 0.18
	arcade._physics_process(1.0 / 30.0)
	await _hold(20)
	await _capture("%s/guard_post_close.png" % out_dir)

	arcade._interact()
	for _frame in 40:
		arcade._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	arcade.player.global_position = Vector3(-0.6, 1.0, post.global_position.z + 5.5)
	arcade.yaw = 0.0
	arcade._physics_process(1.0 / 30.0)
	await _hold(10)
	await _capture("%s/guard_post_opened.png" % out_dir)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
