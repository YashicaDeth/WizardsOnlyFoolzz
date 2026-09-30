extends Node

## Greg, 30 September: a PS4 pad on the sandbox, Dark Souls / Bloodborne
## layout; over the shoulder Shift (or O held) runs and SPACE dodges, no jump.
## Driven by synthetic pad events, since the pad itself cannot be in a test.

var failures: Array[String] = []
var demo


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _button(index: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = demo.pad.device
	event.button_index = index
	event.pressed = down
	# Through the real input path only: the pad hears it the way it would
	# hear the controller.
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = demo.pad.device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _press(index: JoyButton) -> void:
	_button(index, true)
	_button(index, false)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await _frames(3)
	demo.arsenal.select_slot(HunterArsenal.SLOT_ORDER.find("sword"))

	# --- Touchpad: over the shoulder. ---
	_press(JOY_BUTTON_TOUCHPAD)
	check(demo.third_person, "the touchpad switches to third person")
	await _frames(60)

	# --- Sticks. ---
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(2)
	var push: Vector3 = demo._sandbox_move_input()
	var ahead := Vector3(-sin(demo.yaw), 0.0, -cos(demo.yaw))
	check(push.dot(ahead) > 0.95, "left stick up walks forward")
	_axis(JOY_AXIS_LEFT_Y, -0.1)
	await _frames(2)
	check(demo._sandbox_move_input().length() < 0.01, "a stick inside the deadzone does nothing")
	var yaw_before: float = demo.yaw
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(20)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	check(demo.yaw < yaw_before - 0.3, "right stick turns the camera (%.2f rad)" % (yaw_before - demo.yaw))

	# --- Jog, and O held sprints and spends stamina. ---
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	demo.stamina = 100.0
	await _frames(30)
	var jog: float = Vector2(demo.walk.x, demo.walk.z).length()
	check(absf(jog - demo.JOG_SPEED) < 0.3, "third person walks at a jog (%.1f m/s)" % jog)
	_button(JOY_BUTTON_B, true)
	await _frames(40)
	var run: float = Vector2(demo.walk.x, demo.walk.z).length()
	check(demo.pad.sprinting and absf(run - demo.SPRINT_SPEED) < 0.4, "O held sprints (%.1f m/s)" % run)
	check(demo.stamina < 95.0, "and the sprint spends stamina (%.0f)" % demo.stamina)
	_button(JOY_BUTTON_B, false)
	check(not demo.roll.is_rolling(), "letting go of a sprint does not roll")
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(40)

	# --- O tapped: a roll; with nothing pushed, a backstep. ---
	demo.stamina = 100.0
	var facing := Vector3(-sin(demo.avatar.facing_yaw), 0.0, -cos(demo.avatar.facing_yaw))
	_press(JOY_BUTTON_B)
	check(demo.roll.is_rolling() and demo.roll.direction().dot(facing) < -0.9, "O tapped with nothing pushed backsteps")
	await _frames(60)

	# --- SPACE over the shoulder never jumps. ---
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	demo.stamina = 100.0
	demo._unhandled_input(key)
	check(not demo.jump_queued and demo.vertical_velocity == 0.0 and demo.roll.is_rolling(), "SPACE in third person backsteps, it does not jump")
	await _frames(60)

	# --- R1 light, R2 heavy; an attack turns to the stick. ---
	demo.stamina = 100.0
	demo.moveset.reset()
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(2)
	_press(JOY_BUTTON_RIGHT_SHOULDER)
	var to_stick: Vector3 = demo._sandbox_move_input().normalized()
	var faced := Vector3(-sin(demo.avatar.facing_yaw), 0.0, -cos(demo.avatar.facing_yaw))
	check(demo.moveset.current_attack() == "light_1", "R1 is the light")
	check(faced.dot(to_stick) > 0.95, "and the blow turns to where the stick pushes")
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(90)
	demo.stamina = 100.0
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(2)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(demo.moveset.current_attack() == "heavy", "R2 is the heavy")
	await _frames(120)

	# --- L1 guards, L2 parries, R3 locks, cross takes, d-pad changes weapon. ---
	_button(JOY_BUTTON_LEFT_SHOULDER, true)
	check(demo.guarding, "L1 held raises the guard")
	_button(JOY_BUTTON_LEFT_SHOULDER, false)
	check(not demo.guarding, "and lowers it")
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(2)
	check(demo.guarding and demo.guard_held < 0.1, "L2 raises a fresh guard: the parry window")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _frames(2)
	check(not demo.guarding, "and L2 let go lowers it")
	demo.yaw = atan2(-(demo.bodies[0].holder.global_position.x - demo.eye.x), -(demo.bodies[0].holder.global_position.z - demo.eye.z))
	await _frames(30)
	_press(JOY_BUTTON_RIGHT_STICK)
	check(demo.avatar.lock_target != null, "R3 locks on")
	_press(JOY_BUTTON_RIGHT_STICK)
	check(demo.avatar.lock_target == null, "and R3 again releases")
	var weapon_before: String = demo.arsenal.current_id
	_press(JOY_BUTTON_DPAD_RIGHT)
	check(demo.arsenal.current_id != weapon_before, "d-pad right changes weapon (%s -> %s)" % [weapon_before, demo.arsenal.current_id])
	_press(JOY_BUTTON_DPAD_UP)
	check(not demo.duel_mode, "d-pad up switches duel / pack")
	_press(JOY_BUTTON_START)
	check(demo.enemies_enabled, "options turns the enemies on")

	# --- One PS4 pad seen twice (raw + emulated Xbox): each press counts once. ---
	await _frames(90)
	demo.stamina = 100.0
	demo.moveset.reset()
	var lights := [0]
	demo.pad.light.connect(func() -> void: lights[0] += 1)
	var twin: int = demo.pad.device + 1
	for id in [demo.pad.device, twin]:
		var event := InputEventJoypadButton.new()
		event.device = id
		event.button_index = JOY_BUTTON_RIGHT_SHOULDER
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	check(lights[0] == 1, "a press arriving from the raw pad and its Xbox twin counts once (%d)" % lights[0])

	print("SOULS_PAD_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
