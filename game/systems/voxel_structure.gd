class_name VoxelStructure
extends RigidBody3D

## Chunky voxel walls, crates and buildings (Greg, 5 Oct: "chunky VOXEL walls
## and buildings that break into cubes", "as much like Teardown as possible").
##
## A grid of ~15 cm cells, each one material from `MaterialToughness`. A hit
## takes hp off the cells inside a sphere, but only cells whose tier the source
## beats: a pistol holes brick and chips concrete, a bunker shrugs it off. A
## cell at 0 hp leaves as a loose cube. Then connectivity: anything no longer
## joined to an anchor (the floor row, or the rim for a hatch) breaks off as
## its own VoxelStructure, unfrozen, so it falls and can itself be broken.
##
## Standing structures are frozen static bodies with a trimesh; falling pieces
## are dynamic with a convex hull. Loose cubes and pieces are capped and
## recycled through `WorldDebris` to hold the frame.

const GROUP := "voxel_structure"
const CUBE_POOL := "voxel_cube"
const CHUNK_POOL := "voxel_chunk"
## ponytail: fixed budgets; tie to the quality setting (BreakableProp.fragment_budget) once the real map uses this.
const CUBE_BUDGET := 96
const CHUNK_BUDGET := 16
## Cubes spawned per hit; the rest of a blast's removed cells just vanish as dust.
const CUBES_PER_HIT := 14
## A piece this small or smaller falls as loose cubes, not a body of its own.
const LOOSE_CELLS := 2
## Debris faster than this hurts a body it meets (m/s), and how much per kg·m/s.
## Loose cubes' physics layer (BreakableProp's fragments use the same one).
const DEBRIS_LAYER := 1 << 3
const HURT_SPEED := 3.5
const HURT_PER_MOMENTUM := 2.2
## A structure that has lost this share of its cells counts as broken (the
## lab's BROKEN tally, and later the map's "breached").
const BROKEN_SHARE := 0.1
## A blast's shock reaches this far past its radius, at `shock` x its damage:
## weak walls (brick, drywall) blow out wide, hard ones only where it hit.
const SHOCK_REACH := 1.6
## imp-63: a blast blackens surviving cells out to this many times its radius:
## black at the edge of what it blew out, fading to clean. The soot is kept
## per cell and goes with a piece.
const SOOT_REACH := 3.2
const SOOT := Color(0.05, 0.04, 0.035)
## Visual layer of loose pieces, so the floor's scorch decals skip them.
const DEBRIS_VISUAL := 1 << 1
## Meta on a `Ballistics` scar that sits on a voxel wall (names get uniquified).
const SCAR := &"voxel_scar"

const FACES := [
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
]

static var _look: StandardMaterial3D

@export var voxel := 0.15
## "floor": cells on the bottom row hold. "rim": cells on the x/z edges hold
## (a hatch, a roof). "none": a loose piece; its biggest part is the piece.
@export var anchor := "floor"
var size := Vector3i.ONE
## 0 empty, else index + 1 into `palette`.
var cells := PackedByteArray()
var hp := PackedFloat32Array()
## 0 clean, 255 black (imp-63). Sized with `cells` on the first rebuild.
var soot := PackedByteArray()
var palette: Array[String] = []
## Cells when built whole; 0 for a piece that broke off.
var start_cells := 0
var _mesh: MeshInstance3D
var _shape: CollisionShape3D


## A solid block of `material`, `metres` across, its centre at `centre`
## (parent space). The grid's origin is its minimum corner.
static func make(parent: Node, material: String, metres: Vector3, centre: Vector3, anchor_mode := "floor", cell := 0.15) -> VoxelStructure:
	var structure := VoxelStructure.new()
	structure.voxel = cell
	structure.anchor = anchor_mode
	structure.fill(Vector3i(maxi(1, roundi(metres.x / cell)), maxi(1, roundi(metres.y / cell)), maxi(1, roundi(metres.z / cell))), material)
	structure.position = centre - Vector3(structure.size) * cell * 0.5
	parent.add_child(structure)
	return structure


func _init() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	add_to_group(GROUP)


func fill(dims: Vector3i, material: String) -> void:
	size = dims
	palette = [material]
	cells.resize(dims.x * dims.y * dims.z)
	cells.fill(1)
	hp.resize(cells.size())
	hp.fill(MaterialToughness.hp_of(material))
	start_cells = cells.size()


func _ready() -> void:
	rebuild()


func index(c: Vector3i) -> int:
	return c.x + c.y * size.x + c.z * size.x * size.y


func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < size.x and c.y < size.y and c.z < size.z


func cell_at(c: Vector3i) -> String:
	if not inside(c) or cells[index(c)] == 0:
		return ""
	return palette[cells[index(c)] - 1]


