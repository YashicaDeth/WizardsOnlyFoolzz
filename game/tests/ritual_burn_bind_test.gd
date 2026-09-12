extends Node

## E2.6/E2.7. Casting a rite either binds its seal (additive, a circuit
## completed) or burns it (subtractive, a scar) - decided here in
## `RitualApp`, the same repeat count `Boons.grant()` already keeps to price
## a repeat higher (E4.3). A first casting always binds, since burning it on
## the second use would never let E4.3's escalating cost matter; after that
## the risk of a burn climbs with every repeat, and a burnt seal refuses to
## answer at all afterward, permanently, for the rest of the run.

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	var one_dead := {"contents": [{"subject_id": "x", "dead": true, "severed": [], "ruptured": []}]}

	# --- a first casting is always clean -------------------------------------
	var first := RitualApp.attempt("rite_of_bael", one_dead)
	check(bool(first.get("ok", false)), "a fresh rite is grantable at all")
	check(str(first.get("outcome", "")) == "bind", "and a first casting always binds, never burns")
	check((WorldHistory.subject("player").get("burnt_rituals", []) as Array).is_empty(), "so the seal is not burnt afterward")

	# --- the risk climbs with repeats, deterministically ---------------------
	var burn_seen := false
	var bind_seen := false
	for taken in range(1, 10):
		match RitualApp._decide_outcome("rite_of_bael", "player", taken):
			"burn":
				burn_seen = true
			"bind":
				bind_seen = true
	check(burn_seen, "repeating the same rite enough times can burn the seal")
	check(bind_seen, "and a low repeat count can still bind - E4.3's escalating cost gets a chance to matter")
	check(RitualApp._decide_outcome("rite_of_bael", "player", 4) == RitualApp._decide_outcome("rite_of_bael", "player", 4), "the same repeat count answers the same way twice")

	# --- a burnt seal is gone for the run, unconditionally -------------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "burnt_rituals": ["rite_of_bael"]})
	var refused := RitualApp.attempt("rite_of_bael", one_dead)
	check(not bool(refused.get("ok", false)), "a burnt seal refuses even a photo that would otherwise satisfy it")
	check(str(refused.get("reason", "")).contains("BURNT"), "and says why, in those words")

	# --- an actual burn is recorded on the subject and in the world's own
	# ledger, not only returned in the call's result -------------------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	var burning_taken := 0
	for candidate in range(1, 10):
		if RitualApp._decide_outcome("rite_of_bael", "player", candidate) == "burn":
			burning_taken = candidate
			break
	WorldHistory.update_subject("player", {
		"boon_history": {"rite_of_bael": burning_taken},
		"anatomy_state": {"blood": 5000.0, "blood_capacity": 5000.0},
	})
	var burning := RitualApp.attempt("rite_of_bael", one_dead)
	check(bool(burning.get("ok", false)), "the rite still grants what it promised on the casting that burns it")
	check(str(burning.get("outcome", "")) == "burn", "and reports that this specific casting burnt the seal")
	check((WorldHistory.subject("player").get("burnt_rituals", []) as Array).has("rite_of_bael"), "which is now written onto the subject as a permanent fact")
	var burn_event_found := false
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "ritual_completed" and str((event.get("details", {}) as Dictionary).get("outcome", "")) == "burn":
			burn_event_found = true
	check(burn_event_found, "and the world's own ledger records which outcome it actually was")

	print("RITUAL_BURN_BIND_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
