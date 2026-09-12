class_name CarrionScavenger
extends Node3D

## B4.10v2. Rot is a summons, not a particle effect. This modest world actor
## follows the same identified chunks used by extraction: it eats rotten wet
## matter, but leaves bone and cybernetics for the player and the economy.

signal fed(chunk: Dictionary)

@export var travel_speed := 2.4
@export var feed_distance := 0.38
var target: Node3D


static func can_eat(chunk: Node) -> bool:
	var info := GoreChunks.identify(chunk)
	if info.is_empty() or bool(info.get("taken", false)):
		return false
	if bool(info.get("whole_limb", false)):
		return true
	return int(info.get("layer", GoreChunks.Layer.CYBERNETIC)) in [GoreChunks.Layer.SKIN, GoreChunks.Layer.FAT, GoreChunks.Layer.MUSCLE, GoreChunks.Layer.ORGAN]


func _process(delta: float) -> void:
	# Same ordering rule as `scent_sources`: validity first, because
	# `rot_ratio` takes a typed Node and a freed one fails at the call.
	if target == null or not is_instance_valid(target):
		target = _best_scent()
	elif not can_eat(target) or GoreChunks.rot_ratio(target) < 0.5:
		target = _best_scent()
	if target == null:
		return
	global_position = global_position.move_toward(target.global_position, travel_speed * delta)
	if global_position.distance_to(target.global_position) <= feed_distance:
		var eaten := GoreChunks.take(target)
		target = null
		if not eaten.is_empty():
			fed.emit(eaten)


func _best_scent() -> Node3D:
	var nearest: Node3D
	var best_distance := INF
	for chunk in GoreChunks.live:
		if not is_instance_valid(chunk):
			continue
		if not can_eat(chunk) or GoreChunks.rot_ratio(chunk) < 0.5:
			continue
		var candidate := chunk as Node3D
		if candidate == null or not is_instance_valid(candidate) or not candidate.is_inside_tree():
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest
