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
	check(wall.get_node_or_null("ContinueFullGame") is Button, "the stopped run offers its world to PLAY")

	var demo_event_count := WorldHistory.event_count()
	var slot_id := wall.promote_to_full_game()
	check(not slot_id.is_empty() and not WorldHistory.is_demo(), "continuing creates an ordinary PLAY slot")
	check(WorldHistory.active_slot_id == slot_id, "the promoted world is the active PLAY world")
	check(str(WorldHistory.subject("demo_run").get("status", "")) == "continued", "the PLAY copy is no longer stopped at the demo wall")
	check(WorldHistory.event_count("demo_world_continued") == 1, "the PLAY ledger records the continuation once")
	check(WorldHistory.event_count() == demo_event_count + 1, "promotion preserves the completed history before adding its receipt")

	WorldHistory.begin_demo()
	check(str(WorldHistory.subject("demo_run").get("status", "")) == "ended", "the dedicated demo save remains ended and untouched")
	check(WorldHistory.event_count("demo_world_continued") == 0, "PLAY continuation does not leak back into DEMO")
	check(WorldHistory.load_slot(slot_id), "the promoted PLAY slot loads from disk")
	check(str(WorldHistory.subject("demo_run").get("continued_as", "")) == slot_id, "the complete promoted world survives reload")
	get_tree().paused = false
	wall.queue_free()
	print("DEMO_WALL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
