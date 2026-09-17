class_name LocalLaw
extends RefCounted

## AE. "assassination, executing and sneaking systems with the hostile and
## law enforcement type figures who punish you for bad local karmic events" —
## Greg's brief in CHECKLIST.md. There is no uniformed police in a wasteland
## with no government, so "the law" a killing answers to is never invented as
## a separate institution — it is whichever faction actually holds the ground
## it happened on, reading what its own people actually saw there.
##
## Built entirely on machinery that already exists rather than a second
## witness/crime system beside it: `witness_ledger.gd` (F1) already decides
## who saw something and whether a faction ever learns of it; `WorldHistory`'s
## own `event_karma()`/`FACTION_TREE_AXIS` (E1.1/E1.2) already grade an act and
## place every faction on the same Ascent/Descent axis a subject stands on.
## AE1.6's own line — "the law reads position, not evil" — is not a separate
## rule this file has to enforce; it falls out of reusing those two tables
## directly. `offence_magnitude()` below is the whole of it: a faction's own
## axis position decides whether an act was even a wrong to it, not a
## universal crime score everyone is measured against alike.

## AE1.2/AE1.3. The exact outcome vocabulary every other execution in the game
## already uses (`route_endings.gd`, `ascent_entities.gd`, `rival_tactics.gd`
## all key off `npc_resolution`/`execute`) — an assassination moves karma and
## the Tree exactly as hard as any other execution. `event_karma()` (Lane 4's,
## read only) is never touched to add a distinct entry for it.
const KILL_OUTCOME := "execute"

## AE1.1. Distance beyond which nobody could see it regardless of light, noise
## or cover — the same generous range `witness_ledger.gd` already uses for
## "was anybody close enough", so being unseen and being unwitnessed never
## quietly disagree about how far is too far. Callers may pass their own
## measured range instead; this is only the fallback.
const DEFAULT_SIGHT_RANGE := 34.0

## AE1.1. Light and noise raise how exposed an act was; cover lowers it. Below
## this combined exposure, nobody who could have seen it actually noticed —
## real inputs added and subtracted, never a single invented "stealth" stat.
const UNSEEN_EXPOSURE_THRESHOLD := 0.35

## AE1.5. How much a place has to remember (in real offence magnitude, not a
## flat incident count) before it stops merely logging and actually sends its
## holder's own people. Small enough that a place with a real recurring
## problem answers it within a handful of witnessed acts, not a career's worth.
const RESPONSE_THRESHOLD := 0.18

## AE10.14. Existing faction standing changes how much remembered unrest a
## holder tolerates before it sends bodies. This is intentionally a multiplier
## on the local threshold, not a second reputation score and not forgiveness:
## the witnessed wrong still enters the place record either way. `0.4` makes a
## faction that already refuses the actor answer one serious wrong; `1.55`
## gives somebody it reads as kin a meaningfully longer leash without immunity.
const HOSTILE_RESPONSE_SCALE := 0.4
const KIN_RESPONSE_SCALE := 1.55

## AE1.5. What being sent actually is: the exact `grudge` scalar `wire_net.gd`'s
## own channel-contest retaliation (K4.6) and `the_four_horsemen.gd` (K2.5)
## already raise on a faction's own record — the same real field the Hunt
## System already reads, scaled up from the small 0..1 offence magnitudes here
## into that field's own working range.
const GRUDGE_SCALE := 10.0


## AE1.1. "Unseen is a real state with real inputs — light, noise, cover,
## distance." `light`/`noise`/`cover` are each read 0..1 by whatever actually
## measures them out in the world (out of lane); this only ever combines real
## numbers into one honest state, never declares one on its own authority.
static func unseen_state(light: float, noise: float, cover: float, distance: float, sight_range: float = -1.0) -> Dictionary:
	var range_to_use := sight_range if sight_range > 0.0 else DEFAULT_SIGHT_RANGE
	if distance > range_to_use:
		return {"unseen": true, "exposure": 0.0, "beyond_sight": true}
	var exposure := clampf(light + noise - cover, 0.0, 1.0)
	return {"unseen": exposure < UNSEEN_EXPOSURE_THRESHOLD, "exposure": exposure, "beyond_sight": false}


