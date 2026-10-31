class_name GroundHole
extends RefCounted

## Greg, 25 September: "if you shoot downwards with a gun or if you blow up the
## ground there will be an impact hole" (DESIGN/GOAL_LOOP_2.md 0.2b).
##
## Not terrain editing. The ground is one flat collider and mesh, and whether
## it should really give way is the open Teardown question. A hole here is
## what reads as one from standing height: a pit drawn into the surface
## (`ground_hole.gdshader`), a lip of thrown dirt standing proud of it, and
## clods that fly and stay as debris. A round makes a small one; 0.5's blasts
## call `carve()` with a crater's radius.

const GROUP := "ground"
const CLOD_POOL := "ground_clod"
const SOIL := Color("382b1f")
const BOWL := preload("res://shaders/ground_hole.gdshader")


## Only what a scene has named its ground takes a hole, and only where it faces
## up. A crate lid, a car roof, a wall or a body keeps the flat scar.
static func is_ground(collider: Object, normal: Vector3) -> bool:
	return collider is Node and (collider as Node).is_in_group(GROUP) and normal.normalized().y >= 0.7


## How wide a round's hole is, in metres, from the energy it arrived with.
## By the square root, so a rifle's hole is wider than a pistol's without a
## slug leaving a crater: about 5.5 cm of buckshot, 7.5 of pistol, 19 of rifle.
static func radius_for_round(energy: float) -> float:
	return clampf(0.035 * sqrt(maxf(energy, 0.0) / 100.0), 0.04, 0.3)


static func carve(parent: Node, at: Vector3, normal: Vector3, radius: float, direction := Vector3.DOWN) -> Node3D:
	var up := normal.normalized()
	var hole := Node3D.new()
	hole.name = "GroundHole"
	parent.add_child(hole)
	hole.global_position = at + up * 0.004
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	hole.global_basis = Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)
	hole.set_meta("radius", radius)

	var bowl := MeshInstance3D.new()
	bowl.name = "Bowl"
	var disc := PlaneMesh.new()
	disc.size = Vector2(2, 2)
	var pit := ShaderMaterial.new()
	pit.shader = BOWL
	pit.set_shader_parameter("soil", SOIL)
	disc.material = pit
	bowl.mesh = disc
	bowl.scale = Vector3.ONE * radius
	hole.add_child(bowl)

	# The dirt the round threw out, heaped round the edge. Low, chunky and a
	# little out of round, in plain soil: the first render, a full torus in the
	# house grain, read as a tyre lying in the yard rather than as thrown dirt.
	var lip := MeshInstance3D.new()
	lip.name = "Lip"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.98
	ring.outer_radius = 1.36
	ring.rings = 9
	ring.ring_segments = 4
	ring.material = _soil(SOIL)
	lip.mesh = ring
	lip.scale = Vector3(radius * randf_range(0.88, 1.12), radius * 0.2, radius * randf_range(0.88, 1.12))
	hole.add_child(lip)

	var thrown := direction.bounce(up).normalized() if direction.length_squared() > 0.001 else up
	for index in clampi(int(radius * 30.0), 1, 8):
		_throw_clod(parent, at + up * 0.03, up, thrown, radius, index)
	return hole


## Turned earth: flat and matte. The house grain tiles into camouflage blocks
## at a hole's few centimetres, so it is left off here.
static func _soil(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	return material


static func _throw_clod(parent: Node, at: Vector3, up: Vector3, thrown: Vector3, radius: float, index: int) -> void:
	var clod := RigidBody3D.new()
	clod.name = "Clod_%02d" % index
	clod.mass = 0.05 + radius * 0.4
	# The same layers as prop fragments: they land on the world, not on cars.
	clod.collision_layer = 1 << 3
	clod.collision_mask = 1
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * radius * randf_range(0.18, 0.34)
	chunk.material = _soil(SOIL.darkened(randf_range(0.0, 0.3)))
	var visual := MeshInstance3D.new()
	visual.mesh = chunk
	clod.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = chunk.size
	clod.add_child(shape)
	parent.add_child(clod)
	clod.global_position = at
	var spray := (thrown * 0.6 + up * 0.8 + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))).normalized()
	clod.linear_velocity = spray * (1.2 + radius * 6.0)
	clod.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	WorldDebris.register(clod, {"kind": "ground_clod", "part": "clod"}, CLOD_POOL, BreakableProp.fragment_budget())
