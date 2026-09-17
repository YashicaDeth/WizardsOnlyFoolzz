extends Node

## E3.1/E3.2/E3.3. A rite must be refused on a photo that does not actually
## show what it asks for, granted only through boons.gd's real body cost, and
## every rite must be keyed to a real, already-verified seal.

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

	# --- E3.3: no confirm button — an empty photo is refused outright -------
	var empty_photo := {"contents": []}
	var refused := RitualApp.attempt("rite_of_bael", empty_photo)
	check(not bool(refused.get("ok", false)), "an empty photograph completes no rite")

	# --- E3.2: the photo is checked against real anatomy content, not a flag
	var wrong_evidence := {"contents": [{"subject_id": "x", "dead": false, "severed": [], "ruptured": []}]}
	var still_refused := RitualApp.attempt("rite_of_bael", wrong_evidence)
	check(not bool(still_refused.get("ok", false)), "a photo of someone alive does not satisfy a dead_count rite")

	var one_dead := {"contents": [{"subject_id": "x", "dead": true, "severed": [], "ruptured": []}]}
	var before_blood := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	var granted := RitualApp.attempt("rite_of_bael", one_dead)
	check(bool(granted.get("ok", false)), "one real death satisfies rite_of_bael")
	var after_blood := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(after_blood < before_blood, "and it actually costs blood through boons.gd, not a free grant")
	check(is_equal_approx(Boons.stat_bonus("player", "pain_resist"), 0.25), "and the boost is live")

	var events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "ritual_completed")
	check(not events.is_empty(), "a completed rite is a real recorded event")
	check(PlayerActionLedger.count("ritual_completed") == 1 and str((events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_") and int(WorldHistory.get("_ledger_batch_depth")) == 0, "body cost, boon and completion share one closed player-action transaction")

	# --- gored_heads specifically requires a head/brain hit on a dead subject
	var wrong_zone := {"contents": [
		{"subject_id": "a", "dead": true, "severed": ["left_arm"], "ruptured": []},
		{"subject_id": "b", "dead": true, "severed": ["left_arm"], "ruptured": []},
		{"subject_id": "c", "dead": true, "severed": ["left_arm"], "ruptured": []},
		{"subject_id": "d", "dead": true, "severed": ["left_arm"], "ruptured": []},
		{"subject_id": "e", "dead": true, "severed": ["left_arm"], "ruptured": []},
	]}
	var wrong_zone_refused := RitualApp.attempt("rite_of_the_filed_tooth", wrong_zone)
	check(not bool(wrong_zone_refused.get("ok", false)), "five deaths with the wrong wound zone still refuse the Filed Tooth rite")

	var five_gored := {"contents": [
		{"subject_id": "a", "dead": true, "severed": ["head"], "ruptured": []},
		{"subject_id": "b", "dead": true, "severed": [], "ruptured": ["brain"]},
		{"subject_id": "c", "dead": true, "severed": ["head"], "ruptured": []},
		{"subject_id": "d", "dead": true, "severed": ["head"], "ruptured": []},
		{"subject_id": "e", "dead": true, "severed": ["head"], "ruptured": []},
	]}
	var filed_tooth := RitualApp.attempt("rite_of_the_filed_tooth", five_gored)
	check(bool(filed_tooth.get("ok", false)), "five real gored heads satisfies the Filed Tooth rite")
	check(str(filed_tooth.get("seal", "")) == "The Filed Tooth", "and it names its real seal")

	# --- every rite is keyed to a seal goetic_seals.gd actually knows about -
	for ritual_id in RitualApp.RITUALS:
		var seal_name := str((RitualApp.RITUALS[ritual_id] as Dictionary).get("seal", ""))
		check(not GoeticSeals.by_name(seal_name).is_empty(), "%s's seal (%s) actually resolves in GoeticSeals" % [ritual_id, seal_name])

	# --- E4.3 for free: performing the same rite again costs more ----------
	var second_attempt := RitualApp.attempt("rite_of_bael", {"contents": [{"subject_id": "y", "dead": true, "severed": [], "ruptured": []}]})
	check(bool(second_attempt.get("ok", false)) and float(second_attempt.get("cost_paid", 0.0)) > float(granted.get("cost_paid", 0.0)), "repeating the same rite costs more, inherited from boons.gd for free")

	print("RITUAL_APP_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
