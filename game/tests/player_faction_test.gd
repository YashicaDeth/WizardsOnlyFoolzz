extends Node

## U. The player's own faction must actually found, recruit, lose members and
## have real standing — on the same generic machinery every other faction
## already runs on, not a parallel system built just for it.

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

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

	check(PlayerFaction.members().is_empty(), "nothing exists before founding")
	var refused_recruit := PlayerFaction.recruit("player")
	check(not bool(refused_recruit.get("ok", false)), "recruiting before founding is refused")

	# --- U1.1: found something -----------------------------------------------
	var founded := PlayerFaction.found("The Reclaimed", "a bent nail, straightened once")
	check(bool(founded.get("ok", false)), "founding succeeds")
	check(str(WorldHistory.subject("player").get("faction_id", "")) == PlayerFaction.FACTION_ID, "the founder actually belongs to it")
	check(str(WorldHistory.subject("player").get("faction_rank", "")) == "CROWN", "and holds CROWN, the same rank machinery any faction uses")
	check(str(WorldHistory.subject(PlayerFaction.FACTION_ID).get("mark", "")) != "", "the mark is real recorded data, not just a name")
	var founding_events := WorldHistory.events.filter(func(e: Dictionary) -> bool: return str(e.get("type", "")) == "faction_founded")
	check(founding_events.size() == 1 and PLAYER_ACTION_LEDGER.count("faction_founded") == 1 and str((founding_events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "founder, faction record and founding fact share one identified action")

	var double_found := PlayerFaction.found("Something Else")
	check(not bool(double_found.get("ok", false)), "a second founding is refused — there is only one")

	# --- the pyramid reads it exactly like any other faction -----------------
	var wire := WireNet.new()
	var pyramid := wire.pyramid(PlayerFaction.FACTION_ID)
	check(pyramid.headcount == 1, "the pyramid sees the founder as a real member (%d)" % pyramid.headcount)
	check((pyramid.tiers[0].members as Array).size() == 1, "sitting at CROWN, on the same generic tiers every faction uses")

	# --- U1.2: recruits from the clinch/downed window belong to it -----------
	WorldHistory.register_subject("recruit_one", {"name": "Recruit One", "kind": "person", "faction_id": ""})
	var recruited := PlayerFaction.recruit("recruit_one")
	check(bool(recruited.get("ok", false)), "recruiting a real subject succeeds")
	check(str(WorldHistory.subject("recruit_one").get("faction_id", "")) == PlayerFaction.FACTION_ID, "and actually grants the affiliation")
	check(PlayerFaction.members().size() == 2, "the roster actually grows (%d)" % PlayerFaction.members().size())
	check(PLAYER_ACTION_LEDGER.count("recruited_to_own_faction") == 1, "the accepted recruitment has one player-action receipt")

	var already := PlayerFaction.recruit("recruit_one")
	check(not bool(already.get("ok", false)), "recruiting the same person twice is refused")

	# --- U1.3: real standing, computed from who is actually in it ------------
	WorldHistory.register_subject("recruit_saintly", {"name": "Saintly Recruit", "kind": "person", "faction_id": "gate_lanterns", "bond": 90})
	PlayerFaction.recruit("recruit_saintly")
	check(PLAYER_ACTION_LEDGER.count("recruited_to_own_faction") == 2, "each distinct accepted recruit advances the same compact route once")
	var standing_with_saint := PlayerFaction.standing()
	check(standing_with_saint > 0.0, "recruiting someone who was ascending actually pulls the faction's own standing up (%.2f)" % standing_with_saint)

	# --- U1.4: it can lose people ---------------------------------------------
	var lost := PlayerFaction.lose_member("recruit_one", "killed in a raid")
	check(bool(lost.get("ok", false)), "losing a member succeeds")
	check(str(WorldHistory.subject("recruit_one").get("faction_id", "")) != PlayerFaction.FACTION_ID, "and they are actually no longer counted")
	check(PlayerFaction.members().size() == 2, "the roster actually shrinks (%d)" % PlayerFaction.members().size())
	var loss_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "own_faction_lost_member")
	check(not loss_events.is_empty() and str((loss_events[0].get("details", {}) as Dictionary).get("reason", "")) == "killed in a raid", "and the real reason is recorded, not just a disappearance")

	var lose_stranger := PlayerFaction.lose_member("recruit_one", "again")
	check(not bool(lose_stranger.get("ok", false)), "losing someone already gone is refused, not a silent no-op")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "founding, recruitment and loss all close their nested transactions")

	print("PLAYER_FACTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
