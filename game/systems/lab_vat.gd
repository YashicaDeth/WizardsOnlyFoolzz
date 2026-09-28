class_name LabVat
extends RefCounted

## One growth vat, built the same way wherever the facility needs one. Greg on
## first launch (2026-09-24): the tanks were "just cylinder-like models" with
## rings "that intertwine over and over", holding pill-shaped blobs; a vat
## should be sci-fi hardware with a body in it, and a fetus reads better than
## a capsule. So: a steel plinth and crown on real plate texture, a clear glass
## tube, fluid with a lamp in the base, two service struts, feed lines into
## the crown -- and a curled body floating in the medium.

const GLASS := Color(0.55, 0.62, 0.58, 0.10)
const FLUID := Color(0.40, 0.10, 0.06, 0.30)
const FLESH := Color("8a6358")


## `at` is the vat's footprint on the floor. `height` is the glass tube's.
## `occupied` false leaves the tube empty (a drained or a waiting vat).
static func build(host: Node3D, at: Vector3, seed_value: int, height := 2.4, radius := 0.72, occupied := true, lit := true, solid := true) -> Node3D:
	var root := Node3D.new()
	root.name = "LabVat_%d" % seed_value
	root.position = at
	host.add_child(root)
	var plate := LabSurface.material("plate")
	var plinth_height := 0.42
	_cylinder(root, "Plinth", radius + 0.16, radius + 0.22, plinth_height, Vector3(0, plinth_height * 0.5, 0), plate)
	_cylinder(root, "Crown", radius + 0.18, radius + 0.12, 0.34, Vector3(0, plinth_height + height + 0.17, 0), plate)
	# The tube itself, and the medium a hand's width inside it.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = GLASS
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cylinder(root, "Glass", radius, radius, height, Vector3(0, plinth_height + height * 0.5, 0), glass, false)
	var fluid := StandardMaterial3D.new()
	fluid.albedo_color = FLUID
	fluid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fluid.emission_enabled = true
	fluid.emission = Color(0.22, 0.05, 0.02)
	fluid.emission_energy_multiplier = 0.8
	fluid.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cylinder(root, "Medium", radius - 0.05, radius - 0.05, height * 0.92, Vector3(0, plinth_height + height * 0.46, 0), fluid, false)
	# Two service struts instead of rings: hardware, not decoration.
	var grime := LabSurface.material("grime")
	for side in [-1.0, 1.0]:
		var strut := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.09, height + 0.3, 0.09)
		box.material = grime
		strut.mesh = box
		strut.position = Vector3(side * (radius + 0.06), plinth_height + height * 0.5, 0.0)
		root.add_child(strut)
	# Feed lines out of the crown and up into the dark.
	var rust := LabSurface.material("rust")
	for line in 3:
		var angle := TAU * float(line) / 3.0 + float(seed_value)
		_cylinder(root, "Feed%d" % line, 0.035, 0.035, 1.6, Vector3(cos(angle) * radius * 0.5, plinth_height + height + 1.1, sin(angle) * radius * 0.5), rust)
	# Solid: Greg walked straight through the vats on his second walkthrough.
	# One cylinder for the whole column, plinth to crown. Lab dressing passes
	# solid = false: its contract is decoration that never blocks movement.
	if solid:
		_collide(root, radius + 0.18, plinth_height + height + 0.34)
	if lit:
		var lamp := OmniLight3D.new()
		lamp.name = "BaseLamp"
		lamp.position = Vector3(0, plinth_height + 0.3, 0)
		lamp.light_color = Color("d9895a")
		lamp.light_energy = 1.6
		lamp.omni_range = 3.2
		lamp.shadow_enabled = false
		root.add_child(lamp)
	if occupied:
		var fetus := curled_body(seed_value)
		fetus.position = Vector3(0, plinth_height + height * 0.52, 0)
		root.add_child(fetus)
	return root


## A curled body, knees to chest and head bowed, built from a few primitives so
## a corridor of them stays cheap. Big head, short limbs: grown, not born.
static func curled_body(seed_value: int, scale := 1.0) -> Node3D:
	var body := Node3D.new()
	body.name = "Curled"
	var skin := WorldLook.surface(FLESH, "flesh", seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_sphere(body, "Head", 0.16, Vector3(0, 0.16, -0.10), skin)
	_capsule(body, "Torso", 0.15, 0.46, Vector3(0, -0.06, 0.02), Vector3(-28, 0, 0), skin)
	for side in [-1.0, 1.0]:
		_capsule(body, "Thigh", 0.07, 0.34, Vector3(side * 0.09, -0.12, -0.12), Vector3(-80, 0, side * 8.0), skin)
		_capsule(body, "Shin", 0.055, 0.30, Vector3(side * 0.10, -0.22, -0.20), Vector3(10, 0, side * 6.0), skin)
		_capsule(body, "Arm", 0.045, 0.30, Vector3(side * 0.14, 0.02, -0.14), Vector3(-60, side * 20.0, side * 30.0), skin)
	# A cord from the navel up toward the crown.
	_capsule(body, "Cord", 0.02, 0.9, Vector3(0.02, 0.38, 0.02), Vector3(8, 0, 4), skin)
	body.rotation_degrees = Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 360), rng.randf_range(-12, 12))
	body.scale = Vector3.ONE * scale * rng.randf_range(0.9, 1.15)
	return body


static func _cylinder(parent: Node3D, label: String, top: float, bottom: float, height: float, at: Vector3, material: Material, capped := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	mesh.cap_top = capped
	mesh.cap_bottom = capped
	mesh.material = material
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node


static func _sphere(parent: Node3D, label: String, radius: float, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = material
	node.mesh = mesh
	node.position = at
	parent.add_child(node)


static func _capsule(parent: Node3D, label: String, radius: float, height: float, at: Vector3, rotation: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.material = material
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	parent.add_child(node)


static func _collide(root: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "VatCollision"
	var shape := CollisionShape3D.new()
	var column := CylinderShape3D.new()
	column.radius = radius
	column.height = height
	shape.shape = column
	shape.position = Vector3(0, height * 0.5, 0)
	body.add_child(shape)
	root.add_child(body)
