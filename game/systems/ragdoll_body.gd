class_name RagdollBody
extends Node3D

## Turns the exact rendered BaselineHuman zones into a restrained corpse rig.
## No duplicate mannequin is created: scars, clothes, organs, bone exposure,
## and X-ray state all remain on the same nodes the living body used.

const BODY_LAYER := 1 << 6
const WORLD_MASK := 1
const MAX_KILLING_IMPULSE := 16.0
const SETTLE_LINEAR_SPEED := 0.18
const SETTLE_ANGULAR_SPEED := 0.28
const SETTLE_SECONDS := 0.65
const FREEZE_AFTER_SLEEP_SECONDS := 0.25
const FORCE_FREEZE_SECONDS := 3.0

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
var settled := false
var slept := false
var _quiet_seconds := 0.0
var _alive_seconds := 0.0
var _sleep_seconds := 0.0


func activate(rig: BaselineHuman, hit_zone: String, impulse: float, direction: Vector3) -> void:
	source = rig
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
		var heading := direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
		var strength := clampf(maxf(impulse, 1.0), 1.0, MAX_KILLING_IMPULSE)
		struck.apply_central_impulse(heading * strength * struck.mass * 0.12)
		struck.apply_torque_impulse(Vector3(0.0, strength * 0.08, -heading.x * strength * 0.12) * struck.mass)
		var core := bodies.get("torso") as RigidBody3D
		if core != null and core != struck:
			core.apply_central_impulse(heading * strength * core.mass * 0.055)
	set_physics_process(true)


func _make_body(zone_id: String, part: MeshInstance3D) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "%s_physics" % zone_id
	body.mass = float(MASSES.get(zone_id, 5.0))
	body.collision_layer = BODY_LAYER
	body.collision_mask = WORLD_MASK
	body.continuous_cd = true
	body.can_sleep = true
	body.linear_damp = 3.2
	body.angular_damp = 4.4
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
	# Translation is locked by default. These conservative angular limits make
	# the corpse give at shoulders and hips without turning into elastic rope.
	for axis in ["x", "y", "z"]:
		joint.set("angular_limit_%s/enabled" % axis, true)
		joint.set("angular_limit_%s/lower_angle" % axis, -0.72)
		joint.set("angular_limit_%s/upper_angle" % axis, 0.72)


func _physics_process(delta: float) -> void:
	if settled:
		return
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
