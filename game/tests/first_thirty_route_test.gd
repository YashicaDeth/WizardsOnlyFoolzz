extends Node

## The first 30 minutes, end to end (/goal): the real scenes in order, driven
## through their own verbs, out by both routes Greg chose, and into the Hunt
## at each route's own arrival point.
##
##   vat: examination filed -> the examiner leaves -> the tank drains ->
##        END ALL SUFFERING, four wires torn out -> GET REVENGE -> breakout ->
##        the jammed tank pried, the dead subject's smock taken
##   Service Arcade: the ram and the card -> Hollis coerced, his hand on the
##        reader, his gun taken -> the pressure gate
##   Lower Works: then either the fuse and the heat elevator up, or the drain
##        hatch -> the old drains -> the storm outfall
##   Hunt: arrives where that route surfaces, with the handoff consumed.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _carries(label: String) -> bool:
	return VatRebirth.carries(label)


## Everything up to standing in the Lower Works, shared by both routes.
func _through_the_facility(route_name: String) -> Node:
	WorldHistory.clear_history()
	print("--- %s: the vat ---" % route_name)
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	check(vat.phase == "wired", "%s: the drained tank leaves you in the wires" % route_name)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	for step in 40:
		vat._physics_process(0.1)
	check(vat.breakout_complete and vat.can_move, "%s: GET REVENGE, the glass goes, and you stand" % route_name)
	vat.player.global_position = vat.stuck_tank_marker.global_position + Vector3(0, 0.9, 1.2)
	vat._interact()
	vat._interact()
	check(Clothing.worn("player") != "bare", "%s: the restraint pries the jammed tank and the smock comes off the dead" % route_name)
	vat._record_service_arcade_entry()
	vat.queue_free()
	await get_tree().process_frame

	print("--- %s: the Service Arcade ---" % route_name)
	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await get_tree().process_frame
	arcade.player.global_position = arcade.WEAPON_AT
	arcade._interact()
	arcade.player.global_position = arcade.CARD_AT
	arcade._interact()
	var post: FacilityGuardPost = arcade.guard_post
	arcade.player.global_position = post.guard.global_position + Vector3(0, 0, 1.6)
	arcade._interact()
	arcade._interact()
	check(post.door_open and _carries(FacilityGuardPost.GUN_LABEL), "%s: Hollis coerced, the D-section door open, his gun in Carry" % route_name)
	arcade.player.global_position = arcade.GATE_AT + Vector3(0, 0, 2.0)
	arcade._interact()
	arcade._interact()
	check(arcade.gate_open and arcade.lower_works_requested, "%s: the card opens the pressure gate onward" % route_name)
	arcade.queue_free()
	await get_tree().process_frame

	print("--- %s: the Lower Works ---" % route_name)
	var city = load("res://buried_city.tscn").instantiate()
	add_child(city)
	await get_tree().process_frame
	check(city.breach_tool_ready, "%s: the ram came down with you" % route_name)
	return city


func _into_the_hunt(route_name: String, expected_route: String) -> void:
	var handoff := FacilityRoutes.pending_surface_handoff()
	check(str(handoff.get("route_id", "")) == expected_route, "%s: the route graph holds this route's surface handoff" % route_name)
	var arrival: Array = handoff.get("surface_position", [])
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	# On the ground there, not at the exact authored height: the Hunt settles
	# the body onto its terrain (the drains' outfall sits 3.4 m up a bank) and
	# the sallyport's props nudge the elevator's arrival about a metre.
	var landed: Vector3 = hunt.player
	check(arrival.size() == 3 and Vector2(landed.x, landed.z).distance_to(Vector2(float(arrival[0]), float(arrival[2]))) < 2.5,
		"%s: the Hunt opens where this route surfaces (at %s, expected %s)" % [route_name, str(hunt.player), str(arrival)])
	check(FacilityRoutes.pending_surface_handoff().is_empty(), "%s: and the handoff is consumed, once" % route_name)
	check(OpeningDirector.reached("left_facility"), "%s: the opening run is out of the facility" % route_name)
	hunt.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var city = await _through_the_facility("heat elevator")
	city.player.global_position = city.FUSE_AT + Vector3(0, 0.1, 0)
	city._interact()
	city.player.global_position = city.LIFT_AT + Vector3(0, 0.9, 3.2)
	city._interact()
	check(city.lift_requested, "heat elevator: the fuse powers the lift and it carries you up")
	city.queue_free()
	await get_tree().process_frame
	await _into_the_hunt("heat elevator", FacilityRoutes.ROUTE_HEAT_ELEVATOR)
	var lift_arrival: Vector3 = FacilityRoutes.route(FacilityRoutes.ROUTE_HEAT_ELEVATOR).surface_position

	city = await _through_the_facility("old drains")
	city.player.global_position = city.DRAIN_AT + Vector3(0, 0.9, 1.0)
	city._interact()
	check(city.drains_requested, "old drains: the hatch drops you into the drains")
	city.queue_free()
	await get_tree().process_frame
	var drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	await get_tree().process_frame
	for at in [Vector3(0, 1.0, -6.0), Vector3(0, 1.0, drains.CISTERN_Z - 4.0), drains.EXIT_AT + Vector3(0, 0.9, 2.0)]:
		drains.player.global_position = at
		drains._physics_process(0.016)
	drains._interact()
	check(drains.surfaced, "old drains: gallery, cistern, and out through the storm outfall")
	drains.queue_free()
	await get_tree().process_frame
	await _into_the_hunt("old drains", FacilityRoutes.ROUTE_STEALTH)
	var drain_arrival: Vector3 = FacilityRoutes.route(FacilityRoutes.ROUTE_STEALTH).surface_position
	check(drain_arrival.distance_to(lift_arrival) > 20.0, "the two routes out surface in different parts of the map")

	print("FIRST_THIRTY_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
