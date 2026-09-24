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
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	check(is_equal_approx(hunt._movement_stamina_rate(false), 18.0), "an idle body recovers stamina")
	check(is_equal_approx(hunt._movement_stamina_rate(true), -26.0), "sprinting spends stamina at its authored rate")
	hunt.guarding = true
	check(is_zero_approx(hunt._movement_stamina_rate(false)), "passive recovery cannot cancel the cost of a raised guard")
	hunt.guarding = false
	hunt.grapple_target = "held_subject"
	check(is_zero_approx(hunt._movement_stamina_rate(false)), "passive recovery cannot subsidise a held clinch")
	hunt.grapple_target = ""
	hunt.strike_windup = 0.1
	check(is_zero_approx(hunt._movement_stamina_rate(false)), "committing to a swing pauses recovery")
	hunt.strike_windup = -1.0
	hunt.dodge_remaining = 0.1
	check(is_zero_approx(hunt._movement_stamina_rate(false)), "the dodge itself is not also a recovery window")
	hunt.dodge_remaining = 0.0
	check(is_equal_approx(hunt._movement_stamina_rate(false), 18.0), "recovery resumes once exertion genuinely ends")

	print("STAMINA_RECOVERY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
