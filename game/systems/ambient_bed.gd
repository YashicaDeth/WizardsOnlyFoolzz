class_name AmbientBed
extends Node

## Greg, 28 September (question boxes): every opening room gets its own
## ambience, and a music bed under it (a dark drone, an industrial rhythm,
## sparse noise) that rises with tension. The scene sets `tension` (0..1);
## far screams come now and then where the profile has them.

const AMBIENT_AUDIO := preload("res://systems/ambient_audio.gd")
## Per room: loop layers with their volume, and whether screams carry here.
const PROFILES := {
	"vat": {"layers": {"pumps": -22.0, "bubbling": -24.0, "hum": -28.0, "monitor": -30.0, "drip": -26.0}, "screams": true},
	"bay": {"layers": {"hum": -28.0, "industrial": -26.0, "drip": -28.0}, "screams": true},
	"drains": {"layers": {"drip": -20.0, "noise_bed": -26.0, "pumps": -32.0}, "screams": false},
	"arcade": {"layers": {"hum": -26.0, "monitor": -32.0}, "screams": false},
	"city": {"layers": {"noise_bed": -22.0, "drip": -30.0}, "screams": true},
	"support": {"layers": {"hum": -26.0, "industrial": -30.0}, "screams": false},
}
## The music bed: each layer fades in above its tension threshold. Greg, 28
## September: near silence. The bed stays, but low, under breath, heartbeat,
## footsteps and the far screams.
const MUSIC := {"drone": [0.0, -32.0, -20.0], "industrial": [0.45, -36.0, -24.0], "noise_bed": [0.7, -36.0, -26.0]}
const SCREAM_GAP := Vector2(16.0, 38.0)

static var force_in_tests := false

var profile := "vat"
var tension := 0.2
var layers: Dictionary = {}
var music: Dictionary = {}
var scream_player: AudioStreamPlayer
## Your heartbeat, always there, faster and louder with tension (Greg: near
## silence, but breath and heartbeat stay clear).
var heart: AudioStreamPlayer
## The tank has its own heartbeat (TankView); the vat mutes this one then.
var heart_muted := false
var scream_in := 12.0
var screams_heard := 0


static func wanted() -> bool:
	return force_in_tests or OS.get_environment("ATG_TEST_MODE") != "1"


func setup(room: String) -> AmbientBed:
	profile = room if PROFILES.has(room) else "vat"
	name = "AmbientBed"
	return self


func _ready() -> void:
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	var room: Dictionary = PROFILES[profile]
	for kind: String in room.layers:
		layers[kind] = _loop(kind, float(room.layers[kind]), bus)
	var music_bus := "Music" if AudioServer.get_bus_index("Music") >= 0 else bus
	for kind: String in MUSIC:
		music[kind] = _loop(kind, -60.0, music_bus)
	scream_player = AudioStreamPlayer.new()
	scream_player.bus = bus
	scream_player.stream = AMBIENT_AUDIO.stream("scream_far")
	add_child(scream_player)
	heart = AudioStreamPlayer.new()
	heart.name = "Heart"
	heart.bus = bus
	heart.stream = preload("res://systems/sight_audio.gd").stream("heartbeat")
	add_child(heart)
	heart.play()


func _loop(kind: String, volume: float, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = kind.capitalize().replace(" ", "")
	player.stream = AMBIENT_AUDIO.stream(kind)
	player.volume_db = volume
	player.bus = bus
	add_child(player)
	player.play()
	return player


func _process(delta: float) -> void:
	tension = clampf(tension, 0.0, 1.0)
	heart.pitch_scale = lerpf(0.9, 1.7, tension)
	heart.volume_db = -80.0 if heart_muted else lerpf(-24.0, -10.0, tension)
	for kind: String in MUSIC:
		var shape: Array = MUSIC[kind]
		var rise := clampf((tension - float(shape[0])) / maxf(0.01, 1.0 - float(shape[0])), 0.0, 1.0)
		var target := -60.0 if tension < float(shape[0]) else lerpf(float(shape[1]), float(shape[2]), rise)
		var player := music[kind] as AudioStreamPlayer
		player.volume_db = move_toward(player.volume_db, target, delta * 12.0)
	if not bool((PROFILES[profile] as Dictionary).screams):
		return
	scream_in -= delta
	if scream_in <= 0.0:
		scream_in = randf_range(SCREAM_GAP.x, SCREAM_GAP.y)
		scream_player.pitch_scale = randf_range(0.75, 1.15)
		scream_player.volume_db = randf_range(-26.0, -18.0)
		scream_player.play()
		screams_heard += 1
