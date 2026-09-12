class_name DemonAmbition
extends RefCounted

## K5.1 v2. "Lesser demons are rivals reread; they should eventually want
## something of their own." A first version, derived from what is already
## true about a subject rather than an authored personality (non-negotiable
## 2): a lesser demon either wants to settle its own worst recorded grudge,
## or — if it hasn't earned one yet — wants patronage from a real Sin.
##
## `_weakest_sin()` deliberately targets whichever Sin's `signal_control`
## (`wire_net.gd`, K4.4) is currently lowest: a Sin somebody has been
## contesting is a Sin with room in its roster, which ties K4.4/K4.6 and K5.1
## into one story instead of three — weakening a Sin's channel makes it a
## target for opportunists, not just a number going down.
##
## `pursue()` is one concrete step, not flavour text: settling a grudge
## records a real escalation event, and seeking patronage actually grants the
## faction affiliation, which is also the moment `DemonHierarchy.tier()`
## stops reading them as a lesser demon at all — they were reread as a rival
## once (F4.1); this is them being reread again, upward, by their own choice
## rather than a promotion the player caused.

const GRUDGE_THRESHOLD := 15


static func ambition(subject_id: String) -> Dictionary:
	if not DemonHierarchy.is_lesser_demon(subject_id):
		return {}
	var subject := WorldHistory.subject(subject_id)
	var relations: Dictionary = subject.get("relations", {})
	var worst_target := ""
	var worst_grudge := 0
	for other in relations:
		var edge: Dictionary = relations[other]
		if str(edge.get("kind", "")) == "grudge" and int(edge.get("strength", 0)) > worst_grudge:
			worst_grudge = int(edge.get("strength", 0))
			worst_target = str(other)
	if not worst_target.is_empty() and worst_grudge >= GRUDGE_THRESHOLD:
		return {"kind": "settle_grudge", "target": worst_target, "strength": worst_grudge}
	var faction_id := _weakest_sin()
	if faction_id.is_empty():
		return {}
	return {"kind": "seek_patronage", "target": faction_id}


static func _weakest_sin() -> String:
	var weakest := ""
	var weakest_control := 101.0
	for faction_id in DemonHierarchy.SIN_FACTIONS:
		var faction := WorldHistory.subject(faction_id)
		if faction.is_empty():
			continue
		var control := float(faction.get("signal_control", 100.0))
		if control < weakest_control:
			weakest_control = control
			weakest = faction_id
	return weakest


## One concrete step toward the ambition. Meant to be called when the world
## hands the demon an opportunity, not every frame — a real consequence each
## time, never a repeatable no-op.
static func pursue(subject_id: String) -> Dictionary:
	var goal := ambition(subject_id)
	if goal.is_empty():
		return {"ok": false, "reason": "NOTHING TO PURSUE"}
	match str(goal.kind):
		"settle_grudge":
			var target_id := str(goal.target)
			if WorldHistory.subject(target_id).is_empty():
				return {"ok": false, "reason": "TARGET NO LONGER EXISTS"}
			WorldHistory.record_event("demon_pursues_grudge", {"subject_id": subject_id, "target": target_id, "strength": int(goal.strength)})
			return {"ok": true, "kind": "settle_grudge", "target": target_id}
		"seek_patronage":
			var faction_id := str(goal.target)
			var faction := WorldHistory.subject(faction_id)
			if faction.is_empty():
				return {"ok": false, "reason": "NO FACTION WILL HAVE THEM YET"}
			WorldHistory.update_subject(subject_id, {
				"faction_id": faction_id, "faction": str(faction.get("name", faction_id)),
			}, "demon_sought_patronage")
			WorldHistory.record_event("demon_joined_faction", {"subject_id": subject_id, "faction_id": faction_id})
			return {"ok": true, "kind": "seek_patronage", "faction_id": faction_id}
	return {"ok": false, "reason": "UNKNOWN AMBITION"}
