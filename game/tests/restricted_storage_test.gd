extends Node

const RESTRICTED_STORAGE := preload("res://systems/restricted_storage.gd")
const FACILITY := preload("res://systems/facility_territory.gd")
const HANDHELD := preload("res://systems/handheld_device.gd")
const ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

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

	check(not RESTRICTED_STORAGE.is_breached(), "a fresh storage room has not been breached")
	check(not bool(WorldHistory.subject(HANDHELD.DEVICE_ID).get("possessed", true)),
		"AX3.5: a prototype nobody has stolen yet starts unpossessed, not issued for free")

	var receipt_before := ACTION_LEDGER.count("black_mirror_stolen")
	var result := RESTRICTED_STORAGE.take_prototype({"location": "growing_floor"})
	check(bool(result.get("ok", false)), "the one action the room offers succeeds the first time")
	check(RESTRICTED_STORAGE.is_breached(), "taking the prototype marks the room breached")
	check(bool(WorldHistory.subject(HANDHELD.DEVICE_ID).get("possessed", false)),
		"taking the prototype hands the player the Black Mirror")
	check(ACTION_LEDGER.count("black_mirror_stolen") == receipt_before + 1, "the theft writes one routed receipt")
	check(str(WorldHistory.subject(FACILITY.REACTION_SUBJECT).get("status", "")) == "circulating",
		"CellOutz posts a repossession order the moment the prototype goes missing")
	check(WorldHistory.event_count("celloutz_repossession_order_posted") == 1,
		"the theft raises exactly one corporate reaction")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "the theft, the device flip and the reaction close one transaction")

	var second := RESTRICTED_STORAGE.take_prototype()
	check(not bool(second.get("ok", true)), "an already-empty case cannot be stolen from twice")
	check(ACTION_LEDGER.count("black_mirror_stolen") == receipt_before + 1, "a repeat attempt writes no second receipt")

	FACILITY.apply_event("derby_round_won")
	check(WorldHistory.event_count("celloutz_repossession_order_posted") == 1,
		"a later derby win cannot duplicate the reaction the theft already raised")

	print("RESTRICTED_STORAGE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
