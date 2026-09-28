class_name AmbientAudio
extends RefCounted

## Greg, 28 September (question boxes): the sound pass for minutes 0-30.
## Room ambience (the vat room: pumps, bubbling, distant screams, electrical
## hum, heart monitors), footsteps by surface (bare wet feet in the opening,
## louder running), combat hits (bone crack, wet impact, the victim's voice)
## and music beds (a dark drone, industrial rhythm, sparse noise, rising with
## tension). All synthesized, like `SightAudio`: no audio files.

const RATE := 22050
const LOOPS := ["pumps", "bubbling", "hum", "monitor", "drip", "drone", "industrial", "noise_bed"]
const LENGTHS := {
	"pumps": 4.0, "bubbling": 3.0, "hum": 2.0, "monitor": 2.0, "drip": 5.0,
	"drone": 8.0, "industrial": 4.0, "noise_bed": 6.0,
	"scream_far": 2.2, "step_bare": 0.22, "step_tile": 0.16, "step_metal": 0.2,
	"step_water": 0.3, "step_concrete": 0.15, "crack": 0.25, "impact": 0.3, "grunt": 0.45,
}

static var _cache: Dictionary = {}


static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var duration: float = LENGTHS.get(kind, 0.5)
	var frames := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var low := 0.0
	var seed_base := kind.hash()
	for frame in frames:
		var t := float(frame) / RATE
		var cycle := t / duration
		var noise := _noise(frame + seed_base) * 2.0 - 1.0
		var sample := 0.0
		match kind:
			"pumps":
				# Two pistons, slow, with a hiss on each stroke.
				var stroke := pow(maxf(0.0, sin(TAU * cycle * 2.0)), 3.0)
				sample = sin(TAU * 41.0 * t) * stroke * 0.5 + noise * stroke * 0.08
			"bubbling":
				var pop := 1.0 if _noise(frame / 900 + seed_base) > 0.7 else 0.0
				sample = sin(TAU * (300.0 + 500.0 * _noise(frame / 900)) * t) * exp(-fmod(t * 24.0, 1.0) * 6.0) * pop * 0.3
			"hum":
				sample = sin(TAU * 50.0 * t) * 0.3 + sin(TAU * 100.0 * t) * 0.12 + sin(TAU * 150.0 * t) * 0.05
			"monitor":
				# A heart monitor two rooms away: a beep a second.
				var local := fmod(t, 1.0)
				sample = sin(TAU * 980.0 * t) * (1.0 if local < 0.09 else 0.0) * 0.25
			"drip":
				for drop in [0.7, 2.3, 3.9]:
					var at := t - float(drop)
					if at >= 0.0:
						sample += sin(TAU * lerpf(1400.0, 700.0, clampf(at * 12.0, 0.0, 1.0)) * at) * exp(-at * 30.0) * 0.4
			"drone":
				for voice in [[55.0, 0.0], [55.4, 1.7], [82.5, 0.9], [36.7, 2.4]]:
					sample += sin(TAU * float(voice[0]) * t + float(voice[1])) * 0.16
				sample *= 0.7 + 0.3 * sin(TAU * cycle)
			"industrial":
				# A slow machine rhythm: a thud, a clank, a hiss.
				var beat := fmod(t, 1.0)
				sample = sin(TAU * 60.0 * t) * exp(-beat * 10.0) * 0.5
				var off := fmod(t + 0.5, 1.0)
				sample += noise * exp(-off * 25.0) * 0.25
			"noise_bed":
				low = lerpf(low, noise, 0.02)
				sample = low * 0.5 * (0.6 + 0.4 * sin(TAU * cycle * 1.5))
			"scream_far":
				var pitch := 520.0 + 180.0 * sin(TAU * 3.0 * t) + 60.0 * noise
				low = lerpf(low, sin(TAU * pitch * t), 0.12)
				sample = low * sin(PI * cycle) * 0.35
			"step_bare":
				# A wet slap: a soft thump and a splash of noise.
				sample = sin(TAU * 90.0 * t) * exp(-t * 40.0) * 0.5 + noise * exp(-t * 28.0) * 0.35
			"step_tile":
				sample = noise * exp(-t * 60.0) * 0.5 + sin(TAU * 220.0 * t) * exp(-t * 50.0) * 0.3
			"step_metal":
				sample = sin(TAU * 410.0 * t) * exp(-t * 22.0) * 0.3 + noise * exp(-t * 55.0) * 0.3
			"step_water":
				low = lerpf(low, noise, 0.25)
				sample = low * exp(-t * 12.0) * 0.6
			"step_concrete":
				sample = noise * exp(-t * 70.0) * 0.45 + sin(TAU * 120.0 * t) * exp(-t * 45.0) * 0.3
			"crack":
				# Bone giving: a sharp dry snap, then splinters.
				sample = noise * exp(-t * 90.0) * 0.9
				if t > 0.03:
					sample += (1.0 if _noise(frame / 60 + seed_base) > 0.75 else 0.0) * noise * exp(-(t - 0.03) * 30.0) * 0.4
			"impact":
				# Wet flesh: a deep thud with a squelch on top.
				low = lerpf(low, noise, 0.08)
				sample = sin(TAU * 70.0 * t) * exp(-t * 18.0) * 0.6 + low * exp(-t * 12.0) * 0.5
			"grunt":
				var pitch := lerpf(190.0, 120.0, cycle)
				sample = (sin(TAU * pitch * t) + 0.5 * sin(TAU * pitch * 2.0 * t) + 0.3 * noise) * sin(PI * cycle) * 0.35
		var value := clampi(roundi(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)
		bytes.encode_s16(frame * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if kind in LOOPS:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = frames
	_cache[kind] = wav
	return wav


## A one-shot at a point in the world (hits, far screams, enemy steps).
static func play_at(host: Node, kind: String, at: Vector3, volume_db := -4.0, pitch := 1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(kind)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	host.add_child(player)
	player.global_position = at
	player.play()
	player.finished.connect(player.queue_free)


static func _noise(value: int) -> float:
	var x := (value * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10007) / 10007.0


## Greg, 28 September: a hit you can hear. A wet impact on every blow, a
## bone crack when something breaks, and the victim's voice while alive.
static func hit(host: Node, at: Vector3, result: Dictionary, dead := false) -> Array[String]:
	var played: Array[String] = ["impact"]
	play_at(host, "impact", at, -2.0, 0.9 + randf() * 0.2)
	if not str(result.get("fracture", "")).is_empty() or bool(result.get("severed", false)):
		played.append("crack")
		play_at(host, "crack", at, 0.0, 0.9 + randf() * 0.25)
	if not dead:
		played.append("grunt")
		play_at(host, "grunt", at + Vector3.UP * 0.4, -5.0, 0.85 + randf() * 0.35)
	return played


## Footsteps, called from `BodyCamFeel.apply`: a step every stride on the
## floor, the surface from the body's "surface" meta (bare wet feet unless a
## scene says otherwise), louder and quicker when running.
const STRIDE := 1.55
const RUN_SPEED := 5.0

static func step(camera: Camera3D, body: CharacterBody3D, delta: float) -> bool:
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	if not body.is_on_floor() or speed < 0.6:
		return false
	var walked := float(camera.get_meta("step_walked", 0.0)) + speed * delta
	var stride := STRIDE * (1.2 if speed > RUN_SPEED else 1.0)
	if walked < stride:
		camera.set_meta("step_walked", walked)
		return false
	camera.set_meta("step_walked", walked - stride)
	var player := camera.get_node_or_null("Footsteps") as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "Footsteps"
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		camera.add_child(player)
	var surface := str(body.get_meta("surface", "bare"))
	player.stream = stream("step_" + surface)
	player.volume_db = -8.0 if speed > RUN_SPEED else -15.0
	player.pitch_scale = 0.9 + _noise(int(walked * 1000.0) + Time.get_ticks_msec()) * 0.2
	if player.is_inside_tree():
		player.play()
	return true
