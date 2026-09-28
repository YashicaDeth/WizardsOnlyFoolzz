class_name BlackMirrorCamera
extends Control

const Mirror := preload("res://systems/black_mirror.gd")
const SENSOR_SHADER := preload("res://shaders/black_mirror_sensor.gdshader")
const DEPTH_SHADER := preload("res://shaders/black_mirror_depth.gdshader")
const MODES := ["night", "depth"]
## Which of the phone's cameras is up: the low-light sensor, or the LiDAR-style
## depth image (Greg, 2026-09-24). Shift+L cycles it while the phone is raised.
var mode := "night"
var depth_quad: MeshInstance3D
var depth_environment: Environment
var active := false
var sensor := Mirror.night_vision_state()
var source_camera: Camera3D
var source_environment: Environment
var sensor_environment: Environment
var effect: ColorRect
var overlay: Control
var clock := 0.0
var _last_camera_position := Vector3.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect = ColorRect.new()
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_value := ShaderMaterial.new()
	material_value.shader = SENSOR_SHADER
	effect.material = material_value
	add_child(effect)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_camera)
	add_child(overlay)
	sensor.battery = float(WorldHistory.subject("mirror_power").get("charge", 1.0))
	visible = false

func bind(camera: Camera3D, environment: Environment) -> void:
	source_camera = camera
	source_environment = environment

func set_active(enabled: bool) -> void:
	active = enabled and float(sensor.battery) > 0.001
	visible = active
	_apply_mode()
	if is_instance_valid(source_camera):
		if active and source_environment != null:
			sensor_environment = source_environment.duplicate(true)
			# Electronic exposure is isolated to the camera feed. The world light
			# sources and the ordinary player's environment remain untouched.
			sensor_environment.tonemap_exposure = maxf(1.3, source_environment.tonemap_exposure)
			sensor_environment.adjustment_contrast = 1.0
			source_camera.environment = sensor_environment
		else:
			source_camera.environment = null
	if not active:
		WorldHistory.amend_subject("mirror_power", {"kind": "device", "charge": sensor.battery})

func cycle_mode() -> String:
	mode = MODES[(MODES.find(mode) + 1) % MODES.size()]
	_apply_mode()
	return mode


## The depth image is a quad on the camera itself, because only a 3D pass can
## read the depth buffer; the night sensor is the 2D screen pass it always was.
func _apply_mode() -> void:
	var depth := active and mode == "depth"
	if effect != null:
		effect.visible = not depth
	if depth and depth_quad == null and is_instance_valid(source_camera):
		depth_quad = MeshInstance3D.new()
		depth_quad.name = "BlackMirrorDepth"
		var quad := QuadMesh.new()
		var material_value := ShaderMaterial.new()
		material_value.shader = DEPTH_SHADER
		quad.material = material_value
		depth_quad.mesh = quad
		depth_quad.extra_cull_margin = 16384.0
		depth_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		source_camera.add_child(depth_quad)
	if depth_quad != null and is_instance_valid(depth_quad):
		depth_quad.visible = depth
	# The depth image is data, not a picture: no grade, glow or tonemap on it.
	if is_instance_valid(source_camera) and active:
		if depth:
			if depth_environment == null:
				depth_environment = Environment.new()
				depth_environment.background_mode = Environment.BG_COLOR
				depth_environment.background_color = Color.BLACK
				depth_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			source_camera.environment = depth_environment
		elif sensor_environment != null:
			source_camera.environment = sensor_environment


func _exit_tree() -> void:
	if depth_quad != null and is_instance_valid(depth_quad):
		depth_quad.queue_free()
	if is_instance_valid(source_camera):
		source_camera.environment = null

