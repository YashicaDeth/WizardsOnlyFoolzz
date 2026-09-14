extends Node

## AJ5.6. "Freeing souls and enslaving them both have consequences, and they
## are different ones." A verdict is still only ever one god's opinion
## (AJ5.5, untouched) - this is the separate, real mechanical half: standing
## with the god that ruled actually moves, and it moves in opposite
## directions for the two outcomes.

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
	WorldHistory.register_subject("deep_demon", {"kind": "person", "faction_id": "celloutz"})
	WorldHistory.register_subject("deep_saint", {"kind": "person", "faction_id": "gate_lanterns", "bond": 90})
	WorldHistory.register_subject("killer", {"kind": "person"})

	print("AJ5.6 - before any verdict, standing is honestly zero")
	check(is_zero_approx(ModernGods.standing_with("the_market", "killer")), "no opinion has ever been rendered, so no standing exists yet")

	print("AJ5.6 - a FREED verdict actually raises standing with the god that ruled it")
	ModernGods.record_death_verdicts("deep_demon", "killer", {"harvested": true}, ["the_market"])
	var after_freed := ModernGods.standing_with("the_market", "killer")
	check(after_freed > 0.0, "standing genuinely rose (%.2f)" % after_freed)

	print("AJ5.6 - an ENSLAVED verdict actually lowers it - the opposite direction, not the same one")
	WorldHistory.register_subject("killer2", {"kind": "person"})
	ModernGods.record_death_verdicts("deep_saint", "killer2", {"harvested": true}, ["the_market"])
	var after_enslaved := ModernGods.standing_with("the_market", "killer2")
	check(after_enslaved < 0.0, "standing genuinely fell (%.2f)" % after_enslaved)
	check(after_freed != after_enslaved, "freeing and enslaving really are different consequences, not the same effect twice")

	print("AJ5.6 - it is per-killer, not a shared pool")
	check(ModernGods.standing_with("the_market", "killer") > 0.0, "the first killer's own standing was not touched by the second killer's verdict")

	print("AJ5.6 - repeated verdicts with the same god accumulate rather than reset")
	ModernGods.record_death_verdicts("deep_demon", "killer", {"harvested": true}, ["the_market"])
	check(ModernGods.standing_with("the_market", "killer") > after_freed, "a second freed verdict from the same god raises it further")

	print("AJ5.6 - it never runs away past a real bound")
	for _index in 20:
		ModernGods.record_death_verdicts("deep_demon", "killer", {"harvested": true}, ["the_market"])
	check(ModernGods.standing_with("the_market", "killer") <= 1.0, "standing is clamped, not an unbounded accumulator")

	print("AJ5.6 - an undecided verdict moves nothing - a real absence of opinion is not silently scored")
	WorldHistory.register_subject("killer3", {"kind": "person"})
	ModernGods._apply_consequence("the_market", "killer3", "UNDECIDED — EVEN THE MARKET HAS NO OPINION")
	check(is_zero_approx(ModernGods.standing_with("the_market", "killer3")), "an undecided god leaves standing exactly where it found it")

	print("MODERN_GODS_CONSEQUENCE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
