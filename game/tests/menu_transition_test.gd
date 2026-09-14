extends Node

## Regression for the playtest crash: Settings stayed interactive during the
## Gore Sandbox load, so three presses could reach the departing menu. This
## verifies that the first request clears and locks the menu, then that the
## subsequent two requests are harmless no-ops.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	# Root is still adding this test during `_ready`; wait one frame before
	# attaching a full scene and making it `current_scene`.
	await tree.process_frame
	var menu := preload("res://country_town_menu.tscn").instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	await tree.process_frame

	menu._open_settings()
	check(menu.settings_panel.visible, "settings opens before departure")
	menu._open_gore_sandbox()
	menu._open_gore_sandbox()
	menu._open_gore_sandbox()

	check(menu.menu_departing, "first sandbox request locks departure")
	check(not menu.settings_panel.visible, "settings is hidden before the loading plate")
	check(menu.settings_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "settings no longer receives pointer input")
	for button: Button in menu.menu_buttons:
		check(button.disabled, "%s is disabled during departure" % button.name)
	for child in menu.settings_panel.get_node("VBox").get_children():
		if child is BaseButton:
			check((child as BaseButton).disabled, "%s is disabled during departure" % child.name)

	# The interstitial starts asynchronously, but the duplicate requests above
	# must not queue a second trip before it gets its first process frame.
	await tree.process_frame
	check(Interstitial.travelling, "one sandbox transition is in flight")
	print("MENU_TRANSITION_TEST_RESULT failures=%d" % failures.size())
	tree.quit(0 if failures.is_empty() else 1)
