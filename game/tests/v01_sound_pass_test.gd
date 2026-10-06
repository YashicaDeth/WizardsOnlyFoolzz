extends Node

const AMBIENT_AUDIO := preload("res://systems/ambient_audio.gd")
const AMBIENT_BED := preload("res://systems/ambient_bed.gd")
const EXAMINER_VOICE := preload("res://systems/examiner_voice.gd")
const FACILITY := preload("res://facility.gd")
const FP_AUDIO := preload("res://systems/fp_combat_audio.gd")
const FLUID_SOUND := preload("res://systems/fluid_sound.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	AMBIENT_BED.force_in_tests = true
	var bed := AMBIENT_BED.new().setup("vat")
	add_child(bed)
	check(bed.profile == "vat" and bed.layers.has("pumps") and bed.layers.has("bubbling"), "the route starts on the vat pump and bubble bed")
	bed.set_profile("arcade")
	check(bed.profile == "arcade" and bed.layers.has("hum") and not bed.layers.has("pumps"), "a one-map zone crossing replaces the room bed")
	check(bed.profile_switches == 1, "an unchanged room does not rebuild its loops")
	bed.set_profile("arcade")
	check(bed.profile_switches == 1, "staying in a room keeps the same voices")

	check(FACILITY.profile_for(Vector3(0, 0, -10)) == "vat", "Growing Floor selects vat ambience")
	check(FACILITY.profile_for(Vector3(28, 0, -30)) == "arcade", "Service Arcade selects its own ambience")
	check(FACILITY.profile_for(Vector3(28, -12, -90)) == "city", "Lower Works selects its own ambience")
	check(FACILITY.profile_for(Vector3(28, -5, -62)) == "bay", "a moving lift selects the machine bed")
	check(FACILITY.surface_for(Vector3(0, 0, -10)) == "tile", "bare opening feet land on tile")
	check(FACILITY.surface_for(Vector3(28, -5, -62)) == "metal", "lift footsteps land on metal")
	check(FACILITY.surface_for(Vector3(28, -12, -90)) == "concrete", "Lower Works footsteps land on concrete")
	check(AMBIENT_AUDIO.stream("step_bare") != null and AMBIENT_AUDIO.stream("step_metal") != null, "wet skin and surface layers both exist")

	var voice := EXAMINER_VOICE.new()
	add_child(voice)
	voice.speak("You were not supposed to be awake yet.", 1.4, false)
	var peak := 0.0
	for sample_index in 240:
		peak = maxf(peak, absf(EXAMINER_VOICE.sample_at("awake", float(sample_index) / 1200.0, false)))
	check(voice.phrases_spoken == 1 and voice.playing, "the authored examiner line starts its placeholder voice")
	check(peak > 0.08, "the examiner placeholder contains audible formants")

	check(FP_AUDIO.SURFACES == ["flesh", "bone", "metal", "concrete", "glass"], "combat impacts retain all requested materials")
	check(FP_AUDIO.WHOOSH.has("bare") and FP_AUDIO.WHOOSH.has("cleaver") and FP_AUDIO.WHOOSH.has("staff"), "whooshes remain scaled by weapon family")
	for sound in ["glass_crack_1", "glass_crack_2", "glass_crack_3", "glass_burst", "fluid_pour_loop", "fluid_splash", "fluid_splat"]:
		check(FLUID_SOUND.stream(sound) != null, "%s is wired" % sound)

	print("V01_SOUND_PASS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
