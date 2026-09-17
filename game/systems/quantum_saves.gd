class_name QuantumSaves
extends RefCounted

const PlayerActionLedger := preload("res://systems/player_action_ledger.gd")

## Three named worlds the player can preserve and return to. They are copies,
## not checkpoints that overwrite each other: choosing another slot restores
## its own history, bodies, time, flags and visual seed.
const SLOT_COUNT := 3
const SLOT_PATH_FORMAT := "user://quantum_branch_%d.json"
const SCHEMA_VERSION := 1


static func slot_path(slot: int) -> String:
	return SLOT_PATH_FORMAT % clampi(slot, 0, SLOT_COUNT - 1)


static func slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in SLOT_COUNT:
		var entry := _read_slot(slot)
		result.append({
			"slot": slot,
			"occupied": not entry.is_empty(),
			"label": str(entry.get("label", "UNWRITTEN WORLD")),
			"saved_at": str(entry.get("saved_at", "")),
			"world_minute": float((entry.get("world", {}) as Dictionary).get("world_minute", 0.0)),
		})
	return result


static func save_current(slot: int, label: String = "") -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return {}
	var world := WorldHistory.snapshot()
	var resolved_label := label.strip_edges()
	if resolved_label.is_empty():
		resolved_label = "WORLD %02d" % (slot + 1)
	var payload := {
		"schema": SCHEMA_VERSION,
		"slot": slot,
		"label": resolved_label,
		"saved_at": Time.get_datetime_string_from_system(),
		"world": world,
	}
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		return {}
	file.store_string(JSON.stringify(payload))
	return payload.duplicate(true)


## Preserves the current world before crossing over, then writes the selected
## branch to the regular save. Calling code can keep the previous slot index in
## a menu setting; this class never assumes one slot is more real than another.
static func enter(slot: int) -> bool:
	var payload := _read_slot(slot)
	if payload.is_empty() or not payload.get("world", null) is Dictionary:
		return false
	# Restored universe, selected slot and the act of crossing are one boundary.
	WorldHistory.begin_ledger_batch()
	if not WorldHistory.restore_snapshot(payload.world as Dictionary):
		WorldHistory.commit_ledger_batch()
		return false
	WorldHistory.set_flag("quantum_active_slot", slot)
	PlayerActionLedger.record("quantum_branch_entered", {"slot": slot, "label": str(payload.get("label", ""))})
	WorldHistory.commit_ledger_batch()
	return true


## B10.1/B10.2. Who does not restart when the universe does.
##
## T1.1's whole claim is that the universe restarts and you do not, and until
## this list existed that was false in the most literal way available: the
## restart calls `clear_history()`, `clear_history()` empties `subjects`, and
## `subjects` is where bodies live. Nine passes of anatomy were erased with the
## world and a new body was decanted on the other side. The player was not
## surviving the branch, they were being replaced in it.
const CARRIED_SUBJECTS := ["player"]


## A blank, seeded universe intended for the New Game action. It deliberately
## does not destroy another slot; it only creates/replaces the chosen branch.
static func begin_new(slot: int, label: String = "") -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return {}
	var carried := _carry_across()
	# Do not persist the empty instant between erasing the old universe and
	# carrying the surviving body into the new one.
	WorldHistory.begin_ledger_batch()
	WorldHistory.clear_history()
	WorldHistory.run_salt = randi() | 1
	WorldHistory.world_minute = 16.5 * 60.0
	WorldHistory.flags = {"quantum_active_slot": slot}
	WorldHistory.chaos_magick_level = 0.0
	WorldHistory.chaos_magick_at_minute = WorldHistory.world_minute
	for subject_id: String in carried:
		WorldHistory.register_subject(subject_id, carried[subject_id] as Dictionary)
	PlayerActionLedger.record("quantum_branch_born", {"slot": slot, "carried": carried.keys()})
	WorldHistory.commit_ledger_batch()
	CellOutzGrunge.remember_run(WorldHistory.run_salt)
	return save_current(slot, label)


## The bodies that cross, reduced to what is allowed to cross with them.
##
## The record goes over whole — a person is their name, their race, what they
## look like, what they were grown with — because that is what B10.1's
## "recognisably itself" is made of, and none of it is a consequence of the
## branch being left behind. The one thing rewritten on the way through is
## `anatomy_state`, which is reduced by `BaselineHuman.scars_of()` to the marks
## on the body: the holes and where they are, how deep each limb was opened, the
## limbs that are gone, the hardware installed in what is left. The health, the
## blood, the pain, the dose and the tally of how close a limb was to coming off
## are left in the universe that did them.
static func _carry_across() -> Dictionary:
	var carried := {}
	for subject_id: String in CARRIED_SUBJECTS:
		var record: Dictionary = WorldHistory.subject(subject_id)
		if record.is_empty():
			continue
		if record.get("anatomy_state") is Dictionary:
			record["anatomy_state"] = BaselineHuman.scars_of(record.anatomy_state as Dictionary)
		carried[subject_id] = record
	return carried


static func _read_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT or not FileAccess.file_exists(slot_path(slot)):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema", 0)) != SCHEMA_VERSION:
		return {}
	return (parsed as Dictionary).duplicate(true)
