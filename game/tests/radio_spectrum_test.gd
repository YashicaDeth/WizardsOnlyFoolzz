extends Node

## Audio-reactive visuals need a real spectrum reading behind them, not a
## number invented from `strength` alone — a station cutting in and out
## mid-word should visibly flicker with it. Headless has no real DSP behind
## a dummy audio driver, so this covers what is actually verifiable without
## one: the analyzer is really on the bus, in the right slot, and the
## reading is honestly zero rather than a fake nonzero number whenever
## nothing is actually playing.

const RADIO_AUDIO := preload("res://systems/radio_audio.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var radio: Node = RADIO_AUDIO.new()
	add_child(radio)

	var bus_index := AudioServer.get_bus_index(RADIO_AUDIO.BUS)
	check(bus_index != -1, "the FieldRadio bus actually exists")
	check(AudioServer.get_bus_effect_count(bus_index) == 4, "band, drive, room and the analyzer — four effects, not three")
	check(AudioServer.get_bus_effect(bus_index, 3) is AudioEffectSpectrumAnalyzer, "the fourth slot is really the analyzer")

	check(absf(radio.audio_energy()) < 0.001, "nothing tuned in yet, so nothing to read")
	check(radio.spectrum_bands() == Vector3.ZERO, "and all three bands agree on that")

	# Directly, rather than through silence()'s own fade-out timing, which a
	# dummy audio driver in headless mode would read as zero regardless of
	# whether the gain gate actually did anything.
	radio.tune_to("music", 0.8)
	radio._gain = 0.0
	check(absf(radio.audio_energy()) < 0.001, "at zero gain there is nothing to read regardless of what is tuned in")

	if failures.is_empty():
		print("radio spectrum: a real tap, honestly zero at rest")
		get_tree().quit(0)
	else:
		print("radio spectrum FAILURES: ", failures)
		get_tree().quit(1)
