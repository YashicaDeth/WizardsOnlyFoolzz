class_name FacilityElevator
extends Node3D

## A real lift (Greg, 4 October): "you step in, the doors close, the cab
## genuinely descends/ascends through a visible shaft (moving platform, floor
## indicator, hum, light strips passing, shaft glimpsed through gaps) at a
## believable speed, then the doors open on the new level ... No fade."
##
## The cab is an AnimatableBody3D: the player stands on its floor and
## `move_and_slide` carries them, so they keep looking round the whole ride.
## Landing doors and cab doors slide together. Stops are local heights; each
## stop opens one face of the car (-1 = the -Z face, +1 = the +Z face), so a
## through-car can board facing one way and let you out facing the other.
## Placeholder boxes on the DESIGN/FACILITY.md grid until the tunnel kit lands.

signal arrived(stop: int)

const CAR_HALF := Vector2(1.1, 1.1)
const CAR_HEIGHT := 2.7
const SHAFT_HALF := Vector2(1.5, 1.5)
const DOOR_HALF := 0.7
const DOOR_HEIGHT := 2.3
const DOOR_TIME := 1.1
## Believable lift speed, metres per second, with a short ease at each end.
const SPEED := 2.4
const STRIP_EVERY := 3.0
const HUM_RATE := 22050.0

var stops: Array = []
var stop_names: Array = []
var faces: Array = []
var stop := 0
var target := 0
## "open", "closing", "moving", "opening", "closed".
var state := "open"
var doors := 1.0
var cab: AnimatableBody3D
var indicator: Label3D
var landing_labels: Array[Label3D] = []
var _cab_doors := {}
var _landing_doors: Array = []
var _hum: AudioStreamPlayer3D
var _hum_phase := 0.0
var _ride_from := 0.0
var _ride_clock := 0.0
var _hold := 0.0


func setup(stop_heights: Array, names: Array, door_faces: Array, start := 0) -> FacilityElevator:
	stops = stop_heights
	stop_names = names
	faces = door_faces
	stop = start
	target = start
	_build_shaft()
	_build_cab()
	for index in stops.size():
		_build_landing(index)
	_set_cab_y(float(stops[stop]))
	_apply_doors()
	return self


## Called from a landing or from inside the car. Inside: rides to the other
## (next) stop. At a landing: brings the car there, or opens it if it is here.
func use(at: Vector3) -> bool:
	if state in ["moving", "closing"]:
		return false
	if rider_inside(at):
		go_to((stop + 1) % stops.size())
		return true
	var nearest := nearest_landing(at)
	if nearest < 0:
		return false
	if nearest == stop:
		state = "opening"
	else:
		go_to(nearest)
	return true


func go_to(index: int) -> void:
	if index == stop and state == "open":
		return
	target = index
	state = "closing"


func rider_inside(at: Vector3) -> bool:
	var local := cab.to_local(at)
	return absf(local.x) <= CAR_HALF.x and absf(local.z) <= CAR_HALF.y and local.y > -0.3 and local.y < CAR_HEIGHT


## The landing (index) whose doors `at` stands in front of, or -1.
func nearest_landing(at: Vector3) -> int:
	var local := to_local(at)
	for index in stops.size():
		var front := Vector3(0, float(stops[index]), float(faces[index]) * (SHAFT_HALF.y + 1.2))
		var offset := local - front
		if absf(offset.y - 1.0) < 1.6 and Vector2(offset.x, offset.z).length() < 2.2:
			return index
	return -1


func prompt_for(at: Vector3) -> String:
	if state == "moving":
		return "%s  //  %s" % ["GOING UP" if float(stops[target]) > cab.position.y else "GOING DOWN", stop_names[target]]
	if rider_inside(at):
		return "[E] RIDE TO %s" % stop_names[(stop + 1) % stops.size()]
	if nearest_landing(at) >= 0:
		return "[E] CALL THE LIFT"
	return ""


func _physics_process(delta: float) -> void:
	match state:
		"closing":
			doors = move_toward(doors, 0.0, delta / DOOR_TIME)
			if doors <= 0.0:
				if target == stop:
					state = "opening"
				else:
					state = "moving"
					_ride_from = cab.position.y
					_ride_clock = 0.0
		"moving":
			_ride(delta)
		"opening":
			doors = move_toward(doors, 1.0, delta / DOOR_TIME)
			if doors >= 1.0:
				state = "open"
	_apply_doors()
	_feed_hum()


func _ride(delta: float) -> void:
	var goal := float(stops[target])
	var span := absf(goal - _ride_from)
	var duration := span / SPEED + 1.2
	_ride_clock += delta
	var t := clampf(_ride_clock / duration, 0.0, 1.0)
	_set_cab_y(lerpf(_ride_from, goal, smoothstep(0.0, 1.0, t)))
	if t >= 1.0:
		stop = target
		state = "opening"
	indicator.text = _floor_text()
	for label in landing_labels:
		label.text = _floor_text()
	if state == "opening":
		arrived.emit(stop)


