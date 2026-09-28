extends Node

## The derby tunnels (derby_tunnels.tscn): the gate in the arena goes up, the
## car is driven with the real move actions from the gate down the bores,
## through both halls and a barricade, to the drain mouth; the same car arrives
## at the dry falls and is driven out of the gorge; the route leaves a surface
## handoff for the Hunt. Then again on foot: out of the car at the gate and
## walked to the mouth.

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


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(action)


## Steer a car along a line of points through the actions the scene reads.
func _drive_step(car: RigidBody3D, line: Array[Vector3], progress: int) -> int:
	var at := car.global_position
	while progress < line.size() - 1 and Vector2(line[progress].x - at.x, line[progress].z - at.z).length() < 9.0:
		progress += 1
	var ahead := line[mini(progress + 1, line.size() - 1)]
	var forward := -car.global_transform.basis.z.slide(Vector3.UP).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var to := (ahead - at).slide(Vector3.UP)
	var error := atan2(to.dot(right), to.dot(forward))
	var steer := clampf(error * 2.4, -1.0, 1.0)
	var speed := absf(float(car.signed_speed))
	var throttle := 1.0
	if absf(error) > 0.45 and speed > 9.0:
		throttle = 0.0
	elif absf(error) > 0.3:
		throttle = 0.6
	Input.action_release("move_back")
	if throttle > 0.0:
		Input.action_press("move_forward", throttle)
	else:
		Input.action_release("move_forward")
	if steer > 0.02:
		Input.action_release("move_left")
		Input.action_press("move_right", steer)
	elif steer < -0.02:
		Input.action_release("move_right")
		Input.action_press("move_left", -steer)
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")
	return progress


