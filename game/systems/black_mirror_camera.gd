class_name BlackMirrorCamera
extends Control

const Mirror := preload("res://systems/black_mirror.gd")
const SENSOR_SHADER := preload("res://shaders/black_mirror_sensor.gdshader")
const DEPTH_SHADER := preload("res://shaders/black_mirror_depth.gdshader")
const MODES := ["night", "depth"]
const CellOutzType := preload("res://systems/celloutz_type.gd")
const BLOCK_TRACKER := preload("res://systems/block_tracker.gd")
## Dial (v02-51, REMASTER_LOG): the depth camera boxes only what it can see.
## true would tag bodies through walls too, which is a wallhack, not a sensor.
const DEPTH_TRACKS_THROUGH_WALLS := false
## The device's house palette (HandheldDevice), so the lens and the pages are
## one object rather than two interfaces.
const INK := Color("e6d4ac")
const AMBER := Color("b0552a")
const MOSS := Color("8a9a4a")
const REC_RED := Color("e8432e")
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
## v02-51. What the depth camera should look for. Returns an Array of
## {at: Vector3, half: Vector3, tag: String, kind: "body" | "object"}; the host
## scene owns its bodies, the camera only measures and draws them.
var target_provider: Callable
var tracker: Control
## Set by a host that prints its own pad-aware controls. Empty keeps the
## Hunt's keyboard legend.
var hint_line := ""

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


func set_mode(next: String) -> void:
	if MODES.has(next):
		mode = next
		_apply_mode()


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
	if depth and tracker == null:
		tracker = BLOCK_TRACKER.new()
		tracker.name = "DepthTracker"
		add_child(tracker)
		move_child(tracker, overlay.get_index())
	if tracker != null:
		tracker.visible = depth
		if not depth:
			tracker.call("track", [])
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
	if mode == "depth":
		_update_depth_tracking()
	overlay.queue_redraw()
	if not sensor.enabled:
		set_active(false)

## The depth camera's targets: measured from the host's list, occlusion-tested
## along one ray each, handed to the BlockTracker for boxes and tags and to the
## shader as a track mask so a tracked body's points run hot.
func _update_depth_tracking() -> void:
	if tracker == null or not is_instance_valid(source_camera):
		return
	tracker.set("camera", source_camera)
	var entries: Array = []
	if target_provider.is_valid():
		var space := source_camera.get_world_3d().direct_space_state
		var eye := source_camera.global_position
		for entry: Dictionary in target_provider.call():
			var at: Vector3 = entry.get("at", Vector3.ZERO)
			var half: Vector3 = entry.get("half", Vector3(0.3, 0.9, 0.3))
			var distance := eye.distance_to(at)
			var query := PhysicsRayQueryParameters3D.create(eye, at)
			var hit := space.intersect_ray(query)
			var occluded := not hit.is_empty() and eye.distance_to(hit.position) < distance - maxf(half.x, maxf(half.y, half.z)) * 1.3
			if occluded and not DEPTH_TRACKS_THROUGH_WALLS:
				continue
			var copy := entry.duplicate()
			copy["occluded"] = occluded
			entries.append(copy)
	tracker.call("track", entries)
	var rects: Array = []
	var bands := PackedVector2Array()
	var view_size := get_viewport_rect().size
	var to_view := source_camera.global_transform.affine_inverse()
	var tracked: Array = tracker.get("targets")
	var screen_rects: Array = tracker.call("target_rects")
	for index in 8:
		if index < tracked.size() and index < screen_rects.size():
			var r: Rect2 = screen_rects[index]
			rects.append(Vector4(r.position.x / view_size.x, r.position.y / view_size.y, r.end.x / view_size.x, r.end.y / view_size.y))
			var entry: Dictionary = tracked[index]
			var half: Vector3 = entry.get("half", Vector3(0.3, 0.9, 0.3))
			var depth := -(to_view * (entry.get("at", Vector3.ZERO) as Vector3)).z
			var reach := maxf(half.x, maxf(half.y, half.z)) * 1.25
			bands.append(Vector2(depth - reach, depth + reach))
		else:
			rects.append(Vector4.ZERO)
			bands.append(Vector2.ZERO)
	if depth_quad != null and is_instance_valid(depth_quad):
		var depth_material := (depth_quad.mesh as QuadMesh).material as ShaderMaterial
		depth_material.set_shader_parameter("track_count", mini(tracked.size(), 8))
		depth_material.set_shader_parameter("track_rect", rects)
		depth_material.set_shader_parameter("track_band", bands)


