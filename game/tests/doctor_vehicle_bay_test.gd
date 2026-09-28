extends Node

## The third way out (Greg, 24 September, DESIGN/ESCAPE_ROUTES.md): the doctor
## by his vehicle is a hologram. Hitting, questioning or shooting him reveals
## it, he calls (the lift, the roof, the helicopter), the player learns where
## he went, gets the task and can pry out the call emitter, and the bay's ramp
## completes FacilityRoutes' doctor pursuit into the Hunt.

const BAY := preload("res://doctor_vehicle_bay.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _fresh_world() -> void:
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "loose", "anatomy": {"cybernetics": []}})
	WorldHistory.register_subject("inventory", {"kind": "inventory", "items": []})


func _place(bay, at: Vector3) -> void:
	bay.player.global_position = at + Vector3(0, 0.9, 0)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await _struck_route()
	await _questioned()
	await _shot()
	print("DOCTOR_VEHICLE_BAY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _struck_route() -> void:
	_fresh_world()
	DoctorExamination.begin_departure()
	var bay = BAY.instantiate()
	add_child(bay)
	await get_tree().physics_frame
	var record := FacilityRoutes.ensure()
	check(str(record.get("active_route", "")) == FacilityRoutes.ROUTE_DOCTOR, "arriving in the bay is the doctor pursuit")
	check((record.get("route_steps", []) as Array) == ["examination_room", "support_unit"], "the approach through his room and the support unit is filed")
	var head := bay.doctor_rig.parts.get("head") as MeshInstance3D
	check(head != null and head.material_override != bay.hologram_material, "he stands there looking like a man")
	check(bay.doctor_rig.find_children("*", "GeometryInstance3D", true, false).size() > 10, "he is a whole dressed BaselineHuman")

	_place(bay, Vector3(0, 0, 8))
	bay.attack()
	check(bay.state == "real", "swinging from across the bay without a gun does nothing")
	bay._update_hud()
	check(bay.prompt.text.contains("BY HIS CAR"), "far off, the prompt says where he is (%s)" % bay.prompt.text)
	check(not bay.surface(), "the ramp cannot be taken before the call")

	_place(bay, bay.DOCTOR_AT + Vector3(0, 0, 1.5))
	bay._update_hud()
	check(bay.prompt.text.contains("HIT HIM"), "up close the prompt offers the blow (%s)" % bay.prompt.text)
	bay.attack()
	check(bay.state == "reveal" and bay.revealed_by == "struck", "the blow goes through him")
	check(head.material_override == bay.hologram_material, "his head turns to hologram light")
	var shirt_ok := true
	for node in bay.doctor_rig.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).material_override != bay.hologram_material:
			shirt_ok = false
	check(shirt_ok, "all of him, coat included, is hologram light")
	check(bay.screen_split.visible and bay.beam.visible, "the screen splits and the emitter's beam shows")
	check(WorldHistory.event_count("doctor_hologram_revealed") == 1, "the reveal is recorded")
	var doctor := WorldHistory.subject(DoctorExamination.FATE_SUBJECT)
	check(bool(doctor.get("seen_as_hologram", false)) and str(doctor.get("kind", "")) == "person", "the doctor's record says he was a hologram")
	check(DoctorExamination.was_caught(), "reaching him inside the window counts as catching up")
	check(not DoctorExamination.was_killed(), "hitting light kills nobody")

	bay.step(bay.REVEAL_SECONDS + 0.05)
	check(bay.state == "call" and bay.holo_call.playing, "then the 3D call pops up")
	check(WorldHistory.event_count("hologram_call_shown") == 1, "the call is recorded")
	var call: HologramCall = bay.holo_call
	check(not call.using_video, "with no TouchDesigner file the in-engine miniature plays")
	check(call.phase_at(3.0) == "shaft" and call.phase_at(7.5) == "roof" and call.phase_at(13.0) == "airborne", "lift, roof, helicopter, in that order")
	call.seek(3.0)
	var car_mid: float = call.car.position.y
	call.seek(5.9)
	check(call.car.position.y > car_mid and car_mid > 0.0, "the lift car climbs the shaft")
	call.seek(8.0)
	check(call.figure.position.y >= call.SHAFT_TOP, "he steps out on the roof")
	call.seek(14.5)
	check(call.helicopter.position.y > call.PAD_AT.y + 2.0 and not call.figure.visible, "the helicopter lifts off with him aboard")
	check(not call.line_at(2.0).is_empty(), "his lines run as subtitles")
	check(not bay.ramp_open, "the ramp stays shut while he talks")
	call.skip()
	check(bay.state == "after" and bay.ramp_open, "after the call the ramp opens")
	doctor = WorldHistory.subject(DoctorExamination.FATE_SUBJECT)
	check(str(doctor.get("left_by", "")) == "helicopter" and str(doctor.get("left_from", "")) == "roof", "the world now knows he left from the roof by helicopter")
	var task := WorldHistory.subject(bay.TASK_ID)
	check(str(task.get("objective", "")) == "FOLLOW THE DOCTOR // THE ROOF" and str(task.get("status", "")) == "open", "the task goal is given")
	check(WorldHistory.event_count("mission_card_shown") == 1, "and flashes as a mission card")
	bay._update_hud()
	check(bay.objective.text.contains("THE ROOF"), "the objective line reads the task")

	check(not Calling.unlocked(), "calling is locked before the emitter is taken")
	_place(bay, bay.EMITTER_AT + Vector3(0, 0, 1.0))
	bay.interact()
	check(bay.emitter_taken and Calling.unlocked(), "prying out the emitter installs the call implant")
	var contacts := Calling.contacts()
	check(contacts.any(func(row): return str(row.id) == DoctorExamination.FATE_SUBJECT), "the doctor is a contact now")
	bay.toggle_contacts()
	var reply: Dictionary = bay.call_contact(0)
	check(bool(reply.get("ok", false)) and str(reply.get("outcome", "")) == Calling.REFUSED, "calling him back gets refused")

	_place(bay, Vector3(0, bay.RAMP_RISE, bay.RAMP_TOP_Z + 0.5))
	bay.step(0.05)
	check(bay.state == "surfaced" and bay.surface_requested, "walking up the ramp leaves the facility")
	var handoff := FacilityRoutes.pending_surface_handoff()
	check(str(handoff.get("route_id", "")) == FacilityRoutes.ROUTE_DOCTOR and str(handoff.get("exit_id", "")) == "doctor_vehicle_bay", "the route graph hands the Hunt the vehicle bay")
	var arrival: Array = handoff.get("surface_position", [])
	var here := Vector3(float(arrival[0]), float(arrival[1]), float(arrival[2])) if arrival.size() == 3 else Vector3.ZERO
	var apart := arrival.size() == 3
	for other in [FacilityRoutes.ROUTE_STEALTH, FacilityRoutes.ROUTE_HEAT_ELEVATOR, FacilityRoutes.ROUTE_ASSAULT]:
		if here.distance_to(FacilityRoutes.route(other).surface_position) < 15.0:
			apart = false
	check(apart, "it surfaces somewhere none of the other exits do")
	check(OpeningDirector.reached("left_facility") and str(WorldHistory.subject("player").get("left_facility_by", "")) == "doctor_vehicle_bay", "the world records leaving by the doctor's ramp")
	bay.queue_free()
	await get_tree().process_frame


