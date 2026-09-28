extends Node
## Greg: PlayStation pad. Buttons arrive as the keys the game already reads.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _press(button: JoyButton, pressed: bool) -> void:
	var pad := InputEventJoypadButton.new()
	pad.button_index = button
	pad.pressed = pressed
	Input.parse_input_event(pad)
	await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	check(get_node_or_null("/root/PadBridge") != null, "the pad bridge is loaded in every scene")
	await _press(JOY_BUTTON_X, true)
	check(Input.is_key_pressed(KEY_E), "Square is E (use)")
	await _press(JOY_BUTTON_X, false)
	check(not Input.is_key_pressed(KEY_E), "and lets go")
	await _press(JOY_BUTTON_DPAD_LEFT, true)
	check(Input.is_key_pressed(KEY_4), "D-pad left holds 4 (dress a wound)")
	await _press(JOY_BUTTON_DPAD_LEFT, false)
	var events := InputMap.action_get_events("move_forward")
	check(events.any(func(e): return e is InputEventJoypadMotion), "the left stick moves you")
	print("PAD_BRIDGE_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
