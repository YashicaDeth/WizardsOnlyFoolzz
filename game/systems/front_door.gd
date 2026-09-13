class_name FrontDoor
extends Node3D

## The front end, built to the register Greg pointed at across Postal 2,
## HAVKER-MAN X and Eternity Egg: the menu is not buttons on a backdrop, it is a
## made object sitting in a real scene. Three things those references share and
## this project had none of —
##
##   1. something crude and funny before the game proper starts;
##   2. a 3D scene behind the menu with actual junk tumbling through it;
##   3. interface elements that are rendered objects rather than flat panels.
##
## Everything here is generated: the junk is procedural geometry on the
## project's own `WorldLook` materials, the type is drawn in code, and no asset,
## layout or code from any of those games is reproduced.

const INK := Color("dce6ba")
const ACID := Color("b4da48")
const SPORE := Color("9bf01a")
const ARTERIAL := Color("c81f16")
const BILE := Color("b8a12a")
const BRUISE := Color("6a2d6e")

## The junk that falls past the camera. Meat industry, failed medicine and the
## paperwork of both — the three things the Ashbloom actually runs on.
const DEBRIS := [
	{"kind": "organ", "tint": "7a1a16", "size": 0.42},
	{"kind": "organ", "tint": "5e2430", "size": 0.34},
	{"kind": "heart", "tint": "8d1b1d", "size": 0.36},
	{"kind": "liver", "tint": "572625", "size": 0.44},
	{"kind": "tin", "tint": "8a7430", "size": 0.3},
	{"kind": "tin", "tint": "46523a", "size": 0.26},
	{"kind": "vial", "tint": "4f8f7b", "size": 0.25},
	{"kind": "capsule", "tint": "d1a842", "size": 0.23},
	{"kind": "blister", "tint": "a9a8a0", "size": 0.32},
	{"kind": "bone", "tint": "cfc2a4", "size": 0.42},
	{"kind": "bone", "tint": "b8ab88", "size": 0.3},
	{"kind": "paper", "tint": "c9c2a0", "size": 0.38},
	{"kind": "paper", "tint": "9aa878", "size": 0.34},
	{"kind": "tooth", "tint": "e4dcc0", "size": 0.14},
	{"kind": "syringe", "tint": "9bc4c8", "size": 0.3},
]

var clock := 0.0
var pieces: Array[Dictionary] = []
var street_actors: Array[Dictionary] = []
var floor_sigils: Array[Node3D] = []
var relics: Array[Dictionary] = []
var ram_car: Node3D
var impact_dummy: Node3D
var camera: Camera3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = WorldLook.environment("ossuary")
	# The opening is night, not a sunlit brown editor floor.  The very low hour
	# lets the practical red and indigo lights sculpt the street.
	WorldLook.apply_hour(env.environment, 0.08, "ossuary")
	add_child(env)

	camera = Camera3D.new()
	camera.position = Vector3(0, 1.55, 7.6)
	camera.fov = 50.0
	# A composed, low telephoto street view.  It puts the fight in the centre and
	# holds the ruined block behind it instead of aiming down at empty ground.
	camera.rotation.x = deg_to_rad(5.0)
	add_child(camera)

	var key := OmniLight3D.new()
	key.position = Vector3(-1.5, 3.0, 0.3)
	key.light_color = Color("d12520")
	key.light_energy = 7.2
	key.omni_range = 16.0
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(3.8, 4.0, -2.0)
	fill.light_color = Color("57151b")
	fill.light_energy = 2.8
	fill.omni_range = 18.0
	add_child(fill)

	_build_debris()
	_build_living_ashbloom()
	set_process(true)


