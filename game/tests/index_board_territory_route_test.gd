extends Node

const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func press_pin(index: Control) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_P
	event.pressed = true
	index._unhandled_input(event)


func select_row(index: Control, id: String) -> bool:
	for row_index in index._rail_cache.size():
		if str((index._rail_cache[row_index] as Dictionary).id) == id:
			index.rail_index = row_index
			return true
	return false


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	var bone: Dictionary = HOLDINGS.DEFINITIONS[2]
	HOLDINGS.observe(bone.at)
	var index: Control = hunt.world_index
	index.open()
	check(select_row(index, str(bone.record)), "the revealed holding is selectable in the production INDEX")
	press_pin(index)
	check(hunt.pin_board.is_pinned(str(bone.record)), "P carries the selected holding from INDEX onto the room's actual Board")
	var place_cards: Array = hunt.pin_board.cards.filter(func(card): return card.id == str(bone.record))
	check(place_cards.size() == 1 and place_cards[0].kind == "record", "the input route files land as a record instead of misclassifying it as a human photo")

	index.page = 1
	index._rebuild_rail()
	check(select_row(index, "ashline_wreckers"), "the holding's actual holder is reachable on INDEX's faction page")
	press_pin(index)
	check(hunt.pin_board.is_pinned("ashline_wreckers"), "the same INDEX action pins the holder faction")

	var member_id := ""
	var holder_relations: Dictionary = WorldHistory.subject("ashline_wreckers").get("relations", {})
	for related_id in holder_relations:
		if str(WorldHistory.subject(str(related_id)).get("kind", "")) == "person":
			member_id = str(related_id)
			break
	check(not member_id.is_empty(), "the live holder has at least one real person rather than only a faction label")
	var hosted: Control = hunt.handheld._index
	hosted.open()
	hosted.page = 0
	hosted._rebuild_rail()
	check(select_row(hosted, member_id), "that holder's person is reachable through the Black Mirror's hosted INDEX")
	press_pin(hosted)
	check(hunt.pin_board.is_pinned(member_id), "the hosted INDEX bubbles its pin action to the same physical Board")

	check(hunt.pin_board.lay_string(str(bone.record), "ashline_wreckers"), "the player can string the holding to its recorded holder")
	check(hunt.pin_board.supports(str(bone.record), "ashline_wreckers"), "the place-to-holder string is borne out by canonical territory relations")
	check(hunt.pin_board.lay_string("ashline_wreckers", member_id), "the player can continue the chain from faction to one of its people")
	check(hunt.pin_board.supports("ashline_wreckers", member_id), "the faction-to-person string is borne out by that person's real membership")

	print("INDEX_BOARD_TERRITORY_ROUTE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
