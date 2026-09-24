extends Node

## AE1.1-AE1.5. Unseen is real inputs combined, not a flag; an assassination
## runs through the exact same karma vocabulary and witness pipeline any other
## execution does; and a faction only ever answers for an act that is a real
## offence to where it already stands on the Tree, not a universal crime score.

const LocalLaw := preload("res://systems/local_law.gd")
const Holdings := preload("res://systems/ashbloom_holdings.gd")
const Quantum := preload("res://systems/quantum_saves.gd")

var failures: Array[String] = []


func check(condition: bool, what: String) -> void:
	print("PASS " if condition else "FAIL ", what)
	if not condition:
		failures.append(what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("celloutz", {"kind": "faction", "grudge": 0.0})
	WorldHistory.register_subject("wizardsonlyfoolz", {"kind": "faction", "grudge": 0.0})

	print("AE1.1 - unseen is combined from real inputs, not declared on its own")
	var far := LocalLaw.unseen_state(0.9, 0.9, 0.0, 999.0)
	check(bool(far.get("unseen", false)) and bool(far.get("beyond_sight", false)), "far enough away is unseen regardless of light or noise")
	var dark_quiet_covered := LocalLaw.unseen_state(0.05, 0.05, 0.9, 5.0)
	check(bool(dark_quiet_covered.get("unseen", false)) and not bool(dark_quiet_covered.get("beyond_sight", true)), "dark, quiet and covered is unseen within sight range too")
	var bright_loud_exposed := LocalLaw.unseen_state(0.6, 0.6, 0.0, 5.0)
	check(not bool(bright_loud_exposed.get("unseen", true)), "bright and loud with no cover is genuinely seen (%.2f)" % float(bright_loud_exposed.get("exposure", 0.0)))
	var tight_range := LocalLaw.unseen_state(0.0, 0.0, 1.0, 10.0, 5.0)
	check(bool(tight_range.get("beyond_sight", false)), "a caller's own tighter sight range is actually honoured")

	print("AE1.2/AE1.3 - assassination is a real execution that differs by witnesses, not by a second system")
	WorldHistory.register_subject("victim_one", {"name": "Victim One", "kind": "person"})
	var karma_before := float(WorldHistory.subject("player").get("karma", 0.0))
	var quiet_ledger := WitnessLedger.new()
	var unseen_event := LocalLaw.assassinate(quiet_ledger, "player", "victim_one", true, [])
	check(str((unseen_event.get("details", {}) as Dictionary).get("outcome", "")) == "execute", "recorded through the exact same execute vocabulary every other kill uses")
	check(bool((unseen_event.get("details", {}) as Dictionary).get("unseen", false)), "and carries the real unseen flag")
	var karma_after := float(WorldHistory.subject("player").get("karma", 0.0))
	check(karma_after < karma_before, "it really moved the Tree the same way any execution does (%.3f -> %.3f)" % [karma_before, karma_after])
	check(quiet_ledger.in_flight().is_empty(), "nobody witnessed it, so nothing is even in flight to report it")

	WorldHistory.register_subject("witness_one", {"name": "Witness One", "kind": "person", "faction_id": "wizardsonlyfoolz"})
	WorldHistory.register_subject("victim_two", {"name": "Victim Two", "kind": "person"})
	var loud_ledger := WitnessLedger.new()
	var seen_event := LocalLaw.assassinate(loud_ledger, "player", "victim_two", false, ["witness_one"])
	check(loud_ledger.in_flight().size() == 1, "a seen kill really does put a report in flight")
	loud_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	check(loud_ledger.faction_knows("wizardsonlyfoolz", int(seen_event.get("sequence", -1))), "and the witness's own faction actually learns of it")

	print("AE1.6 - a faction only reads an act as an offence relative to where it already stands")
	check(is_zero_approx(LocalLaw.offence_magnitude("celloutz", seen_event)), "an execution is not an offence to a faction already deep in Descent (%.3f)" % LocalLaw.offence_magnitude("celloutz", seen_event))
	check(LocalLaw.offence_magnitude("wizardsonlyfoolz", seen_event) > 0.0, "the same execution is a real offence to a faction that climbed the other way")
	WorldHistory.register_subject("victim_three", {"name": "Victim Three", "kind": "person"})
	var mercy_event := WorldHistory.record_event("npc_resolution", {"subject_id": "victim_three", "outcome": "spare", "actor": "player"})
	check(LocalLaw.offence_magnitude("celloutz", mercy_event) > 0.0, "mercy is a real offence to a faction that deals in ownership, not evil in the abstract")
	check(is_zero_approx(LocalLaw.offence_magnitude("wizardsonlyfoolz", mercy_event)), "the same mercy is no offence at all to the faction it already agrees with")
	check(is_zero_approx(LocalLaw.offence_magnitude("no_such_faction", seen_event)), "an unlisted faction has no axis to read anything against")

	print("AE10.10 - an impaired body's wrong account causes a wrong legal consequence")
	WorldHistory.register_subject("impaired_witness", {
		"name": "Impaired Witness", "kind": "person", "faction_id": "celloutz",
		"anatomy_state": {"consciousness": 20.0},
	})
	WorldHistory.register_subject("wrong_place", {"kind": "place", "held_by": "celloutz", "unrest": 0.0})
	var wrong_ledger := WitnessLedger.new()
	var true_execution := wrong_ledger.record("npc_resolution", {
		"subject_id": "wrongly_seen_victim", "actor": "player", "outcome": "execute",
		"place_id": "wrong_place", "held_by": "celloutz",
	}, ["impaired_witness"])
	var wrong_reports := wrong_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	var wrong_report: Dictionary = wrong_reports[0]
	check(str((true_execution.get("details", {}) as Dictionary).get("outcome", "")) == "execute",
		"the world's true event remains an execution")
	check(str((wrong_report.get("details", {}) as Dictionary).get("outcome", "")) == "spare",
		"the badly impaired witness carries the opposite resolution home")
	var wrong_response := LocalLaw.answer_report(wrong_ledger, wrong_report)
	check(is_zero_approx(LocalLaw.offence_magnitude("celloutz", true_execution)) and bool(wrong_response.get("ok", false)) and float(wrong_response.get("magnitude", 0.0)) > 0.0,
		"CellOutz acts on the reported mercy it condemns, not the true execution it would accept")
	var wrong_knowledge: Array = wrong_ledger.knowledge("celloutz")
	check(str((((wrong_knowledge[0] as Dictionary).get("testimony", {}) as Dictionary).get("outcome", ""))) == "spare" and not ((wrong_knowledge[0] as Dictionary).get("testimony", {}) as Dictionary).has("true_outcome"),
		"faction knowledge stores only the account and never labels or reveals the correction")

	print("AE1.4/AE1.5 - law only responds to what a faction was actually told, and a place remembers locally")
	var untold := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, unseen_event, "player")
	check(not bool(untold.get("ok", false)) and str(untold.get("reason", "")) == "THE HOLDER WAS NEVER TOLD", "an act nobody ever reported to this faction is refused outright, even a real execution")

	var not_offended := LocalLaw.witness_a_wrong("holding_alpha", "celloutz", loud_ledger, seen_event, "player")
	check(not bool(not_offended.get("ok", false)), "a faction this act does not offend never accrues any unrest over it")

	var grudge_before := float(WorldHistory.subject("wizardsonlyfoolz").get("grudge", 0.0))
	var first_response := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, seen_event, "player")
	check(bool(first_response.get("ok", false)) and not bool(first_response.get("dispatched", true)), "one witnessed execution alone is remembered but not yet enough to send anyone")
	var duplicate_response := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, seen_event, "player")
	check(not bool(duplicate_response.get("ok", false)) and str(duplicate_response.get("reason", "")).contains("ALREADY"), "two witnesses cannot make one wrong count twice at the same place")
	WorldHistory.register_subject("victim_four", {"name": "Victim Four", "kind": "person"})
	var second_event := LocalLaw.assassinate(loud_ledger, "player", "victim_four", false, ["witness_one"])
	loud_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	var second_response := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, second_event, "player")
	check(not bool(second_response.get("dispatched", true)), "still not enough on its own (%.3f unrest)" % float(second_response.get("unrest", 0.0)))
	WorldHistory.register_subject("victim_five", {"name": "Victim Five", "kind": "person"})
	var third_event := LocalLaw.assassinate(loud_ledger, "player", "victim_five", false, ["witness_one"])
	loud_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	var third_response := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, third_event, "player")
	check(bool(third_response.get("dispatched", false)), "a place that remembers wrong after wrong eventually sends its own people")
	var grudge_after := float(WorldHistory.subject("wizardsonlyfoolz").get("grudge", 0.0))
	check(grudge_after > grudge_before, "and sending them is a real rise in the faction's own grudge (%.2f -> %.2f)" % [grudge_before, grudge_after])
	check(float(WorldHistory.subject("holding_alpha").get("unrest", -1.0)) == 0.0, "the place's own remembered unrest is spent once it actually acts")

	print("AE10.14 - standing changes enforcement tolerance without erasing the witnessed wrong")
	WorldHistory.register_subject("standing_witness", {"name": "Standing Witness", "kind": "person", "faction_id": "wizardsonlyfoolz"})
	WorldHistory.register_subject("kin_place", {"kind": "place", "held_by": "wizardsonlyfoolz", "unrest": 0.0})
	WorldHistory.register_subject("refused_place", {"kind": "place", "held_by": "wizardsonlyfoolz", "unrest": 0.0})
	var standing_ledger := WitnessLedger.new()
	var kin_event := standing_ledger.record("npc_resolution", {"subject_id": "kin_victim", "outcome": "execute", "actor": "player"}, ["standing_witness"])
	var refused_event := standing_ledger.record("npc_resolution", {"subject_id": "refused_victim", "outcome": "execute", "actor": "player"}, ["standing_witness"])
	standing_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	WorldHistory.amend_subject("player", {"karma": 1.0})
	var kin_response := LocalLaw.witness_a_wrong("kin_place", "wizardsonlyfoolz", standing_ledger, kin_event, "player")
	WorldHistory.amend_subject("player", {"karma": -1.0})
	var refused_response := LocalLaw.witness_a_wrong("refused_place", "wizardsonlyfoolz", standing_ledger, refused_event, "player")
	check(str(kin_response.get("disposition", "")) == "kin" and str(refused_response.get("disposition", "")) == "refuses",
		"law reads the same live faction disposition as trade rather than a second reputation score")
	check(float(kin_response.get("response_threshold", 0.0)) > float(refused_response.get("response_threshold", 0.0)),
		"kin receive a longer leash than somebody the same faction already refuses")
	check(bool(kin_response.get("ok", false)) and not bool(kin_response.get("dispatched", true)) and float(kin_response.get("unrest", 0.0)) > 0.0,
		"a witnessed wrong by kin is remembered locally rather than forgiven or immediately escalated")
	check(bool(refused_response.get("dispatched", false)),
		"the identical witnessed wrong sends law immediately when the faction already refuses the actor")

	print("AE10.15 - the reason for a warrant remains on the player across a quantum restart")
	var wanted_before: Dictionary = WorldHistory.subject("player").get("wanted_for", {})
	check(str(wanted_before.get("event_type", "")) == "npc_resolution" and str(wanted_before.get("outcome", "")) == "execute",
		"dispatch records the actual act and outcome rather than a generic wanted flag")
	check(str(wanted_before.get("subject_id", "")) == "refused_victim" and str(wanted_before.get("faction_id", "")) == "wizardsonlyfoolz" and str(wanted_before.get("place_id", "")) == "refused_place",
		"the warrant memory names its victim, issuing faction and jurisdiction")
	var origin_salt := int(wanted_before.get("origin_run_salt", 0))
	var new_branch := Quantum.begin_new(2, "LAW RESTART PROBE")
	var wanted_after: Dictionary = WorldHistory.subject("player").get("wanted_for", {})
	check(not new_branch.is_empty() and int(WorldHistory.run_salt) != origin_salt,
		"begin_new creates a genuinely different universe for the law-memory proof")
	check(wanted_after == wanted_before and (WorldHistory.subject("refused_place").is_empty()),
		"what the player was wanted for crosses intact while the old jurisdiction itself does not")
	check((WorldHistory.subject("player").get("wanted_history", []) as Array).size() >= 1,
		"the continuing player retains an inspectable warrant history rather than only the latest label")

	print("AE1.4/AE1.5 production seam - a landed report answers through the real surface holding")
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("ashline_wreckers", {"name": "Ashline Wreckers", "kind": "faction", "grudge": 0.0})
	WorldHistory.register_subject("ashline_witness", {"name": "Ashline Witness", "kind": "person", "faction_id": "ashline_wreckers"})
	WorldHistory.register_subject("mercy_target", {"name": "Mercy Target", "kind": "person", "faction_id": "ashline_wreckers"})
	var jurisdiction := Holdings.jurisdiction_at((Holdings.DEFINITIONS[2] as Dictionary).at)
	var field_ledger := WitnessLedger.new()
	var field_event := field_ledger.record("npc_resolution", {
		"subject_id": "mercy_target", "actor": "player", "outcome": "spare",
		"holding_id": jurisdiction.holding_id, "place_id": jurisdiction.place_id, "held_by": jurisdiction.held_by,
	}, ["ashline_witness"])
	var landed := field_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	var field_response := LocalLaw.answer_report(field_ledger, landed[0])
	check(bool(field_response.get("ok", false)) and str(field_response.get("place_id", "")) == "ashbloom:bone_yard",
		"the production report seam resolves into the Bone Yard's canonical place record")
	check(float(WorldHistory.subject("ashbloom:bone_yard").get("unrest", 0.0)) > 0.0,
		"the same place shown by MAP, INDEX and Board now carries its own local unrest")
	var unrest_events := WorldHistory.events.filter(func(event: Dictionary):
		return str(event.get("type", "")) == "local_unrest" and int((event.get("details", {}) as Dictionary).get("source_sequence", -1)) == int(field_event.sequence))
	check(unrest_events.size() == 1, "the local consequence cites the exact witnessed resolution that caused it")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "unrest, warrant memory, dispatch and the holding's spent balance always close one transaction")

	print("LOCAL_LAW_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
