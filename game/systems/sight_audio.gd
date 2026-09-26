class_name SightAudio
extends RefCounted

## Greg, 26 September (question boxes): K = a low choir hum that swells with
## strain; J = a sonar ping in time with the sweep; the weak wall crumbles,
## hatches creak, wires spit sparks. Made in code like OpeningAudio, so there
## are no files to import; each sound is built once and cached.

const RATE := 22050
static var _cache := {}


static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var looping := kind in ["choir", "sonar"]
	var duration: float = {"choir": 4.0, "sonar": 1.0 / 0.35, "crumble": 1.1, "creak": 0.7, "spark": 0.45}.get(kind, 0.5)
	var frames := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for frame in frames:
		var t := float(frame) / RATE
		var sample := 0.0
		match kind:
			"choir":
				# Five low voices a hair out of tune, breathing slowly.
				for voice in [[110.0, 0.0], [110.6, 1.3], [164.8, 2.1], [220.4, 0.7], [82.4, 3.0]]:
					var vibrato := sin(TAU * 4.6 * t + float(voice[1])) * 0.8
					sample += sin(TAU * (float(voice[0]) + vibrato) * t) * 0.14
				sample *= 0.75 + 0.25 * sin(TAU * t / duration)
			"sonar":
				# One ping per sweep (the shader's sweep runs at 0.35 per second).
				var envelope := exp(-t * 7.0)
				sample = sin(TAU * 1180.0 * t) * envelope * 0.55 + sin(TAU * 590.0 * t) * envelope * 0.2
			"crumble":
				var envelope := exp(-t * 4.0)
				var grit := _noise(frame) * 2.0 - 1.0
				var chunk := sin(TAU * 70.0 * t) * exp(-t * 10.0)
				sample = grit * envelope * 0.5 + chunk * 0.5
			"creak":
				var pitch := lerpf(180.0, 260.0, t / duration) + sin(TAU * 23.0 * t) * 20.0
				sample = sin(TAU * pitch * t) * 0.4 * sin(PI * t / duration)
				sample += (_noise(frame * 3) - 0.5) * 0.08
			"spark":
				var crackle := 1.0 if _noise(frame / 40) > 0.6 else 0.0
				sample = (_noise(frame * 7) * 2.0 - 1.0) * crackle * exp(-t * 6.0) * 0.7
				sample += sin(TAU * 60.0 * t) * exp(-t * 3.0) * 0.25
		var value := clampi(roundi(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)
		bytes.encode_s16(frame * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = frames
	_cache[kind] = wav
	return wav


## A one-shot at a place in the world (crumble, creak, spark).
static func play_at(host: Node, kind: String, at: Vector3, volume_db := -4.0) -> AudioStreamPlayer3D:
	if host == null or not host.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(kind)
	player.volume_db = volume_db
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	host.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	return player


static func _noise(value: int) -> float:
	var x := (value * 1103515245 + 12345) & 0x7fffffff
	return float(x % 10000) / 10000.0
