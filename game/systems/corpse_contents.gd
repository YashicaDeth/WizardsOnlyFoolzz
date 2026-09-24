class_name CorpseContents
extends RefCounted

## What is on a body, and how much of it you can actually reach.
##
## Looting a corpse was one keypress that swept the pockets and printed a line.
## `FieldInventory` is a real panel and had never been pointed at anybody else
## -- it draws your bag, your wardrobe, your weapons. So the four things a body
## is actually carrying were spread across a prompt string, a timed dig with no
## UI at all, and two systems nothing displayed.
##
## This is the listing half. It is pure, and it is separate from anything that
## draws, because the failure worth testing is not how the panel looks.
##
## **The gate is the whole design.** A panel that lists the heart of a sealed
## chest is a shortcut past `Extraction` and `Cavity`: you would read "HEART"
## off a body nobody had opened, click it, and nine seconds of digging would
## stop meaning anything. So nothing is listed that is not physically reachable
## right now -- organs need the cavity open, hardware needs the dig to have
## reached `Layer.CYBERNETIC` -- and a zone that is holding out says so without
## saying what it is holding. You learn that there is something behind the
## sternum by opening it, which is the same way you learn it in the world.

## Zones that hold something worth listing but have not been opened are
## reported like this, so a panel can prompt without leaking a manifest.
const SEALED := "sealed"


## Everything on this body, in four sections plus what is refusing to open.
##
## `pockets` is what the caller already knows is loose on them -- the same
## array the Hunt prompt builds its manifest from -- because pockets are on the
## outside and were never the thing the dig was protecting.
static func of(rig: BaselineHuman, pockets: Array = []) -> Dictionary:
	var found := {"pockets": [], "worn": [], "implanted": [], "organs": [], "sealed": []}
	if rig == null or not is_instance_valid(rig) or rig.anatomy == null:
		return found

	for entry in pockets:
		var label := str(entry.get("label", entry) if entry is Dictionary else entry)
		found.pockets.append({"kind": "pocket", "label": label.to_upper()})

	_list_worn(rig, found)
	_list_reachable(rig, found)
	return found


## Clothing, with the condition it is actually in.
##
## Always listed: a garment is on the outside and comes off a body without
## opening it. The condition is the live wardrobe value rather than a fresh
## one, so a jacket that took two rounds is worth what a jacket that took two
## rounds is worth, which is the whole reason `ClothingShell` tracks it.
static func _list_worn(rig: BaselineHuman, found: Dictionary) -> void:
	var wardrobe: Dictionary = rig.wardrobe
	var style := str(wardrobe.get("style", "plain"))
	for zone_id in BaselineHuman.ZONES:
		if not wardrobe.has(zone_id):
			continue
		var integrity := clampf(float(wardrobe.get(zone_id, 0.0)), 0.0, 1.0)
		if integrity <= 0.0:
			# Gone rather than ragged. Nothing to take off them.
			continue
		found.worn.append({
			"kind": "garment",
			"zone": zone_id,
			"style": style,
			"condition": integrity,
			"label": "%s %s" % [style.to_upper(), zone_id.replace("_", " ").to_upper()],
		})


## Hardware and organs, and only where the body is open enough to have them.
static func _list_reachable(rig: BaselineHuman, found: Dictionary) -> void:
	var implants: Dictionary = rig.anatomy.installed_parts
	var organs: Dictionary = rig.anatomy.organs
	var depth: Dictionary = rig.zone_depth
	var withheld := {}

	for zone_id in BaselineHuman.ZONES:
		# A zone that is not on the body any more is not holding anything, and
		# listing a severed arm as sealed would send somebody digging at a
		# stump.
		if rig.severed.has(zone_id):
			continue
		var dug := int(depth.get(zone_id, 0))
		var open := Cavity.is_open(rig, zone_id)

		if implants.has(zone_id):
			# Hardware sits under everything, so reaching it means the dig
			# actually got that far -- the same layer `Extraction` charges for.
			if dug >= GoreChunks.Layer.CYBERNETIC:
				var implant: Dictionary = implants[zone_id]
				found.implanted.append({
					"kind": "cybernetic",
					"zone": zone_id,
					"label": str(implant.get("name", "HARDWARE")).to_upper(),
					"condition": clampf(float(implant.get("condition", 1.0)), 0.0, 1.0),
				})
			else:
				withheld[zone_id] = true

		for organ_id in BaselineHuman.ORGAN_LAYOUT:
			var spec: Dictionary = BaselineHuman.ORGAN_LAYOUT[organ_id]
			if str(spec.get("zone", "")) != zone_id:
				continue
			if not open:
				withheld[zone_id] = true
				continue
			var organ: Dictionary = organs.get(organ_id, {})
			found.organs.append({
				"kind": "organ",
				"zone": zone_id,
				"organ_id": organ_id,
				"ruptured": bool(organ.get("ruptured", false)),
				# A burst organ is still a thing you can lift out; it is simply
				# not worth what an intact one is, and the panel should say so
				# rather than hide it.
				"label": organ_id.replace("_", " ").to_upper() + (" (RUPTURED)" if bool(organ.get("ruptured", false)) else ""),
			})

	for zone_id in withheld:
		found.sealed.append(zone_id)


## A one-line summary for a prompt, before anybody opens a panel.
##
## Counts what is reachable and says how many zones are not, which is enough to
## decide whether to stop and dig without being a manifest of what is inside.
static func summary(found: Dictionary) -> String:
	var reachable: int = (found.get("pockets", []) as Array).size() \
		+ (found.get("worn", []) as Array).size() \
		+ (found.get("implanted", []) as Array).size() \
		+ (found.get("organs", []) as Array).size()
	var shut: int = (found.get("sealed", []) as Array).size()
	if reachable == 0 and shut == 0:
		return "NOTHING ON THEM"
	var line := "%d TO TAKE" % reachable if reachable > 0 else "NOTHING LOOSE"
	if shut > 0:
		line += " // %d SEALED" % shut
	return line


## Whether digging this zone would actually turn anything up.
##
## Asked before a dig is offered, so the player is never invited to spend nine
## seconds on an empty thigh.
static func worth_opening(rig: BaselineHuman, zone_id: String) -> bool:
	if rig == null or not is_instance_valid(rig) or rig.anatomy == null:
		return false
	if rig.severed.has(zone_id):
		return false
	if rig.anatomy.installed_parts.has(zone_id) and int(rig.zone_depth.get(zone_id, 0)) < GoreChunks.Layer.CYBERNETIC:
		return true
	if Cavity.is_open(rig, zone_id):
		return false
	for organ_id in BaselineHuman.ORGAN_LAYOUT:
		if str((BaselineHuman.ORGAN_LAYOUT[organ_id] as Dictionary).get("zone", "")) == zone_id:
			return true
	return false
