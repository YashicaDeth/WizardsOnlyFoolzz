class_name WorldDamage
extends RefCounted

## AB2.1/AB2.2/AB2.3. `DESIGN/DESTRUCTION.md` scopes destruction down from
## "full voxel fracture" (a second project) to "condition, not fracture" —
## this is that primitive, step one of that scope and nothing more. No
## visuals, no per-object break states: those belong to whatever authors a
## real object class on top of this (the design doc's own step two), once
## one exists to need them.
##
## Built the same shape `clothing.gd` already proved for worn layers: static
## functions over a `WorldHistory` subject, no second store anywhere that
## could disagree with the saved world, so "how wrecked is this" (AB2.3) is a
## lookup rather than a walk of the scene. A subject nobody has ever damaged
## simply reads as intact — the same refusal to invent a stored fact
## `Clothing.worn()` already makes for a subject nobody has dressed.

## The generic ladder, used when a caller does not hand in its own. An
## authored object class is expected to define its own break-state
## thresholds against `condition()`'s raw number rather than lean on this —
## it exists so "how wrecked is this, roughly" still has an answer for
## anything that has not been given a real ladder yet.
const DEFAULT_BANDS := [
	{"floor": 0.9, "label": "intact"},
	{"floor": 0.5, "label": "damaged"},
	{"floor": 0.15, "label": "wrecked"},
	{"floor": 0.0, "label": "destroyed"},
]


## Never invents damage that never happened — a subject nobody has recorded
## a hit against simply reads as intact, the same way a fresh weapon reads
## as full condition before anything has ever happened to it.
static func condition(subject_id: String) -> float:
	var record := WorldHistory.subject(subject_id)
	if record.is_empty():
		return 1.0
	return clampf(float(record.get("condition", 1.0)), 0.0, 1.0)


static func is_destroyed(subject_id: String) -> bool:
	return condition(subject_id) <= 0.0


static func _band_for(value: float, bands: Array) -> String:
	for entry: Dictionary in bands:
		if value >= float(entry.get("floor", 0.0)):
			return str(entry.get("label", "intact"))
	if bands.is_empty():
		return "destroyed"
	return str((bands.back() as Dictionary).get("label", "destroyed"))


static func band(subject_id: String, bands: Array = DEFAULT_BANDS) -> String:
	return _band_for(condition(subject_id), bands)


## AB2.2. Damage only lands on a subject the world already knows about — the
## same refusal `Clothing.wear()` gives a subject nobody has registered, so a
## typo'd id fails loudly instead of quietly creating a phantom object with
## no owner and no history behind it. `bands` lets the caller report whether
## *its own* break-state ladder was crossed, not just the generic one.
static func damage(subject_id: String, amount: float, cause: String = "", bands: Array = DEFAULT_BANDS) -> Dictionary:
	if amount <= 0.0:
		return {"ok": false, "reason": "NO DAMAGE TO APPLY"}
	if WorldHistory.subject(subject_id).is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var before := condition(subject_id)
	var after := clampf(before - amount, 0.0, 1.0)
	WorldHistory.amend_subject(subject_id, {"condition": after})
	WorldHistory.record_event("object_damaged", {
		"subject_id": subject_id,
		"amount": snappedf(amount, 0.001),
		"condition": snappedf(after, 0.001),
		"cause": cause,
	})
	return {
		"ok": true,
		"condition": after,
		"band": _band_for(after, bands),
		"crossed_band": _band_for(before, bands) != _band_for(after, bands),
	}


## AB2.4's own scope note: repair is somebody's job, not a timer — this is
## only the arithmetic that whoever eventually holds that job (AA) will call.
## No scheduling, no game-time cost, no owner check: not this file's to
## invent ahead of the system that actually prices it.
static func repair(subject_id: String, amount: float, cause: String = "") -> Dictionary:
	if amount <= 0.0:
		return {"ok": false, "reason": "NO REPAIR TO APPLY"}
	if WorldHistory.subject(subject_id).is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var after := clampf(condition(subject_id) + amount, 0.0, 1.0)
	WorldHistory.amend_subject(subject_id, {"condition": after})
	WorldHistory.record_event("object_repaired", {
		"subject_id": subject_id,
		"amount": snappedf(amount, 0.001),
		"condition": snappedf(after, 0.001),
		"cause": cause,
	})
	return {"ok": true, "condition": after, "band": band(subject_id)}
