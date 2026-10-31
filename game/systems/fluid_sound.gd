class_name FluidSound
extends RefCounted

## The liquid station's sounds: glass cracks per stage, the burst, the gush
## and the pour, splashes where the pour lands, wading. Greg (5 Oct ~19:00):
## "Fix and improve the pour ... and add sound."
##
## The files are synthesised by tools/synth_fluid_sounds.py (no third-party
## licence). One-shots are positional and free themselves; everything goes
## through AudioBus.route to the SFX bus. `played` counts each name so tests
## can tell a sound was asked for without hearing it.

const DIR := "res://audio/fluid/"
## Global dial: 0 silences every liquid sound.
static var volume := 1.0
static var played: Dictionary = {}
static var _cache: Dictionary = {}


static func stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var path := DIR + sound + ".ogg"
	var loaded: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[sound] = loaded
	return loaded


## A one-shot `sound` at `at` (global), loudness 0..1, pitch jittered a little
## so repeats do not machine-gun.
static func play(parent: Node, sound: String, at: Vector3, loudness := 1.0, pitch := 1.0) -> AudioStreamPlayer3D:
	played[sound] = int(played.get(sound, 0)) + 1
	if parent == null or not parent.is_inside_tree() or volume <= 0.0 or loudness <= 0.0:
		return null
	var clip := stream(sound)
	if clip == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = clip
	player.volume_db = linear_to_db(clampf(loudness * volume, 0.001, 1.0))
	player.pitch_scale = pitch * randf_range(0.94, 1.06)
	player.unit_size = 4.0
	player.max_distance = 40.0
	AudioBus.route(player, AudioBus.SFX)
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	return player


## A looping positional player (the pour), stopped and silent until asked.
static func loop(parent: Node, sound: String) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	var clip := stream(sound)
	if clip is AudioStreamOggVorbis:
		clip = clip.duplicate()
		(clip as AudioStreamOggVorbis).loop = true
	player.stream = clip
	player.unit_size = 5.0
	player.max_distance = 40.0
	player.volume_db = -60.0
	AudioBus.route(player, AudioBus.SFX)
	parent.add_child(player)
	return player


static func reset_counts() -> void:
	played.clear()


static func count(sound: String) -> int:
	return int(played.get(sound, 0))
