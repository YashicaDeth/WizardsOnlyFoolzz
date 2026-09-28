class_name DustPuff
extends Node3D

## Ash kicked up by a committed movement — a dodge, a hard landing. A burst of
## soft billboards at the feet, blown back against the direction of travel,
## swelling and thinning out over half a second. Pooled: bursts reuse the same
## few quads, so a fight full of dodges costs the same as one.

const POOL := 18
const PER_BURST := 6
const LIFE := 0.55

var _quads: Array[Dictionary] = []
var _next := 0


func _ready() -> void:
	top_level = true
	var shader := preload("res://shaders/dust_puff.gdshader")
	for i in POOL:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		quad.mesh = mesh
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("seed", float(i) * 3.7)
		quad.material_override = mat
		quad.visible = false
		quad.top_level = true
		add_child(quad)
		_quads.append({"node": quad, "age": LIFE, "velocity": Vector3.ZERO, "size": 0.5})


## `away` is the direction the body is moving; the ash goes the other way.
func burst(feet: Vector3, away: Vector3 = Vector3.ZERO, strength := 1.0) -> void:
	var back := -Vector3(away.x, 0.0, away.z)
	back = back.normalized() if back.length_squared() > 0.0001 else Vector3.ZERO
	for i in PER_BURST:
		var slot: Dictionary = _quads[_next]
		_next = (_next + 1) % POOL
		var spread := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.8, 2.0)
		# Back beats spread on every billow (2.4 > 2.0 * 0.7), so the ash always
		# trails the dodge instead of sometimes leading it.
		slot.velocity = (back * 2.4 + spread * 0.7 + Vector3.UP * randf_range(0.3, 0.9)) * strength
		slot.age = 0.0
		slot.size = randf_range(0.6, 1.0) * strength
		var node := slot.node as MeshInstance3D
		# Lifted clear of the ground so a billboard is never cut flat by it.
		node.global_position = feet + Vector3(0, 0.45, 0) + spread * 0.2
		node.visible = true


func live_count() -> int:
	var n := 0
	for slot in _quads:
		if float(slot.age) < LIFE:
			n += 1
	return n


func _process(delta: float) -> void:
	for slot in _quads:
		if float(slot.age) >= LIFE:
			continue
		slot.age = float(slot.age) + delta
		var node := slot.node as MeshInstance3D
		var t := clampf(float(slot.age) / LIFE, 0.0, 1.0)
		if t >= 1.0:
			node.visible = false
			continue
		slot.velocity = (slot.velocity as Vector3) * (1.0 - delta * 3.5)
		node.global_position += (slot.velocity as Vector3) * delta
		var s := float(slot.size) * (1.0 + t * 1.8)
		node.scale = Vector3(s, s, s)
		(node.material_override as ShaderMaterial).set_shader_parameter("fade", (1.0 - t) * (1.0 - t) * 0.85)
