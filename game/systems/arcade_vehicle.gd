extends RigidBody3D

## Upright arcade chassis. Solver contacts handle momentum and restitution;
## engine and tire forces never replace the body's transform or velocity.
##
## Impact response lives here rather than in the derby scene because the player
## and the AI wreckers run the same chassis, and a throttle cut applied from a
## driver script is overwritten on that driver's next tick.
signal impact(other: Node, closing_speed: float, self_share: float)

const DRIVE_SPEED := 24.0
const REVERSE_SPEED := 10.0
const IMPACT_SPEED := 4.0
## The rebuilt suspended chassis absorbs some normal velocity before the body
## contact is reported. Measured player-specific peaks are 3.39m/s during a
## clean AI run, while barrier hits still reach well above four. Cars therefore
## use the lower measured threshold; scenery keeps the old one.
const VEHICLE_IMPACT_SPEED := 3.0
## Ramming reads as discrete blows rather than one long scrape: a pair that has
## just traded a hit cannot score again until this elapses.
const CONTACT_LOCKOUT_MSEC := 520
## Grip is a friction limit, not a spring. Uncapped lateral correction cancels a
## side impact within one frame, which is what made every ram feel weightless.
const MAX_LATERAL_GRIP := 11.5

## --- A7: the suspension model -------------------------------------------
##
## Greg, repeatedly: *"the derby map is way too tiny"*, *"the map is pretty
## broken"*, *"still not like a driveable wheel adapted suspension system"*. The
## venue was re-authored twice against the first complaint and measured worse
## both times, which was the clue: **the venue was never the problem.** The car
## was a single rigid box held up by a physics material, driven by a central
## force and turned by a yaw torque applied directly to the body. Nothing about
## it behaved like a car, so no arena could feel right around it.
##
## What changes, and why each part matters:
##
## - **Four raycast wheels carry the body.** Forces are applied *at the wheel*
##   rather than at the centre of mass, so weight transfer under brake, throttle
##   and cornering falls out of the physics instead of being faked (A7.2).
## - **Grip is per wheel and proportional to that wheel's load** (A7.3). A
##   lightly loaded inside wheel lets go first, which is what makes a heavy car
##   feel heavy.
## - **Steering is tire force, not torque.** The front wheels point somewhere
##   and the car rotates because of what they do to the ground. This is the
##   fundamental change: the old model could not turn at a standstill because
##   authority was scaled by speed, and that single decision was the root cause
##   of three separate AI failures already recorded in ROADMAP.md.
const WHEEL_ANCHORS := [
	Vector3(-1.02, -0.35, -1.62), Vector3(1.02, -0.35, -1.62),
	Vector3(-1.02, -0.35, 1.66), Vector3(1.02, -0.35, 1.66),
]
## Front wheels steer, rear wheels drive. A derby car is rear-wheel drive and
## that is not a detail: it is why it can be kicked sideways.
const FRONT_WHEELS := [0, 1]
const REAR_WHEELS := [2, 3]
## Matched to `art/scrap_skiff.glb`, which is what the car actually looks like:
## its wheel meshes are 0.70 units tall, so the radius is 0.35. This was 0.30,
## measured against nothing, and the gap is why the visible wheels could never
## sit on the surface the physics was standing on.
const WHEEL_RADIUS := 0.35
const SUSPENSION_REST := 0.35
## Expressed as multiples of mass so the ride height does not change if the
## chassis is ever made heavier or lighter.
## Each wheel pushes back with `compression * SPRING_RATE * mass * 0.25`, so at
## rest four wheels carry `SPRING_RATE * compression * mass`, and equilibrium is
## `compression = gravity / SPRING_RATE`.
##
## At 26 that is 9.8 / 26 = 0.377 — **larger than SUSPENSION_REST**. The spring
## could not hold the car up, compression clamped at 0.35 every frame, and the
## derby has been driving around bottomed out on its bump stops since the
## suspension model was written. The chassis half-height is 0.65 and the ground
## sat at exactly -0.65 in body space, which is to say the hull was resting on
## the floor: Greg's "dragging", measured.
##
## 82 puts equilibrium at 0.12, a little under a third of available travel,
## which is where a road car sits and leaves real compression for a landing
## instead of spending it all standing still.
const SPRING_RATE := 82.0
const SPRING_DAMP := 4.4
## Roughly 30 degrees of lock.
const MAX_STEER := 0.52
## Coefficient of friction at the contact patch. Arcade-sticky on purpose.
const TIRE_GRIP := 1.75
const LATERAL_STIFFNESS := 5.2
## A7.5. Tuned against the new model, not carried over from the old one. The
## first pass at 6.4 asked for 1760N per rear wheel against a ~4700N grip
## limit, so the car accelerated at about a third of the servo it replaced and
## the AI stopped being able to land a blow at all - the balance test caught a
## parked player taking zero damage across a full heat. At 18 the request sits
## just over the limit, so acceleration is grip-limited with a little wheelspin,
## which is both quicker and more honest than a force that always gets its way.
const DRIVE_FORCE := 18.0
const BRAKE_FORCE := 5.0
const ROLLING_DRAG := 0.7
## Cars lean and can be put onto two wheels, but a derby that ends with everyone
## upside down is not a derby. This is A7.4's answer and it is deliberately a
## soft limit rather than the old hard axis lock.
const ANTI_ROLL := 5.5
const UPRIGHT_RECOVERY := 2.2
## Drive and steering are both cut while stunned. The drive model is a strong
## servo targeting a speed and a heading, and at full authority it erases any
## perturbation an impact introduces before the next frame renders.
const STUN_SECONDS := 0.42
const STUN_GRIP := 0.25
## Both bodies apply restitution, so a pair already parts at roughly twice the
## material bounce — measured at 0.67 effective with bounce 0.35. The kick below
## only guarantees separation at moderate speed; the solver does the rest, and
## raising either turns the pit into pinball. See tests/impact_test.gd.
const SEPARATION_GAIN := 0.06
const MAX_SEPARATION := 1.5
## The real feel win. A box collider barely spins on a corner hit, so the yaw is
## authored: clip a wreck on the nose and it slews out of your way.
const SPIN_SHARE := 0.4
const MAX_SPIN := 2.3
## Two cars leaning on each other never reach IMPACT_SPEED, so no impact fires
## and nothing in the solver breaks the stalemate. A continuous repulsion force
## does not fix it either — the drive servo simply out-pushes it and re-closes
## any gap. After a sustained press they are kicked apart as a discrete event.
const GRIND_TRIGGER := 0.45
const SHOVE_IMPULSE := 3.5
const SHOVE_SPIN := 1.2
const SHOVE_STUN := 0.35
## Nobody in a derby sits still with the throttle buried. A car that cannot make
## progress backs itself out and swings clear, so neither the player nor the pit
## ever needs a reset key to get moving again.
const STUCK_SPEED := 1.2
const STUCK_SECONDS := 2.0
const UNSTICK_IMPULSE := 4.5