## AE1.2/AE1.3. "Assassination as a verb: reach somebody who does not know you
## are there." Routed through the real `witness_ledger.gd` (`ledger.record()`)
## rather than a second call straight into `WorldHistory.record_event()`, so
## an assassination is subject to the exact same F1 witness/knowledge pipeline
## every other act already is. `witness_ids` should already be empty for a
## kill `unseen_state()` called unseen — that contract, not a second check
## here, is what makes AE1.2 true: only a seen kill can ever have anyone left
## to report it, so only a seen kill can ever reach `witness_a_wrong()` below.
static func assassinate(ledger: WitnessLedger, actor_id: String, victim_id: String, unseen: bool, witness_ids: Array, details: Dictionary = {}) -> Dictionary:
	var full := details.duplicate()
	full["subject_id"] = victim_id
	full["actor"] = actor_id
	full["outcome"] = KILL_OUTCOME
	full["unseen"] = unseen
	return ledger.record("npc_resolution", full, witness_ids)


## AE1.6. Whether a faction reads this act as an offence at all — not "how
## evil was it" but "which way does this pull, relative to where this faction
## already stands." A faction deep in Descent does not register a Descent-
## pulling act as a wrong; the identical act is a real offence to a faction
## that has climbed the other way, and a faction deep in Descent can just as
## honestly be offended by an act of mercy in its own territory. Reuses
## `event_karma()` and `FACTION_TREE_AXIS` directly — no separate crime value
## exists here for either to drift out of sync with.
static func offence_magnitude(faction_id: String, event: Dictionary) -> float:
	if not WorldHistory.FACTION_TREE_AXIS.has(faction_id):
		return 0.0
	var faction_axis := float(WorldHistory.FACTION_TREE_AXIS[faction_id].get("axis", 0.0))
	# event_karma is negative for a Descent-pulling act; flipping its sign
	# turns it into "how hard this pulls toward Ascent", so multiplying by the
	# faction's own axis reads positive only when the act pulls the same
	# direction the faction is offended by moving away from — i.e. away from
	# where it already stands.
	var pull := -WorldHistory.event_karma(event)
	return maxf(0.0, faction_axis * pull)


## The same derived relationship already used by trade, read as enforcement
## tolerance. `faction_price_factor()` compares the actor's live Tree position
## (including what their body has visibly become) with the faction's; no local-
## law-only affinity is stored or displayed.
static func response_threshold(faction_id: String, actor_id: String) -> float:
	var actor := WorldHistory.subject(actor_id)
	var standing := WorldHistory.faction_price_factor(faction_id, actor)
	var closeness := clampf(standing / 1.2, 0.0, 1.0)
	return RESPONSE_THRESHOLD * lerpf(HOSTILE_RESPONSE_SCALE, KIN_RESPONSE_SCALE, closeness)


