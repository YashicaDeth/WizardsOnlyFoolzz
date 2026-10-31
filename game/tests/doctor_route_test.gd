extends Node

## The doctor's door in the real Growing Floor (Greg, 24 September 2026):
## break it with the restraint, a shoulder, the fire axe or the gun; his room
## is reachable only after; the lift car with doors rides down and hands over
## to the Support Unit, or says plainly that it is not built yet.

const VAT := preload("res://vat_chamber.tscn")

var failures: Array[String] = []
var travelled := ""


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await _restraint_then_room_then_lift()
	await _shoulder()
	await _axe()
	await _gun_then_shoulder()
	await _persistence()
	print("DOCTOR_ROUTE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


## The real opening, filed and torn out of, up to the first steps.
func _opening() -> Node:
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
	for _step in 60:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return vat


func _press(vat: Node, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	vat._unhandled_input(key)


func _click(vat: Node, button := MOUSE_BUTTON_LEFT) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = true
	vat._unhandled_input(click)


## Stand in front of his door, facing into his room.
func _face_door(vat: Node, distance := 1.3) -> void:
	var route: DoctorRoute = vat.doctor_route
	# Moving the mouse ends the guided turn, as it would for a player.
	vat._unhandled_input(InputEventMouseMotion.new())
	vat.player.global_position = Vector3(route.DOOR_AT.x, vat.BODY_HALF_HEIGHT + 0.02, route.WALL_Z - distance)
	vat.player.velocity = Vector3.ZERO
	vat.yaw = PI
	vat.pitch = -0.15
	vat.player.rotation.y = vat.yaw
	vat.camera.rotation = Vector3(vat.pitch, 0, 0)


func _walk_forward(seconds: float) -> void:
	Input.action_press("move_forward")
	for _frame in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame


func _batter(vat: Node, action: Callable, limit: int) -> int:
	var route: DoctorRoute = vat.doctor_route
	var blows := 0
	while not route.door.broken and blows < limit:
		_face_door(vat)
		route.cooldown = 0.0
		action.call()
		blows += 1
		await get_tree().physics_frame
	return blows


func _restraint_then_room_then_lift() -> void:
	WorldHistory.clear_history()
	var vat = await _opening()
	var route: DoctorRoute = vat.doctor_route
	check(route != null and route.door != null and not route.door.broken, "his door stands behind the vat, whole")
	# The guided turn: the head comes round to his door on its own.
	for _frame in int((route.LOOK_SECONDS + 0.3) * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	check(vat.get_node("HUD/Objective").text.contains("HE LEFT THROUGH THAT DOOR") and vat.get_node("HUD/Objective").text.contains("ESCAPE THE FACILITY"), "GET REVENGE names his door, and the way out stays readable")
	var looking: Vector3 = -vat.camera.global_transform.basis.z
	var to_door: Vector3 = (route.DOOR_AT + Vector3(0, 1.3, 0) - vat.camera.global_position).normalized()
	check(looking.dot(to_door) > 0.9, "control arrives turned toward his door (%.2f)" % looking.dot(to_door))

	# Walking at it does not get you in.
	_face_door(vat, 1.6)
	await _walk_forward(2.0)
	check(vat.player.global_position.z < route.WALL_Z - 0.2 and not route.room_entered, "the intact door keeps you out (z %.2f)" % vat.player.global_position.z)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(route.prompt_text().contains("RESTRAINT") and vat.prompt.text.contains("[F] SHOULDER IT"), "the prompt line offers the restraint and a shoulder at the door")

	var clicks := await _batter(vat, func() -> void: _click(vat), 80)
	check(route.door.broken, "clicking with the restraint breaks it (%d blows)" % clicks)
	check(str(WorldHistory.subject(route.DOOR_ID).get("broken_by", "")).ends_with("restraint"), "WorldHistory records the door broken by the restraint (%s)" % WorldHistory.subject(route.DOOR_ID).get("broken_by", ""))
	check(WorldHistory.event_count("doctor_route_door_broken") == 1, "the route records the break")
	check(vat.get_node("HUD/Objective").text.contains("FOLLOW HIM DOWN") or vat.objective_text.contains("FOLLOW HIM DOWN"), "the task moves on to following him down")
	for _frame in 10:
		await get_tree().physics_frame

	_face_door(vat, 1.6)
	await _walk_forward(3.0)
	check(vat.player.global_position.z > route.WALL_Z + 0.6 and route.room_entered, "with the door down you walk into his room (z %.2f)" % vat.player.global_position.z)
	check(WorldHistory.event_count("doctor_route_room_entered") == 1, "entering the room is recorded")

	# The lift: call it, step in, ride down.
	vat.player.global_position = Vector3(route.CAR_AT.x, vat.BODY_HALF_HEIGHT + 0.02, route.ROOM_Z.y - 1.0)
	await get_tree().physics_frame
	check(route.prompt_text() == "[E] CALL THE LIFT", "at the landing the lift can be called")
	_press(vat, KEY_E)
	for _frame in int((route.DOOR_SECONDS + 0.2) * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	check(route.doors_open >= 1.0 and route.lift_state == "open", "the lift doors open")
	vat.yaw = 0.0
	await _walk_forward(0.1)
	vat.player.global_position = route.CAR_AT + Vector3(0, vat.BODY_HALF_HEIGHT + 0.02, 0.2)
	await get_tree().physics_frame
	check(route.prompt_text() == "[E] DOWN", "inside the car it offers the ride down")
	route.travel_hook = func(path: String) -> void: travelled = path
	_press(vat, KEY_E)
	check(WorldHistory.event_count("doctor_route_elevator_taken") == 1, "WorldHistory records doctor_route_elevator_taken")
	for _frame in int((route.DOOR_SECONDS + route.RIDE_SECONDS + 0.5) * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	check(route.doors_open <= 0.0, "the doors shut before the car moves")
	check(route.lift_state == "arrived" and route.car_y <= -route.DESCENT + 0.01, "the car rides all the way down")
	check(vat.player.global_position.y < -route.DESCENT + 2.0, "and the player rides down in it (y %.2f)" % vat.player.global_position.y)
	if ResourceLoader.exists(route.DESTINATION):
		check(travelled == route.DESTINATION, "at the bottom it travels to the Support Unit")
	else:
		check(route.placeholder_shown and vat.subtitle.text.contains("SUPPORT UNIT NOT BUILT YET"), "with no Support Unit yet it says so plainly")
		check(route.prompt_text() == "[E] RIDE BACK UP", "and offers the ride back up")
	vat.queue_free()
	await get_tree().process_frame


func _shoulder() -> void:
	WorldHistory.clear_history()
	var vat = await _opening()
	var route: DoctorRoute = vat.doctor_route
	_face_door(vat, 3.0)
	_press(vat, KEY_F)
	check(route.door.condition() >= 1.0, "a shoulder from across the room does not reach the door")
	var charges := await _batter(vat, func() -> void: _press(vat, KEY_F), 60)
	check(route.door.broken, "shoulder-charging with F bursts it (%d charges)" % charges)
	check(str(WorldHistory.subject(route.DOOR_ID).get("broken_by", "")).ends_with("body"), "and the record says the body did it (%s)" % WorldHistory.subject(route.DOOR_ID).get("broken_by", ""))
	check(charges > 3, "but a body alone takes several goes")
	vat.queue_free()
	await get_tree().process_frame


func _axe() -> void:
	WorldHistory.clear_history()
	var vat = await _opening()
	var route: DoctorRoute = vat.doctor_route
	vat._unhandled_input(InputEventMouseMotion.new())
	vat.player.global_position = Vector3(route.AXE_AT.x, vat.BODY_HALF_HEIGHT + 0.02, route.AXE_AT.z - 1.0)
	await get_tree().physics_frame
	check(route.prompt_text() == "[E] TAKE THE FIRE AXE", "the fire axe by the door can be taken")
	_press(vat, KEY_E)
	check(route.carrying_axe and route.held_weapon() == "axe" and not route.axe_model.visible, "E takes it off the wall and into the hand")
	var labels := (WorldHistory.subject("inventory").get("items", []) as Array).map(func(item): return str(item.get("label", "")))
	check(labels.has("FIRE AXE"), "the axe goes into Carry")
	var swings := await _batter(vat, func() -> void: _click(vat), 30)
	check(route.door.broken and str(WorldHistory.subject(route.DOOR_ID).get("broken_by", "")).ends_with("axe"), "the axe breaks it (%d swings, %s)" % [swings, WorldHistory.subject(route.DOOR_ID).get("broken_by", "")])
	check(route.door.fragments.size() > 0, "and leaves real debris")
	vat.queue_free()
	await get_tree().process_frame


func _gun_then_shoulder() -> void:
	WorldHistory.clear_history()
	var vat = await _opening()
	var route: DoctorRoute = vat.doctor_route
	check(route._gun_rounds() == 0, "no gun on the Growing Floor unless you carry one")
	var carry := Carry.new()
	carry.items.append({"label": route.GUN_LABEL, "kind": "weapon", "weapon": "facility_sidearm", "rounds": 4, "mass": 1.1, "perishes": false, "age": 0.0})
	carry.save_to_history()
	# Aim at the lock: right of centre from the tank's side, since the door is turned to face you.
	for _shot in 2:
		_face_door(vat, 1.3)
		var lock_world: Vector3 = route.door.to_global(Vector3(route.door.width * 0.5 - 0.13, route.door.height * 0.5 - 0.05, 0.0))
		var aim: Vector3 = (lock_world - vat.camera.global_position).normalized()
		vat.yaw = atan2(-aim.x, -aim.z)
		vat.pitch = asin(aim.y)
		vat.player.rotation.y = vat.yaw
		vat.camera.rotation = Vector3(vat.pitch, 0, 0)
		route.cooldown = 0.0
		_click(vat, MOUSE_BUTTON_RIGHT)
	check(route.door.lock_hp <= 0.0 and route._gun_rounds() == 2, "two rounds take out the lock and are spent (%s, %d left)" % [route.door.state, route._gun_rounds()])
	_face_door(vat)
	route.cooldown = 0.0
	_press(vat, KEY_F)
	check(route.door.broken, "then a shoulder puts it into the wall")
	vat.queue_free()
	await get_tree().process_frame


## Built again from the record, the door is still down and the way stays open.
func _persistence() -> void:
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	var route: DoctorRoute = vat.doctor_route
	check(route.door.broken and route.door.passable(), "a door broken in an earlier life is still broken")
	vat.queue_free()
	await get_tree().process_frame
