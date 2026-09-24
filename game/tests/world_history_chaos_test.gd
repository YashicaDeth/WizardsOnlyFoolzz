extends Node

## AS4.2. The storm needs a real cause to read: a level that rises when magick
## is worked and settles back to nothing when it is not.

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
	check(absf(WorldHistory.chaos_magick()) < 0.001, "nothing loose at the start")

	# Working a ritual is what feeds it — nothing else recorded so far does.
	WorldHistory.record_event("device_changed", {})
	check(absf(WorldHistory.chaos_magick()) < 0.001, "an unrelated event leaves it alone")
	WorldHistory.record_event("ritual_completed", {"subject_id": "player", "ritual_id": "test", "seal": "x"})
	var after_one := WorldHistory.chaos_magick()
	check(after_one > 0.1, "a completed ritual actually loosens something")

	# It settles rather than ratcheting: a second ritual soon after should not
	# simply double the level, because the first bump has already begun decaying.
	WorldClock.advance(1.0)
	WorldHistory.record_event("ritual_completed", {"subject_id": "player", "ritual_id": "test2", "seal": "y"})
	check(WorldHistory.chaos_magick() > after_one, "a second ritual loosens more, not less")
	check(WorldHistory.chaos_magick() <= 1.0, "it never exceeds full")

	# And it decays over game-time with nothing feeding it. `advance()` takes
	# real seconds, so convert the authored world-minute half-life through the
	# clock rate rather than quietly depending on a particular day length.
	var before_wait := WorldHistory.chaos_magick()
	WorldClock.advance(WorldHistory.CHAOS_MAGICK_HALF_LIFE_MINUTES / WorldClock.MINUTES_PER_SECOND)
	var after_wait := WorldHistory.chaos_magick()
	check(after_wait < before_wait * 0.6, "a half-life of quiet actually halves it")
	check(after_wait > 0.0, "but it has not vanished outright")

	WorldClock.advance(WorldHistory.CHAOS_MAGICK_HALF_LIFE_MINUTES * 20.0 / WorldClock.MINUTES_PER_SECOND)
	check(WorldHistory.chaos_magick() < 0.001, "and a long enough quiet settles it to nothing")

	if failures.is_empty():
		print("chaos magick: a level, not a switch")
		get_tree().quit(0)
	else:
		print("chaos magick FAILURES: ", failures)
		get_tree().quit(1)
