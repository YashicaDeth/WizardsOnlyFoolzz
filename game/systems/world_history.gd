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
	# E1.1. The act moves its author on the Tree before the write, so the saved
	# file and the axis never disagree.
	var weight := event_karma(event)
	if not is_zero_approx(weight):
		_accumulate_karma(event_actor(event), weight)
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


## E1.1. What a recorded act does to where its author sits on the Tree.
##
## Karma is not a new number and it is never shown as one — it is this axis,
## which has existed and been drawn since the dossier was built, finally being
## moved by what actually happened. `DESIGN/RITUAL_AND_KARMA.md`: *"Karma is
## not a new number. It is the existing Ascent/Descent alignment made visible,
## accumulated from real recorded events, and given consequences."*
##
## Sizes are deliberately small. A handful of executions moves you; a career
## defines you. Nothing here is a good/evil slider and nothing announces
## itself — it is read through the Tree view, per E1.3.
const KARMA := {
	"execute": -0.09,
	"behead": -0.12,
	"spare": 0.08,
	"recruit": 0.05,
	"rob_living": -0.07,
	"rob_dead": -0.02,
	"sell_part": -0.03,
	"silence_witness": -0.11,
	"maim": -0.03,
	"kindness": 0.05,
}


## Which acts count, and for how much. Anything not named here is morally inert
## — swinging, missing, driving, being hit — because a game that scored every
## input would be a morality meter wearing this one's clothes.
func event_karma(event: Dictionary) -> float:
	var details: Dictionary = event.get("details", {})
	match str(event.get("type", "")):
		"npc_resolution":
			return float(KARMA.get(str(details.get("outcome", "")), 0.0))
		"part_extracted":
			return float(KARMA.rob_living if bool(details.get("owner_alive", false)) else KARMA.rob_dead)
		"carried_part_sold":
			return float(KARMA.sell_part)
		"report_cut":
			return float(KARMA.silence_witness)
		"limb_severed_in_combat":
			return float(KARMA.maim)
		"misfire_bond", "bond_strengthened", "npc_spared":
			return float(KARMA.kindness)
	return 0.0


## Who answers for it. Most of these are the player's acts; an event that names
## its own actor is believed.
func event_actor(event: Dictionary) -> String:
	return str((event.get("details", {}) as Dictionary).get("actor", "player"))


## The running total, accumulated as acts are recorded rather than recomputed.
## It has to be stored: `MAX_EVENTS` makes the log a rolling window, so the
## oldest thing you did falls out of it, and a karma recomputed from the log
## alone would quietly forgive you for it. The log is what happened recently;
## this is what it made of you.
func _accumulate_karma(subject_id: String, weight: float) -> void:
	if subject_id == "" or not subjects.has(subject_id):
		return
	var stored: Dictionary = subjects[subject_id]
	stored["karma"] = clampf(float(stored.get("karma", 0.0)) + weight, -1.0, 1.0)
	subjects[subject_id] = stored
	subject_changed.emit(subject_id, stored.duplicate(true))


## Karma over the events still retained, for tests and for rebuilding a save
## whose subjects predate the field. Not the authority — see `_accumulate_karma`.
func karma_from_history(subject_id: String = "player") -> float:
	var total := 0.0
	for event in events:
		if event_actor(event) == subject_id:
			total += event_karma(event)
	return clampf(total, -1.0, 1.0)


func tree_alignment(target: Dictionary) -> float:
	var base := 0.0
	var faction_id := str(target.get("faction_id", ""))
	if FACTION_TREE_AXIS.has(faction_id):
		base = float(FACTION_TREE_AXIS[faction_id].get("axis", 0.0))
	var drift := clampf((float(target.get("bond", 0)) - float(target.get("grudge", 0))) / 140.0, -0.35, 0.35)
	# Birth pulls less hard than it used to, because what you have done now has
	# somewhere to go. Enough of a career overcomes the faction you were born
	# into, which is the whole point of "rank and lineage are not destiny".
	var karma := clampf(float(target.get("karma", 0.0)), -1.0, 1.0)
	return clampf(base * 0.65 + drift + karma, -1.0, 1.0)


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


## A change that is not itself news. One more person hearing a rumour is not an
## event in the world's history, it is a change in what somebody believes — and
## recording every hop would flood a 500-entry log and evict the acts the
## rumour is actually about. Used by F2's propagation.
func amend_subject(subject_id: String, changes: Dictionary) -> Dictionary:
	changes = _normalise_body_records(changes)
	var updated := register_subject(subject_id, {})
	for key in changes:
		updated[key] = changes[key]
	subjects[subject_id] = updated
	_save_history()
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