func set_cell(c: Vector3i, material: String) -> void:
	if not inside(c):
		return
	if material.is_empty():
		cells[index(c)] = 0
		return
	if not palette.has(material):
		palette.append(material)
	cells[index(c)] = palette.find(material) + 1
	hp[index(c)] = MaterialToughness.hp_of(material)


func solid_count() -> int:
	return cells.size() - cells.count(0)


## Lost a real share of itself (or is gone). Pieces that broke off never count.
func broken() -> bool:
	return start_cells > 0 and solid_count() <= int(start_cells * (1.0 - BROKEN_SHARE))


func cell_of(world_point: Vector3) -> Vector3i:
	var local := to_local(world_point) / voxel
	return Vector3i(floori(local.x), floori(local.y), floori(local.z))


func cell_centre(c: Vector3i) -> Vector3:
	return to_global((Vector3(c) + Vector3(0.5, 0.5, 0.5)) * voxel)


## Takes `damage` (full at the centre, half at the edge) off every cell within
## `radius` of `world_point` that `source` can beat. Returns what happened:
## removed cells, cells it could not beat ("blocked"), pieces that broke off.
## `shock` > 0 (blasts): out to SHOCK_REACH x radius, cells also take
## `shock` x damage, falling to nothing at the edge.
func damage_sphere(world_point: Vector3, radius: float, source: String, damage: float, push := Vector3.ZERO, params := {}, shock := 0.0) -> Dictionary:
	var result := {"removed": 0, "blocked": 0, "fell": 0, "material": ""}
	var centre := to_local(world_point) / voxel
	var core := radius / voxel
	var reach := core * (SHOCK_REACH if shock > 0.0 else 1.0)
	var low := Vector3i(floori(centre.x - reach), floori(centre.y - reach), floori(centre.z - reach)).max(Vector3i.ZERO)
	var high := Vector3i(floori(centre.x + reach), floori(centre.y + reach), floori(centre.z + reach)).min(size - Vector3i.ONE)
	var gone: Array[Vector3i] = []
	for z in range(low.z, high.z + 1):
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var i := x + y * size.x + z * size.x * size.y
				if cells[i] == 0:
					continue
				var distance := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)).distance_to(centre)
				if distance > reach:
					continue
				var material := palette[cells[i] - 1]
				if not MaterialToughness.can_break(source, material, params):
					result.blocked += 1
					continue
				if distance <= core:
					hp[i] -= damage * (1.0 - 0.5 * distance / maxf(core, 0.001))
				else:
					hp[i] -= damage * shock * (1.0 - (distance - core) / maxf(reach - core, 0.001))
				if hp[i] <= 0.0:
					result.material = material
					gone.append(Vector3i(x, y, z))
	var sooted := shock > 0.0 and _blacken(centre, core, core * SOOT_REACH)
	if gone.is_empty():
		if sooted:
			# Only the colour changed: the collider stays as it is.
			rebuild(false)
		return result
	var away := push if push.length_squared() > 0.0 else Vector3.UP
	var flown := {}
	for n in gone.size():
		var c := gone[n]
		var material := cell_at(c)
		flown[material] = int(flown.get(material, 0)) + 1
		if int(flown[material]) <= BlastFx.pieces_of(material, CUBES_PER_HIT):
			spawn_cube(get_parent(), cell_centre(c), voxel * 0.9, cell_at(c), (away.normalized() * 3.0 + (cell_centre(c) - world_point).normalized() * 2.5) * clampf(damage / 60.0, 0.4, 3.0))
		cells[index(c)] = 0
	result.removed = gone.size()
	MaterialToughness.play_break(self, world_point, str(result.material))
	var fx := BlastFx.of(self)
	if fx != null:
		fx.break_dust(world_point, str(result.material), gone.size(), away)
	result.fell = _split(away)
	rebuild()
	return result


## Soot on every standing cell within `reach` cells of `centre` (grid units),
## full out to `core`. Returns whether any cell got darker.
func _blacken(centre: Vector3, core: float, reach: float) -> bool:
	if soot.size() != cells.size():
		soot.resize(cells.size())
	var low := Vector3i(floori(centre.x - reach), floori(centre.y - reach), floori(centre.z - reach)).max(Vector3i.ZERO)
	var high := Vector3i(floori(centre.x + reach), floori(centre.y + reach), floori(centre.z + reach)).min(size - Vector3i.ONE)
	var changed := false
	for z in range(low.z, high.z + 1):
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var i := x + y * size.x + z * size.x * size.y
				if cells[i] == 0:
					continue
				var distance := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)).distance_to(centre)
				var t := 1.0 - maxf(distance - core, 0.0) / maxf(reach - core, 0.001)
				if t <= 0.0:
					continue
				# Ragged, not a perfect disc: each cell takes a share of it.
				var level := int(255.0 * clampf(t * 1.4, 0.0, 1.0) * (0.65 + 0.35 * float(hash(i) % 100) / 100.0))
				if level > soot[i]:
					soot[i] = level
					changed = true
	return changed


