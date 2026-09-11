extends Node

## What the radio actually sounds like, and how badly.
##
## A9.5. `procedural_derby_audio.gd` established the approach this follows — a
## named bus with effects on it, waveforms generated in code rather than shipped
## as assets — so this reuses that rather than inventing a second audio idiom.
##
## The reason it is a bus chain and not a volume slider: a weak station is not a
## *quiet* station. It is a narrower, dirtier, more distant one. So the signal
## strength drives four things at once —
##
## - **the band narrows** toward a telephone-thin pass as reception falls,
## - **the drive climbs**, because the receiver is straining,
## - **the room opens up**, so a weak station sounds like it is arriving from
##   somewhere rather than sitting in your ear,
## - **and the carrier hiss crossfades up underneath it.**
##
## Which means the audio agrees with `WireRadio._degrade()`, where the *text* of
## a weak transmission drops syllables. Both halves say the same thing: you are
## not hearing less of it, you are hearing it wrongly.

const BUS := "FieldRadio"
const SAMPLE_RATE := 22050

## Per station kind, the bed it broadcasts. Voice is not synthesised — these are
## carriers and textures under the written transmission, which is where the
## content actually lives.
const BEDS := {
	"wire": {"tone": 210.0, "grit": 0.30, "pulse": 2.4},
	"preacher": {"tone": 148.0, "grit": 0.42, "pulse": 1.1},
	"numbers": {"tone": 620.0, "grit": 0.10, "pulse": 0.7},
	"music": {"tone": 196.0, "grit": 0.16, "pulse": 0.35},
	"hook": {"tone": 330.0, "grit": 0.34, "pulse": 1.7},
	"static": {"tone": 0.0, "grit": 1.0, "pulse": 0.0},
}

## Seconds to fade out when the radio is put away. Not a hard cut — every hard
## cut in this game is a bug — but short enough that walking away from a set
## silences it rather than trailing you.
const FADE_OUT := 0.22

var carrier: AudioStreamPlayer
var station: AudioStreamPlayer
var strength := 0.0
var kind := "static"
## Whether anybody is actually listening. This used to be implicit in
## `strength`, which was exactly backwards: strength 0 is not silence, it is a
## dead band, and a dead band is the *loudest* carrier hiss this thing makes.
## So the receiver ran flat out in every scene that owned a handheld, including
## after the player got out of the car.
var listening := false

var _gain := 0.0

var _band: AudioEffectBandPassFilter
var _drive: AudioEffectDistortion
var _room: AudioEffectReverb
var _beds: Dictionary = {}


func _ready() -> void:
	_ensure_bus()
	for bed in BEDS:
		_beds[bed] = _make_bed(str(bed))
	carrier = _player("Carrier", _beds["static"])
	station = _player("Station", _beds["wire"])
	# Nothing plays until somebody tunes it. The players used to start in
	# `_ready` and there was no stop path anywhere in the class.
	set_process(true)


func _ensure_bus() -> void:
	var index := AudioServer.get_bus_index(BUS)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
		# Order matters: shape the band first, then drive what is left, then put
		# it in a room. Driving before filtering makes mush rather than a radio.
		AudioServer.add_bus_effect(index, AudioEffectBandPassFilter.new())
		AudioServer.add_bus_effect(index, AudioEffectDistortion.new())
		AudioServer.add_bus_effect(index, AudioEffectReverb.new())
	_band = AudioServer.get_bus_effect(index, 0) as AudioEffectBandPassFilter
	_drive = AudioServer.get_bus_effect(index, 1) as AudioEffectDistortion
	_room = AudioServer.get_bus_effect(index, 2) as AudioEffectReverb
	if _drive:
		_drive.mode = AudioEffectDistortion.MODE_LOFI


func _player(node_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.bus = BUS
	player.volume_db = -60.0
	add_child(player)
	return player


## Called by whoever owns the radio, with the current reception. Tuning is
## listening: you are holding the set and turning the dial.
func tune_to(station_kind: String, signal_strength: float) -> void:
	strength = clampf(signal_strength, 0.0, 1.0)
	listening = true
	_gain = 1.0
	var wanted: String = station_kind if BEDS.has(station_kind) else "static"
	if wanted != kind:
		kind = wanted
		if _beds.has(kind):
			station.stream = _beds[kind]
			station.play()


## Put it away. Called when the handheld is lowered or is on any other mode —
## and by anything that leaves a set behind, like getting out of the car.
func silence() -> void:
	listening = false


func _process(delta: float) -> void:
	if _band == null:
		return
	if not listening:
		_gain = maxf(0.0, _gain - delta / FADE_OUT)
	if _gain <= 0.001:
		# Genuinely stopped, not merely turned down: a looping stream left
		# playing at -60dB is still a stream being mixed every frame forever.
		if station.playing:
			station.stop()
		if carrier.playing:
			carrier.stop()
		return
	if not station.playing:
		station.play()
	if not carrier.playing:
		carrier.play()
	# Crossfade. Carrier never leaves entirely, because a perfectly clean
	# reception in this world would be the strangest thing on the band.
	station.volume_db = linear_to_db((clampf(strength, 0.0, 1.0) * 0.85 + 0.02) * _gain)
	carrier.volume_db = linear_to_db(clampf(1.0 - strength, 0.05, 1.0) * 0.5 * _gain)
	# A strong signal is wide; a weak one is a slot. 2600Hz down to a thin 900.
	_band.cutoff_hz = lerpf(900.0, 2600.0, strength)
	_band.resonance = lerpf(1.6, 0.6, strength)
	if _drive:
		_drive.drive = lerpf(0.62, 0.14, strength)
		_drive.post_gain = lerpf(-4.0, -9.0, strength)
	if _room:
		# Distance, not decoration: a weak station is further away.
		_room.room_size = lerpf(0.86, 0.44, strength)
		_room.wet = lerpf(0.42, 0.12, strength)
		_room.dry = lerpf(0.62, 0.95, strength)


## One second of the bed, looped. Written with the same hash-noise trick the
## derby audio uses so the two systems sound like they were built by the same
## hand, because they were.
func _make_bed(bed_kind: String) -> AudioStreamWAV:
	var spec: Dictionary = BEDS.get(bed_kind, BEDS["static"])
	var frames := SAMPLE_RATE
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var tone := float(spec.tone)
	var grit := float(spec.grit)
	var pulse := float(spec.pulse)
	for frame in frames:
		var t := float(frame) / float(SAMPLE_RATE)
		var sample := 0.0
		if tone > 0.0:
			sample += sin(TAU * tone * t) * 0.34
			sample += sin(TAU * tone * 1.5 * t) * 0.12
			if bed_kind == "music":
				# A third and a fifth, detuned, because nothing here is in tune.
				sample += sin(TAU * tone * 1.26 * t) * 0.16
				sample += sin(TAU * tone * 1.49 * t + 0.6) * 0.13
			if pulse > 0.0:
				sample *= 0.62 + 0.38 * maxf(0.0, sin(TAU * pulse * t))
		sample += (_noise(frame) * 2.0 - 1.0) * grit * 0.45
		# A slow wow, the way a salvaged receiver drifts.
		sample *= 0.9 + 0.1 * sin(TAU * 0.23 * t)
		var value := clampi(roundi(clampf(sample, -1.0, 1.0) * 32000.0), -32768, 32767)
		if value < 0:
			value += 65536
		bytes[frame * 2] = value & 0xff
		bytes[frame * 2 + 1] = (value >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav


func _noise(frame: int) -> float:
	var value := int(frame) * 1103515245 + 12345
	value = (value >> 16) & 0x7fff
	return float(value) / 32767.0
