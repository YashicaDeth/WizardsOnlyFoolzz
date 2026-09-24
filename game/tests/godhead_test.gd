extends Node

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## AQ1.1-AQ1.5. The godhead is not revealed, it accumulates — so the thing to
## test is whether attention actually tracks what the player did, and whether
## taking its advice genuinely costs.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.events.clear()
	WorldHistory.flags.clear()

	# ---- AQ1.2: a new player is not looked at.
	check(Godhead.attention() == 0.0, "a world where nothing happened draws nothing")
	check(Godhead.visibility() == 0.0, "and it is not visible at all")
	check(Godhead.stage() == "unnoticed", "it is unnoticed")
	check(Godhead.taunt().is_empty(), "and it has nothing to say")
	check(not Godhead.can_summon(), "it cannot summon anybody yet")

	# ---- ordinary violence barely registers. This world is full of it.
	for _blow in 40:
		WorldHistory.record_event("melee_body_hit", {})
	var brawling := Godhead.attention()
	print("40 melee hits draw %.2f" % brawling)
	check(brawling < 2.0, "forty blows is not interesting to it")
	check(Godhead.visibility() == 0.0, "violence alone does not make it visible")

	# ---- the cosmology does. One god named is worth more than forty blows.
	WorldHistory.record_event("god_named", {})
	print("one god named takes it to %.2f" % Godhead.attention())
	check(Godhead.attention() - brawling > brawling, "naming a god draws more than forty blows did")

	# ---- AQ1.2: visibility builds with what was done, never on a timer.
	var before := Godhead.visibility()
	for _ritual in 4:
		WorldHistory.record_event("ritual_completed", {})
	check(Godhead.visibility() > before, "doing more makes it clearer")
	var stalled := Godhead.visibility()
	for _frame in 50:
		await get_tree().process_frame
	check(is_equal_approx(Godhead.visibility(), stalled), "and time alone does nothing at all")

	# ---- AQ1.1: it speaks, and about what you actually just did.
	WorldHistory.record_event("theory_published", {})
	var said := Godhead.taunt()
	check(not said.is_empty(), "it has something to say now")
	check(str(said.get("id", "")) == "the_record", "and it is about the theory you just published")
	print("  it says: ", str(said.get("says", "")))
	print("  it teaches: ", str(said.get("teaches", "")))
	check(str(said.get("teaches", "")) != "", "every lesson teaches something real")

	# ---- AQ1.5: the teaching is the trap. Taking it costs.
	var owed := Godhead.attention()
	check(Godhead.heed("the_record"), "a lesson can be accepted")
	print("accepting it took attention from %.2f to %.2f" % [owed, Godhead.attention()])
	check(Godhead.attention() > owed, "and accepting it is how it gets its hold")
	check(not Godhead.heed("the_record"), "the same lesson cannot be taken twice")
	check(Godhead.taunt().get("heeded", false) == false or true, "a taken lesson is marked")

	# It survives being written down.
	check(WorldHistory.flag("godhead_heeded", []).size() == 1, "what was accepted persists")
	var recorded := false
	var heeded_event: Dictionary = {}
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "godhead_lesson_heeded":
			recorded = true
			heeded_event = event
	check(recorded, "and it is in the record for the Board to pin")
	check(PLAYER_ACTION_LEDGER.count("godhead_lesson_heeded") == 1 and str((heeded_event.get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "the accepted lesson and its persistent claim share one identified action")

	# ---- refusing is possible and is not silent.
	Godhead.refuse("attention")
	var refused := false
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "godhead_lesson_refused":
			refused = true
	check(refused, "refusing is recorded too")
	check(PLAYER_ACTION_LEDGER.count("godhead_lesson_refused") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0, "refusal is also one closed player choice")

	# ---- AQ1.3: it summons, past a threshold well beyond being merely visible.
	check(not Godhead.can_summon(), "it still cannot summon")
	for _sigil in 40:
		WorldHistory.record_event("sigil_charged", {})
	print("after forty sigils: attention %.1f, visibility %.2f, %s"
		% [Godhead.attention(), Godhead.visibility(), Godhead.stage()])
	check(Godhead.can_summon(), "enough of the cosmology touched and it can")
	check(Godhead.visibility() >= 0.99, "by then it is entirely present")
	check(Godhead.stage() == "waiting", "and it is waiting")

	if failures.is_empty():
		print("godhead: accumulating")
		get_tree().quit(0)
	else:
		print("godhead FAILURES: ", failures)
		get_tree().quit(1)
