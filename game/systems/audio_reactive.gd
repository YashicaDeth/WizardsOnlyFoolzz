class_name AudioReactive
extends Node

## The radio drives the picture.
##
## Greg, pointing at pwnisher's "How I Create Audio-Reactive Art": *"audio
## reactive art for the radio"*. In TouchDesigner that is an Audio Analysis CHOP
## wired into whatever you want to move. This is the same thing on the side that
## ships — Godot already has a spectrum analyser, `AudioBus` already routes the
## radio through a named bus, and nothing was ever reading either of them.
##
## What it hands out is six bands, a level and a beat, all 0 to 1, all already
## normalised and smoothed. That last part is the whole job. Raw magnitudes off
## `AudioEffectSpectrumAnalyzerInstance` are tiny linear numbers that differ by
## orders of magnitude between a quiet voice and a loud engine, and a shader
## uniform fed one of those directly does nothing at all for most of a track and
## then clips. So every band goes through dB, then through a window, then
## through a rolling peak that follows the loudest thing heard recently — which
## is what makes a quiet passage still move something instead of going flat.
##
## `drive()` is the reason it exists: hand it a `PointCloud` or a
## `PsychedelicRig` and a map of band to dial, and the radio moves the artwork.

## Where each band sits, in Hz. Six rather than three because the interesting
## split for visuals is not bass/mid/treble — it is *kick* against *body*
## against *air*, and those are narrower than thirds.
const BANDS := {
	"sub": [20.0, 60.0],
	"bass": [60.0, 250.0],
	"low": [250.0, 800.0],
	"mid": [800.0, 2500.0],
	"high": [2500.0, 8000.0],
	"air": [8000.0, 16000.0],
}

## The window, in decibels, that becomes 0 to 1. Anything under the floor is
## silence as far as a visual is concerned; the ceiling is where a normal mix
## sits rather than where clipping is, so the top of the range gets used.
const DB_FLOOR := -62.0
const DB_CEILING := -12.0

## How fast a band rises and falls, per second. Fast up and slow down, because
## that is how a meter has to behave to read as sound rather than as noise —
## a band that falls as fast as it rises flickers and a band that rises slowly
## misses the transient that was the whole point.
const RISE := 26.0
const FALL := 5.5

## The rolling peak decays this much per second, so a loud moment does not
## permanently deafen everything after it.
const PEAK_DECAY := 0.14
const PEAK_FLOOR := 0.18

signal beat_struck(strength: float)

var bus := "FieldRadio"
var listening := false
## Band name to its current 0-1 value. Read these, or read `band()`.
var levels: Dictionary = {}
## Whole-spectrum loudness, 0 to 1.
var level := 0.0
## Decays to zero after each kick. Useful as a one-shot: a flash, a cut, a
## chunk of gore thrown.
var beat := 0.0

var _bus_index := -1
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _peaks: Dictionary = {}
var _bass_average := 0.0
var _beat_hold := 0.0
var _driven: Array[Dictionary] = []


func _ready() -> void:
	name = "AudioReactive"
	# The picture should keep reacting while the pause menu is up, because the
	# radio keeps playing while the pause menu is up.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for band_name: String in BANDS:
		levels[band_name] = 0.0
		_peaks[band_name] = PEAK_FLOOR
	set_process(false)


## Start listening to a bus. Adds the analyser if that bus has not got one —
## idempotent, so two systems can both ask for the radio without fighting.
func listen(bus_name := "FieldRadio") -> bool:
	bus = bus_name
	AudioBus.ensure()
	_bus_index = AudioServer.get_bus_index(bus)
	if _bus_index == -1:
		# `chain()` rather than `add_bus()`: a bus created by hand here would
		# send to Master and walk straight around the player's mixer, which is
		# the exact bug `AudioBus` was written to make impossible.
		_bus_index = AudioBus.chain(bus)
	if _bus_index == -1:
		push_warning("AudioReactive: no bus called %s and none could be made." % bus)
		return false

	var found := -1
	for index in AudioServer.get_bus_effect_count(_bus_index):
		if AudioServer.get_bus_effect(_bus_index, index) is AudioEffectSpectrumAnalyzer:
			found = index
			break
	if found == -1:
		var effect := AudioEffectSpectrumAnalyzer.new()
		# A longer window is steadier and later; a shorter one is twitchy and
		# on time. Visuals want on time.
		effect.buffer_length = 0.1
		effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		AudioServer.add_bus_effect(_bus_index, effect)
		found = AudioServer.get_bus_effect_count(_bus_index) - 1

	var instance := AudioServer.get_bus_effect_instance(_bus_index, found)
	_analyzer = instance as AudioEffectSpectrumAnalyzerInstance
	if _analyzer == null:
		push_warning("AudioReactive: the analyser on %s gave back no instance." % bus)
		return false
	listening = true
	set_process(true)
	return true


