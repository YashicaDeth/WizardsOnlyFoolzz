class_name ProceduralDerbyAudio
extends Node

## Positional derby audio. Every player here was previously a non-positional
## AudioStreamPlayer, so the engine, impacts, crowd and wind all played flat in
## the listener's head regardless of where they happened in the world. Sources
## that move now move, impacts happen where they happen, and the quarry has a
## reverb bus.
##
## Waveforms remain generated. They are provisional per ART-DIRECTION.md's
## placeholder rule: authored per layer later, same call signatures.

const REVERB_BUS := "DerbyQuarry"
const IMPACT_VOICES := 6

var engine_low: AudioStreamPlayer3D
var engine_high: AudioStreamPlayer3D
var ambience_player: AudioStreamPlayer
var crowd_emitters: Array[AudioStreamPlayer3D] = []
var impact_voices: Array[AudioStreamPlayer3D] = []
var impact_streams: Dictionary = {}
var next_voice := 0


func _ready() -> void:
	_ensure_reverb_bus()
	# Two engine layers crossfaded by load. One pitched sine reads as a mosquito;
	# a rumble under a whine reads as a drivetrain.
	engine_low = _positional("EngineLow", _make_wave("engine_low", 1.25, true), -16.0, 34.0)
	engine_high = _positional("EngineHigh", _make_wave("engine_high", 0.9, true), -30.0, 28.0)
	engine_low.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	engine_high.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP

	for kind in ["panel", "glass", "heavy", "meat"]:
		impact_streams[kind] = _make_wave(kind, 0.5, false)
	for index in IMPACT_VOICES:
		var voice := _positional("ImpactVoice%d" % index, null, -6.0, 60.0)
		impact_voices.append(voice)

	# Ambience stays non-positional on purpose: it is the whole sky, not a source.
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "AshbloomWind"
	ambience_player.stream = _make_wave("wind", 2.8, true)
	ambience_player.volume_db = -24.0
	add_child(ambience_player)

	engine_low.play()
	engine_high.play()
	ambience_player.play()


## Crowd noise belongs in the stands, not in the player's skull. Called by the
## derby once the grandstand positions are known.
func seed_crowd(positions: Array) -> void:
	for position_value in positions:
		var emitter := _positional("CrowdBank%d" % crowd_emitters.size(), _make_wave("crowd", 0.85, false), -13.0, 70.0)
		emitter.position = position_value
		crowd_emitters.append(emitter)


func attach_engine_to(vehicle: Node3D) -> void:
	for layer in [engine_low, engine_high]:
		if layer.get_parent() != null:
			layer.get_parent().remove_child(layer)
		vehicle.add_child(layer)


func update_engine(speed: float, throttle: float) -> void:
	if engine_low == null:
		return
	var load_ratio := clampf(absf(speed) / 24.0, 0.0, 1.0)
	var effort := clampf(load_ratio + absf(throttle) * 0.25, 0.0, 1.0)
	engine_low.pitch_scale = clampf(0.7 + load_ratio * 0.55, 0.6, 1.4)
	engine_high.pitch_scale = clampf(0.85 + load_ratio * 0.95, 0.8, 1.95)
	engine_low.volume_db = lerpf(-22.0, -9.0, effort)
	# The whine only arrives under real load, so cruising and flooring it differ.
	engine_high.volume_db = lerpf(-40.0, -13.0, pow(effort, 1.6))


func play_impact(intensity: float, at: Vector3 = Vector3.ZERO, material: String = "panel") -> void:
	var voice := _free_voice()
	if voice == null:
		return
	var strength := clampf(intensity, 0.0, 1.0)
	var kind := material if impact_streams.has(material) else "panel"
	if strength > 0.72 and kind == "panel":
		kind = "heavy"
	voice.stream = impact_streams[kind]
	voice.global_position = at
	voice.volume_db = lerpf(-18.0, 0.0, strength)
	voice.pitch_scale = randf_range(0.78, 1.12) * (0.86 if kind == "heavy" else 1.0)
	voice.play()
	if strength > 0.55:
		_react_crowd(strength)


func _react_crowd(strength: float) -> void:
	for emitter in crowd_emitters:
		if emitter.playing:
			continue
		emitter.volume_db = lerpf(-19.0, -6.0, strength)
		emitter.pitch_scale = randf_range(0.88, 1.14)
		emitter.play()


