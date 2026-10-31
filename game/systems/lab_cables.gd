extends RefCounted

## The lab's cables (Greg, walkthrough: "intricate Lain / Evangelion wiring,
## not one long tube").
##
## Bundles, not a conduit: dozens of cables of different gauges sagging
## between ceiling hangers down the aisle, dropping in fistfuls into the top
## of every tank, a few heavy umbilicals swagged across overhead, and slack
## snaking over the floor from each tank to the wall. Mostly black and grey
## rubber, some rust-red and bone-white sheath, and a few thin lines that are
## lit, so the room reads as wired rather than piped.
##
## Scenery only: no colliders, and every cable is merged into one mesh per
## sheath colour, so hundreds of cables cost a handful of draw calls.

const RADIAL := 6
const SEGMENTS := 14

const SHEATHS := {
	"black": {"color": Color("1a1816"), "rough": 0.35},
	"grey": {"color": Color("6a6b66"), "rough": 0.55},
	"rust": {"color": Color("7a1e12"), "rough": 0.5},
	"bone": {"color": Color("b0a484"), "rough": 0.7},
	"lit": {"color": Color("0c1512"), "rough": 0.4, "glow": Color("5fd0a0")},
}


## Builds the whole room's wiring under `host`. Returns counts for tests.
## `bays` are the aisle z positions, `tanks` the tank centres, `ceiling` the
## underside of the ceiling, `wall_x` the inside face of the side walls.
## `doors` are floor points no slack may run to (a doorway stays clear).
static func wire(host: Node3D, bays: Array, tanks: Array, ceiling: float, wall_x: float, seed_value: int, doors: Array = [], tank_top := 2.6, keep_clear := 1.6) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cables: Dictionary = {}
	for sheath in SHEATHS:
		cables[sheath] = []
	var count := 0
	# Ceiling runs: two bundles a side, hung from hangers at every bay and
	# sagging between them, each cable its own gauge and its own slack.
	for side in [-1.0, 1.0]:
		for bundle in 2:
			var bundle_x: float = side * (wall_x - 0.5 - float(bundle) * 1.6)
			var strands := rng.randi_range(7, 11)
			for strand in strands:
				var offset := Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.12, 0.08))
				var radius := _gauge(rng)
				var sheath := _sheath(rng)
				for index in bays.size() - 1:
					var a := Vector3(bundle_x + offset.x, ceiling - 0.12 + offset.y, float(bays[index]))
					var b := Vector3(bundle_x + offset.x, ceiling - 0.12 + offset.y, float(bays[index + 1]))
					(cables[sheath] as Array).append({"points": catenary(a, b, rng.randf_range(0.18, 0.75)), "radius": radius})
					count += 1
	# Drops into every tank: a fistful from the nearest ceiling bundle into
	# the lid, slack enough to belly out before they go in.
	for tank in tanks:
		var at: Vector3 = tank
		var side := signf(at.x) if absf(at.x) > 0.01 else 1.0
		var strands := rng.randi_range(4, 7)
		for strand in strands:
			var top := Vector3(side * (wall_x - 0.5 - rng.randf_range(0.0, 1.8)), ceiling - 0.1, at.z + rng.randf_range(-0.8, 0.8))
			var angle := rng.randf() * TAU
			var lid := at + Vector3(cos(angle) * rng.randf_range(0.1, 0.5), tank_top, sin(angle) * rng.randf_range(0.1, 0.5))
			(cables[_sheath(rng)] as Array).append({"points": catenary(top, lid, rng.randf_range(0.2, 0.6)), "radius": _gauge(rng)})
			count += 1
		# And slack over the floor, from the base to the wall.
		for strand in rng.randi_range(1, 3):
			var base := at + Vector3(side * -0.2 + rng.randf_range(-0.3, 0.3), 0.04, rng.randf_range(-0.6, 0.6))
			var wall := Vector3(side * (wall_x - 0.05), 0.04, at.z + rng.randf_range(-1.2, 1.2))
			if doors.any(func(door: Vector3) -> bool: return Vector2(door.x - wall.x, door.z - wall.z).length() < 2.0):
				continue
			(cables[_sheath(rng)] as Array).append({"points": floor_snake(base, wall, rng), "radius": _gauge(rng) * 1.2})
			count += 1
	# Heavy umbilicals swagged across the aisle, never low enough to meet a
	# head walking down the middle of it.
	for index in range(0, bays.size()):
		var z: float = float(bays[index]) + rng.randf_range(-1.2, 1.2)
		var a := Vector3(-wall_x + 0.4, ceiling - 0.1, z)
		var b := Vector3(wall_x - 0.4, ceiling - 0.1, z + rng.randf_range(-1.4, 1.4))
		var sag := minf(ceiling - 2.95, rng.randf_range(0.5, 1.2))
		for strand in rng.randi_range(2, 5):
			var nudge := Vector3(0, rng.randf_range(-0.05, 0.05), float(strand) * 0.13)
			var sheath := "rust" if strand == 0 else ("lit" if rng.randf() < 0.15 else ("grey" if strand % 2 else "black"))
			var strand_sag := minf(sag + rng.randf_range(-0.1, 0.1), ceiling - 0.1 + nudge.y - 2.95)
			(cables[sheath] as Array).append({"points": catenary(a + nudge, b + nudge, strand_sag), "radius": 0.04 + rng.randf() * 0.05})
			count += 1
	# Deep loops along both sides, the drooping hanks of the Wired: from one
	# hanger to the next, down to head height and back, clear of the aisle.
	for side in [-1.0, 1.0]:
		for index in bays.size() - 1:
			for loop in rng.randi_range(2, 4):
				var x: float = side * rng.randf_range(2.2, wall_x - 0.6)
				var a := Vector3(x, ceiling - 0.1, float(bays[index]) + rng.randf_range(-0.4, 0.4))
				var b := Vector3(x + rng.randf_range(-0.6, 0.6), ceiling - 0.1, float(bays[index + 1]) + rng.randf_range(-0.4, 0.4))
				(cables[_sheath(rng)] as Array).append({"points": catenary(a, b, rng.randf_range(1.0, 2.1)), "radius": _gauge(rng)})
				count += 1
	var meshes := 0
	for sheath in SHEATHS:
		var list: Array = cables[sheath]
		if list.is_empty():
			continue
		var node := MeshInstance3D.new()
		node.name = "Cables_%s" % sheath
		node.mesh = _tube_mesh(list)
		node.material_override = _material(sheath)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		host.add_child(node)
		meshes += 1
	return {"cables": count, "meshes": meshes, "lowest_over_aisle": _lowest_over_aisle(cables, keep_clear)}


