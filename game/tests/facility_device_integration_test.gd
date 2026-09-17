extends Node

const FACILITY := preload("res://systems/facility_territory.gd")
const MAP := preload("res://systems/living_map.gd")
const INDEX := preload("res://systems/world_index.gd")
const DEVICE := preload("res://systems/handheld_device.gd")

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
	FACILITY.apply_event("opening_woke")
	FACILITY.apply_event("opening_entered_pit")
	FACILITY.apply_event("derby_round_won")

	var map := MAP.new()
	map.size = Vector2(960, 540)
	add_child(map)
	map.observe(Vector3(31, 0, -77), 0.0)
	map.open_map()
	await get_tree().process_frame
	check(map.facility_sheet, "MAP defaults to the facility sheet after the opening route exists")
	check(map.facility_selected >= 0, "MAP selects a revealed holding")
	var first := map.facility_selected
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	map._gui_input(right)
	check(map.facility_selected != first, "arrow input moves between revealed facility holdings")
	var layer := InputEventKey.new()
	layer.keycode = KEY_L
	layer.pressed = true
	map._gui_input(layer)
	check(not map.facility_sheet, "L returns to the Ashbloom satellite sheet")
	var target_area := FACILITY.target_area()
	check(not target_area.is_empty() and Vector2(float(target_area.x), float(target_area.z)) != map.player_at,
		"opening the corporate MAP publishes only the carrier's approximate area")

	var index := INDEX.new()
	index.size = Vector2(960, 540)
	add_child(index)
	index.open()
	var found_record := false
	for row: Dictionary in index._rail_cache:
		if str(row.id) == "facility:underground_colosseum":
			found_record = true
	check(found_record, "the liberated holding is a selectable World INDEX file")

	var device := DEVICE.new()
	device.size = Vector2(960, 540)
	add_child(device)
	device.load_device()
	check(device.current_mode() == "MAP", "a new post-escape Black Mirror defaults to MAP")
	device.set_mode("INDEX")
	device._advance_page_transition(device.PAGE_TRANSITION_SECONDS)
	device.save_device()
	device.queue_free()
	await get_tree().process_frame
	var reloaded := DEVICE.new()
	reloaded.size = Vector2(960, 540)
	add_child(reloaded)
	reloaded.load_device()
	check(reloaded.current_mode() == "INDEX", "the Black Mirror remembers the player's chosen page")

	print("FACILITY_DEVICE_INTEGRATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
