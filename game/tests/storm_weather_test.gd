extends Node

## AS4. Severity has to be a real read of WorldHistory.chaos_magick(), not a
## number this file invents, and only a real storm should cost the player
## anything (AS4.5) or put a bolt in the sky (AS4.3/AS4.4).

const STORM := preload("res://systems/storm_weather.gd")

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
	WorldHistory.chaos_magick_at_minute = WorldClock.minutes()

	var storm: Node3D = STORM.new()
	add_child(storm)
	await get_tree().process_frame

	check(absf(storm.severity()) < 0.001, "nothing loose, no storm")
	check(absf(storm.exposure_cost(1.0)) < 0.001, "and nothing costs the player anything yet")
	var rain: Node = storm.get_node("Rain")
	check(not bool(rain.emitting), "the rain is not running with nothing feeding it")

	# A quiet ritual's worth of chaos-magick should not be a real storm.
	WorldHistory._bump_chaos_magick(0.05)
	storm._process(0.1)
	check(absf(storm.severity()) < 0.001, "below the floor still reads as no storm")

	# A real charge is a real storm.
	WorldHistory._bump_chaos_magick(0.9)
	storm._process(0.1)
	var severity: float = storm.severity()
	check(severity > 0.5, "a real charge is a real storm (%.2f)" % severity)
	check(bool(rain.emitting), "and the rain actually runs")
	check(storm.exposure_cost(1.0) > 0.0, "being out in it costs something (AS4.5)")

	# Force a strike directly rather than waiting on its own random clock.
	storm._strike(severity)
	check(float(storm._crawler_material.get_shader_parameter("intensity")) > 0.0, "a strike lights the crawler up")
	check(storm._flash_light.light_energy > 0.0, "and flashes a real light, not just the shader")
	check(storm._thunder.playing, "and a real sound plays alongside it (AC1.5)")
	check(str(AudioBus.graph().get("Weather", "")) == AudioBus.AMBIENCE, "thunder is routed through the mixer's Weather chain, not straight to Master")
	check(AudioBus.fully_routed(), "and the mixer graph as a whole still reaches Master through a bus the player can see")
	var lit_energy: float = storm._flash_light.light_energy
	for _tick in 60:
		storm._process(0.1)
	check(storm._flash_light.light_energy < lit_energy, "and it actually fades rather than holding")
	check(storm._flash_light.light_energy < 0.05, "and reaches true zero rather than freezing wherever the crawl's own fade left it")
	check(float(storm._crawler_material.get_shader_parameter("intensity")) < 0.01, "the crawl finishes rather than staying lit forever")

	if failures.is_empty():
		print("storm weather: a readout, not ambience")
		get_tree().quit(0)
	else:
		print("storm weather FAILURES: ", failures)
		get_tree().quit(1)
