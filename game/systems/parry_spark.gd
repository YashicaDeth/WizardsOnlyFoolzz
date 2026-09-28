class_name ParrySpark
extends MeshInstance3D

## A parry is steel meeting steel, and it has to read as that at a glance: a
## white-hot star with a ring punched out of it where the blades bind, a fan of
## sparks thrown along the line the attacking blade was travelling, the
## fighters lit for an instant, and the steel ringing. Who takes what (the
## footing, the riposte) is decided elsewhere; this only shows it.
##
## Before this, a parry was one 0.1 s light and seven small balls built as new
## nodes each time, and nothing you could hear. One ImmediateMesh redrawn per
## frame, one pooled light and one voice, capped: nothing is created per parry.

const LIFE := 0.42
const FLASH_LIFE := 0.13
const RING_LIFE := 0.2
const SPARKS := 26
const MAX_SPARKS := 120
const HOT := Color(1.0, 0.86, 0.56)
const EMBER := Color(1.0, 0.36, 0.06)
## Sizes are fractions of the distance to the camera, so the bind reads the
## same on screen from the eye (0.6 m) as from over the shoulder (3 m): a
## flat size big enough behind you filled a third of the first-person view.
const STAR := 0.07
const RING := 0.16
const STREAK := 0.0035
const LIGHT_ENERGY := 9.0
const LIGHT_FADE := 0.14
const RATE := 22050
## A struck blade: inharmonic partials (Hz, level, decay a second), the high
## ones dying first.
const PARTIALS := [[1180.0, 1.0, 7.0], [1187.0, 0.5, 7.5], [2870.0, 0.6, 11.0], [4410.0, 0.45, 16.0], [6030.0, 0.3, 24.0]]

static var _clang: AudioStreamWAV

var bursts := 0
var _sparks: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()
var _light: OmniLight3D
var _voice: AudioStreamPlayer3D


func _ready() -> void:
	name = "ParrySpark"
	mesh = _mesh
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The bind is at the blades, which the arm and the attacker's body can
	# stand in front of; a contact the fighters hide is no contact.
	mat.no_depth_test = true
	material_override = mat
	_light = OmniLight3D.new()
	_light.light_color = Color("ffd89a")
	_light.omni_range = 4.0
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Clang"
	_voice.stream = clang()
	_voice.max_distance = 30.0
	_voice.unit_size = 4.0
	add_child(_voice)
	AudioBus.route(_voice, "Bodies")


## `at` is where the blades meet; `along` is the way the attacking blade was
## travelling, which is the way the sparks go.
func burst(at: Vector3, along: Vector3, severity := 1.0) -> void:
	var s := clampf(severity, 0.3, 1.5)
	var dir := along.normalized() if along.length_squared() > 0.0001 else Vector3.UP
	bursts += 1
	_flashes.append({"at": at, "age": 0.0, "size": 0.7 + 0.3 * s})
	for i in int(SPARKS * s):
		if _sparks.size() >= MAX_SPARKS:
			_sparks.pop_front()
		# Mostly along the slide, some thrown wide and up off the edges.
		var spray := (dir * 1.6 + Vector3(randf_range(-1, 1), randf_range(-0.3, 1.2), randf_range(-1, 1))).normalized()
		_sparks.append({"at": at, "vel": spray * randf_range(1.0, 6.5), "age": 0.0, "life": LIFE * randf_range(0.5, 1.4)})
	_light.global_position = at
	_light.light_energy = LIGHT_ENERGY * s
	_light.visible = true
	_voice.global_position = at
	_voice.pitch_scale = randf_range(0.93, 1.07)
	_voice.play()


func live_count() -> int:
	return _sparks.size() + _flashes.size()


func light_energy() -> float:
	return _light.light_energy if _light.visible else 0.0


