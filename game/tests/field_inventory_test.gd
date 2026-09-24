extends Node

## AG5.30. Loot is reachable as inventory without navigating the surveillance
## phone, and selection operates on the exact shared Carry object.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.handheld.carry.take_chunk({"layer_name": "skin", "zone": "torso", "subject_id": "inventory_probe"})
	hunt.handheld.carry.take_chunk({"layer_name": "limb", "whole_limb": true, "zone": "left_arm", "subject_id": "inventory_probe"})

	print("AG5.30 - O reaches the actual bag without raising the phone")
	hunt._unhandled_input(key(KEY_O))
	check(hunt.panel_mode == "inventory" and hunt.field_inventory.visible, "O opens the direct field inventory")
	check(not hunt.handheld.is_open, "the Black Mirror stays pocketed")
	check(hunt.field_inventory.carry == hunt.handheld.carry, "field and phone expose the same Carry instance")
	check(hunt.field_inventory.body == hunt.player_rig and hunt.field_inventory.arsenal == hunt.arsenal, "the screen reads the live body and weapons rather than copied display data")

	print("AG5.30 - navigation changes real pocket/equipment state")
	hunt.field_inventory.handle_input(key(KEY_P))
	check(bool((hunt.handheld.carry.items[0] as Dictionary).get("pocketed", false)), "P pockets the selected small item through Carry's capacity rules")
	hunt.field_inventory.handle_input(key(KEY_DOWN))
	check(hunt.field_inventory.selected == 1, "down selects the next exact object")
	hunt.field_inventory.handle_input(key(KEY_ENTER))
	check(hunt.panel_mode.is_empty() and not hunt.field_inventory.visible, "activating a wieldable object returns to play")
	check(hunt.carried_limb_index == 1 and hunt.carried_limb_model != null, "the selected limb—not merely the first available item—is wielded")

	hunt._unhandled_input(key(KEY_O))
	check(hunt._close_active_interface() and hunt.panel_mode.is_empty() and not hunt.field_inventory.visible, "the universal interface close lowers inventory cleanly")
	print("FIELD_INVENTORY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
