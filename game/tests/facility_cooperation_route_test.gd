extends Node

const ROUTES := preload("res://systems/facility_routes.gd")
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func travel_to_compact() -> void:
	check(ROUTES.begin(ROUTES.ROUTE_COOPERATION), "the undercroft compact can be selected")
	check(ROUTES.traverse("ossuary_exchange"), "the route enters the catacombs")
	check(ROUTES.traverse("undercroft_settlement"), "the catacombs reach an underground settlement")
	check(not ROUTES.traverse("lantern_lift"), "no faction outcome is silently chosen for the player")


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	travel_to_compact()
	check(ROUTES.choose_cooperation_outcome("honour"), "the settlement compact can be honoured")
	check(ROUTES.traverse("lantern_lift"), "cooperation opens the Lantern freight lift")
	var allied := ROUTES.consume_surface_handoff()
	check(allied.surface_position == [-8.0, 0.0, 26.0], "the honoured compact reaches the Lantern waystation")
	check(int(WorldHistory.subject("undercroft_freehold").get("standing", 0)) == 10, "the freehold remembers cooperation")

	WorldHistory.clear_history()
	travel_to_compact()
	check(ROUTES.choose_cooperation_outcome("betray"), "cooperation may be followed by betrayal")
	check(not ROUTES.traverse("lantern_lift"), "betrayal cannot use the allies' lift")
	check(ROUTES.traverse("stolen_freight_spur"), "betrayal escapes aboard the stolen freight spur")
	var betrayed := ROUTES.consume_surface_handoff()
	check(betrayed.surface_position == [18.0, 0.0, 20.0], "betrayal reaches a different surface position")
	check(int(WorldHistory.subject("undercroft_freehold").get("standing", 0)) == -20, "the freehold remembers the betrayal")
	check(int(WorldHistory.subject("ashline_wreckers").get("standing", 0)) == 8, "the theft creates an Ashline relationship")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "choice and arrival transactions close")
	print("FACILITY_COOPERATION_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
