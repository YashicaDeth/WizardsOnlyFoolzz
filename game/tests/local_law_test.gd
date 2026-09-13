extends Node

## AE1.1-AE1.5. Unseen is real inputs combined, not a flag; an assassination
## runs through the exact same karma vocabulary and witness pipeline any other
## execution does; and a faction only ever answers for an act that is a real
## offence to where it already stands on the Tree, not a universal crime score.

const LocalLaw := preload("res://systems/local_law.gd")

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

	print("AE1.4/AE1.5 - law only responds to what a faction was actually told, and a place remembers locally")
	var untold := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, unseen_event, "player")
	check(not bool(untold.get("ok", false)) and str(untold.get("reason", "")) == "THE HOLDER WAS NEVER TOLD", "an act nobody ever reported to this faction is refused outright, even a real execution")

	var not_offended := LocalLaw.witness_a_wrong("holding_alpha", "celloutz", loud_ledger, seen_event, "player")
	check(not bool(not_offended.get("ok", false)), "a faction this act does not offend never accrues any unrest over it")

	var grudge_before := float(WorldHistory.subject("wizardsonlyfoolz").get("grudge", 0.0))
	var first_response := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, seen_event, "player")
	check(bool(first_response.get("ok", false)) and not bool(first_response.get("dispatched", true)), "one witnessed execution alone is remembered but not yet enough to send anyone")
	var second_response := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, seen_event, "player")
	check(not bool(second_response.get("dispatched", true)), "still not enough on its own (%.3f unrest)" % float(second_response.get("unrest", 0.0)))
	var third_response := LocalLaw.witness_a_wrong("holding_alpha", "wizardsonlyfoolz", loud_ledger, seen_event, "player")
	check(bool(third_response.get("dispatched", false)), "a place that keeps remembering the same wrong eventually sends its own people")
	var grudge_after := float(WorldHistory.subject("wizardsonlyfoolz").get("grudge", 0.0))
	check(grudge_after > grudge_before, "and sending them is a real rise in the faction's own grudge (%.2f -> %.2f)" % [grudge_before, grudge_after])
	check(float(WorldHistory.subject("holding_alpha").get("unrest", -1.0)) == 0.0, "the place's own remembered unrest is spent once it actually acts")

	print("LOCAL_LAW_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
