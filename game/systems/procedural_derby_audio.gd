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
## The engine layers used to start at their driving volume the moment the scene
## loaded, and update_engine only runs once the round goes active — so the whole
## countdown played a full-level 41Hz rumble before anyone touched the throttle.
## That was the boom on boot. They fade up to idle instead.
const ENGINE_SILENT := -60.0
const ENGINE_IDLE_LOW := -22.0
const ENGINE_IDLE_HIGH := -40.0
## G5.2. The strain layer only exists above this fraction of full effort, so
## it reads as a distinct band kicking in near redline rather than a third
## tone crossfading continuously alongside the other two.
const STRAIN_THRESHOLD := 0.72
const WARM_UP_SECONDS := 0.9

var engine_low: AudioStreamPlayer3D
var engine_high: AudioStreamPlayer3D
var engine_strain: AudioStreamPlayer3D
var ambience_player: AudioStreamPlayer
var crowd_emitters: Array[AudioStreamPlayer3D] = []
var impact_voices: Array[AudioStreamPlayer3D] = []
var impact_streams: Dictionary = {}
var next_voice := 0
var warm_up := 0.0
var target_low := ENGINE_IDLE_LOW
var target_high := ENGINE_IDLE_HIGH
var target_strain := ENGINE_SILENT


func _ready() -> void:
	_ensure_reverb_bus()
	# G5.2. Three engine layers, each gated to its own load band rather than
	# one pitched sine or two tones crossfaded across the whole range: a low
	# rumble that is present at idle, a mid whine that rises with load, and a
	# strain layer that only exists above STRAIN_THRESHOLD, where a real
	# engine starts to sound like it is being asked for more than it wants to
	# give. The band, not just the pitch, is what tells a cruise from a floor.
	engine_low = _positional("EngineLow", _make_wave("engine_low", 1.25, true), ENGINE_SILENT, 34.0)
	engine_high = _positional("EngineHigh", _make_wave("engine_high", 0.9, true), ENGINE_SILENT, 28.0)
	engine_strain = _positional("EngineStrain", _make_wave("engine_strain", 0.7, true), ENGINE_SILENT, 30.0)
	engine_low.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	engine_high.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	engine_strain.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP

	for kind in ["panel", "glass", "heavy", "meat"]:
		impact_streams[kind] = _make_wave(kind, 0.5, false)
	# G5.3. A shared low-end layer that stacks on top of the material voice
	# when a hit is severe, so severity is heard as added weight rather than
	# only a louder copy of the same single sample.
	impact_streams["body"] = _make_wave("impact_body", 0.6, false)
	for index in IMPACT_VOICES:
		var voice := _positional("ImpactVoice%d" % index, null, -6.0, 60.0)
		impact_voices.append(voice)

	# Ambience stays non-positional on purpose: it is the whole sky, not a source.
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "AshbloomWind"
	ambience_player.stream = _make_wave("wind", 2.8, true)
	ambience_player.volume_db = -24.0
	AudioBus.route(ambience_player, AudioBus.AMBIENCE)
	add_child(ambience_player)

	engine_low.play()
	engine_high.play()
	engine_strain.play()
	ambience_player.play()


## Crowd noise belongs in the stands, not in the player's skull. Called by the
## derby once the grandstand positions are known.
func seed_crowd(positions: Array) -> void:
	for position_value in positions:
		var emitter := _positional("CrowdBank%d" % crowd_emitters.size(), _make_wave("crowd", 0.85, false), -13.0, 70.0)
		emitter.position = position_value
		crowd_emitters.append(emitter)


func attach_engine_to(vehicle: Node3D) -> void:
	for layer in [engine_low, engine_high, engine_strain]:
		if layer.get_parent() != null:
			layer.get_parent().remove_child(layer)
		vehicle.add_child(layer)


func _process(delta: float) -> void:
	if warm_up >= 1.0:
		return
	warm_up = minf(1.0, warm_up + delta / WARM_UP_SECONDS)
	_apply_engine_volume()


