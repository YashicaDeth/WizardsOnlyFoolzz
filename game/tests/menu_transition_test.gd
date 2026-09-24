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
	var requests: Array[Dictionary] = []
	menu.travel_request_override = func(scene_path: String, caption: String) -> void:
		requests.append({"scene": scene_path, "caption": caption})
	check(WorldLook.quality_name() == "PERFORMANCE" and is_equal_approx(get_viewport().scaling_3d_scale, 0.75),
		"a cold menu starts on the safe measured graphics contract")
	check(menu.render_scales.max() == 1.0 and menu.render_scales.min() == 0.67,
		"render-scale choices cannot accidentally supersample fullscreen")
	check(menu.get_node("HUD/SettingsPanel/VBox/Resolution").text.contains("75%"),
		"the settings label tells the truth about the active render scale")

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

	check(requests.size() == 1, "three presses request exactly one sandbox transition")
	check(str(requests[0].scene) == "res://gore_demo.tscn", "sandbox is the requested destination")
	print("MENU_TRANSITION_TEST_RESULT failures=%d" % failures.size())
	tree.quit(0 if failures.is_empty() else 1)
