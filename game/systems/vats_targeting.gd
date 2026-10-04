class_name VatsTargeting
extends RefCounted

## Aimed X-ray: slowed time, one body, its parts as targets.
##
## Greg, 2026-10-04: *"VATS-like system built on the existing X-ray: slowed
## time, target cybernetic organs/parts, rupture and explode them (Sniper Elite
## kill-cam x Fallout VATS). Some parts armoured; parts give different stat
## effects."* Controller first.
##
## Nothing here is a second anatomy. Every target is read off the body's own
## `AnatomyComponent` (its organs and the hardware actually installed in it),
## every armour figure is the one `apply_hit()` already charges, and every shot
## lands through `BaselineHuman.hit()` so the wound, the spray, the chunks and
## the kill cam are the ones a normal round earns. VATS only chooses *where*.
##
## The effect table below is an assistant proposal, not Greg's decision
## (AgentHub/queue/questions/vats_part_effects.md): limbs and the hardware in
## them disarm or slow, the eyes and head hardware blind, the lungs and spine
## wind and slow. Organs keep the consequences they already had.

## How slow the world runs while a part is being chosen. Slower than the wheel:
## this is a held breath, not a menu.
const TIME_SCALE := 0.2
## Real seconds of chosen time before the world catches up on its own.
const FOCUS_SECONDS := 4.0
## Real seconds the world stays slow after the trigger, so the round is seen
## to arrive.
const FOLLOW_SECONDS := 0.45
## L2 and R2 pressed this close together (either order) is the chord. Any
## slower and it is aiming then firing, which stays exactly what it was.
const CHORD_WINDOW := 0.2
## Right-stick deflection that counts as a flick to the next part, and the
## dead band it has to return through before another one counts.
const STICK_FLICK := 0.6
const STICK_REST := 0.3
## A round put deliberately into an organ does more to it than one that
## happened to find it: this is the aimed share on top of `apply_hit()`'s own.
const AIMED_ORGAN_SHARE := 1.1
## Rounds put into hardware: how much of the blow the hardware itself takes,
## before its own plate.
const AIMED_IMPLANT_SHARE := 2.5
## A part reads as plated from here up, and the overlay draws it as plate.
const PLATED_AT := 0.15
## A limb is crippled (and its effect lands) at the same 40% the fracture
## rule in `AnatomyComponent.apply_hit()` already uses.
const CRIPPLED_AT := 0.40
## A blinded fighter sees this share of what they used to.
const BLIND_SIGHT := 0.2
## A slowed fighter keeps this share of their pace.
const SLOWED_PACE := 0.5

const ZONE_EFFECTS := {
	"head": "blind",
	"left_arm": "disarm", "right_arm": "disarm",
	"left_leg": "slow", "right_leg": "slow",
}
const ORGAN_EFFECTS := {
	"left_lung": "slow", "right_lung": "slow", "spine": "slow",
}
## Torso hardware by what it does for the body.
const PROFILE_EFFECTS := {
	"bellows": "slow", "filter_stack": "slow", "spine_cage": "slow",
}
## Head to toe, so a stick pushed down walks down the body.
const ORDER := ["eyes", "head", "brain", "left_arm", "right_arm", "torso", "left_lung", "right_lung", "heart", "liver", "spine", "gut", "left_leg", "right_leg"]
const LABELS := {
	"eyes": "EYES", "brain": "BRAIN", "heart": "HEART", "left_lung": "LEFT LUNG",
	"right_lung": "RIGHT LUNG", "liver": "LIVER", "gut": "GUT", "spine": "SPINE",
	"left_arm": "LEFT ARM", "right_arm": "RIGHT ARM", "left_leg": "LEFT LEG", "right_leg": "RIGHT LEG",
}

## The live session. Empty `subject_id` means VATS is off.
var subject_id := ""
var parts: Array[Dictionary] = []
var index := 0
var focus := 0.0
## Counting down after the trigger; VATS ends when it runs out.
var follow := -1.0
var _stick_armed := true


func is_active() -> bool:
	return not subject_id.is_empty()


func is_resolving() -> bool:
	return follow >= 0.0


func current() -> Dictionary:
	if parts.is_empty():
		return {}
	return parts[clampi(index, 0, parts.size() - 1)]


## Opens on one body. False (and stays off) if it has nothing left to aim at.
func begin(rig: BaselineHuman) -> bool:
	end()
	if rig == null or not is_instance_valid(rig) or rig.anatomy == null or rig.anatomy.dead:
		return false
	parts = parts_of(rig)
	if parts.is_empty():
		return false
	subject_id = rig.subject_id
	focus = FOCUS_SECONDS
	follow = -1.0
	_stick_armed = true
	# Open on the heaviest thing it can do: hardware first, because hardware is
	# what this was asked for, then whatever is first head to toe.
	index = 0
	for position in parts.size():
		if str(parts[position].kind) == "implant":
			index = position
			break
	return true


