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
## Ramming reads as discrete blows rather than one long scrape: a pair that has
## just traded a hit cannot score again until this elapses.
const CONTACT_LOCKOUT_MSEC := 520
## Grip is a friction limit, not a spring. Uncapped lateral correction cancels a
## side impact within one frame, which is what made every ram feel weightless.
const MAX_LATERAL_GRIP := 11.5
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

var throttle := 0.0
var steering := 0.0
var enabled := false
var previous_velocity := Vector3.ZERO
var contact_cooldowns: Dictionary = {}
var signed_speed := 0.0
var stun := 0.0
var contact_seconds := 0.0
var grind_side := 1.0

func _ready() -> void:
	mass = 1100.0
	linear_damp = 0.15
	angular_damp = 3.0
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	var material := PhysicsMaterial.new()
	material.friction = 0.25
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
	var forward := -state.transform.basis.z
	var right := state.transform.basis.x
	signed_speed = state.linear_velocity.dot(forward)
	var lateral_speed := state.linear_velocity.dot(right)
	stun = maxf(0.0, stun - state.step)
	if enabled:
		var grip := STUN_GRIP if stun > 0.0 else 1.0
		var lateral_correction := clampf(lateral_speed * 5.0, -MAX_LATERAL_GRIP, MAX_LATERAL_GRIP)
		state.apply_central_force(-right * lateral_correction * mass * grip)
		if stun <= 0.0:
			var target_speed := throttle * (DRIVE_SPEED if throttle >= 0.0 else REVERSE_SPEED)
			var acceleration := clampf((target_speed - signed_speed) * 2.0, -14.0, 12.0)
			state.apply_central_force(forward * acceleration * mass)
			var yaw_target := -steering * clampf(absf(signed_speed) / 8.0, 0.0, 1.0) * 1.55 * signf(signed_speed)
			state.apply_torque(Vector3.UP * (yaw_target - state.angular_velocity.y) * mass * 6.0)
	else:
		state.apply_central_force(-Vector3(state.linear_velocity.x, 0, state.linear_velocity.z) * mass * 5.0)
	_resolve_contacts(state)
	previous_velocity = state.linear_velocity

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
		var id := other.get_instance_id()
		if closing < IMPACT_SPEED or now < int(contact_cooldowns.get(id, 0)):
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

func recover(at: Vector3) -> void:
	global_position = at
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	previous_velocity = Vector3.ZERO
	stun = 0.0
	contact_seconds = 0.0
	contact_cooldowns.clear()