func _free_voice() -> AudioStreamPlayer3D:
	for offset in impact_voices.size():
		var voice: AudioStreamPlayer3D = impact_voices[(next_voice + offset) % impact_voices.size()]
		if not voice.playing:
			next_voice = (next_voice + offset + 1) % impact_voices.size()
			return voice
	# All voices busy: steal the oldest so a big pileup still cracks.
	next_voice = (next_voice + 1) % impact_voices.size()
	return impact_voices[next_voice]


func _positional(player_name: String, stream: AudioStream, volume: float, max_distance: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	if stream != null:
		player.stream = stream
	player.volume_db = volume
	player.max_distance = max_distance
	player.unit_size = 8.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.panning_strength = 1.35
	if AudioServer.get_bus_index(REVERB_BUS) != -1:
		player.bus = REVERB_BUS
	add_child(player)
	return player


func _ensure_reverb_bus() -> void:
	if AudioServer.get_bus_index(REVERB_BUS) != -1:
		return
	var bus_index := AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, REVERB_BUS)
	AudioServer.set_bus_send(bus_index, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.72
	reverb.damping = 0.55
	reverb.spread = 0.85
	reverb.wet = 0.22
	reverb.dry = 0.9
	AudioServer.add_bus_effect(bus_index, reverb)


func _make_wave(kind: String, duration: float, looping: bool) -> AudioStreamWAV:
	var rate := 22050
	var frame_count := roundi(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame in frame_count:
		var t := float(frame) / rate
		var sample := 0.0
		match kind:
			"engine_low":
				sample = sin(TAU * 41.0 * t) * 0.46 + sin(TAU * 27.0 * t) * 0.24 + sin(TAU * 82.0 * t) * 0.12
				sample *= 0.9 + 0.1 * sin(TAU * 6.5 * t)
			"engine_high":
				sample = sin(TAU * 146.0 * t) * 0.2 + sin(TAU * 219.0 * t) * 0.13
				sample += (_hash_noise(frame) * 0.5 - 0.25) * 0.22
			"panel":
				var panel_env := exp(-t * 13.0)
				sample = (_hash_noise(frame) * 2.0 - 1.0) * 0.6 * panel_env
				sample += sin(TAU * 168.0 * t) * 0.4 * panel_env
			"glass":
				var glass_env := exp(-t * 17.0)
				sample = (_hash_noise(frame * 3) * 2.0 - 1.0) * 0.5 * glass_env
				sample += sin(TAU * 2400.0 * t) * 0.3 * glass_env
				sample += sin(TAU * 3300.0 * t) * 0.2 * exp(-t * 24.0)
			"heavy":
				var heavy_env := exp(-t * 6.5)
				sample = (_hash_noise(frame) * 2.0 - 1.0) * 0.5 * heavy_env
				sample += sin(TAU * 58.0 * t) * 0.62 * heavy_env
				sample += sin(TAU * 31.0 * t) * 0.34 * exp(-t * 4.0)
			"meat":
				# Wet, low, and short. Deliberately unpleasant.
				var meat_env := exp(-t * 9.0)
				sample = (_hash_noise(frame * 5) * 2.0 - 1.0) * 0.42 * meat_env
				sample += sin(TAU * 74.0 * t + sin(t * 220.0) * 2.0) * 0.5 * meat_env
			"crowd":
				var crowd_env := sin(clampf(t / duration, 0.0, 1.0) * PI)
				sample = (sin(TAU * 183.0 * t + sin(t * 17.0)) + sin(TAU * 227.0 * t)) * 0.18 * crowd_env
				sample += (_hash_noise(frame) * 2.0 - 1.0) * 0.12 * crowd_env
			_:
				var drift := sin(TAU * 0.37 * t) * 0.4 + sin(TAU * 0.81 * t) * 0.2
				sample = drift * (0.22 + 0.08 * sin(float(frame) * 0.017))
		var value := clampi(roundi(clampf(sample, -1.0, 1.0) * 32760.0), -32768, 32767)
		if value < 0:
			value += 65536
		bytes[frame * 2] = value & 0xff
		bytes[frame * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frame_count
	return stream


func _hash_noise(frame: int) -> float:
	var value := sin(float(frame) * 12.9898) * 43758.5453
	return value - floorf(value)
