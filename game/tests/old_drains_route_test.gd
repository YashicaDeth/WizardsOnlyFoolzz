extends Node

## The demo's second route out (Greg, 24 September): the old drains below the
## Lower Works, walked as FacilityRoutes' maintenance ascent and surfacing at
## the storm outfall, a different part of the map from the heat elevator.

const DRAINS := preload("res://old_drains.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _walk_to(drains, at: Vector3) -> void:
	drains.player.global_position = at + Vector3(0, 0.9, 0)
	drains._physics_process(0.016)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "loose"})
	var drains = DRAINS.instantiate()
	add_child(drains)
	await get_tree().physics_frame
	var record := FacilityRoutes.ensure()
	check(str(record.get("active_route", "")) == FacilityRoutes.ROUTE_STEALTH, "dropping in begins the maintenance ascent")
	check(WorldHistory.event_count("old_drains_entered") == 1, "and the entry is recorded")

	_walk_to(drains, Vector3(0, 0, -6))
	check((FacilityRoutes.ensure().get("route_steps", []) as Array) == ["waste_gallery"], "walking the gallery files the waste gallery")
	_walk_to(drains, Vector3(0, 0, drains.CISTERN_Z - 4.0))
	check((FacilityRoutes.ensure().get("route_steps", []) as Array) == ["waste_gallery", "maintenance_cistern"], "crossing the causeway files the cistern, in order")
	check(not OpeningDirector.reached("left_facility"), "walking up to the grate does not surface you by itself")

	drains.player.global_position = drains.EXIT_AT + Vector3(0, 0.9, 2.0)
	drains._update_hud()
	check(drains.prompt.text.contains("CLIMB OUT"), "at the grate the prompt offers the climb (%s)" % drains.prompt.text)
	drains._interact()
	check(drains.surfaced and drains.surface_requested, "forcing the grate climbs out")
	check(OpeningDirector.reached("left_facility") and str(WorldHistory.subject("player").get("left_facility_by", "")) == "old_drains", "the world records leaving the facility by the drains")
	var handoff := FacilityRoutes.pending_surface_handoff()
	var arrival: Array = handoff.get("surface_position", [])
	check(str(handoff.get("route_id", "")) == FacilityRoutes.ROUTE_STEALTH and str(handoff.get("exit_id", "")) == "storm_outfall", "the route graph hands the Hunt the storm outfall")
	var lift: Vector3 = FacilityRoutes.route(FacilityRoutes.ROUTE_HEAT_ELEVATOR).surface_position
	check(arrival.size() == 3 and Vector3(float(arrival[0]), float(arrival[1]), float(arrival[2])).distance_to(lift) > 20.0, "and it surfaces far from where the heat elevator does")
	check(str(OpeningDirector.resume_destination().scene) == "res://bone_yard_hunt.tscn", "a world that left by the drains resumes on the surface")
	drains.queue_free()

	print("OLD_DRAINS_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
