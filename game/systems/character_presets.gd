class_name CharacterPresets
extends RefCounted

## AX1.3 / AX1.5. "Reusable presets", and "a saved preset gives repeat players
## a much faster route".
##
## `ROUTES` in vat_intake.gd has offered PRESET since it was written and
## nothing was behind it -- only `route == "random"` was ever handled. So the
## first route on the first page of the first screen of the game did nothing,
## which is a bad first promise to break.
##
## The whole value is in one property: **a preset has to restore everything the
## player chose, or it is worse than not having one.** A preset that silently
## drops the birth time sends a repeat player back into the natal chart to
## re-enter it, and they will not know that is why their chart is wrong. So the
## field list lives here, once, and the round-trip test walks it rather than
## checking a handful of fields somebody remembered.

const STORE_ID := "character_presets"

## Everything a player can set during the examination. Adding a field to
## CharacterSheet and not to this list is the bug this constant exists to make
## obvious, and `missing_fields()` below names it out loud.
const SAVED_FIELDS := [
	"route", "race", "traits", "modifiers", "birth", "instrument",
	"appearance", "under_skin", "display_name", "anatomy_sex",
]


static func _store() -> Dictionary:
	var subject := WorldHistory.subject(STORE_ID)
	if subject.is_empty():
		return {}
	return subject.get("presets", {})


## Saves under a player-chosen name. Overwrites deliberately: a repeat player
## refining their build wants one slot that improves, not eleven near-misses.
static func save(preset_name: String, sheet) -> Dictionary:
	var clean := preset_name.strip_edges()
	if clean.is_empty():
		return {"ok": false, "reason": "A PRESET NEEDS A NAME"}
	var snapshot := {}
	for field in SAVED_FIELDS:
		if field in sheet:
			var value = sheet.get(field)
			snapshot[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	var presets := _store().duplicate(true)
	presets[clean] = snapshot
	if WorldHistory.subject(STORE_ID).is_empty():
		WorldHistory.register_subject(STORE_ID, {"kind": "presets", "presets": presets})
	else:
		WorldHistory.update_subject(STORE_ID, {"presets": presets}, "character_preset_saved")
	return {"ok": true, "name": clean, "fields": snapshot.size()}


static func names() -> Array:
	var out: Array = _store().keys()
	out.sort()
	return out


## The fast route. Applies every saved field back onto a sheet in one action --
## that is the "much faster" in AX1.5, and it only holds if nothing is dropped.
static func apply(preset_name: String, sheet) -> Dictionary:
	var presets := _store()
	if not presets.has(preset_name):
		return {"ok": false, "reason": "NO SUCH PRESET"}
	var snapshot: Dictionary = presets[preset_name]
	var restored: Array = []
	for field in SAVED_FIELDS:
		if not snapshot.has(field) or not (field in sheet):
			continue
		var value = snapshot[field]
		sheet.set(field, value.duplicate(true) if value is Dictionary or value is Array else value)
		restored.append(field)
	return {"ok": true, "name": preset_name, "restored": restored}


## Which fields a sheet has that presets would silently lose. Exposed rather
## than kept internal so a test can fail on it the day somebody adds a field to
## CharacterSheet and forgets this file.
static func missing_fields(sheet) -> Array:
	var ignored := [
		# Derived from the chart or the traits rather than chosen, so restoring
		# the inputs restores these for free.
		"points", "attributes",
	]
	var gaps: Array = []
	for property in sheet.get_property_list():
		var field := str(property.get("name", ""))
		if field.begins_with("_") or field == "script" or field == "Built-in script":
			continue
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		if SAVED_FIELDS.has(field) or ignored.has(field):
			continue
		gaps.append(field)
	return gaps