func _draw_camera() -> void:
	var ink := Color("cbe8d1")
	var rect := Rect2(Vector2(22, 20), size - Vector2(44, 40))
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sign_x := 1.0 if corner.x < size.x * 0.5 else -1.0
		var sign_y := 1.0 if corner.y < size.y * 0.5 else -1.0
		overlay.draw_line(corner, corner + Vector2(48 * sign_x, 0), ink * Color(1,1,1,0.55), 1)
		overlay.draw_line(corner, corner + Vector2(0, 22 * sign_y), ink * Color(1,1,1,0.55), 1)
	# A phone recording, not a military scope (Greg, 2026-09-24). Everything
	# sits in one strip across the top centre and one line at the foot: the
	# corners belong to the field HUD (location, brain, minimap, weapon), and a
	# looked-at capture showed REC, the clock and the cell all buried under it.
	# v02-51: set in the device's own type and palette (CellOutzType, bone,
	# copper, moss), so the lens reads as a page of the same phone.
	var elapsed := int(clock)
	var strip := "%02d:%02d:%02d     %s     %02d%% CELL" % [elapsed / 3600, (elapsed / 60) % 60, elapsed % 60, WorldClock.stamp(), roundi(sensor.battery * 100.0)]
	var cap := 11.0
	var rec_width := CellOutzType.width("REC", cap, 1.0)
	var strip_width := rec_width + 18.0 + CellOutzType.width_condensed(strip, cap, 0.9)
	var left := size.x * 0.5 - strip_width * 0.5
	overlay.draw_rect(Rect2(Vector2(left - 30, 26), Vector2(strip_width + 44, 40)), Color(0, 0, 0, 0.5))
	if fmod(clock, 1.2) < 0.8:
		overlay.draw_circle(Vector2(left - 16, 42), 6.0, REC_RED)
	CellOutzType.draw_text(overlay, Vector2(left, 36), "REC", cap, REC_RED, 1.0)
	CellOutzType.draw_condensed(overlay, Vector2(left + rec_width + 18.0, 36), strip, cap, INK, 0.9)
	var cell := Rect2(Vector2(left, 56), Vector2(strip_width, 3))
	overlay.draw_rect(cell, INK * Color(1, 1, 1, 0.15))
	overlay.draw_rect(Rect2(cell.position, Vector2(cell.size.x * float(sensor.battery), cell.size.y)), (MOSS if sensor.battery > 0.2 else REC_RED) * Color(1, 1, 1, 0.9))
	var title := "BLACK MIRROR  /  DEPTH  LIDAR" if mode == "depth" else "BLACK MIRROR  /  LOW-LIGHT"
	var tracked_count := (tracker.get("targets") as Array).size() if tracker != null else 0
	var telemetry := ("RANGE %.1fM   %02d TRACKED" % [sensor.focus_distance, tracked_count]) if mode == "depth" else ("GAIN X%.1f   EXP %.1f   FOCUS %.1fM" % [sensor.gain, sensor.exposure, sensor.focus_distance])
	var hints := hint_line if hint_line != "" else "N RECORD  /  SHIFT+L MODE  /  L LOWER"
	var line := "%s     %s     %s" % [title, telemetry, hints]
	var line_width := CellOutzType.width_condensed(line, 9.0, 0.7)
	# A dark backing, so the readout holds on the depth image's white as well.
	overlay.draw_rect(Rect2(Vector2(size.x * 0.5 - line_width * 0.5 - 12, size.y - 108), Vector2(line_width + 24, 24)), Color(0, 0, 0, 0.62))
	CellOutzType.draw_condensed(overlay, Vector2(size.x * 0.5 - line_width * 0.5, size.y - 100), line, 9.0, INK * Color(1, 1, 1, 0.85), 0.7)
	if mode == "depth":
		_draw_operator_chain(Vector2(34, size.y - 160))


## The TouchDesigner network this image is, drawn as the operator chain in the
## corner: what Greg asked the depth camera to be, said on the glass. A pulse
## runs the wires at the scan rate.
const CHAIN := ["DEPTH", "EDGE", "NORMAL", "POINTS", "SCAN", "TRACK"]


func _draw_operator_chain(at: Vector2) -> void:
	var box := Vector2(52, 18)
	var gap := 12.0
	var pulse := fmod(clock * 1.4, float(CHAIN.size()))
	for index in CHAIN.size():
		var origin := at + Vector2(float(index) * (box.x + gap), 0)
		var hot := absf(pulse - float(index)) < 0.5
		overlay.draw_rect(Rect2(origin, box), Color(0, 0, 0, 0.66))
		overlay.draw_rect(Rect2(origin, box), (AMBER if hot else INK * Color(1, 1, 1, 0.45)), false, 1.0)
		var word: String = CHAIN[index]
		var word_width := CellOutzType.width_condensed(word, 7.0, 0.55)
		CellOutzType.draw_condensed(overlay, origin + Vector2((box.x - word_width) * 0.5, 5.5), word, 7.0, AMBER if hot else INK, 0.55)
		if index > 0:
			overlay.draw_line(origin + Vector2(-gap, box.y * 0.5), origin + Vector2(0, box.y * 0.5), INK * Color(1, 1, 1, 0.5), 1.0)
