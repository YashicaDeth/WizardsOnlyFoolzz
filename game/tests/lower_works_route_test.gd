extends Node

## The Lower Works is an actual opening beat, not a backdrop between two scene
## swaps.  Exercise its physical route directly so a changed interaction radius
## or a future scene refactor cannot leave the player holding the fuse in a
## room that has no usable exit.

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
	var city: Variant = load("res://buried_city.tscn").instantiate()
	add_child(city)
	await get_tree().physics_frame
	await get_tree().physics_frame

	check(not city.fuse_taken, "the lift begins unpowered")
	check(not city.shortcut_open, "and the safer west route begins sealed")
	check(not city.patrol_disabled, "with its sentinel relay live")

	city.player.global_position = city.FUSE_AT
	city._interact()
	check(city.fuse_taken, "the physical fuse can be collected")
	check(not city.fuse_visual.visible, "and disappears from its bracket")

	city.player.global_position = city.SHORTCUT_AT
	city._interact()
	check(city.shortcut_open, "the fuse powers the service shortcut")
	# Greg: "too dark". At 1.9 the frame measured 2.8/255 in Forward+; the
	# lamps that make the district read have to stay at the level measured.
	var bay_lamps: Array = city.get_children().filter(func(node): return node is OmniLight3D and str(node.name).begins_with("BayLamp"))
	check(bay_lamps.size() >= 11 and bay_lamps.all(func(lamp): return (lamp as OmniLight3D).light_energy >= 9.0), "every bay lamp is strong enough to light the floor it hangs over")
	check(city.patrol_disabled, "and disables the sentinel relay")
	check(city.shortcut_gate.is_queued_for_deletion(), "the shortcut collision gate is removed")
	city._physics_process(0.1)
	check(not city.patrol_alert, "a disabled sentinel cannot re-engage")

	# The optional arcade tool is the direct, riskier answer to the same
	# pressure beat.  Check it in a fresh district so the fuse has not already
	# switched the sentinel off.
	WorldHistory.record_event("service_arcade_breach_tool_taken", {"location": "service_arcade"})
	# Lower Works reads the tool from Carry now, so a death can take it away.
	var carry := Carry.new()
	carry.items.append({"label": "BREACH TOOL", "kind": "tool", "mass": 4.0, "perishes": false, "age": 0.0})
	carry.save_to_history()
	var combat_city: Variant = load("res://buried_city.tscn").instantiate()
	add_child(combat_city)
	await get_tree().physics_frame
	combat_city.player.global_position = combat_city.patrol.global_position + Vector3(0, 0, 5.0)
	combat_city._discharge_breach_tool()
	check(combat_city.breach_tool_ready, "the arcade breach tool carries into Lower Works")
	check(combat_city.patrol_disabled and combat_city.sentinel_disable_reason == "breach_interrupted", "the breach tool can interrupt the live sentinel at close range")
	check(WorldHistory.event_count("lower_works_sentinel_breached") == 1, "the direct encounter records its actual resolution")
	combat_city.queue_free()

	# The drain hatch: the second way out, down into the old drains.
	city.player.global_position = city.DRAIN_AT + Vector3(0, 0.9, 1.0)
	city._update_hud()
	check(city.prompt.text.contains("OLD DRAINS"), "the drain hatch offers the old drains (%s)" % city.prompt.text)
	city._interact()
	check(city.drains_requested and WorldHistory.event_count("lower_works_drain_entered") == 1, "dropping through the hatch is recorded and heads for the drains")

	# Greg, 24 September: the heat elevator goes up to the surface now; the
	# derby is shelved as an exit.
	city.player.global_position = city.LIFT_AT + Vector3(0, 0.9, 3.2)
	city._update_hud()
	check(city.prompt.text.contains("HEAT ELEVATOR UP"), "the elevator you can see offers the way up (%s)" % city.prompt.text)
	city._interact()
	check(city.lift_requested and OpeningDirector.reached("left_facility"), "riding it up leaves the facility")
	check(not OpeningDirector.reached("entered_pit") or OpeningDirector.stage() == "left_facility", "without being racked for the derby")
	var handoff := FacilityRoutes.pending_surface_handoff()
	check(str(handoff.get("route_id", "")) == FacilityRoutes.ROUTE_HEAT_ELEVATOR and str(handoff.get("exit_id", "")) == "heat_elevator", "the route graph hands the Hunt the heat elevator's arrival")
	check(str(OpeningDirector.resume_destination().scene) == "res://bone_yard_hunt.tscn", "a world that rode the lift resumes on the surface")
	check(WorldHistory.event_count("lower_works_heat_elevator_ascended") == 1, "and the ascent is one attributable exit event")

	print("LOWER_WORKS_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