func end() -> void:
	subject_id = ""
	parts.clear()
	index = 0
	focus = 0.0
	follow = -1.0


## Real (unscaled) seconds. True while VATS should stay open.
func tick(real_delta: float) -> bool:
	if not is_active():
		return false
	if follow >= 0.0:
		follow -= real_delta
		return follow > 0.0
	focus -= real_delta
	return focus > 0.0


func step(direction: int) -> Dictionary:
	if parts.is_empty():
		return {}
	index = wrapi(index + direction, 0, parts.size())
	return current()


## The right stick, read every frame: one flick, one part. Down and right walk
## down the body, up and left walk back up it. Returns the step taken (0 if
## none) so the caller can tick a sound or a prompt off it.
func read_stick(stick: Vector2) -> int:
	var amount := maxf(absf(stick.x), absf(stick.y))
	if amount < STICK_REST:
		_stick_armed = true
		return 0
	if not _stick_armed or amount < STICK_FLICK:
		return 0
	_stick_armed = false
	var forward := stick.x if absf(stick.x) >= absf(stick.y) else stick.y
	var direction := 1 if forward > 0.0 else -1
	step(direction)
	return direction


## Every part of this body that can be chosen, head to toe. Each carries its
## armour (what `apply_hit()` will actually take off a round sent there) and
## the effect breaking it has.
static func parts_of(rig: BaselineHuman) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if rig == null or rig.anatomy == null:
		return out
	var anatomy := rig.anatomy
	for site_id in anatomy.installed_parts:
		var part: Dictionary = anatomy.installed_parts[site_id]
		var zone := str(AnatomyComponent.INSTALL_SITES.get(site_id, site_id))
		if anatomy.implant_condition(str(site_id)) <= 0.0 or (rig.severed.has(zone) and zone != str(site_id)):
			continue
		out.append({
			"id": "implant:%s" % site_id,
			"kind": "implant",
			"site": str(site_id),
			"zone": zone,
			"label": str(part.get("name", part.get("id", "hardware"))).to_upper(),
			# Its own plate, worn down with it.
			"armour": snappedf(float(part.get("armor", 0.0)) * anatomy.implant_condition(str(site_id)), 0.01),
			"effect": _implant_effect(zone, str(part.get("profile", ""))),
			"order": ORDER.find(zone) - 0.5,
		})
	if not rig.severed.has("head") and not bool(rig.get_meta("vats_eyes_gone", false)):
		out.append(_organic(rig, "eyes", "head", "blind"))
	for organ_id in BaselineHuman.ORGAN_LAYOUT:
		if not anatomy.organ_ok(organ_id):
			continue
		var zone := str((BaselineHuman.ORGAN_LAYOUT[organ_id] as Dictionary).zone)
		if rig.severed.has(zone):
			continue
		out.append(_organic(rig, str(organ_id), zone, str(ORGAN_EFFECTS.get(organ_id, ""))))
	for zone in BaselineHuman.LIMBS:
		if rig.severed.has(zone):
			continue
		out.append(_organic(rig, zone, zone, str(ZONE_EFFECTS.get(zone, ""))))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.order) < float(b.order))
	return out


static func _organic(rig: BaselineHuman, id: String, zone: String, effect: String) -> Dictionary:
	return {
		"id": id,
		"kind": "limb" if BaselineHuman.LIMBS.has(id) else ("sense" if id == "eyes" else "organ"),
		"zone": zone,
		"label": str(LABELS.get(id, id.to_upper())),
		# Behind whatever hardware sits over that zone, exactly as a round is.
		"armour": snappedf(rig.anatomy.zone_armor(zone), 0.01),
		"effect": effect,
		"order": float(ORDER.find(id)),
	}


static func _implant_effect(zone: String, profile: String) -> String:
	if zone == "torso":
		return str(PROFILE_EFFECTS.get(profile, ""))
	return str(ZONE_EFFECTS.get(zone, ""))


static func is_plated(part: Dictionary) -> bool:
	return float(part.get("armour", 0.0)) >= PLATED_AT


## Where on the body this part is, for the overlay and for the round's aim.
static func anchor(rig: BaselineHuman, part: Dictionary) -> Vector3:
	var zone := str(part.get("zone", "torso"))
	var zone_node := rig.parts.get(zone) as Node3D
	match str(part.get("kind", "")):
		"organ":
			var organ := rig.organ_parts.get(str(part.id)) as Node3D
			if organ != null and is_instance_valid(organ) and organ.is_inside_tree():
				return organ.global_position
		"implant":
			if zone_node != null and is_instance_valid(zone_node):
				var hardware := zone_node.get_node_or_null("InstalledHardware") as Node3D
				if hardware != null and hardware.is_inside_tree():
					return hardware.global_position
		"sense":
			if zone_node != null and is_instance_valid(zone_node) and zone_node.is_inside_tree():
				# The face, a little forward of the skull's centre.
				return zone_node.global_position + zone_node.global_transform.basis.z * 0.11 + Vector3.UP * 0.03
	if zone_node != null and is_instance_valid(zone_node) and zone_node.is_inside_tree():
		return zone_node.global_position
	return rig.global_position + Vector3.UP * 1.1


