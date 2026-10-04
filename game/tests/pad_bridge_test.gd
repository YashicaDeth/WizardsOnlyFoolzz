extends Node
## Greg: PlayStation pad. Buttons arrive as the keys the game already reads.

const CombatLayer := preload("res://systems/combat_input_layer.gd")

var failures := 0
var combat_events: Array[String] = []


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _press(button: JoyButton, pressed: bool) -> void:
	var pad := InputEventJoypadButton.new()
	pad.button_index = button
	pad.pressed = pressed
	Input.parse_input_event(pad)
	await get_tree().process_frame


func _trigger(axis: JoyAxis, value: float) -> void:
	var pad := InputEventJoypadMotion.new()
	pad.axis = axis
	pad.axis_value = value
	Input.parse_input_event(pad)
	await get_tree().process_frame
	await get_tree().process_frame


func _pad_combat_verb(verb: String, pressed: bool) -> void:
	combat_events.append("%s:%s" % [verb, "down" if pressed else "up"])
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
	for action in CombatLayer.PHYSICAL_ACTIONS:
		var native_events := InputMap.action_get_events(action)
		check(native_events.any(func(e): return e is InputEventJoypadButton or e is InputEventJoypadMotion), "%s has a native joypad binding" % action)
	bridge.set_combat_receiver(self)
	bridge.set_combat_context("melee")
	await _press(JOY_BUTTON_RIGHT_SHOULDER, true)
	await _press(JOY_BUTTON_RIGHT_SHOULDER, false)
	check(combat_events.slice(-2) == ["light:down", "light:up"], "R1 resolves through the Souls layer as light: %s" % [combat_events])
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(combat_events.slice(-2) == ["heavy:down", "heavy:up"], "R2 resolves through the Souls layer as heavy")
	await _press(JOY_BUTTON_LEFT_SHOULDER, true)
	await _press(JOY_BUTTON_LEFT_SHOULDER, false)
	check(combat_events.slice(-2) == ["block:down", "block:up"], "L1 resolves through the Souls layer as block")
	await _trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _trigger(JOY_AXIS_TRIGGER_LEFT, 0.0)
	check(combat_events.slice(-2) == ["parry:down", "parry:up"], "L2 resolves through the Souls layer as parry")
	bridge.set_combat_context("firearm")
	await _trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _trigger(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(combat_events.slice(-4) == ["aim:down", "aim:up", "fire:down", "fire:up"], "firearm context maps L2 aim and R2 fire")
	bridge.set_combat_context("melee")
	bridge.set_combat_layer("test_discipline", {"melee": {CombatLayer.R1: "special"}})
	await _press(JOY_BUTTON_RIGHT_SHOULDER, true)
	bridge.reset_combat_layer()
	check(combat_events.slice(-2) == ["special:down", "special:up"], "a discipline override releases its old verb during a mid-input swap")
	check(bridge.using_pad, "a pad press switches prompts to the pad")
	check(bridge.keys("WASD MOVE   //   MOUSE LOOK   //   E INTERACT   //   HOLD I INSPECT") == "L-STICK MOVE   //   R-STICK LOOK   //   SQUARE INTERACT   //   HOLD D-RIGHT INSPECT", "prompt keys become buttons: " + bridge.keys("WASD MOVE   //   MOUSE LOOK   //   E INTERACT   //   HOLD I INSPECT"))
	check(bridge.keys("MOUSE LOOK   //   FIND THE WIRES   //   4 LEFT").ends_with("4 LEFT"), "a count is not a key")
	check(bridge.keys("K WIZARD EYES   //   HOLD J DEPTH SCAN") == "D-UP WIZARD EYES   //   HOLD D-DOWN DEPTH SCAN", "wizard eyes stay on D-pad up now that L1 blocks")
	check(bridge.hint("LMB", "LIGHT ATTACK", "melee") == "R1", "combat hints read the active layer")
	check(bridge.hint("LMB", "FIRE", "firearm") == "R2", "firearm hints use R2 instead of the melee button")
	check(bridge.hint("Q", "AIMED X-RAY / VATS", "firearm") == "L2 + R2", "VATS keeps the squeezed trigger chord")
	var gate := get_node("/root/PauseGate")
	gate.page = "controls"
	gate._build_rows()
	var control_values: Array = gate._rows.map(func(row: Dictionary) -> String: return "%s:%s" % [row.label, row.value])
	check(control_values.has("R1:LIGHT") and control_values.has("R2:HEAVY / FIREARM FIRE") and control_values.has("L1:BLOCK") and control_values.has("L2:PARRY / FIREARM AIM"), "the pad controls screen shows the Souls base: %s" % [control_values])
	check(control_values.has("L2 + R2:AIMED X-RAY / VATS"), "the pad controls screen teaches the VATS chord")
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
	bridge.clear_combat_receiver(self)
	bridge.reset_combat_layer()
	print("PAD_BRIDGE_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
