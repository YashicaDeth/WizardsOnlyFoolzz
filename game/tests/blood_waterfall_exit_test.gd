extends Node

## The dry falls (blood_waterfall_exit.tscn): the old drains send you here,
## the place has the blood, gore and broken trees Greg asked for, a player can
## actually walk from the drain mouth down the track and out, a car handed in
## completes it by driving, and the route's surface handoff survives the walk
## for the Hunt to consume.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _events(type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == type:
			found.append(event)
	return found


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	var drains_source := FileAccess.get_file_as_string("res://old_drains.gd")
	check(drains_source.contains("Interstitial.travel(\"res://blood_waterfall_exit.tscn\""), "the storm outfall's grate travels on to the dry falls")

	# The old drains' route, completed the way `old_drains.gd` files it.
	check(FacilityRoutes.begin(FacilityRoutes.ROUTE_STEALTH), "the maintenance ascent begins")
	for district in ["waste_gallery", "maintenance_cistern", "storm_outfall"]:
		FacilityRoutes.traverse(district)
	check(str(FacilityRoutes.pending_surface_handoff().get("route_id", "")) == FacilityRoutes.ROUTE_STEALTH, "the storm outfall leaves a surface handoff pending")

	var falls = load("res://blood_waterfall_exit.tscn").instantiate()
	add_child(falls)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(falls.tree_count >= 40, "the gorge is full of destroyed trees (%d)" % falls.tree_count)
	check(falls.gore_count >= 60, "and gore along the river and the lip (%d)" % falls.gore_count)
	check(falls.wet_rock_material.get_shader_parameter("channel_half_width") > 0.0, "blood still runs down the old watercourse on the falls face")
	check(falls.floor_height(falls.river_x(-90.0), -90.0) < falls.BLOOD_Y, "the river channel dips under the blood line, so the river shows")
	check(falls.floor_height(falls.PLUNGE_CENTRE.x, falls.PLUNGE_CENTRE.y) < falls.BLOOD_Y, "and so does the plunge pool under the falls")
	check(falls.floor_height(falls.EXIT_AT.x, falls.EXIT_AT.z) > falls.BLOOD_Y, "the way out is on dry ground")
	check(not _events("blood_waterfall_reached").is_empty(), "arriving at the falls is recorded")

	# Walk it: from the culvert, out onto the lip, right onto the track, down to
	# the gorge floor and along the river to the way out, using the scene's
	# own movement.
	var route: Array[Vector3] = [
		Vector3(0.0, 0.0, -2.0), Vector3(12.0, 0.0, -3.5), Vector3(13.0, 0.0, -9.0),
		Vector3(13.0, 0.0, -64.0), Vector3(12.0, 0.0, -100.0), falls.EXIT_AT,
	]
	var waypoint := 0
	var lowest := 100.0
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for frame in 60 * 60:
		if falls.completed:
			break
		var at: Vector3 = falls.player.global_position
		lowest = minf(lowest, at.y)
		var target: Vector3 = route[waypoint]
		var flat := Vector2(target.x - at.x, target.z - at.z)
		if flat.length() < 1.5 and waypoint < route.size() - 1:
			waypoint += 1
			continue
		falls.yaw = atan2(-flat.x, -flat.y)
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var ended_at: Vector3 = falls.player.global_position
	check(falls.completed and falls.completed_by == "walking", "walked from the drain mouth down the track and out (ended at %s, waypoint %d)" % [str(ended_at), waypoint])
	check(lowest < falls.FLOOR_Y + 2.0 and lowest > falls.FLOOR_Y - 3.0, "the walk went down onto the gorge floor, not through it (lowest %.1f)" % lowest)
	check(falls.travel_requested, "reaching the way out sends the player on to the overworld")
	var left := _events("blood_waterfall_left")
	check(left.size() == 1 and str(left[0].details.get("by", "")) == "walking", "leaving the falls on foot is recorded")
	check(str(FacilityRoutes.pending_surface_handoff().get("route_id", "")) == FacilityRoutes.ROUTE_STEALTH, "the route's handoff is still there for the Hunt to consume")
	falls.queue_free()
	await get_tree().process_frame

	# A car handed in drives out the same way.
	var driven = load("res://blood_waterfall_exit.tscn").instantiate()
	add_child(driven)
	var car := Node3D.new()
	car.name = "TestCar"
	driven.hand_in_vehicle(car)
	check(car.get_parent() == driven and car.global_position.z > 0.0, "a car handed in waits at the drain mouth")
	await get_tree().physics_frame
	check(not driven.completed, "and has not left yet")
	car.global_position = driven.EXIT_AT + Vector3(0.0, 1.0, 3.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(driven.completed and driven.completed_by == "driving", "driving it to the way out completes the falls")
	var driven_left := _events("blood_waterfall_left")
	check(driven_left.size() == 2 and str(driven_left[1].details.get("vehicle", "")) == "TestCar", "and the car is named in the record")
	driven.queue_free()
	await get_tree().process_frame

	print("BLOOD_WATERFALL_EXIT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
