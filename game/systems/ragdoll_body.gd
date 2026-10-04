class_name RagdollBody
extends Node3D

## Turns the exact rendered BaselineHuman zones into a restrained corpse rig.
## No duplicate mannequin is created: scars, clothes, organs, bone exposure,
## and X-ray state all remain on the same nodes the living body used.

const BODY_LAYER := 1 << 6
const WORLD_MASK := 1
const MAX_KILLING_IMPULSE := 16.0
const BASE_IMPULSE_SPEED := 0.12
const MAX_BODY_SPEED := 6.0
const SETTLE_LINEAR_SPEED := 0.18
const SETTLE_ANGULAR_SPEED := 0.28
const SETTLE_SECONDS := 0.65
const FREEZE_AFTER_SLEEP_SECONDS := 0.25
const FORCE_FREEZE_SECONDS := 3.0

const ATTACK_LAUNCH := {
	"light": {"speed": 0.22, "lift": 0.0},
	"heavy": {"speed": 5.55, "lift": 0.0, "damp": 1.55},
	"poise_break": {"speed": 3.40, "lift": 4.50, "damp": 1.0, "initial_lift": 0.07},
}

const JOINT_LIMITS := {
	"head": Vector2(-0.42, 0.42),
	"left_arm": Vector2(-1.05, 1.05),
	"right_arm": Vector2(-1.05, 1.05),
	"left_leg": Vector2(-0.78, 0.78),
	"right_leg": Vector2(-0.78, 0.78),
}

const MASSES := {
	"torso": 28.0,
	"head": 5.0,
	"left_arm": 4.0,
	"right_arm": 4.0,
	"left_leg": 8.0,
	"right_leg": 8.0,
}

const JOINTS := [
	["torso", "head"],
	["torso", "left_arm"],
	["torso", "right_arm"],
	["torso", "left_leg"],
	["torso", "right_leg"],
]

var bodies: Dictionary = {}
var source: BaselineHuman
var attack_id := ""
var settled := false
var slept := false
var _quiet_seconds := 0.0
var _alive_seconds := 0.0
var _sleep_seconds := 0.0
var _lift_seconds := 0.0


func activate(rig: BaselineHuman, hit_zone: String, impulse: float, direction: Vector3, killing_attack_id := "") -> void:
	# Physics bodies must begin in world space. A ragdoll under a translated
	# actor holder otherwise appears to the physics server at the holder origin
	# and is teleported into place on its first frame; that phantom move was the
	# exact 4 -> 4, 10 -> 10, 16 -> 16 m/s kick from the regression probe.
	top_level = true
	global_transform = Transform3D.IDENTITY
	source = rig
	attack_id = killing_attack_id.strip_edges().to_lower()
	name = "%s_ragdoll" % rig.subject_id
	# Sandbox bodies are nested below a movable holder. A physics island must
	# live in world space once the body dies; inheriting the holder's +0.9/-0.9
	# compensation on the solver's first frame can turn that transform delta
	# into a violent launch. The original parts are reparented with globals kept,
	# so making this neutral world-space container does not move the corpse.
	top_level = true
	global_transform = Transform3D.IDENTITY
	for zone_id in BaselineHuman.ZONES:
		if rig.severed.has(zone_id):
			continue
		var part := rig.parts.get(zone_id) as MeshInstance3D
		if part == null or not is_instance_valid(part) or not part.is_inside_tree():
			continue
		var body := _make_body(str(zone_id), part)
		bodies[zone_id] = body
		var hitbox := rig.get_node_or_null("%s_hitbox" % zone_id) as Area3D
		part.reparent(body, true)
		if hitbox != null:
			hitbox.reparent(body, true)

	for pair in JOINTS:
		_add_joint(str(pair[0]), str(pair[1]))

	var struck := bodies.get(BaselineHuman.canonical_zone(hit_zone)) as RigidBody3D
	if struck == null:
		struck = bodies.get("torso") as RigidBody3D
	if struck != null:
		_launch(struck, impulse, direction)
	set_physics_process(true)


func _launch(struck: RigidBody3D, impulse: float, direction: Vector3) -> void:
	var heading := direction
	heading.y = 0.0
	heading = heading.normalized() if heading.length_squared() > 0.001 else Vector3.FORWARD
	var speed := clampf(maxf(impulse, 1.0), 1.0, MAX_KILLING_IMPULSE) * BASE_IMPULSE_SPEED
	var lift := 0.0
	var launch_class := _attack_launch_class(attack_id)
	if ATTACK_LAUNCH.has(launch_class):
		var profile: Dictionary = ATTACK_LAUNCH[launch_class]
		speed = float(profile.speed)
		lift = float(profile.lift)
		_lift_seconds = 0.06 if launch_class == "poise_break" else 0.0
	var launch := heading * speed + Vector3.UP * lift
	if launch.length() > MAX_BODY_SPEED:
		launch = launch.normalized() * MAX_BODY_SPEED
	global_position += Vector3.UP * float((ATTACK_LAUNCH.get(launch_class, {}) as Dictionary).get("initial_lift", 0.0))
	# Moving every connected part in the same broad direction avoids a single
	# tiny limb yanking the whole rig through a joint. A smaller struck-part
	# bias gives the body a fold without explosive torque or floor skating.
	for body_value in bodies.values():
		var body := body_value as RigidBody3D
		if body == null:
			continue
		body.linear_damp = float((ATTACK_LAUNCH.get(launch_class, {}) as Dictionary).get("damp", 3.2))
		var carry := 1.0 if launch_class == "poise_break" or body.name.begins_with("torso") else 0.76
		body.linear_velocity = launch * carry
		body.angular_velocity = Vector3.ZERO
	var strike_bias := heading * minf(0.42, speed * 0.12)
	struck.linear_velocity = _limited_velocity(struck.linear_velocity + strike_bias)
	struck.angular_velocity = Vector3(0.0, minf(speed * 0.16, 0.75), -heading.x * minf(speed * 0.22, 1.0))