func _press_e() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var tick := 1.0 / float(Engine.physics_ticks_per_second)

	var derby_source := FileAccess.get_file_as_string("res://rift_derby.gd")
	check(derby_source.contains("DERBY_EXIT_SCENE := \"res://derby_tunnels.tscn\""), "the derby's way out is the tunnel gate")

	# --- driving ---------------------------------------------------------------
	var tunnels = load("res://derby_tunnels.tscn").instantiate()
	add_child(tunnels)
	await get_tree().physics_frame
	check(str(FacilityRoutes.ensure().get("active_route", "")) == FacilityRoutes.ROUTE_DERBY_TUNNELS, "the tunnels begin the derby tunnels route")
	check(str(FacilityRoutes.ensure().get("current_district", "")) == "underground_colosseum", "from the colosseum, not the Growing Floor")
	check(_events("derby_tunnels_gate_opened").size() == 1, "the gate opening is recorded")
	check(tunnels.in_car(), "the player starts in the car")
	check(tunnels.drive_line.size() > 200, "the tunnels are long (%d m of centre line)" % int(tunnels.drive_line.size() * 3))
	check(tunnels.lamps.size() >= 20, "and lit along their length (%d lamps)" % tunnels.lamps.size())
	check(tunnels.breakables.size() >= 6, "with barricades to go through (%d)" % tunnels.breakables.size())
	# The gate is closed at first and goes up by itself.
	check(tunnels.gate.position.y < 1.0, "the gate starts down")
	for frame in int(3.0 / tick):
		await get_tree().physics_frame
	check(tunnels.gate.position.y > 6.0, "and goes up into the wall")

	var car: RigidBody3D = tunnels.car
	var line: Array[Vector3] = tunnels.drive_line
	var progress := 0
	var seconds := 0.0
	var lowest_progress_stall := 0.0
	var last_progress := 0
	var resets := 0
	while seconds < 150.0 and not tunnels.completed:
		progress = _drive_step(car, line, progress)
		await get_tree().physics_frame
		seconds += tick
		if progress == last_progress:
			lowest_progress_stall += tick
		else:
			lowest_progress_stall = 0.0
			last_progress = progress
		# Stuck against a kerb or nosed into a wall: press R, as a player would.
		if lowest_progress_stall > 3.0 and resets < 6:
			var r := InputEventKey.new()
			r.keycode = KEY_R
			r.pressed = true
			tunnels._unhandled_input(r)
			resets += 1
			lowest_progress_stall = 0.0
		if lowest_progress_stall > 12.0:
			break
	_release_all()
	print("drove %.1fs, top speed %.1f m/s, smashed %d, progress %d/%d, reset %d times, at %s" % [seconds, tunnels.top_speed, tunnels.smashed, progress, line.size(), resets, str(car.global_position)])
	var entered := _events("derby_tunnels_entered")
	check(entered.size() == 1 and str(entered[0].details.get("by", "")) == "driving", "driving through the gate is recorded as entering the tunnels")
	check(tunnels.completed and tunnels.completed_by == "driving", "drove from the gate to the drain mouth")
	check(tunnels.top_speed > 18.0, "at speed, not crawling (%.1f m/s)" % tunnels.top_speed)
	check(_events("derby_tunnels_car_reset").size() == resets, "each R reset is recorded (%d)" % resets)
	check(tunnels.smashed >= 1 and not _events("derby_tunnels_debris_smashed").is_empty(), "and went through at least one barricade (%d)" % tunnels.smashed)
	var left := _events("derby_tunnels_left")
	check(left.size() == 1 and str(left[0].details.get("by", "")) == "driving" and str(left[0].details.get("vehicle", "")) == str(car.name), "leaving the tunnels by car is recorded")
	var handoff := FacilityRoutes.pending_surface_handoff()
	check(str(handoff.get("route_id", "")) == FacilityRoutes.ROUTE_DERBY_TUNNELS and str(handoff.get("exit_id", "")) == "dry_falls", "the route completes at the dry falls with a surface handoff")
	check(tunnels.travel_requested and car.get_parent() == null, "and the car goes on with the player")
	tunnels.queue_free()
	await get_tree().process_frame

	# --- the same car at the falls --------------------------------------------
	var falls = load("res://blood_waterfall_exit.tscn").instantiate()
	add_child(falls)
	await get_tree().physics_frame
	check(falls.vehicle == car and car.get_parent() == falls, "the car arrives at the falls in the culvert")
	check(falls.in_car() and falls.driver != null and falls.driver.driving, "with the player driving it")
	var reached := _events("blood_waterfall_reached")
	check(reached.size() == 1 and str(reached[0].details.get("route_id", "")) == FacilityRoutes.ROUTE_DERBY_TUNNELS, "the falls know which route brought the player")
	var falls_line: Array[Vector3] = [
		Vector3(0.0, 0.0, 2.0), Vector3(0.0, 0.0, -1.5), Vector3(6.0, 0.0, -3.0), Vector3(12.0, 0.0, -4.5),
		Vector3(13.0, 0.0, -9.0), Vector3(13.0, -8.0, -35.0), Vector3(13.0, 0.0, -64.0), Vector3(12.0, 0.0, -100.0),
		Vector3(10.0, 0.0, -125.0), falls.EXIT_AT,
	]
	var falls_progress := 0
	var falls_seconds := 0.0
	var lowest := 100.0
	while falls_seconds < 60.0 and not falls.completed:
		falls_progress = _drive_step(car, falls_line, falls_progress)
		# The lip is a twenty metre drop: take the turn onto the track slowly.
		if car.global_position.z > -10.0 and absf(float(car.signed_speed)) > 5.0:
			Input.action_release("move_forward")
		await get_tree().physics_frame
		falls_seconds += tick
		lowest = minf(lowest, car.global_position.y)
	_release_all()
	print("falls drive %.1fs, ended at %s, waypoint %d" % [falls_seconds, str(car.global_position), falls_progress])
	check(falls.completed and falls.completed_by == "driving", "drove the car down the track and out of the gorge")
	check(lowest > falls.FLOOR_Y - 3.0, "on the track, not off the lip (lowest %.1f)" % lowest)
	var falls_left := _events("blood_waterfall_left")
	check(falls_left.size() == 1 and str(falls_left[0].details.get("vehicle", "")) == str(car.name), "leaving the falls names the car")
	# What the Hunt does on arrival.
	var consumed := FacilityRoutes.consume_surface_handoff()
	check(str(consumed.get("route_id", "")) == FacilityRoutes.ROUTE_DERBY_TUNNELS and (consumed.get("surface_position", []) as Array).size() == 3, "the Hunt gets the route's arrival point")
	falls.queue_free()
	await get_tree().process_frame

	# --- on foot -----------------------------------------------------------------
	WorldHistory.clear_history()
	var walked = load("res://derby_tunnels.tscn").instantiate()
	add_child(walked)
	for frame in int(3.0 / tick):
		await get_tree().physics_frame
	await _press_e()
	await get_tree().physics_frame
	check(not walked.in_car() and not walked.player_collider.disabled, "E gets the player out of the car")
	check(_events("derby_tunnels_got_out").size() == 1, "getting out is recorded")
	var walk_line: Array[Vector3] = walked.drive_line
	var step := 0
	var walk_seconds := 0.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var skipped := false
	while walk_seconds < 240.0 and not walked.completed:
		# Walk through the gate, then skip the middle: 650 m on foot is two
		# minutes of physics, more than a test run should spend. The last
		# stretch into the mouth is walked again.
		if not skipped and not _events("derby_tunnels_entered").is_empty():
			skipped = true
			step = walk_line.size() - 10
			walked.player.global_position = walk_line[step] + Vector3.UP * 1.0
		var at: Vector3 = walked.player.global_position
		while step < walk_line.size() - 1 and Vector2(walk_line[step].x - at.x, walk_line[step].z - at.z).length() < 2.5:
			step += 1
		var to := walk_line[step] - at
		walked.yaw = atan2(-to.x, -to.z)
		await get_tree().physics_frame
		walk_seconds += tick
	_release_all()
	print("walked %.1fs to %s, step %d/%d" % [walk_seconds, str(walked.player.global_position), step, walk_line.size()])
	var walked_in := _events("derby_tunnels_entered")
	check(walked_in.size() == 1 and str(walked_in[0].details.get("by", "")) == "walking", "walking through the gate is recorded")
	check(walked.completed and walked.completed_by == "walking", "walked from the gate to the drain mouth")
	var walked_out := _events("derby_tunnels_left")
	check(walked_out.size() == 1 and str(walked_out[0].details.get("left_behind", "")) == str(walked.car.name), "the car is recorded as left behind")
	check(VehicleDriver.take_carried() == null, "and no car goes on to the falls")
	check(str(FacilityRoutes.pending_surface_handoff().get("route_id", "")) == FacilityRoutes.ROUTE_DERBY_TUNNELS, "the walk completes the route too")
	walked.queue_free()
	await get_tree().process_frame

	print("DERBY_TUNNELS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
