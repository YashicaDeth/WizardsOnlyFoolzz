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

## Twelve read as a dodecagon on anything as wide as a chest — the flat facets
## were visible on every torso in every capture. Sixteen costs four more
## triangles per ring and stops a body looking like a barrel.
const SEGMENTS := 16


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
## The torso, with shoulders and a neck on it.
##
## The old profile **narrowed** from 0.196 at the chest to 0.120 at the top,
## which is upside down: the shoulder line is the widest part of a human upper
## body, not the narrowest. That is why the arms hung off the sides with daylight
## behind them and why a pair of separate sphere "joints" had to be bolted over
## the seam to hide it.
##
## And it simply stopped at the collar. There was no neck at all, so the head sat
## in the air above a flat top — which is exactly what it looked like.
##
## So: waist in, chest out, **shoulder line widest and flattest**, trapezius
## sloping up off it, then a neck column that runs high enough to end *inside*
## the head. The overlap is the point — two surfaces that meet exactly at a
## shared ring still show a seam when either one moves, and one that runs past
## the join never can.
static func torso(height: float) -> ArrayMesh:
	var h := height * 0.5
	return revolve([
		Vector3(-h, 0.152, 0.098),
		# Waist, genuinely narrower than the hips and the ribs either side of it.
		Vector3(-h * 0.55, 0.134, 0.088),
		Vector3(-h * 0.10, 0.160, 0.104),
		Vector3(h * 0.34, 0.206, 0.118),
		# The shoulder line. Widest ring in the body, and flatter front-to-back
		# than the chest below it, because shoulders are a bar rather than a ball.
		Vector3(h * 0.70, 0.232, 0.113),
		# Trapezius: a slope up off the shoulder, not a step.
		Vector3(h * 0.88, 0.158, 0.099),
		Vector3(h * 0.99, 0.082, 0.076),
		# Neck, running up past the collar and finishing inside the skull.
		Vector3(h * 1.10, 0.064, 0.062),
		Vector3(h * 1.28, 0.061, 0.059),
	])


## The head. Deeper than it is wide, with a jaw that comes to a chin rather than
## a sphere that tapers evenly — the even taper is most of why the old head read
## as a blob with a face painted on it.
static func head(size: float) -> ArrayMesh:
	var r := size * 0.5
	return revolve([
		# Under the jaw, narrow, so the neck disappears into it.
		Vector3(-r * 1.15, 0.044, 0.050),
		# Chin and jawline: the widest part of the lower head is behind the chin,
		# so x stays modest while z runs long.
		Vector3(-r * 0.72, 0.072, 0.090),
		Vector3(-r * 0.32, 0.094, 0.108),
		# Cheekbones.
		Vector3(r * 0.02, 0.104, 0.114),
		Vector3(r * 0.44, 0.100, 0.108),
		Vector3(r * 0.78, 0.080, 0.086),
		Vector3(r * 1.00, 0.040, 0.044),
	])


## The arm, with a deltoid on top of it.
##
## The old one ended at 0.068 — thinner than the bicep below it — so the top of
## the arm was a tapered stump that had to be covered by a sphere. A real
## shoulder is the thickest part of the arm, and once it is, it meets the torso's
## widened shoulder ring on its own and the sphere is not doing any work.
static func arm(length: float) -> ArrayMesh:
	var h := length * 0.5
	return revolve([
		Vector3(-h, 0.034, 0.032),
		# Wrist in, forearm out — the taper that says which end is which.
		Vector3(-h * 0.78, 0.032, 0.031),
		Vector3(-h * 0.52, 0.047, 0.045),
		Vector3(-h * 0.06, 0.050, 0.048),
		Vector3(h * 0.06, 0.056, 0.054),
		Vector3(h * 0.46, 0.078, 0.074),
		# Deltoid: the widest ring in the arm. Carried lower than the very top,
		# because the top has to be a dome rather than a rim.
		Vector3(h * 0.72, 0.092, 0.086),
		Vector3(h * 0.90, 0.068, 0.064),
		# Closed over, not cut off. The previous profile ended on a full-width
		# ring, which `revolve` caps flat — so every arm finished in an open
		# circular lid standing above the shoulder line, clearly detached, right
		# beside the neck. A dome tucks under the torso's shoulder instead.
		Vector3(h, 0.026, 0.024),
	])


