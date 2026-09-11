class_name DerbyAIDriver
extends Node

## Drives an ArcadeVehicle the same way the player does: by setting throttle and
## steering, never by writing linear_velocity. Writing velocity each frame
## silently discards the solver's collision response, which makes every ram read
## as weightless no matter how much damage it scores.

## Enough speed to retain steering authority, well under a committed charge.
const CREEP_THROTTLE := 0.35

var arena_limit := 26.0
var vehicle: RigidBody3D
var aggression := 1.0
var skill := 1.0
var wander_phase := 0.0
var recover_timer := 0.0


func configure(body: RigidBody3D, driver_seed: int) -> void:
	vehicle = body
	var variance := float(driver_seed % 7) / 7.0
	aggression = 0.72 + variance * 0.55
	skill = 0.58 + float((driver_seed * 3) % 5) / 5.0 * 0.38
	wander_phase = float(driver_seed) * 1.37


func tick(delta: float, target_position: Vector3, active: bool) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	vehicle.enabled = active
	if not active:
		vehicle.throttle = 0.0
		vehicle.steering = 0.0
		return
	wander_phase += delta * (0.7 + aggression * 0.5)
	var destination := target_position
	var from_centre := Vector3(vehicle.global_position.x, 0.0, vehicle.global_position.z)
	if from_centre.length() > arena_limit:
		destination = Vector3.ZERO
		recover_timer = 0.9
	elif recover_timer > 0.0:
		recover_timer -= delta
		destination = Vector3.ZERO

	var to_target := destination - vehicle.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.35:
		vehicle.throttle = 0.0
		vehicle.steering = 0.0
		return

	var forward := -vehicle.global_transform.basis.z
	var right := vehicle.global_transform.basis.x
	var heading := to_target / distance
	# Imperfect aim: low-skill drivers drift wide and clip barriers, which is the
	# behaviour that makes a derby pit feel populated rather than choreographed.
	var wander := sin(wander_phase) * (1.0 - skill) * 0.55
	var lateral := clampf(heading.dot(right) * 2.2 + wander, -1.0, 1.0)
	var alignment := heading.dot(forward)

	vehicle.steering = lateral
	if alignment < -0.25:
		# Facing away: reverse out rather than grinding a slow circle.
		vehicle.throttle = -0.65
		vehicle.steering = -lateral
	else:
		var closing := clampf(alignment, 0.0, 1.0)
		# Never coast to a stop while turning. The chassis scales steering
		# authority by speed, so a car side-on to its target had zero throttle
		# from `closing` and therefore zero ability to turn back toward it — a
		# permanent deadlock that left the pit standing still.
		#
		# There is deliberately no distance falloff. The old charge term eased
		# off as the gap closed, so wreckers arrived at walking pace and never
		# reached the impact threshold. A derby driver commits to the hit.
		vehicle.throttle = maxf(CREEP_THROTTLE, clampf(closing * aggression, 0.0, 1.0))
