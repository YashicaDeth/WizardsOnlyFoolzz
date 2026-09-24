extends Node

## Calling (Greg, 24 September): phoning people you have met to invite or
## summon them, like The Sims. Locked until the call emitter is installed; who
## answers comes from the record, and every call is written down.

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
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "anatomy": {"cybernetics": []},
		"relations": {"nix_arden": {"kind": "bond", "strength": 22}},
	})
	WorldHistory.register_subject("nix_arden", {"name": "Nix Arden", "kind": "person", "status": "waiting"})
	WorldHistory.register_subject("ash_captain", {"name": "The Captain", "kind": "person", "relations": {"player": {"kind": "grudge", "strength": -40}}})
	WorldHistory.register_subject("rook_sable", {"name": "Rook Sable", "kind": "person", "status": "unlocated"})
	WorldHistory.register_subject("old_friend", {"name": "Old Friend", "kind": "person", "met_player": true, "status": "dead"})
	WorldHistory.register_subject("guard_hollis", {"name": "Hollis", "kind": "person", "status": "on post"})
	WorldHistory.register_subject("gate_lanterns", {"name": "Gate Lanterns", "kind": "faction", "relations": {"player": {"strength": 10}}})
	PlayerActionLedger.record("facility_guard_coerced", {"subject_id": "guard_hollis", "location": "service_arcade"})
	# A world update naming someone is not the player meeting them.
	WorldHistory.update_subject("rook_sable", {"status": "moving"})

	check(not Calling.unlocked(), "no emitter, no calling")
	var refused := Calling.invite("nix_arden")
	check(not bool(refused.get("ok", true)) and str(refused.get("reason", "")) == "NO CALL IMPLANT", "a call without the implant is refused outright")

	var installed := Calling.install_emitter("test")
	check(bool(installed.get("ok", false)) and Calling.unlocked(), "installing the emitter unlocks calling")
	check(not bool(Calling.install_emitter("test").get("ok", true)), "it cannot go in twice")
	var cybernetics: Array = WorldHistory.subject("player").get("anatomy", {}).get("cybernetics", [])
	check(cybernetics.any(func(entry): return entry is Dictionary and str(entry.get("zone", "")) == "head" and str(entry.get("id", "")) == Calling.IMPLANT_ID), "it sits on the body's cybernetics list, in the head")
	check(WorldHistory.event_count("call_implant_installed") == 1, "the install is recorded")

	var ids: Array = Calling.contacts().map(func(row): return str(row.id))
	check(ids.has("nix_arden"), "someone you are bonded with is a contact")
	check(ids.has("ash_captain"), "someone who hates you is a contact")
	check(ids.has("guard_hollis"), "the guard you coerced is a contact")
	check(ids.has("old_friend"), "someone flagged as met is a contact")
	check(not ids.has("rook_sable"), "someone you have only heard of is not")
	check(not ids.has("gate_lanterns") and not ids.has("player"), "factions and yourself are not")
	check(not bool(Calling.invite("rook_sable").get("ok", true)), "a stranger cannot be called")

	var nix := Calling.invite("nix_arden")
	check(bool(nix.ok) and nix.outcome == Calling.ACCEPTED and not str(nix.line).is_empty() and bool(nix.placeholder), "a friend accepts, with a placeholder line")
	check(str(WorldHistory.subject("nix_arden").get("called_by_player", "")) == Calling.INVITE, "the accepted invite is on their record")
	var captain := Calling.invite("ash_captain")
	check(captain.outcome == Calling.REFUSED and captain.reason == "hostile", "an enemy refuses")
	check(Calling.invite("ash_captain").reason == "screened", "and does not pick up again for a while")
	check(Calling.invite("old_friend").outcome == Calling.NO_ANSWER and Calling.invite("old_friend").reason == "dead", "the dead do not answer")
	check(Calling.invite("guard_hollis").outcome == Calling.NO_ANSWER, "an acquaintance lets it ring out")
	var summoned := Calling.summon("nix_arden")
	check(summoned.outcome == Calling.REFUSED and summoned.reason == "summon_refused", "a friend does not come because you whistle")
	check(Calling.calls().size() >= 6 and WorldHistory.event_count("npc_called") == Calling.calls().size(), "every call is logged and recorded")
	print("CALLING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