func stop() -> void:
	listening = false
	set_process(false)


## One band, 0 to 1. An unknown name is 0 rather than an error, so a shader
## wired to a band this build does not have simply does not move.
func band(band_name: String) -> float:
	return float(levels.get(band_name, 0.0))


## Point the radio at something with dials on it.
##
## `mapping` is band name to dial name — `{"bass": "audio", "air": "glitch"}` —
## and `gain` scales the lot. Anything with `set_dial(String, float)` works, so
## a `PointCloud` and a `PsychedelicRig` are both valid targets and so is
## anything added later that follows the same shape.
func drive(target: Node, mapping: Dictionary, gain := 1.0) -> void:
	if target == null or not target.has_method("set_dial"):
		push_warning("AudioReactive: %s has no set_dial() to drive." % [target])
		return
	_driven.append({"target": target, "mapping": mapping, "gain": gain})


func release(target: Node) -> void:
	for index in range(_driven.size() - 1, -1, -1):
		if (_driven[index] as Dictionary)["target"] == target:
			_driven.remove_at(index)


func _process(delta: float) -> void:
	if not listening or _analyzer == null:
		return
	var loudest := 0.0
	for band_name: String in BANDS:
		var edges: Array = BANDS[band_name]
		var magnitude := _analyzer.get_magnitude_for_frequency_range(
			float(edges[0]), float(edges[1]),
			AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE).length()
		# dB first. Magnitudes are linear and tiny, and the ear — and every
		# visual that is supposed to look like the ear hears — is logarithmic.
		var decibels := linear_to_db(maxf(magnitude, 0.000001))
		var windowed := clampf(inverse_lerp(DB_FLOOR, DB_CEILING, decibels), 0.0, 1.0)

		# Auto-gain against the loudest this band has been lately, so a quiet
		# passage still moves something. Floored, or silence divides into noise.
		var peak := maxf(float(_peaks[band_name]) - PEAK_DECAY * delta, PEAK_FLOOR)
		peak = maxf(peak, windowed)
		_peaks[band_name] = peak
		var scaled := clampf(windowed / peak, 0.0, 1.0)

		var current := float(levels[band_name])
		var rate := RISE if scaled > current else FALL
		levels[band_name] = move_toward(current, scaled, rate * delta)
		loudest = maxf(loudest, float(levels[band_name]))
	level = loudest

	_detect_beat(delta)
	push_to_driven()


## Hand the current bands to everything `drive()` was pointed at. Split out of
## `_process` so that anything holding levels from somewhere other than the
## analyser — a test, a recording, a patch sending bands in over OSC — can push
## them through the same path the radio uses.
func push_to_driven() -> void:
	for entry: Dictionary in _driven:
		# Validity before the cast, not after it. Casting an object that has
		# already been freed throws in GDScript, so a target that went away
		# between frames took the whole radio down with it — which is exactly
		# what happens when a scene changes while something is being driven.
		var held: Variant = entry["target"]
		if not is_instance_valid(held):
			continue
		var target := held as Node
		var gain := float(entry["gain"])
		var mapping: Dictionary = entry["mapping"]
		for band_name: String in mapping:
			target.set_dial(str(mapping[band_name]), band(band_name) * gain)


## A raw magnitude and the loudest this band has been lately, to 0-1. Static and
## pure, because this is the part that is actually easy to get wrong and it can
## be checked without a sound card: silence must be 0, the ceiling must be 1,
## and quiet-but-present must be somewhere a shader can see.
static func normalise(magnitude: float, peak: float) -> float:
	var decibels := linear_to_db(maxf(magnitude, 0.000001))
	var windowed := clampf(inverse_lerp(DB_FLOOR, DB_CEILING, decibels), 0.0, 1.0)
	return clampf(windowed / maxf(peak, PEAK_FLOOR), 0.0, 1.0)


## A kick is bass energy arriving well above where bass has been sitting. Held
## briefly afterwards so two frames of the same hit do not fire twice, which is
## the difference between a beat and a stutter.
func _detect_beat(delta: float) -> void:
	beat = maxf(0.0, beat - delta * 4.2)
	_beat_hold = maxf(0.0, _beat_hold - delta)
	var punch := maxf(band("sub"), band("bass"))
	_bass_average = lerpf(_bass_average, punch, clampf(delta * 2.6, 0.0, 1.0))
	if _beat_hold <= 0.0 and punch > _bass_average * 1.45 and punch > 0.22:
		beat = 1.0
		_beat_hold = 0.11
		beat_struck.emit(punch)
