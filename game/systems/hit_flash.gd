class_name HitFlash
extends MeshInstance3D

## The instant a blow lands: a white-hot core and a spray of sparks thrown on
## through the body along the strike, gone in about a sixth of a second. It
## marks contact, the one moment an action game has to read at a glance, and
## scales with how hard the blow was. One ImmediateMesh redrawn per frame; no
## nodes are created per hit.

const LIFE := 0.16
const SPARKS := 14
const HOT := Color(1.0, 0.92, 0.7)
const EMBER := Color(1.0, 0.45, 0.12)

var _sparks: Array[Dictionary] = []
var _cores: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()


func _ready() -> void:
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
	# Contact happens inside the body's surface; a hit marker that the body
	# hides is no marker. Drawn over the world, as hit sparks usually are.
	mat.no_depth_test = true
	material_override = mat


## `through` is the strike direction; sparks carry on along it.
func burst(at: Vector3, through: Vector3, severity := 0.6) -> void:
	var s := clampf(severity, 0.15, 1.5)
	var dir := through.normalized() if through.length_squared() > 0.0001 else Vector3.FORWARD
	_cores.append({"at": at, "age": 0.0, "size": 0.18 + 0.22 * s})
	for i in int(SPARKS * (0.5 + s * 0.5)):
		var spray := (dir * 1.2 + Vector3(randf_range(-1, 1), randf_range(-0.4, 1.0), randf_range(-1, 1))).normalized()
		_sparks.append({"at": at, "vel": spray * randf_range(3.0, 7.5) * (0.6 + s * 0.4), "age": 0.0, "life": LIFE * randf_range(0.7, 1.3)})


func live_count() -> int:
	return _sparks.size() + _cores.size()


func _process(delta: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var sp := _sparks[i]
		sp.age = float(sp.age) + delta
		if float(sp.age) >= float(sp.life):
			_sparks.remove_at(i)
			continue
		sp.vel = (sp.vel as Vector3) + Vector3.DOWN * 9.0 * delta
		sp.at = (sp.at as Vector3) + (sp.vel as Vector3) * delta
	for i in range(_cores.size() - 1, -1, -1):
		_cores[i].age = float(_cores[i].age) + delta
		if float(_cores[i].age) >= LIFE * 0.6:
			_cores.remove_at(i)
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _sparks.is_empty() and _cores.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var view := cam.global_transform.basis.z if cam != null else Vector3.BACK
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for sp in _sparks:
		var t := float(sp.age) / float(sp.life)
		var head: Vector3 = sp.at
		var tail := head - (sp.vel as Vector3) * 0.025
		var side := (head - tail).cross(view).normalized() * 0.012
		var c := HOT.lerp(EMBER, t)
		c.a = 1.0 - t
		_quad(tail - side, tail + side, head - side, head + side, c)
	for core in _cores:
		var t := float(core.age) / (LIFE * 0.6)
		var size := float(core.size) * (1.0 + t * 0.8)
		var right := view.cross(Vector3.UP).normalized() * size
		var up := right.cross(view).normalized() * size
		var at: Vector3 = core.at
		var c := Color(HOT, (1.0 - t) * 0.9)
		# A four-point star of tapered spikes, not a disc: reads as a strike,
		# not a light. Long vertical/horizontal points, short diagonals.
		for k in 8:
			var ang := TAU * float(k) / 8.0 + 0.3
			var reach := 1.0 if k % 2 == 0 else 0.45
			var point := (right * cos(ang) + up * sin(ang)) * reach
			var perp := (right * -sin(ang) + up * cos(ang)).normalized() * size * 0.12
			_tri(at - perp, at + perp, at + point, c)
	_mesh.surface_end()


func _tri(a: Vector3, b: Vector3, tip: Vector3, c: Color) -> void:
	for v in [a, b, tip]:
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(v)


func _quad(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, c: Color) -> void:
	for v in [a0, a1, b1, a0, b1, b0]:
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(v)
