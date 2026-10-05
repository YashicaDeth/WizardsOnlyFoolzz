extends Node

## Fix-58 in the Service Arcade: the numbered guard on the floor, R1 / LMB in
## reach finishes him with the HOTLINE CLEAVER or the breach ram, the beat
## always ends with him dead and recorded, and Square / X (USE) still drags
## his hand to the reader afterwards. Before, a downed guard could only be
## dragged, and the pad could not USE anything in the arcade.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await _case("cleaver", false)
	await _case("cleaver", true)
	await _case("ram", true)
	await _no_weapon()
	Engine.time_scale = 1.0
	print("ARCADE_EXECUTION_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _arcade(with_cleaver: bool, with_ram: bool) -> Node:
	WorldHistory.clear_history()
	if with_cleaver:
		var carry := Carry.new()
		carry.items.append({"label": DoctorRoute.AXE_LABEL, "kind": "tool", "mass": 2.4, "perishes": false, "age": 0.0, "from": "vat_chamber"})
		carry.save_to_history()
	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await _frames(2)
	if with_ram:
		arcade.weapon_on_floor = false
		arcade.weapon_taken = true
		arcade._hold_ram()
	var guard: BaselineHuman = arcade.guard_post.guard
	guard.hit("left_leg", 30.0, 4.0, "cut")
	guard.anatomy.go_down()
	arcade.player.global_position = guard.global_position + Vector3(0, 1.0, 1.6)
	arcade.player.velocity = Vector3.ZERO
	arcade.yaw = 0.0
	arcade.pitch = -0.3
	await _frames(3)
	return arcade


func _case(weapon: String, pad: bool) -> void:
	var arcade := await _arcade(weapon == "cleaver", weapon == "ram")
	var guard: BaselineHuman = arcade.guard_post.guard
	var tag := "%s%s" % [weapon, " (pad)" if pad else ""]
	check(guard.is_downed(), "%s: the guard is on the floor" % tag)
	check(arcade.prompt.text.contains("EXECUTE"), "%s: the prompt offers EXECUTE (%s)" % [tag, arcade.prompt.text])
	if pad:
		await _button(JOY_BUTTON_RIGHT_SHOULDER)
	else:
		await _action("attack")
	check(arcade.execution != null and (arcade.execution.active or guard.anatomy.dead), "%s: R1 / LMB starts the finisher" % tag)
	if arcade.execution == null:
		arcade.queue_free()
		await _frames(2)
		return
	check(arcade.execution.style_id == weapon, "%s: with the weapon in hand (%s)" % [tag, arcade.execution.style_id])
	var waited := 0.0
	while arcade.execution.active and waited < 4.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(not arcade.execution.active and str(arcade.execution.report.get("reason", "")) == "done", "%s: the beat completes (%.2fs)" % [tag, waited])
	check(guard.anatomy.dead, "%s: he is dead" % tag)
	check(WorldHistory.event_count("facility_guard_executed") == 1, "%s: the execution is recorded once" % tag)
	check(str(WorldHistory.subject(arcade.guard_post.guard_id).get("status", "")) == "dead", "%s: and his record says dead" % tag)
	var stand: float = Vector2(arcade.player.global_position.x - arcade.execution.stand_at.x, arcade.player.global_position.z - arcade.execution.stand_at.z).length()
	check(stand < 0.4, "%s: the player is at the finisher's spot (%.2f m off)" % [tag, stand])
	check(absf(wrapf(arcade.yaw - arcade.execution.view_yaw, -PI, PI)) < 0.35, "%s: facing him" % tag)
	check(is_equal_approx(Engine.time_scale, 1.0), "%s: time runs at 1 afterwards" % tag)
	check(guard.rotation.x < -1.2, "%s: he lies where he was finished" % tag)
	# USE still answers, on the pad too: his hand to the reader opens the door.
	arcade.player.global_position = guard.global_position + Vector3(0, 1.0, 1.6)
	await _frames(2)
	if pad:
		await _button(JOY_BUTTON_X)
	else:
		await _action("interact")
	check(arcade.guard_post.door_open, "%s: USE drags his hand to the reader afterwards" % tag)
	var before: Vector3 = arcade.player.global_position
	Input.action_press("move_back")
	await _frames(12)
	Input.action_release("move_back")
	check(arcade.player.global_position.distance_to(before) > 0.05, "%s: you can walk away" % tag)
	arcade.queue_free()
	await _frames(2)


## Bare-handed there is no finisher here: the press does what it always did.
func _no_weapon() -> void:
	var arcade := await _arcade(false, false)
	await _action("attack")
	check(arcade.execution == null or not arcade.execution.active, "no weapon: no finisher starts")
	check(arcade.guard_post.guard.is_downed(), "no weapon: he stays down, alive")
	arcade.queue_free()
	await _frames(2)


func _action(action: String) -> void:
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
		await _frames(1)


func _button(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
		await _frames(1)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame
