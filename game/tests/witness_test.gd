extends Node

## F1. The claim is not "events have a witnesses field" — it is that what the
## world *records* and what a faction *knows* are two different things, with a
## window between them you can act inside.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.clear_history()
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person", "faction_id": "ashline_wreckers"})
	WorldHistory.register_subject("dray_kell", {"name": "Dray Kell", "kind": "person", "faction_id": "ashline_wreckers"})
	WorldHistory.register_subject("vale_nine", {"name": "Vale Nine", "kind": "person"})
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	# --- who saw it ----------------------------------------------------------
	var crowd := [
		{"id": "mara_voss", "at": Vector3(2, 0, 3), "alive": true},
		{"id": "dray_kell", "at": Vector3(90, 0, 0), "alive": true},
		{"id": "vale_nine", "at": Vector3(5, 0, 5), "alive": false},
		{"id": "player", "at": Vector3(0, 0, 0), "alive": true},
	]
	var seen := WitnessLedger.witnesses_of(Vector3.ZERO, crowd, "player")
	check(seen.has("mara_voss"), "somebody standing next to it saw it")
	check(not seen.has("dray_kell"), "somebody ninety metres away did not")
	check(not seen.has("vale_nine"), "a corpse is not a witness")
	check(not seen.has("player"), "the actor is excluded from their own witnesses")

	# --- the act is recorded, the knowledge is not ---------------------------
	var ledger := WitnessLedger.new()
	var event := ledger.record("execution", {"subject": "player", "victim": "iris_coil"}, seen)
	var sequence := int(event.get("sequence", 0))
	check((event.get("details", {}) as Dictionary).has("witnesses"), "F1.1 the event carries its witnesses")
	check(not ledger.faction_knows("ashline_wreckers", sequence), "the faction does not know it yet")
	check(ledger.in_flight().size() == 1, "one account is walking home")

	# --- it lands ------------------------------------------------------------
	ledger.tick(WitnessLedger.REPORT_DELAY * 0.5)
	check(not ledger.faction_knows("ashline_wreckers", sequence), "and still does not, halfway through")
	var landed := ledger.tick(WitnessLedger.REPORT_DELAY)
	check(landed.size() == 1, "the report arrives")
	check(ledger.faction_knows("ashline_wreckers", sequence), "F1.2 and only then does the faction know")
	check(ledger.in_flight().is_empty(), "nothing is left in the air")

	# --- what arrives is an account, not the event ---------------------------
	var entries := ledger.knowledge("ashline_wreckers")
	check(entries.size() == 1, "the faction holds one entry")
	var entry: Dictionary = entries[0]
	check(str(entry.get("told_by", "")) == "mara_voss", "and knows who told them")
	check(str(entry.get("account", "")) != "execution", "what they hold is a retelling, not the record")

	# --- F1.3: cut the transmission -----------------------------------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person", "faction_id": "ashline_wreckers"})
	var quiet := WitnessLedger.new()
	var second := quiet.record("execution", {"subject": "player", "victim": "rook_sable"}, ["mara_voss"])
	var second_sequence := int(second.get("sequence", 0))
	check(quiet.in_flight().size() == 1, "an account is in the air")
	var lost := quiet.silence("mara_voss")
	check(lost == 1, "killing the witness destroys what they were carrying")
	quiet.tick(WitnessLedger.REPORT_DELAY * 3.0)
	check(not quiet.faction_knows("ashline_wreckers", second_sequence), "F1.3 the faction never learns it")
	check(WorldHistory.event_count("execution") >= 1, "but the world still recorded that it happened")

	# --- an unwitnessed act ---------------------------------------------------
	var alone := WitnessLedger.new()
	var unseen := alone.record("execution", {"subject": "player", "victim": "moth_jerrow"}, [])
	alone.tick(WitnessLedger.REPORT_DELAY * 3.0)
	check(not alone.faction_knows("ashline_wreckers", int(unseen.get("sequence", 0))), "an act nobody saw enters no faction's knowledge")
	check(alone.knowledge("unaffiliated").is_empty(), "and nobody carries it personally either")

	# --- an unaffiliated witness still carries it ----------------------------
	WorldHistory.register_subject("vale_nine", {"name": "Vale Nine", "kind": "person"})
	var drifter := WitnessLedger.new()
	drifter.record("execution", {"subject": "player"}, ["vale_nine"])
	drifter.tick(WitnessLedger.REPORT_DELAY * 1.5)
	check(not drifter.knowledge("unaffiliated").is_empty(), "somebody with no faction is still worth silencing")

	print("WITNESS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
