extends Node

const MAP := preload("res://systems/living_map.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var start: Dictionary = MAP.holding_reveal_profile(0.0)
	var middle: Dictionary = MAP.holding_reveal_profile(0.5)
	var finish: Dictionary = MAP.holding_reveal_profile(1.0)
	check(is_zero_approx(float(start.coverage)) and is_equal_approx(float(finish.coverage), 1.0), "the reveal begins closed and ends on the complete holding edge")
	check(float(start.coverage) < float(middle.coverage) and float(middle.coverage) < float(finish.coverage), "cleaned coverage advances monotonically rather than pulsing in place")
	check(float(middle.edge_width) > float(start.edge_width) and float(middle.edge_width) > float(finish.edge_width), "the cleaning lip carries its strongest weight while it crosses the glass")
	check(float(middle.streak_alpha) > 0.0 and is_zero_approx(float(finish.streak_alpha)), "wipe streaks travel with the front and disappear from settled land")
	print("HOLDING_REVEAL_PROFILE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
