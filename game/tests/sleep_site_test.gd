extends Node

## H10.8. Sleeping is a reachable Hunt action, advances the one persistent
## clock to dawn, records the elapsed time, and refuses nearby danger.

const HUNT := preload("res://bone_yard_hunt.tscn")

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
	WorldHistory.world_minute = 16.5 * WorldClock.MINUTES_PER_HOUR
	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().process_frame
	hunt.set_physics_process(false)
	check(hunt.sleep_site != null and is_instance_valid(hunt.sleep_site), "the Hunt builds a physical bedroll")
	check(hunt.SLEEP_SITE_POSITION.distance_to(Vector3(0, 1.5, 19)) < hunt.SLEEP_REACH, "the bedroll is reachable from the opening route")

	hunt.player = hunt.sleep_site.global_position
	hunt.enemy_retreating = true
	for actor: Dictionary in hunt.encounter_actors:
		actor.disposition = "neutral"
	var before := WorldClock.minutes()
	check(hunt._try_sleep_at_site(), "interacting in reach is owned by the bedroll")
	check(absf(WorldClock.hour() - hunt.SLEEP_WAKE_HOUR) < 0.01 and WorldClock.minutes() > before, "sleep advances forward to 07:00")
	var event := WorldHistory.recent_events(1)[0]
	check(str(event.get("type", "")) == "player_slept" and float((event.details as Dictionary).get("hours", 0.0)) > 0.0, "the sleep and its real elapsed hours enter world history")

	hunt.player = hunt.sleep_site.global_position + Vector3(10, 0, 0)
	check(not hunt._try_sleep_at_site(), "the bedroll cannot be used at a distance")
	hunt.player = hunt.sleep_site.global_position
	hunt.enemy_retreating = false
	hunt.enemy.visible = true
	hunt.enemy.global_position = hunt.player + Vector3(2, 0, 0)
	before = WorldClock.minutes()
	check(hunt._try_sleep_at_site() and is_equal_approx(WorldClock.minutes(), before), "a nearby hunter refuses sleep without moving the clock")

	print("SLEEP_SITE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
