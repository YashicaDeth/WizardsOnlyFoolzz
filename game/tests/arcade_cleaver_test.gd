extends Node

## Job 3 in the real route: the HOTLINE CLEAVER taken in the vat room is in
## hand in the Service Arcade, and R1 (a real joypad press through the
## InputMap) cuts the numbered guard through MeleeDriver.

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
	var plain = load("res://service_arcade.tscn").instantiate()
	add_child(plain)
	await get_tree().physics_frame
	check(plain.melee == null, "without the cleaver the arcade arms nothing new (the ram path is unchanged)")
	plain.queue_free()
	await get_tree().process_frame

	var carry := Carry.new()
	carry.items.append({"label": DoctorRoute.AXE_LABEL, "kind": "tool", "mass": 2.4, "perishes": false, "age": 0.0, "from": "vat_chamber"})
	carry.save_to_history()
	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await get_tree().physics_frame
	check(arcade.melee != null and arcade.arsenal.current_id == "cleaver", "a carried HOTLINE CLEAVER is the arcade's melee weapon")
	check(arcade.cleaver_held != null and arcade.cleaver_held.get_parent() == arcade.camera, "and it is in hand, in view")
	var guard: Node3D = arcade.guard_post.guard
	arcade.player.global_position = guard.global_position + Vector3(0, 1.0, 1.35)
	arcade.yaw = 0.0
	arcade.pitch = -0.3
	await _frames(3)
	var before: float = guard.anatomy.snapshot().hash()
	var cuts := 0
	for swing in 3:
		await _button(JOY_BUTTON_RIGHT_SHOULDER)
		await _seconds(0.9)
	cuts = WorldHistory.event_count("facility_guard_cut")
	check(arcade.melee.contacts > 0, "R1 swings the cleaver into the guard (%d contacts)" % arcade.melee.contacts)
	check(cuts > 0, "the guard post records the cleaver's blows (%d)" % cuts)
	check(guard.anatomy.snapshot().hash() != before, "and the guard's body carries the wounds")
	Engine.time_scale = 1.0
	print("ARCADE_CLEAVER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _button(button: JoyButton) -> void:
	var down := InputEventJoypadButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
