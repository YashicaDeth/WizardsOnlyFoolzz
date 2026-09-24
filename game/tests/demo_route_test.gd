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
	WorldHistory.begin_demo()
	var hunt := (load("res://bone_yard_hunt.tscn") as PackedScene).instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().process_frame
	hunt._rival_retreats("TEST VICTORY")
	check(WorldHistory.event_count("hunt_arc_first_beat_complete") == 1, "the real Hunt win is recorded before the wall")
	check(WorldHistory.event_count("demo_ending_reached") == 1, "the real Hunt win reaches the demo ending")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0 and not bool(WorldHistory.get("_ledger_batch_dirty")), "escape, rivalry and the demo ending close as one retreat outcome")
	check(hunt.demo_wall.visible, "the Hunt displays its authored wall after victory")
	check(get_tree().paused, "the live Hunt is stopped under the wall")
	get_tree().paused = false
	hunt.queue_free()
	await get_tree().process_frame
	var resumed_hunt := (load("res://bone_yard_hunt.tscn") as PackedScene).instantiate()
	add_child(resumed_hunt)
	await get_tree().create_timer(0.05, true).timeout
	check(resumed_hunt.demo_wall.visible, "resuming an ended demo restores the wall")
	check(get_tree().paused, "an ended demo cannot resume beyond its authored stop")
	get_tree().paused = false
	resumed_hunt.queue_free()
	print("DEMO_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
