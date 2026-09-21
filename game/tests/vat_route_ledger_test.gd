extends Node

const VAT := preload("res://vat_chamber.gd")
const OPENING := preload("res://systems/opening_director.gd")
const FACILITY := preload("res://systems/facility_territory.gd")
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
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"kind": "person", "status": "decanted"})
	var vat := VAT.new()
	check(vat._record_service_arcade_entry(), "the first door press enters the service arcade")
	check(OPENING.reached("entered_arcade") and str(WorldHistory.subject("player").get("status", "")) == "loose in the service arcade",
		"route progress and the player's physical status land together")
	var pit := FACILITY.sector("pit")
	var ring := FACILITY.sector("service_ring")
	check(not bool(pit.revealed) and not bool(ring.revealed), "the pit stays unrevealed until the player clears the arcade gate")
	var events := WorldHistory.events.filter(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "opening_entered_arcade")
	check(events.size() == 1 and PLAYER_ACTION_LEDGER.count("opening_entered_arcade") == 1 and str(((events[0] as Dictionary).get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"),
		"arcade entry has one public fact and one stable player receipt")
	check(not vat._record_service_arcade_entry() and WorldHistory.event_count("opening_entered_arcade") == 1,
		"a repeated input during travel cannot duplicate the entry")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0 and not bool(WorldHistory.get("_ledger_batch_dirty")),
		"the opening, territory, player and receipt transaction closes")
	vat.free()
	print("VAT_ROUTE_LEDGER_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
