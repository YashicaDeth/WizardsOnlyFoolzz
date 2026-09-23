class_name LockRing
extends MeshInstance3D

## Live-wire rings on the ground under whoever the player is locked on to.
## `follow(position)` while locked, `release()` when not; it fades either way
## rather than popping, and sits a hair above the ground so it never z-fights.

const SIZE := 2.6
const FADE_RATE := 5.0

var strength := 0.0
var _target_strength := 0.0


func _ready() -> void:
	top_level = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/lock_ring.gdshader")
	material_override = mat
	visible = false


func follow(ground_point: Vector3) -> void:
	global_position = ground_point + Vector3.UP * 0.03
	_target_strength = 1.0


func release() -> void:
	_target_strength = 0.0


func _process(delta: float) -> void:
	strength = move_toward(strength, _target_strength, delta * FADE_RATE)
	visible = strength > 0.001
	if visible:
		(material_override as ShaderMaterial).set_shader_parameter("strength", strength)
