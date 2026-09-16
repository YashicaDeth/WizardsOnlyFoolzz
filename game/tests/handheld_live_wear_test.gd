extends Node

## C10.8. Device wear must enter through things that happen in the playable
## Hunt, not only through direct unit-test calls to `take_wear()`.

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
	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().process_frame

	var device = hunt.handheld
	device.condition = 1.0
	device.impacts.clear()
	device.wear_log.clear()
	device.possessed = true
	device.is_open = true
	device.raised = 1.0
	device.save_device()

	var attacker: Vector3 = hunt.player + Vector3(5.0, 0.0, -4.0)
	var expected_at: Vector2 = hunt._handheld_impact_point(attacker)
	hunt._wound_player(attacker, 20.0, "blunt")
	check(device.condition < 0.96, "a real wound damages the device exposed in the raised hand")
	check(device.impacts.size() == 1, "the live hit creates exactly one glass impact")
	check((device.impacts[0].at as Vector2).distance_to(expected_at) < 0.001, "the crack starts on the attacker's actual screen side")
	check(str(device.wear_log.back()) == "blunt impact while raised", "the shell remembers what caused the live damage")

	device.raised = 0.0
	var pocketed_condition: float = device.condition
	hunt._wound_player(attacker, 20.0, "cut")
	check(is_equal_approx(device.condition, pocketed_condition), "the same wound cannot damage a device protected in the pocket")

	device.raised = 1.0
	var before_drop: float = device.condition
	var dropped: Dictionary = device.drop()
	check(bool(dropped.get("ok", false)), "the real drop transition still succeeds")
	check(device.condition < before_drop, "deliberately dropping the physical object gives it a small lower-edge impact")
	check(str(device.wear_log.back()) == "deliberate drop", "the dropped object carries that action in its wear history")
	check(not device.possessed, "wear does not create a replacement device in the player's hand")

	print("HANDHELD_LIVE_WEAR_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
