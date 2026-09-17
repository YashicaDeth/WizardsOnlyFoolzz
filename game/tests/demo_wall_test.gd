extends Node

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
	check(not WorldHistory.complete_demo("impossible"), "PLAY cannot trip the demo ending")
	check(WorldHistory.event_count("demo_ending_reached") == 0, "PLAY receives no demo ending event")

	WorldHistory.begin_demo()
	var completed := WorldHistory.complete_demo("ashline_captain_repulsed", {
		"after": "hunt_arc_first_beat_complete",
		"next": ["outer_ashbloom_road", "ashline_second_hunt", "board_contracts"],
	})
	check(completed, "a won demo route can complete")
	check(str(WorldHistory.subject("demo_run").status) == "ended", "the demo run is permanently ended")
	check(str(WorldHistory.subject("demo_run").ending) == "ashline_captain_repulsed", "the authored ending id is retained")
	check(WorldHistory.event_count("demo_ending_reached") == 1, "the ending is written once into WorldHistory")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "ended state and the canonical ending event close one transaction")
	check(not WorldHistory.complete_demo("ashline_captain_repulsed"), "the ending is idempotent")
	check(WorldHistory.event_count("demo_ending_reached") == 1, "repeated callbacks cannot duplicate the ending")

	var wall := DemoWall.new()
	add_child(wall)
	wall.open_wall()
	check(wall.visible, "the authored wall visibly covers the stopped game")
	check(get_tree().paused, "the wall stops gameplay rather than running a timer")
	check(wall.get_node_or_null("FrontDoor") is Button, "the stopped run has a keyboard and pointer exit")
	get_tree().paused = false
	wall.queue_free()
	print("DEMO_WALL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
