class_name VehicleDriver
extends Node3D

## Walking-to-seat, cameras and controls for the arcade chassis. Hosts may use
## the old immediate API without binding a walker; the mechanics lab binds its
## real CharacterBody3D and therefore gets the full door sequence.

const VEHICLE := preload("res://systems/arcade_vehicle.gd")
const SCRAP_SKIFF := preload("res://art/scrap_skiff.glb")
const SILHOUETTE := preload("res://systems/silhouette.gd")
const CHASSIS_DIMENSIONS := Vector3(2.65, 1.3, 4.8)
const SKIFF_WHEEL_BOTTOM := 0.030
const GET_OUT_SPEED := 5.0
const REACH_TO_GET_IN := 1.05
const CAMERA_BACK := Vector2(7.2, 9.4)
const CAMERA_UP := Vector2(2.5, 2.9)
const FOV_REST := 72.0
const FOV_FLAT := 90.0
const ENTRY_SECONDS := 1.18
const EXIT_SECONDS := 1.05
## A moving bail: the forward roll, then the stumble that eats the car's speed.
const BAIL_ROLL_SECONDS := 0.45
const BAIL_SECONDS := 0.85
const DOOR_LEFT := -1
const DOOR_RIGHT := 1
## BaselineHuman.SEATED puts its head centre at y=1.16. Keeping the body root
## 0.42 m below the chassis aligns that centre with VehicleInterior.EYE.y and
## prevents the proxy from poking through the roof.
const SEATED_BODY_Y := -0.42
## Visual layer for the player's own body while it is seen from outside (the
## entry/exit sequence and the seated driver). The first-person eyes and the
## cab camera skip it, so the camera never renders the inside of its own head.
const OWN_BODY_LAYER := 5

signal got_out(standing: Vector3, facing_yaw: float)
signal got_in()
signal phase_changed(phase: String)
signal horned()

var car: RigidBody3D
var camera: Camera3D
var cab_camera: Camera3D
var interior: VehicleInterior
var driving := false
var seated := false
var seat_side := DOOR_LEFT
var view := "chase"
var phase := "idle"
var phase_time := 0.0
var exit_kind := "step"
var last_message := ""
var _camera_placed := false
var _walker: CharacterBody3D
var _walker_camera: Camera3D
var _walker_visual: Node3D
var _walker_camera_local := Transform3D.IDENTITY
var _walker_collision_layer := 1
var _walker_collision_mask := 1
var _walker_from := Transform3D.IDENTITY
var _camera_from := Transform3D.IDENTITY
var _standing := Vector3.ZERO
var _facing_yaw := 0.0
var _jam_pulls: Dictionary = {}
var _horn: AudioStreamPlayer3D
var _seat_avatar: BaselineHuman
var _visual_layers: Dictionary = {}
var _entry_handle_animated := false
var _exit_brace_animated := false

static var _carried: RigidBody3D = null


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
	camera.cull_mask &= ~(1 << (VehicleInterior.CAB_LAYER - 1))
	add_child(camera)


func bind_walker(body: CharacterBody3D, eyes: Camera3D, visual: Node3D = null) -> void:
	_walker = body
	_walker_camera = eyes
	_walker_visual = visual
	if eyes != null:
		_walker_camera_local = eyes.transform
		eyes.cull_mask &= ~(1 << (OWN_BODY_LAYER - 1))
	if body != null:
		_walker_collision_layer = body.collision_layer
		_walker_collision_mask = body.collision_mask


func attach(vehicle: RigidBody3D, start_driving := true) -> void:
	car = vehicle
	_camera_placed = false
	_ensure_cab()
	_ensure_seat_avatar()
	if start_driving:
		if _walker != null and is_instance_valid(_walker):
			begin_entry(vehicle, DOOR_LEFT)
		else:
			_enter_immediately(DOOR_LEFT)
	else:
		driving = false
		seated = false


