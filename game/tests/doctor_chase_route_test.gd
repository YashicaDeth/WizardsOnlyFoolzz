extends Node

## Route 3, the doctor chase, played through the real scenes in one world:
## the vat -> his door -> his room -> the lift -> the Support Unit -> Hollis's
## gate -> the vehicle bay -> the hologram -> the ramp -> the surface handoff.
## Each scene has its own suite; this one proves they hand over to each other
## with what a player would actually be carrying.

const VAT := preload("res://vat_chamber.tscn")
const UNIT := preload("res://support_unit.tscn")
const BAY := preload("res://doctor_vehicle_bay.tscn")

var failures: Array[String] = []
var travelled := ""
var checks_run := 0
## Every check below must actually run: a runtime error inside a scene step
## would otherwise skip the rest of that step and still report zero failures.
const EXPECTED_CHECKS := 14


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
	await _vat_to_lift()
	await _support_unit()
	await _vehicle_bay()
	check(checks_run == EXPECTED_CHECKS, "every step ran to the end (%d of %d checks)" % [checks_run, EXPECTED_CHECKS])
	print("DOCTOR_CHASE_ROUTE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _vat_to_lift() -> void:
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
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	await get_tree().physics_frame
	check(vat.can_move, "out of the vat and standing")
	var route: DoctorRoute = vat.doctor_route
	# Break his door with what the breakout gave you.
	var blows := 0
	while not route.door.broken and blows < 80:
		vat._unhandled_input(InputEventMouseMotion.new())
		vat.player.global_position = Vector3(route.DOOR_AT.x, vat.BODY_HALF_HEIGHT + 0.02, route.WALL_Z - 1.3)
		vat.yaw = PI
		vat.pitch = -0.15
		vat.player.rotation.y = vat.yaw
		vat.camera.rotation = Vector3(vat.pitch, 0, 0)
		route.cooldown = 0.0
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		vat._unhandled_input(click)
		blows += 1
		await get_tree().physics_frame
	check(route.door.broken, "his door comes down (%d blows)" % blows)
	check(str(FacilityRoutes.ensure().get("active_route", "")) == FacilityRoutes.ROUTE_DOCTOR, "breaking it begins the doctor pursuit")
	# Walk in, then the lift.
	Input.action_press("move_forward")
	for _frame in int(3.0 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	check(route.room_entered, "into his room")
	vat.player.global_position = Vector3(route.CAR_AT.x, vat.BODY_HALF_HEIGHT + 0.02, route.ROOM_Z.y - 1.0)
	await get_tree().physics_frame
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.pressed = true
	vat._unhandled_input(e)
	for _frame in int((route.DOOR_SECONDS + 0.2) * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	vat.player.global_position = route.CAR_AT + Vector3(0, vat.BODY_HALF_HEIGHT + 0.02, 0.2)
	await get_tree().physics_frame
	route.travel_hook = func(path: String) -> void: travelled = path
	vat._unhandled_input(e)
	for _frame in int((route.DOOR_SECONDS + route.RIDE_SECONDS + 0.5) * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	check(travelled == "res://support_unit.tscn", "the lift carries you down to the Support Unit")
	check((FacilityRoutes.ensure().get("route_steps", []) as Array) == ["examination_room"], "his room is filed on the route")
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
	bay.player.global_position = bay.DOCTOR_AT + Vector3(0, 0.9, 1.5)
	bay.attack()
	check(bay.state == "reveal", "he is a hologram")
	bay.step(bay.REVEAL_SECONDS + 0.05)
	bay.holo_call.skip()
	check(bay.ramp_open, "after his call the ramp opens")
	bay.player.global_position = Vector3(0, bay.RAMP_RISE + 0.9, bay.RAMP_TOP_Z + 0.5)
	bay.step(0.05)
	var handoff := FacilityRoutes.pending_surface_handoff()
	check(str(handoff.get("route_id", "")) == FacilityRoutes.ROUTE_DOCTOR, "the whole chase completes the doctor pursuit and hands the surface its arrival")
	check(OpeningDirector.reached("left_facility"), "the run is out of the facility")
	bay.queue_free()
	await get_tree().process_frame