## AE1.4/AE1.5. "Law figures respond to what was actually witnessed...
## Punishment is local: the holding remembers, and the holding sends them."
## Refuses outright unless the faction that holds this ground has actually
## been told — real knowledge off `witness_ledger.gd`'s own delivery (F1), not
## a direct read of the event log every faction can already see regardless of
## what anybody actually witnessed. What a place remembers accumulates on its
## own real WorldHistory subject (`kind: "place"`, `held_by` the answering
## faction) until it is enough to actually dispatch — a single incident is
## logged and, alone, forgotten; a place that keeps remembering eventually
## raises the faction's own real `grudge`, which is what "sends them" means
## mechanically, the same field the Hunt System already reads off anyone else.
static func witness_a_wrong(place_id: String, faction_id: String, ledger: WitnessLedger, event: Dictionary, actor_id: String) -> Dictionary:
	if not ledger.faction_knows(faction_id, int(event.get("sequence", -1))):
		return {"ok": false, "reason": "THE HOLDER WAS NEVER TOLD"}
	var place := WorldHistory.subject(place_id)
	if not place.is_empty() and str(place.get("held_by", faction_id)) != faction_id:
		return {"ok": false, "reason": "THAT FACTION DOES NOT HOLD THIS GROUND"}
	var magnitude := offence_magnitude(faction_id, event)
	if is_zero_approx(magnitude):
		return {"ok": false, "reason": "NOT AN OFFENCE TO WHOEVER HOLDS THIS GROUND"}
	if place.is_empty():
		WorldHistory.register_subject(place_id, {"kind": "place", "held_by": faction_id, "unrest": 0.0})
		place = WorldHistory.subject(place_id)
	var sequence := int(event.get("sequence", -1))
	var answered: Array = (place.get("law_seen_sequences", []) as Array).duplicate()
	if sequence >= 0 and answered.has(sequence):
		return {"ok": false, "reason": "THIS WRONG WAS ALREADY ANSWERED HERE"}
	if sequence >= 0:
		answered.append(sequence)
		if answered.size() > 64:
			answered.pop_front()
	var unrest := float(place.get("unrest", 0.0)) + magnitude
	var threshold := response_threshold(faction_id, actor_id)
	var disposition := WorldHistory.faction_disposition(faction_id, WorldHistory.subject(actor_id))
	WorldHistory.record_event("local_unrest", {
		"place_id": place_id, "faction_id": faction_id, "actor_id": actor_id,
		"source_sequence": sequence, "magnitude": magnitude, "unrest": unrest,
		"response_threshold": threshold, "disposition": disposition,
	})
	var dispatched := false
	if unrest >= threshold:
		var faction := WorldHistory.subject(faction_id)
		if not faction.is_empty():
			WorldHistory.amend_subject(faction_id, {"grudge": float(faction.get("grudge", 0.0)) + unrest * GRUDGE_SCALE})
		WorldHistory.record_event("law_dispatched", {
			"place_id": place_id, "faction_id": faction_id, "actor_id": actor_id,
			"source_sequence": sequence, "unrest_spent": unrest,
			"response_threshold": threshold, "disposition": disposition,
		})
		unrest = 0.0
		dispatched = true
	WorldHistory.amend_subject(place_id, {"unrest": unrest, "law_seen_sequences": answered})
	return {
		"ok": true, "magnitude": magnitude, "unrest": unrest,
		"dispatched": dispatched, "response_threshold": threshold,
		"disposition": disposition,
	}


## One report that actually completed WitnessLedger's walk home. Resolution
## writers attach the jurisdiction that existed at the scene; this accepts the
## report only when it reached that holder, reconstructs the original event
## shape used by `event_karma()`, and lets the canonical place remember it.
static func answer_report(ledger: WitnessLedger, report: Dictionary) -> Dictionary:
	var details: Dictionary = (report.get("details", {}) as Dictionary).duplicate(true)
	var place_id := str(details.get("place_id", ""))
	var holder_id := str(details.get("held_by", ""))
	if place_id == "" or holder_id == "":
		return {"ok": false, "reason": "NO LOCAL JURISDICTION ON THE REPORT"}
	if str(report.get("faction", "")) != holder_id:
		return {"ok": false, "reason": "THE REPORT WENT SOMEWHERE ELSE"}
	var event := {
		"sequence": int(report.get("sequence", -1)),
		"type": str(report.get("type", "")),
		"details": details,
	}
	var result := witness_a_wrong(place_id, holder_id, ledger, event, str(details.get("actor", details.get("actor_id", "player"))))
	result["place_id"] = place_id
	result["faction_id"] = holder_id
	result["source_sequence"] = int(report.get("sequence", -1))
	result["at"] = details.get("at", {})
	return result
