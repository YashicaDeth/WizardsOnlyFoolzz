class_name Extraction
extends RefCounted

## B5. Taking a part off a body that has not shed it yet — the deliberate
## counterpart to picking a loose piece off the floor.
##
## Greg's brief for B4 ended *"that's how you can rob cybernetics."* B4 built the
## identified chunk; this is what it costs to make one on purpose. Three rules
## come out of the design rather than out of convenience:
##
## - **You have to dig** (B5.2). Hardware sits at `GoreChunks.Layer.CYBERNETIC`
##   and an organ at `ORGAN`, so reaching either means going through everything
##   above it. A body you already opened in the fight is faster to rob, because
##   `BaselineHuman.zone_depth` remembers how far in you got — the same ratchet
##   B4.3 built, now paying for itself.
## - **The tool matters** (B5.3). Bare hands are slow and ruin what they pull
##   out; a blade is quick and rough; something surgical is quick and clean.
##   The difference is the part's condition, which is the price the Choir pays.
## - **Someone notices** (B5.6). Robbing is an act with witnesses like any
##   other, so it routes through `WitnessLedger` rather than being invisible,
##   and a living owner remembers being cut open while they were down.
##
## Nothing here touches the scene. It is handed a snapshot and a delta and hands
## back numbers, plus — on completion — a dictionary in exactly the shape
## `Carry.take_chunk()` already accepts.

const ImplantCatalog := preload("res://systems/implant_catalog.gd")
const PlayerActionLedger := preload("res://systems/player_action_ledger.gd")

## Seconds to clear one layer at speed 1.0. Sized so robbing an intact torso
## with bare hands is a real commitment (about nine seconds) while a limb you
## already cut to the bone comes apart in one or two.
const SECONDS_PER_LAYER := 1.45

const TOOL_PROFILES := {
	"hands": {"speed": 0.55, "damage": 0.34, "label": "BARE HANDS"},
	"blade": {"speed": 1.0, "damage": 0.16, "label": "BLADE"},
	"surgical": {"speed": 1.6, "damage": 0.04, "label": "SURGICAL KIT"},
}

## What counts as surgical is an item, not a weapon slot: the six-finger
## surgical crown out of `implant_catalog.gd` is a Choir tool and reads as one.
const SURGICAL_GOODS := ["surgical kit", "six-finger surgical crown", "bone saw"]
const BLADE_WEAPONS := ["sword", "cleaver", "knife"]


static func profile(tool: String) -> Dictionary:
	return TOOL_PROFILES.get(tool, TOOL_PROFILES.hands)


## What the player is actually holding, resolved once so the UI and the dig
## agree. Carried goods beat the equipped weapon, because a blade in your hand
## does not stop the kit in your bag being the better instrument.
static func tool_for(weapon_id: String, carried: Array) -> String:
	for entry in carried:
		var label := str(entry.get("label", entry) if entry is Dictionary else entry).to_lower()
		for good in SURGICAL_GOODS:
			if label.contains(good):
				return "surgical"
	for blade in BLADE_WEAPONS:
		if weapon_id.to_lower().contains(blade):
			return "blade"
	return "hands"


static func _cybernetics(anatomy: Dictionary) -> Dictionary:
	var installed: Variant = anatomy.get("cybernetics", {})
	return ImplantCatalog.by_zone(installed)


