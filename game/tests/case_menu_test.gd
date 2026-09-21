extends Node

## The shopfront works without the hunt around it: opens, buys the selected
## box for real scrip, lands the receipt, refuses broke wallets, closes.

const MENU := preload("res://systems/case_menu.gd")
const PURSE := preload("res://systems/carry.gd")

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
	WorldHistory.register_subject("inventory", {"items": [], "rust_scrip": 100})
	var menu: CaseMenu = MENU.new()
	add_child(menu)
	menu.close_requested.connect(_on_close)
	menu.open_menu(PURSE.new(), null)
	check(menu.visible, "the exchange opens")
	check(menu.case_ids().size() == 2, "with two boxes on the shelf")

	menu.handle_input(press(KEY_ENTER))
	# The till takes 25 and the box pays its own winnings straight back, so the
	# wallet reads 75 plus whatever the draw was worth rather than flat 75.
	var gain := 0
	if str(menu.last.get("kind", "")) == "scrip":
		gain = int(menu.last.get("amount", 0))
	elif str(menu.last.get("kind", "")) == "gold":
		gain = 200
	var wallet := int(WorldHistory.subject("inventory").get("rust_scrip", -1))
	check(wallet == 75 + gain, "ENTER buys the 25-scrip cache and lands the winnings (%d left)" % wallet)
	check(bool(menu.last.get("ok", false)) and str(menu.last.get("note", "")) != "", "and the receipt lands with a note (%s)" % str(menu.last.get("note", "")))

	WorldHistory.update_subject("inventory", {"rust_scrip": 0}, "test_drain")
	menu.handle_input(press(KEY_ENTER))
	check(not bool(menu.last.get("ok", true)), "a broke wallet is refused at the till")
	menu.handle_input(press(KEY_U))
	check(closed, "U closes the exchange")

	print("CASE_MENU_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