## V1.2. A damaged engine does not wait for the driver to ask more of it — it
## already sounds hurt. `condition` is the same 0..1 field the chassis itself
## already reads for handling (`arcade_vehicle.gd`'s `_condition_scale()`);
## this is the audio side of the same number rather than a second damage
## input invented here.
func update_engine(speed: float, throttle: float, condition := 1.0) -> void:
	if engine_low == null:
		return
	var damage := 1.0 - clampf(condition, 0.0, 1.0)
	var load_ratio := clampf(absf(speed) / 24.0, 0.0, 1.0)
	var effort := clampf(load_ratio + absf(throttle) * 0.25, 0.0, 1.0)
	# A rough, uneven idle rather than a clean pitch shift — the engine
	# audibly missing a beat rather than just running quieter.
	var rattle := sin(Time.get_ticks_msec() * 0.001 * (23.0 + damage * 19.0)) * damage * 0.05
	engine_low.pitch_scale = clampf(0.7 + load_ratio * 0.55 + rattle, 0.55, 1.4)
	engine_high.pitch_scale = clampf(0.85 + load_ratio * 0.95 + rattle * 0.6, 0.8, 1.95)
	engine_strain.pitch_scale = clampf(1.05 + load_ratio * 0.5 + rattle, 1.0, 1.6)
	target_low = lerpf(ENGINE_IDLE_LOW, -9.0, effort)
	# The whine only arrives under real load, so cruising and flooring it differ.
	target_high = lerpf(ENGINE_IDLE_HIGH, -13.0, pow(effort, 1.6))
	# G5.2. Its own band: silent below STRAIN_THRESHOLD, then rises fast, so it
	# reads as the engine being asked for more than it wants to give rather
	# than a third tone blended in across the whole range. A wrecked engine
	# earns that band at a fraction of the effort a pristine one needs to.
	var strain_threshold := lerpf(STRAIN_THRESHOLD, STRAIN_THRESHOLD * 0.3, damage)
	var strain := clampf((effort - strain_threshold) / maxf(1.0 - strain_threshold, 0.01), 0.0, 1.0)
	target_strain = lerpf(ENGINE_SILENT, -7.0, strain * strain)
	_apply_engine_volume()


func _apply_engine_volume() -> void:
	if engine_low == null:
		return
	engine_low.volume_db = lerpf(ENGINE_SILENT, target_low, warm_up)
	engine_high.volume_db = lerpf(ENGINE_SILENT, target_high, warm_up)
	engine_strain.volume_db = lerpf(ENGINE_SILENT, target_strain, warm_up)


## G5.3. `material` picks what a hit sounds like; `intensity` decides whether
## a second, shared low-end layer stacks under it. A light and a severe hit
## on the same panel used to differ only by playing the same one-shot louder;
## now a severe hit is audibly a heavier event, not just a bigger version of
## the same one.
const BODY_LAYER_THRESHOLD := 0.5

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
	if strength > BODY_LAYER_THRESHOLD:
		var body_voice := _free_voice()
		if body_voice != null and body_voice != voice:
			var body_strength := (strength - BODY_LAYER_THRESHOLD) / (1.0 - BODY_LAYER_THRESHOLD)
			body_voice.stream = impact_streams["body"]
			body_voice.global_position = at
			body_voice.volume_db = lerpf(-14.0, 4.0, body_strength)
			body_voice.pitch_scale = randf_range(0.82, 0.98) - body_strength * 0.12
			body_voice.play()
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
	# G5.1. This used to send straight to Master, which meant the SFX slider did
	# nothing to the engines, the impacts or the crowd — the loudest things in
	# the game were the only ones outside the mixer.
	AudioBus.ensure()
	if AudioServer.get_bus_index(REVERB_BUS) != -1:
		AudioBus.chain(REVERB_BUS)
		return
	var bus_index := AudioBus.chain(REVERB_BUS)
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
			"engine_strain":
				# G5.2. The redline layer: higher, harder-edged and dirtier than
				# engine_high, so its arrival reads as strain rather than more of
				# the same whine turned up.
				sample = sin(TAU * 340.0 * t) * 0.22 + sin(TAU * 505.0 * t) * 0.16
				sample = clampf(sample * 1.8, -0.85, 0.85)
				sample += (_hash_noise(frame * 7) * 2.0 - 1.0) * 0.16
			"impact_body":
				# G5.3. A shared low-end thud with no material character of its
				# own, meant to stack under a material voice on a severe hit
				# rather than to be heard alone.
				var body_env := exp(-t * 8.0)
				sample = sin(TAU * 46.0 * t) * 0.6 * body_env
				sample += sin(TAU * 24.0 * t) * 0.4 * exp(-t * 5.0)
				sample += (_hash_noise(frame * 2) * 2.0 - 1.0) * 0.15 * body_env
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
