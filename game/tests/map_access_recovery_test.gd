extends Node

const FACILITY := preload("res://systems/facility_territory.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	FACILITY.apply_event("opening_woke")
	FACILITY.apply_event("opening_entered_pit")
	await get_tree().process_frame
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 35:
		await get_tree().process_frame
	hunt._toggle_panel("map")
	for _open in 4:
		await get_tree().process_frame
	var map: Control = hunt.living_map
	check(hunt.panel_mode == "map" and map.visible and not map.facility_sheet,
		"M opens on the surface satellite, the view Greg wants first")
	check(hunt._pointer.visible,
		"the full map raises its moving custom pointer instead of an aiming reticle")
	hunt.black_mirror_active = false
	hunt._unhandled_input(_key(KEY_L))
	check(map.facility_sheet and not hunt.black_mirror_active and hunt.panel_mode == "map",
		"L changes to the underground facility layer without activating the black-and-white field lens")
	hunt._unhandled_input(_key(KEY_L))
	await get_tree().process_frame
	check(not map.facility_sheet, "L changes back to the surface satellite")
	# Clicking a rendered sector selects it and keeps the pointer free. This is
	# the exact interaction the narrated playtest reported as doing nothing.
	# Headless CanvasItems do not execute `_draw`, so publish the same hit rect a
	# rendered sector produces and drive the production pointer resolver.
	map._facility_rects = [{"index": 0, "rect": Rect2(Vector2(120, 90), Vector2(144, 76)).grow(8.0)}]
	var target: Rect2 = (map._facility_rects[0] as Dictionary).rect
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = target.get_center()
	map._gui_input(click)
	check(map.facility_selected == 0, "clicking a sector selects the sector under the pointer")
	# Even if a synthetic click reaches the field fallback, an open map must not
	# reinterpret it as firing or change the interface owner.
	var ammo_before: Dictionary = hunt.arsenal.state()
	hunt._unhandled_input(click)
	check(hunt.panel_mode == "map" and hunt.arsenal.state() == ammo_before,
		"a map click cannot fall through into weapon input")
	print("MAP_ACCESS_RECOVERY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
