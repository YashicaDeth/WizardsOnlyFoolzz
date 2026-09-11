class_name DerbyAIDriver
extends Node

## Drives an ArcadeVehicle the same way the player does: by setting throttle and
## steering, never by writing linear_velocity. Writing velocity each frame
## silently discards the solver's collision response, which makes every ram read
## as weightless no matter how much damage it scores.

## Enough speed to retain steering authority, well under a committed charge.
const CREEP_THROTTLE := 0.35
## A car that has decided to reverse out commits to it. Without this the
## alignment test flips on the frame it crosses the threshold, and the car
## alternates creep-forward and reverse — both at full lock, both at about one
## metre per second — for the entire heat. Measured: the nearest wrecker held
## 8.2m from a parked player for thirty seconds, oscillating, and the player
## finished the heat on a full hull.
const REVERSE_COMMIT := 0.85
const REVERSE_EXIT_ALIGNMENT := 0.15
## The chassis scales steering authority by speed, so the slower a car is the
## less it can turn. Creeping is therefore the worst possible response to being
## pointed the wrong way: it needs *more* throttle to recover, not less.
const TURN_SPEED := 4.2
const TURN_THROTTLE := 0.72

## How long a driver may stay pressed against its target before breaking off.
## Without this a wrecker that reaches the player simply leans on them forever,
## which is what turned the pit into a static scrum: eight of twelve cars were
## measured stationary and wedged after twenty seconds.
const PRESS_LIMIT := 1.9
const BREAK_OFF := 1.35
const PASS_DISTANCE := 11.0
## Close enough to be touching, not merely nearby. Breaking off at conversation
## distance aborted the run before contact and left the pit unable to land a hit
## at all — measured as a parked player finishing a heat on full hull.
## Measured against the rebuilt chassis (A7), not the old rigid box. Two cars
## in contact sit at about 4.0m centre to centre, so the original 3.9m never
## fired. Widening it to 5.4 was worse and the measurement said so: wreckers
## then peeled off at 4.6-6.6m, before ever touching, and orbited the player for
## a whole heat. This sits just above real contact distance so the peel-off
## breaks a genuine stalled shove and nothing else.
const GRIND_RANGE := 4.2
const GRIND_SPEED := 2.6
## G0.1. Pure pursuit aims at the target's centre, but two chassis touch while
## their centres are still about four metres apart. Near that unreachable point
## the desired heading slews sideways every frame and the hunter orbits. Once a
## reasonably aligned car enters this range it commits to a line *through* the
## target instead, keeping a point beyond the other bumper as its destination.
const FINAL_APPROACH_RANGE := 12.0
const FINAL_APPROACH_ALIGNMENT := 0.93
const FINAL_APPROACH_SECONDS := 1.6
const FINAL_APPROACH_OVERSHOOT := 16.0