## The leg. Ankle, calf, knee, thigh, hip — the knee pinch between calf and
## thigh is what stops it reading as a cone.
static func leg(length: float) -> ArrayMesh:
	var h := length * 0.5
	return revolve([
		Vector3(-h, 0.046, 0.050),
		Vector3(-h * 0.80, 0.039, 0.043),
		# Calf, carried higher and further back than the old profile had it.
		Vector3(-h * 0.34, 0.072, 0.076),
		Vector3(-h * 0.04, 0.057, 0.059),
		Vector3(h * 0.06, 0.071, 0.073),
		Vector3(h * 0.52, 0.094, 0.094),
		Vector3(h * 0.84, 0.104, 0.102),
		Vector3(h, 0.098, 0.096),
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


## A torn membrane rather than a flat rectangle: skin does not come off with a
## clean edge, so both long sides are jagged and the piece has real thickness.
static func torn_flap(width: float, length: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 5
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for step in steps + 1:
		var x := lerpf(-width * 0.5, width * 0.5, float(step) / float(steps))
		var jag := rng.randf_range(-0.3, 0.3) * length
		top.append(Vector3(x, length * 0.5 + jag * 0.4, rng.randf_range(-0.006, 0.006)))
		bottom.append(Vector3(x, -length * 0.5 + jag, rng.randf_range(-0.006, 0.006)))
	for step in steps:
		_tri(surface, bottom[step], top[step], bottom[step + 1])
		_tri(surface, bottom[step + 1], top[step], top[step + 1])
		_tri(surface, bottom[step], bottom[step + 1], top[step])
		_tri(surface, bottom[step + 1], top[step + 1], top[step])
	surface.generate_normals()
	return surface.commit()


## An irregular lump. Fat and loose organ tissue both stop reading as a bead of
## paint the moment the outline is not a perfect sphere.
static func lump(radius: float, seed: int, segments: int = 8) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rings := []
	var ring_count := 5
	for index in ring_count:
		var t := float(index) / float(ring_count - 1)
		var h := lerpf(-radius, radius, t)
		var profile := sin(t * PI) * radius * rng.randf_range(0.78, 1.15)
		rings.append(Vector3(h, profile, profile * rng.randf_range(0.82, 1.1)))
	return revolve(rings, segments)


## A twisted strand, tapered at both ends with an off-centre waist: the
## difference between a torn muscle fibre and a hot-dog-shaped capsule.
static func twisted_strand(length: float, radius: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var h := length * 0.5
	return revolve([
		Vector3(-h, radius * 0.15, radius * 0.15),
		Vector3(-h * 0.6, radius * rng.randf_range(0.85, 1.1), radius * rng.randf_range(0.85, 1.1)),
		Vector3(0.0, radius * rng.randf_range(0.55, 0.75), radius * rng.randf_range(0.55, 0.75)),
		Vector3(h * 0.6, radius * rng.randf_range(0.85, 1.1), radius * rng.randf_range(0.85, 1.1)),
		Vector3(h, radius * 0.15, radius * 0.15),
	], 6)


## Broken housing rather than a clean box: hardware that came off in a piece,
## not off a workbench.
static func hardware_shard(size: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var h := size * 0.5
	return revolve([
		Vector3(-h, size * 0.42, size * 0.30),
		Vector3(-h * 0.4, size * 0.5, size * 0.36),
		Vector3(h * 0.3, size * rng.randf_range(0.30, 0.46), size * 0.26),
		Vector3(h, size * 0.1, size * 0.08),
	], 5)


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