var throttle := 0.0
var steering := 0.0
## Highest normal closing speed seen at a real body contact. Kept as telemetry
## so balance tests can distinguish "never touched" from "threshold too high".
var max_contact_closing := 0.0
var max_vehicle_contact_closing := 0.0
var vehicle_contact_peaks: Dictionary = {}
var enabled := false
var previous_velocity := Vector3.ZERO
var contact_cooldowns: Dictionary = {}
var signed_speed := 0.0
var stun := 0.0
var contact_seconds := 0.0
var stuck_seconds := 0.0
var grind_side := 1.0
## Godot's own default, and the value the derby actually falls at. Named here
## because the rest height below is solved against it rather than measured by
## dropping a car and squinting.
const GRAVITY := 9.8


## How far the suspension is compressed when the car is simply standing still.
##
## Solved, not tuned: four wheels each returning `c * SPRING_RATE * mass * 0.25`
## carry `c * SPRING_RATE * mass`, which balances `GRAVITY * mass` at
## `c = GRAVITY / SPRING_RATE`. Clamped the same way the per-frame force is, so
## if a future spring rate is ever too soft again this reports the bottomed-out
## value rather than a number the car cannot actually reach.
static func rest_compression() -> float:
	return minf(GRAVITY / SPRING_RATE, SUSPENSION_REST)


