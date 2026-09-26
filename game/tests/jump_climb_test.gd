extends Node3D

## JumpClimb: SPACE facing a waist-high ledge hauls you onto it, on open floor
## it jumps and lands, and a ledge above reach is jumped at, not climbed.

const JUMP_CLIMB := preload("res://systems/jump_climb.gd")

var failures := 0
var body: CharacterBody3D


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _block(size: Vector3, at: Vector3) -> void:
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	solid.add_child(shape)
	solid.position = at
	add_child(solid)


func _physics_process(delta: float) -> void:
	if body == null or JUMP_CLIMB.busy(body):
		return
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	JUMP_CLIMB.fall(body, delta)
	body.move_and_slide()


func settle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _ready() -> void:
	WorldHistory.clear_history()
	_block(Vector3(30, 1, 30), Vector3(0, -0.5, 0))
	# A 1.1 m ledge to the north, a 3 m wall to the east.
	_block(Vector3(4, 1.1, 2), Vector3(0, 0.55, -1.6))
	_block(Vector3(1, 3, 4), Vector3(1.4, 1.5, 4))
	body = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	shape.shape = capsule
	body.add_child(shape)
	body.position = Vector3(0, 0.9, 0)
	add_child(body)
	await settle(20)
	check(body.is_on_floor(), "standing")
	check(is_equal_approx(JUMP_CLIMB.feet_offset(body), 0.85), "feet read from the capsule")

	check(JUMP_CLIMB.press(body, 0.0, 1.0, "test_climbed") == "climb", "facing a 1.1 m ledge: climbs")
	check(JUMP_CLIMB.busy(body), "hauling up")
	check(JUMP_CLIMB.press(body, 0.0) == "", "no second press mid-climb")
	await settle(40)
	check(body.global_position.y > 1.8 and body.global_position.z < -0.6, "on top of the ledge (%s)" % str(body.global_position))
	check(WorldHistory.event_count("test_climbed") == 1, "the climb is recorded")

	body.global_position = Vector3(0, 0.9, 4)
	await settle(20)
	var floor_y := body.global_position.y
	check(JUMP_CLIMB.press(body, -PI * 0.5) == "jump", "facing a 3 m wall: jumps, no climb")
	var peak := floor_y
	for _i in 30:
		await get_tree().physics_frame
		peak = maxf(peak, body.global_position.y)
	check(peak > floor_y + 0.4, "leaves the ground (%.2f up)" % (peak - floor_y))
	await settle(30)
	check(absf(body.global_position.y - floor_y) < 0.1, "and lands")

	body.global_position = Vector3(0, 0.9, 4)
	await settle(20)
	floor_y = body.global_position.y
	JUMP_CLIMB.press(body, 0.0, 0.3)
	peak = floor_y
	for _i in 30:
		await get_tree().physics_frame
		peak = maxf(peak, body.global_position.y)
	check(peak < floor_y + 0.4, "a body fresh out of the tank jumps weakly (%.2f up)" % (peak - floor_y))
	print("JUMP_CLIMB_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
