class_name DigTerrain
extends StaticBody3D

## Diggable ground (Greg, 5 Oct: "including making the ground DIGGABLE";
## "smooth ground digging (marching-cubes / SDF terrain)").
##
## A patch of ground held as a density grid (positive = soil) and drawn with
## naive surface nets, one mesh and trimesh per 8-cell chunk. Explosives carve
## a crater, the dig tool takes a scoop; only the chunks a cut touches are
## rebuilt. Every cut is kept in `cuts`, so a save can replay them: craters
## and tunnels persist. The patch's outer skin never changes, so digging at
## the edge shows a wall of earth, not the void.
##
## ponytail: GDScript meshing (~ms per chunk) suits a lab patch; the real map's
## kilometres want Zylann's Voxel Tools (VoxelLodTerrain) behind the same calls.

const GROUP := "dig_terrain"
const CHUNK := 8

@export var cell := 0.25
## Cells across (x, y, z). The ground surface sits `depth` metres above the
## bottom; the top cells are air for the crater lips and spoil.
@export var cells := Vector3i(24, 14, 24)
@export var depth := 3.0
@export var material := "dirt"
var density := PackedFloat32Array()
var cuts: Array = []
var _chunks: Dictionary = {}
var _dirty: Dictionary = {}
var _look: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	var samples := (cells + Vector3i.ONE)
	density.resize(samples.x * samples.y * samples.z)
	for z in samples.z:
		for y in samples.y:
			for x in samples.x:
				density[_s(x, y, z)] = depth - float(y) * cell
	_look = StandardMaterial3D.new()
	_look.vertex_color_use_as_albedo = true
	_look.roughness = 0.97
	for cz in ceili(float(cells.z) / CHUNK):
		for cy in ceili(float(cells.y) / CHUNK):
			for cx in ceili(float(cells.x) / CHUNK):
				_dirty[Vector3i(cx, cy, cz)] = true
	_flush()


func _s(x: int, y: int, z: int) -> int:
	return x + y * (cells.x + 1) + z * (cells.x + 1) * (cells.y + 1)


## The world point's soil density (positive = solid), nearest sample.
func density_at(world_point: Vector3) -> float:
	var local := to_local(world_point) / cell
	var c := Vector3i(roundi(local.x), roundi(local.y), roundi(local.z)).clamp(Vector3i.ZERO, cells)
	return density[_s(c.x, c.y, c.z)]


func is_solid(world_point: Vector3) -> bool:
	return density_at(world_point) > 0.0


## The world height of the untouched surface.
func surface_y() -> float:
	return global_position.y + depth


## A crater or scoop: soil within `radius` of `world_point` is gone, if
## `source` beats the soil's tier. Returns the number of samples cut.
func carve_sphere(world_point: Vector3, radius: float, source := "dig", params := {}) -> int:
	if not MaterialToughness.can_break(source, material, params):
		return 0
	var centre := to_local(world_point)
	var cut := _cut(centre - Vector3.ONE * radius, centre + Vector3.ONE * radius, func(p: Vector3) -> float: return p.distance_to(centre) - radius)
	if cut > 0:
		cuts.append({"shape": "sphere", "at": centre, "r": radius})
		_spoil(world_point, radius)
		MaterialToughness.play_break(self, world_point, material)
	return cut


## A box of soil gone (local space corners), for authored pockets and shafts.
func carve_box(low: Vector3, high: Vector3) -> int:
	var middle := (low + high) * 0.5
	var half := (high - low) * 0.5
	var cut := _cut(low, high, func(p: Vector3) -> float:
		var q := (p - middle).abs() - half
		return maxf(q.x, maxf(q.y, q.z)))
	if cut > 0:
		cuts.append({"shape": "box", "low": low, "high": high})
	return cut


## Replays saved cuts onto fresh ground.
func restore(saved: Array) -> void:
	for entry: Dictionary in saved:
		if entry.shape == "sphere":
			carve_sphere(to_global(entry.at), entry.r, "charge")
		else:
			carve_box(entry.low, entry.high)


## `inside(p)` is the signed distance to the cut (negative inside). Soil takes
## the smaller of what it was and that, so cuts only ever remove.
func _cut(low: Vector3, high: Vector3, inside: Callable) -> int:
	var a := Vector3i((low / cell).floor()).clamp(Vector3i.ONE, cells - Vector3i.ONE)
	var b := Vector3i((high / cell).ceil()).clamp(Vector3i.ONE, cells - Vector3i.ONE)
	var count := 0
	for z in range(a.z, b.z + 1):
		for y in range(a.y, b.y + 1):
			for x in range(a.x, b.x + 1):
				var i := _s(x, y, z)
				var d: float = inside.call(Vector3(x, y, z) * cell)
				if d < density[i]:
					if density[i] > 0.0 and d <= 0.0:
						count += 1
					density[i] = d
					# A sample sits on up to eight cells' corners.
					for dz in [-1, 0]:
						for dy in [-1, 0]:
							for dx in [-1, 0]:
								var c := Vector3i(x + dx, y + dy, z + dz)
								_dirty[Vector3i(c.x / CHUNK, c.y / CHUNK, c.z / CHUNK)] = true
	_flush()
	return count


func _spoil(at: Vector3, radius: float) -> void:
	for n in mini(int(radius * 8.0), 6):
		VoxelStructure.spawn_cube(get_parent(), at + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), 0.12, material, Vector3(randf_range(-2, 2), randf_range(2, 5), randf_range(-2, 2)))


