class_name RivalRegistry
extends RefCounted

## F4. A rival is a conclusion drawn from the world's record, never a cast
## slot. Any existing person can earn the role by surviving harm from the
## player. Their body is the memory: adaptation is derived from the anatomy
## snapshot that already drives movement, combat and the dossier.

const Anatomy := preload("res://systems/anatomy_component.gd")
const DEAD := ["dead", "executed", "killed"]
const HARM_EVENTS := ["melee_body_hit", "npc_anatomy_hit", "firearm_anatomy_hit", "limb_severed_in_combat", "rival_injured", "rival_memory_formed", "derby_vehicle_hit"]
const SURVIVAL_EVENTS := ["rival_survived_hunt", "hunt_arc_first_beat_complete", "npc_spared", "npc_escaped_bleeding"]


static func consider(subject_id: String) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty() or str(subject.get("kind", "person")) != "person" or DEAD.has(str(subject.get("status", "")).to_lower()):
		return {}
	var harm: Array[Dictionary] = []
	var survived: Array[Dictionary] = []
	for event in WorldHistory.events:
		if not _event_names(event, subject_id):
			continue
		var event_type := str(event.get("type", ""))
		if HARM_EVENTS.has(event_type):
			harm.append(event)
		if SURVIVAL_EVENTS.has(event_type) and _survival_holds(event):
			survived.append(event)
	if harm.is_empty() or (survived.is_empty() and str(subject.get("status", "")) != "escaped"):
		return {}
	var origin: Dictionary = harm[0]
	var latest: Dictionary = harm[harm.size() - 1]
	var adaptation := adaptation_from_anatomy(subject)
	var already := bool(subject.get("is_rival", false))
	# The conclusion and its first public fact are indivisible. Reconsidering an
	# existing rival still uses the same safe mutation path without a new fact.
	WorldHistory.begin_ledger_batch()
	var updated := WorldHistory.amend_subject(subject_id, {
		"is_rival": true,
		"rival_origin": str(origin.get("id", "")),
		"rival_origin_type": str(origin.get("type", "")),
		"rival_last_harm": str(latest.get("id", "")),
		"rival_encounters": maxi(1, survived.size()),
		"rival_adaptation": adaptation,
		"memory": _memory(subject, adaptation, latest),
	})
	if not already:
		WorldHistory.record_event("rival_emerged", {"subject_id": subject_id, "origin_event": updated.rival_origin, "origin_type": updated.rival_origin_type, "adaptation": adaptation.duplicate(true)})
	WorldHistory.commit_ledger_batch()
	return updated


static func adaptation_from_anatomy(subject: Dictionary) -> Dictionary:
	var anatomy: Dictionary = subject.get("anatomy_state", {})
	if anatomy.is_empty():
		return {"kind": "scar", "zone": "torso", "response": "remembers the encounter without a reliable body record"}
	var severed: Array = anatomy.get("severed", [])
	if not severed.is_empty():
		var zone := str(severed[0])
		return {"kind": "prosthetic", "zone": zone, "item": _prosthetic_for(zone), "response": "replaces the limb the player took"}
	var organs: Dictionary = anatomy.get("organs", {})
	for organ_id in organs:
		var organ: Dictionary = organs[organ_id]
		if bool(organ.get("ruptured", false)) or float(organ.get("health", 1.0)) <= 0.0:
			return {"kind": "organ_support", "zone": str(organ.get("zone", "torso")), "organ": str(organ_id), "item": "%s cage" % str(organ_id).replace("_", " "), "response": "armours the organ the player ruptured"}
	var worst_zone := ""
	var worst_ratio := 1.0
	var zones: Dictionary = anatomy.get("zones", {})
	for zone_id in zones:
		var zone: Dictionary = zones[zone_id]
		var ceiling := float((Anatomy.DEFAULT_ZONES.get(zone_id, {}) as Dictionary).get("health", 1.0))
		var ratio := float(zone.get("health", ceiling)) / maxf(ceiling, 1.0)
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst_zone = str(zone_id)
	if not worst_zone.is_empty():
		return {"kind": "armour", "zone": worst_zone, "damage_ratio": snappedf(1.0 - worst_ratio, 0.01), "item": "%s impact cage" % worst_zone.replace("_", " "), "response": "plates the place the player nearly opened"}
	return {"kind": "scar", "zone": "torso", "response": "keeps the undamaged body as an accusation"}


static func _event_names(event: Dictionary, subject_id: String) -> bool:
	var details: Dictionary = event.get("details", {})
	for key in ["subject_id", "target", "target_id", "rival"]:
		if str(details.get(key, "")) == subject_id:
			return true
	return false


static func _survival_holds(event: Dictionary) -> bool:
	var outcome := str((event.get("details", {}) as Dictionary).get("outcome", ""))
	return outcome.is_empty() or outcome in ["escaped", "spare", "spared", "survived"]


static func _memory(subject: Dictionary, adaptation: Dictionary, latest: Dictionary) -> String:
	return "%s carries the %s wound from %s; the body answers by %s." % [str(subject.get("name", "They")), str(adaptation.get("zone", "torso")).replace("_", " "), str(latest.get("id", "that encounter")), str(adaptation.get("response", "changing"))]


static func _prosthetic_for(zone: String) -> String:
	match zone:
		"left_arm", "right_arm": return "industrial torque arm"
		"left_leg", "right_leg": return "pile-driver leg"
		"head": return "sealed witness helm"
	return "load-bearing body frame"
