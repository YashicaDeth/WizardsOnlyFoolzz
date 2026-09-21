class_name BloodPool
extends RefCounted

## Blood pooling: what per-drop splats never become.
##
## `BaselineHuman` lands every drop as its own flat splat and caps the floor at
## `splat_budget()`. That is correct for spatter — a drop that lands throws its
## satellites and stops — but a body bleeding out onto one spot leaves a mark
## that *grows*, and two bleeds that meet become one stain rather than two
## overlapping decals. Nothing in the gore stack did either, which was the open
## item: "no pooling that grows and merges".
##
## This is that system, beside the splat path rather than inside it, so spatter
## keeps reading as spatter and accumulation reads as accumulation. Volumes are
## counted in drops: one landed drop is 1.0, a chunk landing feeds its own size
## in the same unit, and the radius follows the area — doubling the blood never
## doubles the width, which is what keeps a long bleed a stain and not a lake.
##
## Deliberately no fluid simulation. `blood_flow.gd` already argues this at the
## scale that matters blood is drops and streaks, not volumes; a pool is where
## those drops ended up, grown the way a spill grows, with drying on top.

## One landed drop. Chunk landings feed a multiple of this from their own size.
const DROP_VOLUME := 1.0
## Square metres of floor per unit of volume. Ninety drops — a minute of a real
## wound at ~1.5 drips a second — cover ~0.36m², a stain about 0.34m across.
## Measured against `BloodFlow.DROPS_PER_BLEED` rather than guessed, for the
## same reason that constant carries its calibration in its comment.
const AREA_PER_VOLUME := 0.004
## However much blood arrives, no single pool outgrows this. A stain you could
## lie down in stops being evidence and starts being a second floor.
const MAX_RADIUS := 0.9
## Two wet edges this close are one stain. Without it every feed near a pool
## starts a satellite instead of joining, and the floor fills with coins.
const MERGE_GAP := 0.05
## Pools sit one lift above splats (`mark_ground_for_chunk` beds at 0.014), so
## accumulation visibly covers spatter instead of z-fighting with it.
const LIFT := 0.016

const FRESH := Color(0.42, 0.038, 0.03)
const DRIED := Color(0.14, 0.028, 0.025)


## Pools are few and large where splats are many and small, so the budget is an
## order of magnitude under `splat_budget()` at every quality.
static func pool_budget() -> int:
	match WorldLook.quality:
		WorldLook.Quality.ULTRA: return 48
		WorldLook.Quality.HIGH: return 32
		_: return 16


## The radius a volume covers. Square-root growth, so early blood spreads fast
## and late blood mostly deepens — the shape of every real spill.
static func radius_for(volume: float) -> float:
	return minf(sqrt(maxf(volume, 0.0) * AREA_PER_VOLUME / PI), MAX_RADIUS)


## Feed blood into a pool set. Nearby feeds join the pool they touch; distant
## ones start their own. Over budget, the feed is absorbed by its nearest pool
## rather than deleted — a cap that erases evidence is a cap that lies about
## where the fighting was. Returns the pool index.
static func feed(pools: Array, at: Vector3, volume: float) -> int:
	if volume <= 0.0:
		return -1
	var incoming := radius_for(volume)
	var best := -1
	var best_gap := INF
	for index in pools.size():
		var pool: Dictionary = pools[index]
		var flat := Vector2(at.x, at.z) - Vector2(pool.pos.x, pool.pos.z)
		var gap := flat.length() - float(pool.radius) - incoming
		if gap < best_gap:
			best_gap = gap
			best = index
	if best >= 0 and best_gap <= MERGE_GAP:
		var pool: Dictionary = pools[best]
		var total := float(pool.volume) + volume
		# The stain's middle moves toward the new blood in proportion, so a
		# body dragged across its own pool leaves the deep end where it died.
		pool.pos = (pool.pos * float(pool.volume) + at * volume) / total
		pool.volume = total
		pool.radius = radius_for(total)
		return best
	if pools.size() >= pool_budget():
		# Full: the nearest pool takes it wherever it is. Wrong shape, right
		# floor — and the alternative is blood vanishing at the cap.
		if best >= 0:
			var pool: Dictionary = pools[best]
			var total := float(pool.volume) + volume
			pool.pos = (pool.pos * float(pool.volume) + at * volume) / total
			pool.volume = total
			pool.radius = radius_for(total)
			return best
		return -1
	pools.append({"pos": at, "volume": volume, "radius": incoming, "age": 0.0})
	return pools.size() - 1