## The first shot is a real place now: a small block of Ashbloom with people
## crossing it and two scavengers fighting in the centre.  It is deliberately
## staged rather than a physics simulation; this is a front door, so it must
## read immediately and never spend menu-frame budget on a whole AI world.
func _build_living_ashbloom() -> void:
	_add_set_piece(BoxMesh.new(), Vector3(0, -1.2, -5.2), Vector3(15.0, 0.22, 13.0), Color("0e0d16"), "rust", 0)
	_add_set_piece(BoxMesh.new(), Vector3(0, -1.06, -5.2), Vector3(3.1, 0.025, 12.0), Color("211722"), "rust", 2)
	var street_body := StaticBody3D.new()
	street_body.position = Vector3(0, -1.2, -5.2)
	var street_collision := CollisionShape3D.new()
	var street_shape := BoxShape3D.new()
	street_shape.size = Vector3(15.0, 0.22, 13.0)
	street_collision.shape = street_shape
	street_body.add_child(street_collision)
	add_child(street_body)
	# Broken side buildings frame the street without covering its actors.
	_add_set_piece(BoxMesh.new(), Vector3(-5.8, 0.2, -6.4), Vector3(2.2, 2.6, 4.4), Color("20121d"), "rust", 5)
	_add_set_piece(BoxMesh.new(), Vector3(5.7, 0.05, -7.3), Vector3(2.5, 2.3, 3.5), Color("171521"), "rust", 7)
	for x in [-0.85, 0.85]:
		_add_set_piece(BoxMesh.new(), Vector3(x, -1.00, -5.2), Vector3(0.08, 0.035, 10.0), Color("c46a2e"), "rust", 12 + int(x * 4.0))
	_build_floor_gore_and_sigils()
	# Two fighters read as a conflict at a glance; the others give the road a
	# population and move on different loops.
	_spawn_actor(Vector3(-0.72, -0.52, -4.6), Color("9a3026"), 0.0, true)
	_spawn_actor(Vector3(0.62, -0.52, -4.8), Color("6d8c67"), 1.7, true)
	_spawn_actor(Vector3(-2.9, -0.52, -7.8), Color("564238"), 2.9, false)
	_spawn_actor(Vector3(2.8, -0.52, -6.4), Color("77533b"), 4.4, false)
	_spawn_actor(Vector3(-1.9, -0.52, -8.8), Color("3c6670"), 5.6, false)
	_build_relics()
	_build_ram_vignette()


func _add_set_piece(mesh: PrimitiveMesh, at: Vector3, scale_value: Vector3, tint: Color, surface_kind: String, seed: int) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = at
	item.scale = scale_value
	mesh.material = WorldLook.surface(tint, surface_kind, seed)
	add_child(item)
	return item


func _build_floor_gore_and_sigils() -> void:
	for index in 17:
		var x := sin(float(index) * 4.7) * 4.3
		var z := -3.2 - fposmod(float(index) * 2.39, 7.4)
		var stain := _add_set_piece(CylinderMesh.new(), Vector3(x, -1.025, z), Vector3(0.14 + float(index % 4) * 0.09, 0.01, 0.08 + float(index % 3) * 0.07), Color("5f1715"), "flesh", index + 30)
		stain.rotation.y = float(index) * 0.72
	for index in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.34 + index * 0.06
		torus.outer_radius = 0.38 + index * 0.06
		torus.rings = 20
		torus.ring_segments = 8
		torus.material = WorldLook.surface(Color("9b241d"), "flesh", 65 + index)
		ring.mesh = torus
		ring.position = Vector3(-2.8 + index * 2.75, -0.99, -4.2 - index * 1.55)
		ring.rotation.x = PI * 0.5
		add_child(ring)
		floor_sigils.append(ring)


func _spawn_actor(at: Vector3, tint: Color, phase: float, fighting: bool) -> void:
	# The menu population uses the same six-zone BaselineHuman rig as the
	# player and live combat.  These are not capsule stand-ins: their anatomy,
	# severing vocabulary and world material are the game's own body contract.
	var body := BaselineHuman.new()
	body.build("frontdoor_%d" % int(phase * 100.0), {"flesh": tint, "variation": int(phase * 13.0), "gore": true, "build": 0.9})
	body.position = at
	add_child(body)
	# A crude held blade gives the two central figures a readable exchange.
	var blade := BoxMesh.new()
	blade.size = Vector3(0.055, 0.5, 0.055)
	var weapon := MeshInstance3D.new()
	weapon.mesh = blade
	weapon.position = Vector3(0.34, 1.05, 0)
	weapon.rotation.z = -0.65
	blade.material = WorldLook.surface(Color("c8baa3"), "bone", int(phase * 23.0))
	body.add_child(weapon)
	street_actors.append({"node": body, "origin": at, "phase": phase, "fighting": fighting, "weapon": weapon})


