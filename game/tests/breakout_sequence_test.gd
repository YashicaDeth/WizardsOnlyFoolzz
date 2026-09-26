extends Node

## Greg, 25 September: he leaves, the screaming starts, the sigil takes your
## brain, shrinks to a motherboard, gets hacked, BRAIN HACKED / SOUL
## OVERTAKEN; your hands rip the cord out of your mouth; three blows and the
## glass goes.

const BREAKOUT := preload("res://systems/breakout_sequence.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(target, code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	target._unhandled_input(e)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	BREAKOUT.force_in_tests = true
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing() if vat.intake.has_method("_finish_filing") else null
	await get_tree().process_frame
	vat.phase = "departure"
	vat._update_departure(10.0)
	check(vat.phase == "hacked", "his door shuts and the hack begins (%s)" % vat.phase)
	var b = vat.breakout
	b.set_process(false)
	var biggest := 0.0
	var smallest_after := 9.0
	for i in 140:
		b.step(0.05)
		if b.clock < b.RUNE_FULL + 0.05:
			biggest = maxf(biggest, b.rune_scale())
		elif b.mode == "hack":
			smallest_after = minf(smallest_after, b.rune_scale())
	check(b.played.has("scream"), "the screaming starts")
	check(biggest > 1.0, "the rune fills the frame (%.2f)" % biggest)
	check(smallest_after < 0.6, "then shrinks into the die (%.2f)" % smallest_after)
	check(vat.phase == "submerged", "and hands back to the tank")
	check(str(vat.mission_card.text) == "BRAIN HACKED SOUL OVERTAKEN", "the card reads BRAIN HACKED / SOUL OVERTAKEN")
	check(WorldHistory.event_count("brain_hacked") == 1, "the hack is recorded")

	vat.phase = "departure"
	vat._update_departure(10.0)
	b.step(0.3)
	key(vat, KEY_F)
	b.step(0.01)
	b.step(0.5)
	check(vat.phase == "submerged" and b.skipped, "F skips the hack (speedrunners)")

	vat._begin_cord()
	check(vat.phase == "cord", "after GET REVENGE your hands come up")
	key(vat, KEY_E)
	for i in 40:
		b.step(0.05)
	check(vat.phase == "smash" and WorldHistory.event_count("opening_cord_ripped") == 1, "E rips the cord out of your mouth")
	key(vat, KEY_E)
	check(not vat.breakout_complete and b.blows == 1, "one blow cracks it")
	key(vat, KEY_E)
	check(not vat.breakout_complete and b.blows == 2, "two blows")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	vat._unhandled_input(click)
	check(vat.phase == "floor", "the third takes it out (a click works too)")
	check(WorldHistory.event_count("opening_glass_hit") == 3 and WorldHistory.event_count("opening_tank_breached") == 1, "every blow and the breach are recorded")
	BREAKOUT.force_in_tests = false
	print("BREAKOUT_SEQUENCE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
