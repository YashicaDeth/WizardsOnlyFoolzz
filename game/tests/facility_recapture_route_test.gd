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
	check(not ROUTES.begin(ROUTES.ROUTE_RECAPTURE), "the derby cannot be selected as an arbitrary route")
	check(ROUTES.begin(ROUTES.ROUTE_STEALTH), "a player may first attempt the mastery route")
	check(not ROUTES.apply_recapture("plot_needs_derby", true), "an unauthored plot recapture is rejected")
	check(not ROUTES.apply_recapture("implant_suppression_lattice", false), "an unseen containment device cannot capture by assertion")
	check(ROUTES.apply_recapture("implant_suppression_lattice", true), "a demonstrated suppression lattice can recapture the player")
	var capture_events := WorldHistory.events.filter(func(event: Dictionary): return str(event.get("type", "")) == "facility_player_recaptured")
	check(capture_events.size() == 1, "recapture is preserved in the shared ledger")
	var capture_details: Dictionary = capture_events[0].get("details", {})
	check(str(capture_details.get("destination", "")) == "res://underground_colosseum.tscn", "recapture reaches the canonical underground derby")
	check(str(capture_details.get("interrupted_route", "")) == ROUTES.ROUTE_STEALTH, "the interrupted escape remains remembered")
	check(ROUTES.traverse("underground_colosseum"), "the processing chute physically reaches the derby")
	check(not ROUTES.traverse("lockdown_grid"), "merely entering the derby does not award its exit")
	check(ROUTES.earn_derby_exit("won the heat and disabled the three lockdown relays"), "played derby victory earns the sallyport route")
	check(ROUTES.traverse("lockdown_grid"), "the won derby opens into the existing Lockdown Grid")
	check(ROUTES.traverse("vehicle_sallyport"), "the winning vehicle can breach the sallyport")
	var handoff := ROUTES.pending_surface_handoff()
	check(not bool(handoff.get("avoided_derby", true)), "the recapture route truthfully records the derby")
	check(handoff.surface_position == [4.0, 0.0, -24.0], "the vehicle breach reaches the southern wreck road")
	check(not ROUTES.apply_recapture("anesthetic_flood", true), "an established successful escape cannot be undone by recapture")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "recapture and victory transactions close")
	print("FACILITY_RECAPTURE_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
