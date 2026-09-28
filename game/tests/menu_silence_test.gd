extends Node

## The front door is deliberately silent: no player is built under the menu
## and no sound is played by hovering, settings, or the periodic logo tear.

var failures: Array[String] = []
var built: Array[String] = []
var heard: Dictionary = {}
var menu: Node


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.update_subject("settings", {"violence_acknowledged": ""}, "test_setup")
	get_tree().node_added.connect(_on_node_added)
	menu = load("res://country_town_menu.tscn").instantiate()
	add_child(menu)
	await _listen(30)
	for button: Button in menu.menu_buttons:
		menu._focus_button(button)
		await _listen(8)
		menu._unfocus_button(button)
	menu._open_settings()
	await _listen(10)
	menu._close_settings()
	menu.ui_time = menu.TITLE_GLITCH_EVERY * 2.0 - 0.05
	await _listen(40)
	check(built.is_empty(), "the front door builds no sound players %s" % [built])
	check(heard.is_empty(), "nothing plays while the front door is up %s" % [heard.keys()])
	print("MENU_SILENCE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _on_node_added(node: Node) -> void:
	if _is_player(node) and menu != null and menu.is_ancestor_of(node):
		built.append(str(node.name))


func _listen(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame
		for node in get_tree().root.find_children("*", "", true, false):
			if _is_player(node) and node.playing:
				heard[str(node.get_path())] = true


func _is_player(node: Node) -> bool:
	return node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D
