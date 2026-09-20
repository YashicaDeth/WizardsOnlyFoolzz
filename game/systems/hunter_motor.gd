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


## The right vector was `Vector3(forward.z, 0.0, -forward.x)`, which is the
## correct formula for a frame whose forward is Godot's own `Vector3.FORWARD`
## (0, 0, -1). This game's forward is the opposite: `camera_forward(0)` is
## (0, 0, 1), which is `Vector3.BACK`. In that frame the same expression yields
## the vector pointing at the player's LEFT, so A and D were swapped.
##
## The check that settles it without arguing about handedness: mouse-right
## decreases yaw (`bone_yard_hunt.gd`, `yaw -= turn.x`), so turning right takes
## the player from facing +Z toward facing -X. Whatever direction turning right
## walks you into is, by definition, the direction strafing right should walk
## you into - and `strafing right == turning 90 degrees right and walking
## forward` is the invariant `movement_lab.gd` now pins, at four yaws, because
## it holds in any frame and cannot be satisfied by an inverted one.
static func wish_direction(input_vector: Vector2, yaw: float) -> Vector3:
	var forward := camera_forward(yaw)
	var right := Vector3(-forward.z, 0.0, forward.x)
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


## The oldest unsolved problem in third person: what a chase camera does when
## there is no room behind the player for one. `collision_safe_camera()` above
## already answers "where does the camera actually go" by pulling it in to
## whatever clearance exists; this answers "how much of a third-person shot is
## even possible right now" — the fraction of the requested distance the
## camera actually got to keep, from `focus` out toward `desired`, after
## `collision_safe_camera()` stopped it at `achieved`.
##
## A corridor or a vat room narrow enough to jam the shoulder-cam into the
## player's own back reads as a ratio near zero here; open ground behind the
## player reads near one. The caller blends perspective by this number rather
## than snapping, so the implant hands control back to your own eyes exactly
## as fast as the room around you closes in, and gives it back the same way
## once there is space for it again — never a hard cut, and never a camera
## left sitting inside geometry.
static func third_person_clearance_blend(focus: Vector3, desired: Vector3, achieved: Vector3) -> float:
	var wanted := focus.distance_to(desired)
	if wanted < 0.001:
		return 1.0
	return clampf(focus.distance_to(achieved) / wanted, 0.0, 1.0)


## `jump_impulse` must be applied here, inside the same move_and_slide() this
## call makes, not by the caller afterward: is_on_floor() only turns false
## once a slide has actually carried the body off the ground, so a caller
## that waits for "after move_body()" is really waiting a whole physics step
## too late — next frame this same floor-stick branch reads is_on_floor()
## still true (the body never got the chance to leave) and stomps whatever
## velocity.y the caller set right back to -FLOOR_STICK. Applied here instead,
## the jump and the slide that has to prove it happen in the same step.
static func move_body(body: CharacterBody3D, direction: Vector3, speed: float, delta: float, forced_direction := Vector3.ZERO, forced_speed := 0.0, jump_impulse := 0.0) -> void:
	var target_direction := forced_direction.normalized() if not forced_direction.is_zero_approx() else direction
	var target_speed := forced_speed if not forced_direction.is_zero_approx() else speed
	var desired := target_direction * target_speed
	var accelerating := direction.length_squared() > 0.001 or not forced_direction.is_zero_approx()
	var response := GROUND_ACCEL if accelerating else GROUND_DECEL
	if not body.is_on_floor():
		response = AIR_ACCEL
	body.velocity.x = move_toward(body.velocity.x, desired.x, response * delta)
	body.velocity.z = move_toward(body.velocity.z, desired.z, response * delta)
	if jump_impulse > 0.0 and body.is_on_floor():
		body.velocity.y = jump_impulse
	elif body.is_on_floor():
		# A small downward bias keeps the capsule attached to descending ramps;
		# floor snap handles steps without turning them into tiny jumps.
		body.velocity.y = -FLOOR_STICK
	else:
		body.velocity.y -= GRAVITY * delta
	body.move_and_slide()
