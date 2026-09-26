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
## `spirits` (world positions), `bodies` (a Callable returning positions) and
## `hidden`: things only the modes show (weak walls, stashes, secret doors),
## each {"id", "at" (centre), "size" (Vector2 width, height), "across"
## (Vector3 along the width)}. `hidden_seen(id)` fires the first time one is
## on screen and near in either mode.

signal hidden_seen(id: String)
## Wires and power (Greg, 26 September: the modes reveal "wires and power").
## `wires`: each {"id", "points" (Array of Vector3, from the supply to what
## it feeds), "on_cut" (Callable)}. Seen in either mode, a wire can then be
## cut at its supply end with `cut_wire_near()`; the host binds that to E.
signal wire_cut(id: String)

const SHADER := preload("res://shaders/signal_sight.gdshader")
const SIGHT_AUDIO := preload("res://systems/sight_audio.gd")
const BONE := Color("e6d4ac")
const ACID := Color("b4da48")
const BLOOD := Color("a8281a")
const COLD := Color("59d9f2")
## Seconds in a mode until the strain is total, and to clear it again.
const STRAIN_SECONDS := 22.0
const RECOVER_SECONDS := 6.0

var enabled := false
## False when the host reads K and J itself (the Hunt: tap K for wizard eyes,
## hold K to re-decant).
var handle_keys := true
var mode := ""  # "", "wizard", "depth"
var strain := 0.0
var clock := 0.0
var spirits: Array = []
var bodies: Callable = Callable()
var hidden: Array = []
var wires: Array = []
## How close the supply end of a seen wire must be to cut it, in metres.
const WIRE_REACH := 1.7
var seen: Dictionary = {}
## How close a hidden thing has to be to be noticed, in metres.
const HIDDEN_RANGE := 9.0
var view: Camera3D
var layer: CanvasLayer
var screen: ColorRect
var marks: Control
var _material: ShaderMaterial
## K's choir hum and J's sonar ping (Greg, 26 September).
var choir: AudioStreamPlayer
var sonar: AudioStreamPlayer
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
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	choir = AudioStreamPlayer.new()
	choir.name = "WizardEyesChoir"
	choir.stream = SIGHT_AUDIO.stream("choir")
	choir.bus = bus
	add_child(choir)
	sonar = AudioStreamPlayer.new()
	sonar.name = "DepthSonar"
	sonar.stream = SIGHT_AUDIO.stream("sonar")
	sonar.bus = bus
	sonar.volume_db = -12.0
	add_child(sonar)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not handle_keys or not (event is InputEventKey) or event.echo:
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
	# Off, the whole layer sleeps: a screen-reading shader copies the frame
	# every frame it is visible, even when it draws nothing.
	var active := mode != "" or strain > 0.0
	if layer != null:
		layer.visible = active
	_update_audio()
	if not active:
		return
	if mode != "":
		_notice_hidden()
		_notice_wires()
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
		_draw_hidden()
		_draw_wires()
		CellOutzType.draw_string_compat(marks, Vector2(marks.size.x * 0.05, marks.size.y * 0.2), "WIZARD EYES  //  K" if mode == "wizard" else "DEPTH  //  J", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACID if mode == "wizard" else COLD)
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


