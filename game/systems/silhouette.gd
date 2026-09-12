class_name Silhouette
extends RefCounted

## G4. Why the world still reads as boxes after a texture pass.
##
## Greg has said it three times in three sessions, and it kept getting answered
## with surfaces: contamination on the albedo, fog pulled back, a material
## system routed through the generator. All of that was worth doing and none of
## it addressed the complaint, because **a texture does not change an outline**.
## A box with brilliant grime on it is a box. What reads at distance, in fog, in
## silhouette against a sky, is the shape of the edge — and every edge in this
## region was a perfect ninety-degree corner on a perfectly plumb wall.
##
## Three things fix that and all three are cheap, because they are attachments
## and transforms rather than new geometry:
##
##   G4.1  a broken corner, so no edge runs uninterrupted to the top
##   G4.2  greebles — pipe, bracket, vent, aerial, tarp — so the outline is busy
##   G4.3  lean and settle, so nothing is plumb and nothing is level
##
## Everything is deterministic from a seed: the same building is broken in the
## same way every time the region generates, because the districts are supposed
## to be a place rather than a fresh roll.

const GREEBLE_TINTS := ["3a2f26", "463526", "2c3028", "55442e", "38403a"]


## G4.3. A building that has been standing in a poisoned wind for decades is not
## plumb. Small angles — anything past about four degrees stops reading as
## settling and starts reading as a bug.
static func settle(node: Node3D, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7717 + 3
	node.rotation.x += deg_to_rad(rng.randf_range(-2.4, 2.4))
	node.rotation.z += deg_to_rad(rng.randf_range(-3.1, 3.1))
	node.rotation.y += deg_to_rad(rng.randf_range(-6.0, 6.0))
	# Sunk at one corner rather than floating.
	node.position.y -= rng.randf_range(0.0, 0.22)


## G4.1 and G4.2. Hangs junk off a shell: pipes down a wall, brackets, a vent
## box, an aerial, a sagging tarp, and a bite taken out of one top corner so the
## roofline is never a clean rectangle.
##
## `surface` is a Callable taking (Color, String, int) and returning a material,
## so this does not need to know about WorldLook and can be tested without it.
static func dress(parent: Node3D, dimensions: Vector3, seed_value: int, surface: Callable) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729 + 17
	var added := 0
	var half_x := dimensions.x * 0.5
	var half_z := dimensions.z * 0.5

	# --- G4.1: a broken corner ------------------------------------------
	# A wedge cut from one top corner. Drawn as a dark block sitting slightly
	# proud of the wall, which reads as missing masonry rather than as a lump,
	# because it breaks the roofline where the eye follows it.
	var corner := Vector3(
		half_x * (1.0 if rng.randf() > 0.5 else -1.0),
		dimensions.y - rng.randf_range(0.2, 0.7),
		half_z * (1.0 if rng.randf() > 0.5 else -1.0)
	)
	var bite := _block(parent, corner, Vector3(rng.randf_range(1.4, 3.0), rng.randf_range(1.0, 2.2), rng.randf_range(1.4, 3.0)), Color("1b1512"), "rust", rng.randi(), surface)
	bite.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.4))
	added += 1

	# --- G4.2: greebles --------------------------------------------------
	# Vertical pipes down one face. These do most of the work: a run of thin
	# verticals against a flat wall is what stops it reading as a single plane.
	# Every face, not one. A building dressed on two sides is a facade, and the
	# player walks round it.
	for face in 4:
		var outward: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][face]
		var reach: float = half_z if face < 2 else half_x
		var span: float = half_x if face < 2 else half_z
		for pipe in rng.randi_range(2, 4):
			var along := rng.randf_range(-0.85, 0.85) * span
			var height := dimensions.y * rng.randf_range(0.55, 1.05)
			var thickness := rng.randf_range(0.22, 0.42)
			var at: Vector3 = outward * (reach + thickness * 0.5)
			if face < 2:
				at.x = along
			else:
				at.z = along
			at.y = height * 0.5
			var pipe_node := _block(parent, at, Vector3(thickness, height, thickness), Color(GREEBLE_TINTS[rng.randi() % GREEBLE_TINTS.size()]), "rust", rng.randi(), surface)
			pipe_node.rotation.z = rng.randf_range(-0.07, 0.07)
			added += 1
		# A bracket or an awning jutting out, which is what actually breaks the
		# vertical edge when you are standing next to the thing.
		if rng.randf() > 0.35:
			var jut := rng.randf_range(0.6, 1.5)
			var at_j: Vector3 = outward * (reach + jut * 0.5)
			if face < 2:
				at_j.x = rng.randf_range(-0.6, 0.6) * span
			else:
				at_j.z = rng.randf_range(-0.6, 0.6) * span
			at_j.y = dimensions.y * rng.randf_range(0.4, 0.85)
			var awning := _block(parent, at_j, Vector3(rng.randf_range(1.0, 2.4), 0.18, jut) if face < 2 else Vector3(jut, 0.18, rng.randf_range(1.0, 2.4)), Color(GREEBLE_TINTS[rng.randi() % GREEBLE_TINTS.size()]), "rust", rng.randi(), surface)
			awning.rotation.x = rng.randf_range(-0.22, 0.06)
			added += 1

	# A vent box or two, proud of the wall.
	for vent in rng.randi_range(1, 3):
		var side := rng.randf() > 0.5
		var at_v := Vector3(rng.randf_range(-0.7, 0.7) * half_x, dimensions.y * rng.randf_range(0.35, 0.8), half_z + 0.22) if side else Vector3(half_x + 0.22, dimensions.y * rng.randf_range(0.35, 0.8), rng.randf_range(-0.7, 0.7) * half_z)
		_block(parent, at_v, Vector3(rng.randf_range(0.5, 1.1), rng.randf_range(0.4, 0.8), 0.4), Color(GREEBLE_TINTS[rng.randi() % GREEBLE_TINTS.size()]), "chrome", rng.randi(), surface)
		added += 1

	# Roof clutter: a tank, a stub chimney, an aerial. The roofline is what you
	# see from anywhere in the district, so it gets the most attention.
	for lump in rng.randi_range(2, 5):
		var at_r := Vector3(rng.randf_range(-0.6, 0.6) * half_x, dimensions.y + rng.randf_range(0.2, 0.6), rng.randf_range(-0.6, 0.6) * half_z)
		var lump_node := _block(parent, at_r, Vector3(rng.randf_range(0.9, 2.6), rng.randf_range(0.8, 2.4), rng.randf_range(0.9, 2.6)), Color(GREEBLE_TINTS[rng.randi() % GREEBLE_TINTS.size()]), "rust", rng.randi(), surface)
		lump_node.rotation.y = rng.randf_range(0.0, TAU)
		added += 1
	if rng.randf() > 0.35:
		var mast_height := rng.randf_range(2.6, 6.5)
		var mast := _block(parent, Vector3(rng.randf_range(-0.5, 0.5) * half_x, dimensions.y + mast_height * 0.5, rng.randf_range(-0.5, 0.5) * half_z), Vector3(0.14, mast_height, 0.14), Color("2b2b28"), "chrome", rng.randi(), surface)
		mast.rotation.z = rng.randf_range(-0.16, 0.16)
		added += 1

	# A tarp or sheet, hung and sagging. A soft angled plane against all those
	# right angles is the cheapest thing that stops a wall looking machined.
	if rng.randf() > 0.4:
		var tarp := _block(parent, Vector3(rng.randf_range(-0.5, 0.5) * half_x, dimensions.y * rng.randf_range(0.4, 0.75), half_z + 0.3), Vector3(rng.randf_range(1.2, 2.6), rng.randf_range(1.0, 2.0), 0.06), Color("46402c"), "dirt", rng.randi(), surface)
		tarp.rotation = Vector3(rng.randf_range(-0.22, 0.0), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.3, 0.3))
		added += 1

	return added