func _floor_text() -> String:
	var nearest := 0
	for index in stops.size():
		if absf(float(stops[index]) - cab.position.y) < absf(float(stops[nearest]) - cab.position.y):
			nearest = index
	var arrow := ""
	if state == "moving":
		arrow = "UP " if float(stops[target]) > cab.position.y else "DOWN "
	return arrow + str(stop_names[nearest])


func _set_cab_y(y: float) -> void:
	cab.position.y = y


func _apply_doors() -> void:
	var face := int(faces[stop]) if state != "moving" else 0
	for side: int in _cab_doors:
		var open := doors if side == face else 0.0
		for leaf: Node3D in _cab_doors[side]:
			var sign := signf(leaf.get_meta("home_x"))
			leaf.position.x = float(leaf.get_meta("home_x")) + sign * open * DOOR_HALF * 0.95
	for index in _landing_doors.size():
		var open := doors if index == stop and state != "moving" else 0.0
		for leaf: Node3D in _landing_doors[index]:
			var sign := signf(leaf.get_meta("home_x"))
			leaf.position.x = float(leaf.get_meta("home_x")) + sign * open * DOOR_HALF * 0.95


func _build_shaft() -> void:
	var bottom := float(stops.min()) - 0.6
	var top := float(stops.max()) + CAR_HEIGHT + 1.2
	var height := top - bottom
	var wall := Color("1a1512")
	# Side walls are solid; the two door faces are cut by a landing door at
	# each stop and are otherwise solid too.
	for side: int in [-1, 1]:
		_box(self, Vector3(0.3, height, SHAFT_HALF.y * 2.0 + 0.6), Vector3(side * (SHAFT_HALF.x + 0.15), bottom + height * 0.5, 0), wall)
	for face: int in [-1, 1]:
		var cuts: Array = []
		for index in stops.size():
			if int(faces[index]) == face:
				cuts.append(float(stops[index]))
		cuts.sort()
		var from := bottom
		for y: float in cuts:
			_face_slab(face, from, y, wall)
			# Jambs either side of the landing door; the next slab is its lintel.
			for jamb: int in [-1, 1]:
				var width := SHAFT_HALF.x - DOOR_HALF
				_box(self, Vector3(width, DOOR_HEIGHT, 0.3), Vector3(jamb * (DOOR_HALF + width * 0.5), y + DOOR_HEIGHT * 0.5, face * (SHAFT_HALF.y + 0.15)), wall)
			from = y + DOOR_HEIGHT
		_face_slab(face, from, top, wall)
	_box(self, Vector3(SHAFT_HALF.x * 2.0 + 0.6, 0.3, SHAFT_HALF.y * 2.0 + 0.6), Vector3(0, bottom - 0.15, 0), wall)
	_box(self, Vector3(SHAFT_HALF.x * 2.0 + 0.6, 0.3, SHAFT_HALF.y * 2.0 + 0.6), Vector3(0, top + 0.15, 0), wall)
	# Light strips passing the car's slots: an amber bar every few metres on
	# both side walls, and a real light every other one.
	var strip := StandardMaterial3D.new()
	strip.albedo_color = Color("d2ecc0")
	strip.emission_enabled = true
	strip.emission = Color("b8e0a0")
	strip.emission_energy_multiplier = 3.0
	var y := bottom + 1.5
	var count := 0
	while y < top - 0.5:
		for side: int in [-1, 1]:
			var bar := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.05, 0.08, SHAFT_HALF.y * 1.6)
			bar.mesh = mesh
			bar.material_override = strip
			bar.position = Vector3(side * (SHAFT_HALF.x - 0.03), y, 0)
			add_child(bar)
		if count % 2 == 0:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color("d2ecc0")
			lamp.light_energy = 0.7
			lamp.omni_range = 2.6
			lamp.position = Vector3(SHAFT_HALF.x - 0.3, y, 0)
			add_child(lamp)
		y += STRIP_EVERY
		count += 1


func _face_slab(face: int, from: float, to: float, color: Color) -> void:
	if to - from < 0.05:
		return
	_box(self, Vector3(SHAFT_HALF.x * 2.0 + 0.6, to - from, 0.3), Vector3(0, (from + to) * 0.5, face * (SHAFT_HALF.y + 0.15)), color)


