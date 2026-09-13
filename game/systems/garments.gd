class_name Garments
extends RefCounted

## B7.1 / B7.2. What somebody is wearing, as a layer on a zone rather than a
## number on a character.
##
## The rig has had a coat, a collar and a strap since it was built and none of
## them meant anything: they were geometry, and protection was a stat somewhere
## else. This makes them the same object. A garment covers named zones, and what
## it does — how much it stops, how much it keeps out of the lungs, how warm it
## is — belongs to the garment, so taking a coat off a body takes its protection
## off too and there is no second place where the number lives.
##
## B7.2's claim falls out of that rather than needing its own system: armour is
## what a zone is wearing or carrying, cover is what a zone is behind, and both
## resolve to the same `shielding()` figure that `apply_hit()` reads. There is
## no armour stat to disagree with the coat.

## `shield` is what it stops of a melting hit (B3's radiation path), `plate` is
## ordinary armour against everything else, and `seal` is how much of the air it
## keeps out of somebody standing in a storm.
const CATALOGUE := {
	"ash coat": {
		"covers": ["torso", "left_arm", "right_arm"],
		"shield": 0.32, "plate": 0.12, "seal": 0.35, "warmth": 0.5,
	},
	"lead wrap": {
		"covers": ["torso"],
		"shield": 0.62, "plate": 0.18, "seal": 0.2, "warmth": 0.1,
	},
	"filter mask": {
		"covers": ["head"],
		"shield": 0.1, "plate": 0.04, "seal": 0.75, "warmth": 0.05,
	},
	"scrap plate": {
		"covers": ["torso", "left_leg", "right_leg"],
		"shield": 0.22, "plate": 0.34, "seal": 0.05, "warmth": 0.15,
	},
	"pit leathers": {
		"covers": ["left_arm", "right_arm", "left_leg", "right_leg"],
		"shield": 0.12, "plate": 0.2, "seal": 0.1, "warmth": 0.4,
	},
}


## Everything `worn` puts over `zone_id`, added up and capped. Layers stack,
## because two coats are warmer than one, but never to nothing getting through:
## somebody in every garment in the game is still somebody standing in it.
static func shielding(worn: Array, zone_id: String) -> Dictionary:
	var shield := 0.0
	var plate := 0.0
	var seal := 0.0
	var warmth := 0.0
	for name in worn:
		var garment: Dictionary = CATALOGUE.get(str(name).to_lower(), {})
		if garment.is_empty():
			continue
		if not (zone_id in (garment.get("covers", []) as Array)):
			continue
		shield += float(garment.get("shield", 0.0))
		plate += float(garment.get("plate", 0.0))
		seal += float(garment.get("seal", 0.0))
		warmth += float(garment.get("warmth", 0.0))
	return {
		"shield": clampf(shield, 0.0, 0.85),
		"plate": clampf(plate, 0.0, 0.8),
		"seal": clampf(seal, 0.0, 0.9),
		"warmth": clampf(warmth, 0.0, 1.0),
	}


## B7.2. Cover is the same figure arriving from the world instead of from a
## wardrobe. A wall between somebody and a hit protects the zone it is in front
## of exactly the way a plate strapped to that zone does, so it is added here
## rather than special-cased in whatever does the shooting.
static func with_cover(protection: Dictionary, cover: float) -> Dictionary:
	var combined := protection.duplicate()
	var behind := clampf(cover, 0.0, 1.0)
	combined["plate"] = clampf(float(protection.get("plate", 0.0)) + behind * 0.6, 0.0, 0.9)
	combined["shield"] = clampf(float(protection.get("shield", 0.0)) + behind * 0.5, 0.0, 0.9)
	return combined


## What the zones of a body are wearing, for anything that has to draw it.
static func covered_zones(worn: Array) -> Array[String]:
	var zones: Array[String] = []
	for name in worn:
		var garment: Dictionary = CATALOGUE.get(str(name).to_lower(), {})
		for zone_id in (garment.get("covers", []) as Array):
			if not zones.has(str(zone_id)):
				zones.append(str(zone_id))
	return zones