func _process(delta: float) -> void:
	if not active:
		return
	clock += delta
	var ambient := 0.04
	if source_environment != null:
		ambient = clampf(source_environment.ambient_light_energy * 0.09, 0.003, 0.16)
	var distance := 10.0
	var motion := 0.0
	if is_instance_valid(source_camera):
		motion = clampf(source_camera.global_position.distance_to(_last_camera_position) / maxf(delta * 10.0, 0.01), 0.0, 1.0)
		_last_camera_position = source_camera.global_position
		var from := source_camera.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from - source_camera.global_basis.z * 60.0)
		var hit := source_camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			distance = from.distance_to(hit.position)
	sensor = Mirror.step_night_vision(sensor, {"enabled": active, "ambient_luminance": ambient, "highlight_luminance": 0.3, "subject_distance": distance, "contrast": 0.55, "motion": motion}, delta)
	var settings: Dictionary = WorldHistory.subject("settings")
	var material_value := effect.material as ShaderMaterial
	material_value.set_shader_parameter("exposure", sensor.exposure)
	material_value.set_shader_parameter("gain", sensor.gain)
	material_value.set_shader_parameter("sensor_noise", sensor.noise * (0.15 if settings.get("reduced_glitch", false) else 1.0))
	material_value.set_shader_parameter("focus_error", 1.0 - float(sensor.focus_confidence))
	material_value.set_shader_parameter("bloom", sensor.bloom)
	overlay.queue_redraw()
	if not sensor.enabled:
		set_active(false)

func _draw_camera() -> void:
	var ink := Color("cbe8d1")
	var rect := Rect2(Vector2(22, 20), size - Vector2(44, 40))
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sign_x := 1.0 if corner.x < size.x * 0.5 else -1.0
		var sign_y := 1.0 if corner.y < size.y * 0.5 else -1.0
		overlay.draw_line(corner, corner + Vector2(48 * sign_x, 0), ink * Color(1,1,1,0.55), 1)
		overlay.draw_line(corner, corner + Vector2(0, 22 * sign_y), ink * Color(1,1,1,0.55), 1)
	var font := ThemeDB.fallback_font
	# A phone recording, not a military scope (Greg, 2026-09-24). Everything
	# sits in one strip across the top centre and one line at the foot: the
	# corners belong to the field HUD (location, brain, minimap, weapon), and a
	# looked-at capture showed REC, the clock and the cell all buried under it.
	var elapsed := int(clock)
	var red := Color("ff3b30")
	var strip := "REC   %02d:%02d:%02d     %s     %02d%% CELL" % [elapsed / 3600, (elapsed / 60) % 60, elapsed % 60, WorldClock.stamp(), roundi(sensor.battery * 100.0)]
	var strip_width := font.get_string_size(strip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var left := size.x * 0.5 - strip_width * 0.5
	overlay.draw_rect(Rect2(Vector2(left - 30, 26), Vector2(strip_width + 44, 40)), Color(0, 0, 0, 0.45))
	if fmod(clock, 1.2) < 0.8:
		overlay.draw_circle(Vector2(left - 16, 42), 7.0, red)
	overlay.draw_string(font, Vector2(left, 48), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, red)
	overlay.draw_string(font, Vector2(left, 48), "      " + strip.substr(3), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	var cell := Rect2(Vector2(left, 58), Vector2(strip_width, 3))
	overlay.draw_rect(cell, ink * Color(1, 1, 1, 0.15))
	overlay.draw_rect(Rect2(cell.position, Vector2(cell.size.x * float(sensor.battery), cell.size.y)), ink * Color(1, 1, 1, 0.7))
	var readout := ("BLACK MIRROR  /  DEPTH     " if mode == "depth" else "BLACK MIRROR  /  LOW-LIGHT     ") + "GAIN x%.1f   EXP %.1f   FOCUS %.1fm     N RECORD  ·  SHIFT+L MODE  ·  L LOWER" % [sensor.gain, sensor.exposure, sensor.focus_distance]
	var readout_width := font.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	# A dark backing, so the readout holds on the depth image's white as well.
	overlay.draw_rect(Rect2(Vector2(size.x * 0.5 - readout_width * 0.5 - 10, size.y - 106), Vector2(readout_width + 20, 22)), Color(0, 0, 0, 0.55))
	overlay.draw_string(font, Vector2(size.x * 0.5 - readout_width * 0.5, size.y - 90), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink * Color(1, 1, 1, 0.75))