func _build_cab() -> void:
	cab = AnimatableBody3D.new()
	cab.name = "Cab"
	cab.sync_to_physics = true
	add_child(cab)
	var steel := Color("3a332c")
	_box(cab, Vector3(CAR_HALF.x * 2.0, 0.2, CAR_HALF.y * 2.0), Vector3(0, -0.1, 0), Color("2a2420"), true)
	_box(cab, Vector3(CAR_HALF.x * 2.0, 0.12, CAR_HALF.y * 2.0), Vector3(0, CAR_HEIGHT + 0.06, 0), steel, true)
	# Side walls with a slot at eye height: the shaft goes by through it.
	for side: int in [-1, 1]:
		var x := side * (CAR_HALF.x + 0.05)
		_box(cab, Vector3(0.1, 1.35, CAR_HALF.y * 2.0), Vector3(x, 0.675, 0), steel, true)
		_box(cab, Vector3(0.1, 0.85, CAR_HALF.y * 2.0), Vector3(x, CAR_HEIGHT - 0.425, 0), steel, true)
		_box(cab, Vector3(0.1, 0.5, 0.4), Vector3(x, 1.6, CAR_HALF.y - 0.2), steel, true)
		_box(cab, Vector3(0.1, 0.5, 0.4), Vector3(x, 1.6, -CAR_HALF.y + 0.2), steel, true)
	for face: int in [-1, 1]:
		var z := face * (CAR_HALF.y + 0.05)
		var jamb := CAR_HALF.x - DOOR_HALF
		for side: int in [-1, 1]:
			_box(cab, Vector3(jamb, CAR_HEIGHT, 0.1), Vector3(side * (DOOR_HALF + jamb * 0.5), CAR_HEIGHT * 0.5, z), steel, true)
		_box(cab, Vector3(DOOR_HALF * 2.0, CAR_HEIGHT - DOOR_HEIGHT, 0.1), Vector3(0, (CAR_HEIGHT + DOOR_HEIGHT) * 0.5, z), steel, true)
		var leaves: Array = []
		for side: int in [-1, 1]:
			leaves.append(_leaf(cab, Vector3(side * DOOR_HALF * 0.5, DOOR_HEIGHT * 0.5, face * (CAR_HALF.y - 0.02)), Color("5a5048")))
		_cab_doors[face] = leaves
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("d2ecc0")
	lamp.light_energy = 1.2
	lamp.omni_range = 3.2
	lamp.position = Vector3(0, CAR_HEIGHT - 0.3, 0)
	cab.add_child(lamp)
	indicator = _label(cab, Vector3(0, DOOR_HEIGHT + 0.2, -CAR_HALF.y + 0.1), 0.0)
	var back := _label(cab, Vector3(0, DOOR_HEIGHT + 0.2, CAR_HALF.y - 0.1), PI)
	back.name = "IndicatorBack"
	indicator.text = str(stop_names[stop])
	indicator.set_meta("twin", back)
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "Hum"
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = HUM_RATE
	generator.buffer_length = 0.25
	_hum.stream = generator
	_hum.unit_size = 4.0
	_hum.position = Vector3(0, -0.4, 0)
	cab.add_child(_hum)


func _build_landing(index: int) -> void:
	var face := int(faces[index])
	var y := float(stops[index])
	var leaves: Array = []
	for side: int in [-1, 1]:
		leaves.append(_leaf(self, Vector3(side * DOOR_HALF * 0.5, y + DOOR_HEIGHT * 0.5, face * (SHAFT_HALF.y + 0.32)), Color("4a3d33")))
	_landing_doors.append(leaves)
	var label := _label(self, Vector3(0, y + DOOR_HEIGHT + 0.35, face * (SHAFT_HALF.y + 0.33)), 0.0 if face > 0 else PI)
	label.text = str(stop_names[stop])
	landing_labels.append(label)


func _feed_hum() -> void:
	if _hum == null or not _hum.is_inside_tree():
		return
	if state == "moving" and not _hum.playing:
		_hum.play()
	elif state != "moving" and _hum.playing:
		_hum.stop()
	if not _hum.playing:
		return
	var playback := _hum.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	for frame in playback.get_frames_available():
		_hum_phase = fmod(_hum_phase + 1.0 / HUM_RATE, 1000.0)
		# Mains hum and its harmonic under a slow cable shudder.
		var sample := 0.16 * sin(TAU * 55.0 * _hum_phase) + 0.07 * sin(TAU * 110.0 * _hum_phase) + 0.03 * sin(TAU * 3.1 * _hum_phase) * sin(TAU * 220.0 * _hum_phase)
		playback.push_frame(Vector2(sample, sample))


func _process(_delta: float) -> void:
	if indicator != null and indicator.has_meta("twin"):
		(indicator.get_meta("twin") as Label3D).text = indicator.text


func _leaf(parent: Node3D, at: Vector3, color: Color) -> AnimatableBody3D:
	var leaf := AnimatableBody3D.new()
	leaf.sync_to_physics = false
	leaf.position = at
	leaf.set_meta("home_x", at.x)
	parent.add_child(leaf)
	_shape(leaf, Vector3(DOOR_HALF, DOOR_HEIGHT, 0.06), Vector3.ZERO, color)
	return leaf


func _label(parent: Node3D, at: Vector3, turn: float) -> Label3D:
	var label := Label3D.new()
	label.font_size = 48
	label.pixel_size = 0.004
	label.modulate = Color("ff5a2a")
	label.outline_size = 0
	label.position = at
	label.rotation.y = turn
	parent.add_child(label)
	return label


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, onto_body := false) -> void:
	if onto_body:
		_shape(parent, size, at, color)
		return
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	_shape(body, size, Vector3.ZERO, color)


func _shape(body: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	mesh.position = at
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = at
	body.add_child(collider)
