extends Node

## AG5.11. Save files: deletable, continuable, several of them. Runs against
## the real slot machinery, not a mock of it — `_saves_dir()` resolves to
## `TEST_SAVES_DIR` under `ATG_TEST_MODE`, so this actually round-trips files
## on disk without ever touching a real player's `saves/` directory.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.clear_history()
	check(WorldHistory.list_slots().is_empty(), "a fresh install starts with no slots at all")

	var slot_a := WorldHistory.create_slot("Vale Rime")
	WorldHistory.record_event("test_marker", {"which": "a"})
	check(WorldHistory.active_slot_id == slot_a, "creating a slot makes it the active one")
	check(WorldHistory.event_count("test_marker") == 1, "and the world it starts from is genuinely empty first")

	var slot_b := WorldHistory.create_slot("Roan Hollow")
	WorldHistory.record_event("test_marker", {"which": "b"})
	check(slot_a != slot_b, "a second slot gets its own id")
	check(WorldHistory.event_count("test_marker") == 1, "and starts with none of the first slot's history")

	var slots := WorldHistory.list_slots()
	check(slots.size() == 2, "both slots are listed (%d)" % slots.size())

	var loaded_a := WorldHistory.load_slot(slot_a)
	check(loaded_a, "the first slot loads on request")
	check(WorldHistory.active_slot_id == slot_a, "and becomes active again")
	check(WorldHistory.event_count("test_marker") == 1, "with exactly its own one marker back")
	var markers: Array[Dictionary] = []
	for event in WorldHistory.events:
		if event.type == "test_marker":
			markers.append(event)
	check(str(markers[0].details.get("which", "")) == "a", "and it is genuinely slot A's marker, not slot B's (%s)" % str(markers[0].details.get("which", "")))

	var loaded_b := WorldHistory.load_slot(slot_b)
	check(loaded_b, "the second slot loads independently")
	check(WorldHistory.event_count("test_marker") == 1, "with its own single marker, not a merge of both")

	var missing := WorldHistory.load_slot("slot_does_not_exist")
	check(not missing, "loading an id that was never created is refused, not silently accepted")

	var deleted := WorldHistory.delete_slot(slot_a)
	check(deleted, "an existing slot can actually be deleted")
	check(WorldHistory.list_slots().size() == 1, "and it is genuinely gone from the list, not just hidden")
	var still_there := WorldHistory.load_slot(slot_a)
	check(not still_there, "and its file is gone too — it cannot be loaded back")

	# Deleting the slot you are standing in is not a state a save-select
	# screen should be able to get stuck in.
	WorldHistory.load_slot(slot_b)
	WorldHistory.delete_slot(slot_b)
	check(WorldHistory.active_slot_id == "", "deleting the active slot clears active_slot_id rather than pointing at nothing")

	if failures.is_empty():
		print("save slots: several worlds, each of them real, none of them each other's")
		get_tree().quit(0)
	else:
		print("save slots FAILURES: ", failures)
		get_tree().quit(1)
