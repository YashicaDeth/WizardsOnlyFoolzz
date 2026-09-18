extends Node

## E6/E8. Substances and meditation have always cost consciousness and never
## shown it. `_update_altered_perception()` is what finally does — and it has
## to actually relax back to neutral once consciousness recovers, not just
## stop pushing the dials up further.

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

	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 30:
		await get_tree().process_frame

	var psychedelic: Control = hunt.get("psychedelic")
	var player_rig: Node = hunt.get("player_rig")

	# Full consciousness: nothing this system owns should be doing anything.
	player_rig.anatomy.consciousness = 100.0
	hunt.call("_update_altered_perception")
	check(absf(psychedelic.dial("chromatic_offset")) < 0.001, "full consciousness has no chromatic separation")
	check(absf(psychedelic.dial("kaleidoscope_segments")) < 0.001, "and no kaleidoscope fold")

	# A substance or a deep meditation session actually shows.
	player_rig.anatomy.consciousness = 20.0
	hunt.call("_update_altered_perception")
	var altered_chromatic: float = psychedelic.dial("chromatic_offset")
	var altered_kaleidoscope: float = psychedelic.dial("kaleidoscope_segments")
	var altered_displacement: float = psychedelic.dial("displacement_strength")
	check(altered_chromatic > 0.0, "losing consciousness actually distorts the frame (%.4f)" % altered_chromatic)
	check(altered_kaleidoscope > 0.0, "deep enough and the kaleidoscope fold engages too (%.2f)" % altered_kaleidoscope)
	for _frame in 120:
		hunt.call("_update_altered_perception")
	check(is_equal_approx(psychedelic.dial("displacement_strength"), altered_displacement),
		"a held altered state stays bounded instead of recompounding every frame")

	# Blood-loss collapse must remain playable and must not look like a drug.
	player_rig.anatomy.blood_remaining = player_rig.anatomy.blood_capacity * 0.30
	player_rig.anatomy.consciousness = 8.0
	hunt.call("_update_altered_perception")
	check(psychedelic.dial("displacement_strength") <= 0.0061,
		"blood-loss displacement is capped below the intentional trip (%.4f)" % psychedelic.dial("displacement_strength"))
	check(psychedelic.dial("chromatic_offset") <= 0.0016,
		"blood-loss chromatic separation remains readable (%.4f)" % psychedelic.dial("chromatic_offset"))
	check(psychedelic.dial("kaleidoscope_segments") < 2.0,
		"bleeding out never folds the playfield into a psychedelic kaleidoscope")

	# And it relaxes back down rather than freezing at the worst it reached —
	# the exact failure storm_weather.gd's own flash light had.
	player_rig.anatomy.blood_remaining = player_rig.anatomy.blood_capacity
	player_rig.anatomy.critical = false
	player_rig.anatomy.pain = 0.0
	player_rig.anatomy.consciousness = 100.0
	hunt.call("_update_altered_perception")
	check(absf(psychedelic.dial("chromatic_offset")) < 0.001, "coming back round actually clears the distortion")
	check(absf(psychedelic.dial("kaleidoscope_segments")) < 0.001, "and the fold, rather than either freezing where it was")

	# Night uses local light-warp shells and contributes nothing to this
	# fullscreen dial. Altered consciousness therefore sets the whole value.
	WorldClock.set_hour(2.0)
	hunt.call("_update_day_night")
	var night_only: float = psychedelic.dial("displacement_strength")
	player_rig.anatomy.consciousness = 20.0
	hunt.call("_update_altered_perception")
	check(is_zero_approx(night_only) and psychedelic.dial("displacement_strength") > night_only,
		"night stays sober while altered consciousness alone raises fullscreen warp (%.4f vs %.4f)" % [psychedelic.dial("displacement_strength"), night_only])

	if failures.is_empty():
		print("altered perception: the cost finally shows")
		get_tree().quit(0)
	else:
		print("altered perception FAILURES: ", failures)
		get_tree().quit(1)
