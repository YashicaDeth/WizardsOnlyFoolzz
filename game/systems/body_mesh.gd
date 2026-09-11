class_name BodyMesh
extends RefCounted

## Geometry factory for the baseline human. Kept apart from `baseline_human.gd`
## so the body's simulation and the body's shape can change independently — the
## rig cares which zones exist and what state they are in, not how many rings a
## femur is swept from.
##
## Everything is generated rather than authored because the zones, their sizes
## and their seated/standing layouts are all defined in code; a static GLB would
## have to be re-exported every time one of them moved. Authored meshes replace
## these later per ART-DIRECTION.md's placeholder rule — same node names, same
## pivots, same scale.
##
## Profiles are arrays of Vector3(height, radius_x, radius_z). The elliptical
## cross-section is the whole reason this exists: a chest is wide and flat and a
## forearm is round, and a capsule cannot express the difference.

const SEGMENTS := 12


static func revolve(rings: Array, segments: int = SEGMENTS) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in rings.size() - 1:
		var lower: Vector3 = rings[index]
		var upper: Vector3 = rings[index + 1]
		for step in segments:
			var a := TAU * float(step) / float(segments)
			var b := TAU * float(step + 1) / float(segments)
			var p0 := Vector3(cos(a) * lower.y, lower.x, sin(a) * lower.z)
			var p1 := Vector3(cos(b) * lower.y, lower.x, sin(b) * lower.z)
			var p2 := Vector3(cos(a) * upper.y, upper.x, sin(a) * upper.z)
			var p3 := Vector3(cos(b) * upper.y, upper.x, sin(b) * upper.z)
			_tri(surface, p0, p2, p1)
			_tri(surface, p1, p2, p3)
	# Cap both ends so a severed limb is not a hollow tube when you look into it.
	_cap(surface, rings[0], segments, true)
	_cap(surface, rings[rings.size() - 1], segments, false)
	surface.generate_normals()
	return surface.commit()


## Sweeps a small circular tube along an elliptical arc. Ribs, mostly.
static func arc_tube(width: float, depth: float, thickness: float, from_angle: float, to_angle: float, steps: int = 10) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := 6
	for index in steps:
		var t0 := lerpf(from_angle, to_angle, float(index) / float(steps))
		var t1 := lerpf(from_angle, to_angle, float(index + 1) / float(steps))
		var c0 := Vector3(cos(t0) * width, 0.0, sin(t0) * depth)
		var c1 := Vector3(cos(t1) * width, 0.0, sin(t1) * depth)
		for step in ring:
			var a := TAU * float(step) / float(ring)
			var b := TAU * float(step + 1) / float(ring)
			var o0a := Vector3(0.0, sin(a) * thickness, 0.0) + Vector3(cos(t0), 0.0, sin(t0)) * cos(a) * thickness
			var o0b := Vector3(0.0, sin(b) * thickness, 0.0) + Vector3(cos(t0), 0.0, sin(t0)) * cos(b) * thickness
			var o1a := Vector3(0.0, sin(a) * thickness, 0.0) + Vector3(cos(t1), 0.0, sin(t1)) * cos(a) * thickness
			var o1b := Vector3(0.0, sin(b) * thickness, 0.0) + Vector3(cos(t1), 0.0, sin(t1)) * cos(b) * thickness
			_tri(surface, c0 + o0a, c1 + o1a, c0 + o0b)
			_tri(surface, c0 + o0b, c1 + o1a, c1 + o1b)
	surface.generate_normals()
	return surface.commit()


## Flesh. Proportions are the point: shoulders wider than the waist, a calf that
## swells and tapers to an ankle, a forearm narrower than a bicep.
static func torso(height: float) -> ArrayMesh:
	var h := height * 0.5
	return revolve([
		Vector3(-h, 0.150, 0.095),
		Vector3(-h * 0.55, 0.142, 0.092),
		Vector3(-h * 0.10, 0.155, 0.100),
		Vector3(h * 0.42, 0.196, 0.112),
		Vector3(h * 0.80, 0.188, 0.104),
		Vector3(h, 0.120, 0.078),
	])


static func head(size: float) -> ArrayMesh:
	var r := size * 0.5
	return revolve([
		Vector3(-r * 1.05, 0.052, 0.058),
		Vector3(-r * 0.55, 0.086, 0.094),
		Vector3(-r * 0.10, 0.104, 0.112),
		Vector3(r * 0.45, 0.098, 0.106),
		Vector3(r * 0.95, 0.048, 0.052),
	])


static func arm(length: float) -> ArrayMesh:
	var h := length * 0.5
	return revolve([
		Vector3(-h, 0.036, 0.034),
		Vector3(-h * 0.55, 0.046, 0.044),
		Vector3(-h * 0.06, 0.052, 0.050),
		Vector3(h * 0.05, 0.058, 0.056),
		Vector3(h * 0.62, 0.074, 0.070),
		Vector3(h, 0.068, 0.066),
	])


static func leg(length: float) -> ArrayMesh:
	var h := length * 0.5
	return revolve([
		Vector3(-h, 0.048, 0.052),
		Vector3(-h * 0.72, 0.042, 0.046),
		Vector3(-h * 0.30, 0.068, 0.070),
		Vector3(-h * 0.02, 0.058, 0.060),
		Vector3(h * 0.05, 0.072, 0.074),
		Vector3(h * 0.68, 0.098, 0.098),
		Vector3(h, 0.092, 0.092),
	])


## Bone. Sits inside the flesh, shows through the X-ray, and is what is left
## sticking out of a stump.
static func long_bone(length: float, thickness: float) -> ArrayMesh:
	var h := length * 0.5
	var t := thickness
	return revolve([
		Vector3(-h, t * 1.5, t * 1.5),
		Vector3(-h * 0.88, t * 1.7, t * 1.7),
		Vector3(-h * 0.70, t * 0.86, t * 0.86),
		Vector3(h * 0.70, t * 0.82, t * 0.82),
		Vector3(h * 0.88, t * 1.75, t * 1.75),
		Vector3(h, t * 1.55, t * 1.55),
	], 8)


static func skull(size: float) -> ArrayMesh:
	var r := size * 0.5
	return revolve([
		Vector3(-r * 1.0, 0.040, 0.046),
		Vector3(-r * 0.62, 0.062, 0.076),
		Vector3(-r * 0.22, 0.078, 0.092),
		Vector3(r * 0.22, 0.086, 0.094),
		Vector3(r * 0.70, 0.070, 0.074),
		Vector3(r * 0.98, 0.026, 0.028),
	], 10)


static func vertebra() -> ArrayMesh:
	return revolve([
		Vector3(-0.016, 0.020, 0.017),
		Vector3(-0.004, 0.029, 0.024),
		Vector3(0.004, 0.029, 0.024),
		Vector3(0.016, 0.020, 0.017),
	], 8)


static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


static func _cap(surface: SurfaceTool, ring: Vector3, segments: int, flip: bool) -> void:
	var centre := Vector3(0.0, ring.x, 0.0)
	for step in segments:
		var a := TAU * float(step) / float(segments)
		var b := TAU * float(step + 1) / float(segments)
		var p0 := Vector3(cos(a) * ring.y, ring.x, sin(a) * ring.z)
		var p1 := Vector3(cos(b) * ring.y, ring.x, sin(b) * ring.z)
		if flip:
			_tri(surface, centre, p0, p1)
		else:
			_tri(surface, centre, p1, p0)
