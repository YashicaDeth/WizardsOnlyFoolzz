extends Node

## Visual proof for the doctor's route: his door whole from the Growing Floor,
## the doorway after the axe with the pieces on the floor, his room, and the
## inside of the lift car on the way down.
## Run windowed: ... res://tests/doctor_route_capture.tscn -- --out=DIR

var vat: Node
var route: DoctorRoute


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	vat = load("res://vat_chamber.tscn").instantiate()
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
	for _step in 60:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	route = vat.doctor_route
	# Let the guided turn play: this is the frame control arrives on.
	for _frame in 170:
		await get_tree().physics_frame
	await _capture("%s/doctor_route_1_control_turns_to_door.png" % out_dir)

	await _look_from(Vector3(0.2, 0.0, 0.7), route.DOOR_AT + Vector3(-0.4, 1.3, 0))
	await _capture("%s/doctor_route_2_door_intact.png" % out_dir)

	# The axe, then the door.
	vat.player.global_position = Vector3(route.AXE_AT.x, vat.BODY_HALF_HEIGHT + 0.02, route.AXE_AT.z - 1.0)
	route._use()
	while not route.door.broken:
		await _look_from(Vector3(route.DOOR_AT.x, 0.0, route.WALL_Z - 1.3), route.DOOR_AT + Vector3(0, 1.1, 0))
		route.cooldown = 0.0
		route.strike("axe")
		for _frame in 8:
			await get_tree().physics_frame
	for _frame in 120:
		await get_tree().physics_frame
	await _look_from(Vector3(route.DOOR_AT.x - 0.5, 0.0, route.WALL_Z - 2.2), route.DOOR_AT + Vector3(0, 0.5, 1.0))
	await _capture("%s/doctor_route_3_door_broken.png" % out_dir)

	await _look_from(Vector3(1.4, 0.0, 8.4), Vector3(-1.4, 1.2, 4.3))
	await _capture("%s/doctor_route_4_exam_room.png" % out_dir)

	await _look_from(Vector3(route.CAR_AT.x, 0.0, route.ROOM_Z.y - 2.2), route.CAR_AT + Vector3(0, 1.2, 0))
	route._use()
	for _frame in 70:
		await get_tree().physics_frame
	await _capture("%s/doctor_route_5_lift_open.png" % out_dir)

	await _look_from(route.CAR_AT + Vector3(0, 0, 0.6), route.CAR_AT + Vector3(0, 1.5, -2.0))
	route._use()
	for _frame in int((route.DOOR_SECONDS + route.RIDE_SECONDS * 0.5) * 60.0):
		await get_tree().physics_frame
	await _capture("%s/doctor_route_6_inside_lift_riding.png" % out_dir)
	for _frame in int(route.RIDE_SECONDS * 0.6 * 60.0):
		await get_tree().physics_frame
	await _capture("%s/doctor_route_7_lift_arrived.png" % out_dir)
	get_tree().quit()


func _look_from(feet: Vector3, target: Vector3) -> void:
	vat._unhandled_input(InputEventMouseMotion.new())
	vat.player.global_position = Vector3(feet.x, maxf(feet.y, route.car_y) + vat.BODY_HALF_HEIGHT + 0.02, feet.z)
	vat.player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var aim: Vector3 = (target - vat.camera.global_position).normalized()
	vat.yaw = atan2(-aim.x, -aim.z)
	vat.pitch = asin(aim.y)
	for _frame in 3:
		await get_tree().physics_frame


func _capture(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
