extends Node

const Quantum := preload("res://systems/quantum_saves.gd")
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# Test-mode writes are suppressed by WorldHistory, so this can exercise a
	# branch without touching a real player's ordinary save.
	WorldHistory.clear_history()
	WorldHistory.run_salt = 7001
	WorldHistory.register_subject("branch_a", {"name": "FIRST WORLD", "kind": "person"})
	WorldHistory.record_event("branch_a_event")
	var saved_a := Quantum.save_current(0, "FIRST WORLD")
	check(not saved_a.is_empty(), "saves a complete first quantum world")

	WorldHistory.clear_history()
	WorldHistory.run_salt = 9001
	WorldHistory.register_subject("branch_b", {"name": "SECOND WORLD", "kind": "person"})
	var saved_b := Quantum.save_current(1, "SECOND WORLD")
	check(not saved_b.is_empty(), "saves a separate second quantum world")
	check(Quantum.enter(0), "can enter an existing quantum world")
	check(WorldHistory.subject("branch_a").get("name", "") == "FIRST WORLD", "restores first world bodies")
	check(WorldHistory.subject("branch_b").is_empty(), "does not blend bodies between worlds")
	check(WorldHistory.run_salt == 7001, "restores the world's visual seed")
	check(Quantum.slots()[1].get("label", "") == "SECOND WORLD", "lists the second branch metadata")
	print("QUANTUM_SAVES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
