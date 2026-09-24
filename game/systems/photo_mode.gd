class_name PhotoMode
extends CanvasLayer

## Photo mode (item 6, Greg 2026-09-24). F10 in the Hunt freezes the world and
## hands you a free camera on a leash around where you stood; the shutter writes
## a real image plus what was in frame, read off the rigs by FieldCamera, into
## the album the Brain Index shows (PhotoAlbum).
##
## Photo-mode shots are kept apart from FieldCamera's evidence album on purpose:
## the rituals read that one, and whether a staged photograph should count as
## proof (for a contract, a demon, a Wire profile) is Greg's call, recorded on
## the design page rather than decided here.

signal taken(path: String)

## How far the camera may wander from where you stood.
const RADIUS := 12.0
const FILTERS := ["NATURAL", "DIGICAM", "MONO"]
const SHADER := preload("res://shaders/photo_filter.gdshader")
const CellOutzType := preload("res://systems/celloutz_type.gd")
const AMBER := Color(1.0, 0.55, 0.12)

var active := false
var filter := 0
var fov := 70.0
var hide_ui := false
var cam: Camera3D
## Bodies FieldCamera reads for the caption; the owner fills it on enter.
var rigs: Array = []
var location := ""

var _previous: Camera3D
var _anchor := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _hidden: Array[CanvasLayer] = []
var _was_paused := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE
## False until a frame has passed, so the press that opened photo mode
## cannot also close it.
var _armed := false
var _flash := 0.0
var _last_caption := ""
var _grade: ColorRect
var _stamp: Control
var _ui: Control


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_grade = ColorRect.new()
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade_material := ShaderMaterial.new()
	grade_material.shader = SHADER
	_grade.material = grade_material
	add_child(_grade)
	# The date stamp is part of the picture; the viewfinder is not.
	_stamp = Control.new()
	_stamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.draw.connect(_draw_stamp)
	add_child(_stamp)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	visible = false


func enter(from: Camera3D, anchor: Vector3) -> void:
	if active or from == null or not from.is_inside_tree():
		return
	active = true
	_armed = false
	_previous = from
	_anchor = anchor
	cam = Camera3D.new()
	cam.name = "PhotoModeCamera"
	fov = from.fov
	from.get_parent().add_child(cam)
	cam.global_transform = from.global_transform
	var euler := from.global_transform.basis.get_euler()
	_pitch = euler.x
	_yaw = euler.y
	cam.make_current()
	_was_paused = get_tree().paused
	get_tree().paused = true
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var canvas := node as CanvasLayer
		if canvas != self and canvas.visible:
			canvas.visible = false
			_hidden.append(canvas)
	_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_filter()
	visible = true


