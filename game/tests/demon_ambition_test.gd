extends Node

## K5.1 v2. A lesser demon must actually want something derived from its own
## real state, and pursuing it must be a real consequence, not a no-op — and
## succeeding at patronage must actually graduate them out of "lesser demon."

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
	WorldHistory.register_subject("vanity_row", {"kind": "faction", "name": "Vanity Row", "channel": "test", "signal_control": 100.0})
	WorldHistory.register_subject("honeyvein", {"kind": "faction", "name": "The Honeyvein", "channel": "test", "signal_control": 40.0})
	WorldHistory.register_subject("long_static", {"kind": "faction", "name": "The Long Static", "channel": "test", "signal_control": 70.0})

	check(DemonAmbition.ambition("nobody").is_empty(), "a subject that does not exist has no ambition")

	WorldHistory.register_subject("bystander", {"kind": "person", "is_rival": false, "faction_id": ""})
	check(DemonAmbition.ambition("bystander").is_empty(), "a bystander who was never made a rival wants nothing here")

	# --- a fresh lesser demon with no grudge yet seeks patronage -------------
	WorldHistory.register_subject("fresh_demon", {"kind": "person", "is_rival": true, "faction_id": ""})
	var fresh_ambition := DemonAmbition.ambition("fresh_demon")
	check(str(fresh_ambition.get("kind", "")) == "seek_patronage", "a lesser demon with no real grudge yet seeks patronage")
	check(str(fresh_ambition.get("target", "")) == "honeyvein", "and targets whichever Sin is currently weakest, not an authored favourite (%s)" % str(fresh_ambition.get("target", "")))

	var pursued := DemonAmbition.pursue("fresh_demon")
	check(bool(pursued.get("ok", false)), "pursuing patronage succeeds")
	check(str(WorldHistory.subject("fresh_demon").get("faction_id", "")) == "honeyvein", "and actually grants the faction affiliation, not just a flag")
	check(not DemonHierarchy.is_lesser_demon("fresh_demon"), "which graduates them out of being a lesser demon at all")
	var join_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "demon_joined_faction")
	check(not join_events.is_empty(), "and it is a real recorded event")

	# --- a demon with a real, strong grudge pursues that instead -------------
	WorldHistory.register_subject("player", {"kind": "person", "name": "THE HUNTER"})
	WorldHistory.register_subject("vengeful_demon", {
		"kind": "person", "is_rival": true, "faction_id": "",
		"relations": {"player": {"kind": "grudge", "strength": 40}},
	})
	var vengeful_ambition := DemonAmbition.ambition("vengeful_demon")
	check(str(vengeful_ambition.get("kind", "")) == "settle_grudge", "a demon with a real strong grudge pursues that instead of patronage")
	check(str(vengeful_ambition.get("target", "")) == "player", "naming the actual target of the grudge")

	var events_before := WorldHistory.events.size()
	var grudge_pursuit := DemonAmbition.pursue("vengeful_demon")
	check(bool(grudge_pursuit.get("ok", false)), "pursuing the grudge succeeds")
	check(WorldHistory.events.size() == events_before + 1, "and records exactly one real escalation event, not a silent no-op")
	check(DemonHierarchy.is_lesser_demon("vengeful_demon"), "and they are still a lesser demon — settling a grudge is not the same graduation patronage is")

	# --- a weak grudge is not enough to override seeking patronage -----------
	WorldHistory.register_subject("mild_grudge_demon", {
		"kind": "person", "is_rival": true, "faction_id": "",
		"relations": {"player": {"kind": "grudge", "strength": 3}},
	})
	check(str(DemonAmbition.ambition("mild_grudge_demon").get("kind", "")) == "seek_patronage", "a grudge too small to matter yet does not override seeking patronage")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "autonomous patronage state and its public fact close one world transaction")

	print("DEMON_AMBITION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
