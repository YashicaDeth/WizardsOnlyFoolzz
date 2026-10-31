extends Node

## The arrival reveal (systems/exit_reveal.gd): from a consumed facility
## handoff, the camera starts on the exact exit point, rises, passes the
## nearest settlements and marks each on the map (AshbloomHoldings) as it
## passes, then hands the host its camera and its world back. Two exits reveal
## different places; a skip still marks them; WorldHistory records it; and the
## Hunt plays it on arrival.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _reveal_events() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "exit_reveal_seen":
			found.append(event)
	return found


func _surface(route_id: String, steps: Array) -> Dictionary:
	FacilityRoutes.begin(route_id)
	for district in steps:
		FacilityRoutes.traverse(str(district))
	return FacilityRoutes.consume_surface_handoff()


## Plays one reveal to the end against a stand-in host and returns the order
## in which settlements were marked, with the clock at each.
func _play_through(label: String, handoff: Dictionary) -> Array:
	var host := Node3D.new()
	add_child(host)
	var host_camera := Camera3D.new()
	host.add_child(host_camera)
	host_camera.make_current()
	var reveal := ExitReveal.attach(host, handoff, host_camera)
	check(reveal != null and reveal.active, "%s: a consumed handoff starts a reveal" % label)
	await get_tree().physics_frame
	await get_tree().process_frame
	check(get_tree().paused, "%s: the world is held while it plays" % label)
	check(get_viewport().get_camera_3d() == reveal.cam, "%s: the reveal's camera has the screen" % label)
	var at: Array = handoff.surface_position
	var exit_point := Vector3(float(at[0]), 0.0, float(at[2]))
	var start_flat := Vector2(reveal.cam.global_position.x - exit_point.x, reveal.cam.global_position.z - exit_point.z).length()
	check(start_flat <= Vector2(ExitReveal.SHOULDER_BACK, ExitReveal.SHOULDER_SIDE).length() + 0.01 and absf(reveal.cam.global_position.y - (ExitReveal.EYE + ExitReveal.SHOULDER_UP)) < 0.01, "%s: it starts over the shoulder, on the exact spot the player came out of" % label)
	check(reveal.duration >= 8.0 and reveal.duration <= 12.5, "%s: it runs 8-12 seconds (%.1f)" % [label, reveal.duration])
	var marks: Array = []
	var highest := 0.0
	var steps := 0
	while reveal.active and steps < 400:
		reveal.advance(0.1)
		steps += 1
		if reveal.cam != null:
			highest = maxf(highest, reveal.cam.global_position.y)
		for row in reveal.settlements:
			if bool(row.marked) and not marks.any(func(m: Array) -> bool: return m[0] == row.id):
				marks.append([row.id, reveal.clock])
	check(highest > 100.0, "%s: the camera rises high over the overworld (%.0f m)" % [label, highest])
	check(not marks.is_empty() and marks.size() == reveal.settlements.size(), "%s: every nearby settlement is marked (%s)" % [label, str(marks)])
	var in_flight := true
	for mark: Array in marks:
		in_flight = in_flight and float(mark[1]) < reveal.duration - ExitReveal.PULL_UP
	check(in_flight, "%s: each is marked as the camera passes it, not at the end" % label)
	for row in reveal.settlements:
		check(bool(AshbloomHoldings.holding(str(row.id)).get("revealed", false)), "%s: %s is revealed on the map" % [label, str(row.name)])
	check(not get_tree().paused, "%s: the world runs again afterwards" % label)
	check(get_viewport().get_camera_3d() == host_camera, "%s: and the host has its camera back" % label)
	host.queue_free()
	return marks


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	WorldHistory.clear_history()
	check(ExitReveal.attach(self, {}, null) == null, "no handoff, no reveal")

	var outfall := _surface(FacilityRoutes.ROUTE_STEALTH, ["waste_gallery", "maintenance_cistern", "storm_outfall"])
	var outfall_marks := await _play_through("storm outfall", outfall)
	await get_tree().process_frame
	WorldHistory.clear_history()
	var lift := _surface(FacilityRoutes.ROUTE_HEAT_ELEVATOR, ["heat_elevator"])
	var lift_marks := await _play_through("heat elevator", lift)
	await get_tree().process_frame
	check(not outfall_marks.is_empty() and not lift_marks.is_empty() and outfall_marks[0][0] != lift_marks[0][0],
		"the two exits reveal different places first (%s, %s)" % [str(outfall_marks), str(lift_marks)])
	var seen := _reveal_events()
	check(seen.size() == 1 and str(seen[0].details.get("exit_id", "")) == "heat_elevator"
		and (seen[0].details.get("settlements_marked", []) as Array).size() == lift_marks.size()
		and not bool(seen[0].details.get("skipped", true)), "WorldHistory records the reveal and the settlements it marked")

	# Skipped: any key after the first half second ends it, and the places
	# are still marked, because the player came out there either way.
	WorldHistory.clear_history()
	var shaft := _surface(FacilityRoutes.ROUTE_ASSAULT, [])
	if shaft.is_empty():
		# The assault needs control points; fake the handoff the way it would read.
		shaft = {"route_id": FacilityRoutes.ROUTE_ASSAULT, "exit_id": "blast_shaft", "surface_position": [30.0, 0.0, -14.0]}
	var host := Node3D.new()
	add_child(host)
	var host_camera := Camera3D.new()
	host.add_child(host_camera)
	host_camera.make_current()
	var reveal := ExitReveal.attach(host, shaft, host_camera)
	await get_tree().physics_frame
	await get_tree().process_frame
	var early := InputEventKey.new()
	early.keycode = KEY_SPACE
	early.pressed = true
	get_viewport().push_input(early)
	check(reveal.active, "a key in the first half second does not skip (it is the one that brought you here)")
	reveal.advance(1.0)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	get_viewport().push_input(key)
	check(not reveal.active and reveal.skipped, "any key after that skips")
	var all_marked := true
	for row in reveal.settlements:
		all_marked = all_marked and bool(AshbloomHoldings.holding(str(row.id)).get("revealed", false))
	check(all_marked, "a skipped reveal still marks its settlements")
	var skipped := _reveal_events()
	check(skipped.size() == 1 and bool(skipped[0].details.get("skipped", false)), "and the record says it was skipped")
	check(not get_tree().paused and get_viewport().get_camera_3d() == host_camera, "skipping hands everything back")
	host.queue_free()
	await get_tree().process_frame

	# In the Hunt: arriving with a pending handoff plays the reveal.
	WorldHistory.clear_history()
	FacilityRoutes.begin(FacilityRoutes.ROUTE_STEALTH)
	for district in ["waste_gallery", "maintenance_cistern", "storm_outfall"]:
		FacilityRoutes.traverse(district)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var in_hunt: ExitReveal = hunt.exit_reveal
	check(in_hunt != null and in_hunt.active and get_tree().paused, "the Hunt plays the reveal when a route surfaces into it, holding the world")
	check(in_hunt != null and in_hunt.exit_at.distance_to(Vector3(-26.0, 0.0, 12.0)) < 0.01, "from the storm outfall's own arrival point")
	if in_hunt != null:
		in_hunt.finish(true)
	check(not get_tree().paused and get_viewport().get_camera_3d() == hunt.camera, "and hands the Hunt its camera and world back")
	hunt.queue_free()
	await get_tree().process_frame
	# Without a handoff (a resumed save), there is nothing to reveal.
	var resumed = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(resumed)
	await get_tree().process_frame
	check(resumed.exit_reveal == null and not get_tree().paused, "a Hunt entered without a handoff plays nothing")
	resumed.queue_free()
	await get_tree().process_frame

	print("EXIT_REVEAL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
