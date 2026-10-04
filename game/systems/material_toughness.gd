class_name MaterialToughness
extends RefCounted

## Greg, 5 Oct ~01:45 (AgentHub/data/greg_playtest_b_2026-10-05.md), replacing
## the 25 Sep "authored stages, not Teardown" answer:
##   "A TOUGHNESS SCALE, 5 tiers: 1 soft (dirt, wood, flesh) / 2 medium (brick,
##    drywall) / 3 hard (concrete, steel sheet) / 4 armoured (bunker, vault) /
##    5 sealed (elite bunkers, story doors). Melee breaks 1-2, guns 1-3,
##    explosives 1-4, special charges 5."
##   "What beats the top tiers: explosives (charges, grenades, breach
##    launcher), heavy carried tools over time (thermal drill, cutting torch),
##    chaos magick at high altitude, vehicles ramming."
##
## One table for every breakable that speaks tiers: `VoxelStructure`,
## `DigTerrain`, and later the real map. A source either can or cannot beat a
## material's tier; how fast it gets through is the material's `hp` per voxel
## against the source's damage.

const SOFT := 1
const MEDIUM := 2
const HARD := 3
const ARMOURED := 4
const SEALED := 5

## hp is per 15 cm voxel. `sound` feeds `GoreChunks.impact_sample`, so a
## material's break is synthesised the same way a body layer's hit is.
const MATERIALS := {
	"dirt": {"tier": SOFT, "hp": 6.0, "colour": Color("5a4a3a"), "mass": 1.6,
		"sound": {"freq": 60.0, "noise": 0.9, "decay": 9.0, "gain": 0.5, "character": "slap"}},
	"wood": {"tier": SOFT, "hp": 10.0, "colour": Color("6b4a2c"), "mass": 0.5,
		"sound": {"freq": 180.0, "noise": 0.5, "decay": 12.0, "gain": 0.6, "character": "crack"}},
	"flesh": {"tier": SOFT, "hp": 8.0, "colour": Color("70201c"), "mass": 1.0,
		"sound": {"freq": 90.0, "noise": 0.55, "decay": 6.0, "gain": 0.55, "character": "slap"}},
	"drywall": {"tier": MEDIUM, "hp": 8.0, "colour": Color("b8b0a0"), "mass": 0.7,
		"sound": {"freq": 240.0, "noise": 0.8, "decay": 16.0, "gain": 0.5, "character": "slap"}},
	"brick": {"tier": MEDIUM, "hp": 18.0, "colour": Color("7a3a2a"), "mass": 2.0,
		"sound": {"freq": 320.0, "noise": 0.6, "decay": 14.0, "gain": 0.65, "character": "crack"}},
	"concrete": {"tier": HARD, "hp": 30.0, "colour": Color("6e6a62"), "mass": 2.4,
		"sound": {"freq": 140.0, "noise": 0.7, "decay": 10.0, "gain": 0.7, "character": "crack"}},
	"steel_sheet": {"tier": HARD, "hp": 40.0, "colour": Color("4c5054"), "mass": 3.0,
		"sound": {"freq": 860.0, "noise": 0.12, "decay": 7.0, "gain": 0.7, "character": "crack"}},
	"bunker": {"tier": ARMOURED, "hp": 60.0, "colour": Color("3b3d36"), "mass": 3.2,
		"sound": {"freq": 110.0, "noise": 0.5, "decay": 6.0, "gain": 0.8, "character": "crack"}},
	"vault": {"tier": ARMOURED, "hp": 80.0, "colour": Color("2e3236"), "mass": 4.0,
		"sound": {"freq": 520.0, "noise": 0.1, "decay": 4.0, "gain": 0.8, "character": "crack"}},
	"sealed": {"tier": SEALED, "hp": 120.0, "colour": Color("1f1d22"), "mass": 4.5,
		"sound": {"freq": 70.0, "noise": 0.3, "decay": 3.0, "gain": 0.9, "character": "crack"}},
}

## The highest tier each source can beat. `over_time` sources only bite while
## held on the spot (thermal drill, cutting torch): their damage is per second.
const SOURCES := {
	"melee": {"tier": MEDIUM},
	"firearm": {"tier": HARD},
	"explosive": {"tier": ARMOURED},
	"charge": {"tier": SEALED},
	"cutting_torch": {"tier": ARMOURED, "over_time": true},
	"thermal_drill": {"tier": SEALED, "over_time": true},
	"dig": {"tier": SOFT, "over_time": true},
}

## Chaos magick beats tiers by how high the caster is (Greg: "at high
## altitude"). Not built yet; this is the dial it will read. Tier per metre.
static var chaos_tier_per_metre := 0.0
## Ramming: a vehicle beats the tier its kinetic energy reaches. Joules per
## tier step; a 1.2 t car at 50 km/h (~116 kJ) beats tier 3. A dial.
static var ram_joules_per_tier := 35000.0


static func tier_of(material: String) -> int:
	return int((MATERIALS.get(material, MATERIALS.dirt) as Dictionary).tier)


static func hp_of(material: String) -> float:
	return float((MATERIALS.get(material, MATERIALS.dirt) as Dictionary).hp)


## The tier a source beats. `params` carries what the variable sources need:
## "speed" (m/s) and "mass" (kg) for "vehicle", "altitude" (m) for "chaos".
static func source_tier(source: String, params := {}) -> int:
	match source:
		"vehicle":
			var mass := float(params.get("mass", 0.0))
			var speed := float(params.get("speed", 0.0))
			return clampi(int(0.5 * mass * speed * speed / ram_joules_per_tier), 0, SEALED)
		"chaos":
			return clampi(int(float(params.get("altitude", 0.0)) * chaos_tier_per_metre), 0, SEALED)
	return int((SOURCES.get(source, {"tier": 0}) as Dictionary).tier)


static func can_break(source: String, material: String, params := {}) -> bool:
	return source_tier(source, params) >= tier_of(material)


static func is_over_time(source: String) -> bool:
	return bool((SOURCES.get(source, {}) as Dictionary).get("over_time", false))


## What WorldBreak's weapon kinds are in this table's words.
static func source_for(kind: String) -> String:
	return "firearm" if kind in ["firearm", "round", "gun"] else ("melee" if kind in ["melee", "blade", "blunt", ""] else kind)


static var _sounds: Dictionary = {}


## One break voice per material, synthesised once (`GoreChunks.impact_sample`)
## and cached, so brick, steel and dirt each sound like themselves.
static func play_break(host: Node3D, at: Vector3, material: String) -> void:
	if host == null or not host.is_inside_tree() or host.get_tree().current_scene == null or DisplayServer.get_name() == "headless":
		return
	if not _sounds.has(material):
		var profile: Dictionary = (MATERIALS.get(material, MATERIALS.dirt) as Dictionary).sound
		var rate := 22050
		var bytes := PackedByteArray()
		bytes.resize(int(rate * 0.3) * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(material)
		for frame in bytes.size() / 2:
			var sample := GoreChunks.impact_sample(profile, float(frame) / rate, rng.randf_range(-1.0, 1.0))
			bytes.encode_s16(frame * 2, int(sample * 32000.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.data = bytes
		_sounds[material] = wav
	var player := AudioStreamPlayer3D.new()
	player.stream = _sounds[material]
	player.unit_size = 5.0
	player.max_distance = 40.0
	player.pitch_scale = randf_range(0.9, 1.1)
	AudioBus.route(player, AudioBus.SFX)
	host.get_tree().current_scene.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
