extends Node

const KEYS_CARD := preload("res://systems/keys_card.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var card := KEYS_CARD.new()
	add_child(card)
	card.configure("F1", [
		{"group": "MOVING", "rows": [["WASD", "MOVE"]]},
		{"group": "FIGHTING", "rows": [["LMB", "ATTACK"]]},
		{"group": "HANDS ON", "rows": [["C", "GRAPPLE"]]},
		{"group": "WHAT YOU CARRY", "rows": [["G", "PHONE"]]},
	])
	card.toggle()
	check(card.page_count() == 2, "four control families become two readable leaves")
	var first: Array = card.page_groups()
	check(first.size() == 2 and str(first[0].group) == "MOVING" and str(first[1].group) == "FIGHTING",
		"the first leaf keeps movement and combat together")
	card.change_page(1)
	var second: Array = card.page_groups()
	check(second.size() == 2 and str(second[0].group) == "HANDS ON" and str(second[1].group) == "WHAT YOU CARRY",
		"the second leaf keeps interactions and carried interfaces together")
	card.change_page(1)
	check(card.page == 0, "turning beyond the last leaf wraps without an empty page")
	# Slice 13. The header used to be one fixed sentence everywhere, so the card
	# could not tell you which page of the index you were standing on.
	check(card.subject_line() == "WHAT THIS BODY CAN BE MADE TO DO", "with nothing behind it the card describes itself")
	card.set_reading("WIRE")
	check(card.subject_line() == "READING // WIRE", "the card names the page it is held up over (%s)" % card.subject_line())
	card.set_reading("")
	check(card.subject_line() == "WHAT THIS BODY CAN BE MADE TO DO", "and goes back to describing itself when that page closes")
	card.close()
	var stayed := card.page
	card.change_page(1)
	check(card.page == stayed, "closed help cannot steal page controls from gameplay")
	print("KEYS_CARD_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
