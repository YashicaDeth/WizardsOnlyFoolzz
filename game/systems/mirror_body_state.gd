class_name MirrorBodyState
extends RefCounted

## B9's contract with the room mirror.  A mirror must read the gameplay rig,
## not a character-sheet summary or an independently authored portrait.  This
## is intentionally data-only so the future physical mirror can choose its own
## camera/material while having exactly one source for what it must show.

static func snapshot(rig: BaselineHuman) -> Dictionary:
	if rig == null or not is_instance_valid(rig) or rig.anatomy == null:
		return {"ok": false, "reason": "NO LIVE RIG"}
	var zones := {}
	for zone_id in BaselineHuman.ZONES:
		var anatomy_zone: Dictionary = rig.anatomy.zones.get(zone_id, {})
		var maximum := float((AnatomyComponent.DEFAULT_ZONES.get(zone_id, {}) as Dictionary).get("health", 100.0))
		var part := rig.parts.get(zone_id) as Node3D
		zones[zone_id] = {
			"health_ratio": clampf(float(anatomy_zone.get("health", 0.0)) / maxf(maximum, 1.0), 0.0, 1.0),
			"visible": part != null and part.visible,
			"severed": rig.severed.has(zone_id),
			"opened_layer": rig.exposed_layer(zone_id),
			"implant": rig.anatomy.installed_parts.has(zone_id),
		}
	var ruptured: Array[String] = []
	for organ_id in rig.anatomy.organs:
		if bool((rig.anatomy.organs[organ_id] as Dictionary).get("ruptured", false)):
			ruptured.append(str(organ_id))
	return {
		"ok": true,
		"subject_id": rig.anatomy.subject_id,
		"zones": zones,
		"ruptured_organs": ruptured,
		"downed": rig.is_downed(),
		"dead": rig.anatomy.dead,
		"undying": rig.anatomy.undying,
		"spirit_burden": rig.anatomy.spirit_burden,
	}
