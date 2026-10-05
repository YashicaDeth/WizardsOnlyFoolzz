extends Node3D

## Lab-53: a real crash crumples the body and takes parts off; a slow knock
## only dents; engine damage lowers top speed. VEHICLE_DAMAGE_RESULT failures=N.

var failures: Array[String] = []


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
	await _crash_into_wall()
	_threshold()
	await _engine_costs_speed()
	print("VEHICLE_DAMAGE_RESULT failures=%d" % failures.size())
	for failure in failures:
		print("  - ", failure)
	get_tree().quit(1 if failures.size() > 0 else 0)


func _floor() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -0.5
	add_child(ground)


func _car(model: String, at: Vector3) -> RigidBody3D:
	var car := VehicleDamage.make(model, 2, true)
	add_child(car)
	car.teleport(Transform3D(Basis.IDENTITY, at))
	return car


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _crash_into_wall() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 3, 1)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1.5, -40)
	add_child(wall)
	var car := _car("sedan", Vector3(0, 0.95, 0))
	var damage := car.get_node("Damage") as VehicleDamage
	await _frames(20)
	check(damage.max_crush == 0.0 and damage.detached.is_empty(), "a parked car is untouched")
	check(damage.driver != null, "a driver sits in the car")
	var health_before := _health(damage.driver)
	car.enabled = true
	car.throttle = 1.0
	var peak := 0.0
	for i in 600:
		await get_tree().physics_frame
		peak = maxf(peak, float(car.signed_speed))
		if damage.hits > 0:
			break
	car.throttle = 0.0
	await _frames(30)
	print("  wall hit at peak %.1f m/s: %s" % [peak, damage.report()])
	check(damage.hits > 0, "driving into the wall registers an impact")
	check(damage.max_crush > 0.08, "the front crumples (%.2f m)" % damage.max_crush)
	check(not damage.detached.is_empty(), "a fast hit takes parts off (%s)" % [damage.detached])
	check(damage.engine < 1.0, "a front hit costs the engine")
	check(_loose_parts() > 0, "detached parts are physics bodies in the world")
	check(_health(damage.driver) < health_before, "the driver takes the crash")
	car.queue_free()
	wall.queue_free()


func _loose_parts() -> int:
	var count := 0
	for child in get_children():
		if child is RigidBody3D and str(child.name).ends_with("_Detached"):
			count += 1
	return count


func _health(rig: BaselineHuman) -> float:
	if rig == null:
		return 0.0
	var total := 0.0
	for zone in rig.parts.keys():
		total += rig.zone_health(str(zone))
	return total


## Below the steel tier a ram only dents, however often it lands; above it a
## panel comes off.
func _threshold() -> void:
	var car := _car("suv", Vector3(30, 0.95, 0))
	var damage := car.get_node("Damage") as VehicleDamage
	var nose := car.to_global(Vector3(0, 0, -car.hull_size.z * 0.5))
	for i in 6:
		damage.hit(nose, car.global_basis.z, 9.0, "vehicle", {"mass": car.mass, "speed": 9.0})
	check(damage.max_crush > 0.05, "slow knocks dent the nose")
	check(damage.detached == ["Windscreen"], "slow knocks break glass but never beat steel's tier (%s)" % [damage.detached])
	damage.hit(nose, car.global_basis.z, 18.0, "vehicle", {"mass": car.mass, "speed": 18.0})
	check(damage.detached.has("BumperFront"), "a fast ram takes the bumper off (%s)" % [damage.detached])
	var melee := damage.hit(car.to_global(Vector3(-car.hull_size.x * 0.5, 0, 0)), car.global_basis.x, 30.0, "melee")
	check(not (melee.detached as Array).has("DoorLeft"), "melee cannot take a steel door off")
	car.queue_free()


func _engine_costs_speed() -> void:
	var healthy := _car("sedan", Vector3(-20, 0.95, 60))
	var wrecked := _car("sedan", Vector3(20, 0.95, 60))
	await _frames(10)
	var damage := wrecked.get_node("Damage") as VehicleDamage
	var nose := wrecked.to_global(Vector3(0, 0.3, -wrecked.hull_size.z * 0.5))
	for i in 4:
		damage.hit(nose, wrecked.global_basis.z, 12.0, "vehicle", {"mass": wrecked.mass, "speed": 12.0})
	check(damage.engine < 0.6, "front hits wreck the engine (%.2f)" % damage.engine)
	var tops := [0.0, 0.0]
	for car: RigidBody3D in [healthy, wrecked]:
		car.enabled = true
		car.throttle = 1.0
	for i in 420:
		await get_tree().physics_frame
		tops[0] = maxf(tops[0], float(healthy.signed_speed))
		tops[1] = maxf(tops[1], float(wrecked.signed_speed))
	print("  top speed healthy %.1f, wrecked engine %.1f" % tops)
	check(tops[0] > 15.0, "a healthy car gets up to speed")
	check(tops[1] < tops[0] * 0.8, "a damaged engine lowers top speed")
