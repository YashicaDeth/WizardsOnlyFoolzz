extends Node

## AJ2.1-AJ2.3, AJ2.5. What a fired sigil actually does: effects parsed from
## the stated intent against broad word families (never a spell list), a
## real miss when nothing matches, the same glyph hitting harder the more it
## has genuinely worked, and corruption when a caster charges past what
## chaos_pending says they can carry.

const ChaosSigil := preload("res://systems/chaos_sigil.gd")
const Boons := preload("res://systems/boons.gd")

var failures: Array[String] = []


func check(condition: bool, what: String) -> void:
	print("PASS " if condition else "FAIL ", what)
	if not condition:
		failures.append(what)


func _fired(intent: String, subject_id: String = "player") -> Dictionary:
	var charged: Dictionary = ChaosSigil.charge(intent, subject_id).get("sigil", {})
	WorldClock.pass_time(ChaosSigil.FORGET_HOURS + 1.0)
	return ChaosSigil.fire(charged).get("sigil", {})


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "bond": 200.0})

	print("AJ2.1 - effects come from real words in the intent, not a spell list")
	var violent := _fired("i want to hurt the wrecker crew")
	var result := ChaosSigil.resolve(violent, "player")
	check(bool(result.get("ok", false)), "a matched intent resolves")
	check(str(result.get("result", "")) == "resolved", "and actually resolves rather than misfiring")
	check(str(result.get("family", "")) == "violence", "matched to the family the words actually belong to (%s)" % str(result.get("family", "")))
	check(Boons.stat_bonus("player", "combat_power") > 0.0, "a real, readable boon landed on the exact stat the family names")

	print("AJ2.2 - an intent that matches nothing is a real miss, not a silent success")
	var unfired := _fired("xyzzy plugh qwzx")
	var miss := ChaosSigil.resolve(unfired, "player")
	check(bool(miss.get("ok", false)), "resolving a miss is not an error - it is a real outcome")
	check(str(miss.get("result", "")) == "misfired", "and is honestly labelled as one")
	var corruption_after_miss := float(WorldHistory.subject("player").get("chaos_corruption", 0.0))
	check(corruption_after_miss > 0.0, "a miss leaves something behind - real corruption, not nothing (%.1f)" % corruption_after_miss)

	print("AJ2.1 - a resolved sigil cannot resolve twice")
	var refire := ChaosSigil.resolve(result.get("sigil", {}), "player")
	check(not bool(refire.get("ok", false)) and str(refire.get("reason", "")) == "ALREADY RESOLVED", "resolving is a one-time event, same as firing already is")

	print("AJ2.3 - the same glyph genuinely gets stronger the more it has worked")
	var first_hit := _fired("hurt them again")
	var first_result := ChaosSigil.resolve(first_hit, "player")
	var first_magnitude := float(first_result.get("magnitude", 0.0))
	var second_hit := _fired("hurt them again")
	var second_result := ChaosSigil.resolve(second_hit, "player")
	var second_magnitude := float(second_result.get("magnitude", 0.0))
	check(int(first_hit.get("seed", -1)) == int(second_hit.get("seed", -2)), "same intent really does mean the same glyph (seed)")
	check(second_magnitude > first_magnitude, "the second real working of the same glyph hits harder (%.3f vs %.3f)" % [second_magnitude, first_magnitude])
	var different_glyph := _fired("hide from them instead")
	var different_result := ChaosSigil.resolve(different_glyph, "player")
	check(float(different_result.get("magnitude", 0.0)) < second_magnitude, "a genuinely different glyph does not inherit the first one's earned strength")

	print("AJ2.5 - charging more than you can carry corrupts the overcharged sigil")
	WorldHistory.clear_history()
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("carrier", {"name": "OVERLOADED", "kind": "person", "bond": 200.0})
	var carried: Array[Dictionary] = []
	for index in ChaosSigil.CARRY_CAPACITY:
		carried.append(ChaosSigil.charge("hold this %d" % index, "carrier").get("sigil", {}))
	for sigil in carried:
		check(not bool(sigil.get("corrupted", false)), "within carry capacity, nothing is corrupted yet")
	var overcharged: Dictionary = ChaosSigil.charge("kill them all, one too many", "carrier").get("sigil", {})
	check(bool(overcharged.get("corrupted", false)), "the sigil that pushed past capacity comes out corrupted")

	WorldClock.pass_time(ChaosSigil.FORGET_HOURS + 1.0)
	var overcharged_fired: Dictionary = ChaosSigil.fire(overcharged).get("sigil", {})
	var overcharge_result := ChaosSigil.resolve(overcharged_fired, "carrier")
	check(str(overcharge_result.get("result", "")) == "misfired", "a corrupted sigil always misfires, even naming a real family")
	check(str(overcharge_result.get("family", "z")) == "", "a corrupted sigil's own words never get to matter")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "successful and misfired resolutions both close their nested effect transaction")

	print("CHAOS_SIGIL_RESOLVE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
