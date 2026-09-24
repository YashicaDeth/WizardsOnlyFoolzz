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
	check(ROUTES.begin(ROUTES.ROUTE_ASSAULT), "the direct assault can be attempted")
	check(not ROUTES.traverse("containment_concourse"), "selecting assault does not award the first control point")
	check(not ROUTES.record_assault_breakthrough("concourse", ""), "an unexplained breakthrough is rejected")
	check(ROUTES.record_assault_breakthrough("concourse", "security response defeated in play"), "the played concourse breakthrough is recorded")
	check(ROUTES.traverse("containment_concourse"), "the player can occupy the cleared concourse")
	check(not ROUTES.record_assault_breakthrough("shaft", "barrier destroyed"), "assault control points cannot be skipped")
	check(ROUTES.record_assault_breakthrough("transit", "executive response defeated in play"), "the executive transit is earned")
	check(ROUTES.traverse("executive_transit"), "the executive transit connects to the concourse")
	check(ROUTES.record_assault_breakthrough("shaft", "blast barrier destroyed in play"), "the final barrier has a demonstrated cause")
	check(ROUTES.traverse("blast_shaft"), "the blast shaft completes the direct assault")
	var handoff := ROUTES.consume_surface_handoff()
	check(handoff.surface_position == [30.0, 0.0, -14.0], "direct assault reaches the exposed eastern ridge")
	check(int(WorldHistory.subject("celloutz").get("standing", 0)) == -30, "CellOutz remembers the executive breach")
	check(WorldHistory.event_count("facility_assault_breakthrough") == 3, "all three played breakthroughs remain in the shared ledger")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "assault transactions close")
	print("FACILITY_ASSAULT_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