func get_in() -> bool:
	if car == null or not is_instance_valid(car):
		return false
	if _walker != null and is_instance_valid(_walker):
		return begin_entry(car, DOOR_LEFT)
	_enter_immediately(DOOR_LEFT)
	return true


func begin_entry(vehicle: RigidBody3D, side := DOOR_LEFT) -> bool:
	if phase != "idle" or seated or vehicle == null or not is_instance_valid(vehicle):
		return false
	car = vehicle
	seat_side = -1 if side < 0 else 1
	if _walker == null or not is_instance_valid(_walker):
		_enter_immediately(seat_side)
		return true
	if not door_in_reach(_walker.global_position, car, seat_side):
		last_message = "USE AT THE DRIVER DOOR" if seat_side < 0 else "USE AT THE PASSENGER DOOR"
		return false
	_ensure_cab()
	_ensure_seat_avatar()
	var damage := _damage()
	if damage != null and damage.door_jammed(seat_side):
		var key := "%d:%d" % [car.get_instance_id(), seat_side]
		var pulls := int(_jam_pulls.get(key, 0)) + 1
		_jam_pulls[key] = pulls
		if pulls < 3:
			phase_time = 0.0
			_set_phase("jam_pull")
			last_message = "JAMMED // PULL %d/3" % pulls
			return true
		damage.free_door_latch(seat_side)
		_jam_pulls.erase(key)
		last_message = "JAMMED // KICKED FREE"
	else:
		last_message = "GETTING IN"
	_walker_from = _walker.global_transform
	_camera_from = _walker_camera.global_transform
	_set_walker_collision(false)
	_show_walker_visual(true)
	_entry_handle_animated = false
	phase_time = 0.0
	_set_phase("enter")
	return true


func get_out(force := false) -> bool:
	if not seated or car == null or not is_instance_valid(car):
		return false
	if force or _walker == null or not is_instance_valid(_walker):
		_exit_immediately()
		return true
	exit_kind = "jump" if absf(float(car.signed_speed)) > GET_OUT_SPEED else "step"
	last_message = "BAILING OUT" if exit_kind == "jump" else "GETTING OUT"
	driving = false
	car.throttle = 0.0
	_camera_from = _active_camera().global_transform
	_walker.global_transform = _seat_body_transform()
	_show_walker_visual(false)
	_exit_brace_animated = false
	phase_time = 0.0
	_set_phase("exit")
	return true


func interrupt_entry(reason := "HIT") -> bool:
	if phase != "enter" and phase != "jam_pull":
		return false
	var damage := _damage()
	if damage != null:
		damage.set_door_open(seat_side, 0.0)
	phase = "idle"
	phase_time = 0.0
	seated = false
	driving = false
	if _walker != null and is_instance_valid(_walker):
		_walker.global_transform = _walker_from
	_set_walker_collision(true)
	if _walker_camera != null:
		_walker_camera.transform = _walker_camera_local
		_walker_camera.current = true
	_show_walker_visual(false)
	last_message = "ENTRY INTERRUPTED // %s" % reason
	phase_changed.emit(phase)
	return true


func occupied() -> bool:
	return seated or phase != "idle"


func can_get_in(from: Vector3) -> bool:
	return not occupied() and car != null and is_instance_valid(car) and door_in_reach(from, car, DOOR_LEFT)


func door_in_reach(from: Vector3, vehicle: RigidBody3D, side := DOOR_LEFT) -> bool:
	return from.distance_to(door_handle(vehicle, side)) <= REACH_TO_GET_IN


func door_handle(vehicle: RigidBody3D, side := DOOR_LEFT) -> Vector3:
	var half_width := float(vehicle.hull_size.x) * 0.5
	return vehicle.to_global(Vector3(float(-1 if side < 0 else 1) * (half_width + 0.12), 0.48, -0.18))


func standing_point(vehicle: RigidBody3D, side := DOOR_LEFT) -> Vector3:
	var side_sign := -1 if side < 0 else 1
	var outward := vehicle.global_basis.x.slide(Vector3.UP).normalized() * float(side_sign)
	var point := door_handle(vehicle, side) + outward * 0.72
	point.y = vehicle.global_position.y + 0.05
	return point


