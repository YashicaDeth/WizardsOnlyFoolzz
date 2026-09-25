class_name VehicleDriver
extends Node3D

## The player's hands on an arcade chassis (`arcade_vehicle.gd`) outside the
## derby pit: the move actions go into throttle and steering exactly as the
## derby's own `_update_boat` does, a chase camera follows (pulled in when a
## tunnel wall is between it and the car), and the player can get out and back
## in. The host scene owns its walking body; this only says where to stand it.
##
## Also carries a car across a scene change (`carry` / `take_carried`), so the
## car driven out of the derby tunnels is the car that arrives at the dry falls,
## dents and all.

const VEHICLE := preload("res://systems/arcade_vehicle.gd")
const SCRAP_SKIFF := preload("res://art/scrap_skiff.glb")
const SILHOUETTE := preload("res://systems/silhouette.gd")
const CHASSIS_DIMENSIONS := Vector3(2.65, 1.3, 4.8)
const SKIFF_WHEEL_BOTTOM := 0.030
## Too fast to step out of. The derby lets you climb out whenever the round
## allows; out here a door opened at speed is the player thrown on the road.
const GET_OUT_SPEED := 5.0
const REACH_TO_GET_IN := 4.2
const CAMERA_BACK := Vector2(7.2, 9.4)
const CAMERA_UP := Vector2(2.5, 2.9)
const FOV_REST := 72.0
const FOV_FLAT := 90.0

signal got_out(standing: Vector3, facing_yaw: float)
signal got_in()

var car: RigidBody3D
var camera: Camera3D
var driving := false
var _camera_placed := false

## A car on its way to the next scene. Static so it survives the old scene
## being freed; the car itself is out of the tree while it waits.
static var _carried: RigidBody3D = null


## An arcade chassis dressed as the derby dresses the player's wrecker: the
## scrap skiff shell seated on the suspension's contact patch, regrimed, with
## the biopunk kit hung on it.
static func make_car(seed_value := 3) -> RigidBody3D:
	var body: RigidBody3D = VEHICLE.new()
	body.name = "MercyCountyWrecker"
	var shell := SCRAP_SKIFF.instantiate() as Node3D
	shell.name = "AuthoredScrapSkiff"
	shell.scale = Vector3(1.15, 1.15, 1.15)
	shell.position.y = VEHICLE.rest_contact_y() - SKIFF_WHEEL_BOTTOM * shell.scale.y
	body.add_child(shell)
	WorldLook.regrime(shell, seed_value)
	SILHOUETTE.dress_vehicle(body, CHASSIS_DIMENSIONS, VEHICLE.WHEEL_ANCHORS, seed_value, WorldLook.surface)
	return body


static func carry(vehicle: RigidBody3D) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	# The derby's engine voices belong to the scene that made them.
	for child in vehicle.get_children():
		if child is AudioStreamPlayer3D:
			child.queue_free()
	vehicle.throttle = 0.0
	vehicle.steering = 0.0
	vehicle.enabled = false
	if vehicle.get_parent() != null:
		vehicle.get_parent().remove_child(vehicle)
	_carried = vehicle


static func take_carried() -> RigidBody3D:
	var vehicle := _carried
	_carried = null
	if vehicle != null and not is_instance_valid(vehicle):
		return null
	return vehicle


func _init() -> void:
	top_level = true
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.fov = FOV_REST
	camera.far = 700.0
	add_child(camera)


func attach(vehicle: RigidBody3D, start_driving := true) -> void:
	car = vehicle
	_camera_placed = false
	if start_driving:
		get_in()
	else:
		driving = false


func get_in() -> bool:
	if car == null or not is_instance_valid(car):
		return false
	driving = true
	car.enabled = true
	camera.current = true
	_camera_placed = false
	got_in.emit()
	return true


## Out through the driver's door, onto whatever is beside the car there. Refused
## at speed.
func get_out() -> bool:
	if not driving or car == null or not is_instance_valid(car):
		return false
	if absf(float(car.signed_speed)) > GET_OUT_SPEED:
		return false
	driving = false
	car.throttle = 0.0
	car.steering = 0.0
	car.enabled = false
	camera.current = false
	var basis := car.global_transform.basis
	var standing := car.global_position - basis.x.slide(Vector3.UP).normalized() * 2.4
	standing.y = car.global_position.y + 0.3
	var forward := -basis.z.slide(Vector3.UP).normalized()
	got_out.emit(standing, atan2(-forward.x, -forward.z))
	return true


func can_get_in(from: Vector3) -> bool:
	return not driving and car != null and is_instance_valid(car) and from.distance_to(car.global_position) <= REACH_TO_GET_IN


func speed() -> float:
	return float(car.signed_speed) if car != null and is_instance_valid(car) else 0.0


func _physics_process(delta: float) -> void:
	if car == null or not is_instance_valid(car):
		return
	if driving:
		car.throttle = Input.get_axis("move_back", "move_forward")
		car.steering = Input.get_axis("move_left", "move_right")
		_follow(delta)


func _follow(delta: float) -> void:
	var forward := -car.global_transform.basis.z.slide(Vector3.UP).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	var pace := clampf(absf(float(car.signed_speed)) / float(VEHICLE.DRIVE_SPEED), 0.0, 1.0)
	var pivot := car.global_position + Vector3.UP * 1.4
	var desired := car.global_position - forward * lerpf(CAMERA_BACK.x, CAMERA_BACK.y, pace) + Vector3.UP * lerpf(CAMERA_UP.x, CAMERA_UP.y, pace)
	# A tunnel wall between the car and where the camera wants to be pulls the
	# camera in along the line to it, so a bend never shows the back of a wall.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pivot, desired)
	query.exclude = [car.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		desired = (hit.position as Vector3).lerp(pivot, 0.12)
	if not _camera_placed:
		camera.global_position = desired
		_camera_placed = true
	else:
		camera.global_position = camera.global_position.lerp(desired, minf(delta * 6.0, 1.0))
	camera.fov = lerpf(camera.fov, lerpf(FOV_REST, FOV_FLAT, pace * pace), minf(delta * 3.0, 1.0))
	var look := car.global_position + forward * 9.0 + Vector3.UP * 1.1
	if camera.global_position.distance_to(look) > 0.1:
		camera.look_at(look, Vector3.UP)
