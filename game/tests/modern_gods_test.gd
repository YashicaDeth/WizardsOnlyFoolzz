extends Node

## AJ3/AJ5. Gods are real subjects with real attention, and a death's verdict
## must actually read the victim's real alignment plus the kill's real
## circumstance — and different gods must actually disagree on the same death.

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
	ModernGods.seed_gods()
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "all modern gods seed in one closed schema transaction")

	for god_id in ModernGods.GODS:
		var subject := WorldHistory.subject(god_id)
		check(str(subject.get("kind", "")) == "god", "%s is a real registered subject, not a flavour label" % god_id)
		check(int(subject.get("attention", -1)) == 0, "and starts with no attention")

	# --- AJ5.2: the two poles read off the victim's own real alignment ------
	WorldHistory.register_subject("deep_demon", {"kind": "person", "faction_id": "celloutz"})
	WorldHistory.register_subject("deep_saint", {"kind": "person", "faction_id": "gate_lanterns", "bond": 90})
	var demon_verdict := ModernGods.verdict("the_market", "deep_demon", {"harvested": true})
	var saint_verdict := ModernGods.verdict("the_market", "deep_saint", {"harvested": true})
	check(demon_verdict.label == ModernGods.FREED, "killing something deep in Descent reads as freeing it (%s)" % demon_verdict.label)
	check(saint_verdict.label == ModernGods.ENSLAVED, "killing something that was climbing reads as forcing it back (%s)" % saint_verdict.label)
	check(demon_verdict.lean > saint_verdict.lean, "and the lean itself actually differs, not just the label")

	# --- AJ3.2/AJ3.4: attention is real and accumulates ---------------------
	check(int(WorldHistory.subject("the_market").get("attention", 0)) == 2, "the_market's attention actually rose from being asked (2 verdicts so far)")

	# --- AJ5.3: circumstance actually changes the verdict, same victim ------
	WorldHistory.register_subject("limbo_victim", {"kind": "person"})
	var no_harvest := ModernGods.verdict("the_market", "limbo_victim", {"harvested": false})
	var with_harvest := ModernGods.verdict("the_market", "limbo_victim", {"harvested": true})
	check(with_harvest.lean > no_harvest.lean, "The Market actually cares whether a part was harvested, same victim (%.2f > %.2f)" % [with_harvest.lean, no_harvest.lean])

	var no_witness := ModernGods.verdict("the_engagement", "limbo_victim", {"witnessed": 0})
	var witnessed := ModernGods.verdict("the_engagement", "limbo_victim", {"witnessed": 5})
	check(witnessed.lean > no_witness.lean, "The Engagement actually cares whether it was seen, same victim")

	# --- AJ5.4: gods actually disagree on the same death ---------------------
	WorldHistory.register_subject("ambiguous_victim", {"kind": "person"})
	var details := {"witnessed": 0, "harvested": true, "contracted": false, "public": false}
	var engagement_verdict := ModernGods.verdict("the_engagement", "ambiguous_victim", details)
	var market_verdict := ModernGods.verdict("the_market", "ambiguous_victim", details)
	check(engagement_verdict.label != market_verdict.label, "two gods reading the exact same death actually disagree (%s vs %s)" % [engagement_verdict.label, market_verdict.label])

	# --- AJ5.7: recorded in WorldHistory, one event per god's opinion -------
	WorldHistory.clear_history()
	ModernGods.seed_gods()
	WorldHistory.register_subject("recorded_victim", {"kind": "person"})
	var results := ModernGods.record_death_verdicts("recorded_victim", "player", {"harvested": true})
	check(results.size() == ModernGods.GODS.size(), "every god is asked, and every opinion is returned (%d)" % results.size())
	var verdict_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "death_verdict")
	check(verdict_events.size() == ModernGods.GODS.size(), "and each opinion is its own recorded event, never summed into one (%d events)" % verdict_events.size())
	var distinct_gods := {}
	for event in verdict_events:
		distinct_gods[str((event.get("details", {}) as Dictionary).get("god_id", ""))] = true
	check(distinct_gods.size() == ModernGods.GODS.size(), "and each event is attributed to its own god, not anonymous")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "all gods' attention, separate opinions and standing consequences close one death transaction")

	# --- asking a subset only asks that subset -------------------------------
	WorldHistory.clear_history()
	ModernGods.seed_gods()
	WorldHistory.register_subject("subset_victim", {"kind": "person"})
	var subset_results := ModernGods.record_death_verdicts("subset_victim", "player", {}, ["the_brand"])
	check(subset_results.size() == 1 and subset_results[0].god_id == "the_brand", "asking a specific god only asks that god, not all four")

	print("MODERN_GODS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
