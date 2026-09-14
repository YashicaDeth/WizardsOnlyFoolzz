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

	var text: String = PerfProbe.call("_report", false)
	check(text.contains("FRAME") and text.contains("OUTPUT") and text.contains("SPLIT"), "the plain-text dump carries the three sections that answer the question")
	check(not text.contains("[color"), "the plain dump has no bbcode in it — it is meant to be read in Notepad")

	print("PERF_PROBE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
