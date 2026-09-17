class_name OffscreenHunts
extends RefCounted

## F10.11. A hunt belongs to WorldHistory and WorldClock, not to the scene
## containing its body. Every quarter-hour spent somewhere else advances the
## exact hunter/target pair. Catch-up is arithmetic, so sleep and long scene
## absences do not require an idle Node to survive in memory or emit one event
## per missed frame.

const TURN_MINUTES := 15.0
const LIVE_HUNT_STATUSES := ["hunting"]
const SCAN_MINUTES := 1.0
static var _last_scan_minute := -INF


static func start(hunter_id: String, target_id: String, hunt_location: String) -> Dictionary:
	var hunter := WorldHistory.subject(hunter_id)
	if hunter.is_empty() or WorldHistory.subject(target_id).is_empty() or hunt_location.is_empty():
		return {"ok": false, "reason": "HUNT NEEDS EXACT PEOPLE AND A PLACE"}
	var same_hunt := str(hunter.get("hunt_target", "")) == target_id and str(hunter.get("hunt_location", "")) == hunt_location
	var changes := {
		"hunt_target": target_id,
		"hunt_location": hunt_location,
		"hunt_started_minute": float(hunter.get("hunt_started_minute", WorldClock.minutes())) if same_hunt else WorldClock.minutes(),
		"hunt_last_minute": float(hunter.get("hunt_last_minute", WorldClock.minutes())) if same_hunt else WorldClock.minutes(),
		"hunt_offscreen_turns": int(hunter.get("hunt_offscreen_turns", 0)) if same_hunt else 0,
		"hunt_phase": str(hunter.get("hunt_phase", "present")) if same_hunt else "present",
	}
	var updated := WorldHistory.amend_subject(hunter_id, changes)
	updated["ok"] = true
	return updated


## Called by whichever scene currently owns the clock. Time spent at the
## hunt's own place is deliberately not background progress; when the caller
## names a different place, every completed interval since the last settlement
## lands in one mutation and one event.
static func advance(current_location: String) -> Array[Dictionary]:
	var settled: Array[Dictionary] = []
	var now := WorldClock.minutes()
	# Derby calls this every physics frame because it owns the clock. Hunting
	# turns are quarter-hour facts, so a deep subject scan sixty times a second
	# would be pure waste. A quantum restart can move the clock backwards; that
	# resets the process-local throttle rather than silencing the new universe.
	if now < _last_scan_minute:
		_last_scan_minute = -INF
	if now - _last_scan_minute < SCAN_MINUTES:
		return settled
	_last_scan_minute = now
	for hunter_id in WorldHistory.all_subjects():
		var hunter := WorldHistory.subject(str(hunter_id))
		if str(hunter.get("kind", "")) != "person" or str(hunter.get("status", "")) not in LIVE_HUNT_STATUSES:
			continue
		var target_id := str(hunter.get("hunt_target", ""))
		var hunt_location := str(hunter.get("hunt_location", ""))
		if target_id.is_empty() or WorldHistory.subject(target_id).is_empty() or hunt_location.is_empty():
			continue
		var anchor := float(hunter.get("hunt_last_minute", now))
		if current_location == hunt_location:
			# Do not later misclassify a long face-to-face encounter as time away.
			if now - anchor >= TURN_MINUTES:
				WorldHistory.amend_subject(str(hunter_id), {"hunt_last_minute": now, "hunt_phase": "present"})
			continue
		var turns := int(floor(maxf(now - anchor, 0.0) / TURN_MINUTES))
		if turns <= 0:
			continue
		var total := int(hunter.get("hunt_offscreen_turns", 0)) + turns
		var phase := _phase(total)
		WorldHistory.amend_subject(str(hunter_id), {
			"hunt_last_minute": anchor + float(turns) * TURN_MINUTES,
			"hunt_offscreen_turns": total,
			"hunt_phase": phase,
			"hunt_last_elsewhere": current_location,
		})
		var event := WorldHistory.record_event("hunt_advanced_elsewhere", {
			"hunter_id": str(hunter_id), "target_id": target_id,
			"hunt_location": hunt_location, "player_location": current_location,
			"turns": turns, "total_turns": total, "phase": phase,
		})
		settled.append(event)
	return settled


## F10.12. Succession can carry an unfinished hunt as well as an office. The
## successor inherits the exact target, place and accumulated search state;
## no prior relation or encounter is required. Whether they had ever met is
## recorded, so an inherited stranger remains distinguishable from a rival who
## earned the hunt personally.
static func inherit(fallen_id: String, successor_id: String) -> Dictionary:
	var fallen := WorldHistory.subject(fallen_id)
	var successor := WorldHistory.subject(successor_id)
	var target_id := str(fallen.get("hunt_target", ""))
	var hunt_location := str(fallen.get("hunt_location", ""))
	if fallen.is_empty() or successor.is_empty() or target_id.is_empty() or hunt_location.is_empty():
		return {"ok": false, "reason": "NO UNFINISHED HUNT TO INHERIT"}
	if str(successor.get("kind", "")) != "person" or LIVE_HUNT_STATUSES.has(str(successor.get("status", ""))):
		return {"ok": false, "reason": "SUCCESSOR CANNOT INHERIT"}
	var met_before := _has_met(successor_id, target_id)
	WorldHistory.begin_ledger_batch()
	var updated := WorldHistory.update_subject(successor_id, {
		"status": "hunting", "hunt_target": target_id,
		"hunt_location": hunt_location,
		"hunt_started_minute": WorldClock.minutes(),
		"hunt_last_minute": WorldClock.minutes(),
		"hunt_offscreen_turns": int(fallen.get("hunt_offscreen_turns", 0)),
		"hunt_phase": str(fallen.get("hunt_phase", "present")),
		"hunt_inherited_from": fallen_id,
		"hunt_inherited_without_contact": not met_before,
	}, "hunt_inherited")
	WorldHistory.amend_subject(fallen_id, {"hunt_inherited_by": successor_id})
	WorldHistory.commit_ledger_batch()
	updated["ok"] = true
	return updated


static func _phase(turns: int) -> String:
	if turns >= 6:
		return "waiting"
	if turns >= 3:
		return "closing"
	return "searching"


static func _has_met(subject_id: String, target_id: String) -> bool:
	var relations: Dictionary = WorldHistory.subject(subject_id).get("relations", {})
	if relations.has(target_id):
		return true
	for event in WorldHistory.events:
		var details: Dictionary = event.get("details", {}) as Dictionary
		var names_subject := false
		var names_target := false
		for key in details:
			if str(details[key]) == subject_id:
				names_subject = true
			if str(details[key]) == target_id:
				names_target = true
		if names_subject and names_target:
			return true
	return false
