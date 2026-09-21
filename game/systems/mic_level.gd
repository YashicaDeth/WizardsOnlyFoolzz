class_name MicLevel
extends Node

## Live microphone amplitude, for the waveform on the dialogue screen.
##
## Separate from `VoiceInput` on purpose. That runs Vosk in another process and
## returns words; this stays inside Godot and returns loudness, every frame.
## Words arrive when you stop speaking, which is far too late to draw a wave
## with — the visual has to answer "is it hearing me" while you are still
## mid-sentence.
##
## Both open the microphone at once. Windows shared mode allows that, and if a
## driver refuses, this degrades to reporting silence while Vosk keeps working:
## the waveform going flat is a much smaller loss than losing the transcript.

const BUS_NAME := "MicCapture"

var capture: AudioEffectCapture
var player: AudioStreamPlayer
var level := 0.0
var active := false


func _ready() -> void:
	set_process(false)


func start() -> bool:
	if active:
		return true
	# Godot refuses to open an input stream at all without this, and it is off
	# by default, so a build that never sets it reports permanent silence and
	# looks like a broken meter rather than a missing permission.
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		ProjectSettings.set_setting("audio/driver/enable_input", true)

	var index := AudioServer.get_bus_index(BUS_NAME)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS_NAME)
	# Muted, not silent-by-volume: without this the microphone is routed to the
	# speakers and the player hears themselves with a frame of latency, which
	# is intolerable and is the classic version of this bug.
	AudioServer.set_bus_mute(index, true)

	capture = null
	for effect_index in AudioServer.get_bus_effect_count(index):
		var effect := AudioServer.get_bus_effect(index, effect_index)
		if effect is AudioEffectCapture:
			capture = effect
			break
	if capture == null:
		capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(index, capture)

	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = BUS_NAME
	add_child(player)
	player.play()
	active = true
	set_process(true)
	return true


func stop() -> void:
	if not active:
		return
	if player != null and is_instance_valid(player):
		player.stop()
		player.queue_free()
	active = false
	level = 0.0
	set_process(false)


func _process(_delta: float) -> void:
	if capture == null:
		return
	var frames := capture.get_frames_available()
	if frames <= 0:
		# Decay rather than hold. A meter frozen at its last value during a gap
		# in the stream reads as a stuck needle.
		level = maxf(0.0, level - 0.06)
		return
	var buffer := capture.get_buffer(frames)
	var peak := 0.0
	# Every eighth frame. At 44.1kHz a full scan is thousands of samples per
	# visual frame for a number that only has to be roughly right.
	var index := 0
	while index < buffer.size():
		var sample: Vector2 = buffer[index]
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		index += 8
	# Gained up: conversational speech on a desk microphone peaks well under
	# full scale, and an honest 0..1 meter would sit flat for a normal voice.
	level = clampf(peak * 3.2, 0.0, 1.0)
