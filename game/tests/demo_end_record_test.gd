extends Node

## The demo end card reads your run off the world record (Greg, 24 September;
## the checklist's B2 and V.7): how you got out and what you did.

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
	var lines: Array[String] = DemoWall.record_lines()
	check(lines[0] == "OUT BY  NOT YET OUT" and lines[1] == "DIED  0", "a fresh world has nothing on the card yet")
	FacilityRoutes.ensure()
	WorldHistory.amend_subject(FacilityRoutes.SUBJECT, {"completed_routes": [FacilityRoutes.ROUTE_STEALTH]})
	WorldHistory.record_event("player_died", {})
	WorldHistory.record_event("player_died", {})
	WorldHistory.record_event("npc_killed", {})
	WorldHistory.record_event("bingyanga_released", {})
	WorldHistory.record_event("growing_floor_vat_smashed", {})
	WorldHistory.record_event("world_object_struck", {"broke": true})
	WorldHistory.record_event("world_object_struck", {"broke": false})
	WorldHistory.record_event("blood_move", {"move": "feint"})
	lines = DemoWall.record_lines()
	check(lines[0].begins_with("OUT BY") and not lines[0].ends_with("NOT YET OUT"), "the card names the route you took (%s)" % lines[0])
	check("DIED  2" in lines and "KILLED  1" in lines and "FREED  1" in lines, "deaths, kills and the freed, from the record")
	check("TANKS SMASHED  1" in lines and "THINGS BROKEN  1" in lines and "BLOOD MOVES  1" in lines, "tanks, breaks (only real breaks) and moves")
	print("DEMO_END_RECORD_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
