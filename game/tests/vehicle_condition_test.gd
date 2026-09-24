extends Node

## V1.1/V1.2. Hull integrity — the same shape `condition` already takes on the
## handheld and a weapon's own wear. Before this a car had no notion of
## damage at all: `rift_derby.gd` tracked its own scene-local `integrity` int
## instead, duplicated per car via `set_meta()`. `ArcadeVehicle.condition` is
## the one real field now; this covers the unit-level rules directly, the
## same way `vehicle_fuel_test.gd` covers `fuel`.

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

	# --- a hard impact drops condition measurably -----------------------------
	var rammer: RigidBody3D = _spawn(Vector3(0, 0.75, 0))
	_build_wall(Vector3(0, 1.0, 10.0))
	rammer.linear_velocity = Vector3(0, 0, 22.0)
	var rammer_seconds := 0.0
	while rammer_seconds < 1.5:
		await get_tree().physics_frame
		rammer_seconds += 1.0 / float(Engine.physics_ticks_per_second)
	print("rammer condition after a hard wall hit: %.3f" % rammer.condition)
	check(rammer.condition < 0.95, "a hard impact drops condition measurably (%.3f left)" % rammer.condition)
	check(rammer.condition >= 0.0, "condition never goes negative")

	# --- a soft contact doesn't -------------------------------------------
	var toucher: RigidBody3D = _spawn(Vector3(-24, 0.75, 0))
	_build_wall(Vector3(-24, 1.0, 3.0))
	toucher.linear_velocity = Vector3(0, 0, 1.2)
	var toucher_seconds := 0.0
	while toucher_seconds < 2.0:
		await get_tree().physics_frame
		toucher_seconds += 1.0 / float(Engine.physics_ticks_per_second)
	print("toucher condition after a soft nudge: %.3f" % toucher.condition)
	check(is_equal_approx(toucher.condition, 1.0),
		"a soft contact under the impact threshold does not cost condition (%.3f left)" % toucher.condition)

	# --- clamped, not just bounded in the common case -----------------------
	var wrecked: RigidBody3D = _spawn(Vector3(24, 0.75, 0))
	_build_wall(Vector3(24, 1.0, 6.0))
	wrecked.condition = 0.01
	wrecked.linear_velocity = Vector3(0, 0, 30.0)
	var wrecked_seconds := 0.0
	while wrecked_seconds < 1.0:
		await get_tree().physics_frame
		wrecked_seconds += 1.0 / float(Engine.physics_ticks_per_second)
	check(wrecked.condition >= 0.0, "condition clamps at zero rather than going negative on a huge hit")

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


func _build_wall(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 4, 1)
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)
	wall.global_position = at
	return wall


func _spawn(at: Vector3) -> RigidBody3D:
	var car: RigidBody3D = VEHICLE.new()
	add_child(car)
	car.global_position = at
	return car


func _report() -> void:
	if failures.is_empty():
		print("vehicle condition: clean")
		get_tree().quit(0)
	else:
		print("vehicle condition FAILURES: ", failures)
		get_tree().quit(1)
