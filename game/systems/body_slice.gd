class_name BodySlice
extends RefCounted

## Cutting a body somewhere the rig did not plan for.
##
## `baseline_human._sever_zone()` already takes a limb off, but only ever at a
## joint the zone table knew about in advance. A blade that comes down through a
## collarbone at forty degrees gets rounded to "the arm came off at the
## shoulder", because a zone is the smallest thing the body can lose. Every cut
## in the game therefore lands on one of a dozen pre-agreed lines, and a sword
## and a shotgun take a limb off in exactly the same place.
##
## This cuts the geometry instead. Given a mesh and a plane, it returns the two
## halves and the cross-section between them.
##
## The reason this is cheap here and expensive everywhere else is worth stating,
## because it is the whole argument for doing it:
##
## Runtime mesh slicing is hard in most engines because characters are *skinned*
## -- every vertex the cut invents needs new bone indices and new bone weights
## derived from its neighbours, and getting that wrong tears the mesh apart the
## next time it animates. `BodyMesh` has no skeleton and no skin. A limb is a
## revolved `ArrayMesh` of plain positions, closed at both ends. So the hard
## half of the problem does not exist, and what is left is the part that is just
## arithmetic: classify each vertex against the plane, split the triangles that
## straddle it, and close the hole.
##
## Being closed already is the other half of the gift. A cut across a solid
## produces a loop, and a loop can be filled. Cutting an open shell would leave
## a cross-section with no boundary to fill against.

## Distances below this count as *on* the plane. A vertex exactly on the cut is
## the one case that produces degenerate triangles, so it is pushed to whichever
## side it is nearest and the straddle test skips it.
const EPSILON := 0.00001


