class_name IntakeWatchers
extends Node3D

## Beat 3 of `DESIGN/OPENING_TORTURE_INTAKE.md`. Greg: "he says hurry up now,
## I'm being watched too, and then the cameras that are all around zoom in
## closer and you see them on your depth map and your x-ray."
##
## Four wall cameras on the Growing Floor. Until he says it they sweep the
## room; then every head swings onto your tank, every lens barrel runs out,
## and the form is overlaid with a depth-scan pulse that boxes each camera
## where it hangs. They stay on you. These are the Growing Floor's own
## `SecurityCamera`s, so later beats (a camera seeing you break tanks) can use
## them as they are.

## Where the Growing Floor's cameras have always hung ("cameras everywhere",
## Greg, 24 September); they used to be fixed boxes that never moved.
const SPOTS := [
	Vector3(-7.2, 3.7, 2.8),
	Vector3(7.2, 3.7, 2.8),
	Vector3(-7.2, 3.7, -6.5),
	Vector3(7.2, 3.7, -6.5),
]
const TURN_SECONDS := 0.9
const ZOOM_SECONDS := 1.3
const SCAN_SECONDS := 3.6

var cameras: Array[SecurityCamera] = []
var target := Vector3(0.0, 1.55, 0.0)
var closed_in := false
var since := 0.0
var clock := 0.0
var scan: Control
var view_camera: Camera3D
var _from_yaw: Array[float] = []
var _from_pitch: Array[float] = []


func build(tank_head: Vector3) -> void:
	target = tank_head
	for index in SPOTS.size():
		var lens := SecurityCamera.new()
		lens.name = "GrowingFloorCamera%d" % (index + 1)
		add_child(lens)
		lens.build("growing_floor_camera_%d" % (index + 1), float(index) * 1.7)
		WorldHistory.update_subject(lens.camera_id, {"place": "growing_floor"})
		lens.position = SPOTS[index]
		# The mount faces into the room, toward the tank's side of it.
		var flat := Vector3(target.x, SPOTS[index].y, target.z)
		lens.look_at(flat, Vector3.UP)
		cameras.append(lens)


func close_in(hud: Control, eye: Camera3D) -> void:
	if closed_in:
		return
	closed_in = true
	since = 0.0
	view_camera = eye
	_from_yaw.clear()
	_from_pitch.clear()
	for lens in cameras:
		_from_yaw.append(lens.head.rotation.y)
		_from_pitch.append(lens.head.rotation.x)
		lens.tracking = true
		lens.lock = 1.0
		lens._tint()
	if hud != null:
		scan = Control.new()
		scan.name = "WatcherScan"
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scan.draw.connect(_draw_scan)
		# Sized after it is in the tree: a preset applied to a Control with no
		# parent yet resolves against nothing and leaves it 0x0, invisible.
		hud.add_child(scan)
		scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	WorldHistory.record_event("intake_cameras_closed_in", {"cameras": cameras.size(), "place": "growing_floor"})


func _process(delta: float) -> void:
	clock += delta
	for index in cameras.size():
		var lens := cameras[index]
		if not closed_in:
			# Sweeping the room, nobody in particular.
			lens.head.rotation.y = sin(clock * SecurityCamera.SWEEP_SPEED + index * 1.7) * 0.5
			lens.head.rotation.x = SecurityCamera.PITCH
			continue
		var aim := _aim(lens)
		var turn := ease(clampf(since / TURN_SECONDS, 0.0, 1.0), 0.5)
		lens.head.rotation.y = lerp_angle(_from_yaw[index], aim.x, turn)
		lens.head.rotation.x = lerpf(_from_pitch[index], aim.y, turn)
		# The barrel runs out after the head has found you.
		var zoom := ease(clampf((since - TURN_SECONDS * 0.6) / ZOOM_SECONDS, 0.0, 1.0), 0.4)
		lens.lens.scale.y = 1.0 + zoom * 3.2
		lens.lens.position.z = -0.24 - zoom * 0.1
	if closed_in:
		since += delta
		if scan != null and is_instance_valid(scan):
			if since > SCAN_SECONDS:
				scan.queue_free()
				scan = null
			else:
				scan.queue_redraw()


## Yaw and pitch that put a head's lens on the tank, in the mount's space.
func _aim(lens: SecurityCamera) -> Vector2:
	var local := lens.to_local(target) - lens.head.position
	var yaw := atan2(-local.x, -local.z)
	var level := Vector2(local.x, local.z).length()
	return Vector2(yaw, clampf(atan2(local.y, level), -1.2, 0.3))


func zoom_amount() -> float:
	return 0.0 if cameras.is_empty() else (cameras[0].lens.scale.y - 1.0) / 3.2


## The depth scan: the room goes to a cold wash for a moment and each camera is
## boxed where it hangs, whatever is in front of it. They can see you; now you
## can see them.
func _draw_scan() -> void:
	if scan == null or view_camera == null:
		return
	var fade := clampf(1.0 - (since - SCAN_SECONDS + 0.8) / 0.8, 0.0, 1.0) * clampf(since / 0.25, 0.0, 1.0)
	var size := scan.size
	scan.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.1, 0.12, 0.28 * fade))
	var sweep_y := fmod(since * 0.6, 1.0) * size.y
	scan.draw_line(Vector2(0, sweep_y), Vector2(size.x, sweep_y), Color(0.4, 1.0, 0.9, 0.35 * fade), 2.0)
	for index in cameras.size():
		var lens := cameras[index]
		var point := lens.head.global_position
		var on_screen := not view_camera.is_position_behind(point)
		var at := view_camera.unproject_position(point) if on_screen else Vector2(size.x * (0.1 if lens.position.x < 0 else 0.9), size.y * 0.12)
		at = at.clamp(Vector2(40, 40), size - Vector2(40, 40))
		var box := 26.0 + 6.0 * sin(since * 9.0 + index)
		var hot := Color(1.0, 0.18, 0.1, 0.9 * fade)
		var corner := box * 0.45
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var c := at + Vector2(sx, sy) * box
				scan.draw_line(c, c - Vector2(sx * corner, 0), hot, 2.0)
				scan.draw_line(c, c - Vector2(0, sy * corner), hot, 2.0)
		scan.draw_circle(at, 3.0, hot)
		CellOutzType.draw_string_compat(scan, at + Vector2(box + 6.0, -box + 12.0), "CAM 0C-%d  //  ON YOU" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hot)