## Which zones on this body are worth opening, richest first. Hardware outranks
## an organ because it neither spoils nor grows back, and within hardware the
## ranking is what is actually left of the part — an intact rangefinder eye is
## worth opening a skull for, a half-dead sternum plate is not. Ordering by
## whatever the dictionary happened to hold first made the choice arbitrary,
## which is the opposite of the decision B2.6 exists to pose.
## `exposure` is an optional zone -> already-open layer map (the rig's own
## `zone_depth`). It only breaks ties, but it breaks them the way a person
## would: with two parts worth the same, take the one you have already cut
## most of the way down to.
static func robbable_zones(anatomy: Dictionary, exposure: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var installed := _cybernetics(anatomy)
	for zone_id in installed:
		var part: Dictionary = installed[zone_id]
		var maximum := maxf(1.0, float(part.get("max_condition", 100.0)))
		var ratio := clampf(float(part.get("condition", maximum)) / maximum, 0.0, 1.0)
		out.append({
			"zone": str(zone_id), "kind": "cybernetic",
			"label": str(part.get("name", "hardware")),
			# Priced the way the Choir prices it in `Carry.sale_value`: what the
			# kind is worth, scaled by how much of it is left. Ranking by raw
			# condition points instead made a big cheap armour plate outrank an
			# intact optic, because a sternum simply has more of them.
			"worth": 24.0 * ratio,
		})
	var organs: Dictionary = anatomy.get("organs", {})
	for organ_id in organs:
		var organ: Dictionary = organs[organ_id]
		if bool(organ.get("ruptured", false)):
			continue
		var ceiling := maxf(1.0, float(organ.get("max_health", organ.get("health", 1.0))))
		out.append({
			"zone": str(organ.get("zone", "torso")), "kind": "organ",
			"label": str(organ_id), "organ_id": str(organ_id),
			"worth": 12.0 * clampf(float(organ.get("health", 0.0)) / ceiling, 0.0, 1.0),
		})
	out.sort_custom(func(a, b):
		if not is_equal_approx(float(a.worth), float(b.worth)):
			return float(a.worth) > float(b.worth)
		var a_open := int(exposure.get(str(a.zone), 0))
		var b_open := int(exposure.get(str(b.zone), 0))
		if a_open != b_open:
			return a_open > b_open
		# Last resort, so the order is stable run to run rather than however
		# the dictionary happened to be built.
		return str(a.zone) < str(b.zone)
	)
	return out


## The layer a dig has to reach. An empty zone is not diggable at all, which is
## what stops this becoming a generic "hold E on a corpse" resource button.
static func target_layer(anatomy: Dictionary, zone_id: String, organ_id := "") -> int:
	if _cybernetics(anatomy).has(zone_id):
		return GoreChunks.Layer.CYBERNETIC
	if organ_id != "" and (anatomy.get("organs", {}) as Dictionary).has(organ_id):
		return GoreChunks.Layer.ORGAN
	return -1


## How long this dig takes, given how far the fight already opened the zone.
static func required_seconds(anatomy: Dictionary, zone_id: String, tool: String, already_open := 0, organ_id := "") -> float:
	var target := target_layer(anatomy, zone_id, organ_id)
	if target < 0:
		return -1.0
	var remaining := maxi(1, target - clampi(already_open, 0, target))
	return float(remaining) * SECONDS_PER_LAYER / maxf(0.1, float(profile(tool).speed))


static func begin(subject_id: String, anatomy: Dictionary, zone_id: String, tool: String, already_open := 0, organ_id := "") -> Dictionary:
	var needed := required_seconds(anatomy, zone_id, tool, already_open, organ_id)
	if needed < 0.0:
		return {}
	return {
		"subject_id": subject_id,
		"zone": zone_id,
		"organ_id": organ_id,
		"tool": tool if TOOL_PROFILES.has(tool) else "hands",
		"progress": 0.0,
		"required": needed,
		"target": target_layer(anatomy, zone_id, organ_id),
		"opened_from": clampi(already_open, 0, GoreChunks.Layer.CYBERNETIC),
		"complete": false,
	}


## One tick of holding the key down. Returns the session so a caller can read
## `progress / required` for a meter without a second call.
static func dig(session: Dictionary, delta: float) -> Dictionary:
	if session.is_empty() or bool(session.get("complete", false)):
		return session
	var needed := maxf(0.01, float(session.get("required", 1.0)))
	session["progress"] = clampf(float(session.get("progress", 0.0)) + maxf(0.0, delta), 0.0, needed)
	session["complete"] = float(session.progress) >= needed
	return session


## How deep the dig has got, as a real `GoreChunks.Layer`. The body's exposed
## layer should follow this while it happens, so a half-finished extraction
## leaves the zone visibly opened rather than untouched.
static func reached_layer(session: Dictionary) -> int:
	if session.is_empty():
		return 0
	var opened := int(session.get("opened_from", 0))
	var needed := maxf(0.01, float(session.get("required", 1.0)))
	var span := maxi(1, int(session.get("target", GoreChunks.Layer.CYBERNETIC)) - opened)
	var ratio := clampf(float(session.get("progress", 0.0)) / needed, 0.0, 1.0)
	return clampi(opened + int(round(ratio * float(span))), 0, GoreChunks.Layer.CYBERNETIC)


## What comes out, in `Carry.take_chunk()`'s shape. The lien is the point: a
## part carries whose body it came off for the rest of its existence, which is
## what lets the Choir price it and the owner recognise it.
static func extract(session: Dictionary, anatomy: Dictionary) -> Dictionary:
	if session.is_empty() or not bool(session.get("complete", false)):
		return {}
	var zone_id := str(session.zone)
	var organ_id := str(session.get("organ_id", ""))
	var layer := target_layer(anatomy, zone_id, organ_id)
	if layer < 0:
		return {}
	var tool_profile := profile(str(session.tool))
	var condition := 1.0
	var implant_name := ""
	if layer == GoreChunks.Layer.CYBERNETIC:
		var part: Dictionary = _cybernetics(anatomy).get(zone_id, {})
		implant_name = str(part.get("name", part.get("id", "salvage")))
		condition = clampf(float(part.get("condition", 100.0)) / maxf(1.0, float(part.get("max_condition", 100.0))), 0.0, 1.0)
	else:
		var organ: Dictionary = (anatomy.get("organs", {}) as Dictionary).get(organ_id, {})
		condition = clampf(float(organ.get("health", 30.0)) / maxf(1.0, float(organ.get("max_health", organ.get("health", 30.0)))), 0.0, 1.0)
	return {
		"layer": layer,
		"layer_name": GoreChunks.LAYER_NAMES[layer],
		"zone": zone_id,
		"subject_id": str(session.subject_id),
		"organ_id": organ_id if layer == GoreChunks.Layer.ORGAN else "",
		"implant": implant_name,
		"condition": clampf(condition - float(tool_profile.damage), 0.0, 1.0),
		"lien": str(session.subject_id),
		"tool": str(session.tool),
		"taken": true,
		"spawn_msec": Time.get_ticks_msec(),
	}


## Removes what was taken from the body it was taken from, so the dossier, the
## X-ray and any later dig all agree that the socket is empty now.
static func strip_from_rig(rig: Node, extracted: Dictionary) -> void:
	if rig == null or not is_instance_valid(rig) or extracted.is_empty():
		return
	var anatomy: Node = rig.get("anatomy")
	if anatomy == null:
		return
	var zone_id := str(extracted.get("zone", ""))
	if int(extracted.get("layer", -1)) == GoreChunks.Layer.CYBERNETIC:
		(anatomy.get("installed_parts") as Dictionary).erase(zone_id)
	else:
		var organ_id := str(extracted.get("organ_id", ""))
		if organ_id != "":
			anatomy.call("damage_organ", organ_id, 9999.0)
	# The zone is open to the bone now whatever else is true of it.
	if rig.has_method("mark_opened"):
		rig.call("mark_opened", zone_id, GoreChunks.Layer.CYBERNETIC)


## B5.6. The act enters the record with whoever saw it, the owner remembers if
## they are alive to remember, and the part is flagged as somebody else's —
## which `Carry.sale_value` reads when the Choir quotes a price.
static func notice(ledger: WitnessLedger, extracted: Dictionary, at: Vector3, candidates: Array, owner_alive: bool, location := "") -> Dictionary:
	if extracted.is_empty():
		return {}
	var owner := str(extracted.get("subject_id", ""))
	var witnesses := WitnessLedger.witnesses_of(at, candidates, "player")
	var details := {
		"subject_id": owner,
		"part": str(extracted.get("implant", extracted.get("organ_id", extracted.get("layer_name", "tissue")))),
		"zone": str(extracted.get("zone", "")),
		"tool": str(extracted.get("tool", "hands")),
		"owner_alive": owner_alive,
		"location": location,
	}
	# The extraction fact, witness payload and living owner's memory are one
	# player act. WitnessLedger still owns testimony; it only uses our receipt.
	WorldHistory.begin_ledger_batch()
	if ledger != null:
		ledger.record("part_extracted", details, witnesses, true)
	else:
		PlayerActionLedger.record("part_extracted", details)
	if owner_alive and owner != "":
		var subject := WorldHistory.subject(owner)
		WorldHistory.update_subject(owner, {
			"grudge": mini(100, int(subject.get("grudge", 0)) + 26),
			"memory": "The Hunter cut %s out of me while I was on the ground." % details.part,
		}, "robbed_while_down")
	WorldHistory.commit_ledger_batch()
	return {"witnesses": witnesses, "stolen": not witnesses.is_empty() or owner_alive}