func _build_relics() -> void:
	for index in 4:
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.24
		sphere.height = 0.48
		sphere.radial_segments = 12
		sphere.rings = 8
		sphere.material = WorldLook.surface(Color("6a3c83"), "flesh", 100 + index)
		orb.mesh = sphere
		orb.position = Vector3(-3.5 + index * 2.15, 0.25 + (index % 2) * 0.42, -7.2 + (index % 3) * 0.7)
		add_child(orb)
		relics.append({"node": orb, "origin": orb.position, "phase": float(index) * 1.4})


## A short, repeating vehicle beat previews the game's consequences without
## replacing the actual derby.  The body is a separate loose model so the car
## never has to fake a collision by moving an NPC controller through a wall.
func _build_ram_vignette() -> void:
	ram_car = Node3D.new()
	add_child(ram_car)
	var shell := _add_piece_to(ram_car, BoxMesh.new(), Vector3.ZERO, Vector3(1.1, 0.36, 0.55), Color("7d251d"), "rust", 141)
	shell.position.y = -0.67
	for side in [-0.4, 0.4]:
		var wheel := _add_piece_to(ram_car, CylinderMesh.new(), Vector3(side, -0.88, 0.0), Vector3(0.18, 0.11, 0.18), Color("181312"), "rust", 143 + int(side * 10.0))
		wheel.rotation.x = PI * 0.5
	impact_dummy = Node3D.new()
	impact_dummy.position = Vector3(0.55, -0.56, -5.55)
	add_child(impact_dummy)
	var limb := _add_piece_to(impact_dummy, CapsuleMesh.new(), Vector3(0, 0.25, 0), Vector3(0.16, 0.7, 0.16), Color("78251f"), "flesh", 150)
	limb.rotation.z = PI * 0.5
	var skull := _add_piece_to(impact_dummy, SphereMesh.new(), Vector3(0.42, 0.36, 0), Vector3(0.2, 0.2, 0.2), Color("a76d54"), "flesh", 151)
	# A small existing pool makes the repeated impact read as violent rather
	# than slapstick, without adding any UI explanation.
	var pool := _add_set_piece(CylinderMesh.new(), Vector3(0.85, -1.02, -5.55), Vector3(0.42, 0.01, 0.24), Color("741714"), "flesh", 152)
	pool.rotation.y = 0.32


func _add_piece_to(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, scale_value: Vector3, tint: Color, surface_kind: String, seed: int) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = at
	item.scale = scale_value
	mesh.material = WorldLook.surface(tint, surface_kind, seed)
	parent.add_child(item)
	return item


func _build_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90211
	for index in 66:
		var spec: Dictionary = DEBRIS[index % DEBRIS.size()]
		var piece := MeshInstance3D.new()
		piece.mesh = _junk_mesh(str(spec.kind), float(spec.size) * rng.randf_range(0.7, 1.4))
		piece.mesh.surface_set_material(0, WorldLook.surface(
			Color(str(spec.tint)),
			"flesh" if spec.kind == "organ" else ("bone" if spec.kind in ["bone", "tooth"] else "rust"),
			index + 3
		))
		add_child(piece)
		var state := {
			"node": piece,
			"origin": Vector3(rng.randf_range(-3.6, 3.6), rng.randf_range(-3.0, 3.0), rng.randf_range(-2.6, 1.6)),
			"fall": rng.randf_range(0.22, 0.68),
			"spin": Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-1.4, 1.4), rng.randf_range(-1.4, 1.4)),
			"drift": rng.randf_range(0.0, TAU),
		}
		# Organs should never fall as perfect fruit.  A slightly asymmetric body
		# and a different scale per chunk sells soft tissue before the player is
		# even close enough to inspect it.
		if spec.kind in ["organ", "heart", "liver"]:
			piece.scale = Vector3(rng.randf_range(0.72, 1.2), rng.randf_range(0.9, 1.42), rng.randf_range(0.68, 1.16))
		pieces.append(state)
		piece.position = state.origin


