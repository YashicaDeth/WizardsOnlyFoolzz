class_name HologramCall
extends Control

## The doctor's 3D call (Greg, 24 September): "he projects you a 3d call of
## himself which is getting the elvator out and exiting the building on the
## top on a helicopter so you see this in a 3d touchdesigner deisgned
## animation that pops up".
##
## Greg's TouchDesigner piece does not exist yet, so this is an in-engine
## stand-in: a hologram-shaded miniature of the building, the lift car rising
## up its shaft with him in it, the roof, and a helicopter spinning up and
## lifting off. Everything goes through `play()`, and **if a rendered file
## exists at `res://art/calls/<call_id>.ogv` that plays instead**, with the
## same frame, subtitles and `finished` signal, so dropping his animation in
## never touches the encounter that calls this.
##
## The subtitles are PLACEHOLDER lines in the doctor's register
## (`doctor_examination.gd`: he explains, he does not gloat). His name and
## history are open (DESIGN/ESCAPE_ROUTES.md, "Still open").

signal finished(call_id: String)

const HOLOGRAM_SHADER := preload("res://shaders/hologram.gdshader")
const CALL_DIR := "res://art/calls/"
const DURATION := 15.0
const OPEN_SECONDS := 0.45

## [from, to, line]. PLACEHOLDER, all of them.
const DOCTOR_LINES := [
	[0.6, 4.2, "You hit light. I would have been disappointed if you hadn't tried."],
	[4.2, 7.8, "I was in the lift before you were out of the tank. I always am."],
	[7.8, 11.4, "The roof. You'll want to know that. You won't get there today."],
	[11.4, 14.6, "Keep the emitter. Call someone. See who comes."],
]

## Where the miniature's parts sit, in its own small world.
const SHAFT_TOP := 6.0
const PAD_AT := Vector3(1.7, SHAFT_TOP, 0.0)
const KIOSK_AT := Vector3(0.0, SHAFT_TOP, 0.0)

var call_id := "doctor_call"
var caller := "THE VISITING DOCTOR"
var clock := 0.0
var playing := false
var using_video := false

var frame: Panel
var header: Label
var subtitle: Label
var container: SubViewportContainer
var viewport: SubViewport
var video: VideoStreamPlayer
var camera: Camera3D
var hologram: ShaderMaterial
var car: Node3D
var figure: Node3D
var helicopter: Node3D
var rotor: Node3D
var tail_rotor: Node3D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


## The one entry point. Plays Greg's file if there is one, else the miniature.
func play(id: String = "doctor_call", caller_name: String = "THE VISITING DOCTOR") -> void:
	call_id = id
	caller = caller_name.to_upper()
	clock = 0.0
	playing = true
	visible = true
	_clear()
	_build_frame()
	var path := CALL_DIR + id + ".ogv"
	var stream: VideoStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as VideoStream
	using_video = stream != null
	if using_video:
		video = VideoStreamPlayer.new()
		video.stream = stream
		video.expand = true
		video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video.finished.connect(_end)
		container.add_sibling(video)
		container.visible = false
		video.play()
	else:
		_build_miniature()
	WorldHistory.record_event("hologram_call_shown", {"call_id": id, "source": "video" if using_video else "in_engine"})
	_pose(0.0)
	set_process(true)


## Jump the miniature to a moment. Captures and tests use it; play uses it
## every frame.
func seek(seconds: float) -> void:
	clock = clampf(seconds, 0.0, DURATION)
	_pose(clock)


func skip() -> void:
	if playing:
		_end()


func _process(delta: float) -> void:
	if not playing:
		return
	clock += delta
	_pose(clock)
	if not using_video and clock >= DURATION:
		_end()


func _end() -> void:
	if not playing:
		return
	playing = false
	visible = false
	set_process(false)
	finished.emit(call_id)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	frame = null
	video = null


func _build_frame() -> void:
	frame = Panel.new()
	frame.name = "CallFrame"
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -380
	frame.offset_right = 380
	frame.offset_top = -250
	frame.offset_bottom = 230
	frame.pivot_offset = Vector2(380, 240)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.04, 0.05, 0.9)
	style.border_color = Color("5fd6e8")
	style.set_border_width_all(2)
	style.shadow_color = Color(0.2, 0.8, 1.0, 0.25)
	style.shadow_size = 18
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	header = Label.new()
	header.position = Vector2(16, 8)
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color("8ff0ff"))
	frame.add_child(header)
	container = SubViewportContainer.new()
	container.stretch = true
	container.position = Vector2(12, 36)
	container.size = Vector2(736, 368)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(736, 368)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	subtitle = Label.new()
	subtitle.position = Vector2(16, 410)
	subtitle.size = Vector2(728, 56)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("e6fbff"))
	frame.add_child(subtitle)


