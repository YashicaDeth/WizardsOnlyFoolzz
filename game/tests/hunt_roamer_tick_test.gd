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

	var near: Dictionary = {}
	check(is_equal_approx(RoamerDetail.due_delta(near, 20.0, 0.016), 0.016),
		"a nearby roamer keeps the exact every-frame delta")

	var reduced: Dictionary = {}
	var reduced_spent := 0.0
	for _tick in 14:
		reduced_spent += RoamerDetail.due_delta(reduced, 120.0, 1.0 / 60.0)
	check(is_zero_approx(reduced_spent), "a reduced roamer skips work before its quarter-second tick")
	reduced_spent += RoamerDetail.due_delta(reduced, 120.0, 1.0 / 60.0)
	check(is_equal_approx(reduced_spent, 0.25), "a reduced roamer spends all saved time on the due tick")

	var dormant: Dictionary = {}
	var dormant_spent := 0.0
	for _tick in 89:
		dormant_spent += RoamerDetail.due_delta(dormant, 200.0, 1.0 / 60.0)
	check(is_zero_approx(dormant_spent), "a dormant roamer skips work before its 1.5-second tick")
	dormant_spent += RoamerDetail.due_delta(dormant, 200.0, 1.0 / 60.0)
	check(is_equal_approx(dormant_spent, 1.5), "a dormant roamer spends all saved time on the due tick")

	var culled := {"detail_tick_elapsed": 0.4}
	check(is_zero_approx(RoamerDetail.due_delta(culled, 300.0, 0.016)),
		"a roamer awaiting the cull pass performs no AI work")
	check(is_zero_approx(float(culled.detail_tick_elapsed)), "the culled tier cannot leak saved time into a reused actor")

	var returning := {"detail_tick_elapsed": 0.2}
	check(is_equal_approx(RoamerDetail.due_delta(returning, 20.0, 0.016), 0.016),
		"a body returning nearby resumes the ordinary frame delta")
	check(is_zero_approx(float(returning.detail_tick_elapsed)), "returning nearby clears the distant accumulator")

	print("HUNT_ROAMER_TICK_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
