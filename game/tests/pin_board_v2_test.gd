extends Node

## L v2 verification, behavioural rather than visual (board_capture.gd already
## covers the look of it). L2.6: the wall now has a real capacity. L3.5: a
## string that held up a since-fabricated theory is flagged as disproved
## when the board rebuilds. L1.5: a straight line that would cut through a
## pinned card gets a real, nonzero detour; one with nothing in its way does
## not.

const BOARD := preload("res://systems/pin_board.gd")

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
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain", "faction_id": "ashline_wreckers"})
	WorldHistory.register_subject("ashline_wreckers", {"name": "Ashline Wreckers", "kind": "faction", "doctrine": "Rank is won by remembered impact"})
	WorldHistory.record_event("faction_post_vacated", {"subject": "ashline_wreckers"})

	var layer := CanvasLayer.new()
	add_child(layer)
	var board: Control = BOARD.new()
	layer.add_child(board)
	await get_tree().process_frame
	board.load_board()
	board.rebuild()

	print("L2.6 v2 - the wall has a real capacity")
	for index in BOARD.MAX_PINNED - 1:
		# The player card already used one slot on a fresh board.
		WorldHistory.register_subject("filler_%d" % index, {"name": "Filler %d" % index, "kind": "person"})
		_check(board.pin("filler_%d" % index, "photo"), "slot %d takes a pin" % index)
	_check(board.pinned.size() == BOARD.MAX_PINNED, "the wall is now at its stated capacity (%d)" % board.pinned.size())
	WorldHistory.register_subject("one_too_many", {"name": "One Too Many", "kind": "person"})
	_check(not board.pin("one_too_many", "photo"), "a pin past capacity is refused")
	_check(not board.last_refusal.is_empty(), "and the refusal says why (%s)" % board.last_refusal)
	_check(board.unpin("filler_0"), "taking one down frees a slot")
	_check(board.pin("one_too_many", "photo"), "which the refused pin can now take")

	print("L3.5 v2 - a disproved string is flagged")
	# The wall is still at capacity from the section above — free some room
	# rather than letting a stale-full wall silently swallow the next pin.
	for index in range(1, 20):
		board.unpin("filler_%d" % index)
	board.pin("mara_voss", "photo")
	# theory_rotation's supported_by is ["faction", "rank", "command"]; mara_voss
	# describes as a person with a faction_id, which contains none of those
	# tokens literally, so this comes back a fabrication once published.
	board.lay_string("mara_voss", "theory_rotation")
	board.publish("theory_rotation")
	board.rebuild()
	var found_disproved := false
	for thread: Dictionary in board.threads:
		if str(thread["from"]) == "mara_voss" or str(thread["to"]) == "mara_voss":
			found_disproved = bool(thread.get("disproved", false))
	_check(found_disproved, "the string into the fabricated theory is marked disproved after rebuild")

	board.pin("player", "photo")
	board.lay_string("player", "theory_absent_god")
	board.rebuild()
	var control_marked := false
	for thread: Dictionary in board.threads:
		if str(thread["from"]) == "player" and str(thread["to"]) == "theory_absent_god":
			control_marked = bool(thread.get("disproved", false))
	_check(not control_marked, "a string into a theory that was never published is not marked disproved")

	print("L1.5 v2 - strings route around what is in their way")
	var clear_detour: Vector2 = board._thread_detour(Vector2(-2000, 0), Vector2(2000, 0))
	_check(clear_detour == Vector2.ZERO, "a line with nothing pinned near it gets no detour")
	# `_to_screen()` is the identity transform here — the board has never been
	# drawn, so `_board_rect` is still zero-sized, `pan` is zero and `zoom` is
	# 1.0 — so a card pinned at board position (640, 360) sits at screen
	# position (640, 360) too, squarely on the line this checks.
	WorldHistory.register_subject("blocker_target", {"name": "Blocker", "kind": "person"})
	board.pin("blocker_target", "photo", Vector2(640, 360))
	board.rebuild()
	var blocked_detour: Vector2 = board._thread_detour(Vector2(0, 360), Vector2(1280, 360))
	_check(blocked_detour.length() > 1.0, "a line straight through a pinned card gets a real detour (%.1f)" % blocked_detour.length())

	print("L4.4 v2 - a published theory can be retracted")
	_check(board.is_published("theory_rotation"), "theory_rotation is still on the record from the section above")
	var bad_retract: Dictionary = board.retract("theory_absent_god")
	_check(not bool(bad_retract.get("ok", true)), "retracting a theory that was never published is refused")
	var retract_result: Dictionary = board.retract("theory_rotation")
	_check(bool(retract_result.get("ok", false)), "retracting a published theory succeeds (%s)" % str(retract_result.get("detail", "")))
	_check(not board.is_published("theory_rotation"), "the retracted theory is no longer published")
	_check(int(retract_result.get("exposure", 0)) > 0 and int(retract_result.get("grudge", 0)) > 0, "walking it back costs real exposure and grudge, not nothing")
	# mara_voss is still pinned and still strung to theory_rotation from the
	# L3.5 section above — retract() only pulled the publish record, not the
	# string, so the same evidence can carry a second publish.
	var republish: Dictionary = board.publish("theory_rotation")
	_check(bool(republish.get("ok", false)), "a retracted theory can be published again on the same evidence")

	print("L1.6 v2 - the board ages when the player has been away")
	# Establishes today's event count as the baseline first — the test has
	# already recorded events above just setting up its own fixtures, and
	# measuring neglect against no prior visit at all is a different question
	# (answered by the "first ever open" case below) from measuring it
	# against a real gap since the player was last actually in the room.
	board.open()
	_check(is_equal_approx(board.neglect, 0.0), "opening the board for the first time is not itself neglect")
	for index in 40:
		WorldHistory.record_event("test_filler_event", {})
	board.open()
	_check(board.neglect > 0.0, "a real gap in world events since the last visit reads as neglect (%.3f)" % board.neglect)
	board.open()
	_check(is_equal_approx(board.neglect, 0.0), "opening again immediately resets it rather than compounding")

	print("L_V2_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
