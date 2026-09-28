extends Node

## Greg (2026-09-24): you arrive in the Hunt hurting from the decant, it eases
## off over the first minute unless something new hurts you, and you surface
## in the morning rather than at whatever hour the opening ran the clock to.

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
	WorldHistory.world_minute = 21.0 * 60.0 + 55.0
	OpeningDirector.advance("left_facility")
	check(is_equal_approx(WorldClock.hour(), OpeningDirector.SURFACE_HOUR), "leaving the facility surfaces you at %02d:00, not 21:55 (%.2f)" % [int(OpeningDirector.SURFACE_HOUR), WorldClock.hour()])

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt.player_rig.anatomy.pain = 85.0
	hunt._arrival_ease = -1.0
	hunt._ease_arrival_pain(0.016)
	for _second in 61:
		hunt._ease_arrival_pain(1.0)
	check(hunt.player_rig.anatomy.pain <= hunt.ARRIVAL_PAIN_FLOOR + 0.5, "decant pain eases to a mild floor over a minute (%.1f)" % hunt.player_rig.anatomy.pain)

	hunt.player_rig.anatomy.pain = 85.0
	hunt._arrival_ease = -1.0
	hunt._ease_arrival_pain(0.016)
	hunt._ease_arrival_pain(10.0)
	hunt.player_rig.anatomy.pain = 95.0
	hunt._ease_arrival_pain(1.0)
	for _second in 60:
		hunt._ease_arrival_pain(1.0)
	check(hunt.player_rig.anatomy.pain >= 90.0, "a new injury cancels the ease (%.1f)" % hunt.player_rig.anatomy.pain)
	print("ARRIVAL_EASE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
