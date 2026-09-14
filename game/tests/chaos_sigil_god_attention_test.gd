extends Node

## AJ3.4. "Naming a god in an intent gets their attention, which is not
## always wanted." A stated intent that names one of `modern_gods.gd`'s real
## roster raises that god's own real `attention` the moment `resolve()` reads
## it — whether the sigil goes on to resolve, misfire or come out corrupted,
## because naming is what costs the attention, not a working that succeeded.

const ChaosSigil := preload("res://systems/chaos_sigil.gd")

var failures: Array[String] = []


func check(condition: bool, what: String) -> void:
	print("PASS " if condition else "FAIL ", what)
	if not condition:
		failures.append(what)


func _fired(intent: String, subject_id: String = "player") -> Dictionary:
	var charged: Dictionary = ChaosSigil.charge(intent, subject_id).get("sigil", {})
	WorldClock.pass_time(ChaosSigil.FORGET_HOURS + 1.0)
	return ChaosSigil.fire(charged).get("sigil", {})


func _attention(god_id: String) -> int:
	return int(WorldHistory.subject(god_id).get("attention", 0))


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "bond": 200.0})
	ModernGods.seed_gods()

	print("AJ3.4 - naming nothing gets no god's attention")
	var unnamed := ChaosSigil.resolve(_fired("i want to hurt the wrecker crew"), "player")
	check(bool((unnamed.get("named_gods", ["x"]) as Array).is_empty()), "an intent naming no god returns an empty named_gods list")
	for god_id in ModernGods.GODS:
		check(_attention(god_id) == 0, "%s's attention stays at zero when nobody named it" % god_id)

	print("AJ3.4 - naming a god that also resolves gets that god real attention")
	var engagement_result := ChaosSigil.resolve(_fired("i want to hurt the engagement for what it did"), "player")
	check(str(engagement_result.get("result", "")) == "resolved", "the sigil still resolves on its own real family match")
	check((engagement_result.get("named_gods", []) as Array).has("the_engagement"), "the_engagement is reported as named")
	check(_attention("the_engagement") == 1, "and its real attention actually rose (%d)" % _attention("the_engagement"))
	check(_attention("the_market") == 0, "a god never named is never touched")

	print("AJ3.4 - naming a god in a genuine miss still gets their attention")
	var miss_result := ChaosSigil.resolve(_fired("xyzzy the market plugh"), "player")
	check(str(miss_result.get("result", "")) == "misfired", "the intent still honestly misfires - it matched no family")
	check((miss_result.get("named_gods", []) as Array).has("the_market"), "but the_market was still named")
	check(_attention("the_market") == 1, "attention is not a reward for success - a miss still names the god (%d)" % _attention("the_market"))

	print("AJ3.4 - naming a god in a corrupted sigil still gets their attention")
	WorldHistory.register_subject("carrier", {"name": "OVERLOADED", "kind": "person", "bond": 200.0})
	for index in ChaosSigil.CARRY_CAPACITY:
		ChaosSigil.charge("hold this %d" % index, "carrier")
	var overcharged: Dictionary = ChaosSigil.charge("the quota owes me everything", "carrier").get("sigil", {})
	check(bool(overcharged.get("corrupted", false)), "this sigil really is the one that overcharged")
	WorldClock.pass_time(ChaosSigil.FORGET_HOURS + 1.0)
	var overcharge_result := ChaosSigil.resolve(ChaosSigil.fire(overcharged).get("sigil", {}), "carrier")
	check(str(overcharge_result.get("result", "")) == "misfired", "a corrupted sigil always misfires regardless of its own words")
	check((overcharge_result.get("named_gods", []) as Array).has("the_quota"), "but naming the_quota still counted even inside a corrupted working")
	check(_attention("the_quota") == 1, "and its attention still rose (%d)" % _attention("the_quota"))

	print("AJ3.4 - an intent naming two gods raises both, once each")
	ChaosSigil.resolve(_fired("let the market and the brand both notice me"), "player")
	check(_attention("the_market") == 2, "the_market's attention rose again from the second naming (%d)" % _attention("the_market"))
	check(_attention("the_brand") == 1, "the_brand got its own first mention counted too (%d)" % _attention("the_brand"))

	print("CHAOS_SIGIL_GOD_ATTENTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