func speed() -> float:
	return float(car.signed_speed) if car != null and is_instance_valid(car) else 0.0


func toggle_view() -> String:
	if not seated:
		return view
	view = "cab" if view == "chase" else "chase"
	_set_drive_camera()
	return view


func horn() -> void:
	_ensure_horn()
	_horn.play()
	horned.emit()


func _physics_process(delta: float) -> void:
	if car == null or not is_instance_valid(car):
		return
	if phase != "idle":
		_tick_transition(delta)
		return
	if driving:
		car.throttle = clampf(Input.get_axis("move_back", "move_forward") + Input.get_action_strength("pad_combat_r2") - Input.get_action_strength("pad_combat_l2"), -1.0, 1.0)
		car.steering = Input.get_axis("move_left", "move_right")
		car.handbrake = Input.is_action_pressed("vehicle_handbrake")
		if interior != null:
			interior.drive(float(car.steering), float(car.throttle))
			interior.report({"speed": absf(float(car.signed_speed)) * 3.6, "fuel": float(car.fuel), "hull": float(car.condition), "gear": "R" if float(car.signed_speed) < -0.5 else "D"})
		_follow(delta)


func _tick_transition(delta: float) -> void:
	phase_time += delta
	var damage := _damage()
	if phase == "jam_pull":
		if damage != null:
			damage.set_door_open(seat_side, sin(clampf(phase_time / 0.22, 0.0, 1.0) * PI) * 0.09)
		if phase_time >= 0.22:
			if damage != null:
				damage.set_door_open(seat_side, 0.0)
			_set_phase("idle")
		return
	if phase == "bail":
		_tick_bail(delta)
		return
	if phase == "enter":
		_tick_enter(clampf(phase_time / ENTRY_SECONDS, 0.0, 1.0), damage)
		if phase_time >= ENTRY_SECONDS:
			_finish_entry()
	elif phase == "exit":
		_tick_exit(clampf(phase_time / EXIT_SECONDS, 0.0, 1.0), damage)
		if phase_time >= EXIT_SECONDS:
			_finish_exit()


func _tick_enter(t: float, damage: VehicleDamage) -> void:
	var missing := damage == null or damage.door_missing(seat_side)
	var handle_pose := _standing_transform()
	if t >= 0.18 and not _entry_handle_animated:
		_entry_handle_animated = true
		_play_walker_action("interact", 1.45)
	if t < 0.22:
		_walker.global_transform = _walker_from.interpolate_with(handle_pose, _smooth(t / 0.22))
	elif t < 0.43:
		_walker.global_transform = handle_pose
		if not missing:
			damage.set_door_open(seat_side, _smooth((t - 0.22) / 0.21))
	elif t < 0.79:
		var sit := _smooth((t - 0.43) / 0.36)
		_walker.global_transform = handle_pose.interpolate_with(_seat_body_transform(), sit)
		_walker_camera.global_transform = _camera_from.interpolate_with(_cab_transform(), sit)
	else:
		_walker.global_transform = _seat_body_transform()
		_walker_camera.global_transform = _cab_transform()
		if not missing:
			damage.set_door_open(seat_side, 1.0 - _smooth((t - 0.79) / 0.21))
	if t >= 0.62 and _seat_avatar != null:
		_show_walker_visual(false)
		_seat_avatar.visible = true
	else:
		if _seat_avatar != null:
			_seat_avatar.visible = false
		_show_walker_visual(true)
		_sync_visual()


