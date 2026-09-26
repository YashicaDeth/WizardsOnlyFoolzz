extends Node

## The Brain Index hub (Greg, 2026-09-24): Tab opens it over the Hunt, its
## tabs cycle in his order, and TASKS / MAP hand over to the real surfaces.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(hunt, code: int, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	hunt._unhandled_input(event)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _f in 5:
		await get_tree().physics_frame
	# Greg, 26 September: the inventory is on Tab; the hub moved to Shift+Tab.
	key(hunt, KEY_TAB, true)
	check(hunt.panel_mode == "hub" and hunt.brain_hub.visible, "Shift+Tab opens the Brain Index hub")
	check(BrainIndexHub.TABS == ["CARRY", "COMBAT", "BRAIN INDEX", "TASKS", "MAP"] and hunt.brain_hub.tab == 0, "tabs in Greg's order, opening on CARRY")
	key(hunt, KEY_RIGHT)
	check(hunt.brain_hub.tab == 1, "arrows move between tabs")
	hunt.brain_hub.tab = BrainIndexHub.TABS.find("MAP")
	key(hunt, KEY_ENTER)
	check(hunt.panel_mode == "map" and not hunt.brain_hub.visible, "the MAP tab hands over to the satellite map")
	key(hunt, KEY_TAB, true)
	check(hunt.panel_mode == "hub", "Shift+Tab from the map comes back to the hub")
	key(hunt, KEY_TAB)
	check(hunt.panel_mode == "" and not hunt.brain_hub.visible, "and Tab again closes it")
	print("BRAIN_HUB_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
