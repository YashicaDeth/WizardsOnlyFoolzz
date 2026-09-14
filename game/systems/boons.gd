class_name Boons
extends RefCounted

## E4. "Boosts are always temporary. The cost should be paid in the body or in
## standing, because those are the two ledgers the game already keeps."
## — DESIGN/RITUAL_AND_KARMA.md
##
## This is the machinery E2 (rituals) and E6 (drugs) both hang a boost off of
## once their own content exists — neither is built yet, so nothing here
## invents a ritual or a drug. What it enforces is the rule itself:
##
## - **E4.1.** There is no function that grants a permanent effect. Every
##   grant carries a duration, and `active_boons()` prunes anything past it —
##   the temporariness is structural, not a value someone has to remember to
##   set.
## - **E4.2.** The cost is paid against the same body the anatomy component
##   already tracks (blood, an organ, a limb) or against standing (`bond`),
##   never a currency. Reuses `AnatomyComponent`'s own zone/organ tables so a
##   subject with no anatomy snapshot yet still gets the real defaults rather
##   than an invented one.
## - **E4.3.** The same boost taken again costs more, so stacking one boost is
##   worse than varying what you take.
##
## Read/write only through `WorldHistory`'s public API, same as
## `cosmology_factions.gd` and `ascent_entities.gd` — this never touches a
## live `AnatomyComponent` node directly, only the persisted snapshot shape it
## already reads and writes (`snapshot()`/`restore()`), so whoever wires a
## live boost effect onto a scene can restore from the same subject.

const AnatomyComponent := preload("res://systems/anatomy_component.gd")
const COST_KINDS := ["blood", "organ", "limb", "standing"]
const REPEAT_MULTIPLIER := 1.4
const BLOOD_FLOOR := 250.0
const LIMB_FLOOR := 5.0


static func grant(subject_id: String, boon_id: String, stat: String, magnitude: float, duration_seconds: float, cost_kind: String, base_cost: float, cost_target: String = "") -> Dictionary:
	if not COST_KINDS.has(cost_kind):
		return {"ok": false, "reason": "UNKNOWN COST KIND"}
	if duration_seconds <= 0.0:
		return {"ok": false, "reason": "NOT A BOOST IF IT DOES NOT END"}
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var history: Dictionary = subject.get("boon_history", {})
	var taken := int(history.get(boon_id, 0))
	var scaled_cost := base_cost * pow(REPEAT_MULTIPLIER, float(taken))
	var payment := _pay(subject_id, cost_kind, scaled_cost, cost_target)
	if not bool(payment.get("ok", false)):
		return payment
	history[boon_id] = taken + 1
	var active := active_boons(subject_id)
	active = active.filter(func(b): return str((b as Dictionary).get("id", "")) != boon_id)
	active.append({
		"id": boon_id, "stat": stat, "magnitude": magnitude,
		"granted_msec": Time.get_ticks_msec(), "duration_msec": int(duration_seconds * 1000.0),
	})
	WorldHistory.amend_subject(subject_id, {"boon_history": history, "active_boons": active})
	WorldHistory.record_event("boon_granted", {
		"subject_id": subject_id, "boon_id": boon_id, "stat": stat, "magnitude": magnitude,
		"cost_kind": cost_kind, "cost_paid": scaled_cost, "times_taken": taken + 1,
	})
	return {"ok": true, "cost_paid": scaled_cost, "duration_msec": int(duration_seconds * 1000.0)}


## The live total for one stat across every boost still running, so a caller
## never has to know how many are stacked or prune them itself.
static func stat_bonus(subject_id: String, stat: String) -> float:
	var total := 0.0
	for entry in active_boons(subject_id):
		if str((entry as Dictionary).get("stat", "")) == stat:
			total += float((entry as Dictionary).get("magnitude", 0.0))
	return total


## E4.1, enforced. Prunes anything past its own duration and writes the
## pruned list back, so an expired boost cannot linger just because nothing
## asked about it in a while.
static func active_boons(subject_id: String) -> Array:
	var subject := WorldHistory.subject(subject_id)
	var now := Time.get_ticks_msec()
	var kept: Array = []
	var changed := false
	for entry in (subject.get("active_boons", []) as Array):
		var boon: Dictionary = entry
		if now - int(boon.get("granted_msec", 0)) < int(boon.get("duration_msec", 0)):
			kept.append(boon)
		else:
			changed = true
	if changed:
		WorldHistory.amend_subject(subject_id, {"active_boons": kept})
	return kept