func _tick_exit(t: float, damage: VehicleDamage) -> void:
	var missing := damage == null or damage.door_missing(seat_side)
	var outside := _standing_transform()
	if t < 0.24:
		if not missing:
			damage.set_door_open(seat_side, _smooth(t / 0.24))
		_walker_camera.global_transform = _camera_from.interpolate_with(_cab_transform(), _smooth(t / 0.24))
	elif t < 0.76:
		var stand := _smooth((t - 0.24) / 0.52)
		_walker.global_transform = _seat_body_transform().interpolate_with(outside, stand)
		_walker_camera.global_transform = _cab_transform().interpolate_with(_outside_camera_transform(), stand)
	else:
		_walker.global_transform = outside
		_walker_camera.global_transform = _outside_camera_transform()
		if not missing:
			damage.set_door_open(seat_side, 1.0 - _smooth((t - 0.76) / 0.24))
	if t < 0.38 and _seat_avatar != null:
		_show_walker_visual(false)
		_seat_avatar.visible = true
	else:
		if not _exit_brace_animated:
			_exit_brace_animated = true
			_play_walker_action("interact", 1.55)
		if _seat_avatar != null:
			_seat_avatar.visible = false
		_show_walker_visual(true)
		_sync_visual()


## Roll over the shoulder, then a stumble: the eyes pitch through a full turn
## and dip while the ground scrubs the inherited speed away.
func _tick_bail(delta: float) -> void:
	var flat := Vector3(_walker.velocity.x, 0.0, _walker.velocity.z) * exp(-3.2 * delta)
	var fall := _walker.velocity.y - 9.8 * delta
	if _walker.is_on_floor() and fall < 0.0:
		fall = 0.0
	_walker.velocity = Vector3(flat.x, fall, flat.z)
	_walker.move_and_slide()
	var view_pose := _walker_camera_local
	if phase_time < BAIL_ROLL_SECONDS:
		var roll := _smooth(phase_time / BAIL_ROLL_SECONDS)
		view_pose.basis = view_pose.basis * Basis(Vector3.RIGHT, -TAU * roll)
		view_pose.origin.y -= sin(roll * PI) * 0.55
	else:
		var stumble := clampf((phase_time - BAIL_ROLL_SECONDS) / (BAIL_SECONDS - BAIL_ROLL_SECONDS), 0.0, 1.0)
		var sway := sin(stumble * PI) * (1.0 - stumble)
		view_pose.basis = view_pose.basis * Basis(Vector3.FORWARD, sway * 0.32 * float(seat_side)) * Basis(Vector3.RIGHT, -sway * 0.25)
		view_pose.origin.y -= sway * 0.3
	_walker_camera.transform = view_pose
	if phase_time >= BAIL_SECONDS:
		_walker_camera.transform = _walker_camera_local
		_standing = _walker.global_position
		_set_phase("idle")
		last_message = "OUT"
		got_out.emit(_standing, _facing_yaw)


func _finish_entry() -> void:
	seated = true
	driving = seat_side < 0
	car.enabled = driving
	car.handbrake = false
	view = "cab"
	_ensure_seat_avatar()
	if _seat_avatar != null:
		_seat_avatar.visible = true
	_set_phase("idle")
	_show_walker_visual(false)
	_set_drive_camera()
	got_in.emit()


func _finish_exit() -> void:
	seated = false
	driving = false
	car.throttle = 0.0
	car.steering = 0.0
	car.handbrake = false
	car.enabled = false
	_standing = standing_point(car, seat_side)
	var forward := -car.global_basis.z.slide(Vector3.UP).normalized()
	_facing_yaw = atan2(-forward.x, -forward.z)
	_walker.global_position = _standing
	_walker.rotation.y = _facing_yaw
	_set_walker_collision(true)
	if exit_kind == "jump":
		var outward := car.global_basis.x.slide(Vector3.UP).normalized() * float(seat_side)
		_walker.velocity = car.linear_velocity + outward * 2.2 + Vector3.UP * 2.4
		if _walker_visual is BaselineHuman and (_walker_visual as BaselineHuman).rigged != null:
			(_walker_visual as BaselineHuman).rigged.play_action("Roll", 1.35)
		# The body is out but still tumbling: the driver keeps it until the
		# roll and stumble have spent the car's speed.
		_walker_camera.transform = _walker_camera_local
		_walker_camera.current = true
		if _seat_avatar != null:
			_seat_avatar.visible = false
		phase_time = 0.0
		last_message = "ROLLING CLEAR"
		_set_phase("bail")
		return
	_walker.velocity = Vector3.ZERO
	_walker_camera.transform = _walker_camera_local
	_walker_camera.current = true
	_show_walker_visual(false)
	if _seat_avatar != null:
		_seat_avatar.visible = false
	_set_phase("idle")
	got_out.emit(_standing, _facing_yaw)


