extends Node

## AR1 / AV1. `sephiroth.gd`'s data is meant to be shared by more than one
## panel (this page, and whatever AV1.1's plane ladder eventually is), so
## its own shape is worth checking on its own — a broken path list or a
## sephirah placed off the 0..1 canvas breaks every future reader of it, not
## just this one. `_sephirah_reached()` is the one piece of the TREE page
## that is pure data and needs no rendering context, matching the split
## `double_pyramid_test.gd` already draws for the pyramid page.

const SEPHIROTH := preload("res://systems/sephiroth.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")
const WIRE_NET := preload("res://systems/wire_net.gd")

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

	print("AR1/AV1 - the shared tree data is the tradition's own shape")
	_check(SEPHIROTH.ORDER.size() == 10, "ten sephiroth counted, Da'ath excluded from the count")
	_check(SEPHIROTH.node_ids().size() == 11, "eleven nodes drawn - the ten plus Da'ath")
	_check(SEPHIROTH.PATHS.size() == 22, "twenty-two paths, the tradition's own count")
	var touches_daath := false
	for path in SEPHIROTH.PATHS:
		if path[0] == "daath" or path[1] == "daath":
			touches_daath = true
	_check(not touches_daath, "Da'ath is unmapped - no path in the list reaches it (AV1.3)")
	for node_id in SEPHIROTH.node_ids():
		_check(SEPHIROTH.NAMES.has(node_id), "%s has a real name, not a raw id" % node_id)
		_check(SEPHIROTH.POSITIONS.has(node_id), "%s has a real position" % node_id)
		var position: Vector2 = SEPHIROTH.POSITIONS[node_id]
		_check(position.x >= 0.0 and position.x <= 1.0 and position.y >= 0.0 and position.y <= 1.0, "%s sits inside the normalized canvas" % node_id)
	for path in SEPHIROTH.PATHS:
		_check(SEPHIROTH.POSITIONS.has(path[0]) and SEPHIROTH.POSITIONS.has(path[1]), "path %s references two real nodes" % [path])
	_check(SEPHIROTH.is_countable("malkuth") and not SEPHIROTH.is_countable("daath"), "is_countable() agrees with the ten/Da'ath split")

	print("AR1/AV1 - what is 'reached' comes from real standing, not an invented beat")
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "relations": {}})
	var index: Control = WORLD_INDEX.new()
	add_child(index)
	await get_tree().process_frame

	_check(index._sephirah_reached("malkuth", "", "") == true, "Malkuth always reads reached - it is where the player already stands")
	_check(index._sephirah_reached("keter", "", "") == false, "Keter never reads reached - past reach is past reach, not a difficulty slider")
	_check(index._sephirah_reached("daath", "black_mile", "ashline_wreckers") == false, "and neither does giving Da'ath a faction it does not have - it stays dark regardless")
	_check(index._sephirah_reached("tiferet", "", "") == false, "Tiferet is dark with no real commitment on either ladder")
	_check(index._sephirah_reached("tiferet", "black_mile", "") == true, "...and lights the moment either ladder has one")
	_check(index._sephirah_reached("hod", "", "") == false, "a leaning sephirah with no real relation stays dark")

	WorldHistory.update_subject("player", {"relations": {
		"choir_of_marrow": {"kind": "grudge", "strength": 99},
	}})
	_check(index._sephirah_reached("hod", "", "") == false, "a grudge is not real standing here either - only INFLUENCE_KINDS count, same rule the pyramid already uses")

	WorldHistory.update_subject("player", {"relations": {
		"choir_of_marrow": {"kind": "command", "strength": 40},
	}})
	_check(index._sephirah_reached("hod", "", "") == true, "real influence over the leaning faction lights it")
	_check(index._sephirah_reached("netzach", "", "") == true, "...and lights every sephirah sharing that same lean, not just one")
	_check(index._sephirah_reached("gevurah", "", "") == false, "but not an unrelated one with no relation of its own")

	print("SEPHIROTH_TREE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
