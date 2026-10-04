class_name OrganSystem
extends RefCounted

## Organs, cybernetics and the X-ray as ONE system (lab-48).
##
## Greg, 5 Oct ~02:05 (`AgentHub/data/greg_playtest_b_2026-10-05.md`), the spec:
##
## > Rupturable organs and a cohesive cybernetic + organ system that pairs with
## > the X-ray. Bodies take realistic wounds: cut a hole in someone's chest,
## > shoot their stomach open or their ribs, then MANUALLY rip out the heart or
## > another organ, which you can see in X-ray mode.
## > X-ray is how you PEEP someone's cybernetics before deciding to fight them.
## > It shows: where implants and armour plates are; what each implant does
## > (short tags: reflex booster, lung filter); how healthy their organs are and
## > what is already damaged; their loot value.
## > Ripping out: on a corpse (harvest) AND as a finisher on a downed living
## > enemy, but ONLY through a wound you actually made [...] No hole, no rip.
## > Ruptured organs fail in their own way: lungs = breathless, no sprint;
## > heart = fast death; liver/gut = slow bleed; brain = drop. Cybernetic organs
## > can be shorted or overloaded (the shock staff). You can swap harvested
## > organs (natural or cybernetic) into yourself. Harvested organs sell on the
## > market.
##
## Nothing here is a second anatomy. Organ state is `AnatomyComponent.organs`,
## hardware is `AnatomyComponent.installed_parts`, the hole is `Cavity` and
## `BaselineHuman.zone_depth`, what comes out is in `Carry.take_chunk()`'s
## shape and is priced by `Carry.sale_value()`, an implant goes into you
## through `Carry.install_into()` and an organ through
## `AnatomyComponent.replace_organ()`. This file is the rules that join them.
##
## Every number below marked DIAL is an assistant default, not Greg's decision
## (DESIGN/REMASTER_LOG.md, lab-48).

const ImplantCatalog := preload("res://systems/implant_catalog.gd")

# --- dials --------------------------------------------------------------------

## DIAL. A burst heart with nothing pumping for it: seconds to death.
const HEART_DEATH_SECONDS := 6.0
## DIAL. The least a ruptured liver, gut, stomach or kidney bleeds inside, in
## ml/s. ~4300 ml of blood at 6 ml/s is about two minutes on its own: slow.
const SLOW_BLEED_FLOOR := 6.0
## DIAL. Seconds an implant stays dead after one shock.
const SHORT_SECONDS := 6.0
## DIAL. Share of an implant's maximum condition one shock burns. A second
## shock while it is still shorted overloads it: it burns out for good.
const SHORT_WEAR := 0.12
## DIAL. Seconds of holding to rip an organ free, at full grip.
const RIP_SECONDS := 1.5
## DIAL. Progress lost per second once you let go: it slips back in.
const RIP_SLIP_PER_SECOND := 0.7
## DIAL. Tugs per second. The organ gives on each tug and holds between.
const TUG_RATE := 2.2
## DIAL. How far away an organ can be reached by hand.
const RIP_REACH := 2.4
## DIAL. How close to the aim line (metres) an organ has to be to be grabbed.
const RIP_AIM_TOLERANCE := 0.11
## DIAL. Bare hands bruise what they pull: condition lost on the way out.
const HAND_DAMAGE := 0.1
## DIAL. A torso hit opens the chest once the zone has been cut to this layer
## and has this share of its health left or less.
const OPEN_AT_LAYER := GoreChunks.Layer.BONE
const OPEN_AT_HEALTH := 0.75
## DIAL. The X-ray hides the chest's mosaic censor (it censors skin, and the
## X-ray is not looking at skin); an opened chest loses it with the wall.
const XRAY_HIDES_CHEST_CENSOR := true
## DIAL. Under the X-ray: how hard each organ glows in its own colour, and
## how see-through hardware is, so a sternum plate does not hide the heart
## behind it. The skin becomes `xray_shell.gdshader`'s film (the sweep's own
## 62% flesh left a red dummy's organs lost in its red skin).
const XRAY_ORGAN_GLOW := 0.85
const XRAY_HARDWARE := 0.4
const XRAY_SHELL := preload("res://systems/xray_shell.gdshader")
const SHELL_PIECES := ["Shoulder_", "Clavicle_"]

static var _shell: ShaderMaterial


static func xray_shell() -> ShaderMaterial:
	if _shell == null:
		_shell = ShaderMaterial.new()
		_shell.shader = XRAY_SHELL
	return _shell

## What `Carry.sale_value()` starts from for each kind, mirrored for the scan's
## estimate (the scan has no buyer, no market and no spoil clock to ask).
const VALUE_BASE := {"organ": 12, "cybernetic": 24}

