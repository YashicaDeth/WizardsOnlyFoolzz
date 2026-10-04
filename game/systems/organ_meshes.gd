class_name OrganMeshes
extends RefCounted

## The organs as shapes, rather than as seven spheres of different colours.
##
## Greg, 5 Oct: *"realistic and wet, Sniper Elite X-ray quality, low-poly but
## anatomically right."* Each organ here is a deformed sphere (or, for the gut,
## a swept tube) with the silhouette that makes it read at a glance: the heart
## a blunt cone tipped down and to the body's left with its great vessels on
## top, each lung a tall half-cone flat on the side facing the heart, the liver
## a wedge thick on the right, the stomach a J, the gut a coil, the kidneys
## beans with the dent facing the spine, the brain two furrowed hemispheres.
##
## Sizes come in as the radius `BaselineHuman.ORGAN_LAYOUT` already gives, so
## every caller that sized an organ by its sphere keeps sizing it the same way.
## The material is on the mesh surface, like the `SphereMesh` it replaces, so
## `WoundMarks` and the X-ray depth override read it from the same place.
##
## Local axes are the rig's: +X is the body's right, +Y up, -Z its front.

const RINGS := 9
const SEGMENTS := 14

## How wet. Dials, not decisions: the clear coat is what reads as "wet" under
## the lab's lamps, and roughness under ~0.3 starts looking like plastic.
const WET_ROUGHNESS := 0.3
const WET_CLEARCOAT := 0.85
const WET_CLEARCOAT_ROUGHNESS := 0.12


static func mesh_for(organ_id: String, radius: float, tint: Color, variation := 0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match organ_id:
		"heart":
			_blob(st, radius, func(p: Vector3) -> Vector3: return _heart(p))
			# Aortic arch and the stump of the pulmonary trunk, on top.
			_tube(st, _arch(Vector3(0.05, 0.75, 0.0), 0.62, 0.55), radius * 0.2, radius)
			_tube(st, [Vector3(-0.2, 0.7, -0.15), Vector3(-0.32, 1.08, -0.2)], radius * 0.16, radius)
		"left_lung", "right_lung":
			var side := -1.0 if organ_id == "left_lung" else 1.0
			_blob(st, radius, func(p: Vector3) -> Vector3: return _lung(p, side))
		"liver":
			_blob(st, radius, func(p: Vector3) -> Vector3: return _liver(p))
		"stomach":
			_blob(st, radius, func(p: Vector3) -> Vector3: return _stomach(p))
		"gut":
			_tube(st, _coil(), radius * 0.2, radius)
		"left_kidney", "right_kidney":
			var side := -1.0 if organ_id == "left_kidney" else 1.0
			_blob(st, radius, func(p: Vector3) -> Vector3: return _kidney(p, side))
		"brain":
			_blob(st, radius, func(p: Vector3) -> Vector3: return _brain(p))
		"spine":
			_blob(st, radius, func(p: Vector3) -> Vector3: return Vector3(p.x * 0.5, p.y * 1.3, p.z * 0.5))
		_:
			_blob(st, radius, func(p: Vector3) -> Vector3: return p)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, wet_material(tint, "bone" if organ_id == "spine" else "flesh", variation))
	return mesh


## Flesh that has just come out of somebody: the world's own flesh grain, with
## a clear coat over it and the roughness taken down so it catches every lamp.
static func wet_material(tint: Color, kind := "flesh", variation := 0) -> StandardMaterial3D:
	var material := WorldLook.surface(tint, kind, variation)
	if kind == "bone":
		return material
	material.roughness = WET_ROUGHNESS
	material.metallic = 0.0
	material.metallic_specular = 0.7
	material.clearcoat_enabled = true
	material.clearcoat = WET_CLEARCOAT
	material.clearcoat_roughness = WET_CLEARCOAT_ROUGHNESS
	material.rim_enabled = true
	material.rim = 0.3
	material.rim_tint = 0.6
	return material


## A unit sphere pushed into shape by `shape`, then scaled to `radius`.
static func _blob(st: SurfaceTool, radius: float, shape: Callable) -> void:
	var grid: Array = []
	for ring in RINGS + 1:
		var theta := PI * float(ring) / float(RINGS)
		var row: Array = []
		for segment in SEGMENTS + 1:
			var phi := TAU * float(segment) / float(SEGMENTS)
			var p := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			row.append((shape.call(p) as Vector3) * radius)
		grid.append(row)
	for ring in RINGS:
		for segment in SEGMENTS:
			var a: Vector3 = grid[ring][segment]
			var b: Vector3 = grid[ring][segment + 1]
			var c: Vector3 = grid[ring + 1][segment]
			var d: Vector3 = grid[ring + 1][segment + 1]
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(d)
			st.add_vertex(c)


