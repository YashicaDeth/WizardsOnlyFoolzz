extends Node

## E8. A held state, real elapsed time paying down pain and nothing else,
## a real cost for being interrupted, and reaching the entity layer only by
## time actually held.

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "anatomy_state": {"pain": 40.0}})
	AscentEntities.seed_entities()

	check(not Meditation.is_meditating("player"), "starts not meditating")
	var refused_tick := Meditation.tick("player", 1.0)
	check(not bool(refused_tick.get("ok", false)), "ticking before beginning is refused, not a silent no-op")
	var refused_end := Meditation.end("player")
	check(not bool(refused_end.get("ok", false)), "ending before beginning is refused")

	# --- E8.1/E8.4: a held state, with real context captured at the start ---
	var began := Meditation.begin("player", {"signal_grade": 1, "territory": "bone_yard_pit", "nearby": ["mara_voss"]})
	check(bool(began.get("ok", false)), "beginning succeeds")
	check(Meditation.is_meditating("player"), "and is now a real held state")
	var again := Meditation.begin("player")
	check(not bool(again.get("ok", false)), "beginning again on top of an existing session is refused")
	check(str(WorldHistory.subject("player").get("meditation_context", {}).get("territory", "")) == "bone_yard_pit", "the context is really recorded, not discarded")

	# --- E8.2/E8.6: real time pays down pain, and only pain -----------------
	var before_pain := float(WorldHistory.subject("player").get("anatomy_state", {}).get("pain", 0.0))
	var tick_result := Meditation.tick("player", 5.0)
	check(bool(tick_result.get("ok", false)), "ticking while held succeeds")
	var after_pain := float(WorldHistory.subject("player").get("anatomy_state", {}).get("pain", 0.0))
	check(after_pain < before_pain, "pain actually pays down (%.1f -> %.1f)" % [before_pain, after_pain])
	check(is_equal_approx(after_pain, before_pain - Meditation.PAIN_RATE * 5.0), "at exactly the stated rate, not an arbitrary amount")
	check(float(tick_result.get("stamina_multiplier", 0.0)) > 1.0, "a real stamina multiplier is offered for whoever owns the live value")
	check(not WorldHistory.subject("player").get("anatomy_state", {}).has("blood") or float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0)) == 5000.0, "it costs no blood — the only route that costs the body nothing")

	# --- E8.5: deep enough, it reaches the entity layer ----------------------
	check(not tick_result.has("glimpsed"), "a five-second sit does not reach the entity layer yet")
	var deep_tick := Meditation.tick("player", Meditation.ENTITY_THRESHOLD_SECONDS)
	check(deep_tick.has("glimpsed") and AscentEntities.ENTITIES.has(str(deep_tick.glimpsed)), "deep enough, it actually glimpses a real entity")
	check(not bool(WorldHistory.subject(str(deep_tick.glimpsed)).get("has_noticed", false)), "and it is a glimpse, not regard() — no attention spent")

	# --- E8.3: interrupted is worse than never started -----------------------
	Meditation.end("player")
	WorldHistory.amend_subject("player", {"anatomy_state": {"pain": 10.0}})
	Meditation.begin("player")
	Meditation.tick("player", 20.0)
	var pain_before_interrupt := float(WorldHistory.subject("player").get("anatomy_state", {}).get("pain", 0.0))
	var interrupted := Meditation.interrupt("player", "hit by a wrecker")
	check(bool(interrupted.get("ok", false)), "interrupting a real session succeeds")
	check(not Meditation.is_meditating("player"), "and it actually ends the held state")
	var pain_after_interrupt := float(WorldHistory.subject("player").get("anatomy_state", {}).get("pain", 0.0))
	check(pain_after_interrupt > pain_before_interrupt, "interruption actually costs pain — worse than never having started (%.1f -> %.1f)" % [pain_before_interrupt, pain_after_interrupt])

	# --- a clean, voluntary end costs nothing ---------------------------------
	Meditation.begin("player")
	var pain_before_clean_end := float(WorldHistory.subject("player").get("anatomy_state", {}).get("pain", 0.0))
	var ended := Meditation.end("player")
	check(bool(ended.get("ok", false)), "a clean end succeeds")
	var pain_after_clean_end := float(WorldHistory.subject("player").get("anatomy_state", {}).get("pain", 0.0))
	check(is_equal_approx(pain_before_clean_end, pain_after_clean_end), "and costs nothing — only interruption does")

	print("MEDITATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
