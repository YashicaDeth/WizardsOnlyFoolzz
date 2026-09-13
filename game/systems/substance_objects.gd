class_name SubstanceObjects
extends RefCounted

## AU1.2. "A drug is an object — a baggie, a blister, a tab, a weight."
##
## That line has been true in the data since `carry.gd` learned `take_substance`
## — every pickup already carries its `form` and the Choir already prices it.
## None of it had geometry. A baggie of Marrow Dust and a pressed weight of
## Choir Bloom were the same invisible nothing in the bag, which is the exact
## failure AU1.2 was written against.
##
## AU3.2 is the other half: *"every substance in AU is physically set out in the
## room and takeable, not chosen from a list"*. So this file builds both — the
## four carried forms, and the things a shed has around them.
##
## Primitives only, at real scale, same rule as everything else. A blotter tab
## is 12mm because a blotter tab is 12mm; a pressed weight is 28g of volume
## rather than a cube somebody eyeballed.

const POWDER_WHITE := Color("ded8cc")
const POWDER_BONE := Color("c8bda6")
const PLASTIC_CLEAR := Color("aab5b2")
const PLASTIC_DARK := Color("15181a")
const FOIL := Color("b9bec2")
const CARD := Color("cfc4ad")
const INK := Color("2a2320")
const STEEL := Color("8f959a")
const RESIN := Color("4a3a1c")
const GLASS := Color("cfe0dd")

## Which shape each catalogued form gets. The substance decides the colour of
## what is inside it; the form decides everything else, which is why two
## substances in baggies still read as two different baggies.
const FORMS := ["baggie", "weight", "tab", "blister"]

## The contents colour per substance, so a bag of ground bone and a bag of
## anything else are not the same prop with a different label.
const FILL := {
	"marrow_dust": Color("d9d2c0"),
	"choir_bloom": Color("6c7a41"),
	"static_hymn": Color("3d4348"),
}


static func build(form: String, substance_id := "") -> Node3D:
	var root := Node3D.new()
	root.name = form
	var fill: Color = FILL.get(substance_id, POWDER_BONE)
	match form:
		"baggie": _build_baggie(root, fill)
		"weight": _build_weight(root, fill)
		"tab": _build_tab(root, fill)
		"blister": _build_blister(root, fill)
		_: _build_baggie(root, fill)
	return root


