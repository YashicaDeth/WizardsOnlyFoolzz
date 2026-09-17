extends Node

const DERBY := preload("res://rift_derby.gd")
const CAST := preload("res://systems/cast_names.gd")
const FACILITY := preload("res://systems/facility_territory.gd")
const OPENING := preload("res://systems/opening_director.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	for choice: String in ["join", "escape", "fight"]:
		WorldHistory.clear_history()
		CAST.ensure(DERBY.RINGMASTER_SLOT, {"status": "waiting"})
		var derby := DERBY.new()
		check(derby._record_ringmaster_choice(choice), "%s is an authored ringmaster choice" % choice)
		var event_type := "ringmaster_%s" % ("challenged" if choice == "fight" else ("joined" if choice == "join" else "escaped"))
		check(WorldHistory.event_count(event_type) == 1 and PLAYER_ACTION_LEDGER.count(event_type) == 1,
			"%s produces one public event and one summarized player receipt" % choice)
		var choice_events := WorldHistory.events.filter(func(event: Dictionary) -> bool: return str(event.get("type", "")) == event_type)
		check(str(((choice_events[0] as Dictionary).get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"),
			"%s outcome carries its stable action identity" % choice)
		check(bool(FACILITY.sector("surface_gate").revealed) and OPENING.reached("left_facility"),
			"%s advances facility territory and the opening route through the same boundary" % choice)
		check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "%s closes the choice transaction" % choice)
		derby.free()
	var invalid_derby := DERBY.new()
	check(not invalid_derby._record_ringmaster_choice("invalid"), "an unauthored outcome cannot advance the route")
	invalid_derby.free()
	print("RINGMASTER_CHOICE_LEDGER_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