## G2.1-G2.3. The derby cars are an authored shell (bonnet, cabin, engine,
## panels, rails per the glTF) but a clean shell at rest still reads as a
## kart, for the same reason G4 already diagnosed for buildings: a smooth
## surface reads as manufactured no matter what texture sits on it. This
## hangs the same kind of attachment kit the buildings get, tuned for a
## vehicle instead of a wall:
##
##   G2.1  exposed mechanism low and central, where a stripped car actually
##         bares its guts, not on the roofline
##   G2.2  bone struts lashed corner to corner like a repair that used
##         whatever was on hand, with a sinew strap crossing each one
##   G2.3  fungal bloom in the wheel wells (wet, shaded, never washed) and
##         dried spatter on the flanks from the last thing this car hit
##
## Parented to the chassis body itself, not the scaled authored shell, so
## `dimensions` and `wheel_positions` are real chassis-local metres and do
## not have to track whatever scale the shell mesh happens to render at.
## `wheel_positions` are the four suspension anchors the chassis already
## carries — passed in rather than hard-coded so this stays a generic kit,
## like `dress()` above.
##
## `include_spatter` defaults on but the derby turns it off for the AI
## wreckers specifically: `tests/derby_balance_test.tscn` measured that
## adding the dried-spatter patches to all twelve AI-driven cars reproducibly
## zeroed every hunter-player impact for the full 30s heat (0 impacts, hull
## unscratched) while the exact same patches on the player's own parked car,
## and every other piece of this kit on the wreckers, measured clean. No
## collision shape is involved anywhere in this kit, so the mechanism was not
## found — only the reproduction. Rather than ship a silent regression against
## the one system this project has already lost weeks to once, the feature is
## gated here until someone can chase the real cause.
static func dress_vehicle(parent: Node3D, dimensions: Vector3, wheel_positions: Array, seed_value: int, surface: Callable, include_spatter: bool = true) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 92821 + 41
	var added := 0
	var half_x := dimensions.x * 0.5
	var half_y := dimensions.y * 0.5
	var half_z := dimensions.z * 0.5

	# --- G2.1: exposed mechanism ------------------------------------------
	_block(parent, Vector3(0.0, -half_y * 0.15, -half_z * 0.55), Vector3(half_x * 0.85, dimensions.y * 0.42, dimensions.z * 0.3), Color("242424"), "chrome", rng.randi(), surface)
	added += 1
	for rib in rng.randi_range(3, 5):
		var along := lerpf(-half_z * 0.7, half_z * 0.75, float(rib) / 4.0)
		var pipe := _block(parent, Vector3(0.0, -half_y * 0.55, along), Vector3(0.14, 0.14, 0.5), Color("352a20"), "rust", rng.randi(), surface)
		pipe.rotation.x = PI * 0.5
		added += 1
	# A ragged sill standing in for the door skin that has been cut away.
	for side in [-1.0, 1.0]:
		_block(parent, Vector3(side * half_x * 0.95, -half_y * 0.2, 0.0), Vector3(0.14, half_y * 0.5, dimensions.z * 0.55), Color("241f1a"), "rust", rng.randi(), surface)
		added += 1

	# --- G2.2: bone and sinew lashings -------------------------------------
	# Corner to corner, because that is where a lashing actually has to run
	# to hold a cracked panel down rather than sitting on it as ornament.
	for lash in rng.randi_range(2, 4):
		var from_corner := Vector3(half_x * (1.0 if lash % 2 == 0 else -1.0), half_y * 0.35, half_z * rng.randf_range(-0.9, 0.6))
		var to_corner := Vector3(half_x * (-1.0 if lash % 2 == 0 else 1.0), half_y * 0.45, half_z * rng.randf_range(-0.5, 0.9))
		var direction := to_corner - from_corner
		var span := direction.length()
		if span < 0.2:
			continue
		var mid := (from_corner + to_corner) * 0.5
		var bone := _block(parent, mid, Vector3(span, 0.14, 0.14), Color("c8bc94"), "bone", rng.randi(), surface)
		_orient_x(bone, direction / span)
		added += 1
		# The sinew: a darker, thinner strap crossing the bone at an angle,
		# standing in for the actual lashing holding it down.
		var sinew := _block(parent, mid + Vector3(0, 0.05, 0), Vector3(span * 0.88, 0.05, 0.22), Color("3a1410"), "flesh", rng.randi(), surface)
		_orient_x(sinew, direction / span)
		sinew.rotate_object_local(Vector3.RIGHT, deg_to_rad(14.0))
		added += 1

	# --- G2.3: fungal bloom in the wheel wells, dried spatter -------------
	for wheel_position in wheel_positions:
		var well: Vector3 = wheel_position
		for lump in rng.randi_range(2, 3):
			_sphere(parent, well + Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(0.05, 0.28), rng.randf_range(-0.22, 0.22)), 0.08 + rng.randf() * 0.09, Color("5a7a2c"), "dirt", rng.randi(), surface)
			added += 1
	# Dried spatter: flattened blotches on the flanks, as if something hit
	# the panel and dried there rather than being painted on. See the
	# docstring above — gated off the AI wreckers pending a real diagnosis.
	if include_spatter:
		for spatter in rng.randi_range(4, 7):
			var side_sign := 1.0 if rng.randf() > 0.5 else -1.0
			var at := Vector3(side_sign * half_x * rng.randf_range(0.85, 1.0), rng.randf_range(-half_y * 0.4, half_y * 0.6), rng.randf_range(-half_z * 0.8, half_z * 0.8))
			var patch := _block(parent, at, Vector3(0.03, rng.randf_range(0.18, 0.4), rng.randf_range(0.14, 0.3)), Color("400e0a"), "flesh", rng.randi(), surface)
			patch.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2))
			added += 1

	return added


## Aligns a mesh's local +X axis (the long axis of a BoxMesh) onto a world
## direction without going through Euler angles, which fall over whenever
## the direction points anywhere near straight up.
static func _orient_x(node: Node3D, x_axis: Vector3) -> void:
	var up_reference := Vector3.UP
	if absf(x_axis.dot(up_reference)) > 0.98:
		up_reference = Vector3.FORWARD
	var z_axis := x_axis.cross(up_reference).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	node.transform.basis = Basis(x_axis, y_axis, z_axis)


static func _sphere(parent: Node3D, at: Vector3, radius: float, tint: Color, kind: String, seed_value: int, surface: Callable) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 5
	if surface.is_valid():
		sphere.material = surface.call(tint, kind, seed_value)
	mesh_instance.mesh = sphere
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance


static func _block(parent: Node3D, at: Vector3, size: Vector3, tint: Color, kind: String, seed_value: int, surface: Callable) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	if surface.is_valid():
		box.material = surface.call(tint, kind, seed_value)
	mesh_instance.mesh = box
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance
