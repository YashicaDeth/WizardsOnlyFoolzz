extends Node

## Route 3 after the v0.1 examiner fight, played through the real scenes in one
## world: take his dropped keycard, open the staff door, then preserve the
## chase handoffs through the Support Unit, Hollis's gate, the now-empty
## vehicle bay, the ramp and the surface. ExaminerKeycardTest owns the detailed
## fight/card/door assertions; this suite does not duplicate them.

const VAT := preload("res://vat_chamber.tscn")
const UNIT := preload("res://support_unit.tscn")
const BAY := preload("res://doctor_vehicle_bay.tscn")

var failures: Array[String] = []
var checks_run := 0
## Every check below must actually run: a runtime error inside a scene step
## would otherwise skip the rest of that step and still report zero failures.
const EXPECTED_CHECKS := 9


func check(condition: bool, label: String) -> void:
	checks_run += 1
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	await _keycard_to_chase()
	await _support_unit()
	await _vehicle_bay()
	check(checks_run == EXPECTED_CHECKS, "every step ran to the end (%d of %d checks)" % [checks_run, EXPECTED_CHECKS])
	print("DOCTOR_CHASE_ROUTE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _place(vat, at: Vector3, look_at_point: Vector3) -> void:
	vat.player.global_position = Vector3(at.x, vat.BODY_HALF_HEIGHT + 0.02, at.z)
	vat.player.velocity = Vector3.ZERO
	var to := look_at_point - at
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = 0.0
	vat.player.rotation.y = vat.yaw
	vat.camera.rotation = Vector3.ZERO


func _press(vat, action: String) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E if action == "interact" else KEY_NONE
	event.physical_keycode = event.keycode
	event.pressed = true
	vat._unhandled_input(event)


func _keycard_to_chase() -> void:
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	# His door only gives once you are dressed (Greg's playtest gate).
	preload("res://systems/clothing.gd").wear("player", "scavenged_coat")
	WorldHistory.amend_subject(FacilityRoutes.SUBJECT, {"completed_routes": [FacilityRoutes.ROUTE_HEAT_ELEVATOR]})  # a returning run: side exits open
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	await get_tree().physics_frame
	var route: DoctorRoute = vat.doctor_route
	var fight: ExaminerFight = route.fight
	# The examiner suite owns the fight and the individual card/door assertions.
	# This route suite uses the same real interaction path as its _place/_press
	# helpers, then concentrates on the chase handoffs that follow.
	fight._win()
	var card_at: Vector3 = fight.keycard_pickup.global_position if fight.keycard_on_floor() else vat.player.global_position
	_place(vat, card_at + Vector3(0, 0, 0.8), card_at)
	await get_tree().physics_frame
	_press(vat, "interact")
	_place(vat, vat.STAFF_DOOR_AT + Vector3(-1.2, 0, 0), vat.STAFF_DOOR_AT)
	_press(vat, "interact")

	# The detailed room/lift mechanics remain covered by doctor_route_test.
	# Seed only the route boundary needed to exercise the still-current chase.
	route._take_axe()
	var began := FacilityRoutes.begin(FacilityRoutes.ROUTE_DOCTOR)
	var filed_room := FacilityRoutes.traverse("examination_room")
	check(began and filed_room and (FacilityRoutes.ensure().get("route_steps", []) as Array) == ["examination_room"], "the doctor pursuit is filed through his examination room")
	vat.queue_free()
	await get_tree().process_frame


func _support_unit() -> void:
	var unit = UNIT.instantiate()
	add_child(unit)
	unit.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check((FacilityRoutes.ensure().get("route_steps", []) as Array) == ["examination_room", "support_unit"], "the hallways are filed next")
	check(unit.holding_ram, "you arrive holding something to meet Hollis with")
	var post: FacilityGuardPost = unit.guard_post
	var hollis_at: Vector3 = post.guard.global_position
	unit.player.global_position = hollis_at + Vector3(0, 1.0, 1.6)
	var to: Vector3 = hollis_at - unit.player.global_position
	unit.yaw = atan2(-to.x, -to.z)
	unit.player.rotation.y = unit.yaw
	var said: String = unit.interact()
	check(post.door_open, "Hollis's gate opens (%s)" % said)
	unit.player.global_position = Vector3(0, 1.0, unit.GATE_Z - 2.0)
	unit._check_gate()
	unit.player.global_position = unit.EXIT_AT + Vector3(0, 1.0, 1.0)
	check(unit.interact() == "exit" and unit.exit_message.is_empty(), "and the way down to the vehicle bay is taken")
	unit.queue_free()
	await get_tree().process_frame


func _vehicle_bay() -> void:
	var bay = BAY.instantiate()
	add_child(bay)
	await get_tree().physics_frame
	check(bay.empty_bay and bay.state == "after", "after the examiner's defeat his vehicle bay is empty")
	check(bay.ramp_open, "the empty bay's ramp is open")
	bay.player.global_position = Vector3(0, bay.RAMP_RISE + 0.9, bay.RAMP_TOP_Z + 0.5)
	bay.step(0.05)
	var handoff := FacilityRoutes.pending_surface_handoff()
	check(str(handoff.get("route_id", "")) == FacilityRoutes.ROUTE_DOCTOR, "the whole chase completes the doctor pursuit and hands the surface its arrival")
	check(OpeningDirector.reached("left_facility"), "the run is out of the facility")
	bay.queue_free()
	await get_tree().process_frame
