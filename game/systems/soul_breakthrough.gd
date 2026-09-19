class_name SoulBreakthrough
extends RefCounted

## AX2.2 / AX2.3. The breakthrough, and who it belongs to.
##
## `brain_index.gd` says it plainly where the chip is installed: "Somebody else
## does this to you. `owner_faction` is who it answers to, and it is not you."
## This file is the moment that stops being true. Nothing new is installed and
## nothing arrives — the same hardware answers to somebody else afterwards.
##
## The direction doc draws one line harder than any other in the opening:
##
##   "The breakthrough is the player's own soul: accumulated suffering, refusal
##   to submit and the player's inner demon seize and rewrite the government
##   brain implant into the chaos-magick interface. **There is no separate
##   unknown entity granting or entering with the power.**"
##
## So there is no benefactor here, no voice, no pact and no visiting power, and
## the test enforces it: the seizure records the player as the only actor.

## Who the chip answers to once the player has taken it. Deliberately not a
## faction name — the point is that it stops belonging to an institution.
const OWNER_SELF := "self"

## Suffering is endured; refusal is chosen. They are not worth the same, and
## the doc's phrasing is "accumulated suffering AND refusal to submit".
const SUFFERING_WEIGHT := 0.15
const REFUSAL_WEIGHT := 0.25
const THRESHOLD := 1.0

## How far the seizure charges chaos magick. It is not a full bar: this is the
## first act, and AJ has a whole ladder above it.
const SEIZURE_CHARGE := 0.35


## An ember rather than a meter. `suffering` counts torture cycles endured,
## `refusals` counts answers the player declined during the examination.
static func ember(suffering: int, refusals: int) -> float:
	var raw := float(maxi(suffering, 0)) * SUFFERING_WEIGHT + float(maxi(refusals, 0)) * REFUSAL_WEIGHT
	return clampf(raw, 0.0, 2.0)


## **Submission never awakens it.** A player who endures everything and refuses
## nothing has been broken exactly as intended, and the institution wins that
## run. At least one refusal is required no matter how much was endured, which
## is the mechanical form of "refusal to submit" rather than a flavour line
## over a damage counter.
static func awakened(suffering: int, refusals: int) -> bool:
	if refusals <= 0:
		return false
	return ember(suffering, refusals) >= THRESHOLD


## Rewrites the government's chip into the player's interface. Returns what
## happened rather than a bare bool, because the caller wants to show it: the
## owner before, the owner after, and the serial that did not change — it is
## the same hardware, which is the horror and the point.
static func seize(subject_id: String = "player", suffering: int = 0, refusals: int = 0) -> Dictionary:
	if not awakened(suffering, refusals):
		return {"ok": false, "reason": "NOT AWAKE", "ember": ember(suffering, refusals)}
	var chip: Dictionary = BrainIndex.chip(subject_id)
	if chip.is_empty():
		return {"ok": false, "reason": "NOTHING IN THE HEAD TO TAKE"}
	var was := str(chip.get("owner_faction", ""))
	if was == OWNER_SELF:
		return {"ok": false, "reason": "ALREADY YOURS"}
	var rewritten := chip.duplicate(true)
	rewritten["owner_faction"] = OWNER_SELF
	rewritten["seized_from"] = was
	# The only actor. No third name is ever written here, and the test fails if
	# one is.
	rewritten["seized_by"] = subject_id
	rewritten["revoked"] = false
	rewritten["revoked_reason"] = ""
	# The event type is what raises chaos magick: `CHAOS_MAGICK` in
	# world_history.gd maps it to SEIZURE_CHARGE, the same way a completed
	# ritual is weighted. Recording the event is the charge - there is no
	# second call that could drift out of step with it.
	WorldHistory.update_subject(subject_id, {"wetwire_chip": rewritten}, "soul_seized_implant")
	return {
		"ok": true,
		"was": was,
		"now": OWNER_SELF,
		"serial": str(chip.get("serial", "")),
		"seized_by": subject_id,
		"ember": ember(suffering, refusals),
	}
