extends Node

## W1.2. Contamination has weather — it moves, it settles, it gets worse.
## `WorldWeather.contamination()` is a pure function of `WorldClock` (W1.1) and
## `WorldHistory.chaos_magick()` (AS4.2), the same way `WorldClock` itself is a
## pure function of one stored minute: nothing new to save, nothing that can
## drift out of sync with either source.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.chaos_magick_level = 0.0
	WorldHistory.chaos_magick_at_minute = 0.0
	WorldHistory.world_minute = 0.0

	# --- it gets worse ---------------------------------------------------
	var day_one := WorldWeather.ambient_contamination()
	check(day_one > 0.0, "even day one already reads something, not a clean zero")
	WorldHistory.world_minute = 20.0 * WorldClock.MINUTES_PER_DAY
	var day_twenty := WorldWeather.ambient_contamination()
	check(day_twenty > day_one, "twenty days on, the ambient floor has genuinely risen")
	check(is_equal_approx(day_twenty, 21.0 * WorldWeather.AMBIENT_PER_DAY), "the floor is exactly the authored per-day rate, not a guess")

	WorldHistory.world_minute = 5000.0 * WorldClock.MINUTES_PER_DAY
	check(WorldWeather.ambient_contamination() <= WorldWeather.AMBIENT_CEILING, "the floor stops at its authored ceiling rather than running past 1.0 given enough days")

	# --- it moves / it settles: worse at night, receding by day ----------
	WorldHistory.world_minute = 10.0 * WorldClock.MINUTES_PER_DAY
	WorldClock.set_hour(13.0)
	var floor_at_noon := WorldWeather.ambient_contamination()
	var at_noon := WorldWeather.contamination()
	# Later the same day (22.0 > 13.0, so set_hour stays on today rather than
	# rolling to tomorrow the way asking for an earlier clock-time would).
	WorldClock.set_hour(22.0)
	var floor_at_night := WorldWeather.ambient_contamination()
	var at_night := WorldWeather.contamination()
	check(at_night > at_noon, "the same day reads worse at 10pm than at 1pm")
	check(is_equal_approx(floor_at_noon, floor_at_night), "the ambient floor itself does not care what hour it is")
	check(at_noon >= floor_at_noon - 0.001, "contamination() never reads below that day's own ambient floor")

	# --- a storm already loose in the air counts too, and it settles -----
	WorldHistory.world_minute = 0.0
	WorldHistory.chaos_magick_level = 0.0
	WorldHistory.chaos_magick_at_minute = 0.0
	WorldClock.set_hour(13.0)
	var calm := WorldWeather.contamination()
	WorldHistory.record_event("ritual_completed", {"subject_id": "player", "ritual_id": "test", "seal": "x"})
	var during_storm := WorldWeather.contamination()
	check(during_storm > calm, "a storm already loose in the air reads as worse contamination too")

	WorldClock.advance(WorldHistory.CHAOS_MAGICK_HALF_LIFE_MINUTES * 20.0)
	# Pinned back to the same daylight hour so only the storm's own decay is
	# under test here — the diurnal push is covered separately above.
	WorldClock.set_hour(13.0)
	var after_storm := WorldWeather.contamination()
	check(after_storm < during_storm, "once the storm has settled, contamination comes back down")
	check(after_storm >= WorldWeather.ambient_contamination() - 0.001, "but it settles back to that day's floor, never below it")

	# --- always a sane fraction -------------------------------------------
	WorldHistory.world_minute = 999999.0 * WorldClock.MINUTES_PER_DAY
	WorldHistory.chaos_magick_level = 1.0
	WorldHistory.chaos_magick_at_minute = WorldClock.minutes()
	WorldClock.set_hour(2.0)
	check(WorldWeather.contamination() <= 1.0, "worst case — ancient save, deep night, a live storm — still clamps to full, not past it")

	if failures.is_empty():
		print("world weather: contamination has weather")
		get_tree().quit(0)
	else:
		print("world weather FAILURES: ", failures)
		get_tree().quit(1)