var arena_limit := 26.0
var vehicle: RigidBody3D
var aggression := 1.0
var skill := 1.0
var wander_phase := 0.0
var recover_timer := 0.0
## "hunt" drives at the target, "circle" orbits the pit waiting for a turn.
var role := "hunt"
var press_timer := 0.0
var reverse_timer := 0.0
var break_off_timer := 0.0
var break_off_heading := Vector3.FORWARD
var final_approach_timer := 0.0
var final_approach_heading := Vector3.FORWARD
var final_approach_count := 0
var max_target_alignment := -1.0


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
	final_approach_timer = maxf(0.0, final_approach_timer - delta)

	# A derby hit should be a pass, not a shove held indefinitely. Once a driver
	# has been on top of its target for PRESS_LIMIT it breaks off, drives clear
	# and comes back round — the same discrete-blow logic the chassis already
	# applies to car-on-car contact, applied to intent rather than to physics.
	var gap := Vector3(target_position.x - vehicle.global_position.x, 0.0, target_position.z - vehicle.global_position.z).length()
	if break_off_timer > 0.0:
		final_approach_timer = 0.0
		break_off_timer -= delta
		destination = vehicle.global_position + break_off_heading * PASS_DISTANCE
		if break_off_timer <= 0.0:
			press_timer = 0.0
	elif gap < GRIND_RANGE and vehicle.linear_velocity.length() < GRIND_SPEED:
		# Only a stalled shove counts. A fast pass through the same space is the
		# hit we want, and must not be interrupted.
		press_timer += delta
		if press_timer >= PRESS_LIMIT:
			press_timer = 0.0
			break_off_timer = BREAK_OFF
			var away := vehicle.global_position - target_position
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.FORWARD
			# Peel off to one side rather than reversing straight back, so the
			# pit reads as cars circling for another run.
			break_off_heading = (away.normalized() + Vector3(-away.z, 0.0, away.x).normalized() * 0.85).normalized()
	else:
		press_timer = maxf(0.0, press_timer - delta * 0.5)

	# A circling driver keeps its distance and its speed up, so the cars waiting
	# their turn still look like a moving pit instead of parked scenery.
	if role == "circle" and break_off_timer <= 0.0:
		final_approach_timer = 0.0
		var offset := vehicle.global_position - target_position
		offset.y = 0.0
		if offset.length() < 0.5:
			offset = Vector3.FORWARD
		var orbit := Vector3(-offset.z, 0.0, offset.x).normalized()
		destination = target_position + offset.normalized() * 15.0 + orbit * 9.0

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
	var approach_alignment := heading.dot(forward)
	if role == "hunt" and break_off_timer <= 0.0:
		if gap <= FINAL_APPROACH_RANGE:
			max_target_alignment = maxf(max_target_alignment, approach_alignment)
		if final_approach_timer <= 0.0 and gap <= FINAL_APPROACH_RANGE and approach_alignment >= FINAL_APPROACH_ALIGNMENT:
			final_approach_timer = FINAL_APPROACH_SECONDS
			final_approach_heading = heading
			final_approach_count += 1
		if final_approach_timer > 0.0:
			# The point stays beyond the target, so the steering gap cannot collapse
			# to zero at bumper distance. This is a run, not another orbit.
			destination = target_position + final_approach_heading * FINAL_APPROACH_OVERSHOOT
			to_target = destination - vehicle.global_position
			to_target.y = 0.0
			distance = maxf(to_target.length(), 0.01)
			heading = to_target / distance
	# Imperfect aim: low-skill drivers drift wide and clip barriers, which is the
	# behaviour that makes a derby pit feel populated rather than choreographed.
	# Inside the approach cone the driver stops showing off and lines the bonnet
	# up. Committing while nearly side-on only produced a faster miss.
	var preparing_approach := role == "hunt" and gap <= FINAL_APPROACH_RANGE and break_off_timer <= 0.0
	var wander := 0.0 if preparing_approach else sin(wander_phase) * (1.0 - skill) * 0.55
	# A7 fallout. A gain of 2.2 saturates this to full lock on anything past a
	# few degrees off-axis, so with the rebuilt tire-steered chassis a wrecker
	# cornered permanently and never straightened up: measured at throttle 0.72
	# and under 2 m/s beside a parked player for a whole heat, while cars out in
	# the open reached 14 m/s. The old yaw-torque chassis hid it because torque
	# snapped the car round regardless. Proportional steering lets a car that is
	# nearly lined up commit to the run instead of scrubbing speed in a turn.
	# Extra rack only while lining up the run. Globally restoring the old 2.2
	# gain makes every car corner permanently; locally, 1.75 closes the last
	# angle before the bumper is committed.
	var steering_gain := 1.75 if preparing_approach and final_approach_timer <= 0.0 else 1.15
	var lateral := clampf(heading.dot(right) * steering_gain + wander, -1.0, 1.0)
	var alignment := heading.dot(forward)

	vehicle.steering = -lateral
	if final_approach_timer > 0.0:
		# Keep correcting toward the point beyond the target, but never attenuate
		# the throttle. This holds a line through the chassis instead of curling
		# toward the unreachable centre at walking speed.
		vehicle.throttle = 1.0
		reverse_timer = 0.0
		return
	reverse_timer = maxf(0.0, reverse_timer - delta)
	if reverse_timer <= 0.0 and alignment < -0.25:
		reverse_timer = REVERSE_COMMIT
	# Hysteresis: having committed to reversing, keep reversing until the nose
	# is genuinely coming round, not merely past the threshold it entered on.
	if reverse_timer > 0.0 and alignment < REVERSE_EXIT_ALIGNMENT:
		# Facing away: reverse out rather than grinding a slow circle.
		vehicle.throttle = -0.65
		vehicle.steering = lateral
	else:
		reverse_timer = 0.0
		var closing := clampf(alignment, 0.0, 1.0)
		# Never coast to a stop while turning. The chassis scales steering
		# authority by speed, so a car side-on to its target had zero throttle
		# from `closing` and therefore zero ability to turn back toward it — a
		# permanent deadlock that left the pit standing still.
		#
		# There is deliberately no distance falloff. The old charge term eased
		# off as the gap closed, so wreckers arrived at walking pace and never
		# reached the impact threshold. A derby driver commits to the hit.
		var floor_throttle := CREEP_THROTTLE
		if vehicle.linear_velocity.length() < TURN_SPEED and absf(lateral) > 0.75:
			floor_throttle = TURN_THROTTLE
		vehicle.throttle = maxf(floor_throttle, clampf(closing * aggression, 0.0, 1.0))
