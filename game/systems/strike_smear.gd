class_name StrikeSmear
extends Node3D

## Afterimages of the weapon on a committed swing: the blade leaves a few
## fading copies of itself along its path, more and brighter the harder the
## blow is thrown. Pooled — never more than `MAX_GHOSTS` copies of a weapon
## exist — and it only reads the weapon's transform, so it can follow a sword,
## a bat or a severed arm without knowing which.

const MAX_GHOSTS := 5
const LIFE := 0.12
const SPAWN_EVERY := 0.022
const MIN_SPEED := 4.0
const MIN_COMMIT := 0.25

var _ghosts: Array[Dictionary] = []
var _since := 0.0
var _last_tip := Vector3.ZERO
var _has_last := false
var _source_id := 0
var _material := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.albedo_color = Color(1.0, 0.55, 0.3, 0.5)
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Afterimages right at the lens washed the whole frame out (caught
	# in-scene); they fade out inside ~2 m of the camera.
	_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	_material.distance_fade_min_distance = 0.9
	_material.distance_fade_max_distance = 2.2


## One frame of the held weapon. `tip` is its far end in world space.
func feed(model: Node3D, tip: Vector3, delta: float, commitment: float) -> void:
	_age(delta)
	if model == null or not is_instance_valid(model) or not model.is_visible_in_tree():
		_has_last = false
		return
	if model.get_instance_id() != _source_id:
		_clear()
		_source_id = model.get_instance_id()
	var speed := (tip - _last_tip).length() / maxf(delta, 1e-4) if _has_last else 0.0
	_last_tip = tip
	_has_last = true
	_since += delta
	if speed < MIN_SPEED or commitment < MIN_COMMIT or _since < SPAWN_EVERY:
		return
	_since = 0.0
	_spawn(model, clampf(commitment, 0.0, 1.0))


func live_count() -> int:
	return _ghosts.size()


func _spawn(model: Node3D, strength: float) -> void:
	var ghost: Dictionary
	if _ghosts.size() >= MAX_GHOSTS:
		ghost = _ghosts.pop_front()
	else:
		ghost = {"root": Node3D.new(), "age": 0.0, "strength": 0.0}
		(ghost.root as Node3D).top_level = true
		add_child(ghost.root)
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var source := child as MeshInstance3D
			if source.mesh == null:
				continue
			var copy := MeshInstance3D.new()
			copy.mesh = source.mesh
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.material_override = _material.duplicate()
			copy.set_meta("offset", model.global_transform.affine_inverse() * source.global_transform)
			(ghost.root as Node3D).add_child(copy)
	var root := ghost.root as Node3D
	root.global_transform = model.global_transform
	for copy in root.get_children():
		(copy as MeshInstance3D).transform = copy.get_meta("offset")
	root.visible = true
	ghost.age = 0.0
	ghost.strength = strength
	_ghosts.append(ghost)


func _age(delta: float) -> void:
	for i in range(_ghosts.size() - 1, -1, -1):
		var ghost := _ghosts[i]
		ghost.age = float(ghost.age) + delta
		var fade := 1.0 - float(ghost.age) / LIFE
		var root := ghost.root as Node3D
		if fade <= 0.0:
			root.queue_free()
			_ghosts.remove_at(i)
			continue
		for copy in root.get_children():
			var mat := (copy as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color.a = fade * (0.18 + 0.4 * float(ghost.strength))


func _clear() -> void:
	for ghost in _ghosts:
		(ghost.root as Node3D).queue_free()
	_ghosts.clear()
	_has_last = false