func _process(delta: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var sp := _sparks[i]
		sp.age = float(sp.age) + delta
		if float(sp.age) >= float(sp.life):
			_sparks.remove_at(i)
			continue
		sp.vel = (sp.vel as Vector3) * (1.0 - 1.5 * delta) + Vector3.DOWN * 9.8 * delta
		sp.at = (sp.at as Vector3) + (sp.vel as Vector3) * delta
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i].age = float(_flashes[i].age) + delta
		if float(_flashes[i].age) >= RING_LIFE:
			_flashes.remove_at(i)
	if _light.visible:
		_light.light_energy = move_toward(_light.light_energy, 0.0, LIGHT_ENERGY * delta / LIGHT_FADE)
		_light.visible = _light.light_energy > 0.01
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _sparks.is_empty() and _flashes.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var view := cam.global_transform.basis.z if cam != null else Vector3.BACK
	var eye := cam.global_position if cam != null else Vector3.ZERO
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for sp in _sparks:
		var t := float(sp.age) / float(sp.life)
		var head: Vector3 = sp.at
		var tail := head - (sp.vel as Vector3) * 0.016
		var side := (head - tail).cross(view).normalized() * STREAK * maxf(0.3, head.distance_to(eye))
		# White-hot for a moment, then an ember cooling as it falls.
		var c := HOT.lerp(EMBER, minf(1.0, t * 2.0))
		c.a = 1.0 - t * t
		_quad(tail - side, tail + side, head - side, head + side, c)
	for flash in _flashes:
		var age := float(flash.age)
		var right := view.cross(Vector3.UP).normalized()
		var up := right.cross(view).normalized()
		var at: Vector3 = flash.at
		var near := maxf(0.3, at.distance_to(eye))
		var size := float(flash.size) * STAR * near
		if age < FLASH_LIFE:
			# The star: long flat points either side (the line the blades
			# lie along), short ones up and down.
			var t := age / FLASH_LIFE
			var c := Color(HOT, 1.0 - t)
			# A hot filled core, so it reads as a flash and not as a reticle.
			for k in 10:
				var a0 := TAU * float(k) / 10.0
				var a1 := TAU * float(k + 1) / 10.0
				_tri(at + (right * cos(a0) + up * sin(a0)) * size * 0.4, at + (right * cos(a1) + up * sin(a1)) * size * 0.4, at, c)
			for k in 8:
				var ang := TAU * float(k) / 8.0
				var reach := size * (1.6 if k % 4 == 0 else (0.7 if k % 2 == 0 else 0.35)) * (1.0 + t * 0.5)
				var point := (right * cos(ang) + up * sin(ang)) * reach
				var perp := (right * -sin(ang) + up * cos(ang)) * size * 0.1
				_tri(at - perp, at + perp, at + point, c)
		# The ring: the clang, seen, thrown out and gone.
		var r := lerpf(0.1, 1.0, age / RING_LIFE) * RING * near
		var ring := Color(EMBER, 0.35 * (1.0 - age / RING_LIFE))
		for k in 24:
			var a0 := TAU * float(k) / 24.0
			var a1 := TAU * float(k + 1) / 24.0
			var in0 := (right * cos(a0) + up * sin(a0)) * r
			var in1 := (right * cos(a1) + up * sin(a1)) * r
			# A soft warm band rather than a hairline: a hairline circle is UI.
			_quad(at + in0 * 0.7, at + in0, at + in1 * 0.7, at + in1, ring)
	_mesh.surface_end()


## The steel ringing, synthesized once: a hard bright strike, then the blade's
## own partials.
static func clang() -> AudioStreamWAV:
	if _clang != null:
		return _clang
	var duration := 0.9
	var frames := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var seed_value := 7654321
	for frame in frames:
		var t := float(frame) / RATE
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed_value) / float(0x7fffffff) * 2.0 - 1.0
		var sample := noise * exp(-t * 90.0) * 0.35
		for partial in PARTIALS:
			sample += sin(TAU * float(partial[0]) * t) * float(partial[1]) * exp(-t * float(partial[2])) * 0.24
		bytes.encode_s16(frame * 2, clampi(roundi(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767))
	_clang = AudioStreamWAV.new()
	_clang.format = AudioStreamWAV.FORMAT_16_BITS
	_clang.mix_rate = RATE
	_clang.data = bytes
	return _clang


func _tri(a: Vector3, b: Vector3, tip: Vector3, c: Color) -> void:
	for v in [a, b, tip]:
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(v)


func _quad(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, c: Color) -> void:
	for v in [a0, a1, b1, a0, b1, b0]:
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(v)
