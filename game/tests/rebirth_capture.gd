extends Node

## Visual proof for death as vat rebirth: Hollis's warning shot, the regrown
## body waking in the tank, and the old body in the arcade.
## Run windowed: ... res://tests/rebirth_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "loose"})

	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	arcade.set_physics_process(false)
	arcade.player.global_position = arcade.WEAPON_AT
	arcade._interact()
	arcade.player.global_position = arcade.CARD_AT
	arcade._interact()
	var post: FacilityGuardPost = arcade.guard_post
	arcade.player.global_position = post.guard.global_position + Vector3(-0.8, 1.0, 6.0)
	arcade._physics_process(1.0 / 30.0)
	await _hold(12)
	await _capture("%s/rebirth_warning_shot.png" % out_dir)
	while not arcade.died:
		post.fire_cooldown = 0.0
		arcade._physics_process(1.0 / 30.0)
	arcade.queue_free()
	await _hold(2)

	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	vat.set_physics_process(false)
	for _frame in 30:
		vat._physics_process(1.0 / 30.0)
		await get_tree().process_frame
	await _capture("%s/rebirth_regrown_tank.png" % out_dir)
	vat.clock = 5.7
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	vat.queue_free()
	await _hold(2)

	arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	arcade.set_physics_process(false)
	var body: Node3D = arcade.remains_nodes.values()[0][0]
	arcade.player.global_position = body.global_position + Vector3(0.4, 1.0, 2.6)
	arcade.pitch = -0.35
	arcade._physics_process(1.0 / 30.0)
	await _hold(12)
	await _capture("%s/rebirth_old_body.png" % out_dir)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