## One round arriving at the chosen part. Goes through `BaselineHuman.hit()`
## so armour, wound, spray, chunks and death are the ordinary ones; the
## return is `hit()`'s own result with what VATS added: `vats_part`,
## `broken` and `effect` (the effect only when it broke this time).
static func strike(rig: BaselineHuman, part: Dictionary, damage: float, impulse: float, direction: Vector3, damage_type := "ballistic") -> Dictionary:
	var zone := str(part.get("zone", "torso"))
	var kind := str(part.get("kind", ""))
	var id := str(part.get("id", ""))
	var result: Dictionary
	var broken := false
	match kind:
		"organ":
			var was_ok := rig.anatomy.organ_ok(id)
			result = rig.hit(zone, damage, impulse, damage_type, id, direction)
			var applied := float(result.get("damage", 0.0))
			if rig.anatomy.organ_ok(id) and not rig.anatomy.dead:
				rig.anatomy.damage_organ(id, applied * AIMED_ORGAN_SHARE)
			broken = was_ok and not rig.anatomy.organ_ok(id)
			result["organ"] = rig.anatomy.organs.get(id, {}).duplicate()
		"implant":
			var site := str(part.get("site", zone))
			var plate := float((rig.anatomy.installed_parts.get(site, {}) as Dictionary).get("armor", 0.0))
			var before := rig.anatomy.implant_condition(site)
			# The hardware takes the round first; what gets past its plate
			# reaches the meat it is bolted into.
			rig.anatomy.damage_implant(site, damage * AIMED_IMPLANT_SHARE * (1.0 - clampf(plate, 0.0, 0.85)))
			result = rig.hit(zone, damage * 0.5, impulse, damage_type, "", direction)
			broken = before > 0.0 and rig.anatomy.implant_condition(site) <= 0.0
			if broken:
				_blow_hardware(rig, site, zone)
			result["implant_condition"] = rig.anatomy.implant_condition(site)
		"sense":
			# Not an organ the anatomy tracks, so the round is told so — an
			# empty organ id here would send it on into the brain.
			result = rig.hit(zone, damage * 0.6, impulse, damage_type, "eyes", direction)
			broken = float(result.get("damage", 0.0)) >= 4.0 and not bool(rig.get_meta("vats_eyes_gone", false))
			if broken:
				rig.set_meta("vats_eyes_gone", true)
		_:
			var ceiling := float((AnatomyComponent.DEFAULT_ZONES.get(zone, {"health": 100.0}) as Dictionary).get("health", 100.0))
			var was_whole := rig.zone_health(zone) > ceiling * CRIPPLED_AT
			result = rig.hit(zone, damage, impulse, damage_type, "", direction)
			broken = was_whole and (rig.zone_health(zone) <= ceiling * CRIPPLED_AT or bool(result.get("severed", false)))
	result["zone"] = str(result.get("zone", zone))
	result["vats_part"] = id
	result["broken"] = broken
	result["effect"] = str(part.get("effect", "")) if broken else ""
	return result


## Hardware that has been shot to nothing comes off the body. The rig redraws
## a zone's hardware from what is installed, so it is enough to hide the piece
## that was there; its condition (zero) is what every system reads.
static func _blow_hardware(rig: BaselineHuman, site: String, zone: String) -> void:
	if site != zone:
		return
	var zone_node := rig.parts.get(zone) as Node3D
	if zone_node == null or not is_instance_valid(zone_node):
		return
	var hardware := zone_node.get_node_or_null("InstalledHardware") as Node3D
	if hardware != null:
		hardware.visible = false


## What a broken part does to the fighter it was in. Writes the actor record
## the Hunt's own AI already reads (`speed`, `disarmed`) plus two flags its
## perception and grip recovery check (`blinded`, `vats_disarmed`). Returns
## true if this changed anything.
static func apply_effect(actor: Dictionary, effect: String) -> bool:
	match effect:
		"slow":
			if bool(actor.get("vats_slowed", false)):
				return false
			actor["vats_slowed"] = true
			actor["speed"] = float(actor.get("speed", 3.7)) * SLOWED_PACE
			return true
		"disarm":
			if bool(actor.get("vats_disarmed", false)):
				return false
			actor["disarmed"] = true
			actor["vats_disarmed"] = true
			return true
		"blind":
			if bool(actor.get("blinded", false)):
				return false
			actor["blinded"] = true
			actor["tracking_light"] = false
			return true
	return false


## What a fighter's eyes are worth to `PERCEPTION.visibility()`.
static func sight(actor: Dictionary) -> float:
	return BLIND_SIGHT if bool(actor.get("blinded", false)) else 1.0
