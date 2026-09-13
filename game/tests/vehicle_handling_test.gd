extends Node

## V1.2. Damage is physical and visible, and it changes how it drives. The
## visible half (crushed shell, shed panels) already existed in
## `_update_player_damage_visual`/`_update_detachable_parts`; this proves the
## other half: a battered `ArcadeVehicle` actually corners, brakes and
## accelerates worse, because `handling_fraction()` now scales the same grip
## limit that clamps all three, driven by real `_integrate_forces` physics
## rather than a read of the constant.

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

	var healthy: ArcadeVehicle = _spawn(Vector3(-4, 0.75, 0))
	var battered: ArcadeVehicle = _spawn(Vector3(4, 0.75, 0))
	battered.apply_damage(70)
	check(is_equal_approx(healthy.handling_fraction(), 1.0), "an undamaged chassis drives at full handling")
	check(battered.handling_fraction() < 0.7, "a chassis at 30%% integrity is measurably below full handling (%.2f)" % battered.handling_fraction())

	healthy.enabled = true
	battered.enabled = true
	healthy.throttle = 1.0
	battered.throttle = 1.0
	var seconds := 0.0
	while seconds < 1.4:
		await get_tree().physics_frame
		seconds += 1.0 / float(Engine.physics_ticks_per_second)

	var healthy_speed: float = healthy.linear_velocity.length()
	var battered_speed: float = battered.linear_velocity.length()
	print("healthy speed %.2f m/s // battered speed %.2f m/s" % [healthy_speed, battered_speed])
	check(healthy_speed > 1.0, "the healthy car actually moved under throttle")
	check(battered_speed < healthy_speed * 0.85, "the battered car puts down measurably less speed under identical throttle")

	# Same story sideways: a hard steering input should carry the healthy car
	# further off its line than the battered one over the same window.
	healthy.throttle = 0.0
	battered.throttle = 0.0
	healthy.linear_velocity = Vector3(0, 0, -10)
	battered.linear_velocity = Vector3(0, 0, -10)
	healthy.steering = 1.0
	battered.steering = 1.0
	var healthy_start := healthy.global_position
	var battered_start := battered.global_position
	seconds = 0.0
	while seconds < 0.8:
		await get_tree().physics_frame
		seconds += 1.0 / float(Engine.physics_ticks_per_second)
	var healthy_drift := absf(healthy.global_position.x - healthy_start.x)
	var battered_drift := absf(battered.global_position.x - battered_start.x)
	print("healthy lateral drift %.2fm // battered lateral drift %.2fm" % [healthy_drift, battered_drift])
	check(battered_drift < healthy_drift, "the battered chassis turns in less over the same steering input")

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
		print("vehicle handling: clean")
		get_tree().quit(0)
	else:
		print("vehicle handling FAILURES: ", failures)
		get_tree().quit(1)
