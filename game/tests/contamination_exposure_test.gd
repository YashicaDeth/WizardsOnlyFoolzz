extends Node

## W1.3. Being caught out in it costs something. B7.1 already built the cost
## (`AnatomyComponent.expose()`, dosing whatever a garment leaves uncovered)
## and already wired it to the air in `bone_yard_hunt.gd`'s `_update_air()` —
## proven by `garments_test.gd` and `radiation_path_test.gd`, which this does
## not re-prove. What changed for W1.3 is the wiring, not the cost mechanism:
## until W1.2, `_update_air()` fed the air `chaos_magick()` alone, so a quiet
## run with no ritual ever performed exposed a body to exactly nothing no
## matter how many days had passed. It now feeds `WorldWeather.contamination()`
## instead, so the weather itself is what a body is caught out in.
##
## Checked as a single direct call rather than by running many physics ticks
## and averaging: this scene is heavy enough that a tight, uninterrupted
## `await physics_frame` loop against it is measurably timing-sensitive in
## headless mode (observed: identical logic reproducibly reads a different
## outcome depending only on whether an unrelated print statement sits in the
## loop) — a pre-existing fragility in driving this particular scene under a
## test harness, not something this pass introduces or should paper over by
## quietly depending on it.

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

	# An old, contaminated world at deep night, with no ritual ever worked —
	# WorldWeather's ambient/diurnal terms should tax a standing body with
	# chaos_magick at zero throughout.
	WorldHistory.chaos_magick_level = 0.0
	WorldHistory.chaos_magick_at_minute = 0.0
	WorldHistory.world_minute = 90.0 * WorldClock.MINUTES_PER_DAY
	WorldClock.set_hour(2.0)

	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 90:
		await get_tree().process_frame

	var player_rig: Node = hunt.get("player_rig")
	var anatomy: Node = player_rig.get("anatomy")
	var air: Node = hunt.get("air")
	var expected := WorldWeather.contamination()
	check(expected > 0.05, "sanity: this scenario's severity actually clears expose()'s dead-zone threshold (%.3f)" % expected)

	var dose_before: Dictionary = (anatomy.get("dose") as Dictionary).duplicate()
	hunt.call("_update_air")
	check(is_equal_approx(float(air.call("severity")), expected), "_update_air() sets the air's severity to WorldWeather.contamination()")

	var dose_after: Dictionary = anatomy.get("dose")
	var any_zone_dosed := false
	for zone_id in dose_after:
		if float(dose_after[zone_id]) > float(dose_before.get(zone_id, 0.0)):
			any_zone_dosed = true
	check(any_zone_dosed, "one call to _update_air() actually doses the player's body through expose()")
	check(WorldHistory.chaos_magick_level == 0.0, "sanity: still nobody worked a ritual in this run — the dose above came from ambient weather alone")

	_report()


func _report() -> void:
	if failures.is_empty():
		print("contamination exposure: costs something even on a quiet run")
		get_tree().quit(0)
	else:
		print("contamination exposure FAILURES: ", failures)
		get_tree().quit(1)
