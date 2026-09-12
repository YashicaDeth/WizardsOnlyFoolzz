extends Node

## L2 verification, behavioural rather than visual: the board is a model before
## it is a wall, and the model is what has to be right. Runs headless, because
## nothing here depends on anything being painted.

const BOARD := preload("res://systems/pin_board.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain"})
	WorldHistory.register_subject("dolan_kreeg", {"name": "Dolan Kreeg", "kind": "person", "status": "executed"})
	WorldHistory.register_subject("ashline_wreckers", {"name": "Ashline Wreckers", "kind": "faction", "doctrine": "Rank is won by remembered impact"})
	WorldHistory.record_event("derby_round_won", {"subject": "player"})

	var layer := CanvasLayer.new()
	add_child(layer)
	var board: Control = BOARD.new()
	layer.add_child(board)
	await get_tree().process_frame

	print("L2 - pinning")
	board.load_board()
	board.rebuild()

	# L2.3. A new wall is not blank and it is not full: the authored theories
	# were already up, and exactly one card is the player's.
	_check(board.pinned.size() == 1, "a new board has exactly one pinned card")
	_check(board.is_pinned("player"), "and that card is the player")
	_check(not board.is_pinned("mara_voss"), "somebody the player has met is NOT auto-pinned")
	var theory_count := 0
	for card in board.cards:
		if card.kind == "theory":
			theory_count += 1
	_check(theory_count == BOARD.THEORIES.size(), "every authored theory is up (%d)" % theory_count)

	# L2.1. The player puts it up themselves.
	_check(board.pin("mara_voss", "photo"), "a subject can be pinned")
	_check(board.is_pinned("mara_voss"), "and it stays pinned")
	_check(not board.pin("mara_voss", "photo"), "the same thing cannot be pinned twice")
	_check(board.pin("ashline_wreckers", "record"), "a faction can be pinned")
	_check(board.pin("event:0", "cutting"), "an event can be pinned as a cutting")
	_check(board.pin("part:HEART@mara_voss", "cutting"), "a carried part can be pinned with its provenance")

	board.rebuild()
	var by_id: Dictionary = {}
	for card in board.cards:
		by_id[card.id] = card
	_check(by_id.has("mara_voss") and by_id["mara_voss"].kind == "photo", "a person draws as a photograph")
	_check(by_id.has("ashline_wreckers") and by_id["ashline_wreckers"].kind == "record", "a faction draws as a filed record")
	_check(by_id.has("event:0") and by_id["event:0"].kind == "cutting", "an event draws as a cutting")
	_check(by_id.has("part:HEART@mara_voss") and str(by_id["part:HEART@mara_voss"].body).contains("MARA"), "a pinned part names whose it was")

	# Somebody finished is crossed out, wherever the card came from.
	board.pin("dolan_kreeg", "photo")
	board.rebuild()
	for card in board.cards:
		if card.id == "dolan_kreeg":
			_check(card.struck, "an executed subject is crossed out")

	# Moving a card is the player rearranging their own argument.
	var before: Vector2 = board.pinned[1]["at"]
	board.move_card("mara_voss", Vector2(40, -25))
	_check((board.pinned[1]["at"] as Vector2).is_equal_approx(before + Vector2(40, -25)), "a card can be moved by hand")

	# Taking something down.
	_check(board.unpin("event:0"), "a pinned card can be taken down")
	_check(not board.is_pinned("event:0"), "and it is gone")
	_check(not board.unpin("theory_ownership"), "an authored theory is not the player's to remove")

	# The wall persists, because it is a thing in a room rather than a view.
	var saved: int = board.pinned.size()
	board.save_board()
	board.pinned.clear()
	board.load_board()
	_check(board.pinned.size() == saved, "the wall survives a reload (%d cards)" % saved)
	_check(board.is_pinned("mara_voss"), "and remembers what was on it")

	# Held in the hand, placed by clicking the wall.
	board.hold("dolan_kreeg", "photo", "DOLAN KREEG")
	_check(not board.holding.is_empty(), "something can be held on its way to the wall")
	board.unpin("dolan_kreeg")
	_check(board.drop_held(Vector2(120, -80)), "and dropped where the player clicked")
	_check(board.holding.is_empty(), "the hand is empty afterwards")
	for entry in board.pinned:
		if str(entry["ref"]) == "dolan_kreeg":
			_check((entry["at"] as Vector2).is_equal_approx(Vector2(120, -80)), "it landed exactly where it was dropped")

	# Cards do not land on top of each other.
	var clear := true
	for a in board.pinned:
		for b in board.pinned:
			if a == b:
				continue
			if ((a["at"] as Vector2) - (b["at"] as Vector2)).length() < 40.0:
				clear = false
	_check(clear, "auto-placed cards do not stack on each other")

	print("")
	print("L3 - strings are claims")
	board.pin("mara_voss", "photo")
	board.pin("ashline_wreckers", "record")
	board.pin("event:0", "cutting")
	board.pin("part:HEART@mara_voss", "cutting")

	# L3.1. A connection between two things that are actually on the wall.
	_check(board.lay_string("mara_voss", "ashline_wreckers"), "a string can be laid between two pinned cards")
	_check(not board.lay_string("mara_voss", "ashline_wreckers"), "the same string cannot be laid twice")
	_check(not board.lay_string("ashline_wreckers", "mara_voss"), "nor the same string backwards")
	_check(not board.lay_string("mara_voss", "mara_voss"), "a card cannot be strung to itself")
	_check(not board.lay_string("mara_voss", "sil_fenmark"), "nothing can be strung to a card that is not up")

	# L3.2. The world bears some of these out and not others.
	_check(board.supports("mara_voss", "ashline_wreckers"), "a captain and her own faction is supported")
	_check(board.supports("part:HEART@mara_voss", "theory_ownership"), "a carried part supports IT IS A DEBT")
	_check(not board.supports("ashline_wreckers", "theory_frequency"), "a road syndicate does not support THE SIGNAL IS THE PRAYER")
	_check(not board.supports("mara_voss", "dolan_kreeg"), "two people who never met are not connected")

	# L3.2. Supported strings open work; unsupported ones do not.
	var leads_before: int = board.leads().size()
	board.lay_string("part:HEART@mara_voss", "theory_ownership")
	_check(board.leads().size() == leads_before + 1, "a supported string opens a lead")
	var leads_after: int = board.leads().size()
	board.lay_string("ashline_wreckers", "theory_frequency")
	_check(board.leads().size() == leads_after, "an unsupported string opens nothing")

	# L3.3. The one that matters: the board must not give it away.
	board.rebuild()
	var true_thread: Dictionary = {}
	var false_thread: Dictionary = {}
	for thread in board.threads:
		if str(thread["from"]) == "part:HEART@mara_voss":
			true_thread = thread
		if str(thread["from"]) == "ashline_wreckers" and str(thread["to"]) == "theory_frequency":
			false_thread = thread
	_check(not true_thread.is_empty() and not false_thread.is_empty(), "both strings are on the wall")
	_check(true_thread.keys() == false_thread.keys(), "a false string carries no field a true one does not")
	_check(not true_thread.has("supported") and not false_thread.has("supported"), "nothing drawn knows whether it is true")

	# L3.4. The ledger knows, because the ledger is the record of what happened.
	var recorded := false
	for event in WorldHistory.events:
		if str(event.get("type", "")) == "board_string_drawn" and str((event.get("details", {}) as Dictionary).get("target", "")) == "theory_frequency":
			recorded = true
			_check(not bool((event.get("details", {}) as Dictionary).get("supported", true)), "the ledger records the wrong claim as unsupported")
	_check(recorded, "drawing a string is recorded as something the player did")

	# Cutting, and cards taking their strings down with them.
	_check(board.cut_string("mara_voss", "ashline_wreckers"), "a string can be cut")
	var before_unpin: int = board.strings.size()
	board.unpin("part:HEART@mara_voss")
	_check(board.strings.size() < before_unpin, "taking a card down takes its strings with it")

	# Strings persist with the wall.
	var kept: int = board.strings.size()
	board.save_board()
	board.strings.clear()
	board.load_board()
	_check(board.strings.size() == kept, "strings survive a reload (%d)" % kept)

	print("")
	if failures.is_empty():
		print("L2 + L3 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
