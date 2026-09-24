class_name BlackMirrorCamera
extends Control

const Mirror := preload("res://systems/black_mirror.gd")
const SENSOR_SHADER := preload("res://shaders/black_mirror_sensor.gdshader")
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

func _exit_tree() -> void:
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
	# A phone recording, not a military scope (Greg, 2026-09-24): the red REC
	# dot, the clock burned into the corner, the cell in the other.
	if fmod(clock, 1.2) < 0.8:
		overlay.draw_circle(Vector2(46, 48), 7.0, Color("ff3b30"))
	overlay.draw_string(font, Vector2(60, 54), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ff3b30"))
	var elapsed := int(clock)
	overlay.draw_string(font, Vector2(104, 54), "%02d:%02d:%02d" % [elapsed / 3600, (elapsed / 60) % 60, elapsed % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	var stamp := WorldClock.stamp()
	overlay.draw_string(font, Vector2(size.x - 34 - font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, 54), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	overlay.draw_string(font, Vector2(34, size.y - 57), "BLACK MIRROR  /  LOW-LIGHT SENSOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	overlay.draw_string(font, Vector2(34, size.y - 36), "GAIN ×%.1f   EXP %.1f   FOCUS %.1fm    N RECORD · L LOWER" % [sensor.gain, sensor.exposure, sensor.focus_distance], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink * Color(1,1,1,0.65))
	var power := Rect2(size.x - 134, size.y - 58, 86, 5)
	overlay.draw_rect(power, ink * Color(1,1,1,0.15))
	overlay.draw_rect(Rect2(power.position, Vector2(power.size.x * float(sensor.battery), power.size.y)), ink)
	overlay.draw_string(font, Vector2(size.x - 134, size.y - 32), "%02d%%  CELL" % roundi(sensor.battery * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
