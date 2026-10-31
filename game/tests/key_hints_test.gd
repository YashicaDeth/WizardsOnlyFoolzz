extends Node

## Greg, 28 September: each new key shown once, big, bottom centre, gone when
## used, never again. Checked in the real vat room.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var hints: KeyHints = vat.key_hints
	vat._on_hack_finished(false)
	await get_tree().process_frame
	check(hints._panel.visible and hints._key.text == "K", "after the hack, K is offered first (%s)" % hints._key.text)
	var bottom: float = hints._panel.position.y + hints._panel.size.y
	check(bottom > vat.get_viewport().get_visible_rect().size.y * 0.6, "bottom of the screen")
	press(KEY_K)
	await get_tree().process_frame
	await get_tree().process_frame
	check(hints._key.text == "HOLD J", "pressing K clears it and J comes next")
	press(KEY_J)
	await get_tree().process_frame
	check(KeyHints.seen("wizard_eyes") and KeyHints.seen("depth_scan"), "both are remembered as seen")
	hints.offer("wizard_eyes", KEY_K, "K", "wizard eyes")
	await get_tree().process_frame
	check(not hints._panel.visible, "a seen hint never comes back")
	vat.key_hints.offer("use", KEY_E, "E", "use")
	await get_tree().process_frame
	hints.age = hints.HOLD_SECONDS
	await get_tree().process_frame
	await get_tree().process_frame
	check(not hints._panel.visible and KeyHints.seen("use"), "an unused hint still goes after a while")
	print("KEY_HINTS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
