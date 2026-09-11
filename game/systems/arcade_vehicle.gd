extends RigidBody3D

## Upright arcade chassis. Solver contacts handle momentum and restitution;
## engine and tire forces never replace the body's transform or velocity.
signal impact(other: Node, closing_speed: float)

var throttle := 0.0
var steering := 0.0
var enabled := false
var previous_velocity := Vector3.ZERO
var contact_cooldowns: Dictionary = {}
var signed_speed := 0.0

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
	material.bounce = 0.35
	physics_material_override = material
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.65, 1.3, 4.8)
	collider.shape = box
	add_child(collider)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var forward := -state.transform.basis.z
	var right := state.transform.basis.x
	signed_speed = state.linear_velocity.dot(forward)
	var lateral_speed := state.linear_velocity.dot(right)
	if enabled:
		var target_speed := throttle * (24.0 if throttle >= 0.0 else 10.0)
		var acceleration := clampf((target_speed - signed_speed) * 2.0, -14.0, 12.0)
		state.apply_central_force(forward * acceleration * mass)
		state.apply_central_force(-right * lateral_speed * mass * 5.0)
		var yaw_target := -steering * clampf(absf(signed_speed) / 8.0, 0.0, 1.0) * 1.55 * signf(signed_speed)
		state.apply_torque(Vector3.UP * (yaw_target - state.angular_velocity.y) * mass * 6.0)
	else:
		state.apply_central_force(-Vector3(state.linear_velocity.x, 0, state.linear_velocity.z) * mass * 5.0)
	var now := Time.get_ticks_msec()
	for index in state.get_contact_count():
		var other := state.get_contact_collider_object(index) as Node
		if other == null:
			continue
		var id := other.get_instance_id()
		if now < int(contact_cooldowns.get(id, 0)):
			continue
		var normal := state.get_contact_local_normal(index)
		var other_velocity := state.get_contact_collider_velocity_at_position(index)
		var closing := maxf(0.0, -(previous_velocity - other_velocity).dot(normal))
		if closing >= 4.0:
			contact_cooldowns[id] = now + 650
			impact.emit.call_deferred(other, closing)
	previous_velocity = state.linear_velocity
	if contact_cooldowns.size() > 64:
		for id in contact_cooldowns.keys():
			if now > int(contact_cooldowns[id]):
				contact_cooldowns.erase(id)

func recover(at: Vector3) -> void:
	global_position = at
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	previous_velocity = Vector3.ZERO
	contact_cooldowns.clear()