## True when the spring cannot hold the car up at all and it is riding on its
## bump stops. Worth being able to ask, because the symptom — a car that drags,
## bottoms on every bump and has no travel left to absorb a landing — reads as
## ten different handling problems rather than as one wrong constant.
static func bottomed_out() -> bool:
	return GRAVITY / SPRING_RATE >= SUSPENSION_REST


## Where the ground is, in the chassis's own space, with the car at rest. This
## is the number anything hanging a wheel or a body shell off the chassis needs,
## and the only correct source for it is the suspension model itself.
static func rest_contact_y() -> float:
	var anchor: Vector3 = WHEEL_ANCHORS[0]
	return anchor.y - (SUSPENSION_REST + WHEEL_RADIUS - rest_compression())


## Per-wheel state, kept for the AI, the audio and the camera to read.
var wheel_contacts := [false, false, false, false]
var wheel_loads := [0.0, 0.0, 0.0, 0.0]
var wheel_slip := 0.0
var airborne := false
## Physics normally guarantees finite transforms, but a high-speed compound
## contact is precisely where that guarantee matters most.  Retaining the last
## good body state gives a bad contact a safe recovery path instead of letting
## NaN values poison every wheel ray and appear to hard-freeze the game.
var _last_safe_transform := Transform3D.IDENTITY
var _has_safe_transform := false

