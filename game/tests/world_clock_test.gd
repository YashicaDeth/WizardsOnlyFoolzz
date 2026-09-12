extends Node

## W1.1 and A9.7 v2. The clock, and the dial that finally has something to read.

const RADIO := preload("res://systems/wire_radio.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.world_minute = 16.5 * 60.0
	check(absf(WorldClock.hour() - 16.5) < 0.001, "a world opens in the late afternoon")
	check(WorldClock.day() == 1, "on day one")
	check(WorldClock.phase() == "day", "which is still day")

	# It advances, and it advances at the rate it says it does.
	WorldClock.advance(60.0)
	check(absf(WorldClock.hour() - 17.5) < 0.01, "a real minute is a game hour")

	# A full day turns over.
	WorldHistory.world_minute = 0.0
	WorldClock.advance(60.0 * 24.0)
	check(WorldClock.day() == 2, "twenty-four game hours is a new day")

	# The phases land where they are named.
	for sample in [[2.0, "deep night"], [5.5, "before dawn"], [7.5, "dawn"], [13.0, "day"], [19.0, "dusk"], [22.0, "night"]]:
		WorldClock.set_hour(float(sample[0]))
		check(WorldClock.phase() == str(sample[1]), "%.1f is %s" % [sample[0], sample[1]])

	# Light is continuous and dark at the ends.
	WorldClock.set_hour(2.0)
	check(WorldClock.daylight() <= 0.001 and WorldClock.is_night(), "the middle of the night is dark")
	WorldClock.set_hour(13.0)
	check(WorldClock.daylight() >= 0.999 and not WorldClock.is_night(), "the middle of the day is not")
	WorldClock.set_hour(6.2)
	var twilight := WorldClock.daylight()
	check(twilight > 0.0 and twilight < 1.0, "dawn is neither")

	# The clock never runs backwards, whatever it is asked.
	WorldClock.set_hour(13.0)
	var before := WorldClock.minutes()
	WorldClock.set_hour(9.0)
	check(WorldClock.minutes() > before, "asking for an hour already past means tomorrow")

	# And sleeping moves it.
	var slept := WorldClock.pass_time(8.0)
	check(absf(slept - 8.0) < 0.001, "eight hours passes eight hours")
	check(absf(WorldClock.pass_time(8.0, 2.5) - 2.5) < 0.001, "being woken shortens it")

	# ---- A9.7 v2: the dial at three in the morning is not the dial at noon.
	var radio = RADIO.new()
	radio.listener = Vector2.ZERO
	WorldClock.set_hour(12.0)
	var noon := _live(radio.band())
	WorldClock.set_hour(3.0)
	var small_hours := _live(radio.band())
	print("on air at noon: ", noon)
	print("on air at 3am:  ", small_hours)
	check(noon != small_hours, "the dial is not the same at 3am as at noon")
	check(small_hours.has("UNNAMED CARRIER"), "the numbers station never stops")
	check(noon.has("UNNAMED CARRIER"), "at either hour")
	check(not noon.has("THE FULL SCHEDULE"), "the preacher is not on at midday")
	check(small_hours.has("THE FULL SCHEDULE"), "he is on at three")
	check(noon.has("BONE YARD PIT CONTROL"), "pit control runs with the pit")
	check(not small_hours.has("BONE YARD PIT CONTROL"), "and signs off after the last heat")

	# Off air is zero strength, not weak, however close you stand.
	WorldClock.set_hour(3.0)
	radio.listener = Vector2(-155.0, 0.0)
	for entry: Dictionary in radio.band():
		if str(entry["name"]) == "BONE YARD PIT CONTROL":
			check(float(entry["strength"]) == 0.0, "standing under an off-air mast still gets nothing")
			check(float(entry["returns_in"]) > 0.0, "and the dial says when it comes back")

	if failures.is_empty():
		print("world clock: keeping time")
		get_tree().quit(0)
	else:
		print("world clock FAILURES: ", failures)
		get_tree().quit(1)


func _live(band: Array) -> Array:
	var names: Array = []
	for entry: Dictionary in band:
		if bool(entry.get("on_air", false)):
			names.append(str(entry["name"]))
	names.sort()
	return names
