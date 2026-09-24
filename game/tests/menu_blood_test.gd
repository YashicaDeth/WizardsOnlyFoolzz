extends Node

## The menus match the logo: lines type on, and the hovered item gets blood
## poured under it with drips running off.

const MENU := preload("res://country_town_menu.gd")
const BLOOD := preload("res://systems/menu_blood.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	check(MENU.typed("QUIT", 0.0) == "█", "a line starts as a cursor")
	check(MENU.typed("QUIT", 0.5) == "QU█", "and types on")
	check(MENU.typed("QUIT", 1.0) == "QUIT", "and ends as the whole word, no cursor")
	var hud := Control.new()
	hud.size = Vector2(800, 600)
	add_child(hud)
	var button := Button.new()
	button.text = "DEMO"
	button.position = Vector2(50, 100)
	button.size = Vector2(300, 40)
	hud.add_child(button)
	var blood = BLOOD.new()
	hud.add_child(blood)
	blood.point_at(button)
	check(blood.target == button and blood.pour == 0.0, "hovering starts a fresh pour under the item")
	for _step in 20:
		blood.step(0.05)
	check(blood.pour >= 1.0, "the pour runs the item's width")
	check(blood.drips.any(func(drip) -> bool: return float(drip.len) > 5.0), "and drips run off it")
	blood.release(button)
	for _step in 20:
		blood.step(0.05)
	check(blood.fade <= 0.0, "leaving the item lets it fade")
	print("MENU_BLOOD_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