func _ready() -> void:
	mass = 1100.0
	linear_damp = 0.15
	angular_damp = 1.6
	# A7.4. The old model locked pitch and roll outright, which is why the car
	# read as a slab on rails. The suspension now carries the body and an
	# anti-roll term keeps it drivable, so it leans, dives and can be tipped -
	# without the heat ending with twelve cars on their roofs.
	axis_lock_angular_x = false
	axis_lock_angular_z = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	var material := PhysicsMaterial.new()
	# The body itself is nearly frictionless now. Grip belongs to the tires; a
	# sliding box that also grips is two conflicting models fighting each other.
	material.friction = 0.05
	material.bounce = 0.22
	physics_material_override = material
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.65, 1.3, 4.8)
	collider.shape = box
	add_child(collider)
	# Neighbouring cars slew opposite ways off a stalemate instead of shuffling
	# together in the same direction.
	grind_side = 1.0 if get_instance_id() % 2 == 0 else -1.0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var transform := state.transform
	if not _state_is_finite(transform, state.linear_velocity, state.angular_velocity):
		_restore_safe_state(state)
		return
	_last_safe_transform = transform
	_has_safe_transform = true
	var forward := -transform.basis.z
	var right := transform.basis.x
	var up := transform.basis.y
	signed_speed = state.linear_velocity.dot(forward)
	stun = maxf(0.0, stun - state.step)

	var space := get_world_3d().direct_space_state
	var grounded := 0
	var total_load := 0.0
	wheel_slip = 0.0
	var steer := clampf(-steering, -1.0, 1.0) * MAX_STEER
	# Lock tightens with speed, the way a real rack loads up. Note this does not
	# reduce *authority* at low speed the way the old servo did - at a standstill
	# the wheels still point, they simply have nothing to push against yet.
	steer *= lerpf(1.0, 0.45, clampf(absf(signed_speed) / DRIVE_SPEED, 0.0, 1.0))

	for index in WHEEL_ANCHORS.size():
		var anchor: Vector3 = WHEEL_ANCHORS[index]
		var world_anchor := transform * anchor
		var reach := SUSPENSION_REST + WHEEL_RADIUS
		var query := PhysicsRayQueryParameters3D.create(world_anchor, world_anchor - up * reach)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			wheel_contacts[index] = false
			wheel_loads[index] = 0.0
			continue
		wheel_contacts[index] = true
		grounded += 1

		# `intersect_ray` returns the hit under "position"; there is no "point".
		var contact: Vector3 = hit.position
		var offset := contact - state.transform.origin
		var point_velocity := state.linear_velocity + state.angular_velocity.cross(offset)

		# --- suspension ---------------------------------------------------
		var distance := world_anchor.distance_to(contact)
		var compression := clampf(reach - distance, 0.0, SUSPENSION_REST)
		var travel_speed := point_velocity.dot(up)
		var spring := compression * SPRING_RATE * mass * 0.25
		var damper := travel_speed * SPRING_DAMP * mass * 0.25
		var load := maxf(0.0, spring - damper)
		wheel_loads[index] = load
		total_load += load
		state.apply_force(up * load, offset)

		# --- tire ---------------------------------------------------------
		# Grip is a friction limit against this wheel's own load, which is what
		# makes weight transfer matter rather than just look like it does.
		var limit := load * TIRE_GRIP
		var steered := forward if not FRONT_WHEELS.has(index) else forward.rotated(up, steer).normalized()
		var lateral_axis := steered.cross(up).normalized()
		var lateral_speed := point_velocity.dot(lateral_axis)
		var lateral_force := clampf(-lateral_speed * LATERAL_STIFFNESS * mass * 0.25, -limit, limit)
		if absf(lateral_speed) * LATERAL_STIFFNESS * mass * 0.25 > limit:
			wheel_slip = maxf(wheel_slip, clampf(absf(lateral_speed) / 8.0, 0.0, 1.0))
		state.apply_force(lateral_axis * lateral_force, offset)

		var rolling := point_velocity.dot(steered)
		var longitudinal := 0.0
		if enabled and stun <= 0.0 and REAR_WHEELS.has(index):
			var target := throttle * (DRIVE_SPEED if throttle >= 0.0 else REVERSE_SPEED)
			if absf(throttle) > 0.05:
				longitudinal = signf(target - rolling) * DRIVE_FORCE * mass * 0.25 * absf(throttle)
				if absf(rolling) > absf(target):
					longitudinal = 0.0
			else:
				longitudinal = -rolling * BRAKE_FORCE * mass * 0.25 * 0.2
		elif not enabled:
			longitudinal = -rolling * BRAKE_FORCE * mass * 0.25
		longitudinal -= rolling * ROLLING_DRAG * mass * 0.25 * 0.1
		longitudinal = clampf(longitudinal, -limit, limit)
		state.apply_force(steered * longitudinal, offset)

	airborne = grounded == 0

	# --- anti-roll and self-righting --------------------------------------
	# A7.4 in practice. Leaning is wanted; ending the heat on your roof is not.
	if grounded > 0:
		var lean := up.cross(Vector3.UP)
		state.apply_torque(lean * ANTI_ROLL * mass * 0.5)
	elif up.dot(Vector3.UP) < 0.2:
		# On its back with no wheels down, nothing can recover it, so help.
		var righting := up.cross(Vector3.UP)
		state.apply_torque(righting * UPRIGHT_RECOVERY * mass)

	# The stuck rule predates this rework and still earns its place: a wedged car
	# has to be able to back itself out without the player reaching for a key.
	if enabled and stun <= 0.0 and absf(throttle) > 0.25 and absf(signed_speed) < STUCK_SPEED:
		stuck_seconds += state.step
		if stuck_seconds >= STUCK_SECONDS:
			_shunt_free(state, forward)
	else:
		stuck_seconds = 0.0
	_resolve_contacts(state)
	previous_velocity = state.linear_velocity


func _state_is_finite(transform: Transform3D, linear: Vector3, angular: Vector3) -> bool:
	return _vector_is_finite(transform.origin) \
		and _vector_is_finite(transform.basis.x) \
		and _vector_is_finite(transform.basis.y) \
		and _vector_is_finite(transform.basis.z) \
		and _vector_is_finite(linear) \
		and _vector_is_finite(angular)


func _vector_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _restore_safe_state(state: PhysicsDirectBodyState3D) -> void:
	state.transform = _last_safe_transform if _has_safe_transform else Transform3D.IDENTITY
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	previous_velocity = Vector3.ZERO
	signed_speed = 0.0
	wheel_slip = 0.0
	stun = STUN_SECONDS
	contact_seconds = 0.0
	stuck_seconds = 0.0


