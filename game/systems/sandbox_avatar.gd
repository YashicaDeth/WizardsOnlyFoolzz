class_name SandboxAvatar
extends Node3D

## The sandbox's player, with a body (Greg, 30 September: the sandbox is where
## melee is tested "for third person and first person"). The range used to be
## a floating eye: V only flipped a flag, so third person never left the head.
## This is a BaselineHuman on the player's feet, a Souls shoulder camera
## blended from the eye the way the Hunt blends its own (bone_yard_hunt.gd
## `_update_camera`), and a lock that holds one body in frame.
##
## The owner keeps its eye, yaw and pitch and hands them in every frame; this
## places the body, faces it, and returns nothing but where the camera went.

const BODY_MOTION := preload("res://systems/hunter_body_motion.gd")

const FIRST_PERSON_FOV := 78.0
const THIRD_PERSON_FOV := 63.0
const BLEND_RATE := 3.2
## How far a lock reaches and how far off the look line it will pick a body.
const LOCK_RANGE := 14.0
const LOCK_CONE := 0.5
## A lock breaks when the body gets this far away or goes down.
const LOCK_BREAK := 18.0
## Third person with no lock: the body turns to where it is being pushed.
const TURN_RATE := 12.0

var rig: BaselineHuman
var motion: HunterBodyMotion
var ring: LockRing
var third_person := false
## 0 = in the eye, 1 = over the shoulder. Slides, never cuts.
var blend := 0.0
## The Node3D holder of the locked body (the sandbox's `holder`), or null.
var lock_target: Node3D
var facing_yaw := 0.0
var _camera_at := Vector3.ZERO
var _camera_ready := false
var _own_colliders: Array[RID] = []


func build() -> void:
	name = "SandboxAvatar"
	rig = BaselineHuman.new()
	rig.name = "PlayerBody"
	add_child(rig)
	rig.build("sandbox_player", {"gore": BaselineHuman.apply_gore_setting(), "blood": 4300.0})
	HunterAppearance.style_world_rig(rig, "sandbox_player", true)
	rig.dress(ClothingShell.humiliation_wardrobe())
	motion = BODY_MOTION.new()
	motion.name = "BodyMotion"
	add_child(motion)
	motion.configure(rig)
	motion.set_perspective(true)
	ring = LockRing.new()
	ring.name = "LockRing"
	add_child(ring)
	for node in rig.find_children("*", "CollisionObject3D", true, false):
		_own_colliders.append((node as CollisionObject3D).get_rid())
	visible = false


## True for anything that belongs to this body, so the owner's traces can pass
## through it: from over the shoulder every shot starts behind your own back.
func owns(node: Node) -> bool:
	return rig != null and node != null and (node == rig or rig.is_ancestor_of(node))


func toggle_lock(bodies: Array, eye: Vector3, look: Vector3) -> bool:
	if lock_target != null:
		release_lock()
		return false
	var best: Node3D = null
	var best_score := INF
	for entry: Dictionary in bodies:
		var holder := entry.get("holder") as Node3D
		var body := entry.get("rig") as BaselineHuman
		if holder == null or not is_instance_valid(holder) or body == null or not is_instance_valid(body) or body.anatomy.dead:
			continue
		var to := holder.global_position - eye
		var distance := to.length()
		if distance > LOCK_RANGE or distance < 0.01:
			continue
		var off_line := 1.0 - to.normalized().dot(look.normalized())
		if off_line > LOCK_CONE:
			continue
		# Near the middle of the view beats merely near.
		var score := off_line * 12.0 + distance
		if score < best_score:
			best_score = score
			best = holder
	lock_target = best
	return best != null


func release_lock() -> void:
	lock_target = null
	if ring != null:
		ring.release()


func locked_rig() -> BaselineHuman:
	if lock_target == null or not is_instance_valid(lock_target):
		return null
	for child in lock_target.get_children():
		if child is BaselineHuman:
			return child as BaselineHuman
	return null


