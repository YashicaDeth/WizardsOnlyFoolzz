extends Node

## P2. One executable, two doors, and two histories that cannot overwrite one
## another. This uses the real WorldHistory file routing under its test-only
## paths rather than mocking persistence.

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
	var play_slot := WorldHistory.create_slot("PLAY CONTROL")
	WorldHistory.record_event("play_only_marker")
	check(not WorldHistory.is_demo(), "a normal slot runs in PLAY mode")

	WorldHistory.begin_demo()
	check(WorldHistory.is_demo(), "DEMO is one runtime mode flag")
	check(WorldHistory.active_slot_id.is_empty(), "DEMO never points at a PLAY slot")
	check(WorldHistory.event_count("play_only_marker") == 0, "the PLAY history did not leak into DEMO")
	WorldHistory.record_event("demo_only_marker")
	check(FileAccess.file_exists(WorldHistory.TEST_DEMO_SAVE_PATH), "DEMO writes its dedicated save file")

	WorldHistory.enter_play_mode(false)
	check(WorldHistory.load_slot(play_slot), "the original PLAY slot still loads")
	check(WorldHistory.event_count("play_only_marker") == 1, "the PLAY history survived the DEMO session")
	check(WorldHistory.event_count("demo_only_marker") == 0, "the DEMO history did not leak into PLAY")

	WorldHistory.begin_demo()
	check(WorldHistory.event_count("demo_only_marker") == 1, "the dedicated DEMO slot resumes")

	print("DEMO_MODE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