static func _default_anatomy_state() -> Dictionary:
	var organs := {}
	for organ_id in AnatomyComponent.ORGANS:
		var organ: Dictionary = (AnatomyComponent.ORGANS[organ_id] as Dictionary).duplicate(true)
		organ["ruptured"] = false
		organs[organ_id] = organ
	var zones := {}
	for zone_id in AnatomyComponent.DEFAULT_ZONES:
		zones[zone_id] = (AnatomyComponent.DEFAULT_ZONES[zone_id] as Dictionary).duplicate(true)
	return {"blood": 5000.0, "blood_capacity": 5000.0, "organs": organs, "zones": zones}


## A cost can stand on its own.  Petitions and creditors spend the same body /
## standing ledger as a boon, but they must not invent a fake timed boost merely
## to get access to it.  Keep the actual debit private below and expose this
## narrow public door so those systems cannot couple themselves to an underscore
## implementation detail.
static func pay(subject_id: String, cost_kind: String, amount: float, cost_target: String = "") -> Dictionary:
	if not COST_KINDS.has(cost_kind):
		return {"ok": false, "reason": "UNKNOWN COST KIND"}
	return _pay(subject_id, cost_kind, amount, cost_target)


static func _pay(subject_id: String, cost_kind: String, amount: float, cost_target: String) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	var anatomy: Dictionary = subject.get("anatomy_state", {})
	if anatomy.is_empty():
		anatomy = _default_anatomy_state()
	match cost_kind:
		"blood":
			var current := float(anatomy.get("blood", anatomy.get("blood_capacity", 5000.0)))
			if current <= BLOOD_FLOOR:
				return {"ok": false, "reason": "NOT ENOUGH BLOOD LEFT TO SPEND"}
			anatomy["blood"] = maxf(BLOOD_FLOOR, current - amount)
			WorldHistory.amend_subject(subject_id, {"anatomy_state": anatomy})
			return {"ok": true}
		"organ":
			if cost_target.is_empty() or not AnatomyComponent.ORGANS.has(cost_target):
				return {"ok": false, "reason": "NO ORGAN NAMED"}
			var organs: Dictionary = anatomy.get("organs", {})
			var default_organ: Dictionary = AnatomyComponent.ORGANS[cost_target]
			var organ: Dictionary = organs.get(cost_target, default_organ.duplicate(true))
			var health := float(organ.get("health", default_organ.get("health", 20.0)))
			if health <= 1.0:
				return {"ok": false, "reason": "THAT ORGAN HAS NOTHING LEFT TO GIVE"}
			organ["health"] = maxf(0.0, health - amount)
			organ["ruptured"] = bool(organ.get("ruptured", false)) or float(organ.health) <= 0.0
			organs[cost_target] = organ
			anatomy["organs"] = organs
			WorldHistory.amend_subject(subject_id, {"anatomy_state": anatomy})
			return {"ok": true}
		"limb":
			if cost_target.is_empty() or not AnatomyComponent.DEFAULT_ZONES.has(cost_target):
				return {"ok": false, "reason": "NO LIMB NAMED"}
			var zones: Dictionary = anatomy.get("zones", {})
			var default_zone: Dictionary = AnatomyComponent.DEFAULT_ZONES[cost_target]
			var zone: Dictionary = zones.get(cost_target, default_zone.duplicate(true))
			var zone_health := float(zone.get("health", default_zone.get("health", 60.0)))
			if zone_health <= LIMB_FLOOR:
				return {"ok": false, "reason": "THAT LIMB HAS NOTHING LEFT TO GIVE"}
			zone["health"] = maxf(LIMB_FLOOR, zone_health - amount)
			zones[cost_target] = zone
			anatomy["zones"] = zones
			WorldHistory.amend_subject(subject_id, {"anatomy_state": anatomy})
			return {"ok": true}
		"standing":
			var bond := float(subject.get("bond", 0))
			if bond <= 0.0:
				return {"ok": false, "reason": "YOU HAVE NO STANDING LEFT TO SPEND"}
			WorldHistory.amend_subject(subject_id, {"bond": maxf(0.0, bond - amount)})
			return {"ok": true}
	return {"ok": false, "reason": "UNKNOWN COST KIND"}
