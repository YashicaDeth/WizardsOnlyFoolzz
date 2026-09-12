extends Node

## AS2. The sun and the base ambient used to be set once and never touched
## again — a fixed noon no matter how many hours world_clock.gd had actually
## advanced. `_update_day_night()` has to actually read the clock, and night
## has to mean something more than a dimmer, static frame.

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

	WorldClock.set_hour(13.0)
	hunt.call("_update_day_night")
	var sun: DirectionalLight3D = hunt.get("sun")
	var noon_energy: float = sun.light_energy
	var noon_warp: float = hunt.get("psychedelic").dial("displacement_strength")
	check(noon_energy > 1.0, "full daylight is a bright sun (%.2f)" % noon_energy)
	check(absf(noon_warp) < 0.001, "and the night warp is off at noon")

	WorldClock.set_hour(2.0)
	hunt.call("_update_day_night")
	var night_energy: float = sun.light_energy
	var night_warp: float = hunt.get("psychedelic").dial("displacement_strength")
	check(night_energy < noon_energy * 0.15, "deep night is genuinely dim, not a re-tinted noon (%.2f)" % night_energy)
	check(night_warp > 0.0, "and the light actually warps at night rather than only dimming")

	# A dawn in between should sit between the two, since it reads off the
	# same continuous daylight() curve rather than snapping between states.
	WorldClock.set_hour(6.2)
	hunt.call("_update_day_night")
	var dawn_energy: float = sun.light_energy
	check(dawn_energy > night_energy and dawn_energy < noon_energy, "dawn sits between night and noon (%.2f)" % dawn_energy)

	if failures.is_empty():
		print("day/night: the sun finally reads the clock")
		get_tree().quit(0)
	else:
		print("day/night FAILURES: ", failures)
		get_tree().quit(1)
