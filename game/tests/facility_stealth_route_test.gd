extends Node

const ROUTES := preload("res://systems/facility_routes.gd")
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
	check(ROUTES.begin(ROUTES.ROUTE_STEALTH), "maintenance ascent can be selected")
	check(not ROUTES.traverse("maintenance_cistern"), "exploration cannot skip the waste gallery")
	check(ROUTES.traverse("waste_gallery"), "waste gallery connects to the Growing Floor")
	check(ROUTES.traverse("maintenance_cistern"), "maintenance network is physically connected")
	check(ROUTES.pending_surface_handoff().is_empty(), "discovering the network does not pretend the player escaped")
	check(ROUTES.traverse("storm_outfall"), "storm outfall completes the mastery route")
	var handoff := ROUTES.pending_surface_handoff()
	check(bool(handoff.get("avoided_derby", false)), "the stealth route genuinely avoids the derby")
	check(handoff.get("surface_position", []) == [-26.0, 0.0, 12.0], "the outfall owns a distinct surface arrival")
	var consumed := ROUTES.consume_surface_handoff()
	check(not consumed.is_empty() and ROUTES.pending_surface_handoff().is_empty(), "surface handoff is consumed once")
	check(int(WorldHistory.subject("gate_lanterns").get("standing", 0)) == 4, "quiet arrival begins a Gate Lantern relationship")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "route actions close their ledger transactions")
	print("FACILITY_STEALTH_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
