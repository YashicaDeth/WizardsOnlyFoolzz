extends Node3D

## Car-71: door-local prompts, hinged entry, missing-door entry and an exit
## point outside the hull, damage interrupting entry and the moving bail. CAR_ENTRY_RESULT failures=N.

var failures: Array[String] = []
var car: RigidBody3D
var damage: VehicleDamage
var driver: VehicleDriver
var body: CharacterBody3D
var eyes: Camera3D


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	_floor()
	car = VehicleDamage.make("sedan", 71, false)
	add_child(car)
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)))
	damage = car.get_node("Damage") as VehicleDamage
	body = CharacterBody3D.new()
	body.name = "Player"
	add_child(body)
	eyes = Camera3D.new()
	eyes.position.y = 0.77
	body.add_child(eyes)
	driver = VehicleDriver.new()
	add_child(driver)
	driver.bind_walker(body, eyes)
	await _frames(3)
	await _door_entry()
	await _interrupted_entry()
	await _moving_bail()
	await _jammed_passenger_entry()
	await _doorless_entry()
	print("CAR_ENTRY_RESULT failures=%d" % failures.size())
	for failure in failures:
		print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _door_entry() -> void:
	body.global_position = car.global_position + Vector3(0, 0.05, 0)
	check(not driver.door_in_reach(body.global_position, car, VehicleDriver.DOOR_LEFT), "the car centre does not offer an entry prompt")
	body.global_position = driver.standing_point(car, VehicleDriver.DOOR_LEFT)
	check(driver.door_in_reach(body.global_position, car, VehicleDriver.DOOR_LEFT), "the driver handle offers entry")
	check(driver.begin_entry(car, VehicleDriver.DOOR_LEFT), "entry starts at the driver door")
	await _seconds(0.43)
	check(damage.door_open_amount(VehicleDriver.DOOR_LEFT) > 0.25, "the real hinged driver door swings open")
	await _seconds(0.95)
	check(driver.seated and driver.driving and driver.phase == "idle", "enter through the door sets the driver seat")
	check(damage.door_open_amount(VehicleDriver.DOOR_LEFT) < 0.02, "the driver door closes after sitting")
	var seated_body := car.get_node_or_null("PlayerSeatBody") as BaselineHuman
	var seated_head := seated_body.parts.get("head") as Node3D if seated_body != null else null
	check(seated_head != null and absf(seated_body.position.y + seated_head.position.y - VehicleInterior.EYE.y) < 0.08, "the seated body stays inside the cab at eye height")
	Input.action_press("pad_combat_r2")
	await _seconds(1.5)
	Input.action_release("pad_combat_r2")
	print("  entry test drive throttle=%.2f speed=%.2f" % [float(car.throttle), float(car.signed_speed)])
	check(float(car.signed_speed) > 1.0, "R2 accelerates forward from the driver seat")
	car.linear_velocity = Vector3.ZERO
	await _frames(8)
	check(driver.get_out(), "exit starts from the seat")
	await _seconds(1.2)
	var expected := driver.standing_point(car, VehicleDriver.DOOR_LEFT)
	var flat_error := Vector2(body.global_position.x - expected.x, body.global_position.z - expected.z).length()
	check(not driver.seated and flat_error < 0.15, "exit puts the body beside the driver door")
	var local := car.to_local(body.global_position)
	check(absf(local.x) > float(car.hull_size.x) * 0.5, "exit never leaves the body inside the car")


func _interrupted_entry() -> void:
	body.global_position = driver.standing_point(car, VehicleDriver.DOOR_LEFT)
	var before := body.global_position
	check(driver.begin_entry(car, VehicleDriver.DOOR_LEFT), "a second entry starts")
	await _seconds(0.5)
	check(driver.interrupt_entry("TOOK DAMAGE"), "taking damage interrupts entry")
	check(not driver.seated and driver.phase == "idle" and body.global_position.distance_to(before) < 0.2, "an interrupted entry leaves the body outside at the handle")
	check(damage.door_open_amount(VehicleDriver.DOOR_LEFT) < 0.02, "an interrupted entry lets the door shut")


func _moving_bail() -> void:
	body.global_position = driver.standing_point(car, VehicleDriver.DOOR_LEFT)
	check(driver.begin_entry(car, VehicleDriver.DOOR_LEFT), "entry before the bail")
	await _seconds(1.35)
	Input.action_press("pad_combat_r2")
	var waited := 0.0
	while float(car.signed_speed) <= VehicleDriver.GET_OUT_SPEED + 0.5 and waited < 6.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	Input.action_release("pad_combat_r2")
	print("  bail speed=%.2f" % float(car.signed_speed))
	check(driver.get_out() and driver.exit_kind == "jump", "getting out above GET_OUT_SPEED is a jump, not a refusal")
	var saw_bail := false
	var out_calls := [0]
	driver.got_out.connect(func(_at: Vector3, _yaw: float) -> void: out_calls[0] += 1)
	waited = 0.0
	while (driver.occupied() or out_calls[0] == 0) and waited < 4.0:
		saw_bail = saw_bail or driver.phase == "bail"
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(saw_bail, "a moving exit rolls and stumbles before control returns")
	check(not driver.occupied() and out_calls[0] == 1, "the bail hands the body back once")
	var local := car.to_local(body.global_position)
	check(absf(local.x) > float(car.hull_size.x) * 0.5 or absf(local.z) > float(car.hull_size.z) * 0.5, "the bail leaves the body outside the hull")
	check(eyes.transform.basis.is_equal_approx(Basis.IDENTITY), "the eyes come upright after the roll")
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)))
	await _frames(10)


func _doorless_entry() -> void:
	var part: Dictionary = damage.door_part(VehicleDriver.DOOR_LEFT)
	damage._detach("DoorLeft", -car.global_basis.x, (part.node as Node3D).global_position)
	await _frames(2)
	check(damage.door_missing(VehicleDriver.DOOR_LEFT), "the driver door is physically detached")
	body.global_position = driver.standing_point(car, VehicleDriver.DOOR_LEFT)
	check(driver.begin_entry(car, VehicleDriver.DOOR_LEFT), "a missing door still starts entry")
	await _seconds(1.35)
	check(driver.seated and driver.driving, "a missing door still allows the driver seat")
	driver.get_out(true)


func _jammed_passenger_entry() -> void:
	var passenger: Dictionary = damage.door_part(VehicleDriver.DOOR_RIGHT)
	passenger.hp = 10.0
	body.global_position = driver.standing_point(car, VehicleDriver.DOOR_RIGHT)
	check(driver.begin_entry(car, VehicleDriver.DOOR_RIGHT), "a jammed passenger door accepts the first pull")
	await _seconds(0.3)
	check(not driver.seated and driver.last_message.contains("1/3"), "the first jammed-door pull does not teleport into the seat")
	check(driver.begin_entry(car, VehicleDriver.DOOR_RIGHT), "a jammed passenger door accepts the second pull")
	await _seconds(0.3)
	check(driver.begin_entry(car, VehicleDriver.DOOR_RIGHT), "the third pull kicks a jammed door free")
	await _seconds(1.35)
	check(driver.seated and not driver.driving and driver.seat_side == VehicleDriver.DOOR_RIGHT, "the passenger side uses the same seated entry without taking the wheel")
	driver.get_out(true)


func _floor() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -0.5
	add_child(ground)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
