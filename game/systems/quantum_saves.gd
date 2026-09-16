class_name QuantumSaves
extends RefCounted

## Three named worlds the player can preserve and return to. They are copies,
## not checkpoints that overwrite each other: choosing another slot restores
## its own history, bodies, time, flags and visual seed.
const SLOT_COUNT := 3
const SLOT_PATH_FORMAT := "user://quantum_branch_%d.json"
## Every other save path in this project has a sandboxed twin that ATG_TEST_MODE
## selects — `SAVES_DIR`/`TEST_SAVES_DIR` and `DEMO_SAVE_PATH`/
## `TEST_DEMO_SAVE_PATH` in `world_history.gd`. These three did not, so the two
## quantum suites wrote their branches straight over a real player's, and
## permanently: a branch is the whole world, and nothing keeps a copy. Same
## pattern, resolved in `slot_path()` so every read and write in this file goes
## through the one decision.
const TEST_SLOT_PATH_FORMAT := "user://test_quantum_branch_%d.json"
const SCHEMA_VERSION := 1


static func slot_path(slot: int) -> String:
	var format := SLOT_PATH_FORMAT
	if OS.get_environment("ATG_TEST_MODE") == "1":
		format = TEST_SLOT_PATH_FORMAT
	return format % clampi(slot, 0, SLOT_COUNT - 1)


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
	if not WorldHistory.restore_snapshot(payload.world as Dictionary):
		return false
	WorldHistory.set_flag("quantum_active_slot", slot)
	WorldHistory.record_event("quantum_branch_entered", {"slot": slot, "label": str(payload.get("label", ""))})
	return true


## A blank, seeded universe intended for the New Game action. It deliberately
## does not destroy another slot; it only creates/replaces the chosen branch.
static func begin_new(slot: int, label: String = "") -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return {}
	WorldHistory.clear_history()
	WorldHistory.run_salt = randi() | 1
	WorldHistory.world_minute = 16.5 * 60.0
	WorldHistory.flags = {"quantum_active_slot": slot}
	WorldHistory.chaos_magick_level = 0.0
	WorldHistory.chaos_magick_at_minute = WorldHistory.world_minute
	WorldHistory.record_event("quantum_branch_born", {"slot": slot})
	CellOutzGrunge.remember_run(WorldHistory.run_salt)
	return save_current(slot, label)


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
