class_name Blast
extends RefCounted

const WORLD_BREAK := preload("res://systems/world_break.gd")

## One explosion for every breakable that speaks tiers (`VoxelStructure`,
## `DigTerrain`), the older breakables (`WorldBreak`), bodies (wounded, and
## thrown as ragdolls when it kills them) and anything loose (pushed).
## Grenades, demolition charges and later the breach launcher all land here.


## `source` is a `MaterialToughness.SOURCES` key ("explosive", "charge").
## Returns a tally: cells removed, soil cut, bodies hit, things pushed.
static func explode(host: Node3D, at: Vector3, radius: float, damage: float, source := "explosive") -> Dictionary:
	var tally := {"removed": 0, "blocked": 0, "dug": 0, "bodies": 0, "pushed": 0, "props": 0}
	var tree := host.get_tree()
	for node in tree.get_nodes_in_group(VoxelStructure.GROUP):
		var structure := node as VoxelStructure
		if not is_instance_valid(structure) or structure.is_queued_for_deletion():
			continue
		var result := structure.damage_sphere(at, radius, source, damage, Vector3.UP)
		tally.removed += int(result.removed)
		tally.blocked += int(result.blocked)
	for node in tree.get_nodes_in_group(DigTerrain.GROUP):
		tally.dug += (node as DigTerrain).carve_sphere(at, radius * 0.85, source)
	# Bodies, props and loose things inside twice the radius.
	var query := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = radius * 2.0
	query.shape = ball
	query.transform = Transform3D(Basis(), at)
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	var met := host.get_world_3d().direct_space_state.intersect_shape(query, 128)
	var struck_rigs: Dictionary = {}
	var struck_props: Dictionary = {}
	for hit in met:
		var collider: Object = hit.collider
		var rig := _rig_of(collider)
		if rig != null:
			if struck_rigs.has(rig):
				continue
			struck_rigs[rig] = true
			var to := rig.global_position + Vector3(0, 1.0, 0) - at
			var fall := clampf(1.0 - to.length() / (radius * 2.0), 0.1, 1.0)
			rig.hit_at(rig.global_position + Vector3(0, 1.0, 0), damage * fall, damage * fall * 0.6, "blunt", to.normalized())
			tally.bodies += 1
			continue
		if collider is RigidBody3D and not (collider as RigidBody3D).freeze:
			var body := collider as RigidBody3D
			var away := body.global_position - at
			var push := clampf(1.0 - away.length() / (radius * 2.0), 0.0, 1.0) * damage * 0.05
			body.apply_central_impulse((away.normalized() + Vector3.UP * 0.6).normalized() * push * body.mass)
			tally.pushed += 1
			continue
		if collider is Node and not struck_props.has(collider) and not collider is VoxelStructure and not collider is DigTerrain:
			struck_props[collider] = true
			var broke: Dictionary = WORLD_BREAK.hit(collider, damage, "explosion", at, ((collider as Node3D).global_position - at).normalized() if collider is Node3D else Vector3.UP, source, "explosive")
			if not broke.is_empty():
				tally.props += 1
	_flash(host, at, radius)
	return tally


static func _rig_of(collider: Object) -> BaselineHuman:
	var node := collider as Node
	for _depth in 4:
		if node == null:
			return null
		if node is BaselineHuman:
			return node
		node = node.get_parent()
	return null


static func _flash(host: Node3D, at: Vector3, radius: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("ffb36a")
	light.light_energy = 8.0
	light.omni_range = radius * 5.0
	var scene := host.get_tree().current_scene
	(scene if scene != null else host).add_child(light)
	light.global_position = at + Vector3.UP * 0.3
	var fade := light.create_tween()
	fade.tween_property(light, "light_energy", 0.0, 0.35)
	fade.tween_callback(light.queue_free)
	MaterialToughness.play_break(host, at, "concrete")
