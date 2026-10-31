extends Node

## bughunt-79: START's input chooser is the first thing every run passes
## through and every other suite skips it (ATG_TEST_MODE). It must be opaque,
## keep the pad inside its three choices, close on Circle/Escape, and start the
## run from either choice.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# The chooser only opens outside test mode.
	OS.set_environment("ATG_TEST_MODE", "0")
	var menu: Node = load("res://country_town_menu.tscn").instantiate()
	# The menu is the current scene, as in the game, so its travel replaces it
	# and not this test.
	get_tree().root.add_child.call_deferred(menu)
	await get_tree().process_frame
	get_tree().current_scene = menu
	for _frame in 6:
		await get_tree().process_frame
	var card := menu.get_node_or_null("HUD/WarningCard")
	if card != null:
		card.hide()
	menu.call("_start_demo")
	await get_tree().process_frame
	var chooser: Control = menu.get_node_or_null("HUD/InputChooser")
	check(chooser != null, "START opens the input chooser")
	if chooser == null:
		_finish()
		return
	var plate := chooser.get_theme_stylebox("panel")
	check(plate is StyleBoxFlat and (plate as StyleBoxFlat).bg_color.a > 0.9, "its plate is opaque over the menu column")
	var focus := get_viewport().gui_get_focus_owner()
	check(focus is Button and chooser.is_ancestor_of(focus), "focus lands on a choice")
	# Walk the d-pad down past BACK: it wraps to the first choice, never the
	# menu behind.
	var stayed := true
	for _step in 5:
		_press("ui_down")
		await get_tree().process_frame
		var owner := get_viewport().gui_get_focus_owner()
		stayed = stayed and owner != null and chooser.is_ancestor_of(owner)
	check(stayed, "the d-pad stays inside the three choices")
	_press("ui_cancel")
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(chooser) or chooser.is_queued_for_deletion(), "Circle / Escape closes it")
	check(get_viewport().gui_get_focus_owner() == menu.get_node("HUD/Play"), "and focus is back on the demo door")
	check(not bool(menu.get("menu_departing")), "closing it starts nothing")
	menu.call("_start_demo")
	await get_tree().process_frame
	chooser = menu.get_node_or_null("HUD/InputChooser")
	var keyboard: Button = null
	for button in chooser.find_children("*", "Button", true, false):
		if (button as Button).text.begins_with("KEYBOARD"):
			keyboard = button
	check(keyboard != null, "it reopens with KEYBOARD + MOUSE")
	if keyboard != null:
		keyboard.emit_signal("pressed")
		await get_tree().process_frame
		check(bool(menu.get("menu_departing")), "choosing starts the run")
		check(not bool(get_node("/root/PadBridge").using_pad), "and the choice is kept")
		# Let the travel finish rather than quitting under a threaded load.
		var waited := 0.0
		while waited < 60.0 and not _in_vat():
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
		check(_in_vat(), "and the run arrives in the vat")
	_finish()


func _in_vat() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == "res://vat_chamber.tscn"


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _finish() -> void:
	OS.set_environment("ATG_TEST_MODE", "1")
	print("MENU_INPUT_CHOOSER_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