## Short tags for the X-ray, by catalogue id. Greg's examples were "reflex
## booster" and "lung filter"; the catalogue has no reflex booster
## (AgentHub/queue/questions/lab48_reflex_booster.md), so these name what is
## actually in `implant_catalog.gd`.
const TAGS := {
	"copper lung bellows": "LUNG BELLOWS",
	"filter trachea": "LUNG FILTER",
	"quiet-heart regulator": "HEART REGULATOR",
	"remote pulse cage": "PULSE CAGE",
	"blackbox liver": "BLACKBOX LIVER",
	"ceramic sternum": "PLATED RIBS",
	"load-bearing spine cage": "SPINE CAGE",
	"left clavicle rail": "CLAVICLE RAIL",
	"rangefinder eye": "RANGEFINDER EYE",
	"optic spool": "OPTIC SPOOL",
	"jaw telemetry nail": "TELEMETRY NAIL",
	"dose counter": "DOSE COUNTER",
	"ledger thumb": "LEDGER THUMB",
	"ankle compass": "ANKLE COMPASS",
	"heel anchors": "HEEL ANCHORS",
	"salvaged torque arm": "TORQUE ARM",
	"ashline industrial arm": "INDUSTRIAL ARM",
	"ashline scrap arm": "SCRAP ARM",
	"six-finger surgical crown": "SURGICAL CROWN",
	"scrying ball": "SCRYING BALL",
	"wetwire chip": "WETWIRE CHIP",
}

## What a piece of hardware does for the organs it sits among. `breath` keeps
## a body breathing with a lung gone, `heartbeat` keeps the blood moving with
## the heart gone, `liver` filters for a ruptured liver. `plate` is passive
## metal: it is armour, it conducts, it does not short. Everything else is a
## powered part that a shock can stop.
const ROLES := {
	"copper lung bellows": "breath",
	"quiet-heart regulator": "heartbeat",
	"remote pulse cage": "heartbeat",
	"blackbox liver": "liver",
	"ceramic sternum": "plate",
	"load-bearing spine cage": "plate",
	"left clavicle rail": "plate",
}

## Where hardware at a torso site sits inside the chest, in the torso part's
## own space (front is -Z), by profile. Anything else sits at the zone centre.
const PLACES := {
	"chest_plate": Vector3(0.0, 0.11, -0.125),
	"bone_rail": Vector3(-0.09, 0.25, -0.09),
	"spine_cage": Vector3(0.0, 0.0, 0.115),
	"regulator": Vector3(-0.02, 0.07, -0.08),
	"pulse_cage": Vector3(-0.05, 0.10, -0.09),
	"bellows": Vector3(0.0, 0.17, -0.06),
	"filter_stack": Vector3(0.0, 0.26, -0.03),
	"organ_box": Vector3(0.09, -0.04, -0.07),
	"optic": Vector3(0.05, 0.03, -0.1),
	"optic_spool": Vector3(-0.05, 0.03, -0.1),
	"jaw_nail": Vector3(0.0, -0.09, -0.08),
}

const ORGAN_LABELS := {
	"brain": "BRAIN", "heart": "HEART", "left_lung": "LEFT LUNG", "right_lung": "RIGHT LUNG",
	"liver": "LIVER", "gut": "GUT", "spine": "SPINE", "stomach": "STOMACH",
	"left_kidney": "LEFT KIDNEY", "right_kidney": "RIGHT KIDNEY",
}
const SLOW_BLEEDERS := ["liver", "gut", "stomach", "left_kidney", "right_kidney"]

const SPARK := Color(1.0, 0.82, 0.42)
const XRAY_CYAN := Color(0.35, 0.95, 0.9)


# --- implants: tags, roles, shorting ------------------------------------------

static func tag_of(part: Dictionary) -> String:
	var id := str(part.get("id", part.get("name", ""))).to_lower()
	return str(TAGS.get(id, str(part.get("name", id)).to_upper()))


static func role_of(part: Dictionary) -> String:
	return str(ROLES.get(str(part.get("id", part.get("name", ""))).to_lower(), "powered"))


static func now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


static func is_shorted(part: Dictionary) -> bool:
	return float(part.get("shorted_until", -1.0)) > now()


## Does this hardware do its job right now: there, not wrecked, not shorted.
## A plate is always "working" while it has condition: it is metal.
static func implant_active(part: Dictionary) -> bool:
	if part.is_empty():
		return false
	if float(part.get("condition", 0.0)) <= 0.0:
		return false
	return role_of(part) == "plate" or not is_shorted(part)


static func has_active_role(anatomy: AnatomyComponent, role: String) -> bool:
	if anatomy == null:
		return false
	for site_id in anatomy.installed_parts:
		var part: Dictionary = anatomy.installed_parts[site_id]
		if role_of(part) == role and implant_active(part):
			return true
	return false


