extends Node

## F10.15. The hunter's old world does not cross a quantum restart. The player
## does, and their compact memory must still name exactly who came after them.

const MEMORY := preload("res://systems/hunt_memory.gd")
const QUANTUM := preload("res://systems/quantum_saves.gd")

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
	WorldHistory.run_salt = 4511
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	hunt._begin_canonical_encounter()
	var first: Array = MEMORY.known_by()
	check(first.size() == 1,
		"the production canonical encounter writes one hunter onto the player")
	var captain_id := str(first[0].get("hunter_id", "")) if not first.is_empty() else ""
	check(not captain_id.is_empty() and not WorldHistory.subject(captain_id).is_empty(),
		"the memory names the exact real captain rather than a hunt category")
	check(str(first[0].get("reason", "")) == "canonical_rival" and int(first[0].get("source_run", 0)) == 4511,
		"it remembers why and in which universe the hunt began")
	MEMORY.remember(captain_id, "canonical_rival")
	check(MEMORY.known_by().size() == 1 and WorldHistory.event_count("player_hunted_by") == 1,
		"restoring the same encounter cannot duplicate the same hunt memory")

	WorldHistory.register_subject("other_hunter", {
		"name": "Ledger Bailiff Nineteen", "kind": "person",
		"faction_id": "celloutz", "status": "active",
	})
	MEMORY.remember("other_hunter", "repossession_contract", "facility:1")
	check(MEMORY.known_by().size() == 2,
		"a distinct named contract hunter becomes a distinct memory")
	var old_names := (MEMORY.known_by() as Array).map(func(entry: Dictionary): return str(entry.get("name", "")))

	var born := QUANTUM.begin_new(2, "HUNTER MEMORY WORLD")
	check(not born.is_empty(), "a genuinely fresh universe is born")
	check(WorldHistory.subject(captain_id).is_empty() and WorldHistory.subject("other_hunter").is_empty(),
		"the old hunters and their world do not cross with the player")
	var carried: Array = MEMORY.known_by()
	check(carried.size() == 2,
		"the new universe still knows both people hunted this player")
	var carried_names := carried.map(func(entry: Dictionary): return str(entry.get("name", "")))
	check(carried_names == old_names,
		"their exact names survive rather than collapsing into a wanted counter")
	check(int((WorldHistory.subject("player").get("last_hunter", {}) as Dictionary).get("source_run", 0)) == 4511,
		"the newest hunter memory still points back to the universe that produced it")

	print("HUNT_MEMORY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
