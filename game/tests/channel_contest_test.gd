extends Node

## K4.4. A Sin holds signal, not a keep — each of the five routes must be a
## real requirement against real state, not a cost paid to a menu.

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
	WorldHistory.register_subject("vanity_row", {
		"name": "Vanity Row", "kind": "faction", "channel": "A beauty pageant broadcast for augments.",
		"relations": {"cass_lumen": {"kind": "command", "strength": 55}},
	})
	WorldHistory.register_subject("cass_lumen", {"name": "Cass Lumen", "kind": "person", "faction_id": "vanity_row", "elo": 1000})
	WorldHistory.register_subject("no_channel_faction", {"name": "Nothing To Take", "kind": "faction"})

	var wire := WireNet.new()

	check(is_equal_approx(wire.faction_signal_control("vanity_row"), 100.0), "an uncontested channel starts fully held")

	var no_channel := wire.contest_channel("no_channel_faction", "flood")
	check(not bool(no_channel.get("ok", false)), "a faction with no channel cannot be contested at all")

	# --- out-publish requires actually out-reaching them ---------------------
	var too_weak := wire.contest_channel("vanity_row", "out_publish")
	check(not bool(too_weak.get("ok", false)), "out-publishing refuses a player who does not yet out-reach the channel")

	# A real reach advantage (a strong bond edge counts as influence, per
	# _build_account) rather than an invented number, so the success case
	# proves the same gate, the other way.
	WorldHistory.update_subject("player", {"relations": {"someone": {"kind": "bond", "strength": 200}}})
	wire.rebuild()
	var out_published := wire.contest_channel("vanity_row", "out_publish")
	check(bool(out_published.get("ok", false)), "and succeeds once the player genuinely out-reaches the channel")
	check(wire.faction_signal_control("vanity_row") < 100.0, "and actually reduces signal control")

	# --- discredit requires real evidence, not a click ----------------------
	var no_evidence := wire.contest_channel("vanity_row", "discredit")
	check(not bool(no_evidence.get("ok", false)), "discredit refuses with nothing traced")
	wire.act("cass_lumen", "trace")
	var control_before_discredit := wire.faction_signal_control("vanity_row")
	var with_evidence := wire.contest_channel("vanity_row", "discredit")
	check(bool(with_evidence.get("ok", false)), "and succeeds once a real trace exists on one of its own people")
	check(wire.faction_signal_control("vanity_row") < control_before_discredit, "and actually reduces signal control (%.0f -> %.0f)" % [control_before_discredit, wire.faction_signal_control("vanity_row")])

	# --- hijack/cut require physical access, not a flag you can skip --------
	var hijack_denied := wire.contest_channel("vanity_row", "hijack", "player", false)
	check(not bool(hijack_denied.get("ok", false)), "hijack refuses without physical access")
	var hijack_granted := wire.contest_channel("vanity_row", "hijack", "player", true)
	check(bool(hijack_granted.get("ok", false)), "and succeeds once physically present at the terminal")

	var cut_denied := wire.contest_channel("vanity_row", "cut", "player", false)
	check(not bool(cut_denied.get("ok", false)), "cut refuses without physical access")
	var cut_granted := wire.contest_channel("vanity_row", "cut", "player", true)
	check(bool(cut_granted.get("ok", false)) and is_equal_approx(wire.faction_signal_control("vanity_row"), 0.0), "cut, once done, removes coverage entirely")

	# --- flood is a denial move, always available, never a full capture -----
	WorldHistory.amend_subject("vanity_row", {"signal_control": 100.0})
	var flooded := wire.contest_channel("vanity_row", "flood")
	check(bool(flooded.get("ok", false)) and wire.faction_signal_control("vanity_row") > 0.0 and wire.faction_signal_control("vanity_row") < 100.0, "flood dents control without ever zeroing it in one pass")

	# --- every real contest is a recorded event, not a silent number change -
	var contest_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "channel_contested")
	check(contest_events.size() >= 3, "every successful contest is a real recorded event (%d)" % contest_events.size())

	# --- FACTIONS.md step 7: the propagation-gating factor is a real 0-1 read
	WorldHistory.amend_subject("vanity_row", {"signal_control": 0.0})
	check(is_equal_approx(wire.signal_reach_factor("vanity_row"), 0.0), "a fully cut channel gates propagation down to nothing")
	WorldHistory.amend_subject("vanity_row", {"signal_control": 40.0})
	check(is_equal_approx(wire.signal_reach_factor("vanity_row"), 0.4), "a half-flooded-ish channel carries a rumour proportionally, not all-or-nothing")

	# --- K4.6 v2: the Sin acts on the world — its own captain remembers ------
	var grudge_before := int(WorldHistory.subject("cass_lumen").get("grudge", 0))
	WorldHistory.amend_subject("vanity_row", {"signal_control": 100.0})
	wire.contest_channel("vanity_row", "flood", "player")
	var grudge_after_flood := int(WorldHistory.subject("cass_lumen").get("grudge", 0))
	check(grudge_after_flood > grudge_before, "flooding Vanity Row's channel actually raises Cass Lumen's grudge (%d -> %d)" % [grudge_before, grudge_after_flood])

	wire.contest_channel("vanity_row", "cut", "player", true)
	var grudge_after_cut := int(WorldHistory.subject("cass_lumen").get("grudge", 0))
	check(grudge_after_cut > grudge_after_flood, "and cutting the mast entirely is remembered harder than flooding it (%d > %d)" % [grudge_after_cut, grudge_after_flood])

	var refused := wire.contest_channel("vanity_row", "hijack", "player", false)
	check(not bool(refused.get("ok", false)), "a refused contest attempt")
	check(int(WorldHistory.subject("cass_lumen").get("grudge", 0)) == grudge_after_cut, "does not also raise grudge — only a contest that actually landed is remembered")

	var player_contests := WorldHistory.events.filter(func(e: Dictionary) -> bool:
		return str(e.get("type", "")) == "channel_contested" and str((e.get("details", {}) as Dictionary).get("subject_id", "")) == "player")
	check(player_contests.size() == PLAYER_ACTION_LEDGER.count("channel_contested") and player_contests.all(func(e: Dictionary) -> bool: return str((e.get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_")), "every landed player contest has exactly one durable action receipt")
	var receipts_before_npc := PLAYER_ACTION_LEDGER.count("channel_contested")
	var npc_contest := wire.contest_channel("vanity_row", "flood", "cass_lumen")
	check(bool(npc_contest.get("ok", false)) and PLAYER_ACTION_LEDGER.count("channel_contested") == receipts_before_npc, "a non-player channel move remains a world event rather than a counterfeit player action")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "signal control, public fact and retaliation grudges close one nested transaction")

	print("CHANNEL_CONTEST_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