## A press-seal bag, 50×50mm, sat slumped rather than flat — the contents pool
## in the bottom third and the empty top folds over, which is the whole reason
## a bag reads as a bag and not as a card.
static func _build_baggie(root: Node3D, fill: Color) -> void:
	var slump := _box(Vector3(0.050, 0.016, 0.022), fill.lightened(0.10), 0.94)
	slump.position = Vector3(0, 0.008, 0)
	root.add_child(slump)

	# The bag around it, slightly larger and clear.
	var bag := _box(Vector3(0.052, 0.019, 0.025), PLASTIC_CLEAR, 0.38)
	_clarify(bag, 0.20)
	(bag.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
	bag.position = Vector3(0, 0.0095, 0)
	root.add_child(bag)

	# The empty top, creased over. Half the height it was: at 30mm it stood up
	# off a 50mm bag like a sail and became the whole silhouette, which left the
	# thing the bag is *for* reading as nothing.
	var flap := _box(Vector3(0.050, 0.015, 0.0022), PLASTIC_CLEAR, 0.42)
	_clarify(flap, 0.16)
	flap.rotation = Vector3(deg_to_rad(-74.0), 0, 0)
	flap.position = Vector3(0, 0.0235, 0.006)
	root.add_child(flap)

	# The zip: two ribs, which is the detail that makes it a press-seal and not
	# a sandwich bag.
	for side in [-0.0016, 0.0016]:
		var rib := _box(Vector3(0.050, 0.0018, 0.0016), PLASTIC_CLEAR.darkened(0.12), 0.3)
		_clarify(rib, 0.65)
		rib.position = Vector3(0, 0.0195, side)
		root.add_child(rib)


## 28g, pressed and wrapped. Cling wrap is a second skin one millimetre off the
## brick with a different roughness — a single shiny box reads as a bar of soap.
static func _build_weight(root: Node3D, fill: Color) -> void:
	var brick := _box(Vector3(0.062, 0.026, 0.042), fill, 0.92)
	brick.position = Vector3(0, 0.013, 0)
	root.add_child(brick)

	# Cling is scuffed, not polished, and it is a closed box - leaving it
	# double-sided let its own back faces sort over the brick.
	var wrap := _box(Vector3(0.064, 0.028, 0.044), PLASTIC_CLEAR, 0.44)
	_clarify(wrap, 0.13)
	(wrap.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
	wrap.position = Vector3(0, 0.014, 0)
	root.add_child(wrap)

	# Tape across the seam, because nobody wraps one of these neatly.
	var tape := _box(Vector3(0.068, 0.0022, 0.016), Color("6d6553"), 0.86)
	tape.rotation = Vector3(0, deg_to_rad(6.0), 0)
	tape.position = Vector3(0, 0.0282, 0.004)
	root.add_child(tape)


## Blotter: a 12mm square of card with the perforation grid still on it and a
## print that runs off the edges, because a sheet is cut from a bigger sheet.
static func _build_tab(root: Node3D, fill: Color) -> void:
	var card := _box(Vector3(0.012, 0.0004, 0.012), CARD, 0.95)
	card.position = Vector3(0, 0.0002, 0)
	root.add_child(card)

	# The print. Four quarters of a pattern that does not resolve at this size,
	# which is exactly right — it is a fragment of a sheet.
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var mark := _box(Vector3(0.0042, 0.0002, 0.0042), fill.lightened(0.1), 0.9)
			mark.position = Vector3(qx * 0.0027, 0.0006, qz * 0.0027)
			root.add_child(mark)

	# Perforation: a nick out of each edge.
	for edge in range(4):
		var nick := _box(Vector3(0.0008, 0.0007, 0.0008), CARD.darkened(0.35), 0.95)
		var angle := float(edge) * PI * 0.5
		nick.position = Vector3(sin(angle) * 0.006, 0.0003, cos(angle) * 0.006)
		root.add_child(nick)


## Foil-backed card. Named in AU1.2 and used by nothing in the catalogue yet —
## built anyway, because the moment a pharmaceutical enters AU it needs to
## already look like one rather than like a baggie with a different label.
static func _build_blister(root: Node3D, fill: Color) -> void:
	var card := _box(Vector3(0.034, 0.0006, 0.052), FOIL, 0.42)
	card.position = Vector3(0, 0.0003, 0)
	root.add_child(card)

	for row in 4:
		for column in 2:
			var dome := SphereMesh.new()
			dome.radius = 0.0048
			dome.height = 0.0072
			dome.radial_segments = 10
			dome.rings = 5
			var bubble := MeshInstance3D.new()
			bubble.mesh = dome
			bubble.material_override = _material(PLASTIC_CLEAR, 0.08)
			_clarify(bubble, 0.34)
			bubble.position = Vector3(-0.0075 + float(column) * 0.015, 0.0028, -0.018 + float(row) * 0.012)
			root.add_child(bubble)

			var pill := _box(Vector3(0.0062, 0.0026, 0.0062), fill.lightened(0.28), 0.9)
			pill.position = Vector3(-0.0075 + float(column) * 0.015, 0.0019, -0.018 + float(row) * 0.012)
			root.add_child(pill)


## --- AU3.1/AU3.2: what a shed has around them ---------------------------

const PROPS := ["tray", "grinder", "lighter", "ashtray", "scales"]


static func build_prop(prop: String) -> Node3D:
	var root := Node3D.new()
	root.name = prop
	match prop:
		"tray": _build_tray(root)
		"grinder": _build_grinder(root)
		"lighter": _build_lighter(root)
		"ashtray": _build_ashtray(root)
		"scales": _build_scales(root)
	return root


## A rolling tray: a shallow metal dish with a lip, scratched to hell.
static func _build_tray(root: Node3D) -> void:
	var floor_plate := _box(Vector3(0.180, 0.0022, 0.130), Color("6d5a3e"), 0.55)
	floor_plate.position = Vector3(0, 0.0011, 0)
	root.add_child(floor_plate)
	for side in range(4):
		var along_x := side % 2 == 0
		var lip := _box(
			Vector3(0.180 if along_x else 0.0022, 0.009, 0.0022 if along_x else 0.130),
			Color("5c4b32"), 0.5,
		)
		var sign_of := 1.0 if side < 2 else -1.0
		lip.position = Vector3(
			0.0 if along_x else sign_of * 0.089, 0.005,
			sign_of * 0.064 if along_x else 0.0,
		)
		root.add_child(lip)


## Two-part grinder, teeth showing, sat open the way one always is.
static func _build_grinder(root: Node3D) -> void:
	var lower := _cylinder(0.028, 0.016, Color("4b4f52"), 0.36)
	lower.position = Vector3(0, 0.008, 0)
	root.add_child(lower)
	# Knurling: a ring of fins around the barrel.
	for tooth in 24:
		var angle := TAU * float(tooth) / 24.0
		var fin := _box(Vector3(0.0016, 0.014, 0.0030), Color("3d4144"), 0.4)
		fin.rotation = Vector3(0, -angle, 0)
		fin.position = Vector3(sin(angle) * 0.0284, 0.008, cos(angle) * 0.0284)
		root.add_child(fin)
	# The lid, off and leaning against it.
	var lid := _cylinder(0.028, 0.012, Color("55595c"), 0.34)
	lid.rotation = Vector3(deg_to_rad(74.0), 0, 0)
	lid.position = Vector3(0.040, 0.026, 0.004)
	root.add_child(lid)
	# The teeth in the open half.
	for tooth in 9:
		var angle := TAU * float(tooth) / 9.0
		var peg := _cylinder(0.0014, 0.006, STEEL, 0.3)
		peg.position = Vector3(sin(angle) * 0.014, 0.019, cos(angle) * 0.014)
		root.add_child(peg)


static func _build_lighter(root: Node3D) -> void:
	var body := _box(Vector3(0.023, 0.058, 0.012), Color("b02a1c"), 0.35)
	body.position = Vector3(0, 0.029, 0)
	root.add_child(body)
	var fluid := _box(Vector3(0.019, 0.030, 0.010), Color("d8552f"), 0.1)
	_clarify(fluid, 0.55)
	fluid.position = Vector3(0, 0.017, 0)
	root.add_child(fluid)
	var hood := _box(Vector3(0.019, 0.010, 0.011), STEEL, 0.28)
	hood.position = Vector3(0, 0.062, 0)
	root.add_child(hood)
	var wheel := _cylinder(0.0052, 0.006, Color("6e7478"), 0.3)
	wheel.rotation = Vector3(0, 0, deg_to_rad(90.0))
	wheel.position = Vector3(0, 0.0665, -0.001)
	root.add_child(wheel)


static func _build_ashtray(root: Node3D) -> void:
	var dish := _cylinder(0.056, 0.012, Color("2b2b2e"), 0.62)
	dish.position = Vector3(0, 0.006, 0)
	root.add_child(dish)
	var well := _cylinder(0.046, 0.010, Color("1a1a1c"), 0.85)
	well.position = Vector3(0, 0.0105, 0)
	root.add_child(well)
	# Two notches to rest one in, and what is already in it.
	for side in [-1.0, 1.0]:
		var notch := _box(Vector3(0.004, 0.006, 0.020), Color("1a1a1c"), 0.8)
		notch.position = Vector3(side * 0.050, 0.013, 0)
		root.add_child(notch)
	# Three dead ones, lying flat and pointing different ways. Rotating on two
	# axes at once stood them on end and they read as spilled chalk.
	for butt in 3:
		var stub := _cylinder(0.0040, 0.018, Color("cfc7b4"), 0.94)
		var lean: float = [-0.7, 0.35, 1.35][butt]
		stub.rotation = Vector3(deg_to_rad(90.0), lean, 0)
		stub.position = Vector3(-0.014 + float(butt) * 0.014, 0.0134, -0.004 + float(butt) * 0.005)
		root.add_child(stub)
		var burnt := _cylinder(0.0038, 0.005, Color("55504a"), 0.98)
		burnt.rotation = stub.rotation
		burnt.position = stub.position + Vector3(sin(lean) * 0.0115, 0.0, cos(lean) * 0.0115)
		root.add_child(burnt)
	var ash := _cylinder(0.030, 0.003, Color("9a948a"), 0.98)
	ash.position = Vector3(0, 0.0125, 0)
	root.add_child(ash)


static func _build_scales(root: Node3D) -> void:
	var body := _box(Vector3(0.110, 0.016, 0.082), PLASTIC_DARK, 0.5)
	body.position = Vector3(0, 0.008, 0)
	root.add_child(body)
	var pan := _box(Vector3(0.088, 0.0018, 0.062), Color("7e858a"), 0.58)
	pan.position = Vector3(0, 0.0169, -0.006)
	root.add_child(pan)
	var screen := _box(Vector3(0.034, 0.0012, 0.014), Color("0f2a22"), 0.2)
	var lit := screen.material_override as StandardMaterial3D
	lit.emission_enabled = true
	lit.emission = Color("57d39a")
	lit.emission_energy_multiplier = 0.9
	screen.position = Vector3(0, 0.0167, 0.031)
	screen.name = "readout"
	root.add_child(screen)


## --- primitives ----------------------------------------------------------

static func _box(size: Vector3, tint: Color, roughness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(tint, roughness)
	return node


static func _cylinder(radius: float, height: float, tint: Color, roughness: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(tint, roughness)
	return node


static func _material(tint: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = 0.0
	return material


static func _clarify(node: MeshInstance3D, alpha: float) -> void:
	var material := node.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(material.albedo_color.r, material.albedo_color.g, material.albedo_color.b, alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
