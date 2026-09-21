class_name ClothingShell
extends RefCounted

## Clothes, as the layer a blow meets before skin.
##
## Bodies are naked meshes with wounds painted straight onto them, so a bullet
## opens skin it never passed through and a slash shreds flesh that should have
## had a jacket in the way first. That is the "cuts in clothes" gap: without a
## garment layer there is nowhere for it to land.
##
## This is that layer, cut to the rig that exists. Garments hang off the same
## six damage zones the anatomy already tracks, and the shell mesh is the same
## revolution profile as the flesh pushed slightly outward — no skeleton, no
## skinning, no UVs, because the bodies have none of those either.
##
## Balance is one-way on purpose. Cloth absorbs part of the first hits and then
## it is gone: integrity only falls until something mends it, so clothing is
## ablative cover rather than armour, and a long fight always ends naked. A rig
## with no wardrobe entry for a zone is naked there and behaves exactly as
## before, which is what keeps every existing damage number intact.

## The six damage zones garments hang off. Mirrors
## `AnatomyComponent.DEFAULT_ZONES` rather than reading it, so this file never
## loads the anatomy to answer a clothing question.
const ZONES := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]

## How far the shell stands off the skin, in metres. Clears the flesh at every
## ring including the shoulder line, close enough that it never reads as a
## second body.
const CLOTH_LIFT := 0.012

## Fraction of a blow cloth eats while it holds. Edges meet weave and slow;
## bullets punch through it; blunt barely notices it is there.
const ABSORB := {
	"cut": 0.30,
	"shear": 0.30,
	"puncture": 0.20,
	"ballistic": 0.20,
	"blunt": 0.05,
}
const ABSORB_DEFAULT := 0.15

## Integrity lost per point of damage. A 30-damage slash costs 0.6: two solid
## hits open the garment, a graze barely marks it. Tuned so the first exchange
## of a fight looks clothed and the end of one does not.
const WEAR_PER_DAMAGE := 0.02


## A dressed body. Every zone starts whole; damage is what changes that.
static func fresh_wardrobe() -> Dictionary:
	var wardrobe := {}
	for zone in ZONES:
		wardrobe[zone] = 1.0
	return wardrobe


## What a blow does to the garment over a zone, and what is left for the skin.
## Returns `{absorbed, passed, breached, integrity}`. A zone with no entry is
## naked and passes everything, so undressed rigs behave exactly as before.
static func resolve_hit(wardrobe: Dictionary, zone_id: String, damage: float, damage_type: String) -> Dictionary:
	var integrity := float(wardrobe.get(zone_id, 0.0))
	if integrity <= 0.0 or damage <= 0.0:
		return {"absorbed": 0.0, "passed": damage, "breached": false, "integrity": 0.0}
	var rate: float = ABSORB.get(damage_type, ABSORB_DEFAULT)
	# Ragged cloth stops less than whole cloth. The absorb falls with what is
	# left rather than holding full value until the moment it tears, or the
	# last thread would stop a sword like a new jacket.
	var absorbed := damage * rate * integrity
	var remaining := maxf(0.0, integrity - damage * WEAR_PER_DAMAGE)
	wardrobe[zone_id] = remaining
	return {
		"absorbed": absorbed,
		"passed": damage - absorbed,
		"breached": remaining <= 0.0 and integrity > 0.0,
		"integrity": remaining,
	}


## Repair hook for the economy: cloth comes back by purchase or loot, never by
## waiting. Clamped, because mending past whole is how you get armour.
static func mend(wardrobe: Dictionary, zone_id: String, amount: float) -> float:
	var patched := clampf(float(wardrobe.get(zone_id, 0.0)) + amount, 0.0, 1.0)
	wardrobe[zone_id] = patched
	return patched


## What a tailor charges to make a wardrobe whole again, in rust scrip. Missing
## zones are naked, not damaged — there is nothing to mend, so they price at
## zero. This is the hook a vendor calls: it prices and `mend()` repairs, and
## the wallet moves through the existing inventory pattern, which is where a
## tailor belongs rather than in here. Who sells it and where is a content
## decision, not a systems one.
const MEND_PRICE_PER_FULL := 20


static func price_to_mend(wardrobe: Dictionary) -> int:
	var total := 0.0
	for zone in ZONES:
		if wardrobe.has(zone):
			total += (1.0 - clampf(float(wardrobe.get(zone, 0.0)), 0.0, 1.0)) * MEND_PRICE_PER_FULL
	return int(ceil(total))


## The garment mesh for a zone: its own flesh profile revolved one lift further
## out. Same silhouette language as the body under it, which is what makes a
## tear read as torn clothing rather than a second wound.
static func shell_mesh(zone_id: String, half_height: float) -> ArrayMesh:
	var rings: Array = []
	for ring: Vector3 in BodyMesh.scaled(BodyMesh.profile_for(zone_id), half_height):
		rings.append(Vector3(ring.x, ring.y + CLOTH_LIFT, ring.z + CLOTH_LIFT))
	return BodyMesh.revolve(rings)


## Cloth, worn. Dark and rough, paling as it shreds so a breached garment reads
## threadbare at a glance rather than needing a second system to say so.
## `soak` is blood dried into the weave, 0 clean to 1 saturated: it drags the
## cloth toward dried-blood dark, which is how a jacket that has been in a
## fight keeps showing it after the bleeding stops.
static func shell_material(coverage: float, soak := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("2e2a26").lightened((1.0 - clampf(coverage, 0.0, 1.0)) * 0.45)
	material.albedo_color = material.albedo_color.lerp(Color("3d0907"), clampf(soak, 0.0, 1.0) * 0.7)
	material.roughness = 0.94
	material.metallic = 0.0
	return material


## Blood dried into the weave, per rig per zone. Integrity is what the garment
## is; soak is what has happened to it — tracked apart so mending the tear
## does not wash out the stain. Keyed by rig instance like the wet feet in
## `Footprints`, and with the same cleanup debt: rigs are few and capped by
## the population, so this is a note rather than a leak danger.
static var _soak: Dictionary = {}


static func stain(owner: Object, zone_id: String, amount: float) -> float:
	if owner == null or amount <= 0.0:
		return 0.0
	var key := "%d:%s" % [owner.get_instance_id(), zone_id]
	var soaked := clampf(float(_soak.get(key, 0.0)) + amount, 0.0, 1.0)
	_soak[key] = soaked
	return soaked


static func soak_of(owner: Object, zone_id: String) -> float:
	if owner == null:
		return 0.0
	return float(_soak.get("%d:%s" % [owner.get_instance_id(), zone_id], 0.0))
