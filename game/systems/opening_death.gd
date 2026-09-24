class_name OpeningDeath
extends RefCounted

## AX4.5. What happens when the player dies during the facility escape.
##
## Until 24 September this file held the question open with an honest ordinary
## reload, because the death fiction was not authored. Greg has now answered
## it: **you are reborn in a vat** -- the soul bound to Earth through repeated
## rebirth, from the player direction interview -- and, in his words, "dont
## forget the save character preset so you can reload it if you die without
## wasting time". So a death sends the player back to the Growing Floor, and
## the body they filed last is waiting for them on the clipboard instead of a
## blank form.
##
## What is still NOT decided stays refused below: rebirth is not a respawn
## timer, a backup, or a clone, and nothing here says the universe resets. The
## world keeps what happened (Law 13 is still an open conflict with rebirth).

const FICTION_AUTHORED := true
const REBIRTH_SCENE := "res://vat_chamber.tscn"
const STORE_ID := "opening_rebirth"

## Claims the authored fiction still does not make. Each is a specific answer
## to a question Greg has not given, so text that uses one is overreaching.
const COUNTERFEITS := [
	"respawn", "resurrect", "clone", "backup", "reprint", "immortal",
]


## The player died in the opening. Records the rebirth, marks one as pending
## for the vat to pick up, and names the preset the new body is grown from.
static func handle(cause: String = "") -> Dictionary:
	var store := WorldHistory.subject(STORE_ID)
	var count := int(store.get("count", 0)) + 1
	var preset := CharacterPresets.LAST_BODY if CharacterPresets.names().has(CharacterPresets.LAST_BODY) else ""
	var changes := {"count": count, "pending": true, "preset": preset, "last_cause": cause}
	if store.is_empty():
		changes["kind"] = "rebirth_record"
		WorldHistory.register_subject(STORE_ID, changes)
	else:
		WorldHistory.update_subject(STORE_ID, changes, "opening_rebirth_marked")
	WorldHistory.record_event("opening_rebirth", {"cause": cause, "count": count, "preset": preset})
	return {
		"ok": true,
		"kind": "rebirth",
		"scene": REBIRTH_SCENE,
		"preset": preset,
		"count": count,
		"cause": cause,
	}


## Read once by the vat on load. Returns the pending rebirth (or {}) and
## clears it, so reloading the scene later is not mistaken for another death.
static func consume_pending() -> Dictionary:
	var store := WorldHistory.subject(STORE_ID)
	if not bool(store.get("pending", false)):
		return {}
	WorldHistory.update_subject(STORE_ID, {"pending": false}, "opening_rebirth_decanted")
	return {"count": int(store.get("count", 0)), "preset": str(store.get("preset", ""))}


## Whether any text claims more than the authored fiction does.
static func counterfeits_in(text: String) -> Array:
	var found: Array = []
	var lowered := text.to_lower()
	for word in COUNTERFEITS:
		if lowered.contains(word):
			found.append(word)
	return found