## Anything no longer joined to an anchor breaks off and falls. Returns the
## number of pieces that came away.
func _split(push: Vector3) -> int:
	var seen := PackedByteArray()
	seen.resize(cells.size())
	var islands: Array = []
	var held: Array = []
	for i in cells.size():
		if cells[i] == 0 or seen[i] == 1:
			continue
		var island := _flood(i, seen)
		var anchored := false
		for c: Vector3i in island:
			if _is_anchor(c):
				anchored = true
				break
		(held if anchored else islands).append(island)
	if anchor == "none" and held.is_empty() and not islands.is_empty():
		# A loose piece keeps its biggest part; only the smaller ones come away.
		islands.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
		islands.pop_front()
	for island: Array in islands:
		_break_off(island, push)
	if solid_count() == 0:
		queue_free()
	return islands.size()


func _is_anchor(c: Vector3i) -> bool:
	match anchor:
		"floor":
			return c.y == 0
		"rim":
			return c.x == 0 or c.z == 0 or c.x == size.x - 1 or c.z == size.z - 1
	return false


func _flood(start: int, seen: PackedByteArray) -> Array:
	var out: Array = []
	var stack := [start]
	seen[start] = 1
	var layer := size.x * size.y
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var c := Vector3i(i % size.x, (i / size.x) % size.y, i / layer)
		out.append(c)
		for face in FACES:
			var n: Vector3i = c + (face[0] as Vector3i)
			if not inside(n):
				continue
			var j := n.x + n.y * size.x + n.z * layer
			if cells[j] != 0 and seen[j] == 0:
				seen[j] = 1
				stack.append(j)
	return out


func _break_off(island: Array, push: Vector3) -> void:
	if island.size() <= LOOSE_CELLS:
		for c: Vector3i in island:
			spawn_cube(get_parent(), cell_centre(c), voxel * 0.9, cell_at(c), push.normalized())
			cells[index(c)] = 0
		return
	var low := Vector3i(size)
	var high := Vector3i.ZERO
	for c: Vector3i in island:
		low = low.min(c)
		high = high.max(c)
	var piece := VoxelStructure.new()
	piece.voxel = voxel
	piece.anchor = "none"
	piece.size = high - low + Vector3i.ONE
	piece.cells.resize(piece.size.x * piece.size.y * piece.size.z)
	piece.hp.resize(piece.cells.size())
	var mass_total := 0.0
	var dirty := soot.size() == cells.size()
	if dirty:
		piece.soot.resize(piece.cells.size())
	for c: Vector3i in island:
		var material := cell_at(c)
		piece.set_cell(c - low, material)
		piece.hp[piece.index(c - low)] = hp[index(c)]
		if dirty:
			piece.soot[piece.index(c - low)] = soot[index(c)]
		mass_total += float((MaterialToughness.MATERIALS.get(material, {}) as Dictionary).get("mass", 2.0))
		cells[index(c)] = 0
	piece.freeze = false
	piece.mass = maxf(mass_total, 1.0)
	piece.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	get_parent().add_child(piece)
	piece.global_transform = global_transform.translated_local(Vector3(low) * voxel)
	piece.linear_velocity = push.normalized() * 0.6
	_hurts_bodies(piece)
	WorldDebris.register(piece, {"kind": "voxel_piece", "material": piece.palette[0]}, CHUNK_POOL, CHUNK_BUDGET)


## The exposed faces as one mesh (vertex colour per material, a little grain
## per cell so a wall reads as blocks), and the matching collider unless
## `collide` is false (a soot-only change keeps the old one).
func rebuild(collide := true) -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Voxels"
		add_child(_mesh)
		_shape = CollisionShape3D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var colour_of: Array[Color] = []
	for material in palette:
		colour_of.append((MaterialToughness.MATERIALS.get(material, MaterialToughness.MATERIALS.dirt) as Dictionary).colour)
	var layer := size.x * size.y
	if soot.size() != cells.size():
		soot.resize(cells.size())
	for z in size.z:
		for y in size.y:
			for x in size.x:
				var id := cells[x + y * size.x + z * layer]
				if id == 0:
					continue
				var grain := 0.86 + 0.14 * float(hash(Vector3i(x, y, z)) % 100) / 100.0
				var tint: Color = colour_of[id - 1] * grain
				var black := soot[x + y * size.x + z * layer]
				if black > 0:
					tint = tint.lerp(SOOT, float(black) / 255.0 * 0.88)
				tint.a = 1.0
				var base := Vector3(x, y, z)
				for face in FACES:
					var n: Vector3i = face[0]
					var nx: int = x + n.x
					var ny: int = y + n.y
					var nz: int = z + n.z
					if nx >= 0 and ny >= 0 and nz >= 0 and nx < size.x and ny < size.y and nz < size.z and cells[nx + ny * size.x + nz * layer] != 0:
						continue
					var start := verts.size()
					for corner: Vector3 in face[1]:
						verts.append((base + corner) * voxel)
						normals.append(Vector3(n))
						colours.append(tint)
					# Godot's front faces wind clockwise seen from outside.
					indices.append_array([start, start + 2, start + 1, start, start + 3, start + 2])
	_drop_scars()
	if verts.is_empty():
		_mesh.mesh = null
		_shape.shape = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, look())
	_mesh.mesh = mesh
	if not collide and _shape.shape != null:
		return
	if freeze:
		var faces := PackedVector3Array()
		for i in indices:
			faces.append(verts[i])
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(faces)
		trimesh.backface_collision = true
		_shape.shape = trimesh
	else:
		# ponytail: a hull over the piece, so an L-shaped chunk collides as its hull; compound boxes if that shows.
		var hull := ConvexPolygonShape3D.new()
		hull.points = verts
		_shape.shape = hull


