class_name ProximityVoice
extends Node

## Local push-to-talk transport for conversations with nearby people.
## It captures a transient microphone buffer, reports only timing/level to the
## host, then discards the samples. Speech recognition and authored spoken
## replies plug in after this boundary; neither belongs in the resolution UI.

signal capture_started(subject_id: String)
signal capture_finished(subject_id: String, result: Dictionary)
signal capture_failed(reason: String)

const BUS_NAME := "NPCVoiceCapture"
const MIN_UTTERANCE := 0.16

var active := false
var target_id := ""
var level := 0.0
var available := false
var status := "MIC INITIALISING"
var captured_frames := 0
var started_msec := 0
var capture: AudioEffectCapture
var microphone: AudioStreamPlayer
var target_anchor: Node3D


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") == "1":
		available = true
		status = "MIC READY / TEST TRANSPORT"
		set_process(true)
		return
	_setup_capture_bus()


func _setup_capture_bus() -> void:
	var bus_index := AudioServer.get_bus_index(BUS_NAME)
	if bus_index < 0:
		AudioServer.add_bus(AudioServer.bus_count)
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, BUS_NAME)
		# The capture effect still receives the signal; it is simply not fed back
		# into the speakers, which would create an immediate echo loop.
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus_index, capture)
	microphone = AudioStreamPlayer.new()
	microphone.name = "MicrophoneTransport"
	microphone.stream = AudioStreamMicrophone.new()
	microphone.bus = BUS_NAME
	add_child(microphone)
	microphone.play()
	available = microphone.playing
	status = "MIC READY / HOLD V" if available else "MIC INPUT UNAVAILABLE"
	set_process(true)


func begin(subject_id: String, anchor: Node3D) -> bool:
	if active:
		return true
	if not available:
		capture_failed.emit(status)
		return false
	target_id = subject_id
	target_anchor = anchor
	captured_frames = 0
	level = 0.0
	started_msec = Time.get_ticks_msec()
	if capture != null:
		capture.clear_buffer()
	active = true
	status = "LISTENING / RELEASE V TO SEND"
	capture_started.emit(target_id)
	return true


func finish(send := true) -> Dictionary:
	if not active:
		return {}
	_process_capture()
	active = false
	var duration := maxf(float(Time.get_ticks_msec() - started_msec) / 1000.0, float(captured_frames) / 44100.0)
	var result := {
		"duration": snappedf(duration, 0.01),
		"peak": snappedf(level, 0.001),
		"frames": captured_frames,
		"sent": send and duration >= MIN_UTTERANCE,
	}
	status = "VOICE SENT / WAITING" if result.sent else "TOO SHORT / HOLD V AND SPEAK"
	var finished_id := target_id
	target_id = ""
	level = 0.0
	if send:
		capture_finished.emit(finished_id, result)
	return result


func cancel() -> void:
	if active:
		finish(false)
	status = "MIC READY / HOLD V" if available else "MIC INPUT UNAVAILABLE"


func _process(_delta: float) -> void:
	if active:
		_process_capture()


func _process_capture() -> void:
	if OS.get_environment("ATG_TEST_MODE") == "1":
		captured_frames += 7350
		level = 0.55
		return
	if capture == null:
		return
	var available_frames := capture.get_frames_available()
	if available_frames <= 0:
		level = move_toward(level, 0.0, 0.05)
		return
	var buffer := capture.get_buffer(available_frames)
	captured_frames += buffer.size()
	var peak := 0.0
	# Sample enough points to drive a responsive meter without walking a huge
	# buffer every render frame.
	@warning_ignore("integer_division")
	var stride := maxi(1, buffer.size() / 96)
	for index in range(0, buffer.size(), stride):
		var stereo: Vector2 = buffer[index]
		peak = maxf(peak, maxf(absf(stereo.x), absf(stereo.y)))
	level = lerpf(level, peak, 0.42)


## Proves the reply originates at the person's head. The small radio click is
## provisional; an authored line or local TTS stream can replace it without
## changing the proximity or dialogue logic.
func play_positional_acknowledgement(anchor: Node3D) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var speaker := AudioStreamPlayer3D.new()
	speaker.name = "VoiceReply"
	speaker.max_distance = 18.0
	speaker.unit_size = 2.5
	speaker.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	speaker.stream = _acknowledgement_stream()
	anchor.add_child(speaker)
	speaker.finished.connect(speaker.queue_free)
	speaker.play()


func _acknowledgement_stream() -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * 0.22)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for index in frames:
		var envelope := 1.0 - float(index) / float(frames)
		var wave := sin(TAU * (170.0 + sin(float(index) * 0.004) * 22.0) * float(index) / rate)
		var sample := int(clampf(wave * envelope * 0.18, -1.0, 1.0) * 32767.0)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream
