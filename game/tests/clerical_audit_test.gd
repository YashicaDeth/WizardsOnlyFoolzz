extends Node

## D2.4 v2. CLERICAL ERROR was structurally undiscoverable: `_mistranscribe()`
## overwrote one field with a wrong value and threw the true one away in the
## same statement, so nothing anywhere could ever have compared the sheet to
## what the player actually said, at any cost. This proves the true value
## survives, that it takes a real Wire lookup (AUDIT, +1 exposure) to see it
## rather than being free, and that the World Index actually surfaces both
## states.

const SHEET := preload("res://systems/character_sheet.gd")
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

	print("D2.4 v2 - the true value survives the mistranscription")
	var sheet: CharacterSheet = SHEET.new()
	sheet.display_name = "TEST SUBJECT"
	sheet.traits.append("clerical_error")
	var state: Dictionary = sheet.apply_to_world()
	var clerical: Dictionary = state.get("clerical_error", {})
	_check(not clerical.is_empty(), "apply_to_world() records which field went wrong and what it really was")
	_check(not bool(clerical.get("discovered", false)), "and it starts undiscovered - the wrong sheet is all a normal read shows")
	_check(clerical.get("true_value", null) != null, "the true value itself is a real, held value, not thrown away")

	print("D2.4 v2 - finding out costs a real Wire lookup")
	var index: Control = WORLD_INDEX.new()
	add_child(index)
	await get_tree().process_frame
	index.size = Vector2(1280, 720)
	index.open()
	index._jump_to_subject("player")
	index._process(0.05)
	var audit_link := {}
	for link: Dictionary in index._link_rects:
		if str(link.get("kind", "")) == "audit":
			audit_link = link
	_check(not audit_link.is_empty(), "the dossier offers a real, clickable AUDIT link while it is undiscovered")
	var exposure_before: int = index.wire.exposure
	index._follow_link(audit_link)
	_check(index.wire.exposure > exposure_before, "following it actually costs exposure, not a free tooltip (%d -> %d)" % [exposure_before, index.wire.exposure])
	var after: Dictionary = WorldHistory.subject("player").get("clerical_error", {})
	_check(bool(after.get("discovered", false)), "and the record is marked discovered afterward")

	index._process(0.05)
	var audit_link_after := {}
	for link: Dictionary in index._link_rects:
		if str(link.get("kind", "")) == "audit":
			audit_link_after = link
	_check(audit_link_after.is_empty(), "once discovered, the AUDIT link is gone - there is nothing left to look up")

	print("CLERICAL_AUDIT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
