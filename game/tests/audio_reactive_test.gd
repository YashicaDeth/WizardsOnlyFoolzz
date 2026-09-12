extends Node

## The radio driving the picture, checked without a sound card.
##
## Headless Godot mixes into a dummy audio driver, so no test here can prove
## that a loud kick makes the orb flash. What it can prove is everything around
## that: the analyser is actually hung on the bus the player's mixer feeds
## rather than on a private one going round it, asking twice does not hang two,
## the normalisation turns silence into zero and a full signal into one, and a
## band pushed through `drive()` lands on the right dial of the right object.
##
## Those are the four things that were wrong the first time this kind of code
## gets written, and none of them needs a speaker.

const REACTIVE := preload("res://systems/audio_reactive.gd")
const CLOUD := preload("res://systems/point_cloud.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	tree.create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		print("audio reactive: TIMED OUT")
		tree.quit(3))
	await tree.process_frame

	# ---- the window. Silence is nothing, a full signal is everything, and the
	# quiet middle has to land somewhere a shader can see rather than at zero.
	check(AudioReactive.normalise(0.0, 1.0) <= 0.001, "silence is zero")
	check(AudioReactive.normalise(db_to_linear(-6.0), 1.0) >= 0.999, "a loud band is one")
	var quiet := AudioReactive.normalise(db_to_linear(-40.0), 1.0)
	check(quiet > 0.05 and quiet < 0.95, "and a quiet one is neither: %.3f" % quiet)
	# Auto-gain: the same quiet signal reads louder once the rolling peak has
	# fallen, which is what stops a soft passage going flat.
	check(AudioReactive.normalise(db_to_linear(-40.0), 0.5) > quiet,
		"a fallen peak lifts a quiet band")
	check(AudioReactive.normalise(db_to_linear(-40.0), 0.0001) <= 1.0,
		"and the peak floor stops silence dividing into noise")

	# ---- the analyser goes on the bus the mixer owns.
	var radio: AudioReactive = REACTIVE.new()
	add_child(radio)
	var opened := radio.listen("FieldRadio")
	check(opened, "it attaches to the radio bus")
	var index := AudioServer.get_bus_index("FieldRadio")
	check(index != -1, "the bus exists afterwards")
	check(AudioServer.get_bus_send(index) != "Master",
		"and it feeds the player's mixer rather than going round it")
	var analysers := 0
	for slot in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, slot) is AudioEffectSpectrumAnalyzer:
			analysers += 1
	check(analysers == 1, "exactly one analyser is hung on it")

	# ---- asking twice does not hang a second one.
	radio.listen("FieldRadio")
	var again := 0
	for slot in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, slot) is AudioEffectSpectrumAnalyzer:
			again += 1
	check(again == 1, "and asking again does not hang another")

	# ---- an unknown band is nothing, not an error.
	check(absf(radio.band("does_not_exist")) < 0.0001, "an unknown band reads zero")

	# ---- and a band lands on the dial it was mapped to.
	var cloud: PointCloud = CLOUD.new()
	add_child(cloud)
	radio.drive(cloud, {"bass": "audio", "air": "glitch"}, 1.0)
	radio.levels["bass"] = 0.8
	radio.levels["air"] = 0.25
	radio.push_to_driven()
	check(absf(cloud.dial("audio") - 0.8) < 0.0001, "bass reaches the audio dial")
	check(absf(cloud.dial("glitch") - 0.25) < 0.0001, "air reaches the glitch dial")

	# ---- gain scales the whole mapping rather than one band of it.
	radio.release(cloud)
	radio.drive(cloud, {"bass": "audio"}, 0.5)
	radio.push_to_driven()
	check(absf(cloud.dial("audio") - 0.4) < 0.0001, "gain scales what arrives")

	# ---- a freed target does not take the radio down with it.
	cloud.queue_free()
	await tree.process_frame
	radio.push_to_driven()
	check(true, "a target that has gone away is skipped rather than fatal")

	# ---- the beat fires once per kick, not once per frame of one.
	# An array, not an int: GDScript lambdas capture by value, so a counter kept
	# as a plain int is incremented on a copy and reads zero forever afterwards.
	var struck := [0]
	radio.beat_struck.connect(func(_strength: float) -> void: struck[0] += 1)
	for _quiet in 40:
		radio.levels["sub"] = 0.02
		radio.levels["bass"] = 0.02
		radio._detect_beat(0.016)
	var before: int = struck[0]
	for _loud in 6:
		radio.levels["sub"] = 0.9
		radio.levels["bass"] = 0.9
		radio._detect_beat(0.016)
	check(struck[0] == before + 1, "one kick is one beat, not six: %d" % (int(struck[0]) - before))

	if failures.is_empty():
		print("audio reactive: listening")
		tree.quit(0)
	else:
		print("audio reactive FAILURES: ", failures)
		tree.quit(1)
