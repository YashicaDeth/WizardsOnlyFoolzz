extends Node
## Brief: combat keys are rebindable. Rebind DODGE in the pause menu; the
## Hunt's strip shows the new key and pressing it dodges; the old key no
## longer does. Pad keys keep the fixed layout.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	return key


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	var gate := get_node("/root/PauseGate")
	var hud: Node = hunt.find_child("FieldInterface", true, false)
	check(hud != null, "the Hunt's field HUD is found")
	check(hunt._action_key(_key(KEY_SPACE)) == KEY_SPACE, "by default Space is the dodge key")
	gate._apply_rebind("dodge", _key(KEY_C))
	check(hunt._action_key(_key(KEY_C)) == KEY_SPACE, "after rebinding, C reads as the dodge key")
	check(hunt._action_key(_key(KEY_SPACE)) == KEY_NONE, "and Space no longer dodges")
	var offers: Array = hud._current_offers()
	check(offers.any(func(o): return o[0] == "C" and o[1] == "DODGE"), "the strip prints C DODGE: %s" % [offers])
	check(gate._key_label("dodge") == "C", "the pause menu row shows C")
	var pad_space := _key(KEY_SPACE)
	pad_space.device = PadBridgeScript.SYNTHETIC
	check(hunt._action_key(pad_space) == KEY_SPACE, "the pad's Cross still dodges")
	gate._apply_rebind("guard", _key(KEY_V))
	Input.parse_input_event(_key(KEY_V))
	await get_tree().process_frame
	await get_tree().process_frame
	check(Input.is_action_pressed("guard"), "a rebound guard key holds the guard action")
	var up := _key(KEY_V)
	up.pressed = false
	Input.parse_input_event(up)
	gate._reset_keybinds()
	check(hunt._action_key(_key(KEY_SPACE)) == KEY_SPACE, "reset puts Space back")
	print("COMBAT_REBIND_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


const PadBridgeScript := preload("res://systems/pad_bridge.gd")
