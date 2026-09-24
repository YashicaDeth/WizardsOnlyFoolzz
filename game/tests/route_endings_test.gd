extends Node

## E7.3. Both endings must actually be reachable from real recorded karma,
## written exactly once, and never contradict themselves on a second read.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- neither ending is reached from Limbo --------------------------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	check(RouteEndings.check("player") == "", "a newcomer in Limbo has reached no ending")

	# --- run it down far enough and the soul is signed over -----------------
	for i in 20:
		WorldHistory.record_event("npc_resolution", {"subject_id": "v%d" % i, "outcome": "execute", "actor": "player"})
	var alignment := WorldHistory.tree_alignment(WorldHistory.subject("player"))
	var ending := RouteEndings.check("player")
	check(alignment <= RouteEndings.DEMON_THRESHOLD, "a career of executions actually crosses the demon threshold (%.2f)" % alignment)
	check(ending == RouteEndings.ENDING_DEMON, "and it is written as the demon ending, not inferred each time")
	check(bool(WorldHistory.subject("player").get("route_ending_recorded", false)), "recorded permanently on the subject")

	# --- it does not silently re-fire or contradict itself -------------------
	var events_before := WorldHistory.events.size()
	var second_check := RouteEndings.check("player")
	check(second_check == ending, "checking again returns the same ending")
	check(WorldHistory.events.size() == events_before, "and does not record a second route_ending_reached event")

	# --- climbing far enough reaches the other ending, on a fresh subject ---
	WorldHistory.clear_history()
	WorldHistory.register_subject("zealot", {"name": "Zealot", "kind": "person", "faction_id": "gate_lanterns"})
	for i in 20:
		WorldHistory.record_event("npc_resolution", {"subject_id": "s%d" % i, "outcome": "spare", "actor": "zealot"})
	var climbed := WorldHistory.tree_alignment(WorldHistory.subject("zealot"))
	var ascended := RouteEndings.check("zealot")
	check(climbed >= RouteEndings.ASCENDANT_THRESHOLD, "a career of mercy from an ascending birth crosses the ascendant threshold (%.2f)" % climbed)
	check(ascended == RouteEndings.ENDING_ASCENDANT, "and it is written as the ascendant ending")
	check(RouteEndings.ending_of("zealot") == RouteEndings.ENDING_ASCENDANT, "ending_of() reads it back correctly")

	# --- K3.3: the ascendant ending is the "forced God's attention" moment --
	check(RouteEndings.forced_gods_attention("zealot"), "the ascendant ending reads as having forced God's attention")
	check(not RouteEndings.forced_gods_attention("player"), "the demon ending does not")

	# --- K3.1: the first ending reached locks; the other threshold is ignored
	# once it has, which is the "committing to one closes the other" half of
	# the answer this file's own comment argues for.
	WorldHistory.clear_history()
	WorldHistory.register_subject("reformed", {"name": "Reformed", "kind": "person"})
	for i in 20:
		WorldHistory.record_event("npc_resolution", {"subject_id": "early%d" % i, "outcome": "execute", "actor": "reformed"})
	check(RouteEndings.check("reformed") == RouteEndings.ENDING_DEMON, "signs away first")
	for i in 40:
		WorldHistory.record_event("npc_resolution", {"subject_id": "late%d" % i, "outcome": "spare", "actor": "reformed"})
	var drifted := WorldHistory.tree_alignment(WorldHistory.subject("reformed"))
	var still_demon := RouteEndings.check("reformed")
	check(drifted >= RouteEndings.ASCENDANT_THRESHOLD, "and genuinely drifts all the way back up on paper (%.2f)" % drifted)
	check(still_demon == RouteEndings.ENDING_DEMON, "but the recorded ending does not silently flip to ascendant just because the axis crossed back")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "the permanent ending lock and its one public fact always close together")

	print("ROUTE_ENDINGS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