## The yaw the owner should turn toward while locked, eased; unlocked it is
## returned unchanged. Sandbox yaw looks along (-sin, -cos).
func steer_yaw(yaw: float, eye: Vector3, real_delta: float) -> float:
	if lock_target == null or not is_instance_valid(lock_target):
		return yaw
	var to := lock_target.global_position - eye
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return yaw
	return lerp_angle(yaw, atan2(-to.x, -to.z), clampf(real_delta * 9.0, 0.0, 1.0))


## Where a third-person blow goes: at the lock, else the way the body faces.
## First person keeps the camera, so this is only asked for over the shoulder.
func strike_direction(eye: Vector3) -> Vector3:
	if lock_target != null and is_instance_valid(lock_target):
		var to := lock_target.global_position + Vector3.UP * 0.3 - eye
		if to.length_squared() > 0.0001:
			return to.normalized()
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


## Once a physics frame. `eye` is the head, `walk` the ground velocity.
## Returns nothing; places `camera` itself.
func advance(real_delta: float, eye: Vector3, stance_height: float, yaw: float, pitch: float, walk: Vector3,
		dodging: bool, crouching: bool, camera: Camera3D, shove: Vector2, roll: float) -> void:
	if lock_target != null:
		var locked := locked_rig()
		if locked == null or locked.anatomy.dead or locked.anatomy.downed or lock_target.global_position.distance_to(eye) > LOCK_BREAK:
			release_lock()
	blend = move_toward(blend, 1.0 if third_person else 0.0, BLEND_RATE * real_delta)
	var feet := Vector3(eye.x, eye.y - stance_height, eye.z)
	global_position = feet

	# Facing. First person: the view. Locked: the target. Otherwise the body
	# turns into its own movement, which is the Souls free-camera rule.
	var want := yaw
	if third_person and lock_target != null:
		var to := lock_target.global_position - feet
		want = atan2(-to.x, -to.z)
	elif third_person and Vector2(walk.x, walk.z).length() > 0.4:
		want = atan2(-walk.x, -walk.z)
	elif not third_person:
		want = yaw
	else:
		want = facing_yaw
	facing_yaw = lerp_angle(facing_yaw, want, clampf(real_delta * TURN_RATE, 0.0, 1.0)) if blend > 0.0 else want
	rig.rotation.y = facing_yaw
	motion.update(real_delta, walk, true, false, crouching, dodging)

	var look := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var focus := feet + Vector3.UP * 1.5
	var distance := 3.6
	if lock_target != null:
		var gap := feet.distance_to(lock_target.global_position)
		distance = clampf(3.6 + gap * 0.22, 3.6, 6.2)
		focus = focus.lerp(lock_target.global_position + Vector3.UP * 0.9, 0.32)
	var desired := feet + Vector3.UP * 1.75 - look * distance + right * 0.62
	if not _camera_ready:
		_camera_at = desired
		_camera_ready = true
	_camera_at = _camera_at.lerp(desired, clampf(real_delta * (15.0 if lock_target != null else 11.0), 0.0, 1.0))
	var shoulder := HunterMotor.collision_safe_camera(get_world_3d().direct_space_state, focus, _camera_at, _own_colliders)
	# A wall that pushes the shoulder into the back hands over to the eye, as
	# in the Hunt, instead of filling the frame with the player's own coat.
	var seen := blend * HunterMotor.third_person_clearance_blend(eye, shoulder)
	camera.global_position = eye.lerp(shoulder, seen)
	var aim := eye + look * 12.0
	var tp_aim := focus if lock_target != null else shoulder + look * 12.0
	camera.look_at(aim.lerp(tp_aim, seen), Vector3.UP)
	camera.rotation.x += shove.y
	camera.rotation.y += shove.x
	camera.rotation.z += roll
	camera.fov = lerpf(FIRST_PERSON_FOV, THIRD_PERSON_FOV, seen)

	# First person keeps the sandbox's own viewmodel, so the body only shows
	# once the camera has actually left the head.
	visible = seen > 0.35
	motion.set_perspective(seen <= 0.5)
	if lock_target != null and ring != null:
		ring.follow(Vector3(lock_target.global_position.x, 0.0, lock_target.global_position.z))
