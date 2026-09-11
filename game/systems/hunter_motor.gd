class_name HunterMotor
extends RefCounted

## Shared camera-relative movement for the Hunt Grounds and its movement lab.
## Input.get_vector reports forward as negative Y; this is the one place that
## converts that convention into the camera's positive forward vector.

const GROUND_ACCEL := 34.0
const GROUND_DECEL := 46.0
const AIR_ACCEL := 9.0
const GRAVITY := 22.0
const FLOOR_STICK := 0.8
const MAX_SLOPE_DEGREES := 50.0


static func configure(body: CharacterBody3D) -> void:
	body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	body.up_direction = Vector3.UP
	body.floor_snap_length = 0.42
	body.floor_max_angle = deg_to_rad(MAX_SLOPE_DEGREES)
	body.floor_stop_on_slope = true
	body.floor_constant_speed = true
	body.safe_margin = 0.035
	body.max_slides = 6


static func camera_forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw)).normalized()


static func wish_direction(input_vector: Vector2, yaw: float) -> Vector3:
	var forward := camera_forward(yaw)
	var right := Vector3(forward.z, 0.0, -forward.x)
	# W is input_vector.y == -1. Negating it makes W follow the camera.
	var wish := right * input_vector.x - forward * input_vector.y
	return wish.normalized() if wish.length_squared() > 0.0001 else Vector3.ZERO


static func dodge_direction(input_vector: Vector2, yaw: float) -> Vector3:
	var wish := wish_direction(input_vector, yaw)
	return wish if not wish.is_zero_approx() else -camera_forward(yaw)


static func collision_safe_camera(space: PhysicsDirectSpaceState3D, focus: Vector3, desired: Vector3, exclusions: Array[RID] = []) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(focus, desired)
	query.exclude = exclusions
	query.collide_with_areas = false
	var obstruction := space.intersect_ray(query)
	if obstruction.is_empty():
		return desired
	# Pull toward the subject instead of offsetting by the surface normal. This
	# remains stable in tight concave corners where adjacent normals disagree.
	var toward_focus: Vector3 = (focus - obstruction.position).normalized()
	return obstruction.position + toward_focus * 0.24


static func move_body(body: CharacterBody3D, direction: Vector3, speed: float, delta: float, forced_direction := Vector3.ZERO, forced_speed := 0.0) -> void:
	var target_direction := forced_direction.normalized() if not forced_direction.is_zero_approx() else direction
	var target_speed := forced_speed if not forced_direction.is_zero_approx() else speed
	var desired := target_direction * target_speed
	var accelerating := direction.length_squared() > 0.001 or not forced_direction.is_zero_approx()
	var response := GROUND_ACCEL if accelerating else GROUND_DECEL
	if not body.is_on_floor():
		response = AIR_ACCEL
	body.velocity.x = move_toward(body.velocity.x, desired.x, response * delta)
	body.velocity.z = move_toward(body.velocity.z, desired.z, response * delta)
	if body.is_on_floor():
		# A small downward bias keeps the capsule attached to descending ramps;
		# floor snap handles steps without turning them into tiny jumps.
		body.velocity.y = -FLOOR_STICK
	else:
		body.velocity.y -= GRAVITY * delta
	body.move_and_slide()
