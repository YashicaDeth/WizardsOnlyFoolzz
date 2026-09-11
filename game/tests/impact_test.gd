extends Node

## Tier 1a regression cover. Every check here failed before the impact rework:
## the uncapped grip force cancelled side hits inside one frame, and sustained
## engine force held rammed cars in contact instead of letting them part.

const VEHICLE := preload("res://systems/arcade_vehicle.gd")

var failures: Array[String] = []
var hits: Array[Dictionary] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	_build_floor()
	await _test_head_on()
	await _test_grip_cap()
	await _test_grind_breaks()
	print("IMPACT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400, 1, 400)
	collision.shape = shape
	collision.position.y = -0.5
	floor_body.add_child(collision)
	add_child(floor_body)


func _spawn(at: Vector3, facing: float) -> RigidBody3D:
	var car: RigidBody3D = VEHICLE.new()
	add_child(car)
	car.global_position = at
	car.rotation.y = facing
	car.enabled = true
	return car


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _test_head_on() -> void:
	var left := _spawn(Vector3(0, 0.75, 14), 0.0)
	var right := _spawn(Vector3(0, 0.75, -14), PI)
	left.impact.connect(func(other, closing, share): hits.append({"closing": closing, "share": share}))
	left.throttle = 1.0
	right.throttle = 1.0
	var separation_peak := 0.0
	var struck := false
	for frame in 240:
		await get_tree().physics_frame
		var axis := (right.global_position - left.global_position)
		axis.y = 0.0
		if axis.length() < 0.01:
			continue
		axis = axis.normalized()
		if not hits.is_empty():
			struck = true
			left.throttle = 0.0
			right.throttle = 0.0
			separation_peak = maxf(separation_peak, (right.linear_velocity - left.linear_velocity).dot(axis))
		if struck and frame > 120:
			break
	check(struck, "head-on ram registers an impact")
	var closing: float = hits[0].closing if not hits.is_empty() else 0.0
	check(closing > 8.0, "closing speed reflects both cars arriving (%.1f m/s)" % closing)
	var share: float = hits[0].share if not hits.is_empty() else 0.0
	check(share > 0.3 and share < 0.7, "mutual ram splits the blame (%.2f)" % share)
	# The whole point of Tier 1a: the pair has to actually come apart — but a
	# derby is not pinball, so the upper bound is part of the contract.
	check(separation_peak > 5.0 and separation_peak < 22.0, "cars part with weight, not launch (%.1f m/s)" % separation_peak)
	check(left.stun > 0.0 or right.stun > 0.0, "impact cuts drive so the pair parts")
	var before: int = hits.size()
	await _settle(6)
	check(hits.size() == before, "contact lockout suppresses rescoring the same pair")
	left.queue_free()
	right.queue_free()
	await _settle(2)


func _test_grip_cap() -> void:
	var car := _spawn(Vector3(60, 0.75, 0), 0.0)
	await _settle(4)
	car.throttle = 0.0
	# A T-bone arrives as sideways velocity. Grip may shave it, never erase it.
	car.linear_velocity = car.global_transform.basis.x * 8.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lateral: float = car.linear_velocity.dot(car.global_transform.basis.x)
	check(lateral > 6.5, "capped grip lets a side impact carry the car (%.1f m/s)" % lateral)
	car.queue_free()
	await _settle(2)


func _test_grind_breaks() -> void:
	var left := _spawn(Vector3(-60, 0.75, 2.55), 0.0)
	var right := _spawn(Vector3(-60, 0.75, -2.55), PI)
	await _settle(4)
	var start: float = left.global_position.distance_to(right.global_position)
	# Below the impact threshold, so only the sustained-contact pressure can
	# break this. Two cars leaning on each other used to stay there all round.
	left.throttle = 0.35
	right.throttle = 0.35
	var peak := 0.0
	var slew := 0.0
	for frame in 150:
		await get_tree().physics_frame
		peak = maxf(peak, left.global_position.distance_to(right.global_position))
		slew = maxf(slew, absf(left.rotation.y))
	# Both cars hold the throttle into each other for the whole window, so they
	# are expected to re-engage — and the second engagement arrives fast enough
	# to score as a real impact, which can rotate the car back toward straight.
	# The contract is therefore about peaks: they come apart, and they turn.
	check(peak > 5.3, "sustained shove breaks a low-speed grind (touching at 4.80 m, peak gap %.2f m)" % peak)
	check(slew > 0.1, "a pinned car slews off the contact (peak %.2f rad)" % slew)
	left.queue_free()
	right.queue_free()
	await _settle(2)
