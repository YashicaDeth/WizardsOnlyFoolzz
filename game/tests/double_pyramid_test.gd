extends Node

## AI1. "Two pyramids meeting at a point. Upright above, inverted below."
##
## `_strongest_ladder_faction()` is the one piece of this that is pure data
## and needs no rendering context, so it is what gets a real headless
## pass/fail suite; `_tier_rects` (which cone actually put what on screen)
## only exists once a real draw has happened and is checked by the windowed
## capture alongside this instead, the same split `index_substrate_test.gd`
## already draws between what headless can and cannot verify here.

const WORLD_INDEX := preload("res://systems/world_index.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	var index: Control = WORLD_INDEX.new()
	add_child(index)
	await get_tree().process_frame
	index.open()

	print("AI2.1/AI2.3 - which faction populates a cone is read, not authored")
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "relations": {}})
	_check(index._strongest_ladder_faction(["ashline_wreckers", "black_mile"]) == "", "no commitment to either side reads as nothing claimed, not a default pick")

	WorldHistory.update_subject("player", {"relations": {
		"ashline_wreckers": {"kind": "command", "strength": 30},
		"black_mile": {"kind": "command", "strength": 80},
	}})
	_check(index._strongest_ladder_faction(["ashline_wreckers", "black_mile"]) == "black_mile", "the stronger of two real relations wins, not the first one listed")

	WorldHistory.update_subject("player", {"relations": {
		"ashline_wreckers": {"kind": "grudge", "strength": 99},
		"black_mile": {"kind": "command", "strength": 5},
	}})
	_check(index._strongest_ladder_faction(["ashline_wreckers", "black_mile"]) == "black_mile", "a grudge is not real standing - only INFLUENCE_KINDS count, the same rule the Wire already prices reach by")

	print("AI2.1 - a faction with no real members at all is still a real read, not a crash")
	WorldHistory.register_subject("empty_cult", {"name": "Empty Cult", "kind": "faction"})
	_check(not index.wire.pyramid("empty_cult").is_empty(), "an empty faction still returns a real, drawable pyramid shape rather than nothing")

	print("DOUBLE_PYRAMID_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
