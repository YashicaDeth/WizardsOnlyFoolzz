class_name SignalSight
extends Node

## Greg, 26 September: the cameras send invisible signals "that you can only
## see in those special K and J modes". Question boxes, same day:
##  K = wizard eyes, a toggle. J = the depth scan, held. Both from the brain
##  hack on (the host sets `enabled`). Free, but the view strains the longer
##  you stay in: static from the edges, blur, then a nosebleed; leaving clears
##  it. Only hacked cameras notice you doing it.
##  Wizard eyes shows camera signals as pulsing wave rings, and spirits as
##  glowing green figures where people died. The depth scan shows camera
##  signals and bodies through walls.
##
## One component per scene: `add_child`, then `setup(camera)`. The host feeds
## `spirits` (world positions) and `bodies` (a Callable returning positions).

const SHADER := preload("res://shaders/signal_sight.gdshader")
const BONE := Color("e6d4ac")
const ACID := Color("b4da48")
const BLOOD := Color("a8281a")
const COLD := Color("59d9f2")
## Seconds in a mode until the strain is total, and to clear it again.
const STRAIN_SECONDS := 22.0
const RECOVER_SECONDS := 6.0

var enabled := false
var mode := ""  # "", "wizard", "depth"
var strain := 0.0
var clock := 0.0
var spirits: Array = []
var bodies: Callable = Callable()
var view: Camera3D
var layer: CanvasLayer
var screen: ColorRect
var marks: Control
var _material: ShaderMaterial
var _wizard_on := false
var _depth_held := false


func setup(camera: Camera3D) -> void:
	view = camera
	layer = CanvasLayer.new()
	layer.name = "SignalSight"
	# Over the world and its grade, under every HUD.
	layer.layer = -40
	add_child(layer)
	screen = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	screen.material = _material
	layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks = Control.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(marks)
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.draw.connect(_draw_marks)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_K and key.pressed:
		toggle_wizard()
	elif key.keycode == KEY_J:
		hold_depth(key.pressed)


func toggle_wizard() -> void:
	if not enabled:
		return
	_wizard_on = not _wizard_on
	_apply()


func hold_depth(held: bool) -> void:
	_depth_held = held and enabled
	_apply()


func _apply() -> void:
	var was := mode
	mode = "depth" if _depth_held else ("wizard" if _wizard_on else "")
	if mode != was and mode != "":
		WorldHistory.record_event("signal_sight_used", {"mode": mode})
		_notice_hacked()


## Only hacked cameras notice: a looped camera's loop breaks when you look at
## the network through the chip it was looped by.
func _notice_hacked() -> void:
	for lens in SecurityCamera.all_cameras():
		if lens.looped_for > 0.0:
			lens.looped_for = 0.0
			WorldHistory.record_event("hacked_camera_noticed_sight", {"camera_id": lens.camera_id})


func _process(delta: float) -> void:
	clock += delta
	if mode != "":
		strain = minf(1.0, strain + delta / STRAIN_SECONDS)
	else:
		strain = maxf(0.0, strain - delta / RECOVER_SECONDS)
	if _material != null:
		_material.set_shader_parameter("mode", {"": 0, "wizard": 1, "depth": 2}[mode])
		_material.set_shader_parameter("strain", strain)
	if marks != null:
		marks.queue_redraw()


func _project(point: Vector3) -> Variant:
	if view == null or not is_instance_valid(view) or view.is_position_behind(point):
		return null
	return view.unproject_position(point)


func _draw_marks() -> void:
	if mode == "" and strain <= 0.0:
		return
	if mode != "":
		_draw_signals()
		if mode == "wizard":
			_draw_spirits()
		else:
			_draw_bodies()
		CellOutzType.draw_string_compat(marks, Vector2(24, marks.size.y * 0.2), "WIZARD EYES  //  K" if mode == "wizard" else "DEPTH  //  J", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACID if mode == "wizard" else COLD)
	# The nosebleed: past halfway, blood runs down from the top of the view.
	if strain > 0.5:
		var run := clampf((strain - 0.5) / 0.5, 0.0, 1.0)
		var x := marks.size.x * 0.46
		marks.draw_line(Vector2(x, 0), Vector2(x + sin(clock) * 3.0, marks.size.y * 0.55 * run), Color(BLOOD, 0.85), 6.0)
		marks.draw_circle(Vector2(x + sin(clock) * 3.0, marks.size.y * 0.55 * run), 5.0, Color(BLOOD, 0.9))


## Each camera's signal: rings pulsing out of the lens along what it sees.
func _draw_signals() -> void:
	var tone := ACID if mode == "wizard" else COLD
	for lens in SecurityCamera.all_cameras():
		if lens.broken:
			continue
		var eye: Vector3 = lens.eye()
		var forward: Vector3 = lens.forward()
		for ring in 6:
			var along := fmod(float(ring) / 6.0 + clock * 0.35, 1.0)
			var distance := along * SecurityCamera.RANGE
			var centre: Vector3 = eye + forward * distance
			var at = _project(centre)
			if at == null:
				continue
			var edge = _project(centre + view.global_transform.basis.x * tan(SecurityCamera.HALF_ANGLE) * distance)
			var radius := 6.0 if edge == null else maxf(3.0, (edge as Vector2).distance_to(at))
			var alpha := (1.0 - along) * (0.9 if lens.tracking else 0.55)
			marks.draw_arc(at, radius, 0.0, TAU, 32, Color(BLOOD if lens.tracking else tone, alpha), 3.0)
			marks.draw_arc(at, radius + 3.0, 0.0, TAU, 32, Color(BLOOD if lens.tracking else tone, alpha * 0.35), 6.0)
		var lens_at = _project(eye)
		if lens_at != null:
			var pulse := 5.0 + 3.0 * absf(sin(clock * 4.0))
			marks.draw_circle(lens_at, pulse + 4.0, Color(tone, 0.25))
			marks.draw_circle(lens_at, pulse, Color(tone, 0.95))


## Where people died: soft green figures standing there.
func _draw_spirits() -> void:
	for point in spirits:
		var feet = _project(point)
		var head = _project(point + Vector3(0, 1.75, 0))
		if feet == null or head == null:
			continue
		var height: float = (feet as Vector2).distance_to(head)
		var sway := sin(clock * 1.3 + point.x) * height * 0.03
		var top: Vector2 = head + Vector2(sway, 0)
		for glow in 3:
			var grow := float(3 - glow) * height * 0.04
			var colour := Color(ACID, 0.12 + 0.18 * float(glow))
			marks.draw_circle(top + Vector2(0, height * 0.1), height * 0.1 + grow, colour)
			var body := PackedVector2Array([top + Vector2(-height * 0.14 - grow, height * 0.22), top + Vector2(height * 0.14 + grow, height * 0.22), feet + Vector2(height * 0.1 + grow, 0), feet + Vector2(-height * 0.1 - grow, 0)])
			marks.draw_colored_polygon(body, colour)


## Bodies through walls, as X-ray outlines.
func _draw_bodies() -> void:
	if not bodies.is_valid():
		return
	for point in bodies.call():
		var feet = _project(point)
		var head = _project(point + Vector3(0, 1.8, 0))
		if feet == null or head == null:
			continue
		var height: float = (feet as Vector2).distance_to(head)
		var w := height * 0.2
		marks.draw_rect(Rect2((head as Vector2) - Vector2(w, 0), Vector2(w * 2.0, height)), Color(COLD, 0.9), false, 2.0)
		marks.draw_circle((head as Vector2) + Vector2(0, height * 0.1), height * 0.08, Color(COLD, 0.6))
