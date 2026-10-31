class_name FpCombatAudio
extends Node

## imp-64. Greg, 5 Oct ~19:00: *"The first person needs a lot of work"*:
## swing and hit sounds. A whoosh when the blade starts to travel, scaled to
## the weapon and the blow, and a hit voiced by what it met (flesh, bone,
## metal, concrete, glass). Recorded CC0 sounds from Freesound, credited in
## `CREDITS.md`; pitch is jittered per play so a chain does not repeat.
## `MeleeDriver` owns one, so every first-person melee owner gets it.

const DIR := "res://audio/fp_combat/"
## Weapon (or `bare`) -> [light whoosh, heavy whoosh, pitch]. A heavier
## weapon moves more air: lower pitch, louder.
const WHOOSH := {
	"bare": ["whoosh_bare", "whoosh_bare", 1.0],
	"cleaver": ["whoosh_light", "whoosh_heavy", 1.0],
	"staff": ["whoosh_staff", "whoosh_staff", 0.82],
	"default": ["whoosh_light", "whoosh_heavy", 0.92],
}
const SURFACES := ["flesh", "bone", "metal", "concrete", "glass"]
## Name fragments that say what a collider is made of, when nothing tags it.
const NAME_HINTS := {
	"glass": ["glass", "window", "pane", "tank", "screen"],
	"metal": ["metal", "steel", "iron", "pipe", "locker", "door", "rail", "grate", "vat", "shutter", "cage", "gate"],
}

var whooshes := 0
var impacts: Dictionary = {}
var last_surface := ""

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % index
		add_child(voice)
		AudioBus.route(voice, "Bodies")
		_voices.append(voice)


## The blade starts to travel (the active phase of a swing).
func whoosh(weapon_id: String, heavy: bool) -> void:
	var row: Array = WHOOSH.get(weapon_id, WHOOSH.default)
	whooshes += 1
	_play(str(row[1] if heavy else row[0]), float(row[2]) * (0.88 if heavy else 1.0), 0.0 if heavy else -3.0)


## A blow landed on `surface` (one of SURFACES).
func impact(surface: String, heavy: bool) -> void:
	if not surface in SURFACES:
		surface = "concrete"
	impacts[surface] = int(impacts.get(surface, 0)) + 1
	last_surface = surface
	_play("hit_" + surface, 0.9 if heavy else 1.0, 0.0 if heavy else -2.5)


## What a collider is, for its hit sound. A body is flesh, or bone when a
## heavy blunt blow lands; then an explicit `surface` meta on the collider or
## a parent, then the kind of node, then its name; concrete otherwise.
static func surface_of(collider: Object, packet: Dictionary = {}) -> String:
	if MeleeDriver.rig_of(collider) != null:
		# ponytail: the driver never sees the anatomy's result, so bone is
		# guessed from the blow; read the fracture report if one gets exposed.
		return "bone" if bool(packet.get("heavy", false)) and str(packet.get("damage_type", "")) == "blunt" else "flesh"
	var node := collider as Node
	for _depth in 6:
		if node == null:
			break
		if node.has_meta("surface"):
			var tagged := str(node.get_meta("surface"))
			if tagged in SURFACES:
				return tagged
		if node is GlassTank:
			return "glass"
		if node is BreakableDoor:
			return "metal"
		var lower := str(node.name).to_lower()
		for surface: String in NAME_HINTS:
			for hint: String in NAME_HINTS[surface]:
				if lower.contains(hint):
					return surface
		node = node.get_parent()
	return "concrete"


func _play(sound: String, pitch: float, volume_db: float) -> void:
	if not _streams.has(sound):
		_streams[sound] = load(DIR + sound + ".ogg")
	var voice := _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = _streams[sound]
	voice.pitch_scale = pitch * _rng.randf_range(0.94, 1.06)
	voice.volume_db = volume_db
	voice.play()
