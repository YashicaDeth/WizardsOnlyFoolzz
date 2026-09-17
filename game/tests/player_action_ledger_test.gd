extends Node

const LEDGER := preload("res://systems/player_action_ledger.gd")

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER"})
	var first := LEDGER.record("held_item_inspected", {"item": "cigarette", "location": "ashbloom"})
	var second := LEDGER.record("smoke_trick", {"trick": "O", "location": "ashbloom"})
	check(str(first.details.action_id) == "action_000001", "the first routed act receives a durable receipt")
	check(str(second.details.action_id) == "action_000002", "receipts advance through one sequence")
	check(str(first.details.subject_id) == "player", "the common route supplies the player actor by default")
	check(WorldHistory.event_count("held_item_inspected") == 1 and WorldHistory.event_count("smoke_trick") == 1, "existing event names remain available to every current consumer")
	check(LEDGER.count("held_item_inspected") == 1 and LEDGER.count("smoke_trick") == 1, "the compact ledger summarizes acts without scanning history")
	check(str(WorldHistory.subject(LEDGER.SUBJECT).last.type) == "smoke_trick", "the ledger exposes the latest physical act")
	WorldHistory.begin_ledger_batch()
	LEDGER.record("smoke_exhaled", {"device": "joint"})
	check(int(WorldHistory.get("_ledger_batch_depth")) == 1, "the action route nests inside a larger physical transaction")
	WorldHistory.commit_ledger_batch()
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0 and LEDGER.count("smoke_exhaled") == 1, "the outer transaction performs the final commit")
	print("PLAYER_ACTION_LEDGER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