func _flush() -> void:
	for key: Vector3i in _dirty:
		_mesh_chunk(key)
	_dirty.clear()


## Naive surface nets: one vertex per cell the surface crosses (the mean of
## its edge crossings), one quad per crossed sample edge.
func _mesh_chunk(key: Vector3i) -> void:
	var start := key * CHUNK
	var end := (start + Vector3i.ONE * CHUNK).min(cells)
	if start.x >= cells.x or start.y >= cells.y or start.z >= cells.z:
		return
	# Cell vertices for this chunk plus one cell back on each axis, which the
	# quads on the chunk's low faces share.
	var vertex_of: Dictionary = {}
	var verts := PackedVector3Array()
	var colours := PackedColorArray()
	var base: Color = (MaterialToughness.MATERIALS.get(material, MaterialToughness.MATERIALS.dirt) as Dictionary).colour
	var sy := cells.x + 1
	var sz := sy * (cells.y + 1)
	var offsets := [0, 1, sy, 1 + sy, sz, 1 + sz, sy + sz, 1 + sy + sz]
	var corner := PackedFloat32Array()
	corner.resize(8)
	for z in range(maxi(start.z - 1, 0), end.z):
		for y in range(maxi(start.y - 1, 0), end.y):
			for x in range(maxi(start.x - 1, 0), end.x):
				# Most cells are all soil or all air: eight reads and out.
				var origin := _s(x, y, z)
				var solid := 0
				for k in 8:
					corner[k] = density[origin + offsets[k]]
					solid += 1 if corner[k] > 0.0 else 0
				if solid == 0 or solid == 8:
					continue
				var sum := Vector3.ZERO
				var crossings := 0
				for edge in _EDGES:
					var dp := corner[edge[0]]
					var dq := corner[edge[1]]
					if (dp > 0.0) != (dq > 0.0):
						sum += _CORNERS[edge[0]].lerp(_CORNERS[edge[1]], dp / (dp - dq))
						crossings += 1
				var at := Vector3(x, y, z) + sum / float(crossings)
				vertex_of[Vector3i(x, y, z)] = verts.size()
				verts.append(at * cell)
				# Deeper soil is darker and redder.
				var below := clampf((depth - at.y * cell) / depth, 0.0, 1.0)
				var grain := 0.9 + 0.1 * float(hash(Vector3i(x, y, z)) % 100) / 100.0
				var tint := base.lerp(Color("2a1a12"), below * 0.7) * grain
				tint.a = 1.0
				colours.append(tint)
	var indices := PackedInt32Array()
	# A sample edge along `axis` from sample s, crossed by the surface, is
	# ringed by the four cells sharing it.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		# Only the chunk owning the edge's base sample draws it.
		var stride: int = [1, sy, sz][axis]
		for z in range(start.z, end.z):
			for y in range(start.y, end.y):
				for x in range(start.x, end.x):
					var i := _s(x, y, z)
					var ds := density[i]
					if (ds > 0.0) == (density[i + stride] > 0.0):
						continue
					var s := Vector3i(x, y, z)
					if s[u] < 1 or s[v] < 1:
						continue
					var c0 := s
					var c1 := s
					c1[u] -= 1
					var c2 := s
					c2[u] -= 1
					c2[v] -= 1
					var c3 := s
					c3[v] -= 1
					if not (vertex_of.has(c0) and vertex_of.has(c1) and vertex_of.has(c2) and vertex_of.has(c3)):
						continue
					var quad := [vertex_of[c0], vertex_of[c1], vertex_of[c2], vertex_of[c3]]
					# Face out of the soil: towards the air end of the edge.
					var out := Vector3.ZERO
					out[axis] = -1.0 if ds <= 0.0 else 1.0
					var normal := (verts[quad[1]] - verts[quad[0]]).cross(verts[quad[2]] - verts[quad[0]])
					if normal.dot(out) > 0.0:
						indices.append_array([quad[0], quad[2], quad[1], quad[0], quad[3], quad[2]])
					else:
						indices.append_array([quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]])
	var chunk: MeshInstance3D = _chunks.get(key)
	if chunk == null:
		chunk = MeshInstance3D.new()
		chunk.name = "Chunk_%d_%d_%d" % [key.x, key.y, key.z]
		add_child(chunk)
		var shape := CollisionShape3D.new()
		shape.name = "Shape_%d_%d_%d" % [key.x, key.y, key.z]
		add_child(shape)
		chunk.set_meta("shape", shape)
		_chunks[key] = chunk
	var collider := chunk.get_meta("shape") as CollisionShape3D
	if indices.is_empty():
		chunk.mesh = null
		collider.shape = null
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		tool.set_color(colours[i])
		tool.add_vertex(verts[i])
	for i in indices:
		tool.add_index(i)
	tool.generate_normals()
	tool.set_material(_look)
	var mesh := tool.commit()
	chunk.mesh = mesh
	var faces := PackedVector3Array()
	for i in indices:
		faces.append(verts[i])
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.set_faces(faces)
	trimesh.backface_collision = true
	collider.shape = trimesh


## A cell's corners, k = x + 2y + 4z, and its twelve edges as corner pairs.
const _CORNERS: Array[Vector3] = [
	Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0),
	Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1),
]
const _EDGES := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
