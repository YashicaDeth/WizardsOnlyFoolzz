class_name RunLifecycle
extends RefCounted

## T1.2. "Death is an event in the world rather than a reload." Deliberately
## does not touch T1.1 ("what persists between runs") — that is explicitly
## blocked on Greg, and this file does not guess an answer by building T1.3's
## inheritance or T1.5's run shape on top of it. What is safe regardless of
## how T1.1 resolves: a permanent death should be a rich recorded fact, not
## a bare reload with nothing written down.
##
## `record_death()` captures what the world actually knew at the moment it
## happened — where the run had reached (`OpeningDirector`), what was being
## carried (`Carry`), and where the subject stood on the axis
## (`tree_alignment()`) — rather than a single "GAME OVER" flag. Whatever
## T1.1 eventually decides should inherit, T1.3's answer reads off this
## event rather than needing a second record built later.

const OpeningDirectorScript := preload("res://systems/opening_director.gd")
const CarryScript := preload("res://systems/carry.gd")


static func record_death(subject_id: String, cause: String, details: Dictionary = {}) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {}
	var carried: Array = []
	if subject_id == "player":
		var carry := CarryScript.new()
		for item in carry.items:
			carried.append(str((item as Dictionary).get("label", "")))
	var record := {
		"subject_id": subject_id,
		"cause": cause,
		"stage": OpeningDirectorScript.stage() if subject_id == "player" else "",
		"alignment": WorldHistory.tree_alignment(subject),
		"karma": float(subject.get("karma", 0.0)),
		"carried": carried,
		"grudge": int(subject.get("grudge", 0)),
	}
	for key in details:
		record[key] = details[key]
	WorldHistory.record_event("permanent_death", record)
	return record


## Every permanent death recorded so far, oldest first — the raw material
## whatever T1.3 eventually builds (a body, a debt, a reputation, a wall of
## pins) would read from, without this file deciding which of those it is.
static func death_history() -> Array:
	var out: Array = []
	for event in WorldHistory.events:
		if str(event.get("type", "")) == "permanent_death":
			out.append(event.get("details", {}))
	return out