## Electricity through a body (the PRODSTAFF, a live cable). Every powered
## implant that still works stops for `SHORT_SECONDS * power` and loses some
## of its condition; one that was already shorted overloads and burns out.
## Plates conduct and are untouched. Returns what happened, per site.
static func shock(anatomy: AnatomyComponent, power := 1.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if anatomy == null:
		return out
	var strength := clampf(power, 0.1, 3.0)
	for site_id in anatomy.installed_parts:
		var part: Dictionary = anatomy.installed_parts[site_id]
		if role_of(part) == "plate" or float(part.get("condition", 0.0)) <= 0.0:
			continue
		var maximum := maxf(1.0, float(part.get("max_condition", 100.0)))
		var overload := is_shorted(part)
		part["shorted_until"] = now() + SHORT_SECONDS * strength
		if overload:
			part["condition"] = 0.0
			part["overloaded"] = true
		else:
			part["condition"] = maxf(0.0, float(part.get("condition", 0.0)) - maximum * SHORT_WEAR * strength)
		anatomy.installed_parts[site_id] = part
		out.append({"site": str(site_id), "tag": tag_of(part), "overloaded": overload, "condition": anatomy.implant_condition(str(site_id))})
	return out


## The same, on a rig, with the sparks where each part is.
static func shock_rig(rig: BaselineHuman, power := 1.0) -> Array[Dictionary]:
	if rig == null or not is_instance_valid(rig):
		return []
	var shorted := shock(rig.anatomy, power)
	for entry in shorted:
		spark(rig, str(entry.site), 1.6 if bool(entry.overloaded) else 1.0)
	sync_visuals(rig, bool(rig.get("_xray")))
	return shorted


# --- organ failure ------------------------------------------------------------

## What this body's organs are doing to it right now. Greg's four rules, with
## the hardware that can stand in for an organ while it is working.
static func failure(anatomy: AnatomyComponent) -> Dictionary:
	var out := {"breathless": false, "no_sprint": false, "heart_failing": false, "slow_bleed": false, "dropped": false}
	if anatomy == null:
		return out
	var lung_gone := not anatomy.organ_ok("left_lung") or not anatomy.organ_ok("right_lung")
	if lung_gone and not has_active_role(anatomy, "breath"):
		out.breathless = true
		out.no_sprint = true
	if not anatomy.organ_ok("heart") and not has_active_role(anatomy, "heartbeat") and not anatomy.dead:
		out.heart_failing = true
	for organ_id in SLOW_BLEEDERS:
		if not anatomy.organs.has(organ_id) or anatomy.organ_ok(organ_id):
			continue
		if organ_id == "liver" and has_active_role(anatomy, "liver"):
			continue
		out.slow_bleed = true
	out.dropped = anatomy.dead or anatomy.downed or anatomy.failed or not anatomy.organ_ok("brain")
	return out


## How fast this body can move, as a share of its normal pace.
static func pace(anatomy: AnatomyComponent) -> float:
	var state := failure(anatomy)
	if bool(state.dropped):
		return 0.0
	if bool(state.heart_failing):
		return 0.35
	if bool(state.breathless):
		return 0.6
	return 1.0


## One step of the failures that take time. Called by `OrganLife` on every
## body that has one (the lab's dummies, the sparring partner, the player).
static func tick(anatomy: AnatomyComponent, delta: float) -> void:
	if anatomy == null or anatomy.dead:
		return
	var state := failure(anatomy)
	if bool(state.heart_failing) and not anatomy.failed:
		var stopped := float(anatomy.get_meta("heart_stopped_for", 0.0)) + delta
		anatomy.set_meta("heart_stopped_for", stopped)
		anatomy.consciousness = maxf(0.0, anatomy.consciousness - delta * 100.0 / HEART_DEATH_SECONDS)
		if stopped >= HEART_DEATH_SECONDS:
			anatomy.finish("heart_failure")
	else:
		anatomy.set_meta("heart_stopped_for", 0.0)
	if bool(state.slow_bleed) and anatomy.internal_bleed_rate < SLOW_BLEED_FLOOR:
		anatomy.internal_bleed_rate = SLOW_BLEED_FLOOR


## The node that runs `tick()` for one rig, plus the intermittent sparks of a
## shorted implant while it is shorted.
static func attach(rig: BaselineHuman) -> Node:
	if rig == null or rig.anatomy == null:
		return null
	var existing := rig.get_node_or_null("OrganLife")
	if existing != null:
		return existing
	var life := OrganLife.new()
	life.name = "OrganLife"
	life.rig = rig
	rig.add_child(life)
	return life


class OrganLife extends Node:
	var rig: BaselineHuman
	var _crackle := 0.0

	func _process(delta: float) -> void:
		if rig == null or not is_instance_valid(rig) or rig.anatomy == null:
			return
		OrganSystem.tick(rig.anatomy, delta)
		_crackle -= delta
		if _crackle > 0.0:
			return
		_crackle = randf_range(0.35, 0.8)
		for site_id in rig.anatomy.installed_parts:
			var part: Dictionary = rig.anatomy.installed_parts[site_id]
			if OrganSystem.is_shorted(part) and float(part.get("condition", 0.0)) > 0.0:
				OrganSystem.spark(rig, str(site_id), 0.45)


# --- the hole -----------------------------------------------------------------

## Whether `zone` on this body is open to its organs: a wall cut off it
## (`Cavity`), or a wound cut down to the organ layer. Deliberately not
## `Cavity.is_open()`, whose fallback counts a visible organ as an opening —
## and the X-ray makes every organ visible.
static func is_opened(rig: BaselineHuman, zone_id: String) -> bool:
	if rig == null or not is_instance_valid(rig):
		return false
	var part := rig.parts.get(zone_id) as Node3D
	if part != null and is_instance_valid(part) and bool(part.get_meta(Cavity.OPEN_MARK, false)):
		return true
	return rig.exposed_layer(zone_id) >= GoreChunks.Layer.ORGAN


## After a blow lands on a body: a torso cut or shot deep enough opens the
## chest. The wall comes off (`Cavity.open_zone` + `shed_wall`), the organs
## show through the hole, and the zone is recorded open to the organ layer so
## a hand can go in. Returns the cut, or empty when nothing opened.
static func after_hit(rig: BaselineHuman, result: Dictionary, direction: Vector3, damage_type: String) -> Dictionary:
	if rig == null or not is_instance_valid(rig) or not rig.gore:
		return {}
	if str(result.get("zone", "")) != "torso" or not damage_type in ["cut", "puncture", "ballistic", "shear"]:
		return {}
	if is_opened(rig, "torso") and bool((rig.parts.torso as Node3D).get_meta(Cavity.OPEN_MARK, false)):
		return {}
	var ceiling := float(AnatomyComponent.DEFAULT_ZONES.torso.health)
	if rig.exposed_layer("torso") < OPEN_AT_LAYER or rig.zone_health("torso") > ceiling * OPEN_AT_HEALTH:
		return {}
	var facing := -direction if direction.length_squared() > 0.001 else -(rig.global_transform.basis.z)
	var cut := Cavity.open_zone(rig, "torso", facing.normalized())
	if cut.is_empty():
		return {}
	Cavity.shed_wall(rig, cut, direction, GoreChunks.Layer.BONE)
	rig.mark_opened("torso", GoreChunks.Layer.ORGAN)
	_set_chest_forms(rig, false)
	sync_visuals(rig, bool(rig.get("_xray")))
	return cut


# --- the rip ------------------------------------------------------------------

## Why this cannot be ripped out right now, or "" if it can. `id` is an organ
## id or `implant:<site>`.
static func rip_refusal(rig: BaselineHuman, id: String) -> String:
	if rig == null or not is_instance_valid(rig) or rig.anatomy == null:
		return "NOTHING THERE"
	var zone := zone_of(rig, id)
	if zone == "":
		return "NOTHING THERE"
	if rig.severed.has(zone):
		return "GONE"
	if id.begins_with("implant:"):
		if not rig.anatomy.installed_parts.has(id.trim_prefix("implant:")):
			return "ALREADY TAKEN"
	elif bool((rig.anatomy.organs.get(id, {}) as Dictionary).get("removed", false)):
		return "ALREADY TAKEN"
	elif not rig.anatomy.organ_ok(id):
		# A burst organ came out on its own (`BaselineHuman._spill_organ`).
		return "BURST"
	if not rig.anatomy.dead and not rig.anatomy.downed:
		return "STILL STANDING"
	if not is_opened(rig, zone):
		return "NO OPENING"
	return ""


static func zone_of(rig: BaselineHuman, id: String) -> String:
	if id.begins_with("implant:"):
		var site := id.trim_prefix("implant:")
		return str(AnatomyComponent.INSTALL_SITES.get(site, site)) if rig.anatomy.installed_parts.has(site) else ""
	if not rig.anatomy.organs.has(id):
		return ""
	return str((rig.anatomy.organs[id] as Dictionary).get("zone", "torso"))


static func begin_rip(rig: BaselineHuman, id: String) -> Dictionary:
	if rip_refusal(rig, id) != "":
		return {}
	return {"rig": rig, "id": id, "zone": zone_of(rig, id), "progress": 0.0, "phase": 0.0, "tension": 1.0, "complete": false}


## One step of the hold. The grip pulls in tugs: on each one the organ gives,
## between them it holds (`tension` near 1). Let go and it slips back in.
static func tug(session: Dictionary, delta: float, holding: bool) -> Dictionary:
	if session.is_empty() or bool(session.get("complete", false)):
		return session
	if holding:
		session.phase = float(session.phase) + delta * TUG_RATE
		var give := 0.25 + 0.75 * pow(absf(sin(float(session.phase) * PI)), 2.0)
		session.tension = 1.0 - give
		# 0.625 is the mean of `give`, so a steady hold takes RIP_SECONDS.
		session.progress = clampf(float(session.progress) + delta / RIP_SECONDS * give / 0.625, 0.0, 1.0)
	else:
		session.tension = 1.0
		session.progress = maxf(0.0, float(session.progress) - delta * RIP_SLIP_PER_SECOND)
	session.complete = float(session.progress) >= 1.0
	return session


## How far out of the body the organ has come, in metres, for the animation.
static func pull_offset(session: Dictionary) -> float:
	var progress := float(session.get("progress", 0.0))
	return progress * 0.09 + sin(float(session.get("phase", 0.0)) * TAU) * 0.006 * float(session.get("tension", 1.0))


## It comes out. The organ (or hardware) leaves the body for good, a living
## owner pays for it (heart or brain: dead; anything else: bleeding inside),
## and what is handed back is `Carry.take_chunk()`'s shape.
static func finish_rip(session: Dictionary) -> Dictionary:
	if session.is_empty() or not bool(session.get("complete", false)):
		return {}
	var rig := session.get("rig") as BaselineHuman
	var id := str(session.id)
	if rip_refusal(rig, id) != "":
		return {}
	var anatomy := rig.anatomy
	var alive := not anatomy.dead
	var zone := str(session.zone)
	var info := {}
	if id.begins_with("implant:"):
		var site := id.trim_prefix("implant:")
		var part: Dictionary = anatomy.installed_parts.get(site, {})
		var pulled := anatomy.pull_part(site, true)
		if not bool(pulled.get("ok", false)):
			return {}
		var visual := (rig.parts.get(zone) as Node3D).get_node_or_null("Implant_%s" % site) if rig.parts.get(zone) != null else null
		if visual != null:
			visual.queue_free()
		info = {
			"layer": GoreChunks.Layer.CYBERNETIC, "layer_name": "cybernetic",
			"implant": str(part.get("id", part.get("name", "hardware"))),
			"tag": tag_of(part),
			"condition": clampf(anatomy.implant_condition_ratio(part) - HAND_DAMAGE * 0.5, 0.0, 1.0),
		}
	else:
		var organ: Dictionary = anatomy.organs[id]
		var ceiling := float((AnatomyComponent.ORGANS.get(id, {"health": 30.0}) as Dictionary).health)
		var condition := clampf(float(organ.get("health", 0.0)) / maxf(1.0, ceiling), 0.0, 1.0)
		if bool(organ.get("ruptured", false)):
			condition = minf(condition, 0.15)
		organ["health"] = 0.0
		organ["ruptured"] = true
		organ["removed"] = true
		anatomy.organs[id] = organ
		var mesh := rig.organ_parts.get(id) as Node3D
		if mesh != null and is_instance_valid(mesh):
			mesh.visible = false
		info = {
			"layer": GoreChunks.Layer.ORGAN, "layer_name": "organ",
			"organ_id": id,
			"condition": clampf(condition - HAND_DAMAGE, 0.0, 1.0),
		}
		if alive:
			if id in ["heart", "brain"]:
				anatomy.finish("organ_ripped")
			else:
				anatomy.internal_bleed_rate += float((AnatomyComponent.ORGANS.get(id, {"bleed": 1.0}) as Dictionary).bleed) * 14.0
	info.merge({
		"zone": zone, "subject_id": anatomy.subject_id, "lien": anatomy.subject_id,
		"tool": "hands", "taken": true, "ripped_alive": alive, "spawn_msec": Time.get_ticks_msec(),
	})
	rig.call("_refresh_wounds", zone)
	Extraction.notice(null, info, rig.global_position, [], alive and not anatomy.dead)
	return info


## The organ or hardware the aim line is on, inside reach, on any of `rigs`.
## Only parts that are actually on the body; whether the hand can get in is
## `rip_refusal()`'s question, so the prompt can say why not.
static func aimed_part(rigs: Array, from: Vector3, along: Vector3, reach := RIP_REACH) -> Dictionary:
	var best := {}
	var best_miss := RIP_AIM_TOLERANCE
	var ray := along.normalized()
	for entry in rigs:
		var rig := entry as BaselineHuman
		if rig == null or not is_instance_valid(rig) or rig.anatomy == null or not rig.is_inside_tree():
			continue
		var candidates: Array = []
		for organ_id in rig.organ_parts:
			var organ: Dictionary = rig.anatomy.organs.get(organ_id, {})
			if organ.is_empty() or bool(organ.get("ruptured", false)) or organ_id == "spine":
				continue
			var node := rig.organ_parts[organ_id] as Node3D
			if node != null and is_instance_valid(node) and node.is_inside_tree():
				candidates.append([str(organ_id), node.global_position])
		for site_id in rig.anatomy.installed_parts:
			var zone := str(AnatomyComponent.INSTALL_SITES.get(site_id, site_id))
			var part_node := rig.parts.get(zone) as Node3D
			if part_node == null or not part_node.is_inside_tree():
				continue
			var visual := part_node.get_node_or_null("Implant_%s" % site_id) as Node3D
			candidates.append(["implant:%s" % site_id, visual.global_position if visual != null else part_node.global_position])
		for candidate in candidates:
			var at: Vector3 = candidate[1]
			var depth := (at - from).dot(ray)
			if depth < 0.0 or depth > reach:
				continue
			var miss := (from + ray * depth).distance_to(at)
			if miss < best_miss:
				best_miss = miss
				best = {"rig": rig, "id": str(candidate[0]), "at": at, "distance": depth}
	return best


static func label_of(rig: BaselineHuman, id: String) -> String:
	if id.begins_with("implant:"):
		return tag_of(rig.anatomy.installed_parts.get(id.trim_prefix("implant:"), {}))
	return str(ORGAN_LABELS.get(id, id.to_upper()))


# --- swap and sell ------------------------------------------------------------

## Into the bag, with its sell value written on it (`Carry.sale_value()`, no
## buyer: the anonymous broker's price).
static func carry_item(carry: Carry, info: Dictionary) -> Dictionary:
	if carry == null or info.is_empty():
		return {}
	var item := carry.take_chunk(info)
	if item.is_empty():
		return {}
	if info.has("tag"):
		item["tag"] = str(info.tag)
	item["value"] = carry.sale_value(item)
	carry.save_to_history()
	return item


## A harvested organ into your own body, through the seam
## `AnatomyComponent.replace_organ()` was left for. It works as well as it was
## kept: its condition becomes its health. Removes it from the bag.
static func install_organ(carry: Carry, index: int, anatomy: AnatomyComponent) -> Dictionary:
	if carry == null or anatomy == null or index < 0 or index >= carry.items.size():
		return {}
	var item: Dictionary = carry.items[index]
	var organ_id := str(item.get("organ_id", ""))
	if str(item.get("kind", "")) != "organ" or not AnatomyComponent.ORGANS.has(organ_id):
		return {}
	var condition := clampf(float(item.get("condition", 0.5)), 0.0, 1.0)
	var was_ruptured := not anatomy.organ_ok(organ_id)
	var fresh := anatomy.replace_organ(organ_id, {"from": str(item.get("from", "")), "condition": condition})
	fresh["health"] = float((AnatomyComponent.ORGANS[organ_id] as Dictionary).health) * maxf(0.2, condition)
	anatomy.organs[organ_id] = fresh
	if was_ruptured:
		# The bleed from the organ that is no longer there stops with it.
		anatomy.internal_bleed_rate = maxf(0.0, anatomy.internal_bleed_rate - float((AnatomyComponent.ORGANS[organ_id] as Dictionary).bleed) * 14.0)
	anatomy.set_meta("heart_stopped_for", 0.0)
	carry.items.remove_at(index)
	carry.save_to_history()
	WorldHistory.record_event("organ_installed", {"organ": organ_id, "condition": snappedf(condition, 0.01), "lien": str(item.get("lien", ""))})
	return {"organ": organ_id, "condition": condition, "health": float(fresh.health)}


## Either kind, into you: an organ through `install_organ()`, hardware
## through `Carry.install_into()` (the path the decanting loadout uses).
static func install_into_self(carry: Carry, index: int, body: BaselineHuman) -> Dictionary:
	if carry == null or body == null or index < 0 or index >= carry.items.size():
		return {}
	match str((carry.items[index] as Dictionary).get("kind", "")):
		"organ":
			return install_organ(carry, index, body.anatomy)
		"cybernetic":
			return carry.install_into(index, body)
	return {}


# --- the scan -----------------------------------------------------------------

## What the X-ray tells you about somebody before you decide to fight them:
## where their hardware and plate is and what it does, how their organs are,
## and what they are worth opened. Pure, so a HUD and a test read the same.
static func scan(rig: BaselineHuman) -> Dictionary:
	var out := {"subject": "", "implants": [], "plates": [], "organs": [], "damaged": [], "value": 0}
	if rig == null or not is_instance_valid(rig) or rig.anatomy == null:
		return out
	var anatomy := rig.anatomy
	out.subject = anatomy.subject_id
	var value := 0.0
	for site_id in anatomy.installed_parts:
		var part: Dictionary = anatomy.installed_parts[site_id]
		var condition := anatomy.implant_condition(str(site_id))
		var entry := {
			"site": str(site_id),
			"zone": str(AnatomyComponent.INSTALL_SITES.get(site_id, site_id)),
			"name": str(part.get("name", part.get("id", ""))),
			"tag": tag_of(part),
			"role": role_of(part),
			"condition": snappedf(condition, 0.01),
			"armour": snappedf(float(part.get("armor", 0.0)) * condition, 0.01),
			"active": implant_active(part),
			"shorted": is_shorted(part) and condition > 0.0,
			"burnt": condition <= 0.0,
		}
		out.implants.append(entry)
		if str(entry.role) == "plate" or float(entry.armour) >= VatsTargeting.PLATED_AT:
			out.plates.append(entry)
		value += float(VALUE_BASE.cybernetic) * maxf(0.2, condition) if condition > 0.0 else 0.0
	for zone_id in BaselineHuman.ZONES:
		var plate := float(Garments.shielding(anatomy.worn, str(zone_id)).plate)
		if plate > 0.0:
			out.plates.append({"site": str(zone_id), "zone": str(zone_id), "tag": "WORN PLATE", "role": "worn", "armour": snappedf(plate, 0.01), "active": true})
	for organ_id in AnatomyComponent.ORGANS:
		if not anatomy.organs.has(organ_id):
			continue
		var organ: Dictionary = anatomy.organs[organ_id]
		var ceiling := float((AnatomyComponent.ORGANS[organ_id] as Dictionary).health)
		var ratio := clampf(float(organ.get("health", 0.0)) / maxf(1.0, ceiling), 0.0, 1.0)
		var state := "OK"
		if bool(organ.get("removed", false)):
			state = "TAKEN"
		elif bool(organ.get("ruptured", false)):
			state = "RUPTURED"
		elif ratio < 0.5:
			state = "DAMAGED"
		elif ratio < 0.95:
			state = "BRUISED"
		out.organs.append({"id": str(organ_id), "label": str(ORGAN_LABELS.get(organ_id, str(organ_id).to_upper())), "health": snappedf(ratio, 0.01), "state": state})
		if state != "OK":
			out.damaged.append(str(organ_id))
		if state in ["OK", "BRUISED", "DAMAGED"] and organ_id != "spine":
			value += float(VALUE_BASE.organ) * maxf(0.2, ratio)
	out.value = roundi(value)
	return out


# --- what the X-ray and the hole show -----------------------------------------

## Keeps a body's hardware visible as hardware: each installed part is a piece
## inside the zone it sits in, shown while the X-ray is on it or its zone is
## open. Under the X-ray it draws through the body in cold cyan; a shorted
## part flickers hot. Also hides the chest's censor under the X-ray.
static func sync_visuals(rig: BaselineHuman, xray: bool) -> void:
	if rig == null or not is_instance_valid(rig) or rig.anatomy == null:
		return
	var wanted := {}
	for site_id in rig.anatomy.installed_parts:
		var zone := str(AnatomyComponent.INSTALL_SITES.get(site_id, site_id))
		if zone == str(site_id):
			# A zone-keyed part is drawn by the rig itself (`_show_installed`).
			continue
		var part_node := rig.parts.get(zone) as Node3D
		if part_node == null or not is_instance_valid(part_node):
			continue
		var part: Dictionary = rig.anatomy.installed_parts[site_id]
		var node_name := "Implant_%s" % site_id
		wanted[node_name] = true
		var visual := part_node.get_node_or_null(node_name) as MeshInstance3D
		if visual == null:
			visual = MeshInstance3D.new()
			visual.name = node_name
			visual.mesh = rig.call("_implant_mesh", str(part.get("profile", "")))
			visual.position = PLACES.get(str(part.get("profile", "")), Vector3.ZERO)
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visual.set_meta("site", str(site_id))
			part_node.add_child(visual)
		var material := visual.material_override as StandardMaterial3D
		if material == null:
			material = WorldLook.surface(Color(str(part.get("tint", "9a8f7c"))), "chrome", hash(str(site_id)))
			visual.material_override = material
		var shorted := is_shorted(part) and float(part.get("condition", 0.0)) > 0.0
		var dead := float(part.get("condition", 0.0)) <= 0.0
		var shown := xray or is_opened(rig, zone)
		if visual.visible != shown:
			visual.visible = shown
		visual.transparency = XRAY_HARDWARE if xray else 0.0
		var glow: Color = SPARK if shorted else (Color(0.25, 0.1, 0.08) if dead else XRAY_CYAN)
		if material.no_depth_test != xray or material.emission_enabled != (xray or shorted) or material.emission != glow:
			material.no_depth_test = xray
			material.render_priority = 5 if xray else 0
			material.emission_enabled = xray or shorted
			material.emission = glow
			material.emission_energy_multiplier = 1.6 if xray else 0.8
	for zone_id in rig.parts:
		var part_node := rig.parts[zone_id] as Node3D
		if part_node == null or not is_instance_valid(part_node):
			continue
		for child in part_node.get_children():
			if str(child.name).begins_with("Implant_") and not wanted.has(str(child.name)):
				child.queue_free()
	# Organs glow their own colour under the X-ray, a damaged one hot.
	for organ_id in rig.organ_parts:
		var organ := rig.organ_parts[organ_id] as MeshInstance3D
		if organ == null or not is_instance_valid(organ) or organ.mesh == null or organ.mesh.get_surface_count() == 0:
			continue
		var wet := organ.mesh.surface_get_material(0) as StandardMaterial3D
		if wet == null:
			continue
		var glow := xray and organ.visible
		if wet.emission_enabled != glow:
			wet.emission_enabled = glow
		if glow:
			var ceiling := float((AnatomyComponent.ORGANS.get(organ_id, {"health": 30.0}) as Dictionary).health)
			var hurt := 1.0 - clampf(float((rig.anatomy.organs.get(organ_id, {}) as Dictionary).get("health", ceiling)) / maxf(1.0, ceiling), 0.0, 1.0)
			var hue := wet.albedo_color.lightened(0.25).lerp(Color(1.0, 0.25, 0.1), hurt)
			if wet.emission != hue:
				wet.emission = hue
				wet.emission_energy_multiplier = XRAY_ORGAN_GLOW * (1.0 + hurt)
	_shell_skin(rig, xray)
	if XRAY_HIDES_CHEST_CENSOR:
		var torso_open := bool((rig.parts.get("torso") as Node3D).get_meta(Cavity.OPEN_MARK, false)) if rig.parts.get("torso") != null else false
		_set_chest_forms(rig, not xray and not torso_open)
		_set_form(rig, "buttock", not xray)


## Under the X-ray the zone parts (and the shoulder caps over them) wear the
## radiograph film; off it, the rig redraws its own flesh (`_refresh_zone`),
## so wounds, bruising and dose come back exactly as they were.
static func _shell_skin(rig: BaselineHuman, xray: bool) -> void:
	var shell := xray_shell()
	for zone_id in rig.parts:
		var skin := rig.parts[zone_id] as MeshInstance3D
		if skin == null or not is_instance_valid(skin):
			continue
		var on := xray and not rig.severed.has(zone_id) and not rig.anatomy.installed_parts.has(zone_id)
		if on:
			if skin.material_override != shell:
				skin.material_override = shell
			if skin.transparency != 0.0:
				skin.transparency = 0.0
		elif skin.material_override == shell:
			rig.call("_refresh_zone", zone_id)
		for child in skin.get_children():
			var piece := child as MeshInstance3D
			if piece == null or not _is_shell_piece(str(piece.name)):
				continue
			if on and piece.material_override != shell:
				piece.set_meta("pre_xray", piece.material_override)
				piece.material_override = shell
			elif not on and piece.material_override == shell:
				piece.material_override = piece.get_meta("pre_xray") as Material
				piece.remove_meta("pre_xray")


static func _is_shell_piece(piece_name: String) -> bool:
	for prefix: String in SHELL_PIECES:
		if piece_name.begins_with(prefix):
			return true
	return false


static func _set_chest_forms(rig: BaselineHuman, shown: bool) -> void:
	_set_form(rig, "chest", shown)


## A `BodyForms` region's form and censor, shown or not. The censor covers
## skin; under the X-ray the skin is not what is being looked at. The groin's
## stays (it is in front of nothing the scan reads).
static func _set_form(rig: BaselineHuman, region: String, shown: bool) -> void:
	var torso := rig.parts.get("torso") as Node3D
	if torso == null or not is_instance_valid(torso):
		return
	for child in torso.get_children():
		var child_name := str(child.name)
		if child_name.contains(region) and (child_name.begins_with("Censor_") or child_name.begins_with("Nude_")):
			(child as Node3D).visible = shown


## A burst of sparks and a flash where a piece of hardware is.
static func spark(rig: BaselineHuman, site_id: String, strength := 1.0) -> void:
	if rig == null or not is_instance_valid(rig) or not rig.is_inside_tree():
		return
	var zone := str(AnatomyComponent.INSTALL_SITES.get(site_id, site_id))
	var part_node := rig.parts.get(zone) as Node3D
	if part_node == null:
		return
	var anchor := part_node.get_node_or_null("Implant_%s" % site_id) as Node3D
	if anchor == null:
		anchor = part_node.get_node_or_null("InstalledHardware") as Node3D
	var at := anchor.global_position if anchor != null else part_node.global_position
	var burst := CPUParticles3D.new()
	burst.name = "ImplantSparks"
	burst.one_shot = true
	burst.emitting = false
	burst.amount = int(30 + 50 * strength)
	burst.lifetime = 0.6
	burst.explosiveness = 0.9
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 1.2 * strength
	burst.initial_velocity_max = 3.6 * strength
	burst.gravity = Vector3(0, -9.0, 0)
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.0
	var bead := SphereMesh.new()
	bead.radius = 0.011
	bead.height = 0.022
	bead.radial_segments = 4
	bead.rings = 2
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = SPARK
	hot.emission_enabled = true
	hot.emission = SPARK
	hot.emission_energy_multiplier = 6.0
	hot.no_depth_test = true
	bead.material = hot
	burst.mesh = bead
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.7, 0.85, 1.0)
	flash.light_energy = 3.5 * strength
	flash.omni_range = 1.6
	burst.add_child(flash)
	var root := rig.get_tree().current_scene if rig.get_tree().current_scene != null else rig.get_tree().root
	root.add_child(burst)
	burst.global_position = at
	burst.emitting = true
	var tween := burst.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.22)
	burst.get_tree().create_timer(1.2).timeout.connect(burst.queue_free)
