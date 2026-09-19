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

## AN6.5. Authored silhouettes by the thing that made the opening. These are
## aspect ratios rather than replacement meshes: the wound still keeps its
## exact impact point, depth, layer and deterministic torn rim, while a blade
## leaves a slash and a round leaves a compact entry. Impact angle adds to this
## profile below instead of selecting a second canned wound.
const TYPE_ASPECT := {
	"ballistic": 1.0,
	"puncture": 1.18,
	"cut": 2.35,
	"shear": 1.75,
	"blunt": 1.25,
}
const GRAZE_STRETCH := {
	"ballistic": 0.85,
	"puncture": 1.05,
	"cut": 1.25,
	"shear": 1.10,
	"blunt": 0.45,
}


## One wound, as data. `at` and `normal` are in the limb's own local space, so
## the mark rides the limb through every animation and leaves with it when it
## comes off — which is the whole reason to store it there rather than in world
## space and chase it every frame.
static func make(at: Vector3, normal: Vector3, damage: float, damage_type: String, layer: int, travel: Vector3 = Vector3.ZERO) -> Dictionary:
	var spread: float = float(LAYER_SPREAD.get(layer, 0.04))
	# Bigger hits open bigger holes, but sub-linearly: a 90-damage slug does not
	# leave a hole three times the width of a 30-damage one, it leaves a deeper
	# one, and past a point it takes the limb off instead.
	var scale := clampf(sqrt(damage / 40.0), 0.45, 2.1)
	if damage_type in TEARING:
		scale *= 1.35
	var shape := _impact_shape(normal, travel, damage_type)
	return {
		"at": at,
		"normal": normal,
		"radius": spread * scale,
		"layer": layer,
		"damage": damage,
		"type": damage_type,
		"aspect": shape.aspect,
		"shape_rotation": shape.rotation,
		# Overwritten by `_record_wound` with `Penetration`'s own fraction once a
		# round has actually crossed tissue. Left at 1.0 here so a caller with no
		# penetration model (a punch, a claw) still gets the old full-depth crater
		# rather than a mysteriously shallow one.
		"depth": 1.0,
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


## --- scars a save file can hold ------------------------------------------
##
## B10.2 wants the body to carry its scars across a restart, and a restart goes
## out through a JSON file. JSON has no Vector3. `JSON.stringify` does not fail
## on one, which is the trap — it writes the *string* `"(0.1, 0.2, 0.3)"`, and
## parsing hands that string straight back. A wound whose `at` is a string is
## not a place on a limb any more: `to_local` arithmetic on it is meaningless
## and `WoundMarks.build` would put every crater at the origin.
##
## So positions leave as three plain numbers and come back as a position.
## `from_record` also accepts a Vector3 unchanged, because the same pair is used
## for the in-memory hand-off where nothing has been through a file.
static func to_record(wound: Dictionary) -> Dictionary:
	var out := wound.duplicate(true)
	out["at"] = _triple(wound.get("at", Vector3.ZERO))
	out["normal"] = _triple(wound.get("normal", Vector3.UP))
	return out


static func from_record(record_data: Dictionary) -> Dictionary:
	var out := record_data.duplicate(true)
	out["at"] = _vector(record_data.get("at", Vector3.ZERO), Vector3.ZERO)
	out["normal"] = _vector(record_data.get("normal", Vector3.UP), Vector3.UP)
	# JSON has no integers either — every number comes back a float, and `seed`
	# is fed to `RandomNumberGenerator.seed` and `layer` indexes a tint table.
	# A crater generated from a float seed is a differently-shaped crater, which
	# would mean a scar that changes shape every time it is saved.
	out["seed"] = int(record_data.get("seed", 0))
	out["layer"] = int(record_data.get("layer", 0))
	out["radius"] = float(record_data.get("radius", 0.04))
	out["damage"] = float(record_data.get("damage", 0.0))
	out["depth"] = float(record_data.get("depth", 1.0))
	out["aspect"] = maxf(1.0, float(record_data.get("aspect", 1.0)))
	out["shape_rotation"] = float(record_data.get("shape_rotation", 0.0))
	return out


## The whole per-zone table, in and out. Zones are filtered on the way back in
## rather than trusted: a save is a file on someone's disk, and a key that is
## not a limb would put wounds on a body part that does not exist.
static func to_records(marks: Dictionary) -> Dictionary:
	var out := {}
	for zone: String in marks.keys():
		var list: Array = []
		for wound in marks[zone]:
			if wound is Dictionary:
				list.append(to_record(wound as Dictionary))
		if not list.is_empty():
			out[zone] = list
	return out


static func from_records(saved: Variant, allowed: Array = []) -> Dictionary:
	var out := {}
	if not saved is Dictionary:
		return out
	for zone_key in (saved as Dictionary):
		var zone := str(zone_key)
		if not allowed.is_empty() and not allowed.has(zone):
			continue
		var stored: Variant = (saved as Dictionary)[zone_key]
		if not stored is Array:
			continue
		var list: Array = []
		for wound in (stored as Array):
			if wound is Dictionary:
				list.append(from_record(wound as Dictionary))
			if list.size() >= MAX_PER_ZONE:
				break
		if not list.is_empty():
			out[zone] = list
	return out


static func _triple(value: Variant) -> Array:
	if value is Vector3:
		var vector: Vector3 = value
		return [vector.x, vector.y, vector.z]
	if value is Array and (value as Array).size() >= 3:
		var stored: Array = value
		return [float(stored[0]), float(stored[1]), float(stored[2])]
	return [0.0, 0.0, 0.0]


static func _vector(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		var stored: Array = value
		return Vector3(float(stored[0]), float(stored[1]), float(stored[2]))
	return fallback


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
static func build(wound: Dictionary, tint: Color, cavity_contents: Mesh = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var radius: float = float(wound.get("radius", 0.04))
	var depth_fraction: float = clampf(float(wound.get("depth", 1.0)), 0.0, 1.0)
	var aspect: float = maxf(1.0, float(wound.get("aspect", 1.0)))
	node.mesh = _crater(radius, int(wound.get("seed", 0)), tint, str(wound.get("type", "ballistic")), depth_fraction, aspect, cavity_contents != null)

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
	# Body first, cavity void next, organ after it, torn tunnel last. Explicit
	# priorities make that authored stack stable even though the two inner meshes
	# deliberately ignore the intact body's depth.
	material.render_priority = 3
	node.material_override = material
	if cavity_contents != null:
		_add_cavity_contents(node, cavity_contents, radius, depth_fraction, aspect)

	var at: Vector3 = wound.get("at", Vector3.ZERO)
	var normal: Vector3 = wound.get("normal", Vector3.UP)
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	normal = normal.normalized()
	# Sunk very slightly into the surface, so the rim sits in the skin rather
	# than standing on it.
	node.position = at - normal * radius * 0.10
	node.basis = _basis_facing(normal) * Basis(Vector3.UP, float(wound.get("shape_rotation", 0.0)))
	return node


## The thing seen through a deep opening is not another painted layer. It is a
## view of the same organ mesh the body carries internally, fitted behind the
## irregular inner rim. `no_depth_test` is narrowly safe here because the copy
## is smaller than that rim; the opaque procedural body surface would otherwise
## cover it even though the authored wound geometry has opened a window.
static func _add_cavity_contents(wound_node: MeshInstance3D, source: Mesh, radius: float, depth_fraction: float, aspect: float) -> void:
	var sink := lerpf(0.25, 1.0, clampf(depth_fraction, 0.0, 1.0))
	# Cover the uncut procedural limb surface behind the authored aperture. This
	# is the dark space around an organ, not the contents themselves; without it
	# the untouched skin mesh reads as a flesh-coloured floor behind the hole.
	var cavity_void := MeshInstance3D.new()
	cavity_void.name = "CavityVoid"
	var void_mesh := SphereMesh.new()
	# Oversized behind the tunnel; the higher-priority ragged wall masks it back
	# to the irregular inner ring without asking the intact body mesh for a hole.
	void_mesh.radius = radius * 0.82
	void_mesh.height = radius * 1.64
	cavity_void.mesh = void_mesh
	cavity_void.position = Vector3(0.0, -radius * 0.94 * sink, 0.0)
	cavity_void.scale = Vector3(sqrt(maxf(1.0, aspect)), 0.08, 1.0 / sqrt(maxf(1.0, aspect)))
	var void_material := StandardMaterial3D.new()
	void_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_material.albedo_color = WOUND_BLOOD.darkened(0.82)
	void_material.no_depth_test = true
	void_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	void_material.render_priority = 1
	cavity_void.material_override = void_material
	wound_node.add_child(cavity_void)

	var contents := MeshInstance3D.new()
	contents.name = "CavityContents"
	contents.mesh = source.duplicate(true)
	var bounds := contents.mesh.get_aabb().size
	var source_span := maxf(bounds.x, maxf(bounds.y, bounds.z))
	var fit := radius * 1.02 / maxf(source_span, 0.001)
	contents.scale = Vector3.ONE * fit
	contents.position = Vector3(radius * 0.04, -radius * 0.96 * sink, 0.0)
	# A long cut reveals a correspondingly narrow strip of what is behind it.
	contents.scale.z /= sqrt(maxf(1.0, aspect))
	var material := _mesh_material(source)
	if material != null:
		material.no_depth_test = true
		material.render_priority = 2
		contents.material_override = material
	contents.set_meta("source_mesh", source)
	wound_node.add_child(contents)


static func _mesh_material(source: Mesh) -> StandardMaterial3D:
	if source.get_surface_count() <= 0:
		return null
	var original := source.surface_get_material(0) as StandardMaterial3D
	return original.duplicate(true) as StandardMaterial3D if original != null else null


## The crater itself. A fan from a sunk centre out to a ragged rim, plus a lip
## ring outside it for the tissue pushed up around the hole.
##
## `depth_fraction` is `Penetration`'s own fraction for this wound — 0 at the
## surface, 1 out the other side. AN6.1: a wound is an opening with depth, not
## a decal, which means the depth has to answer to the same number that
## decided whether the round stopped inside or went through. Without this the
## crater's sink was a constant multiple of its radius, so a graze that barely
## broke the skin and a round that blew through the far side read as the same
## hole with a different rim width — a wider decal, not a deeper one.
static func _crater(radius: float, seed_value: int, tint: Color, damage_type: String, depth_fraction: float = 1.0, aspect: float = 1.0, open_cavity: bool = false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Tearing damage is more irregular than a punch, so it gets a rougher rim and
	# fewer, longer tears rather than a uniformly wobbly circle.
	var tearing := damage_type in TEARING
	var segments := 11 if tearing else 14
	var jitter := 0.42 if tearing else 0.22
	# A graze still has to read as an opening rather than a flat paint mark, so
	# the floor is not zero — but it is well below a wound that actually went
	# somewhere, which is the whole point of tying this to the fraction at all.
	var sink := lerpf(0.25, 1.0, clampf(depth_fraction, 0.0, 1.0))
	var depth := radius * (0.75 if tearing else 0.95) * sink

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
	var inner_start := lip_start + segments
	# Preserve roughly the same opening area while changing its silhouette. A
	# slash should not gain damage merely because its authored profile is long.
	var long_axis := sqrt(maxf(1.0, aspect))
	var short_axis := 1.0 / long_axis
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		# Two octaves of wobble, so the outline is not a smooth ellipse.
		var wobble := 1.0 + (rng.randf() - 0.5) * jitter + sin(angle * 3.0 + float(seed_value % 17)) * jitter * 0.35
		var r := radius * clampf(wobble, 0.45, 1.6)
		vertices.append(Vector3(cos(angle) * r * long_axis, 0.0, sin(angle) * r * short_axis))
		colors.append(rim_colour)
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var wobble := 1.0 + (rng.randf() - 0.5) * jitter * 1.4
		var r := radius * 1.16 * clampf(wobble, 0.5, 1.7)
		# The lip stands slightly proud — tissue pushed out of the way rather
		# than a flat ring painted around the hole.
		vertices.append(Vector3(cos(angle) * r * long_axis, radius * 0.045, sin(angle) * r * short_axis))
		colors.append(lip_colour)
	if open_cavity:
		for index in segments:
			var angle := TAU * float(index) / float(segments)
			var r := radius * 0.44
			vertices.append(Vector3(cos(angle) * r * long_axis, -depth, sin(angle) * r * short_axis))
			colors.append(deep)

	for index in segments:
		var next := (index + 1) % segments
		if open_cavity:
			# Tunnel: the inner ring is deliberately unfilled. The organ mesh behind
			# it is what closes the view, so this remains a hole rather than a cone
			# whose floor merely changed colour.
			indices.append(inner_start + index)
			indices.append(rim_start + next)
			indices.append(rim_start + index)
			indices.append(inner_start + index)
			indices.append(inner_start + next)
			indices.append(rim_start + next)
		else:
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


## The strike's tangent is stored as one rotation around the surface normal, so
## the authored ellipse follows the blade/round rather than a global axis. A
## perpendicular hit has no tangent and therefore keeps the weapon profile's
## deterministic default orientation; a grazing hit stretches progressively.
static func _impact_shape(normal: Vector3, travel: Vector3, damage_type: String) -> Dictionary:
	var safe_normal := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var base_aspect := float(TYPE_ASPECT.get(damage_type, 1.0))
	if travel.length_squared() <= 0.0001:
		return {"aspect": base_aspect, "rotation": 0.0}
	var direction := travel.normalized()
	var alignment := clampf(absf(direction.dot(safe_normal)), 0.0, 1.0)
	var grazing := 1.0 - alignment
	var tangent := direction - safe_normal * direction.dot(safe_normal)
	var rotation := 0.0
	if tangent.length_squared() > 0.0001:
		tangent = tangent.normalized()
		var facing := _basis_facing(safe_normal)
		rotation = atan2(tangent.dot(facing.z), tangent.dot(facing.x))
	return {
		"aspect": base_aspect + grazing * float(GRAZE_STRETCH.get(damage_type, 0.65)),
		"rotation": rotation,
	}


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