## A hanging cable between two points: the straight line, dropped by `sag`
## at the middle in a parabola (close enough to a catenary at these spans).
static func catenary(a: Vector3, b: Vector3, sag: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for index in SEGMENTS + 1:
		var t := float(index) / float(SEGMENTS)
		points.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	return points


## Slack lying on the floor: wandering sideways, lifting where it crosses
## itself, flat at both ends.
static func floor_snake(a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> PackedVector3Array:
	var points := PackedVector3Array()
	var across := (b - a)
	across.y = 0.0
	var sideways := across.normalized().cross(Vector3.UP) if across.length_squared() > 0.0001 else Vector3.RIGHT
	var phase := rng.randf() * TAU
	var amount := rng.randf_range(0.15, 0.45)
	for index in SEGMENTS + 1:
		var t := float(index) / float(SEGMENTS)
		var wander := sin(t * 7.0 + phase) * amount * sin(t * PI)
		points.append(a.lerp(b, t) + sideways * wander + Vector3.UP * absf(sin(t * 11.0 + phase)) * 0.03)
	return points


static func _gauge(rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	if roll < 0.45:
		return rng.randf_range(0.014, 0.026)
	if roll < 0.85:
		return rng.randf_range(0.03, 0.05)
	return rng.randf_range(0.06, 0.1)


static func _sheath(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.4:
		return "black"
	if roll < 0.66:
		return "grey"
	if roll < 0.8:
		return "rust"
	if roll < 0.9:
		return "bone"
	return "lit"


static func _material(sheath: String) -> StandardMaterial3D:
	var spec: Dictionary = SHEATHS[sheath]
	var material := StandardMaterial3D.new()
	material.albedo_color = spec.color
	material.roughness = float(spec.rough)
	material.metallic = 0.0
	if spec.has("glow"):
		material.emission_enabled = true
		material.emission = spec.glow
		material.emission_energy_multiplier = 0.9
	return material


## Every cable in one list as tubes in one mesh.
static func _tube_mesh(list: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for cable in list:
		var points: PackedVector3Array = cable.points
		var radius := float(cable.radius)
		for index in points.size():
			var ahead := points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]
			var forward := ahead.normalized() if ahead.length_squared() > 0.000001 else Vector3.FORWARD
			var helper := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
			var right := forward.cross(helper).normalized()
			var up := right.cross(forward).normalized()
			for around in RADIAL:
				var a := TAU * float(around) / float(RADIAL)
				var normal := right * cos(a) + up * sin(a)
				tool.set_normal(normal)
				tool.add_vertex(points[index] + normal * radius)
		for index in points.size() - 1:
			for around in RADIAL:
				var next := (around + 1) % RADIAL
				var p0 := base + index * RADIAL + around
				var p1 := base + index * RADIAL + next
				var p2 := base + (index + 1) * RADIAL + around
				var p3 := base + (index + 1) * RADIAL + next
				tool.add_index(p0)
				tool.add_index(p2)
				tool.add_index(p1)
				tool.add_index(p1)
				tool.add_index(p2)
				tool.add_index(p3)
		base += points.size() * RADIAL
	return tool.commit()


## The lowest any overhead cable hangs over the walking line down the middle
## of the aisle (|x| under `keep_clear`), for the test that keeps heads clear.
static func _lowest_over_aisle(cables: Dictionary, keep_clear: float) -> float:
	var lowest := INF
	for sheath in cables:
		for cable in cables[sheath]:
			for point in (cable.points as PackedVector3Array):
				if absf(point.x) < keep_clear and point.y > 0.5:
					lowest = minf(lowest, point.y)
	return lowest
