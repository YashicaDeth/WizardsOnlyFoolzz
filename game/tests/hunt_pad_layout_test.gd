extends Node

## Round 10: the production Hunt consumes semantic Souls-layer verbs, not raw
## shoulder numbers. Synthetic joy events take the same autoload route as a
## connected PS4/PS5 pad.

var failures: Array[String] = []
var hunt: Node


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _button(index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _axis(index: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _press(index: JoyButton) -> void:
	await _button(index, true)
	await _button(index, false)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bridge := get_node("/root/PadBridge")

	# Melee: R1 light, R2 heavy, L1 block, L2 parry.
	hunt._equip_weapon(0)
	hunt._sync_pad_combat_context()
	hunt.arsenal.cooldown = 0.0
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	check(not hunt.pending_attack.is_empty() and not bool(hunt.pending_attack.get("heavy", false)), "Hunt R1 starts a light melee attack")
	hunt.pending_attack = {}
	hunt.strike_windup = -1.0
	hunt.arsenal.cooldown = 0.0
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(not hunt.pending_attack.is_empty() and bool(hunt.pending_attack.get("heavy", false)), "Hunt R2 starts a heavy melee attack")
	await _button(JOY_BUTTON_LEFT_SHOULDER, true)
	check(hunt.pad_block_held, "Hunt L1 holds block")
	await _button(JOY_BUTTON_LEFT_SHOULDER, false)
	check(not hunt.pad_block_held, "Hunt L1 release lowers block")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	check(hunt.pad_parry_held and hunt.guard_raised == 0.0, "Hunt L2 raises a fresh parry window")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	check(not hunt.pad_parry_held, "Hunt L2 release lowers parry")

	# Firearm exception: only R2 fires and L2 aims.
	hunt.pending_attack = {}
	hunt.strike_windup = -1.0
	hunt._equip_weapon(2)
	hunt._sync_pad_combat_context()
	hunt.arsenal.cooldown = 0.0
	var shots_before: int = hunt._shot_counter
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	check(hunt._shot_counter == shots_before, "Hunt R1 does not become a second firearm trigger")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	check(hunt.firearm_aiming, "Hunt firearm L2 aims")
	await _axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	check(not hunt.firearm_aiming, "Hunt firearm L2 release lowers aim")
	hunt.arsenal.cooldown = 0.0
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(hunt._shot_counter == shots_before + 1, "Hunt firearm R2 fires exactly once")

	# The existing aimed X-ray chord remains layered above aim + fire.
	hunt.arsenal.cooldown = 0.0
	await _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	check(hunt._vats_chord_pending, "L2+R2 is held for the aimed X-ray / VATS chord")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	check(bridge.combat_glyph("light", "melee") == "R1" and bridge.combat_glyph("fire", "firearm") == "R2", "Hunt HUD glyphs come from the same active layer")

	print("HUNT_PAD_LAYOUT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