func exit() -> void:
	if not active:
		return
	active = false
	for canvas in _hidden:
		if is_instance_valid(canvas):
			canvas.visible = true
	_hidden.clear()
	if is_instance_valid(_previous):
		_previous.make_current()
	if is_instance_valid(cam):
		cam.queue_free()
	cam = null
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	visible = false


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	if not active or cam == null:
		return
	_armed = true
	var move := Vector3(
		_axis(KEY_D, KEY_A), _axis(KEY_E, KEY_Q), _axis(KEY_S, KEY_W))
	var speed := 3.0 * (2.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	var basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var position := cam.global_position + basis * move * speed * delta
	position = _anchor + (position - _anchor).limit_length(RADIUS)
	cam.global_transform = Transform3D(basis, position)
	cam.fov = fov
	_stamp.queue_redraw()
	_ui.queue_redraw()


func _axis(positive: Key, negative: Key) -> float:
	return float(Input.is_physical_key_pressed(positive)) - float(Input.is_physical_key_pressed(negative))


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.003
		_pitch = clampf(_pitch - motion.relative.y * 0.003, -1.45, 1.45)
		return true
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return true
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				fov = maxf(15.0, fov - 3.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				fov = minf(110.0, fov + 3.0)
			MOUSE_BUTTON_LEFT:
				shoot()
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return true
		match key.keycode:
			KEY_ESCAPE, KEY_F10:
				if _armed:
					exit()
			KEY_SPACE:
				shoot()
			KEY_F:
				filter = (filter + 1) % FILTERS.size()
				_apply_filter()
			KEY_H:
				hide_ui = not hide_ui
		return true
	return false


func _apply_filter() -> void:
	_grade.visible = filter != 0
	(_grade.material as ShaderMaterial).set_shader_parameter("mode", filter)


## Takes the picture. Awaitable; returns the saved PNG's path.
func shoot() -> String:
	if not active:
		return ""
	_ui.visible = false
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_ui.visible = true
	if image == null or image.is_empty():
		return ""
	var photo := FieldCamera.capture(cam, rigs, location) if cam != null else {}
	var path := PhotoAlbum.save(image, {
		"hour": WorldClock.hour(),
		"filter": FILTERS[filter],
		"fov": fov,
		"location": location,
		"caption": str(photo.get("caption", "")),
	})
	_last_caption = str(photo.get("caption", ""))
	_flash = 1.0
	taken.emit(path)
	return path


func _clock_text() -> String:
	var hour := WorldClock.hour()
	return "%02d:%02d" % [int(hour) % 24, int(fposmod(hour, 1.0) * 60.0)]


## The Y2K digicam's orange LED time in the corner, burnt into the picture.
func _draw_stamp() -> void:
	if not active or FILTERS[filter] != "DIGICAM":
		return
	var size := _stamp.size
	var text := _clock_text()
	var height := 16.0
	var width := CellOutzType.width(text, height, 3.0)
	var at := Vector2(size.x - width - 34.0, size.y - height - 30.0)
	CellOutzType.draw_text(_stamp, at + Vector2(1, 1), text, height, Color(0.25, 0.05, 0.0, 0.6), 3.0)
	CellOutzType.draw_text(_stamp, at, text, height, AMBER, 3.0)


func _draw_ui() -> void:
	if not active:
		return
	var size := _ui.size
	if _flash > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * 0.8))
	if hide_ui:
		return
	var ink := Color(1, 1, 1, 0.7)
	var faint := Color(1, 1, 1, 0.14)
	# Rule of thirds, then the viewfinder's corner brackets.
	for i in [1, 2]:
		_ui.draw_line(Vector2(size.x * i / 3.0, 0), Vector2(size.x * i / 3.0, size.y), faint, 1.0)
		_ui.draw_line(Vector2(0, size.y * i / 3.0), Vector2(size.x, size.y * i / 3.0), faint, 1.0)
	var inset := 28.0
	var arm := 36.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var point := Vector2(lerpf(inset, size.x - inset, corner.x), lerpf(inset, size.y - inset, corner.y))
		var out := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0)
		_ui.draw_line(point, point + Vector2(out.x * arm, 0), ink, 2.0)
		_ui.draw_line(point, point + Vector2(0, out.y * arm), ink, 2.0)
	var line := "LMB SHOOT   WHEEL ZOOM %dMM   F %s   WASD QE MOVE   H HIDE   ESC LEAVE" % [int(_focal_length()), FILTERS[filter]]
	CellOutzType.draw_text(_ui, Vector2(inset + 8, inset + 10), "PHOTO MODE", 12.0, ink, 1.5)
	CellOutzType.draw_text(_ui, Vector2(inset + 8, size.y - inset - 22), line, 9.0, ink, 1.0)
	if not _last_caption.is_empty():
		CellOutzType.draw_text(_ui, Vector2(inset + 8, inset + 30), "LAST: " + _last_caption.to_upper(), 9.0, faint.lightened(0.5), 1.0)


## Vertical FOV to a 35 mm-equivalent focal length, for the readout.
func _focal_length() -> float:
	return 12.0 / tan(deg_to_rad(fov) * 0.5)