func _attack_launch_class(id: String) -> String:
	if id == "charged_heavy":
		return "poise_break"
	if id in ["heavy", "running_attack", "roll_attack"]:
		return "heavy"
	if id.begins_with("light_"):
		return "light"
	return ""


func _limited_velocity(velocity: Vector3) -> Vector3:
	return velocity.normalized() * MAX_BODY_SPEED if velocity.length() > MAX_BODY_SPEED else velocity


func _make_body(zone_id: String, part: MeshInstance3D) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "%s_physics" % zone_id
	body.mass = float(MASSES.get(zone_id, 5.0))
	body.collision_layer = BODY_LAYER
	body.collision_mask = WORLD_MASK
	body.continuous_cd = true
	body.can_sleep = true
	body.linear_damp = 3.2
	body.angular_damp = 5.2
	var contact := PhysicsMaterial.new()
	contact.friction = 0.88
	contact.rough = true
	contact.bounce = 0.0
	body.physics_material_override = contact
	add_child(body)
	body.global_transform = part.global_transform

	var collider := CollisionShape3D.new()
	collider.name = "%s_shape" % zone_id
	var bounds := part.get_aabb()
	var size := bounds.size * part.scale.abs()
	if zone_id == "head":
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(0.08, maxf(size.x, maxf(size.y, size.z)) * 0.5)
		collider.shape = sphere
	elif zone_id == "torso":
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(size.x, 0.16), maxf(size.y, 0.24), maxf(size.z, 0.12))
		collider.shape = box
	else:
		var capsule := CapsuleShape3D.new()
		var length := maxf(size.x, maxf(size.y, size.z))
		var width := maxf(0.045, minf(size.x, minf(size.y, size.z)) * 0.5)
		capsule.radius = width
		capsule.height = maxf(length, width * 2.0 + 0.01)
		collider.shape = capsule
	body.add_child(collider)
	return body


func _add_joint(zone_a: String, zone_b: String) -> void:
	var body_a := bodies.get(zone_a) as RigidBody3D
	var body_b := bodies.get(zone_b) as RigidBody3D
	if body_a == null or body_b == null:
		return
	var joint := Generic6DOFJoint3D.new()
	joint.name = "%s_to_%s" % [zone_a, zone_b]
	add_child(joint)
	joint.global_position = (body_a.global_position + body_b.global_position) * 0.5
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	# Translation is locked by default. Neck, shoulder and hip limits differ,
	# remaining inside an ordinary human range instead of one elastic rope.
	var limits: Vector2 = JOINT_LIMITS.get(zone_b, Vector2(-0.65, 0.65))
	for axis in ["x", "y", "z"]:
		joint.set("angular_limit_%s/enabled" % axis, true)
		joint.set("angular_limit_%s/lower_angle" % axis, limits.x)
		joint.set("angular_limit_%s/upper_angle" % axis, limits.y)


func _physics_process(delta: float) -> void:
	if settled:
		return
	if _lift_seconds > 0.0:
		_lift_seconds = maxf(0.0, _lift_seconds - delta)
		for body_value in bodies.values():
			var lifted_body := body_value as RigidBody3D
			if lifted_body != null:
				lifted_body.apply_central_force(Vector3.UP * lifted_body.mass * 20.0)
	_alive_seconds += delta
	if slept:
		_sleep_seconds += delta
		if _sleep_seconds >= FREEZE_AFTER_SLEEP_SECONDS or _alive_seconds >= FORCE_FREEZE_SECONDS:
			freeze_settled()
		return
	var all_quiet := not bodies.is_empty()
	for body_value in bodies.values():
		var body := body_value as RigidBody3D
		if body == null or not is_instance_valid(body):
			continue
		if body.linear_velocity.length() > SETTLE_LINEAR_SPEED or body.angular_velocity.length() > SETTLE_ANGULAR_SPEED:
			all_quiet = false
			break
	_quiet_seconds = _quiet_seconds + delta if all_quiet else 0.0
	if _quiet_seconds >= SETTLE_SECONDS:
		for body_value in bodies.values():
			var body := body_value as RigidBody3D
			if body != null and is_instance_valid(body):
				body.sleeping = true
		slept = true
	elif _alive_seconds >= FORCE_FREEZE_SECONDS:
		freeze_settled()


func freeze_settled() -> void:
	if settled:
		return
	for body_value in bodies.values():
		var body := body_value as RigidBody3D
		if body == null or not is_instance_valid(body):
			continue
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = true
		body.freeze = true
	slept = true
	settled = true
	set_physics_process(false)


func all_frozen() -> bool:
	if bodies.is_empty():
		return false
	for body_value in bodies.values():
		var body := body_value as RigidBody3D
		if body == null or not is_instance_valid(body) or not body.freeze:
			return false
	return true
