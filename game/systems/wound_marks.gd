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


## The mesh for one wound: a shallow disc, slightly domed, laid against the limb
## surface. Not a decal projector — this game builds its own geometry everywhere
## else and a projector would be one more renderer feature to explain, and would
## not follow a limb that has been thrown across the room.
static func build(wound: Dictionary, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var radius: float = float(wound.get("radius", 0.04))
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	# Tapered, so the rim sits into the skin instead of standing on it as a
	# cylinder with a visible side wall.
	disc.bottom_radius = radius * 1.22
	disc.height = radius * 0.36
	disc.radial_segments = 8
	disc.rings = 1
	node.mesh = disc

	var material := StandardMaterial3D.new()
	# The layer tint alone is wrong, and the first render proved it: `LAYER_TINTS`
	# are the colours of *tissue in section*, which is what a chunk flying
	# through the air should be, and on a body they came out as pale yellow and
	# pink discs that read as buttons sewn to the skin. A wound is not the colour
	# of what is under the skin — it is the colour of what is under the skin with
	# blood in it and shadow around it. So the tint is pulled most of the way to
	# blood and darkened hard.
	material.albedo_color = tint.lerp(WOUND_BLOOD, 0.62).darkened(0.34)
	# Wet. Blood and opened tissue are the shiniest things on a body, and a matte
	# wound reads as paint.
	material.roughness = 0.26
	material.metallic = 0.0
	# Pushed toward the viewer so it never z-fights with the limb it sits on,
	# which at these thicknesses it otherwise always will.
	material.render_priority = 1
	# A hole should not catch a highlight the way a bead does, so the specular
	# contribution is dialled down rather than switched off — wet tissue still
	# has a sheen, it just is not chrome.
	material.metallic_specular = 0.22
	node.material_override = material

	var at: Vector3 = wound.get("at", Vector3.ZERO)
	var normal: Vector3 = wound.get("normal", Vector3.UP)
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	normal = normal.normalized()
	# Sunk very slightly into the surface, so the disc reads as a hole in the
	# limb rather than a coin stuck to it.
	node.position = at - normal * radius * 0.18
	node.basis = _basis_facing(normal)
	# Rolled per wound, so a row of hits is not a row of identical stamps.
	node.rotate_object_local(Vector3.UP, float(int(wound.get("seed", 0)) % 360) * 0.0174533)
	return node


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
