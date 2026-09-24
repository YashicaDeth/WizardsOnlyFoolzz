extends Node

## The re-animated logo (Greg: "reanimating the text and graphic of the
## actual game logo image with gfx stuff"): the real rasters wear the logo
## shader, the seal assembles and throws sparks as it locks, and the mark
## burns in on the heartbeat.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var splash = load("res://boot_splash.tscn").instantiate()
	add_child(splash)
	await get_tree().process_frame
	splash.set_process(false)
	check(splash.seal_rect.material.shader == splash.LOGO_FX and splash.mark_rect.material.shader == splash.LOGO_FX, "the seal and the wordmark both wear the logo shader")
	check(str(splash.mark_rect.texture.resource_path).ends_with("wof_stacked.png"), "on the real logo image, not a redraw")
	splash.stage = splash.Stage.MARK
	splash.stage_clock = 0.0
	splash._update_mark_visibility()
	check(float(splash.seal_material.get_shader_parameter("assemble")) < 0.1, "the seal starts apart")
	splash.stage_clock = splash.SEAL_ASSEMBLE_SECONDS + 0.05
	splash._update_mark_visibility()
	check(float(splash.seal_material.get_shader_parameter("assemble")) >= 0.999 and splash.seal_locked, "and locks together")
	check(splash.sparks.size() >= 20, "throwing sparks from its joints (%d)" % splash.sparks.size())
	for _step in 40:
		splash._update_sparks(0.05)
	check(splash.sparks.is_empty(), "the sparks burn out")
	var beats := 0.0
	for step in 100:
		beats = maxf(beats, splash.heartbeat(float(step) / 100.0))
	check(beats > 0.9 and splash.heartbeat(0.6) < 0.1, "the mark pulses on a heartbeat")
	splash.stage_clock = splash.SEAL_REVEAL_SECONDS + splash.SEAL_HERO_HOLD_SECONDS + splash.LOCKUP_CROSSFADE_SECONDS
	splash._update_mark_visibility()
	check(float(splash.mark_material.get_shader_parameter("reveal")) >= 0.999, "the wordmark has fully burned in")
	check(float(splash.mark_material.get_shader_parameter("glitch")) < 0.4, "and settles so the name reads")
	print("LOGO_FX_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
