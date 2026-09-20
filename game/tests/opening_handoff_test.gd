extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var opening = load("res://vat_chamber.tscn").instantiate()
	add_child(opening)
	await get_tree().physics_frame
	var file := InputEventKey.new()
	file.keycode = KEY_F
	file.pressed = true
	opening.intake._unhandled_input(file)
	var elapsed := 0.0
	while not opening.can_move and elapsed < 12.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	check(opening.can_move and elapsed < 9.0, "filing reaches free movement within nine seconds on the live route")
	var handoff_height: float = opening.camera.global_position.y
	var lowest := handoff_height
	var start: Vector3 = opening.player.position
	Input.action_press("move_forward")
	for frame in 120:
		await get_tree().physics_frame
		lowest = minf(lowest, opening.camera.global_position.y)
	Input.action_release("move_forward")
	check(handoff_height - lowest < 0.12, "standing eye does not fall when physics takes over (drop %.3fm)" % (handoff_height - lowest))
	check(absf(opening.camera.global_position.y - 1.62) < 0.12, "first steps retain standing eye height")
	check(opening.player.position.z < start.z - 3.0 and opening.player.is_on_floor(), "first movement walks forward on the grating")
	check(opening.breakout_complete and opening.first_acquisition_complete, "breakout and existing restraint acquisition survive the handoff")
	check(opening.get_node("HUD/Objective").text.contains("ESCAPE THE FACILITY"), "escape purpose remains visible during the first steps")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK, "live first-step capture saved")
	print("OPENING_HANDOFF_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
