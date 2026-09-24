class_name AlarmXrayFlash
extends Control

## The moment the facility has you (Greg, 24 September): "the depth map like
## white xray looking thing on the camera flashing on it for a second".
##
## Built from two things the game already has, not a new look:
##
## - the Black Mirror's LiDAR depth image, near things white and far things
##   falling to black, laid over the player's camera (`alarm_depth.gdshader`,
##   that shader plus a Compatibility-renderer depth read); and
## - the world X-ray (`WorldXray.sweep`), so the skeletons and organs of the
##   alerted characters draw through the walls while it is up.
##
## It lasts `SECONDS`, strobing like a camera flash that will not settle, with a
## white frame at its start. Then everything is put back as it was.

const DEPTH_SHADER := preload("res://shaders/alarm_depth.gdshader")
const SECONDS := 1.0
const XRAY_REACH := 60.0

var camera: Camera3D
var remaining := 0.0
var flashes := 0
var depth_quad: MeshInstance3D
var white: ColorRect
var stamp: Label
var _rigs: Array = []
var _saved_environment: Environment
var _depth_environment: Environment


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white = ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(white)
	stamp = Label.new()
	stamp.text = "CELLOUTZ // SUBJECT ACQUIRED"
	stamp.add_theme_font_size_override("font_size", 22)
	stamp.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	stamp.position = Vector2(40, 110)
	stamp.visible = false
	add_child(stamp)


func active() -> bool:
	return remaining > 0.0


## Fire it. `rigs` are the BaselineHumans the facility has just alerted.
func flash(rigs: Array) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	flashes += 1
	remaining = SECONDS
	_rigs = rigs.duplicate()
	if depth_quad == null or not is_instance_valid(depth_quad):
		depth_quad = MeshInstance3D.new()
		depth_quad.name = "AlarmDepth"
		var quad := QuadMesh.new()
		var material := ShaderMaterial.new()
		material.shader = DEPTH_SHADER
		quad.material = material
		depth_quad.mesh = quad
		depth_quad.extra_cull_margin = 16384.0
		depth_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		camera.add_child(depth_quad)
	if _depth_environment == null:
		_depth_environment = Environment.new()
		_depth_environment.background_mode = Environment.BG_COLOR
		_depth_environment.background_color = Color.BLACK
		_depth_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_saved_environment = camera.environment
	camera.environment = _depth_environment
	WorldXray.sweep(camera.global_position, _rigs, true, XRAY_REACH)
	_apply()


func _process(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	_apply()
	if remaining <= 0.0:
		_finish()


func _apply() -> void:
	var elapsed := SECONDS - remaining
	# On for most of the second, dropping out twice, like a flash tube
	# that keeps firing.
	var on := remaining > 0.0 and not (elapsed > 0.32 and elapsed < 0.38) and not (elapsed > 0.62 and elapsed < 0.66)
	if depth_quad != null and is_instance_valid(depth_quad):
		depth_quad.visible = on
	white.color = Color(1, 1, 1, clampf(0.85 - elapsed * 6.0, 0.0, 0.85))
	stamp.visible = on and elapsed > 0.1


func _finish() -> void:
	if depth_quad != null and is_instance_valid(depth_quad):
		depth_quad.visible = false
	white.color = Color(1, 1, 1, 0)
	stamp.visible = false
	if camera != null and is_instance_valid(camera):
		camera.environment = _saved_environment
		WorldXray.sweep(camera.global_position, _rigs, false, XRAY_REACH)
	_rigs.clear()