## A tube along `path` (unit space, scaled by `scale`), `thickness` across.
static func _tube(st: SurfaceTool, path: Array, thickness: float, scale: float) -> void:
	var sides := 6
	var rings: Array = []
	for index in path.size():
		var at: Vector3 = (path[index] as Vector3) * scale
		var ahead: Vector3 = (path[mini(index + 1, path.size() - 1)] as Vector3) - (path[maxi(index - 1, 0)] as Vector3)
		if ahead.length_squared() < 0.000001:
			ahead = Vector3.UP
		ahead = ahead.normalized()
		var side := ahead.cross(Vector3.FORWARD if absf(ahead.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(ahead).normalized()
		var ring: Array = []
		for k in sides:
			var angle := TAU * float(k) / float(sides)
			ring.append(at + (side * cos(angle) + up * sin(angle)) * thickness)
		rings.append(ring)
	for index in rings.size() - 1:
		for k in sides:
			var a: Vector3 = rings[index][k]
			var b: Vector3 = rings[index][(k + 1) % sides]
			var c: Vector3 = rings[index + 1][k]
			var d: Vector3 = rings[index + 1][(k + 1) % sides]
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(d)


## Blunt cone, apex down, forward and to the body's left (-X).
static func _heart(p: Vector3) -> Vector3:
	var along := (p.y + 1.0) * 0.5
	var girth := lerpf(0.42, 1.0, sqrt(along))
	var q := Vector3(p.x * girth * 0.95, p.y * 1.12, p.z * girth * 0.85)
	# Tilt the apex.
	q = q.rotated(Vector3.BACK, 0.5).rotated(Vector3.RIGHT, -0.25)
	return q


## Tall half-cone, flat on the side facing the middle (`side` is +1 for the
## right lung), narrowing to the apex.
static func _lung(p: Vector3, side: float) -> Vector3:
	var x := p.x
	if x * side < 0.0:
		x *= 0.32
	var taper := lerpf(1.0, 0.5, clampf(p.y, 0.0, 1.0))
	return Vector3(x * 0.78 * taper, p.y * 1.45, p.z * 1.0 * taper)


## Wedge: the right lobe thick, the left thinning to an edge.
static func _liver(p: Vector3) -> Vector3:
	var right := (p.x + 1.0) * 0.5
	var thick := lerpf(0.28, 0.85, right)
	return Vector3(p.x * 1.55, p.y * thick + (0.12 if p.y < 0.0 else 0.0) * right, p.z * lerpf(0.6, 1.0, right))


## A J: the body of the stomach bent round, the fundus bulging up on the left.
static func _stomach(p: Vector3) -> Vector3:
	var q := Vector3(p.x * 1.2, p.y * 0.62, p.z * 0.7)
	q.y += 0.45 * q.x * q.x - 0.25
	if q.x < 0.0:
		q.y += 0.3 * -q.x
		q *= 1.0 + 0.15 * -p.x
	return q


## Bean, the dent (hilum) facing the middle.
static func _kidney(p: Vector3, side: float) -> Vector3:
	var q := Vector3(p.x * 0.58, p.y * 1.0, p.z * 0.42)
	if q.x * side < 0.0:
		q.x *= 1.0 - 0.75 * cos(p.y * PI * 0.5)
	return q


## Two hemispheres with a fissure down the middle and gyri over the top.
static func _brain(p: Vector3) -> Vector3:
	var q := Vector3(p.x * 0.85, p.y * 0.72, p.z * 1.08)
	var fold := 1.0 + 0.07 * sin(p.x * 11.0) * sin(p.z * 9.0 + p.y * 5.0)
	q *= fold
	if absf(p.x) < 0.2 and p.y > -0.2:
		q.y -= 0.14 * (1.0 - absf(p.x) / 0.2)
	if q.y < -0.35:
		q.y = -0.35 + (q.y + 0.35) * 0.4
	return q


static func _arch(base: Vector3, rise: float, span: float) -> Array:
	var path: Array = []
	for index in 9:
		var t := float(index) / 8.0
		path.append(base + Vector3(span * t, rise * sin(t * PI) + 0.1, -0.05 + 0.15 * t))
	return path


## The small bowel, packed: a loop that winds back and forth across the belly.
static func _coil() -> Array:
	var path: Array = []
	var steps := 70
	for index in steps:
		var t := float(index) / float(steps - 1)
		var angle := t * TAU * 3.0
		var reach := lerpf(0.95, 0.35, t)
		path.append(Vector3(
			cos(angle) * reach + sin(t * TAU * 7.0) * 0.08,
			sin(angle) * reach * 0.62 + sin(t * TAU * 9.0) * 0.06,
			sin(t * TAU * 5.0) * 0.18,
		))
	return path
