class_name WoundMarks
extends RefCounted

## Greg: *"i want you to begin working on the body and skin models taking wound
## damage from the guns rig the bodys to have detailled gruesome body wounds
## with the attached gore"*.
##
## The body already knew it had been shot. What it did not know was *where*.
##
## `hit_at()` receives the exact world point a round struck, converts it to a
## zone name, and throws the point away. Everything downstream then works in
## zones, so `_update_layer_exposure()` could only ever put one box per limb, at
## a hardcoded local offset, showing the deepest layer that limb had been opened
## to. Shoot a thigh six times in six places and you got the same single flap in
## the same spot — which is why the bodies read as taking damage without ever
## looking damaged.
##
## So the point is kept. Each wound is a real position and a real inward
## direction on the limb it landed on, and what is drawn is drawn there.
##
## Kept as plain data plus static builders rather than as a node, for the same
## reason `GoreChunks` is: the rig already owns the meshes and the lifetime, and
## a second node tree that has to be kept in step with the limbs is a second
## thing that can fall out of step with them.

## Per-limb cap. Past this the oldest is replaced, so emptying a magazine into
## one leg degrades the leg rather than the frame rate.
const MAX_PER_ZONE := 14
## Below this much damage nothing is marked. A graze that does two points should
## not leave the same hole a slug does, and marking everything makes the marks
## mean nothing.
const MIN_DAMAGE := 3.0

## How wide a wound reads, by the layer it opened to. A ballistic entry is small
## and deep; a shear that took the muscle off is wide and shallow.
const LAYER_SPREAD := {
	0: 0.030,  # skin
	1: 0.042,  # fat
	2: 0.055,  # muscle
	3: 0.048,  # bone
	4: 0.070,  # organ
	5: 0.052,  # cybernetic
}

## What wounds are actually the colour of. `GoreChunks.LAYER_TINTS` describes
## tissue in section — correct for a chunk in the air, far too pale on a body.
const WOUND_BLOOD := Color(0.28, 0.032, 0.028)
## Damage types that tear rather than punch, and so leave a wider, more ragged
## opening at the same damage.
const TEARING := ["shear", "cut", "blunt"]
## How much wider an exit is than its entry. A round that has crossed a body is
## tumbling and carrying tissue with it, which is why an exit is the wound people
## recognise — and why making it the same hole on the other side would be the one
## detail that gives the whole system away.
const EXIT_SPREAD := 1.85


## One wound, as data. `at` and `normal` are in the limb's own local space, so
## the mark rides the limb through every animation and leaves with it when it
## comes off — which is the whole reason to store it there rather than in world
## space and chase it every frame.
static func make(at: Vector3, normal: Vector3, damage: float, damage_type: String, layer: int) -> Dictionary:
	var spread: float = float(LAYER_SPREAD.get(layer, 0.04))
	# Bigger hits open bigger holes, but sub-linearly: a 90-damage slug does not
	# leave a hole three times the width of a 30-damage one, it leaves a deeper
	# one, and past a point it takes the limb off instead.
	var scale := clampf(sqrt(damage / 40.0), 0.45, 2.1)
	if damage_type in TEARING:
		scale *= 1.35
	return {
		"at": at,
		"normal": normal,
		"radius": spread * scale,
		"layer": layer,
		"damage": damage,
		"type": damage_type,
		# Deterministic per wound so a given hole looks the same every frame
		# rather than crawling.
		"seed": randi(),
	}


## Add a wound to a zone's list, replacing the oldest once the cap is reached.
## Returns the list, so the caller can write it straight back.
static func record(existing: Array, wound: Dictionary) -> Array:
	existing.append(wound)
	while existing.size() > MAX_PER_ZONE:
		existing.remove_at(0)
	return existing


