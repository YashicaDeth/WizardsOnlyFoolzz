class_name Footprints
extends RefCounted

## Bloody footprints: the trail walking out of the stain.
##
## Pools grow where blood lands, but nobody walks through them on screen —
## feet cross gore and leave nothing, so the floor reads as painted rather
## than present. This closes that loop at the footfall the gait already
## reports: `HunterBodyMotion.foot_planted` fires with zero subscribers, and
## this is its first.
##
## Wetness lives per walker, not per print. Standing in a pool soaks the foot;
## every print spends part of it, so one soaking walks out as a trail of about
## ten fading marks and then nothing — which is exactly how far blood goes.
## Dry floor neither soaks nor prints, so the system is silent everywhere
## except where the fighting was.

## Pool volume that soaks a foot fully. Two drops underfoot is a stain worth
## tracking; less than that only wets in proportion.
const SOAK_VOLUME := 2.0
## Each print spends this fraction of what is left. Ten steps of trail, then dry.
const PRINT_COST := 0.7
## Below this nothing prints. Without it a soaked foot would mark the map.
const MIN_WET := 0.15
## A print is a small ragged disc, boot-sized rather than body-sized.
const PRINT_SIZE := 0.075
## Prints sit with the spatter, under the pools that made them.
const LIFT := 0.015
## However long the night, prints stay bounded. Oldest goes first.
const MAX_PRINTS := 120

static var _wet: Dictionary = {}
static var _prints: Dictionary = {}


## One footfall. Returns true when it left a mark. `walker` is only ever an
## identity — the wetness rides with whoever stepped, player or otherwise.
static func step(root: Node, walker: Object, at: Vector3, side: String) -> bool:
	if root == null or not root.is_inside_tree() or walker == null:
		return false
	var id := walker.get_instance_id()
	var soak := clampf(BloodPool.volume_at(root, at) / SOAK_VOLUME, 0.0, 1.0)
	var wet := maxf(float(_wet.get(id, 0.0)), soak)
	if wet < MIN_WET:
		_wet[id] = wet * 0.9
		return false
	var size := PRINT_SIZE * (0.5 + 0.5 * wet)
	var node := MeshInstance3D.new()
	node.name = "BloodPrint"
	node.set_meta("print", true)
	node.mesh = BloodPool.build_pool_mesh(size, _print_count(root) * 2 + (0 if side == "left" else 1))
	node.material_override = print_material(wet)
	node.position = Vector3(at.x, at.y + LIFT, at.z)
	node.rotation.y = randf() * TAU + (0.2 if side == "left" else -0.2)
	root.add_child(node)
	var prints: Array = _prints.get(_scene_key(root), [])
	prints.append(node)
	while prints.size() > MAX_PRINTS:
		var oldest: Node = prints.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_prints[_scene_key(root)] = prints
	_wet[id] = wet * PRINT_COST
	return true


static func wetness(walker: Object) -> float:
	if walker == null:
		return 0.0
	return float(_wet.get(walker.get_instance_id(), 0.0))


static func print_count(root: Node) -> int:
	return _print_count(root)


static func _print_count(root: Node) -> int:
	if root == null:
		return 0
	return (_prints.get(_scene_key(root), []) as Array).size()


static func print_material(wet: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# A fading print thins toward the floor rather than graying out: less
	# blood, same blood colour, which is what a drying sole actually leaves.
	material.albedo_color = Color(0.42, 0.038, 0.03).darkened((1.0 - clampf(wet, 0.0, 1.0)) * 0.35)
	material.roughness = 0.9
	return material


static func _scene_key(root: Node) -> String:
	var path := str(root.scene_file_path)
	return path if not path.is_empty() else str(root.name)


static func clear() -> void:
	for key in _prints:
		for node in _prints[key]:
			if is_instance_valid(node):
				(node as Node).queue_free()
	_prints.clear()
	_wet.clear()
