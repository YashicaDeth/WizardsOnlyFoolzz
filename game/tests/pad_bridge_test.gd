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
	var bridge := get_node("/root/PadBridge")
	check(bridge.using_pad, "a pad press switches prompts to the pad")
	check(bridge.keys("WASD MOVE   //   MOUSE LOOK   //   E INTERACT   //   HOLD I INSPECT") == "L-STICK MOVE   //   R-STICK LOOK   //   SQUARE INTERACT   //   HOLD D-RIGHT INSPECT", "prompt keys become buttons: " + bridge.keys("WASD MOVE   //   MOUSE LOOK   //   E INTERACT   //   HOLD I INSPECT"))
	check(bridge.keys("MOUSE LOOK   //   FIND THE WIRES   //   4 LEFT").ends_with("4 LEFT"), "a count is not a key")
	var label := Label.new()
	add_child(label)
	label.text = "E INTERACT   //   HOLD 4 DRESS"
	await get_tree().process_frame
	check(label.text == "SQUARE INTERACT   //   HOLD D-LEFT DRESS", "a prompt label on screen shows buttons: " + label.text)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not bridge.using_pad, "a real key press switches back to the keyboard")
	check(label.text == "E INTERACT   //   HOLD 4 DRESS", "and the label shows keys again: " + label.text)
	key.pressed = false
	Input.parse_input_event(key)
	print("PAD_BRIDGE_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
