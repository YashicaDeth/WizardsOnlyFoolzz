class_name KillShot
extends RefCounted

## Which shots are worth stopping the world for.
##
## `KillCam` has been the X-ray finisher since it was written, and until now
## only an execution ever fired it -- a melee ending, at arm's length, on
## somebody already down. A rifle that reaches across the bone yard is the other
## occasion for it, and this decides when.
##
## The decision is here rather than inside the eight-thousand-line hunt for one
## reason: the failure this can have is firing the camera over a wound the
## victim would have walked away from, and that is a rule worth being able to
## test without instantiating a world.

## Weapons whose kills earn the camera. A shotgun that happens to finish
## somebody does not: the shot has to be the kind you line up, or the flourish
## stops meaning anything by being everywhere.
const FINISHER_WEAPONS := ["sniper"]

## Organs whose rupture is the reason somebody died rather than a detail of how.
## A ruptured gut is a slow death and a bad finisher; a brain or a heart is the
## shot ending on contact, which is what the camera is claiming happened.
const VITAL_ORGANS := ["brain", "heart", "spine"]


## The payload for `KillCam.trigger()`, or empty when this shot did not earn it.
##
## `zone` is where the round landed, `snapshot` is the victim's anatomy *after*
## the hit. Empty is the normal answer: most shots are not finishers and the
## caller is expected to carry on without one.
static func earned(weapon_id: String, zone: String, snapshot: Dictionary) -> Dictionary:
	if not FINISHER_WEAPONS.has(weapon_id):
		return {}
	# The camera says "this is over". If they are still alive it is lying, and a
	# player who watches an X-ray finisher and then gets shot by the subject of
	# it will not trust the next one.
	if not bool(snapshot.get("dead", false)):
		return {}
	var organ := _vital_lost(zone, snapshot)
	if organ.is_empty():
		# Dead, but not from anything the plate could show rupturing -- bled out
		# from an earlier wound, or a limb hit that finished somebody already
		# nearly gone. Real deaths, wrong occasion.
		return {}
	return {
		"zone": zone,
		"organ": organ,
		"label": "%s / %s" % [_weapon_label(weapon_id), organ.to_upper().replace("_", " ")],
	}


## The vital organ this shot destroyed, preferring one in the zone that was hit
## so a head shot is reported as the brain rather than as whichever vital organ
## happens to be listed first.
static func _vital_lost(zone: String, snapshot: Dictionary) -> String:
	var organs: Dictionary = snapshot.get("organs", {}) if snapshot.get("organs") is Dictionary else {}
	var fallback := ""
	for organ_id in VITAL_ORGANS:
		var organ: Dictionary = organs.get(organ_id, {}) if organs.get(organ_id) is Dictionary else {}
		if organ.is_empty() or not bool(organ.get("ruptured", false)):
			continue
		if str((BaselineHuman.ORGAN_LAYOUT.get(organ_id, {}) as Dictionary).get("zone", "")) == zone:
			return str(organ_id)
		if fallback.is_empty():
			fallback = str(organ_id)
	return fallback


static func _weapon_label(weapon_id: String) -> String:
	var weapon: Dictionary = HunterArsenal.WEAPONS.get(weapon_id, {}) if HunterArsenal.WEAPONS.get(weapon_id) is Dictionary else {}
	return str(weapon.get("label", weapon_id.to_upper()))