func _holo(strength := 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = HOLOGRAM_SHADER
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("line_density", 14.0)
	material.set_shader_parameter("split", 0.02)
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	parent.add_child(piece)
	return piece


## The building cut away to its lift shaft, a roof with a helipad, the car, him
## and the helicopter. Primitive on purpose: a stand-in for Greg's piece.
func _build_miniature() -> void:
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("020809")
	environment.environment = sky
	world.add_child(environment)
	hologram = _holo(1.0)
	var faint := _holo(0.22)
	# The tower: four corner posts, a floor plate every storey, open on the
	# camera side so the shaft and the car read.
	for x in [-0.6, 0.6]:
		for z in [-0.6, 0.6]:
			_box(world, Vector3(0.06, SHAFT_TOP, 0.06), Vector3(x, SHAFT_TOP * 0.5, z), hologram)
	for storey in 7:
		var y := float(storey)
		_box(world, Vector3(3.2, 0.04, 2.2), Vector3(0.8, y, -0.4), faint)
	# Shaft rails.
	for x in [-0.32, 0.32]:
		_box(world, Vector3(0.03, SHAFT_TOP + 0.6, 0.03), Vector3(x, SHAFT_TOP * 0.5, 0.0), hologram)
	# The roof: the lift kiosk and the pad.
	_box(world, Vector3(4.6, 0.08, 3.0), Vector3(1.0, SHAFT_TOP, -0.2), hologram)
	_box(world, Vector3(0.9, 0.9, 0.9), KIOSK_AT + Vector3(0, 0.45, 0), faint)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.9
	disc.height = 0.03
	pad.mesh = disc
	pad.material_override = hologram
	pad.position = PAD_AT + Vector3(0, 0.05, 0)
	world.add_child(pad)
	_box(world, Vector3(0.06, 0.02, 0.6), PAD_AT + Vector3(-0.2, 0.08, 0), hologram)
	_box(world, Vector3(0.06, 0.02, 0.6), PAD_AT + Vector3(0.2, 0.08, 0), hologram)
	_box(world, Vector3(0.4, 0.02, 0.06), PAD_AT + Vector3(0, 0.08, 0), hologram)
	# The car and him in it.
	car = Node3D.new()
	world.add_child(car)
	_box(car, Vector3(0.56, 0.04, 0.56), Vector3(0, 0, 0), hologram)
	_box(car, Vector3(0.56, 0.04, 0.56), Vector3(0, 0.8, 0), hologram)
	for x in [-0.27, 0.27]:
		_box(car, Vector3(0.02, 0.8, 0.56), Vector3(x, 0.4, 0), faint)
	figure = Node3D.new()
	world.add_child(figure)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.11
	capsule.height = 0.52
	body.mesh = capsule
	body.material_override = hologram
	body.position.y = 0.3
	figure.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	head.mesh = sphere
	head.material_override = hologram
	head.position.y = 0.66
	figure.add_child(head)
	# His coat's tail, so the figure reads as the man in the long coat.
	_box(figure, Vector3(0.26, 0.3, 0.05), Vector3(0, 0.2, 0.1), faint)
	# The helicopter.
	helicopter = Node3D.new()
	world.add_child(helicopter)
	var hull := MeshInstance3D.new()
	var hull_mesh := CapsuleMesh.new()
	hull_mesh.radius = 0.28
	hull_mesh.height = 1.1
	hull.mesh = hull_mesh
	hull.material_override = hologram
	hull.rotation_degrees.z = 90.0
	hull.position.y = 0.4
	helicopter.add_child(hull)
	_box(helicopter, Vector3(1.1, 0.08, 0.08), Vector3(-0.95, 0.5, 0), hologram)
	_box(helicopter, Vector3(0.05, 0.3, 0.05), Vector3(0, 0.75, 0), hologram)
	for z in [-0.22, 0.22]:
		_box(helicopter, Vector3(0.9, 0.03, 0.04), Vector3(0, 0.08, z), hologram)
	rotor = Node3D.new()
	rotor.position = Vector3(0, 0.9, 0)
	helicopter.add_child(rotor)
	_box(rotor, Vector3(2.4, 0.02, 0.09), Vector3.ZERO, hologram)
	_box(rotor, Vector3(0.09, 0.02, 2.4), Vector3.ZERO, hologram)
	tail_rotor = Node3D.new()
	tail_rotor.position = Vector3(-1.5, 0.55, 0.06)
	helicopter.add_child(tail_rotor)
	_box(tail_rotor, Vector3(0.03, 0.45, 0.04), Vector3.ZERO, hologram)
	camera = Camera3D.new()
	camera.fov = 42.0
	world.add_child(camera)


## Everything in the call is a function of time, so a capture can stand at any
## moment of it and a test can check where he is.
##   0.0-1.2  the call opens on the shaft
##   1.2-6.0  the car climbs the shaft with him in it
##   6.0-9.0  he walks from the kiosk to the pad; the rotor starts turning
##   9.0-10.5 he boards; the rotor runs up
##  10.5-15.0 the helicopter lifts off, tips its nose and goes
func _pose(t: float) -> void:
	if frame != null:
		var opening := clampf(t / OPEN_SECONDS, 0.0, 1.0)
		var closing := clampf((DURATION - t) / 0.35, 0.0, 1.0)
		frame.scale = Vector2(1.0, maxf(0.02, ease(minf(opening, closing), 0.4)))
		header.text = "INCOMING 3D CALL // %s // %s" % [caller, _timecode(t)]
		subtitle.text = line_at(t)
	if using_video or car == null:
		return
	var rise := clampf((t - 1.2) / 4.8, 0.0, 1.0)
	var car_y := lerpf(0.0, SHAFT_TOP, ease(rise, -1.6))
	car.position = Vector3(0, car_y, 0)
	var walk := clampf((t - 6.0) / 3.0, 0.0, 1.0)
	if t < 6.0:
		figure.position = Vector3(0, car_y + 0.04, 0)
	else:
		figure.position = KIOSK_AT.lerp(PAD_AT + Vector3(-0.35, 0, 0.45), ease(walk, -1.4)) + Vector3(0, 0.04, 0)
		figure.position.y += absf(sin(t * 9.0)) * 0.025 * (1.0 if walk < 1.0 else 0.0)
	figure.visible = t < 9.8
	var spin := clampf((t - 6.5) / 4.0, 0.0, 1.0)
	# Angle is the integral of a speed that ramps up, so scrubbing is smooth.
	rotor.rotation.y = spin * spin * 40.0 + maxf(0.0, t - 10.5) * 32.0
	tail_rotor.rotation.z = rotor.rotation.y * 1.7
	var lift := clampf((t - 10.5) / 4.5, 0.0, 1.0)
	helicopter.position = PAD_AT + Vector3(lift * lift * 5.0, ease(lift, -1.8) * 3.2, lift * lift * -1.5)
	helicopter.rotation = Vector3(0, lift * 0.5, -lift * 0.35)
	hologram.set_shader_parameter("glitch", 0.35 if fmod(t, 3.1) < 0.12 else 0.0)
	# Camera: side-on up the shaft, then back and up to hold the roof.
	var shaft_eye := Vector3(2.4, car_y + 0.9, 3.4)
	var shaft_look := Vector3(0.1, car_y + 0.4, 0)
	var roof_eye := Vector3(3.8, SHAFT_TOP + 2.2 + lift * 1.6, 5.6)
	var roof_look := PAD_AT.lerp(helicopter.position, 0.6) + Vector3(-0.4, 0.3, 0)
	var cut := clampf((t - 5.2) / 1.6, 0.0, 1.0)
	camera.position = shaft_eye.lerp(roof_eye, ease(cut, -1.8))
	camera.look_at(shaft_look.lerp(roof_look, ease(cut, -1.8)), Vector3.UP)


func line_at(t: float) -> String:
	for entry in DOCTOR_LINES:
		if t >= float(entry[0]) and t < float(entry[1]):
			return str(entry[2])
	return ""


## Where he is in the miniature, for tests: "shaft", "roof", "boarded", "airborne".
func phase_at(t: float) -> String:
	if t < 6.0:
		return "shaft"
	if t < 9.8:
		return "roof"
	if t < 10.5:
		return "boarded"
	return "airborne"


func _timecode(t: float) -> String:
	return "%02d:%02d" % [int(t), int(fmod(t, 1.0) * 30.0)]
