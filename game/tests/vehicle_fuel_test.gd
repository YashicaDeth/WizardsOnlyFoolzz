extends Node

## V1.3. Fuel, or a reason a car is not infinite. Before this a derby car (and
## every wrecker) could hold the throttle down for the length of the game
## without ever running dry. `ArcadeVehicle.fuel` now burns while the throttle
## is actually held, idling and coasting cost nothing, and a dry tank cuts the
## drive force in `_integrate_forces` outright rather than just being a number
## nothing reads.

const VEHICLE := preload("res://systems/arcade_vehicle.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	_build_floor()

	# --- unit level: the tank is a real number with real rules ---------------
	var idle: ArcadeVehicle = _spawn(Vector3(-10, 0.75, 0))
	idle.enabled = true
	idle.throttle = 0.0
	for _frame in 120:
		await get_tree().physics_frame
	check(is_equal_approx(idle.fuel, 1.0), "idling with the throttle at rest burns nothing (%.3f left)" % idle.fuel)

	var burner: ArcadeVehicle = _spawn(Vector3(10, 0.75, 0))
	burner.enabled = true
	burner.throttle = 1.0
	for _frame in 120:
		await get_tree().physics_frame
	check(burner.fuel < 1.0, "holding the throttle actually burns fuel (%.3f left)" % burner.fuel)
	check(burner.has_fuel(), "two seconds of full throttle does not already run it dry")

	burner.fuel = 0.02
	burner.linear_velocity = Vector3.ZERO
	for _frame in 150:
		await get_tree().physics_frame
	check(not burner.has_fuel(), "the tank actually reaches empty rather than asymptoting")

	burner.refuel()
	check(is_equal_approx(burner.fuel, 1.0), "refuel tops the tank back up")

	# --- integration level: an empty tank actually stops the car -------------
	var stalled: ArcadeVehicle = _spawn(Vector3(0, 0.75, -20))
	stalled.enabled = true
	stalled.fuel = 0.0
	stalled.throttle = 1.0
	var seconds := 0.0
	while seconds < 1.2:
		await get_tree().physics_frame
		seconds += 1.0 / float(Engine.physics_ticks_per_second)
	var stalled_speed := stalled.linear_velocity.length()
	print("stalled car speed after 1.2s of buried throttle: %.2f m/s" % stalled_speed)
	check(stalled_speed < 0.5, "a dry tank means full throttle does not actually move the car")

	_report()


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400, 1, 400)
	collision.shape = shape
	collision.position.y = -0.5
	floor_body.add_child(collision)
	add_child(floor_body)


func _spawn(at: Vector3) -> ArcadeVehicle:
	var car: ArcadeVehicle = VEHICLE.new()
	add_child(car)
	car.global_position = at
	return car


func _report() -> void:
	if failures.is_empty():
		print("vehicle fuel: clean")
		get_tree().quit(0)
	else:
		print("vehicle fuel FAILURES: ", failures)
		get_tree().quit(1)