## Bullet scars (`Ballistics`) with nothing left round them (a blast took
## the wall there) go too. A scar over its own round's hole keeps its rim.
func _drop_scars() -> void:
	for child in get_children():
		if not child.has_meta(SCAR):
			continue
		var scar := child as Node3D
		var c := cell_of(scar.global_position - scar.global_basis.y * 0.03)
		var held := false
		for z in range(-1, 2):
			for y in range(-1, 2):
				for x in range(-1, 2):
					if not cell_at(c + Vector3i(x, y, z)).is_empty():
						held = true
		if not held:
			scar.queue_free()


## Drops the shared material and the break voices, for a test or scene swap
## that tears down before quitting (engine shutdown freeing static resources
## late can crash).
static func release() -> void:
	_look = null
	MaterialToughness.release()


static func look() -> StandardMaterial3D:
	if _look == null:
		_look = StandardMaterial3D.new()
		_look.vertex_color_use_as_albedo = true
		# The table's colours are sRGB; without this brick reads salmon.
		_look.vertex_color_is_srgb = true
		_look.roughness = 0.88
	return _look


## A loose cube of `material`: falls, hurts what it hits fast, and is capped.
static func spawn_cube(parent: Node, at: Vector3, edge: float, material: String, velocity: Vector3) -> RigidBody3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var cube := RigidBody3D.new()
	cube.name = "VoxelCube"
	# Own layer, so tool rays (mask 1) reach past the rubble to the wall.
	cube.collision_layer = DEBRIS_LAYER
	cube.collision_mask = 1 | DEBRIS_LAYER | RagdollBody.BODY_LAYER
	# imp-63: the piece is the material's (`BlastFx.DEBRIS`): brick chunks,
	# concrete grit, wood splinters, steel shards. One shared mesh and look each.
	var dims := BlastFx.piece_size(material, edge)
	var full := edge * edge * edge
	cube.mass = maxf(0.05, float((MaterialToughness.MATERIALS.get(material, {}) as Dictionary).get("mass", 2.0)) * 0.4 * (dims.x * dims.y * dims.z) / full)
	var visual := MeshInstance3D.new()
	visual.mesh = BlastFx.unit_box()
	visual.material_override = BlastFx.piece_look(material)
	visual.scale = dims
	visual.layers = DEBRIS_VISUAL
	cube.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dims
	collision.shape = shape
	cube.add_child(collision)
	parent.add_child(cube)
	cube.global_position = at
	cube.linear_velocity = velocity
	cube.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	_hurts_bodies(cube)
	WorldDebris.register(cube, {"kind": "voxel_cube", "material": material}, CUBE_POOL, CUBE_BUDGET)
	return cube


## Debris that meets a body's hitbox fast enough wounds it there, by momentum.
static func _hurts_bodies(piece: RigidBody3D) -> void:
	var sensor := Area3D.new()
	sensor.name = "Hurts"
	sensor.monitorable = false
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.12
	shape.shape = ball
	sensor.add_child(shape)
	piece.add_child(sensor)
	sensor.area_entered.connect(func(area: Area3D) -> void: hurt_by(piece, area))


static func hurt_by(piece: RigidBody3D, area: Node) -> Dictionary:
	if not is_instance_valid(piece):
		return {}
	var speed := piece.linear_velocity.length()
	if speed < HURT_SPEED:
		return {}
	var node := area
	while node != null and not node is BaselineHuman:
		node = node.get_parent()
	if node == null:
		return {}
	var momentum := piece.mass * speed
	return (node as BaselineHuman).hit_at(piece.global_position, momentum * HURT_PER_MOMENTUM, momentum * 0.5, "blunt", piece.linear_velocity.normalized())
