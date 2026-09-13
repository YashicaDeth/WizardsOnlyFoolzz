extends Node

## W1.2. Contamination moves, settles and gets worse. Verifies severity() is a
## real function of the calendar and of chaos-magick, that it never leaves
## 0..1, and that the node builds its two haze layers without error.

const CONTAMINATED_AIR := preload("res://systems/contaminated_air.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.world_minute = 0.0
	WorldHistory.chaos_magick_level = 0.0
	WorldHistory.chaos_magick_at_minute = 0.0

	var air := CONTAMINATED_AIR.new()
	add_child(air)
	await get_tree().physics_frame

	check(air.get_node_or_null("UpperHaze") != null, "the upper drifting layer exists")
	check(air.get_node_or_null("GroundHaze") != null, "the ground-settling layer exists")

	# Gets worse: day one should read near-clean, and severity should climb
	# on its own as the calendar advances, with no push from this test beyond
	# moving the clock.
	var day_one := air.severity()
	check(day_one < 0.1, "day one reads close to clean (%.3f)" % day_one)

	WorldHistory.world_minute = 9.0 * WorldClock.MINUTES_PER_DAY
	var mid := air.severity()
	check(mid > day_one, "contamination worsens as days pass (%.3f -> %.3f)" % [day_one, mid])

	WorldHistory.world_minute = 40.0 * WorldClock.MINUTES_PER_DAY
	var worst := air.severity()
	check(worst <= 1.0 and worst >= mid, "it climbs further and never exceeds 1.0 (%.3f)" % worst)

	# Chaos-magick pushes the same number rather than inventing a second one.
	WorldHistory.world_minute = 0.0
	WorldHistory.chaos_magick_level = 0.0
	var clean := air.severity()
	WorldHistory.record_event("ritual_completed", {"subject_id": "player", "ritual_id": "contaminated_air_test", "seal": "x"})
	var chaotic := air.severity()
	check(chaotic > clean, "loose chaos-magick worsens the air too (%.3f -> %.3f)" % [clean, chaotic])
	check(chaotic <= 1.0, "chaos contribution still clamps at 1.0 (%.3f)" % chaotic)

	# Moves: the wind direction is not fixed.
	var wind_a := air.wind_direction()
	for _step in 200:
		air._process(0.1)
	var wind_b := air.wind_direction()
	check(wind_a.distance_to(wind_b) > 0.01, "the wind actually turns over time")
	check(absf(wind_b.length() - 1.0) < 0.01, "wind direction stays a unit vector")

	# follow() recentres on X/Z and leaves height alone, same contract as
	# storm_weather.gd's own follow().
	air.position.y = 4.0
	air.follow(Vector3(12.0, 0.0, -7.0))
	check(air.position.x == 12.0 and air.position.z == -7.0 and air.position.y == 4.0,
		"follow() recentres on the ground plane and leaves height alone")

	print("CONTAMINATED_AIR_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
