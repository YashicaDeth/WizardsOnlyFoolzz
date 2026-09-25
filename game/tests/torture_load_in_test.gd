extends Node

## Greg, 25 September: loading in is being tortured. Black first, screams
## through fluid, the gag, the broadcast line three times and worse each time,
## the glitch, then the room. Nothing behind it runs until it hands over, and
## F cuts straight to the glitch.

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
	TortureLoadIn.force_in_tests = true
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var load_in = vat.load_in
	check(load_in != null and is_instance_valid(load_in), "a new game opens on the load-in")
	check(vat.intake.process_mode == Node.PROCESS_MODE_DISABLED, "the form waits behind it")
	check(load_in.get_index() == load_in.get_parent().get_child_count() - 1, "it sits over the whole HUD")
	vat._physics_process(0.5)
	check(vat.arrival_clock == 0.0, "the examiner does not arrive in the black")
	var texts: Array[String] = []
	var t := 0.0
	while t < 10.7:
		load_in.step(0.05)
		t += 0.05
		var line: String = load_in.broadcast_text()
		if line.length() > 40 and not texts.has(line):
			texts.append(line)
	check(load_in.played.count("scream") == 3, "three screams through the fluid (%d)" % load_in.played.count("scream"))
	check(load_in.played.has("gag") and load_in.played.has("tube"), "the gag goes in and the breathing goes to the tube")
	check(load_in.played.count("broadcast") == 3, "the broadcast repeats three times")
	check(texts.any(func(x): return x.begins_with("HUNDREDS OF YEARS OF THE PERPETUAL POST-APOCALYPSE")), "the first pass is whole")
	check(texts.any(func(x): return x.contains("#") or x.contains("/") or x.contains("_")), "later passes degrade")
	load_in.step(0.2)
	check(load_in.played.has("glitch"), "it glitches out")
	for i in 60:
		if not is_instance_valid(load_in) or load_in.done:
			break
		load_in.step(0.05)
	check(vat.load_in == null, "then hands over to the room")
	check(vat.intake.process_mode == Node.PROCESS_MODE_INHERIT, "and the form runs")
	vat._physics_process(0.5)
	check(vat.arrival_clock > 0.0, "and the examiner comes in")
	check(WorldHistory.event_count("torture_load_in") == 1, "the load-in is recorded")
	vat.queue_free()
	await get_tree().process_frame

	WorldHistory.clear_history()
	var again = load("res://vat_chamber.tscn").instantiate()
	add_child(again)
	await get_tree().process_frame
	var fast = again.load_in
	fast.step(0.3)
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	fast._unhandled_input(key)
	check(fast.skipped and fast.played.has("glitch"), "F cuts straight to the glitch")
	for i in 60:
		if not is_instance_valid(fast) or fast.done:
			break
		fast.step(0.05)
	check(again.load_in == null, "and still hands over through it")
	check(WorldHistory.event_count("torture_load_in") == 1, "the skip is recorded")
	TortureLoadIn.force_in_tests = false
	print("TORTURE_LOAD_IN_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
