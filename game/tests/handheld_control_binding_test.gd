extends Node

## C1.7 regression: physical drop and deliberate re-decant were both on K,
## allowing one press in captivity to perform two irreversible actions.

const HANDHELD := preload("res://systems/handheld_device.gd")
const HUNT := preload("res://bone_yard_hunt.tscn")

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
	check(HANDHELD.DROP_KEY == KEY_DELETE, "dropping the device uses the dedicated Delete key")
	check(HANDHELD.DROP_KEY != KEY_K, "drop no longer shares the irreversible re-decant binding")

	var device := HANDHELD.new()
	add_child(device)
	device.load_device()
	device.open_device()
	device._tab_rects = device.tab_layout(Rect2(Vector2(80, 40), Vector2(1128, 640)))
	check(device.mouse_filter == Control.MOUSE_FILTER_STOP and device._tab_rects.size() == device.MODES.size(),
		"raising the device exposes one clickable region for every drawn app tab")
	var ritual_tab: Rect2 = device._tab_rects[5]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = ritual_tab.get_center()
	device._gui_input(click)
	check(device.current_mode() == "RITUAL", "clicking a drawn tab selects that exact device app")
	device.close_device()
	check(device.mouse_filter == Control.MOUSE_FILTER_IGNORE, "lowered hardware releases the pointer back to the game")
	device.queue_free()

	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().process_frame
	var g_key := InputEventKey.new()
	g_key.keycode = KEY_G
	g_key.pressed = true
	hunt._unhandled_input(g_key)
	check(hunt.handheld.is_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"G raises the Black Mirror and releases the pointer for its controls")
	var f7_key := InputEventKey.new()
	f7_key.keycode = KEY_F7
	f7_key.pressed = true
	hunt._unhandled_input(f7_key)
	check(hunt.handheld.current_mode() == "FIELD", "F7 reaches the seventh advertised app directly")
	var escape_key := InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.pressed = true
	hunt._unhandled_input(escape_key)
	# The headless display refuses MOUSE_MODE_CAPTURED and reports VISIBLE even
	# after the production assignment; the close itself is still testable here.
	var pointer_returned := DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	check(not hunt.handheld.is_open and pointer_returned,
		"Escape lowers the raised Black Mirror and returns control to play")
	var map_key := InputEventKey.new()
	map_key.keycode = KEY_M
	map_key.pressed = true
	hunt._unhandled_input(map_key)
	check(hunt.panel_mode == "map" and hunt.living_map.visible and not hunt.handheld.is_open,
		"M opens the full map as the one active major interface")
	hunt._unhandled_input(g_key)
	check(hunt.handheld.is_open and hunt.panel_mode.is_empty() and not hunt.living_map.visible,
		"G pockets the full map before raising the Black Mirror")
	hunt._unhandled_input(map_key)
	check(not hunt.handheld.is_open and hunt.panel_mode == "map" and hunt.living_map.visible,
		"opening a full panel lowers the Black Mirror instead of drawing underneath it")
	hunt._unhandled_input(escape_key)
	check(hunt.panel_mode.is_empty() and not hunt.living_map.visible,
		"Escape closes the active full-size interface in one step")
	var j_key := InputEventKey.new()
	j_key.keycode = KEY_J
	j_key.pressed = true
	hunt._unhandled_input(j_key)
	check(hunt.allusions_artwork.visible and hunt.panel_mode == "artwork" and hunt.get_node_or_null("HUD/NatalSigil") == null,
		"J opens the interactive artwork without constructing placeholder birth data")
	hunt._unhandled_input(j_key)
	check(not hunt.allusions_artwork.visible and hunt.panel_mode.is_empty(),
		"a second J press returns directly to play rather than cycling into a natal chart")
	hunt._unhandled_input(g_key)
	hunt._unhandled_input(j_key)
	check(not hunt.handheld.is_open and hunt.allusions_artwork.visible and hunt.panel_mode == "artwork",
		"J lowers the Black Mirror before opening the artwork")
	hunt._unhandled_input(g_key)
	check(hunt.handheld.is_open and not hunt.allusions_artwork.visible and hunt.panel_mode.is_empty(),
		"G closes the artwork before raising the Black Mirror")
	hunt._unhandled_input(escape_key)
	var pause_gate := get_node_or_null("/root/PauseGate")
	if pause_gate != null:
		pause_gate.close()
		hunt._toggle_handheld_surface()
		Input.parse_input_event(escape_key)
		await get_tree().process_frame
		check(not hunt.handheld.is_open and not pause_gate.open,
			"a dispatched Escape lowers the phone without also opening PauseGate")
		Input.parse_input_event(escape_key)
		await get_tree().process_frame
		check(pause_gate.open, "a bare dispatched Escape still opens PauseGate")
		pause_gate.close()
	var rows: Array = []
	for group: Dictionary in hunt.keys_card.groups:
		rows.append_array(group.get("rows", []))
	check(rows.any(func(row: Array): return row[0] == HANDHELD.DROP_KEY_LABEL and row[1] == "DROP DEVICE"), "the in-world keys card teaches the new drop binding")
	check(rows.any(func(row: Array): return row[0] == "CLICK / F1-F7" and row[1] == "SELECT DEVICE APP"), "the keys card teaches pointer and direct app selection")
	check(rows.any(func(row: Array): return row[0] == "TAB" and "NEXT DEVICE APP" in row[1]), "the keys card explains Tab's raised-device meaning")
	check(rows.any(func(row: Array): return row[0] == "J" and row[1] == "ALLUSIONS ARTWORK"),
		"the keys card names J's surviving artwork action without promising a sigil")
	check(rows.any(func(row: Array): return row[0] == "K" and "RE-DECANT" in row[1]), "K remains honestly labelled for its one surviving action")
	check(rows.filter(func(row: Array): return row[0] == "K").size() == 1, "the card contains no second hidden K action")

	print("HANDHELD_CONTROL_BINDING_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