func _resolve_contacts(state: PhysicsDirectBodyState3D) -> void:
	var now := Time.get_ticks_msec()
	var pressed := Vector3.ZERO
	for index in state.get_contact_count():
		var other := state.get_contact_collider_object(index) as Node
		if other == null:
			continue
		var normal := state.get_contact_local_normal(index)
		var flat := Vector3(normal.x, 0.0, normal.z)
		var side_on := flat.length() > 0.35
		# Only cars stalemate each other. A car nosed into a barrier just needs
		# to reverse out, and shoving it off the wall would read as magic.
		if side_on and other.get_script() == get_script():
			pressed += flat.normalized()
		var other_velocity := state.get_contact_collider_velocity_at_position(index)
		var closing := maxf(0.0, -(previous_velocity - other_velocity).dot(normal))
		max_contact_closing = maxf(max_contact_closing, closing)
		if other.get_script() == get_script():
			max_vehicle_contact_closing = maxf(max_vehicle_contact_closing, closing)
			vehicle_contact_peaks[other.get_instance_id()] = maxf(float(vehicle_contact_peaks.get(other.get_instance_id(), 0.0)), closing)
		var id := other.get_instance_id()
		var impact_threshold := VEHICLE_IMPACT_SPEED if other.get_script() == get_script() else IMPACT_SPEED
		if closing < impact_threshold or now < int(contact_cooldowns.get(id, 0)):
			continue
		contact_cooldowns[id] = now + CONTACT_LOCKOUT_MSEC
		if side_on:
			_kick_apart(state, index, normal, closing)
		# How much of the closing speed this body brought decides which car wears
		# the damage, so parking in the pit is not a way to farm wrecks.
		var self_share := clampf(maxf(0.0, -previous_velocity.dot(normal)) / maxf(closing, 0.01), 0.0, 1.0)
		impact.emit.call_deferred(other, closing, self_share)
	if pressed.length_squared() > 0.0:
		contact_seconds += state.step
		if contact_seconds >= GRIND_TRIGGER:
			_shove_off(state, pressed.normalized())
	else:
		# Resting contacts drop in and out of the report between solver
		# iterations, so a missing frame is not separation. Decaying rather than
		# clearing keeps a genuine press accumulating toward the trigger.
		contact_seconds = maxf(0.0, contact_seconds - state.step * 0.5)
	if contact_cooldowns.size() > 64:
		for id in contact_cooldowns.keys():
			if now > int(contact_cooldowns[id]):
				contact_cooldowns.erase(id)

func _kick_apart(state: PhysicsDirectBodyState3D, index: int, normal: Vector3, closing: float) -> void:
	var separation := clampf(closing * SEPARATION_GAIN, 0.0, MAX_SEPARATION)
	var linear := normal * separation * mass
	state.apply_central_impulse(linear)
	if state.inverse_inertia.y > 0.0:
		var offset := state.get_contact_local_position(index) - state.transform.origin
		var yaw := clampf(offset.cross(linear).y * state.inverse_inertia.y * SPIN_SHARE, -MAX_SPIN, MAX_SPIN)
		state.apply_torque_impulse(Vector3.UP * yaw / state.inverse_inertia.y)
	stun = STUN_SECONDS * clampf(closing / 12.0, 0.35, 1.0)
	contact_seconds = 0.0

func _shove_off(state: PhysicsDirectBodyState3D, away: Vector3) -> void:
	state.apply_central_impulse(away * SHOVE_IMPULSE * mass)
	if state.inverse_inertia.y > 0.0:
		state.apply_torque_impulse(Vector3.UP * grind_side * SHOVE_SPIN / state.inverse_inertia.y)
	# The stun is what makes this stick: without it the drive servo closes the
	# gap again on the next frame and the pair settles into a limit cycle.
	stun = maxf(stun, SHOVE_STUN)
	contact_seconds = 0.0

func _shunt_free(state: PhysicsDirectBodyState3D, forward: Vector3) -> void:
	state.apply_central_impulse(-forward * signf(throttle) * UNSTICK_IMPULSE * mass)
	if state.inverse_inertia.y > 0.0:
		state.apply_torque_impulse(Vector3.UP * grind_side * SHOVE_SPIN / state.inverse_inertia.y)
	stun = maxf(stun, SHOVE_STUN)
	stuck_seconds = 0.0
	contact_seconds = 0.0

func recover(at: Vector3) -> void:
	global_position = at
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	previous_velocity = Vector3.ZERO
	stun = 0.0
	contact_seconds = 0.0
	stuck_seconds = 0.0
	contact_cooldowns.clear()