## The mesh for one wound: a torn crater, generated per wound.
##
## The first version was a `CylinderMesh` — a clean disc — and rendering it made
## the problem obvious immediately: nine identical circles down a torso read as
## buttons sewn onto the skin, not as holes shot through it. Roundness was doing
## the damage. A real opening is irregular at the rim, sunk in the middle, and
## no two are the same shape.
##
## So the rim radius is jittered per vertex from the wound's own seed, the centre
## is pushed *into* the limb, and the colour runs dark at the middle out to torn
## tissue at the edge as vertex colour, which costs nothing and does the work an
## extra texture would.
static func build(wound: Dictionary, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var radius: float = float(wound.get("radius", 0.04))
	node.mesh = _crater(radius, int(wound.get("seed", 0)), tint, str(wound.get("type", "ballistic")))

	var material := StandardMaterial3D.new()
	# The shape carries the colour now, so the material just lets it through.
	material.vertex_color_use_as_albedo = true
	# Wet. Blood and opened tissue are the shiniest things on a body, and a matte
	# wound reads as paint.
	material.roughness = 0.24
	material.metallic = 0.0
	# A hole has no back face worth culling to, and a torn rim is legible from
	# behind when a limb turns.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	node.material_override = material

	var at: Vector3 = wound.get("at", Vector3.ZERO)
	var normal: Vector3 = wound.get("normal", Vector3.UP)
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	normal = normal.normalized()
	# Sunk very slightly into the surface, so the rim sits in the skin rather
	# than standing on it.
	node.position = at - normal * radius * 0.10
	node.basis = _basis_facing(normal)
	return node


## The crater itself. A fan from a sunk centre out to a ragged rim, plus a lip
## ring outside it for the tissue pushed up around the hole.
static func _crater(radius: float, seed_value: int, tint: Color, damage_type: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Tearing damage is more irregular than a punch, so it gets a rougher rim and
	# fewer, longer tears rather than a uniformly wobbly circle.
	var tearing := damage_type in TEARING
	var segments := 11 if tearing else 14
	var jitter := 0.42 if tearing else 0.22
	var depth := radius * (0.75 if tearing else 0.95)

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# Pull the layer tint toward blood before anything else derives from it.
	# `GoreChunks.LAYER_TINTS` is the colour of tissue *in section* — right for a
	# chunk in the air, and on a body the skin and fat tints are pale cream, so
	# the craters came out as white blobs that read as growths rather than holes.
	# This blend was in the disc version and was lost when the geometry was
	# replaced; losing it undid the whole reason the discs had started to work.
	# 0.88, not 0.66. The layer tints are *pale* — skin and fat are near-cream —
	# so a two-thirds blend still lands on mid-brown, and mid-brown under a key
	# light renders as tan, which is roughly the colour of the skin it is
	# supposed to be a hole in. The tint is a hint about which layer was opened,
	# not the colour of the wound; blood is the colour of the wound.
	var wet: Color = tint.lerp(WOUND_BLOOD, 0.88).darkened(0.42)
	# Middle of the hole: darkest, and below the surface.
	var deep := wet.darkened(0.55)
	var rim_colour := wet.lightened(0.08)
	var lip_colour := wet.lerp(WOUND_BLOOD, 0.5).darkened(0.10)

	vertices.append(Vector3(0.0, -depth, 0.0))
	colors.append(deep)

	var rim_start := vertices.size()
	var lip_start := rim_start + segments
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		# Two octaves of wobble, so the outline is not a smooth ellipse.
		var wobble := 1.0 + (rng.randf() - 0.5) * jitter + sin(angle * 3.0 + float(seed_value % 17)) * jitter * 0.35
		var r := radius * clampf(wobble, 0.45, 1.6)
		vertices.append(Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		colors.append(rim_colour)
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var wobble := 1.0 + (rng.randf() - 0.5) * jitter * 1.4
		var r := radius * 1.16 * clampf(wobble, 0.5, 1.7)
		# The lip stands slightly proud — tissue pushed out of the way rather
		# than a flat ring painted around the hole.
		vertices.append(Vector3(cos(angle) * r, radius * 0.045, sin(angle) * r))
		colors.append(lip_colour)

	for index in segments:
		var next := (index + 1) % segments
		# Fan: centre to rim.
		indices.append(0)
		indices.append(rim_start + next)
		indices.append(rim_start + index)
		# Skirt: rim out to lip.
		indices.append(rim_start + index)
		indices.append(rim_start + next)
		indices.append(lip_start + index)
		indices.append(rim_start + next)
		indices.append(lip_start + next)
		indices.append(lip_start + index)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A cylinder's length runs down its local Y, so the wound faces `normal` when
## local Y is turned onto it.
static func _basis_facing(normal: Vector3) -> Basis:
	var up := normal
	var reference := Vector3.FORWARD
	if absf(up.dot(reference)) > 0.98:
		reference = Vector3.RIGHT
	var right := reference.cross(up).normalized()
	var forward := up.cross(right).normalized()
	return Basis(right, up, forward)


## Where the round actually met the limb, and which way it went in.
##
## The caller has a world point that came off a raycast, which is on or near the
## limb's surface but not exactly on it, and a travel direction. Both are
## converted into the limb's own space here rather than at four call sites.
static func surface_of(part: Node3D, global_point: Vector3, travel: Vector3) -> Dictionary:
	var local := part.to_local(global_point)
	var inward := travel
	if inward.length_squared() < 0.0001:
		# No direction given — a hit with no travel is a contact, so treat the
		# surface as facing away from the limb's own axis.
		inward = -(local.normalized() if local.length_squared() > 0.0001 else Vector3.UP)
	else:
		inward = (part.global_transform.basis.inverse() * inward).normalized()
	return {"at": local, "normal": -inward}
