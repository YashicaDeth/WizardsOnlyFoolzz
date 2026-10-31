extends Node
## X10.11: "a profile run is part of the test suite". Windowed only (a
## headless run draws nothing, so it would time nothing): each scene on the
## first thirty minutes is loaded, settled, and its frame timed by wall clock
## with vsync off. Fails if any breaks the 60 FPS contract (16.7 ms).
## `tools/run_tests.sh --perf` runs it; the numbers go in the log.

const BUDGET_MS := 1000.0 / 60.0
const SCENES := [
	"res://vat_chamber.tscn", "res://support_unit.tscn", "res://service_arcade.tscn",
	"res://old_drains.tscn", "res://buried_city.tscn", "res://derby_tunnels.tscn",
	"res://blood_waterfall_exit.tscn", "res://rift_derby.tscn", "res://bone_yard_hunt.tscn",
]
const SETTLE := 90
const SAMPLE := 120
var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("ROUTE_FRAME_BUDGET skipped: headless draws nothing (run tools/run_tests.sh --perf)")
		get_tree().quit(0)
		return
	get_tree().root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for path: String in SCENES:
		var scene: Node = load(path).instantiate()
		add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame
		var start := Time.get_ticks_usec()
		for _f in SAMPLE:
			await get_tree().process_frame
		var frame_ms := float(Time.get_ticks_usec() - start) / 1000.0 / SAMPLE
		check(frame_ms <= BUDGET_MS, "%s %.2f ms (budget %.1f)" % [path.get_file(), frame_ms, BUDGET_MS])
		scene.queue_free()
		Engine.time_scale = 1.0
		await get_tree().process_frame
	print("ROUTE_FRAME_BUDGET_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