func _enter_immediately(side: int) -> void:
	seat_side = side
	seated = true
	driving = side < 0
	car.enabled = driving
	view = "chase"
	camera.current = true
	_camera_placed = false
	got_in.emit()


func _exit_immediately() -> void:
	driving = false
	seated = false
	car.throttle = 0.0
	car.steering = 0.0
	car.handbrake = false
	car.enabled = false
	camera.current = false
	if cab_camera != null:
		cab_camera.current = false
	_set_phase("idle")
	var standing := standing_point(car, seat_side)
	var forward := -car.global_basis.z.slide(Vector3.UP).normalized()
	got_out.emit(standing, atan2(-forward.x, -forward.z))


func _ensure_cab() -> void:
	if car == null or not is_instance_valid(car):
		return
	interior = car.get_node_or_null("DriverInterior") as VehicleInterior
	if interior == null:
		interior = VehicleInterior.new()
		interior.name = "DriverInterior"
		car.add_child(interior)
		interior.build(int(car.get_instance_id() & 0xffff))
		_set_exterior_layer(car, interior)
	cab_camera = car.get_node_or_null("CabCamera") as Camera3D
	if cab_camera == null:
		cab_camera = Camera3D.new()
		cab_camera.name = "CabCamera"
		cab_camera.position = VehicleInterior.EYE
		cab_camera.fov = 78.0
		cab_camera.cull_mask = (1 << 0) | (1 << (VehicleInterior.CAB_LAYER - 1))
		car.add_child(cab_camera)
	_ensure_horn()


func _ensure_seat_avatar() -> void:
	if _seat_avatar != null and is_instance_valid(_seat_avatar) and _seat_avatar.get_parent() == car:
		_seat_avatar.position = Vector3(-0.38 if seat_side < 0 else 0.38, SEATED_BODY_Y, 0.15)
		return
	if _seat_avatar != null and is_instance_valid(_seat_avatar):
		_seat_avatar.visible = false
	_seat_avatar = car.get_node_or_null("PlayerSeatBody") as BaselineHuman
	if _seat_avatar != null:
		_seat_avatar.position = Vector3(-0.38 if seat_side < 0 else 0.38, SEATED_BODY_Y, 0.15)
		return
	_seat_avatar = BaselineHuman.new()
	_seat_avatar.name = "PlayerSeatBody"
	_seat_avatar.position = Vector3(-0.38 if seat_side < 0 else 0.38, SEATED_BODY_Y, 0.15)
	car.add_child(_seat_avatar)
	_seat_avatar.build("vehicle_player", {"seated": true, "gore": false, "blood": 4800.0})
	_seat_avatar.visible = false
	_set_own_body_layer(_seat_avatar, true)
	var damage := _damage()
	if damage != null:
		damage.driver = _seat_avatar


## Moves a body onto OWN_BODY_LAYER, or back onto the layers it had before.
func _set_own_body_layer(node: Node, own: bool) -> void:
	if node is VisualInstance3D:
		var visual := node as VisualInstance3D
		if own:
			if not _visual_layers.has(visual.get_instance_id()):
				_visual_layers[visual.get_instance_id()] = visual.layers
			visual.layers = 1 << (OWN_BODY_LAYER - 1)
		elif _visual_layers.has(visual.get_instance_id()):
			visual.layers = int(_visual_layers[visual.get_instance_id()])
			_visual_layers.erase(visual.get_instance_id())
	for child in node.get_children():
		_set_own_body_layer(child, own)


