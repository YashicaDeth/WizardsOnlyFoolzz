extends Node

const ImplantCatalog := preload("res://systems/implant_catalog.gd")
const WoundCatalog := preload("res://systems/wound_catalog.gd")

signal event_recorded(event: Dictionary)
signal subject_changed(subject_id: String, subject: Dictionary)

const SAVE_PATH := "user://world_history.json"
const MAX_EVENTS := 500

var events: Array[Dictionary] = []
var next_sequence := 1
var subjects: Dictionary = {}


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") == "1":
		return
	_load_history()


func record_event(event_type: String, details: Dictionary = {}) -> Dictionary:
	var event := {
		"id": "event_%06d" % next_sequence,
		"sequence": next_sequence,
		"time_msec": Time.get_ticks_msec(),
		"type": event_type,
		"details": details.duplicate(true),
	}
	next_sequence += 1
	events.append(event)
	if events.size() > MAX_EVENTS:
		events.pop_front()
	_save_history()
	event_recorded.emit(event)
	return event


func register_subject(subject_id: String, initial_state: Dictionary) -> Dictionary:
	initial_state = _normalise_body_records(initial_state)
	if not subjects.has(subject_id):
		subjects[subject_id] = initial_state.duplicate(true)
		_save_history()
	else:
		# Save-safe schema migration: new authored fields are filled in without
		# erasing injuries, grudges, bonds or memories earned in an older build.
		var before: Dictionary = subjects[subject_id]
		var stored: Dictionary = _normalise_body_records(before)
		var changed := stored != before
		for key in initial_state:
			if not stored.has(key):
				stored[key] = initial_state[key]
				changed = true
		if changed:
			subjects[subject_id] = stored
			_save_history()
	return (subjects[subject_id] as Dictionary).duplicate(true)


func subject(subject_id: String) -> Dictionary:
	if not subjects.has(subject_id):
		return {}
	return (subjects[subject_id] as Dictionary).duplicate(true)


func all_subjects() -> Dictionary:
	return subjects.duplicate(true)


func subjects_in_faction(faction_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for subject_id in subjects:
		var entry: Dictionary = subjects[subject_id]
		if str(entry.get("faction_id", "")) == faction_id:
			var result := entry.duplicate(true)
			result["id"] = subject_id
			found.append(result)
	return found


func relationship_strength(from_id: String, to_id: String) -> int:
	var source := subject(from_id)
	var relations: Dictionary = source.get("relations", {})
	var relation: Dictionary = relations.get(to_id, {})
	return int(relation.get("strength", 0))


## AS ABOVE, SO BELOW: every subject's standing on the vertical Tree between
## the ascending and descending realms that flank Limbo. Faction birth sets a
## baseline pull; a subject's own bonds and grudges drift them from it, so
## rank and lineage are not destiny. Descending principles echo the Seven
## Deadly Sins per the Master Codex; ascending principles are original
## counterparts rather than a mirrored seven.
const FACTION_TREE_AXIS := {
	"ashline_wreckers": {"axis": -0.7, "principle": "Wrath"},
	"black_mile": {"axis": -0.55, "principle": "Greed"},
	"soft_rot": {"axis": -0.8, "principle": "Gluttony"},
	"choir_of_marrow": {"axis": -0.65, "principle": "Envy"},
	"gate_lanterns": {"axis": 0.6, "principle": "Charity"},
}


func tree_alignment(target: Dictionary) -> float:
	var base := 0.0
	var faction_id := str(target.get("faction_id", ""))
	if FACTION_TREE_AXIS.has(faction_id):
		base = float(FACTION_TREE_AXIS[faction_id].get("axis", 0.0))
	var drift := clampf((float(target.get("bond", 0)) - float(target.get("grudge", 0))) / 140.0, -0.35, 0.35)
	return clampf(base * 0.75 + drift, -1.0, 1.0)


func tree_descriptor(target: Dictionary) -> String:
	var faction_id := str(target.get("faction_id", ""))
	if FACTION_TREE_AXIS.has(faction_id):
		return str(FACTION_TREE_AXIS[faction_id].get("principle", ""))
	return ""


func tree_axis_label(value: float) -> String:
	if value > 0.2:
		return "ASCENT"
	if value < -0.2:
		return "DESCENT"
	return "LIMBO"


func update_subject(subject_id: String, changes: Dictionary, event_type: String = "subject_updated") -> Dictionary:
	changes = _normalise_body_records(changes)
	var updated := register_subject(subject_id, {})
	for key in changes:
		updated[key] = changes[key]
	subjects[subject_id] = updated
	record_event(event_type, {"subject_id": subject_id, "changes": changes.duplicate(true)})
	subject_changed.emit(subject_id, updated.duplicate(true))
	return updated.duplicate(true)


## Save-safe migration for the two authoring formats that used to be prose.
## Unknown legacy strings remain labelled but receive an explicit torso zone;
## nothing downstream performs fuzzy keyword inference.
func _normalise_body_records(state: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	if out.has("wounds"):
		out["wounds"] = WoundCatalog.list(out.wounds)
	for anatomy_key in ["anatomy", "anatomy_state"]:
		if out.get(anatomy_key) is Dictionary:
			var anatomy: Dictionary = out[anatomy_key]
			if anatomy.has("wounds"):
				anatomy["wounds"] = WoundCatalog.list(anatomy.wounds)
			if anatomy.has("cybernetics"):
				anatomy["cybernetics"] = ImplantCatalog.list(anatomy.cybernetics)
			out[anatomy_key] = anatomy
	return out


func recent_events(limit: int = 10) -> Array[Dictionary]:
	var first_index: int = maxi(0, events.size() - limit)
	return events.slice(first_index)


func event_count(event_type: String = "") -> int:
	if event_type.is_empty():
		return events.size()
	var count: int = 0
	for event in events:
		if event.type == event_type:
			count += 1
	return count


func clear_history() -> void:
	events.clear()
	subjects.clear()
	next_sequence = 1
	_save_history()


func _load_history() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("events") and parsed.events is Array:
		for stored_event in parsed.events:
			if stored_event is Dictionary:
				events.append(stored_event as Dictionary)
		next_sequence = int(parsed.get("next_sequence", events.size() + 1))
		if parsed.get("subjects", {}) is Dictionary:
			subjects = (parsed.get("subjects", {}) as Dictionary).duplicate(true)
			for subject_id in subjects:
				subjects[subject_id] = _normalise_body_records(subjects[subject_id])


func _save_history() -> void:
	if OS.get_environment("ATG_TEST_MODE") == "1":
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"next_sequence": next_sequence, "events": events, "subjects": subjects}))
