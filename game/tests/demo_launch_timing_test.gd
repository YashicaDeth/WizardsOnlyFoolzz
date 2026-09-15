extends Node

## P4.1/P4.2. A real, wall-clock-timed run of the actual launch funnel — the
## boot slate, the front door, DEMO, the decanting prologue and the first
## frame of the Growing Floor — with the player skipping the instant each
## screen allows it. This is the floor a real player can reach, timed with
## `Time.get_ticks_msec()` rather than settled over a fixed frame count: see
## the WorldClock frame-vs-real-time trap in START_HERE.md before trusting a
## number in this file.
##
## Scope, stated plainly rather than implied: this measures from the boot
## slate's first frame (Godot's own process/window startup is not
## measurable from inside a script it hasn't started running yet) to the
## Growing Floor receiving control. It is a floor on one machine, not proof
## of P5.1's "a machine that is not Greg's".

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
	# The tree is still assembling this very test node when `_ready` fires;
	# `root.add_child` refuses while that is in progress.
	await get_tree().process_frame
	var launch_ms := Time.get_ticks_msec()

	var splash := preload("res://boot_splash.tscn").instantiate()
	get_tree().root.add_child(splash)
	get_tree().current_scene = splash
	await get_tree().process_frame
	# The fastest real player: a click the instant the slate can take one.
	splash._finish()
	await get_tree().process_frame
	await get_tree().process_frame

	var menu := get_tree().current_scene
	check(menu != null and menu.has_method("_start_demo"), "the skipped slate lands on the front door")
	if menu == null or not menu.has_method("_start_demo"):
		print("DEMO_LAUNCH_TIMING_TEST_RESULT failures=", failures.size())
		get_tree().quit(1)
		return

	menu._start_demo()
	await get_tree().process_frame
	check(menu.prologue != null, "DEMO opens the decanting prologue immediately")
	# Same eager click, on the first screen the prologue can take one.
	menu.prologue._end()
	await Interstitial.arrived

	var elapsed_ms := Time.get_ticks_msec() - launch_ms
	print("DEMO_LAUNCH_ELAPSED_MS=", elapsed_ms)
	check(get_tree().current_scene.scene_file_path == "res://vat_chamber.tscn", "the skip path hands control to the Growing Floor")
	check(elapsed_ms < 60000, "the fastest skip path reaches the Growing Floor in under sixty seconds (%dms)" % elapsed_ms)
	print("DEMO_LAUNCH_TIMING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
