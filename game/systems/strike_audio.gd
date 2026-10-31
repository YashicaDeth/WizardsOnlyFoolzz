class_name StrikeAudio
extends Node3D

## What a swing sounds like. Two voices, synthesized once into sample streams
## (no audio files, per the project's procedural rule):
##
##   WHOOSH  a noise band swept downward — the air the blade moves. Pitched by
##           how fast the tip travels, louder the more the blow is committed.
##   CRACK   a short snap and chirp that lands ~80 ms after a hard swing's
##           whoosh starts: the cable whipping after the blade, which is the
##           same order the trail draws them in.
##
## Fed the same per-frame weapon state as `StrikeTrail`; it decides onsets
## itself (speed crossing up through a threshold) so a held, fast weapon does
## not machine-gun. Routed through `AudioBus` "Bodies" -> SFX.

const RATE := 22050
const ONSET_SPEED := 5.0
const REARM_SPEED := 2.5
const CRACK_COMMIT := 0.7
const CRACK_DELAY := 0.08

var swings := 0
var cracks := 0
var _armed := true
var _last_tip := Vector3.ZERO
var _has_last := false
var _crack_in := -1.0
var _whoosh: AudioStreamPlayer3D
var _crack: AudioStreamPlayer3D


func _ready() -> void:
	top_level = true
	_whoosh = _voice("Whoosh", _make("whoosh", 0.32), 18.0)
	_crack = _voice("Crack", _make("crack", 0.16), 26.0)


func feed(tip: Vector3, delta: float, commitment: float, present := true) -> void:
	if _crack_in >= 0.0:
		_crack_in -= delta
		if _crack_in < 0.0:
			_crack.global_position = _last_tip
			_crack.pitch_scale = randf_range(0.92, 1.1)
			_crack.play()
			cracks += 1
	if not present:
		_has_last = false
		return
	var speed := (tip - _last_tip).length() / maxf(delta, 1e-4) if _has_last else 0.0
	_last_tip = tip
	_has_last = true
	if _armed and speed > ONSET_SPEED:
		_armed = false
		swings += 1
		_whoosh.global_position = tip
		_whoosh.pitch_scale = clampf(0.75 + speed * 0.035, 0.75, 1.45)
		_whoosh.volume_db = lerpf(-16.0, -3.0, clampf(commitment, 0.0, 1.0))
		_whoosh.play()
		if commitment >= CRACK_COMMIT:
			_crack_in = CRACK_DELAY
	elif not _armed and speed < REARM_SPEED:
		_armed = true


func _voice(voice_name: String, stream: AudioStream, max_distance: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = voice_name
	player.stream = stream
	player.max_distance = max_distance
	player.unit_size = 3.0
	add_child(player)
	AudioBus.route(player, "Bodies")
	return player


func _make(kind: String, duration: float) -> AudioStreamWAV:
	var frames := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var lp := 0.0
	var seed_value := 1234567
	for frame in frames:
		var t := float(frame) / RATE
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed_value) / float(0x7fffffff) * 2.0 - 1.0
		var sample := 0.0
		if kind == "whoosh":
			# Swell then fall: the blade arrives, passes, leaves. A one-pole low
			# pass whose cutoff sweeps down turns white noise into moving air.
			var env := sin(PI * clampf(t / duration, 0.0, 1.0)) ** 1.6
			var cutoff := lerpf(0.55, 0.06, t / duration)
			lp += (noise - lp) * cutoff
			sample = lp * env * 1.4
		else:
			# The crack: a hard transient, then a fast downward chirp — a cable
			# snapping taut, not a gunshot.
			var env := exp(-t * 55.0)
			var chirp := sin(TAU * (2600.0 - 9000.0 * t) * t)
			sample = (noise * 0.7 * exp(-t * 180.0)) + chirp * 0.45 * env
		var value := clampi(int(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)
		bytes.encode_s16(frame * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
