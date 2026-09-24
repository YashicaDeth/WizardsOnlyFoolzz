extends Node

## The probe has to be right about the numbers it reports or it is worse than
## nothing — a profiler that lies sends the next three hours somewhere useless.

var failures: Array[String] = []

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	check(PerfProbe != null, "the probe is an autoload and exists in every scene")
	check(not PerfProbe.visible, "it is off until asked for — a HUD nobody opted into is a HUD in every screenshot")
	check(PerfProbe.process_mode == Node.PROCESS_MODE_ALWAYS, "it keeps measuring while the game is paused, which is when people open it")
	var old_phone_key := InputEventKey.new()
	old_phone_key.keycode = KEY_F3
	old_phone_key.pressed = true
	PerfProbe._unhandled_input(old_phone_key)
	check(not PerfProbe.showing, "phone function keys no longer also toggle diagnostics")
	var probe_key := InputEventKey.new()
	probe_key.keycode = KEY_F10
	probe_key.pressed = true
	PerfProbe._unhandled_input(probe_key)
	check(PerfProbe.showing and PerfProbe.visible, "F10 opens the isolated performance overlay")
	PerfProbe._unhandled_input(probe_key)
	check(not PerfProbe.showing and not PerfProbe.visible, "F10 closes the overlay cleanly")

	for _f in 12:
		await get_tree().process_frame
	var s: Dictionary = PerfProbe.call("_stats")
	check(s["ms"] > 0.0, "frame time is a real measurement, not zero")
	check(s["fps"] > 0.0, "and so is the rate derived from it")
	check(s["window"].x > 0 and s["window"].y > 0, "it reports the real window size")
	check(s["render_scale"] > 0.0, "and the render scale, which is the setting that can quietly cost 2.25x the pixels")
	check(s["effective"].x == int(s["window"].x * s["render_scale"]), "effective resolution is window times scale — the number nobody computes by hand")
	check(["OFF", "2X", "4X", "8X"].has(s["msaa"]), "MSAA reports as a name rather than an enum nobody can read")
	check(s["nodes"] > 0, "node count is live")

	# The split is the load-bearing number: it says whether to optimise script or
	# renderer, and getting it backwards wastes the whole next session.
	check(s["process_ms"] >= 0.0 and s["physics_ms"] >= 0.0, "the script/physics split reports non-negative times")

	# X1.2. A fast contract check beside the slower rendered benchmarks: the
	# budget and the complete viewport tiers must stay explicit even on a test
	# runner where a hardware timing assertion would not be meaningful.
	check(is_equal_approx(WorldLook.FRAME_BUDGET_MS, 1000.0 / 60.0), "the region has an explicit 16.67 ms / 60 FPS frame budget")
	var quality_before := WorldLook.quality
	var test_view := SubViewport.new()
	add_child(test_view)
	WorldLook.set_quality_name("ULTRA")
	WorldLook.apply_viewport_quality(test_view)
	check(is_equal_approx(test_view.scaling_3d_scale, 1.0) and test_view.msaa_3d == Viewport.MSAA_4X and test_view.use_taa,
		"ULTRA's complete viewport cost is part of the measured preset")
	WorldLook.set_quality_name("PERFORMANCE")
	WorldLook.apply_viewport_quality(test_view)
	check(is_equal_approx(test_view.scaling_3d_scale, 0.75) and test_view.msaa_3d == Viewport.MSAA_DISABLED and not test_view.use_taa,
		"PERFORMANCE applies 75% scale with AA disabled")
	test_view.queue_free()
	WorldLook.quality = quality_before

	var text: String = PerfProbe.call("_report", false)
	check(text.contains("FRAME") and text.contains("OUTPUT") and text.contains("SPLIT"), "the plain-text dump carries the three sections that answer the question")
	check(not text.contains("[color"), "the plain dump has no bbcode in it — it is meant to be read in Notepad")

	print("PERF_PROBE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
