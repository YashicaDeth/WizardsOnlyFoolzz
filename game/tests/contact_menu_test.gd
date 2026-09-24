extends Node

## The contact surface proves three things: people list, the sealed stay
## sealed, and reaching reports the index's answer rather than inventing one.
## All rules belong to BrainIndex; this file draws.

const MENU := preload("res://systems/contact_menu.gd")
const INDEX := preload("res://systems/brain_index.gd")

var failures: Array[String] = []
var closed := false


func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)


func _on_close() -> void:
	closed = true


func press(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var menu: ContactMenu = MENU.new()
	add_child(menu)
	menu.close_requested.connect(_on_close)
	menu.open_menu()
	check(menu.visible, "the contact surface opens")

	var people: Array = INDEX.listing("people")
	check(not people.is_empty(), "people are filed (%d rows)" % people.size())
	var entities: Array = INDEX.listing("entities")
	check(not entities.is_empty(), "entities are filed (%d rows)" % entities.size())
	var sealed := 0
	for row: Dictionary in people:
		if not bool(row.get("open", true)):
			sealed += 1
	check(sealed > 0, "and the unremembered stay sealed (%d of %d)" % [sealed, people.size()])

	# Reach the top row and report whatever the index says — body or refusal,
	# never silence and never invention.
	menu.handle_input(press(KEY_ENTER))
	check(not menu.reading.is_empty(), "reaching answers, one way or another")
	if bool(menu.reading.get("ok", false)):
		check(str(menu.reading.get("body", "")) != "", "an open row reads its body")
	else:
		check(str(menu.reading.get("reason", "")) != "", "a sealed row answers its refusal")

	menu.handle_input(press(KEY_RIGHT))
	check(menu.folder == 1, "RIGHT moves to entities")
	menu.handle_input(press(KEY_F8))
	check(closed, "F8 closes the surface")

	print("CONTACT_MENU_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
