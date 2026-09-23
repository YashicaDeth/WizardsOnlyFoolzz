class_name StrikeTrail
extends MeshInstance3D

## What a swing leaves in the air. Two ribbons from the held weapon's real
## sweep: a hot arc between grip and tip that burns yellow as the blow is
## committed, and a thin red cable trailing off the tip that lags and whips
## after it. Nothing is drawn while the weapon is still, so it reads only
## motion the player actually made. Fed every frame by whoever holds the weapon;
## it keeps no opinion about combat.

const LIFE := 0.24
const CABLE_LIFE := 0.42
const MIN_SPEED := 2.2
const HOT := Color(1.0, 0.82, 0.32)
const EMBER := Color(0.95, 0.35, 0.08)
const CABLE := Color(1.0, 0.1, 0.12)

var _samples: Array[Dictionary] = []
var _tips: Dictionary = {}
var _clock := 0.0
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
	mat.no_depth_test = false
	# Same as the smear: a trail at the lens is a smear across the screen.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.9
	mat.distance_fade_max_distance = 2.2
	material_override = mat


## The far end of a weapon, in its own space: the point of its mesh bounds
## farthest from the grip (the model origin). Measured once per model.
func tip_local(model: Node3D) -> Vector3:
	var key := model.get_instance_id()
	if _tips.has(key):
		return _tips[key]
	var best := Vector3(0, 0, -0.6)
	var best_len := 0.0
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var to_model := model.global_transform.affine_inverse() * mi.global_transform
		var box := mi.mesh.get_aabb()
		for i in 8:
			var p := to_model * box.get_endpoint(i)
			if p.length() > best_len:
				best_len = p.length()
				best = p
	_tips[key] = best
	return best


## One frame of the held weapon. `commitment` 0..1 is how thrown the blow is.
func feed_weapon(model: Node3D, delta: float, commitment := 0.0) -> void:
	if model == null or not is_instance_valid(model) or not model.is_visible_in_tree():
		feed(Vector3.ZERO, Vector3.ZERO, delta, 0.0, false)
		return
	var base := model.global_transform.origin
	var tip := model.global_transform * tip_local(model)
	feed(base, tip, delta, commitment, true)


func feed(base: Vector3, tip: Vector3, delta: float, commitment: float, present := true) -> void:
	_clock += delta
	if present:
		var speed := 0.0
		if not _samples.is_empty():
			speed = (tip - (_samples[-1].tip as Vector3)).length() / maxf(delta, 1e-4)
		_samples.append({"base": base, "tip": tip, "t": _clock, "hot": commitment, "moving": speed > MIN_SPEED})
	while not _samples.is_empty() and _clock - float(_samples[0].t) > CABLE_LIFE:
		_samples.pop_front()
	_rebuild()


func active() -> bool:
	for s in _samples:
		if bool(s.moving):
			return true
	return false


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _samples.size() < 2 or not active():
		return
	# The arc: grip-to-tip quads between consecutive moving samples.
	var drew := false
	for i in range(1, _samples.size()):
		var a: Dictionary = _samples[i - 1]
		var b: Dictionary = _samples[i]
		var age := _clock - float(b.t)
		if age > LIFE or not bool(b.moving):
			continue
		if not drew:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			drew = true
		var fade_a := 1.0 - clampf((_clock - float(a.t)) / LIFE, 0.0, 1.0)
		var fade_b := 1.0 - age / LIFE
		var hot := clampf(float(b.hot), 0.0, 1.0)
		var edge := EMBER.lerp(HOT, hot)
		# Inner third (near the hand) is faint; the edge carries the colour.
		var ia: Vector3 = (a.base as Vector3).lerp(a.tip, 0.35)
		var ib: Vector3 = (b.base as Vector3).lerp(b.tip, 0.35)
		_quad(ia, a.tip, ib, b.tip, Color(edge, 0.0), Color(edge, fade_a * (0.35 + hot * 0.5)), Color(edge, 0.0), Color(edge, fade_b * (0.35 + hot * 0.5)))
	if drew:
		_mesh.surface_end()
	# The cable: a thin ribbon trailing the tip, lagging and wobbling, living
	# longer than the arc so the whip cracks after the blade has passed.
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _samples.size()
	for i in range(1, n):
		var a: Dictionary = _samples[i - 1]
		var b: Dictionary = _samples[i]
		var ta := (_clock - float(a.t)) / CABLE_LIFE
		var tb := (_clock - float(b.t)) / CABLE_LIFE
		var pa := _cable_point(a, ta, i - 1)
		var pb := _cable_point(b, tb, i)
		var w := 0.03 * (1.0 - tb * 0.6)
		var side := (pb - pa).cross(Vector3.UP).normalized() * w
		if side.length_squared() < 1e-8:
			side = Vector3.RIGHT * w
		var ca := Color(CABLE, (1.0 - ta) * 0.9)
		var cb := Color(CABLE, (1.0 - tb) * 0.9)
		_quad(pa - side, pa + side, pb - side, pb + side, ca, ca, cb, cb)
	_mesh.surface_end()


func _cable_point(sample: Dictionary, age: float, index: int) -> Vector3:
	var tip: Vector3 = sample.tip
	# Sag and a travelling wobble: older points fall and curl.
	var wobble := Vector3(sin(float(index) * 1.7 + _clock * 18.0), cos(float(index) * 1.3 + _clock * 15.0), 0.0) * 0.04 * age
	return tip + Vector3.DOWN * age * age * 0.35 + wobble


func _quad(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, c_a0: Color, c_a1: Color, c_b0: Color, c_b1: Color) -> void:
	for v in [[a0, c_a0], [a1, c_a1], [b1, c_b1], [a0, c_a0], [b1, c_b1], [b0, c_b0]]:
		_mesh.surface_set_color(v[1])
		_mesh.surface_add_vertex(v[0])
