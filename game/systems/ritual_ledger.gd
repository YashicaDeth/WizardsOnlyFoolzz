class_name RitualLedger
extends RefCounted

## E3. A rite is evidence the world can check, never a dialogue option with a
## confirm button. The camera owns whether a body was actually in frame and
## what state it was in; this file only defines an evidence claim and remembers
## when the claim was honestly met.

const FieldCamera := preload("res://systems/field_camera.gd")

const LEDGER_ID := "ritual_ledger"

## E3.1. This is the worked example Greg gave us: kill five people and
## photograph their gored heads. It is deliberately the only authored rite in
## this increment. Naming an occult order, inventing a Law, prices, boosts, or
## rewards all belongs to later, separately designed work (E2/E4/E5), not an
## evidence checker silently making those decisions.
const RITUALS: Array[Dictionary] = [
	{
		"id": "five_gored_heads",
		"label": "FIVE HEADS / ONE FRAME",
		"route": "descent",
		"instruction": "FIVE DEAD, DESTROYED HEADS. ONE FRAME.",
		"requirements": [
			{
				"all_of": [
					{"state": "dead"},
					{"zone": "head", "state": "destroyed"},
				],
				"count": 5,
			},
		],
	},
]


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in RITUALS:
		result.append(entry.duplicate(true))
	return result


static func find(ritual_id: String) -> Dictionary:
	for entry in RITUALS:
		if str(entry.get("id", "")) == ritual_id:
			return entry.duplicate(true)
	return {}


static func outstanding() -> Array[Dictionary]:
	var entries: Dictionary = _entries()
	var pending: Array[Dictionary] = []
	for ritual in all():
		if not entries.has(str(ritual.get("id", ""))):
			pending.append(ritual)
	return pending


## Checks one photograph only. The frame is a hard boundary: five close-ups of
## one corpse do not become five bodies, and all conditions must be true of
## each same matched body rather than split across a convenient crowd.
static func evaluate(photo: Dictionary, ritual_id: String) -> Dictionary:
	var ritual := find(ritual_id)
	if ritual.is_empty():
		return {"ok": false, "reason": "UNKNOWN RITE", "requirements": []}
	var reports: Array[Dictionary] = []
	var passed := true
	for raw_requirement in ritual.get("requirements", []) as Array:
		if not raw_requirement is Dictionary:
			passed = false
			continue
		var requirement: Dictionary = raw_requirement
		var report := FieldCamera.verify(photo, requirement)
		report["requirement"] = requirement.duplicate(true)
		reports.append(report)
		if not bool(report.get("ok", false)):
			passed = false
	return {
		"ok": passed and not reports.is_empty(),
		"ritual": ritual,
		"photo_id": str(photo.get("id", "")),
		"requirements": reports,
	}


## E3.3. Taking the photograph is the input. Every unresolved rite evaluates it
## immediately; there is no accept, turn-in, or complete action in this path.
## The ledger snapshot survives even once the 40-photo album rolls over.
static func submit_photo(photo: Dictionary) -> Dictionary:
	var entries: Dictionary = _entries()
	var accepted: Array[Dictionary] = []
	var reports: Array[Dictionary] = []
	for ritual in all():
		var ritual_id := str(ritual.get("id", ""))
		if entries.has(ritual_id):
			continue
		var report := evaluate(photo, ritual_id)
		reports.append(report)
		if not bool(report.get("ok", false)):
			continue
		entries[ritual_id] = {
			"state": "completed",
			"photo_id": str(photo.get("id", "")),
			"photo": photo.duplicate(true),
		}
		accepted.append(ritual)
	if not accepted.is_empty():
		WorldHistory.amend_subject(LEDGER_ID, {"version": 1, "rituals": entries})
		for ritual in accepted:
			WorldHistory.record_event("ritual_completed", {
				"actor": "player",
				"ritual_id": str(ritual.get("id", "")),
				"route": str(ritual.get("route", "")),
				"photo_id": str(photo.get("id", "")),
				"location": str(photo.get("location", "")),
			})
	return {"completed": accepted, "reports": reports}


## A photograph taken before this increment is still evidence. Call this when
## the ritual page opens rather than every draw frame; it can therefore file an
## old valid frame exactly once without making UI rendering mutate game state.
static func reconcile_album() -> Dictionary:
	var accepted: Array[Dictionary] = []
	for raw_photo in FieldCamera.album():
		if raw_photo is Dictionary:
			var result := submit_photo(raw_photo as Dictionary)
			for ritual in result.get("completed", []) as Array:
				if ritual is Dictionary:
					accepted.append(ritual as Dictionary)
	return {"completed": accepted}


## Old photographs can show partial evidence in the handheld without a second
## progress counter. The maximum matched subjects is derived from their real
## stored contents every time the page is opened.
static func best_evidence(ritual_id: String) -> Dictionary:
	var ritual := find(ritual_id)
	if ritual.is_empty():
		return {"ok": false, "requirements": []}
	var best := evaluate({}, ritual_id)
	var best_score := -1
	for raw_photo in FieldCamera.album():
		if not raw_photo is Dictionary:
			continue
		var photo: Dictionary = raw_photo
		var report := evaluate(photo, ritual_id)
		var score := _evidence_score(report)
		if score > best_score:
			best = report
			best_score = score
	return best


static func requirement_label(requirement: Dictionary) -> String:
	if requirement.has("all_of"):
		var labels: Array[String] = []
		for raw in requirement.get("all_of", []) as Array:
			if raw is Dictionary:
				labels.append(requirement_label(raw as Dictionary))
		return " + ".join(PackedStringArray(labels))
	var organ := str(requirement.get("organ", ""))
	if organ != "":
		return "%s RUPTURED" % organ.replace("_", " ").to_upper()
	var zone := str(requirement.get("zone", ""))
	var state := str(requirement.get("state", ""))
	return ("%s %s" % [zone, state]).strip_edges().replace("_", " ").to_upper()


static func _evidence_score(report: Dictionary) -> int:
	var score := 0
	for raw_requirement in report.get("requirements", []) as Array:
		if raw_requirement is Dictionary:
			var requirement: Dictionary = raw_requirement
			score += (requirement.get("matched", []) as Array).size()
	return score


static func _entries() -> Dictionary:
	var state := WorldHistory.register_subject(LEDGER_ID, {
		"kind": "ritual_ledger",
		"version": 1,
		"rituals": {},
	})
	return state.get("rituals", {}) as Dictionary
