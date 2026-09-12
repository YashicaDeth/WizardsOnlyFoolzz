class_name Meditation
extends RefCounted

## E8. "With the stamina and health a meditation or psychedelic drug part
## should be a part of it." E6 built the fast half (`substances.gd`) — costs
## the body, reaches the entity layer quickly. This is the slow half: costs
## only time, and cannot be rushed.
##
## E8.1: a held state on the subject itself (`meditation_progress_seconds`),
## not a button that grants an instant buff — there is no function here that
## returns a benefit without `tick()` having actually been called with real
## elapsed time. Progress accumulates from the caller's own `delta_seconds`
## rather than a wall-clock timestamp, the same way `carry.gd`'s `age()`
## already is "advanced by whoever owns the carry loop" — not this file
## reading `Time.get_ticks_msec()` and hoping the caller ticked it every
## frame without a gap.
##
## E8.2/E8.6: pays down `pain` on the same `anatomy_state` ledger `boons.gd`/
## `substances.gd` already write into, at `PAIN_RATE` per second — and,
## per E8.6, that is the *only* thing it spends: no blood, no organ, no limb.
## Stamina itself lives in a live movement component this file has no
## visibility into (it is not part of `anatomy_state`'s persisted shape), so
## `STAMINA_MULTIPLIER` is offered as the "faster than standing" rate for
## whoever owns that value to apply, rather than this file inventing a second
## stamina field WorldHistory would have to carry.
##
## E8.3: `interrupt()` is not the same call as `end()` — ending cleanly
## banks what was earned; interrupting adds real pain, scaled by how deep the
## session had gotten, because "the world does not pause for it" has to cost
## something or it is not a risk.
##
## E8.4: `begin()` takes `context` as given by the caller (signal grade,
## territory, who is nearby) rather than querying a live scene this file
## cannot see — recorded once, at the moment sitting down actually happened.
##
## E8.5: deep enough (`ENTITY_THRESHOLD_SECONDS`), it calls
## `AscentEntities.glimpse()` exactly like a door substance does — same
## contact, no attention spent, no `wash()` — but only reachable by time
## actually accumulated, never by a single function call.

const PAIN_RATE := 2.0
const STAMINA_MULTIPLIER := 2.5
const ENTITY_THRESHOLD_SECONDS := 60.0


static func is_meditating(subject_id: String) -> bool:
	return bool(WorldHistory.subject(subject_id).get("meditating", false))


static func progress_seconds(subject_id: String) -> float:
	return float(WorldHistory.subject(subject_id).get("meditation_progress_seconds", 0.0))


## E8.1/E8.4. Refuses to restart on top of an existing session, so a second
## call cannot silently reset progress and hide an interruption that should
## have cost something.
static func begin(subject_id: String, context: Dictionary = {}) -> Dictionary:
	if WorldHistory.subject(subject_id).is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	if is_meditating(subject_id):
		return {"ok": false, "reason": "ALREADY SITTING"}
	WorldHistory.amend_subject(subject_id, {
		"meditating": true, "meditation_progress_seconds": 0.0, "meditation_context": context.duplicate(true),
	})
	WorldHistory.record_event("meditation_began", {"subject_id": subject_id, "context": context.duplicate(true)})
	return {"ok": true}


## E8.2/E8.6. One step of pain paydown for however much real time the caller
## reports actually passed. Meant to be called from whoever drives the hold
## (not necessarily every engine frame, but on the same clock the held input
## uses) — `delta_seconds` is trusted, the same way every other `tick(delta)`
## in this codebase trusts its caller's own frame time.
static func tick(subject_id: String, delta_seconds: float) -> Dictionary:
	if not is_meditating(subject_id):
		return {"ok": false, "reason": "NOT SITTING"}
	var subject := WorldHistory.subject(subject_id)
	var anatomy: Dictionary = subject.get("anatomy_state", {})
	var pain := float(anatomy.get("pain", 0.0))
	anatomy["pain"] = clampf(pain - PAIN_RATE * delta_seconds, 0.0, 100.0)
	var progress := float(subject.get("meditation_progress_seconds", 0.0)) + delta_seconds
	WorldHistory.amend_subject(subject_id, {"anatomy_state": anatomy, "meditation_progress_seconds": progress})
	var result := {"ok": true, "pain_after": float(anatomy.pain), "progress_seconds": progress, "stamina_multiplier": STAMINA_MULTIPLIER}
	if progress >= ENTITY_THRESHOLD_SECONDS:
		result["glimpsed"] = _glimpse_one(subject_id)
	return result


static func _glimpse_one(subject_id: String) -> String:
	var entity_ids := AscentEntities.ENTITIES.keys()
	if entity_ids.is_empty():
		return ""
	var index := int(hash(subject_id + "meditation" + str(WorldHistory.next_sequence))) % entity_ids.size()
	var entity_id := str(entity_ids[absi(index)])
	AscentEntities.glimpse(entity_id, subject_id)
	return entity_id


## A clean, voluntary stop. Banks whatever pain paydown already happened;
## no penalty, because nothing forced this one.
static func end(subject_id: String) -> Dictionary:
	if not is_meditating(subject_id):
		return {"ok": false, "reason": "NOT SITTING"}
	var held := progress_seconds(subject_id)
	WorldHistory.amend_subject(subject_id, {"meditating": false, "meditation_progress_seconds": 0.0, "meditation_context": {}})
	WorldHistory.record_event("meditation_ended", {"subject_id": subject_id, "held_seconds": held})
	return {"ok": true, "held_seconds": held}


## E8.3. "Interrupted is worse than never started." A real pain cost, scaled
## by how deep the session had gotten — the world does not pause to let it
## finish gracefully, and getting pulled out of it hurts more the deeper in
## it you were.
static func interrupt(subject_id: String, reason: String) -> Dictionary:
	if not is_meditating(subject_id):
		return {"ok": false, "reason": "NOT SITTING"}
	var held := progress_seconds(subject_id)
	var subject := WorldHistory.subject(subject_id)
	var anatomy: Dictionary = subject.get("anatomy_state", {})
	var shock := clampf(held * 0.5, 0.0, 40.0)
	anatomy["pain"] = clampf(float(anatomy.get("pain", 0.0)) + shock, 0.0, 100.0)
	WorldHistory.amend_subject(subject_id, {
		"anatomy_state": anatomy, "meditating": false, "meditation_progress_seconds": 0.0, "meditation_context": {},
	})
	WorldHistory.record_event("meditation_interrupted", {"subject_id": subject_id, "held_seconds": held, "reason": reason, "shock_pain": shock})
	return {"ok": true, "held_seconds": held, "shock_pain": shock}