func _junk_mesh(kind: String, size: float) -> Mesh:
	match kind:
		"organ":
			var organ := SphereMesh.new()
			organ.radius = size * 0.56
			organ.height = size * 1.72
			organ.radial_segments = 12
			organ.rings = 8
			return organ
		"heart":
			var heart := SphereMesh.new()
			heart.radius = size * 0.56
			heart.height = size * 1.42
			heart.radial_segments = 12
			heart.rings = 8
			return heart
		"liver":
			var liver := SphereMesh.new()
			liver.radius = size * 0.72
			liver.height = size * 0.82
			liver.radial_segments = 12
			liver.rings = 6
			return liver
		"tin":
			var tin := CylinderMesh.new()
			tin.top_radius = size * 0.42
			tin.bottom_radius = size * 0.42
			tin.height = size
			tin.radial_segments = 8
			return tin
		"bone":
			var bone := CapsuleMesh.new()
			bone.radius = size * 0.14
			bone.height = size * 2.0
			bone.radial_segments = 6
			return bone
		"tooth":
			var tooth := PrismMesh.new()
			tooth.size = Vector3(size, size * 1.5, size * 0.7)
			return tooth
		"syringe":
			var syringe := CylinderMesh.new()
			syringe.top_radius = size * 0.06
			syringe.bottom_radius = size * 0.14
			syringe.height = size * 1.8
			syringe.radial_segments = 6
			return syringe
		"vial":
			var vial := CylinderMesh.new()
			vial.top_radius = size * 0.13
			vial.bottom_radius = size * 0.18
			vial.height = size * 1.65
			vial.radial_segments = 10
			return vial
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = size * 0.2
			capsule.height = size * 1.55
			capsule.radial_segments = 10
			return capsule
		"blister":
			var blister := BoxMesh.new()
			blister.size = Vector3(size * 1.45, size * 0.72, size * 0.09)
			return blister
		_:
			var paper := BoxMesh.new()
			paper.size = Vector3(size, size * 1.3, 0.01)
			return paper


func _process(delta: float) -> void:
	clock += delta
	# The shot breathes as the title sequence runs: a slow, almost imperceptible
	# push makes the street feel observed rather than like a paused level.
	if camera != null:
		camera.position.z = 7.6 - minf(clock, 7.0) * 0.075
		camera.position.y = 1.55 + sin(clock * 0.42) * 0.045
	for piece in pieces:
		var node := piece.node as Node3D
		if not is_instance_valid(node):
			continue
		# Falling past the camera and wrapping, rather than simulated: the front
		# end should not be running a physics world to show a menu.
		var fallen := fposmod(clock * float(piece.fall) + float(piece.drift), 7.0)
		var origin: Vector3 = piece.origin
		node.position = Vector3(
			origin.x + sin(clock * 0.4 + float(piece.drift)) * 0.22,
			origin.y + 3.5 - fallen,
			origin.z
		)
		node.rotation += (piece.spin as Vector3) * delta
	for state in street_actors:
		var actor := state.node as Node3D
		if not is_instance_valid(actor):
			continue
		var phase := clock * (1.8 if bool(state.fighting) else 0.7) + float(state.phase)
		var origin: Vector3 = state.origin
		if bool(state.fighting):
			actor.position = origin + Vector3(sin(phase) * 0.22, abs(sin(phase * 2.0)) * 0.08, cos(phase) * 0.12)
			actor.rotation.y = sin(phase * 0.7) * 1.1
			(state.weapon as Node3D).rotation.z = -0.35 + sin(phase * 3.0) * 0.85
		else:
			actor.position = origin + Vector3(sin(phase) * 0.78, abs(sin(phase * 2.0)) * 0.04, cos(phase) * 0.32)
			actor.rotation.y = cos(phase) * 0.65
	for index in floor_sigils.size():
		var sigil := floor_sigils[index]
		if is_instance_valid(sigil):
			sigil.rotation.z += delta * (0.18 + index * 0.045)
			sigil.position.y = -0.99 + sin(clock * 1.4 + index) * 0.025
	for relic in relics:
		var item := relic.node as Node3D
		if is_instance_valid(item):
			item.position = (relic.origin as Vector3) + Vector3(0, sin(clock * 1.5 + float(relic.phase)) * 0.18, 0)
			item.rotate_y(delta * 0.72)
	if is_instance_valid(ram_car) and is_instance_valid(impact_dummy):
		var ram_phase := fposmod(clock * 0.42, 1.0)
		ram_car.position = Vector3(lerpf(-7.2, 6.6, ram_phase), 0, -5.55)
		# The dummy rests, launches at the hit, then settles back into the pool.
		var launch := clampf((ram_phase - 0.49) * 4.1, 0.0, 1.0)
		impact_dummy.position = Vector3(0.55 + launch * 1.9, -0.56 + sin(launch * PI) * 1.05, -5.55 + launch * 0.72)
		impact_dummy.rotation = Vector3(launch * 5.4, launch * 1.8, launch * 4.7)
