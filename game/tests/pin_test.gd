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
	WorldHistory.register_subject("mara_voss", {
	"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain",
	"faction_id": "ashline_wreckers", "injury": "fractured left clavicle",
})
	WorldHistory.register_subject("dolan_kreeg", {"name": "Dolan Kreeg", "kind": "person", "status": "executed", "faction_id": "choir_of_marrow"})
	WorldHistory.register_subject("choir_of_marrow", {"name": "Choir of Marrow", "kind": "faction", "doctrine": "The body is a congregation"})
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
	var pin_event: Dictionary = WorldHistory.events[-1]
	_check(str(pin_event.get("type", "")) == "board_pinned" and str((pin_event.get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "pinning closes with one player-action receipt")
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
	board._commit_move("mara_voss")
	_check(str((WorldHistory.events[-1] as Dictionary).get("type", "")) == "board_card_moved", "releasing a moved card records one gesture rather than every mouse motion")

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
	_check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "board gestures close their shared ledger transaction")

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
	print("L4 - publishing a theory")
	# A theory nothing holds up cannot go out.
	var bare: Dictionary = board.publish("theory_rotation")
	_check(not bool(bare.get("ok", true)), "a theory with no evidence strung to it cannot be published")

	# A sound theory: every string into it is one the world bears out.
	board.pin("part:HEART@mara_voss", "cutting")
	board.pin("mara_voss", "photo")
	board.lay_string("part:HEART@mara_voss", "theory_ownership")
	_check(board.strung_to("theory_ownership").size() > 0, "the theory knows what is holding it up")
	var publications_before := WorldHistory.events.filter(func(event): return str((event as Dictionary).get("type", "")) == "theory_published").size()
	var sound: Dictionary = board.publish("theory_ownership")
	_check(bool(sound.get("ok", false)), "a theory can be published")
	_check(bool(sound.get("sound", false)), "one built only on supported strings is sound")
	_check(str(sound.get("headline", "")).contains("PUBLISHED AGAINST"), "and goes out as an expose: %s" % str(sound.get("headline", "")))
	_check(int(sound.get("exposure", 0)) > 0, "publishing costs exposure")
	_check(int(sound.get("reach", 0)) < 0, "and takes reach off the target")
	_check(board.is_published("theory_ownership"), "the wall remembers it went out")
	var publications_after := WorldHistory.events.filter(func(event): return str((event as Dictionary).get("type", "")) == "theory_published").size()
	_check(publications_after == publications_before + 1, "one publication produces one public outcome, not a duplicate pair")
	_check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "the Wire receipt and board publication close as one transaction")
	_check(not bool(board.publish("theory_ownership").get("ok", true)), "and it cannot go out twice")

	# L4.2 / L4.3. One bad string makes the whole thing a fabrication, and the
	# player had no way of knowing which string that was.
	board.lay_string("dolan_kreeg", "theory_inside")
	board.lay_string("ashline_wreckers", "theory_inside")
	var shaky := false
	for ref in board.strung_to("theory_inside"):
		if not board.supports(str(ref), "theory_inside"):
			shaky = true
	_check(shaky, "at least one string into this theory is not borne out")
	var wrong: Dictionary = board.publish("theory_inside")
	_check(bool(wrong.get("ok", false)), "it publishes anyway, because the player believes it")
	_check(not bool(wrong.get("sound", true)), "but it goes out unsound")
	_check(str(wrong.get("headline", "")) == "FABRICATION PUBLISHED", "as a fabrication: %s" % str(wrong.get("headline", "")))
	_check(int(wrong.get("exposure", 0)) >= 3, "which costs more exposure than the truth did (%d)" % int(wrong.get("exposure", 0)))

	# L4.3. The board never said which it would be.
	_check(not board.strings.any(func(row): return (row as Dictionary).has("sound")), "no string was ever marked sound or unsound")

	# Being right is not the same as being able to prove it.
	WorldHistory.register_subject("quiet_man", {"name": "The Quiet Man", "kind": "person", "role": "Downed at the gate and never named"})
	board.pin("quiet_man", "photo")
	board.lay_string("quiet_man", "theory_absent_god")
	var unprovable: Dictionary = board.publish("theory_absent_god")
	_check(not bool(unprovable.get("ok", true)), "a sound theory about someone you hold nothing on does not go out")
	_check(str(unprovable.get("headline", "")) == "RIGHT, AND YOU CANNOT PROVE IT", "and the game says so in those words")
	_check(not board.is_published("theory_absent_god"), "and it is not on the record")

	var out: Array = board.published()
	_check(out.size() == 2, "both publications are on the record")

	print("")
	print("L5 / L6 - routes, readings and endings")
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person", "injury": "fractured left clavicle"})
	board.load_board()
	board.rebuild()

	# L5.1. Every theory is a route, and the board can say where the player is
	# on each without anything having tracked them.
	var career: Array = board.career()
	_check(career.size() == BOARD.THEORIES.size(), "every theory is a route (%d)" % career.size())
	var fresh_progress := 0.0
	for entry in career:
		fresh_progress += float(entry["progress"])
	_check(is_zero_approx(fresh_progress), "a player who has done nothing is nowhere on any route")

	# Doing the thing the route asks for moves the route, with no quest state in
	# between: the events are the progression.
	WorldHistory.record_event("carried_part", {"subject": "mara_voss", "part": "HEART"})
	var owed: Dictionary = board.route("theory_ownership")
	_check(int(owed["met"]) == 1, "taking a part off a body advances IT IS A DEBT")
	_check(bool((owed["stages"] as Array)[0]["met"]), "and it is the first stage that moved")
	_check(not bool((owed["stages"] as Array)[2]["met"]), "the later stages have not")

	WorldHistory.record_event("carried_part", {"subject": "mara_voss"})
	WorldHistory.record_event("carried_part", {"subject": "mara_voss"})
	_check(int(board.route("theory_ownership")["met"]) >= 2, "three parts is a pattern, and the route knows")

	# L5.2. Nothing anywhere stores what the player is "on".
	var stored: Dictionary = WorldHistory.subject(BOARD.BOARD_ID)
	_check(not stored.has("quests") and not stored.has("active") and not stored.has("route"), "no quest state is stored on the board")
	var recomputed: Dictionary = board.route("theory_ownership")
	_check(int(recomputed["met"]) == int(board.route("theory_ownership")["met"]), "progress is derived the same way every time it is asked for")

	# L6.4. A pre-placed theory reads differently once the player has acted.
	var before_reading: String = board.reading_of("theory_absent_god")
	for _kill in 3:
		WorldHistory.record_event("execution", {"subject": "mara_voss"})
	var after_reading: String = board.reading_of("theory_absent_god")
	_check(before_reading != after_reading, "a theory reads differently after three executions")
	_check(after_reading.contains("THREE"), "and it says so in its own voice: %s" % after_reading.split("
")[0])
	for _more in 4:
		WorldHistory.record_event("execution", {"subject": "mara_voss"})
	_check(board.reading_of("theory_absent_god").contains("SEVEN"), "and again at seven")
	board.rebuild()
	for card in board.cards:
		if card.id == "theory_absent_god":
			_check(str(card.body).contains("SEVEN"), "the card on the wall shows the current reading")

	# L6.2. Walked to the end and made to stand up in public is an ending.
	for _down in 3:
		WorldHistory.record_event("npc_resolution", {"subject": "mara_voss"})
	var walked: Dictionary = board.route("theory_absent_god")
	_check(int(walked["met"]) == int(walked["total"]), "every stage of HE IS NOT LISTENING is met")
	_check(not bool(walked["ending"]), "but walking it is not an ending on its own")
	_check(board.endings_reached().is_empty(), "and no ending has been reached")
	# Strung to an execution the player actually carried out, because that is
	# what this theory says would bear it out. Mara stays on the wall as the
	# person it is about.
	var execution_ref := ""
	for index in WorldHistory.events.size():
		if str((WorldHistory.events[index] as Dictionary).get("type", "")) == "execution":
			execution_ref = "event:%d" % index
			break
	board.pin("mara_voss", "photo")
	board.pin(execution_ref, "cutting")
	board.lay_string(execution_ref, "theory_absent_god")
	var went_out: Dictionary = board.publish("theory_absent_god")
	_check(bool(went_out.get("ok", false)) and bool(went_out.get("sound", false)), "it publishes, and soundly")
	_check(bool(board.route("theory_absent_god")["ending"]), "a route walked to the end and published sound IS an ending")
	_check(board.endings_reached().has("theory_absent_god"), "and the game knows which ending was reached")
	_check(board.endings_reached().size() == 1, "only the route the player actually carried")

	print("")
	if failures.is_empty():
		print("L2 + L3 + L4 + L5 + L6 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
