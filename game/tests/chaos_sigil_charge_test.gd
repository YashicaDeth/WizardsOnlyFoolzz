extends Node

## AJ1.4. "Charging costs something real." A blood sigil is the most literal
## reading of the actual tradition available, not an invented mechanic —
## spent through the exact ledger `boons.gd` already pays E4 boosts from,
## scaled by how much the intent actually condensed to rather than a flat
## number unrelated to what was stated.

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

	print("AJ1.4 - a real cost, paid against the real body")
	var before_blood := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	var charged := ChaosSigil.charge("I want to be seen", "player")
	check(bool(charged.get("ok", false)), "charging a real, stated intent succeeds")
	var after_blood := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(after_blood < before_blood, "blood actually dropped (%.0f -> %.0f)" % [before_blood, after_blood])
	var sigil: Dictionary = charged.get("sigil", {})
	check(bool(sigil.get("charged", false)), "the sigil itself carries its own charged state")
	check(str(sigil.get("cost_kind", "")) == "blood", "and names what it actually cost")

	print("AJ1.4 - a longer ask costs more, the same way a heavier ask should")
	var short_cost: float = ChaosSigil.charge("go", "player").get("sigil", {}).get("cost_paid", 0.0)
	var long_cost: float = ChaosSigil.charge("annihilate the entire ashline wrecker convoy", "player").get("sigil", {}).get("cost_paid", 0.0)
	check(float(long_cost) > float(short_cost), "a more demanding intent draws more blood (%.0f vs %.0f)" % [long_cost, short_cost])

	print("AJ1.4 - nothing stated, nothing to charge")
	var blank := ChaosSigil.charge("   ", "player")
	check(not bool(blank.get("ok", false)), "a blank intent refuses outright rather than charging for nothing")

	print("AJ1.4 - a body with nothing left to give refuses the same way a boon would")
	WorldHistory.amend_subject("player", {"anatomy_state": {"blood": 200.0, "blood_capacity": 5000.0}})
	var refused := ChaosSigil.charge("drain what little is left", "player")
	check(not bool(refused.get("ok", false)), "refused outright, not granted on credit")

	print("AJ1.4 - a real, findable event, not a silent deduction")
	var events: Array[String] = []
	for event in WorldHistory.events:
		events.append(str(event.get("type", "")))
	check(events.count("sigil_charged") == 3, "one event per successful charge above, none for the refused ones (%d)" % events.count("sigil_charged"))
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "body payment, pending count and every charge fact close one transaction")

	print("CHAOS_SIGIL_CHARGE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
