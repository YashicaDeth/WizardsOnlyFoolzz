extends Node

## L6.3 v2 / L6.5 v2 verification.
##
## L6.3: leads have opened since L3.2 but nothing ever read them as clusters,
## so every sideline looked like an isolated dead end rather than its own
## thing — and there was no way to tell "its own cluster" apart from "a
## smaller mainline" mechanically. `sideline_clusters()` groups `leads()` by
## the graph that was always implicit in them; this proves a cluster that
## never touches a theory (a pure side story) and one that touches two
## different mainlines both come out correctly, rather than either being
## forced to resolve into a single story.
##
## L6.5: "no converging on one dungeon" is a content claim about the five
## mainlines, checked here rather than asserted — the five THEORIES'
## `supported_by` vocabularies never overlap (so no two mainlines are ever
## satisfied by the same evidence), their final ROUTES stage never shares an
## event type with another mainline's final stage (so no single act closes
## two routes at once), and the map the `map_travel`-gated stages read
## against has more than one named place for them to happen in.

const BOARD := preload("res://systems/pin_board.gd")
const LIVING_MAP := preload("res://systems/living_map.gd")

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

	var layer := CanvasLayer.new()
	add_child(layer)
	var board: Control = BOARD.new()
	layer.add_child(board)
	await get_tree().process_frame
	board.load_board()
	board.rebuild()

	print("L6.3 v2 - sidelines are their own clusters, not smaller mainlines")
	# A pure sideline: two people connected only to each other, never strung
	# to a theory at all.
	WorldHistory.register_subject("side_witness", {"name": "A Witness", "kind": "person"})
	WorldHistory.register_subject("side_fixer", {"name": "A Fixer", "kind": "person"})
	WorldHistory.record_event("saw_together", {"first": "side_witness", "second": "side_fixer"})
	board.pin("side_witness", "photo")
	board.pin("side_fixer", "photo")
	_check(board.lay_string("side_witness", "side_fixer"), "two people the world actually connects can be strung")

	# A crossing sideline: a chain of three people, strung together, where
	# one end supports theory_ownership (role token "robbery") and the other
	# supports theory_rotation (role token "command") — the same lead chain
	# touching two mainlines rather than converging into one.
	WorldHistory.register_subject("side_debtor", {"name": "A Debtor", "kind": "person", "role": "robbery"})
	WorldHistory.register_subject("side_middle", {"name": "A Go-Between", "kind": "person"})
	WorldHistory.register_subject("side_officer", {"name": "An Officer", "kind": "person", "role": "command"})
	WorldHistory.record_event("passed_a_word", {"first": "side_debtor", "second": "side_middle"})
	WorldHistory.record_event("passed_a_word", {"first": "side_middle", "second": "side_officer"})
	board.pin("side_debtor", "photo")
	board.pin("side_middle", "photo")
	board.pin("side_officer", "photo")
	_check(board.lay_string("side_debtor", "side_middle"), "the first link in the chain is a real connection")
	_check(board.lay_string("side_middle", "side_officer"), "the second link in the chain is a real connection")
	_check(board.lay_string("side_debtor", "theory_ownership"), "one end of the chain genuinely supports a mainline")
	_check(board.lay_string("side_officer", "theory_rotation"), "the other end genuinely supports a different mainline")
	board.rebuild()

	var clusters: Array = board.sideline_clusters()
	var pure_found := false
	var crossing_found := false
	for cluster: Dictionary in clusters:
		var nodes: Array = cluster["nodes"]
		var mainlines: Array = cluster["mainlines"]
		if nodes.has("side_witness") and nodes.has("side_fixer"):
			pure_found = mainlines.is_empty()
		if nodes.has("side_debtor") and nodes.has("side_officer"):
			crossing_found = mainlines.size() == 2
	_check(pure_found, "a cluster with no theory in it reads as its own pure sideline, not a failed mainline")
	_check(crossing_found, "a cluster strung into two different mainlines is read as connecting to both, not folded into one")

	print("L6.5 v2 - different people, places and factions per route")
	var supported_by_seen: Dictionary = {}
	var token_overlap := false
	for theory: Dictionary in BOARD.THEORIES:
		for token: String in (theory.get("supported_by", []) as Array):
			var key := str(token)
			if supported_by_seen.has(key):
				token_overlap = true
			supported_by_seen[key] = str(theory["id"])
	_check(not token_overlap, "no two mainlines share evidence vocabulary that could satisfy both at once")

	var final_events_seen: Dictionary = {}
	var final_overlap := false
	for theory_id: String in BOARD.ROUTES.keys():
		var stages: Array = BOARD.ROUTES[theory_id]
		var final_event := str((stages[stages.size() - 1] as Dictionary).get("event", ""))
		if final_events_seen.has(final_event):
			final_overlap = true
		final_events_seen[final_event] = theory_id
	_check(not final_overlap, "no two mainlines are carried to an ending by the same closing act")

	var district_names: Dictionary = {}
	for district: Dictionary in LIVING_MAP.DISTRICTS:
		district_names[str(district.get("name", ""))] = true
	_check(district_names.size() >= 4, "map_travel-gated stages have more than one real place to happen in (%d districts)" % district_names.size())

	print("SIDELINE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