## Cut `mesh` with `plane` and return both halves.
##
## `above` is the piece on the side the plane normal points at. Either half is
## null when the plane misses the mesh entirely, which is the common case when a
## swing connects with only one limb -- callers check for null rather than
## getting an empty mesh they have to measure.
##
## `section` is the cut face's boundary as unordered segment pairs, kept because
## the caller wants it: it is where blood comes from, where `GoreChunks` should
## spawn the exposed layer, and how wide the wound reads.
static func split(mesh: Mesh, plane: Plane, surface_index := 0) -> Dictionary:
	var empty := {"above": null, "below": null, "section": [], "area": 0.0, "centre": Vector3.ZERO}
	if mesh == null or mesh.get_surface_count() <= surface_index:
		return empty
	var arrays := mesh.surface_get_arrays(surface_index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return empty

	# `SurfaceTool.commit()` produces indexed geometry, so the index array is
	# the one that describes the triangles. A mesh built without it still has
	# vertices in triangle order, so fall back to walking them directly.
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices = PackedInt32Array()
		for i in vertices.size():
			indices.append(i)

	var above := SurfaceTool.new()
	var below := SurfaceTool.new()
	above.begin(Mesh.PRIMITIVE_TRIANGLES)
	below.begin(Mesh.PRIMITIVE_TRIANGLES)
	var section: Array[Vector3] = []
	var above_count := 0
	var below_count := 0

	var triangle := 0
	while triangle + 2 < indices.size():
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		triangle += 3
		var da := plane.distance_to(a)
		var db := plane.distance_to(b)
		var dc := plane.distance_to(c)
		# Treating near-zero as "on the near side" rather than as its own case
		# keeps the straddle logic to two shapes instead of six.
		var up_a := da >= -EPSILON
		var up_b := db >= -EPSILON
		var up_c := dc >= -EPSILON
		var up_count := int(up_a) + int(up_b) + int(up_c)

		if up_count == 3:
			_tri(above, a, b, c)
			above_count += 1
			continue
		if up_count == 0:
			_tri(below, a, b, c)
			below_count += 1
			continue

		# Rotate the triangle so the vertex that sits alone on its side is
		# first. Both straddle cases then have the same shape and only the
		# destination of the two resulting pieces differs.
		var lone_first := _rotate_to_lone(a, b, c, up_a, up_b, up_c)
		var p: Vector3 = lone_first[0]
		var q: Vector3 = lone_first[1]
		var r: Vector3 = lone_first[2]
		var lone_is_above: bool = lone_first[3]
		# The two cut points, on the edges leaving the lone vertex.
		var pq := _cross_point(p, q, plane)
		var pr := _cross_point(p, r, plane)
		section.append(pq)
		section.append(pr)

		var lone_side := above if lone_is_above else below
		var other_side := below if lone_is_above else above
		# The lone vertex keeps a single corner triangle; the opposite edge
		# becomes a quad, which is two triangles wound the same way as the
		# original so the surface does not flip at the cut.
		_tri(lone_side, p, pq, pr)
		_tri(other_side, pq, q, r)
		_tri(other_side, pq, r, pr)
		if lone_is_above:
			above_count += 1
			below_count += 2
		else:
			below_count += 1
			above_count += 2

	if section.is_empty():
		# The plane missed. Whichever side has the triangles gets the whole
		# mesh back, and the other is null.
		above.clear()
		below.clear()
		var untouched := plane.distance_to(vertices[0]) >= 0.0
		return {
			"above": mesh if untouched else null,
			"below": null if untouched else mesh,
			"section": [],
			"area": 0.0,
			"centre": Vector3.ZERO,
		}

	var centre := _centroid(section)
	var area := _cap(above, below, section, centre, plane)
	# A cut that clips a single corner leaves a sliver that is not worth being a
	# separate object. Below three triangles there is nothing to look at.
	var result := {
		"above": _commit(above) if above_count >= 3 else null,
		"below": _commit(below) if below_count >= 3 else null,
		"section": section,
		"area": area,
		"centre": centre,
	}
	return result


## Where an edge crosses the plane. Found by the ratio of the two distances
## rather than by `Plane.intersects_segment()` so an edge that lies along the
## plane returns a usable point instead of null.
static func _cross_point(from: Vector3, to: Vector3, plane: Plane) -> Vector3:
	var d_from := plane.distance_to(from)
	var d_to := plane.distance_to(to)
	var span := d_from - d_to
	if absf(span) < EPSILON:
		return from
	return from.lerp(to, clampf(d_from / span, 0.0, 1.0))


## Puts the vertex that is alone on its side of the plane first, preserving
## winding so the two survivors stay in their original order.
static func _rotate_to_lone(a: Vector3, b: Vector3, c: Vector3, up_a: bool, up_b: bool, up_c: bool) -> Array:
	if up_a != up_b and up_a != up_c:
		return [a, b, c, up_a]
	if up_b != up_a and up_b != up_c:
		return [b, c, a, up_b]
	return [c, a, b, up_c]


## Fills the cut on both halves with a fan from the section's centre.
##
## The fan is built per *segment* rather than by sorting the boundary into a
## loop first. Each straddling triangle contributes exactly one segment, so the
## segments already describe the boundary; ordering them would be work done only
## to throw the order away again. This is exact for the elliptical cross-sections
## `BodyMesh.revolve()` produces, and on a concave section -- a cut through the
## gap between two fingers, say -- the fan would web across the gap. No limb
## profile in `BodyMesh` is concave in cross-section, so that case cannot arise
## from a limb today; it is the thing to revisit if authored meshes replace the
## generated ones.
##
## Returns the filled area, which is what the caller sizes the wound by.
static func _cap(above: SurfaceTool, below: SurfaceTool, section: Array, centre: Vector3, plane: Plane) -> float:
	var area := 0.0
	var index := 0
	while index + 1 < section.size():
		var p: Vector3 = section[index]
		var q: Vector3 = section[index + 1]
		index += 2
		var edge_a := p - centre
		var edge_b := q - centre
		var face := edge_a.cross(edge_b)
		if face.length_squared() < EPSILON * EPSILON:
			continue
		area += face.length() * 0.5
		# The cut face on the lower half looks along the plane normal, and the
		# upper half's looks back down it. Winding is chosen from the actual
		# cross product rather than assumed, because the segment's endpoints
		# arrive in whatever order the straddling triangle happened to have.
		if face.dot(plane.normal) >= 0.0:
			_tri(below, centre, p, q)
			_tri(above, centre, q, p)
		else:
			_tri(below, centre, q, p)
			_tri(above, centre, p, q)
	return area


static func _centroid(points: Array) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for point in points:
		total += point as Vector3
	return total / float(points.size())


static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


## Matches `BodyMesh`: positions go in bare and the normals are derived at the
## end, so a cut piece shades exactly like the mesh it came off.
static func _commit(surface: SurfaceTool) -> ArrayMesh:
	surface.generate_normals()
	return surface.commit()


## Convenience for the common case: a blade sweeping through a body. The plane
## is built from the swing rather than the caller having to derive it, so a
## weapon only has to report where it was and which way it was going.
##
## `through` is a point the blade passed through, `edge_direction` is the line
## of the cutting edge and `travel` is the direction of the swing. The plane
## contains both, which is what a real cut does -- the blade does not slice
## across its own motion.
static func plane_from_swing(through: Vector3, edge_direction: Vector3, travel: Vector3) -> Plane:
	var edge := edge_direction.normalized()
	var sweep := travel.normalized()
	var normal := edge.cross(sweep)
	if normal.length_squared() < EPSILON:
		# Edge and travel parallel: the blade is moving along its own length, a
		# draw cut rather than a chop. Any plane containing the edge will do, so
		# take the one that stands up from it.
		normal = edge.cross(Vector3.UP)
		if normal.length_squared() < EPSILON:
			normal = edge.cross(Vector3.RIGHT)
	return Plane(normal.normalized(), through)