func _set_exterior_layer(node: Node, except: Node) -> void:
	for child in node.get_children():
		if child == except or child is Camera3D:
			continue
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = 1 << 1
		_set_exterior_layer(child, except)


func _ensure_horn() -> void:
	if _horn != null and is_instance_valid(_horn):
		return
	_horn = AudioStreamPlayer3D.new()
	_horn.name = "Horn"
	_horn.max_distance = 70.0
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count := 6615
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in count:
		var envelope := minf(1.0, float(index) / 220.0) * minf(1.0, float(count - index) / 440.0)
		var sample := sin(TAU * 196.0 * float(index) / 22050.0) * 0.65 + sin(TAU * 247.0 * float(index) / 22050.0) * 0.35
		bytes.encode_s16(index * 2, int(clampf(sample * envelope, -1.0, 1.0) * 18000.0))
	wave.data = bytes
	_horn.stream = wave
	(car if car != null else self).add_child(_horn)


func _set_drive_camera() -> void:
	if view == "cab" and cab_camera != null:
		cab_camera.current = true
	else:
		camera.current = true


func _active_camera() -> Camera3D:
	if cab_camera != null and cab_camera.current:
		return cab_camera
	return camera


func _damage() -> VehicleDamage:
	return car.get_node_or_null("Damage") as VehicleDamage if car != null else null


func _standing_transform() -> Transform3D:
	var point := standing_point(car, seat_side)
	var toward := car.global_position - point
	toward.y = 0.0
	var yaw := atan2(-toward.x, -toward.z)
	return Transform3D(Basis(Vector3.UP, yaw), point)


func _seat_body_transform() -> Transform3D:
	var local_x := -0.38 if seat_side < 0 else 0.38
	return car.global_transform * Transform3D(Basis.IDENTITY, Vector3(local_x, -0.18, 0.16))


func _cab_transform() -> Transform3D:
	var eye := VehicleInterior.EYE
	if seat_side > 0:
		eye.x = -eye.x
	return car.global_transform * Transform3D(Basis.IDENTITY, eye)


func _outside_camera_transform() -> Transform3D:
	var pose := _standing_transform()
	pose.origin += Vector3.UP * 0.77
	return pose


func _show_walker_visual(show: bool) -> void:
	if _walker_visual == null or not is_instance_valid(_walker_visual):
		return
	_walker_visual.visible = show
	if show:
		_set_own_body_layer(_walker_visual, true)
		_sync_visual()
	else:
		_set_own_body_layer(_walker_visual, false)
		_walker_visual.global_position = Vector3(0, -40, 0)


func _set_walker_collision(active: bool) -> void:
	if _walker == null or not is_instance_valid(_walker):
		return
	_walker.collision_layer = _walker_collision_layer if active else 0
	_walker.collision_mask = _walker_collision_mask if active else 0


func _sync_visual() -> void:
	if _walker_visual == null or not is_instance_valid(_walker_visual) or _walker == null:
		return
	_walker_visual.global_transform = _walker.global_transform
	_walker_visual.global_position -= Vector3.UP * 0.85


func _play_walker_action(action: String, rate: float) -> void:
	if _walker_visual is BaselineHuman:
		var body := _walker_visual as BaselineHuman
		if body.rigged != null:
			body.rigged.play_action(action, rate)


func _set_phase(next: String) -> void:
	phase = next
	phase_changed.emit(phase)


func _smooth(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _follow(delta: float) -> void:
	var forward := -car.global_transform.basis.z.slide(Vector3.UP).normalized()
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	var pace := clampf(absf(float(car.signed_speed)) / float(VEHICLE.DRIVE_SPEED), 0.0, 1.0)
	var pivot := car.global_position + Vector3.UP * 1.4
	var desired := car.global_position - forward * lerpf(CAMERA_BACK.x, CAMERA_BACK.y, pace) + Vector3.UP * lerpf(CAMERA_UP.x, CAMERA_UP.y, pace)
	var query := PhysicsRayQueryParameters3D.create(pivot, desired)
	query.exclude = [car.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
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