## Hidden things: the outline of what is really there, cracks in wizard eyes,
## the hollow behind it in the depth scan. Noticed once on screen and near.
func _draw_hidden() -> void:
	var tone := ACID if mode == "wizard" else COLD
	var pulse := 0.55 + 0.45 * absf(sin(clock * 3.0))
	for thing: Dictionary in hidden:
		if bool(thing.get("gone", false)):
			continue
		var at: Vector3 = thing.get("at", Vector3.ZERO)
		if view == null or not is_instance_valid(view) or view.global_position.distance_to(at) > HIDDEN_RANGE:
			continue
		var size: Vector2 = thing.get("size", Vector2.ONE)
		var across: Vector3 = (thing.get("across", Vector3.RIGHT) as Vector3).normalized()
		var corners: Array = []
		for c in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
			var p = _project(at + across * c.x * size.x + Vector3.UP * c.y * size.y)
			if p == null:
				corners.clear()
				break
			corners.append(p)
		if corners.is_empty():
			continue
		var outline := PackedVector2Array(corners)
		outline.append(corners[0])
		marks.draw_polyline(outline, Color(tone, 0.9 * pulse), 3.0)
		var centre: Vector2 = (corners[0] + corners[2]) * 0.5
		if mode == "wizard":
			# Cracks out from the middle, jagged, each forking once: the plaster
			# is already failing, you just could not see it.
			var span := (corners[2] as Vector2).distance_to(corners[0])
			for index in 4:
				var corner: Vector2 = corners[index]
				var line := PackedVector2Array([centre])
				for step in range(1, 6):
					var t := float(step) / 6.0
					var side := (corner - centre).orthogonal().normalized()
					var kink := sin(float(index * 7 + step) * 2.9) * span * 0.05
					line.append(centre.lerp(corner, t) + side * kink)
				line.append(corner)
				marks.draw_polyline(line, Color(tone, 0.65 * pulse), 2.0)
				var fork_from: Vector2 = line[3]
				var fork_to := fork_from + (corner - centre).rotated(0.7 if index % 2 == 0 else -0.7) * 0.22
				marks.draw_line(fork_from, fork_to, Color(tone, 0.45 * pulse), 1.5)
		else:
			marks.draw_colored_polygon(PackedVector2Array(corners), Color(0, 0, 0, 0.55))
			CellOutzType.draw_string_compat(marks, centre + Vector2(-26, 5), "HOLLOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(tone, pulse))


## Noticed the first time one is near and its middle is on screen in a mode.
func _notice_hidden() -> void:
	if view == null or not is_instance_valid(view):
		return
	var screen_rect := Rect2(Vector2.ZERO, view.get_viewport().get_visible_rect().size)
	for thing: Dictionary in hidden:
		var id := str(thing.get("id", ""))
		if seen.has(id) or bool(thing.get("gone", false)):
			continue
		var at: Vector3 = thing.get("at", Vector3.ZERO)
		if view.global_position.distance_to(at) > HIDDEN_RANGE:
			continue
		var centre = _project(at)
		if centre == null or not screen_rect.has_point(centre):
			continue
		seen[id] = true
		WorldHistory.record_event("signal_sight_found_hidden", {"id": id, "mode": mode})
		hidden_seen.emit(id)


## Power along each wire: pulses running from the supply to what it feeds.
## A cut wire hangs dark red with a gap where it was cut.
func _draw_wires() -> void:
	var tone := ACID if mode == "wizard" else COLD
	for wire: Dictionary in wires:
		var points: Array = wire.get("points", [])
		if points.size() < 2 or view == null or view.global_position.distance_to(points[0]) > HIDDEN_RANGE * 2.0:
			continue
		var cut := bool(wire.get("cut", false))
		var flat := PackedVector2Array()
		for point in points:
			var at = _project(point)
			if at == null:
				flat.clear()
				break
			flat.append(at)
		if flat.size() < 2:
			continue
		if cut:
			var gap := flat.duplicate()
			gap[0] = flat[0].lerp(flat[1], 0.25)
			marks.draw_polyline(gap, Color(BLOOD, 0.6), 2.0)
			continue
		marks.draw_polyline(flat, Color(tone, 0.35), 5.0)
		marks.draw_polyline(flat, Color(tone, 0.85), 1.6)
		# Three pulses travelling toward the load.
		var lengths: Array = [0.0]
		for index in range(1, flat.size()):
			lengths.append(float(lengths[index - 1]) + flat[index - 1].distance_to(flat[index]))
		var total: float = lengths[lengths.size() - 1]
		if total <= 1.0:
			continue
		for pulse in 3:
			var along := fmod(clock * 0.6 + float(pulse) / 3.0, 1.0) * total
			for index in range(1, flat.size()):
				if along <= float(lengths[index]):
					var t := (along - float(lengths[index - 1])) / maxf(0.001, float(lengths[index]) - float(lengths[index - 1]))
					marks.draw_circle(flat[index - 1].lerp(flat[index], t), 4.0, Color(tone, 0.95))
					break
		marks.draw_circle(flat[0], 7.0, Color(tone, 0.5 + 0.4 * absf(sin(clock * 5.0))))


func _notice_wires() -> void:
	var screen_rect := Rect2(Vector2.ZERO, view.get_viewport().get_visible_rect().size)
	for wire: Dictionary in wires:
		if bool(wire.get("seen", false)):
			continue
		var points: Array = wire.get("points", [])
		if points.is_empty() or view.global_position.distance_to(points[0]) > HIDDEN_RANGE:
			continue
		var at = _project(points[0])
		if at != null and screen_rect.has_point(at):
			wire["seen"] = true
			WorldHistory.record_event("signal_sight_found_wire", {"id": str(wire.get("id", "")), "mode": mode})


## Cuts the nearest seen, live wire whose supply end is within reach.
## Returns its id, or "" when there is none.
func cut_wire_near(position: Vector3) -> String:
	var best: Dictionary = {}
	var best_distance := WIRE_REACH
	for wire: Dictionary in wires:
		if not bool(wire.get("seen", false)) or bool(wire.get("cut", false)):
			continue
		var points: Array = wire.get("points", [])
		if points.is_empty():
			continue
		var supply: Vector3 = points[0]
		var flat := Vector2(supply.x - position.x, supply.z - position.z).length()
		if flat <= best_distance:
			best_distance = flat
			best = wire
	if best.is_empty():
		return ""
	best["cut"] = true
	var id := str(best.get("id", ""))
	var on_cut: Callable = best.get("on_cut", Callable())
	if on_cut.is_valid():
		on_cut.call()
	SIGHT_AUDIO.play_at(self, "spark", (best.get("points", [position]) as Array)[0])
	WorldHistory.record_event("power_wire_cut", {"id": id})
	wire_cut.emit(id)
	return id


func wire_in_reach(position: Vector3) -> bool:
	for wire: Dictionary in wires:
		if bool(wire.get("seen", false)) and not bool(wire.get("cut", false)):
			var supply: Vector3 = (wire.get("points", [Vector3.INF]) as Array)[0]
			if Vector2(supply.x - position.x, supply.z - position.z).length() <= WIRE_REACH:
				return true
	return false


## The hum swells as the strain builds; the ping runs only while J is held.
func _update_audio() -> void:
	if choir == null:
		return
	var wizard := mode == "wizard"
	if wizard and not choir.playing:
		choir.play()
	elif not wizard and choir.playing:
		choir.stop()
	choir.volume_db = lerpf(-20.0, -8.0, strain)
	var depth := mode == "depth"
	if depth and not sonar.playing:
		sonar.play()
	elif not depth and sonar.playing:
		sonar.stop()
