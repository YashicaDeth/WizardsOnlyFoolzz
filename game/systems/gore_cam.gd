class_name GoreCam
extends Node
## Greg, Walkthrough 2 (24 September): the derby's kill cam "as a slow-motion
## cutscene of the actual body being gored rather than a green X-ray card".
## On a kill the world drops into slow motion and a camera of its own swings
## slowly around the real body in the crushed cab while the gore that the
## kill already throws is still in the air, then hands the view back.
##
## Additive: the host calls `trigger()` and does nothing else. It never
## touches the host's camera beyond making it current again at the end.

const DURATION := 2.6
const SLOW_SCALE := 0.18
## Around the body: how far out, how high, how far the camera swings.
const DISTANCE := 3.2
const HEIGHT := 1.1
const SWING := 0.9

var active := false
var clock := 0.0
var camera: Camera3D
var _previous: Camera3D
var _focus := Vector3.ZERO
var _start_angle := 0.0
var _hud: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## `focus` is the body (the driver's head in the cab); `from` is the blow's
## direction, so the camera starts on the side the hit came from. `hud` is
## put away for the shot, because a cutscene is not read through the dash.
func trigger(focus: Vector3, from: Vector3, hud: CanvasLayer = null) -> void:
	if active:
		return
	var viewport_camera := get_viewport().get_camera_3d()
	if viewport_camera == null:
		return
	active = true
	clock = 0.0
	_focus = focus
	_previous = viewport_camera
	var flat := Vector3(from.x, 0.0, from.z)
	_start_angle = atan2(flat.x, flat.z) + PI if flat.length_squared() > 0.001 else 0.0
	camera = Camera3D.new()
	camera.name = "GoreCamera"
	camera.fov = 48.0
	get_parent().add_child(camera)
	_place(0.0)
	camera.make_current()
	Engine.time_scale = SLOW_SCALE
	_hud = hud if hud != null and hud.visible else null
	if _hud != null:
		_hud.visible = false


func _process(delta: float) -> void:
	if not active:
		return
	# Unscaled time, or the shot would also be slowed by its own effect.
	clock += delta / maxf(Engine.time_scale, 0.001)
	if clock >= DURATION:
		finish()
		return
	_place(clock / DURATION)


func _place(t: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var angle := _start_angle + ease(t, -1.6) * SWING
	var at := _focus + Vector3(sin(angle), 0.0, cos(angle)) * lerpf(DISTANCE, DISTANCE * 0.72, t) + Vector3.UP * HEIGHT
	camera.global_position = at
	camera.look_at(_focus, Vector3.UP)


func finish() -> void:
	if not active:
		return
	active = false
	Engine.time_scale = 1.0
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
	_hud = null
	if is_instance_valid(_previous):
		_previous.make_current()
	if camera != null and is_instance_valid(camera):
		camera.queue_free()
	camera = null


func _exit_tree() -> void:
	if active:
		Engine.time_scale = 1.0
