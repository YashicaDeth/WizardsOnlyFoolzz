extends Node

## E1. The Ascent/Descent axis has been computed, stored and drawn since the
## dossier was built, and until now nothing moved it but the faction you were
## born into. The claim here is that what you actually do is what puts you on
## it — and that it still never becomes a good/evil slider with a number on it.

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

	var born := WorldHistory.tree_alignment(WorldHistory.subject("player"))
	check(is_equal_approx(born, 0.0), "an unaffiliated newcomer starts in Limbo")

	# --- acts move you, and inert acts do not ------------------------------
	WorldHistory.record_event("weapon_fired", {"weapon": "shotgun"})
	WorldHistory.record_event("player_dodged", {})
	check(is_equal_approx(WorldHistory.tree_alignment(WorldHistory.subject("player")), 0.0), "swinging and missing is not a moral act")

	WorldHistory.record_event("npc_resolution", {"subject_id": "a", "outcome": "execute", "actor": "player"})
	var after_kill := WorldHistory.tree_alignment(WorldHistory.subject("player"))
	check(after_kill < 0.0, "executing somebody who was already down pulls you down (%.3f)" % after_kill)

	WorldHistory.record_event("npc_resolution", {"subject_id": "b", "outcome": "spare", "actor": "player"})
	check(WorldHistory.tree_alignment(WorldHistory.subject("player")) > after_kill, "sparing the next one pulls back up")

	# --- the ladder is climbable and fallable, but not instantly ------------
	for index in 12:
		WorldHistory.record_event("npc_resolution", {"subject_id": "v%d" % index, "outcome": "execute", "actor": "player"})
	var sunk := WorldHistory.tree_alignment(WorldHistory.subject("player"))
	check(sunk <= -0.5, "a career of it sinks you (%.2f)" % sunk)
	check(WorldHistory.tree_axis_label(sunk) == "DESCENT", "and the Tree reads it as DESCENT without a number")
	check(sunk >= -1.0, "the axis never leaves the wheel")

	# --- robbing, and whether they were alive to feel it --------------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER"})
	WorldHistory.record_event("part_extracted", {"subject_id": "x", "owner_alive": false})
	var corpse_karma := float(WorldHistory.subject("player").get("karma", 0.0))
	WorldHistory.record_event("part_extracted", {"subject_id": "y", "owner_alive": true})
	var living_karma := float(WorldHistory.subject("player").get("karma", 0.0))
	check(corpse_karma < 0.0, "robbing a corpse costs something")
	check(living_karma - corpse_karma < corpse_karma, "cutting it out of someone still alive costs more")

	# --- silencing a witness is the worst thing in the table ----------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {})
	WorldHistory.record_event("report_cut", {"subject": "witness", "reports": 1})
	check(float(WorldHistory.subject("player").get("karma", 0.0)) <= -0.1, "killing the one who saw it is the heaviest single act")

	# --- what you did outweighs where you were born ------------------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("saint", {"faction_id": "ashline_wreckers", "name": "Born Wrong"})
	var birth := WorldHistory.tree_alignment(WorldHistory.subject("saint"))
	check(birth < 0.0, "an Ashline birth starts you below the line (%.2f)" % birth)
	for index in 14:
		WorldHistory.record_event("npc_resolution", {"subject_id": "s%d" % index, "outcome": "spare", "actor": "saint"})
	var redeemed := WorldHistory.tree_alignment(WorldHistory.subject("saint"))
	check(redeemed > birth, "a life of sparing people climbs out of it (%.2f -> %.2f)" % [birth, redeemed])
	check(redeemed > 0.0, "far enough to cross into Ascent, because lineage is not destiny")

	# --- the log is a window; the karma is what it made of you --------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {})
	WorldHistory.record_event("npc_resolution", {"subject_id": "old", "outcome": "execute", "actor": "player"})
	var remembered := float(WorldHistory.subject("player").get("karma", 0.0))
	check(is_equal_approx(WorldHistory.karma_from_history("player"), remembered), "while the act is still in the log, both readings agree")
	for index in WorldHistory.MAX_EVENTS + 5:
		WorldHistory.record_event("weapon_fired", {"weapon": "sidearm"})
	check(is_equal_approx(float(WorldHistory.subject("player").get("karma", 0.0)), remembered), "and the act still counts after it falls out of the log")
	check(WorldHistory.karma_from_history("player") > remembered, "even though the log itself has forgotten it")

	print("KARMA_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