func _questioned() -> void:
	_fresh_world()
	var bay = BAY.instantiate()
	add_child(bay)
	await get_tree().physics_frame
	_place(bay, bay.DOCTOR_AT + Vector3(0, 0, 3.0))
	bay.interact()
	check(bay.state == "questioning", "E near him questions him")
	bay._update_hud()
	check(bay.speech.text.contains("long way"), "he answers like a man (%s)" % bay.speech.text)
	bay.step(3.3)
	bay.step(3.3)
	check(bay.state == "reveal" and bay.revealed_by == "questioned", "questioning him long enough gives him away")
	check(not DoctorExamination.was_caught(), "with no departure window open, nothing says he was caught")
	bay.queue_free()
	await get_tree().process_frame


func _shot() -> void:
	_fresh_world()
	WorldHistory.amend_subject("inventory", {"items": [{"label": "CELL OUTZ BREACH NINE", "kind": "weapon"}]})
	var bay = BAY.instantiate()
	add_child(bay)
	await get_tree().physics_frame
	_place(bay, bay.DOCTOR_AT + Vector3(0, 0, 6.0))
	bay.attack()
	check(bay.state == "reveal" and bay.revealed_by == "shot", "Hollis's gun from across the bay: the round goes through him")
	bay.queue_free()
	await get_tree().process_frame
