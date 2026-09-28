extends Node

## Greg, 26 September: minutes 0-30 are timed, hidden, and shown per area on a
## card when you surface.

const RUN_TIMER := preload("res://systems/run_timer.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func backdate(seconds: float) -> void:
	var run := RUN_TIMER.record()
	WorldHistory.amend_subject(RUN_TIMER.SUBJECT, {"started": float(run.started) - seconds})


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	check(not RUN_TIMER.running(), "no run before the vat room")
	RUN_TIMER.start()
	RUN_TIMER.enter("growing_floor")
	backdate(300.0)
	RUN_TIMER.enter("service_arcade")
	RUN_TIMER.enter("service_arcade")
	backdate(240.0)
	# A death: the vat room loads again mid-run.
	RUN_TIMER.start()
	check(RUN_TIMER.elapsed() >= 539.0, "a rebirth does not restart the clock (%.0fs)" % RUN_TIMER.elapsed())
	RUN_TIMER.enter("growing_floor")
	backdate(60.0)
	RUN_TIMER.enter("lower_works")
	backdate(600.0)
	var summary := RUN_TIMER.finish()
	var rows: Array = summary.rows
	check(rows.size() == 4, "one row per area entered, repeats in a row merged (%d)" % rows.size())
	check(str(rows[0].label) == "GROWING FLOOR" and absf(float(rows[0].seconds) - 300.0) < 2.0, "growing floor 5:00 (%s)" % RUN_TIMER.clock(rows[0].seconds))
	check(str(rows[1].label) == "SERVICE ARCADE" and absf(float(rows[1].seconds) - 240.0) < 2.0, "service arcade 4:00")
	check(absf(float(summary.total) - 1200.0) < 3.0 and bool(summary.under_target), "20:00 total, under the 30 (%s)" % RUN_TIMER.clock(summary.total))
	check(RUN_TIMER.finish().is_empty(), "a finished run does not end twice")
	check(RUN_TIMER.clock(1805.0) == "30:05", "clock reads minutes:seconds")

	# Surfacing: the Hunt shows the card only for a run that was open.
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	check(hunt.find_children("*", "RunCard", true, false).is_empty() and _cards(hunt) == 0, "starting the Hunt directly shows no card")
	hunt.queue_free()
	await get_tree().process_frame
	RUN_TIMER.start()
	RUN_TIMER.enter("growing_floor")
	backdate(90.0)
	var surfaced = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(surfaced)
	await get_tree().process_frame
	# Greg, 28 September: the payoff first (daylight, wind, title, keys), then
	# the run card.
	var payoff = surfaced.get_node_or_null("Surfacing")
	check(payoff != null, "surfacing plays the payoff: daylight, wind, the title, the keys")
	check(_cards(surfaced) == 0, "the run card waits for it")
	payoff.clock = payoff.KEYS_AT + payoff.KEYS_HOLD
	await get_tree().process_frame
	await get_tree().process_frame
	check(_cards(surfaced) == 1, "surfacing from a run shows the card")
	check(payoff._wind.playing, "and the wind is up")
	check(not RUN_TIMER.running() and WorldHistory.event_count("opening_run_finished") == 1, "and the run is closed on record")
	print("RUN_TIMER_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _cards(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child.get_script() == preload("res://systems/run_card.gd"):
			count += 1
	return count
