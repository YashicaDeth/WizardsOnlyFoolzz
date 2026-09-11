extends Node

## F2. A grudge is not assigned to whoever the design says should hate you. It
## is inherited across relation edges that already existed, gets weaker the
## further it travels, and is a slightly different story every time it is told.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _seed() -> void:
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER"})
	# A chain: the victim, their close friend, that friend's ally, and a
	# distant acquaintance at the far end of it.
	WorldHistory.register_subject("victim", {"name": "The Victim", "relations": {"friend": {"kind": "bond", "strength": 90}}})
	WorldHistory.register_subject("witness", {"name": "The Witness", "relations": {"friend": {"kind": "ally", "strength": 80}}})
	WorldHistory.register_subject("friend", {
		"name": "Close Friend", "grudge": 0,
		"relations": {"victim": {"kind": "bond", "strength": 90}, "second": {"kind": "ally", "strength": 70}},
	})
	WorldHistory.register_subject("second", {
		"name": "Second Hand", "grudge": 0,
		"relations": {"victim": {"kind": "known", "strength": 30}, "third": {"kind": "known", "strength": 25}},
	})
	WorldHistory.register_subject("third", {"name": "Third Hand", "grudge": 0, "relations": {"victim": {"kind": "known", "strength": 10}}})
	WorldHistory.register_subject("stranger", {"name": "Unconnected", "grudge": 0, "relations": {}})


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	_seed()

	var killing := {"sequence": 7, "type": "npc_resolution", "details": {"subject_id": "victim", "outcome": "execute", "actor": "player"}}
	var ledger := WitnessLedger.new()
	var reached: Array = ledger.propagate("witness", killing)
	var ids: Array = []
	for entry in reached:
		ids.append(str(entry.id))

	# --- F2.1: it travels the edges that exist, and only those --------------
	check(ids.has("friend"), "the witness tells the person they actually know")
	check(ids.has("second"), "and it carries on to their ally")
	check(not ids.has("stranger"), "somebody with no edge to anyone never hears it")

	# --- F2.2: distance costs ----------------------------------------------
	var force_by_id := {}
	var hops_by_id := {}
	for entry in reached:
		force_by_id[str(entry.id)] = float(entry.force)
		hops_by_id[str(entry.id)] = int(entry.hops)
	check(float(force_by_id.friend) > float(force_by_id.second), "it arrives weaker the further it goes (%.2f -> %.2f)" % [force_by_id.friend, force_by_id.second])
	check(int(hops_by_id.friend) < int(hops_by_id.second), "and further is measured in real hops")
	check(not ids.has("third") or float(force_by_id.get("third", 0.0)) < float(force_by_id.second), "and it fades out rather than travelling forever")

	# --- F2.3: every retelling is a retelling -------------------------------
	var first_account := ""
	var later_account := ""
	for entry in reached:
		if str(entry.id) == "friend":
			first_account = str(entry.account)
		if str(entry.id) == "second":
			later_account = str(entry.account)
	check(first_account != "" and later_account != "", "every hop carries an account of what happened")
	check(first_account != later_account, "and it is not the same story by the second telling")

	# --- the grudge is the payload ------------------------------------------
	var close := int(WorldHistory.subject("friend").get("grudge", 0))
	var distant := int(WorldHistory.subject("second").get("grudge", 0))
	check(close > 0, "somebody bonded to the victim takes it personally (%d)" % close)
	check(close > distant, "and takes it harder than somebody who barely knew them (%d vs %d)" % [close, distant])
	check(int(WorldHistory.subject("stranger").get("grudge", 0)) == 0, "a stranger holds nothing against you")
	check((WorldHistory.subject("friend").get("heard", []) as Array).size() > 0, "and what they heard is on their record, not just a number")

	# --- an inert act spreads as news but not as a grievance ----------------
	_seed()
	var nothing := {"sequence": 9, "type": "weapon_fired", "details": {"subject_id": "victim", "actor": "player"}}
	WitnessLedger.new().propagate("witness", nothing)
	check(int(WorldHistory.subject("friend").get("grudge", 0)) == 0, "hearing you fired a gun is not a reason to hate you")
	check((WorldHistory.subject("friend").get("heard", []) as Array).size() > 0, "though they did still hear about it")

	# --- F2.4: the Wire is the faster, worse carrier ------------------------
	_seed()
	var wire_ledger := WitnessLedger.new()
	var blasted: Array = wire_ledger.broadcast(killing, ["friend", "second", "stranger"], 1.0)
	check(blasted.size() == 3, "the Wire reaches people no friendship graph connects")
	check(int(WorldHistory.subject("stranger").get("heard", []).size()) > 0, "including somebody with no edges at all")
	var wire_account := str((blasted[0] as Dictionary).account)
	check(int((blasted[0] as Dictionary).hops) > WitnessLedger.MAX_HOPS, "and it arrives more distorted than any retelling on foot")
	check(wire_account != first_account, "so the Wire's version is not the witness's version")

	print("PROPAGATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
