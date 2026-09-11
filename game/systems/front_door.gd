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
	{"kind": "organ", "tint": "7a1a16", "size": 0.34},
	{"kind": "organ", "tint": "5e2430", "size": 0.28},
	{"kind": "tin", "tint": "8a7430", "size": 0.3},
	{"kind": "tin", "tint": "46523a", "size": 0.26},
	{"kind": "bone", "tint": "cfc2a4", "size": 0.42},
	{"kind": "bone", "tint": "b8ab88", "size": 0.3},
	{"kind": "paper", "tint": "c9c2a0", "size": 0.38},
	{"kind": "paper", "tint": "9aa878", "size": 0.34},
	{"kind": "tooth", "tint": "e4dcc0", "size": 0.14},
	{"kind": "syringe", "tint": "9bc4c8", "size": 0.3},
]

var clock := 0.0
var pieces: Array[Dictionary] = []
var camera: Camera3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = WorldLook.environment("ossuary")
	add_child(env)

	camera = Camera3D.new()
	camera.position = Vector3(0, 0, 3.4)
	camera.fov = 62.0
	add_child(camera)

	var key := OmniLight3D.new()
	key.position = Vector3(1.6, 1.4, 2.6)
	key.light_color = Color("ffd8a0")
	key.light_energy = 4.2
	key.omni_range = 12.0
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, -0.8, 1.8)
	fill.light_color = SPORE
	fill.light_energy = 2.4
	fill.omni_range = 10.0
	add_child(fill)

	_build_debris()
	set_process(true)


func _build_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90211
	for index in 46:
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
		pieces.append(state)
		piece.position = state.origin


func _junk_mesh(kind: String, size: float) -> Mesh:
	match kind:
		"organ":
			var organ := SphereMesh.new()
			organ.radius = size * 0.5
			organ.height = size * 1.5
			organ.radial_segments = 7
			organ.rings = 4
			return organ
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
		_:
			var paper := BoxMesh.new()
			paper.size = Vector3(size, size * 1.3, 0.01)
			return paper


func _process(delta: float) -> void:
	clock += delta
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
