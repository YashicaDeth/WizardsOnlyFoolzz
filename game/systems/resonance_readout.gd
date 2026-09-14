class_name ResonanceReadout
extends RefCounted

## The compact, truthful payload for a future handheld resonance page.  It is
## deliberately presentation-neutral: ritual, meditation, substances, plane
## access and consequences already have their own systems; this only reports
## their shared state so a screen cannot invent a second cosmology.

const PROVENANCE := {
	"ritual_completed": "OBSERVED",
	"plane_petitioned": "OBSERVED",
	"plane_altitude_failed": "OBSERVED",
	"substance_taken": "ATTRIBUTED",
	"meditation_ended": "OBSERVED",
	"meditation_interrupted": "OBSERVED",
}


static func snapshot(subject_id: String, plane_id: String = "yesod") -> Dictionary:
	var plane := PlaneLadder.plane(plane_id)
	if plane.is_empty() or bool(plane.get("daath", false)):
		return {"ok": false, "reason": "NO READOUT FOR AN UNMAPPED PLACE"}
	var altitude := PlaneLadder.altitude(subject_id)
	var floors: Array = []
	for floor_name in PlaneLadder.FLOOR_ORDER:
		var required := PlaneLadder.floor_requirement(plane_id, floor_name)
		floors.append({
			"action": floor_name,
			"available": altitude >= required,
			"required": required,
		})
	return {
		"ok": true,
		"subject_id": subject_id,
		"plane_id": plane_id,
		"plane_name": str(plane.get("name", plane_id)),
		"altitude": altitude,
		"meditating": Meditation.is_meditating(subject_id),
		"floors": floors,
		"provenance": provenance_summary(subject_id),
		"consequence": consequence(subject_id),
	}


## Counts sources rather than treating a pile of posts as corroboration.  One
## event remains one event, even if a dozen feeds repeat it.
static func provenance_summary(subject_id: String) -> Dictionary:
	var counts := {"OBSERVED": 0, "ATTRIBUTED": 0, "CONTESTED": 0, "FABRICATED": 0}
	for event in WorldHistory.events:
		var details: Dictionary = event.get("details", {})
		if str(details.get("subject_id", "")) != subject_id:
			continue
		var status := str(PROVENANCE.get(str(event.get("type", "")), "CONTESTED"))
		counts[status] = int(counts.get(status, 0)) + 1
	return counts


## The wheel's sentence.  It deliberately describes outstanding harm and
## repair without pretending to know a cosmic verdict.
static func consequence(subject_id: String) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	var karma := clampf(float(subject.get("karma", 0.0)), -1.0, 1.0)
	var posture := "MIXED: KEEP WITNESSES IN FRAME"
	if karma <= -0.25:
		posture = "HARM OUTRUNS REPAIR"
	elif karma >= 0.25:
		posture = "REPAIR HAS A TRACE"
	return {"karma": karma, "posture": posture, "question": "WHO PAYS FOR WHAT MOVED?"}