## Old blood is matte and dark, fresh blood wet and bright — the same drying
## the streaks already speak in `BloodFlow.streak_material()`, so a pool beside
## a body reads as the same event at a later hour.
static func pool_material(age01: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Greg: "realistic and fun but abstract arty" — the arty half is a lighting
	# decision, not a shape one. Drawn flat like the splats, a mark rather
	# than an object competing with the floor on the floor's terms.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = FRESH.lerp(DRIED, clampf(age01, 0.0, 1.0))
	material.roughness = lerpf(0.18, 0.92, clampf(age01, 0.0, 1.0))
	return material


## A ragged disc on the floor plane: a fan with jittered radii and a couple of
## thrown fingers, the same silhouette language as the splats so the two read
## as one system at different hours rather than two effects.
static func build_pool_mesh(radius: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var steps := 17
	var rim: Array[float] = []
	for step in steps:
		var jitter := rng.randf_range(0.72, 1.0)
		if step % 5 == 0:
			jitter *= rng.randf_range(1.2, 1.7)
		rim.append(jitter)
	var center := Vector3.ZERO
	var center_tint := Color(1, 1, 1, 1)
	for step in steps:
		var a0 := TAU * float(step) / float(steps)
		var a1 := TAU * float(step + 1) / float(steps)
		var p0 := Vector3(cos(a0) * rim[step], 0, sin(a0) * rim[step]) * radius
		var p1 := Vector3(cos(a1) * rim[(step + 1) % steps], 0, sin(a1) * rim[(step + 1) % steps]) * radius
		points.append_array([center, p0, p1])
		# Darker in the middle where it is deepest, paler at the rim where it
		# thins — the only depth cue a flat mark gets, and it is enough.
		colors.append_array([center_tint.darkened(0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 1)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func build_pool_node(pool: Dictionary, seed_value: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "BloodPool"
	node.mesh = build_pool_mesh(float(pool.radius), seed_value)
	node.material_override = pool_material(float(pool.get("age", 0.0)))
	var at: Vector3 = pool.pos
	node.position = Vector3(at.x, at.y + LIFT, at.z)
	return node


## --- live registry ----------------------------------------------------------
##
## `GoreChunks` is static and outlives its scene (see its AG1.6 comment), so
## pool sets are keyed by scene exactly like `blood_records` rather than held
## in one array the next scene inherits. `clear()` is for suite setup and scene
## swaps, and every walker here prunes freed nodes first for the same reason
## `GoreChunks.prune()` exists.

static var _pool_sets: Dictionary = {}
static var _pool_nodes: Dictionary = {}


static func _scene_key(root: Node) -> String:
	var path := str(root.scene_file_path)
	return path if not path.is_empty() else str(root.name)


## Feed the live set for a scene and pin a node to it. The mesh is rebuilt when
## the radius moves because pools are few and feeds are sparse — the churn
## argument that made streaks reuse their node does not apply at 48 objects.
static func keep(root: Node, at: Vector3, volume: float) -> int:
	if root == null or not root.is_inside_tree() or volume <= 0.0:
		return -1
	var key := _scene_key(root)
	var pools: Array = _pool_sets.get(key, [])
	var index := feed(pools, at, volume)
	if index < 0:
		return -1
	_pool_sets[key] = pools
	var nodes: Array = _pool_nodes.get(key, [])
	while nodes.size() <= index:
		nodes.append(null)
	var node := nodes[index] as MeshInstance3D
	if node == null or not is_instance_valid(node):
		node = build_pool_node(pools[index], index + 1)
		root.add_child(node)
		nodes[index] = node
	else:
		var pool: Dictionary = pools[index]
		node.mesh = build_pool_mesh(float(pool.radius), index + 1)
		node.position = Vector3(pool.pos.x, pool.pos.y + LIFT, pool.pos.z)
	_pool_nodes[key] = nodes
	return index


static func pool_count(root: Node) -> int:
	if root == null:
		return 0
	return (_pool_sets.get(_scene_key(root), []) as Array).size()


static func clear() -> void:
	for key in _pool_nodes:
		for node in _pool_nodes[key]:
			if is_instance_valid(node):
				(node as Node).queue_free()
	_pool_sets.clear()
	_pool_nodes.clear()
