extends Node

## AJ4.1/AJ4.3. "Skill is what you have actually done, read off the record"
## and "a practice you stop practising decays." skill_level() counts real
## sigil_resolved events for a family inside a trailing window of WorldClock
## time - nothing invented, nothing pruned on a timer, just a window that
## moves and lets old workings age out of it on their own.

const ChaosSigil := preload("res://systems/chaos_sigil.gd")

var failures: Array[String] = []


func check(condition: bool, what: String) -> void:
	print("PASS " if condition else "FAIL ", what)
	if not condition:
		failures.append(what)


func _work(intent: String, subject_id: String) -> void:
	var charged: Dictionary = ChaosSigil.charge(intent, subject_id).get("sigil", {})
	WorldClock.pass_time(ChaosSigil.FORGET_HOURS + 1.0)
	var fired: Dictionary = ChaosSigil.fire(charged).get("sigil", {})
	ChaosSigil.resolve(fired, subject_id)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "bond": 500.0})

	print("AJ4.1 - untouched, no skill exists yet")
	check(ChaosSigil.skill_level("player", "violence") == 0, "a family never worked has no skill in it")

	print("AJ4.1 - skill is a real count of what actually happened")
	_work("hurt one", "player")
	_work("hurt two", "player")
	_work("hurt three", "player")
	check(ChaosSigil.skill_level("player", "violence") == 3, "three real successful workings, three counted (%d)" % ChaosSigil.skill_level("player", "violence"))
	check(ChaosSigil.skill_level("player", "sight") == 0, "a different family the caster never worked stays at zero")

	print("AJ4.1 - a miss never counts as skill")
	_work("qwzx plugh", "player")
	check(ChaosSigil.skill_level("player", "violence") == 3, "a misfire in an unrelated attempt does not inflate a real family's count")

	print("AJ4.3 - a practice not kept up genuinely decays out of the record")
	# The three violence workings and the miss above are already spread across
	# real WorldClock time - each fire had to pass its own forget gate - so by
	# now the *newest* violence working is FORGET_HOURS+1 hours old.
	WorldClock.pass_time(ChaosSigil.SKILL_DECAY_HOURS - (ChaosSigil.FORGET_HOURS + 1.0) - 1.0)
	check(ChaosSigil.skill_level("player", "violence") > 0, "at least the most recent working is still inside the window")
	WorldClock.pass_time(2.0)
	check(ChaosSigil.skill_level("player", "violence") == 0, "past the window, even the most recent working has genuinely aged out")

	print("AJ4.3 - working it again after the gap starts the count fresh, for real")
	_work("hurt again after the gap", "player")
	check(ChaosSigil.skill_level("player", "violence") == 1, "a real new working counts again, from where the record actually is")

	print("CHAOS_SIGIL_SKILL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
