class_name ProceduralDerbyAudio
extends Node

var engine_player: AudioStreamPlayer
var impact_player: AudioStreamPlayer
var crowd_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer


func _ready() -> void:
	engine_player = _player("EngineLoop", _make_wave("engine", 1.25, true), -15.0)
	impact_player = _player("ImpactOneShot", _make_wave("impact", 0.42, false), -5.0)
	crowd_player = _player("CrowdReaction", _make_wave("crowd", 0.85, false), -11.0)
	ambience_player = _player("AshbloomWind", _make_wave("wind", 2.8, true), -24.0)
	engine_player.play()
	ambience_player.play()


func update_engine(speed: float, throttle: float) -> void:
	if engine_player == null:
		return
	engine_player.pitch_scale = clampf(0.62 + absf(speed) * 0.038, 0.55, 1.72)
	engine_player.volume_db = lerpf(-20.0, -8.0, clampf(absf(speed) / 24.0 + absf(throttle) * 0.2, 0.0, 1.0))


func play_impact(intensity: float) -> void:
	if impact_player == null:
		return
	impact_player.volume_db = lerpf(-15.0, -1.0, clampf(intensity, 0.0, 1.0))
	impact_player.pitch_scale = randf_range(0.72, 1.08)
	impact_player.play()
	if intensity > 0.55 and crowd_player != null:
		crowd_player.volume_db = lerpf(-17.0, -5.0, intensity)
		crowd_player.pitch_scale = randf_range(0.88, 1.12)
		crowd_player.play()


func _player(player_name: String, stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


func _make_wave(kind: String, duration: float, looping: bool) -> AudioStreamWAV:
	var rate := 22050
	var frame_count := roundi(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame in frame_count:
		var t := float(frame) / rate
		var sample := 0.0
		match kind:
			"engine":
				sample = sin(TAU * 52.0 * t) * 0.44 + sin(TAU * 104.0 * t) * 0.2 + sin(TAU * 26.0 * t) * 0.16
			"impact":
				var envelope := exp(-t * 11.0)
				var noise := fmod(sin(float(frame) * 12.9898) * 43758.5453, 2.0) - 1.0
				sample = (noise * 0.65 + sin(TAU * 71.0 * t) * 0.55) * envelope
			"crowd":
				var envelope := sin(clampf(t / duration, 0.0, 1.0) * PI)
				sample = (sin(TAU * 183.0 * t + sin(t * 17.0)) + sin(TAU * 227.0 * t)) * 0.18 * envelope
			_:
				var drift := sin(TAU * 0.37 * t) * 0.4 + sin(TAU * 0.81 * t) * 0.2
				sample = drift * (0.22 + 0.08 * sin(float(frame) * 0.017))
		var value := clampi(roundi(sample * 32760.0), -32768, 32767)
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
