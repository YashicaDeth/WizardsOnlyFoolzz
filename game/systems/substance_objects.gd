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

## Which shape each catalogued form gets.
const FORMS := ["baggie", "weight", "tab", "blister"]

## The contents colour per substance, so a bag of ground bone and a bag of
## anything else are not the same prop with a different label.
const FILL := {
	"marrow_dust": Color("d9d2c0"),
	"choir_bloom": Color("6c7a41"),
	"static_hymn": Color("3d4348"),
}

## What the substance physically *is*, at the scale you can see it. `coarse` is
## the size of one grain: Marrow Dust is cut bone and therefore chips and
## splinters rather than flour, which is the difference between a bag that reads
## as ground bone and a bag that reads as sugar.
const GRAIN := {
	"marrow_dust": {"chip": Color("ece5d2"), "dark": Color("978a71"), "coarse": 0.0042},
	"choir_bloom": {"chip": Color("87954f"), "dark": Color("39431f"), "coarse": 0.0048},
	"static_hymn": {"chip": Color("656d75"), "dark": Color("23272b"), "coarse": 0.0030},
}


## Greg, on this whole game: *"everything looks like boxes"*. That was literally
## true here — a pressed weight of Choir Bloom, a fungal graft the Choir grows on
## purpose, was a green box with a lighter green box on top of it, and the only
## thing separating it from a bag of ground bone was the hex code.
##
## The rule that replaces "form decides the shape, substance decides the colour":
## **where the substance IS the object, the substance decides the silhouette.** A
## cultivated graft is not a brick; a dose somebody scrapes off a blown speaker
## is not a square of card. Only where the container genuinely is the object — a
## press-seal bag, a foil blister — does the form still lead, and even then what
## is inside it is built as matter with grain and lumps rather than as a slab in
## a tint.
##
## Silhouette is the test, because silhouette is what survives distance: each of
## these has to be nameable from across the shed with the colour taken away.
static func build(form: String, substance_id := "") -> Node3D:
	var root := Node3D.new()
	root.name = form
	var fill: Color = FILL.get(substance_id, POWDER_BONE)
	match form:
		"baggie":
			_build_baggie(root, fill, substance_id)
		"weight":
			if substance_id == "choir_bloom":
				_build_graft(root, fill)
			else:
				_build_weight(root, fill, substance_id)
		"tab":
			if substance_id == "static_hymn":
				_build_cone(root, fill)
			else:
				_build_tab(root, fill)
		"blister":
			_build_blister(root, fill, substance_id)
		_:
			_build_baggie(root, fill, substance_id)
	return root


## A press-seal bag, 55mm, sat slumped. Every part of this is a curve: the
## contents pool into a sagging pillow, the bag skin follows it, the empty top
## gathers into a twist. The old version was three boxes and a flap and it
## photographed as a white rectangle at any distance over half a metre —
## a bag has *no* straight edges, which is precisely how you know it is soft.
##
## What is in it is built as grain, not as a fill colour: Marrow Dust is cut
## cortical bone, so the bag holds chips and splinters of visibly different
## sizes and the smallest of them have spilled onto the table.
static func _build_baggie(root: Node3D, fill: Color, substance_id := "") -> void:
	var grain: Dictionary = GRAIN.get(substance_id, GRAIN["marrow_dust"])
	var chip: Color = grain["chip"]
	var dark: Color = grain["dark"]
	var coarse: float = grain["coarse"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("baggie" + substance_id)

	# The pool of contents. Sunk below the table plane so the bottom of the
	# ellipsoid is cut off and it reads as slumped under its own weight rather
	# than as an egg balanced on a bench.
	var pool := _blob(Vector3(0.050, 0.026, 0.032), fill.darkened(0.05), 0.96)
	pool.position = Vector3(0, 0.0085, 0)
	root.add_child(pool)
	# A second, smaller heap offset to one side, because contents settle
	# unevenly and one lump is a shape while two lumps are a substance.
	var heap := _blob(Vector3(0.028, 0.020, 0.022), fill, 0.96)
	heap.position = Vector3(-0.011, 0.0105, 0.002)
	root.add_child(heap)

	# The grain itself, breaking the surface of the pool.
	for _piece in 14:
		var angle := rng.randf_range(0.0, TAU)
		var reach := rng.randf_range(0.0, 0.020)
		var size := coarse * rng.randf_range(0.55, 1.5)
		var shard := _box(
			Vector3(size, size * rng.randf_range(0.3, 0.7), size * rng.randf_range(0.5, 1.3)),
			chip.lerp(dark, rng.randf_range(0.0, 0.55)), 0.97,
		)
		shard.rotation = Vector3(rng.randf_range(-0.6, 0.6), angle, rng.randf_range(-0.6, 0.6))
		shard.position = Vector3(
			sin(angle) * reach, 0.0155 - reach * 0.22, cos(angle) * reach * 0.62,
		)
		root.add_child(shard)

	# The bag skin: the same slumped shape one millimetre proud of the contents,
	# clear, and closed so its own back faces cannot sort over what it contains.
	var skin := _blob(Vector3(0.055, 0.030, 0.036), PLASTIC_CLEAR, 0.34, 14)
	_clarify(skin, 0.22)
	(skin.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
	skin.position = Vector3(0, 0.0085, 0)
	root.add_child(skin)

	# The empty top gathered into a twist — a taper, not a flap. This is the
	# silhouette detail: a pinched crown over a soft body says "bag" from a
	# distance where nothing else on the object is resolvable.
	var neck := _taper(0.0035, 0.014, 0.014, PLASTIC_CLEAR, 0.36)
	_clarify(neck, 0.26)
	neck.rotation = Vector3(0, 0, deg_to_rad(13.0))
	neck.position = Vector3(0.002, 0.0245, 0.001)
	root.add_child(neck)
	var twist := _taper(0.0022, 0.0042, 0.009, PLASTIC_CLEAR, 0.36)
	_clarify(twist, 0.32)
	twist.rotation = Vector3(deg_to_rad(18.0), 0, deg_to_rad(34.0))
	twist.position = Vector3(0.006, 0.0335, 0.001)
	root.add_child(twist)

	# The zip: two ribs, which is the detail that makes it a press-seal and not
	# a sandwich bag.
	for side in [-0.0018, 0.0018]:
		var rib := _box(Vector3(0.042, 0.0016, 0.0014), PLASTIC_CLEAR.darkened(0.16), 0.3)
		_clarify(rib, 0.7)
		rib.position = Vector3(0, 0.0225, side)
		root.add_child(rib)

	# What got spilled getting it open. A bag nobody has opened is stock; a bag
	# with dust beside it is somebody's.
	for spill in 3:
		var dust := _blob(
			Vector3(0.016 - float(spill) * 0.004, 0.0012, 0.012 - float(spill) * 0.003),
			chip.darkened(0.12), 0.99, 8,
		)
		dust.position = Vector3(0.034 + float(spill) * 0.012, 0.0004, 0.010 - float(spill) * 0.007)
		root.add_child(dust)


## 28g, pressed and wrapped. Cling wrap is a second skin one millimetre off the
## brick with a different roughness — a single shiny box reads as a bar of soap.
## The corner is torn open and the press is crumbling out of it, so even the one
## form that genuinely is a rectangle is not a *clean* rectangle.
static func _build_weight(root: Node3D, fill: Color, substance_id := "") -> void:
	var grain: Dictionary = GRAIN.get(substance_id, GRAIN["marrow_dust"])
	var chip: Color = grain["chip"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weight" + substance_id)

	var brick := _box(Vector3(0.062, 0.024, 0.042), fill, 0.92)
	brick.position = Vector3(0, 0.012, 0)
	root.add_child(brick)
	# The press is domed, not flat — a mould never fills square at the top.
	var dome := _blob(Vector3(0.058, 0.012, 0.038), fill.lightened(0.05), 0.93)
	dome.position = Vector3(0, 0.0235, 0)
	root.add_child(dome)

	# Cling is scuffed, not polished, and it is a closed box - leaving it
	# double-sided let its own back faces sort over the brick.
	var wrap := _box(Vector3(0.064, 0.027, 0.044), PLASTIC_CLEAR, 0.44)
	_clarify(wrap, 0.13)
	(wrap.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
	wrap.position = Vector3(0, 0.0135, 0)
	root.add_child(wrap)

	# Tape across the seam, because nobody wraps one of these neatly.
	var tape := _box(Vector3(0.068, 0.0022, 0.016), Color("6d6553"), 0.86)
	tape.rotation = Vector3(0, deg_to_rad(6.0), 0)
	tape.position = Vector3(0, 0.0272, 0.004)
	root.add_child(tape)

	# The opened corner and what came out of it.
	var torn := _box(Vector3(0.014, 0.010, 0.013), fill.darkened(0.10), 0.95)
	torn.rotation = Vector3(deg_to_rad(16.0), deg_to_rad(-22.0), deg_to_rad(9.0))
	torn.position = Vector3(0.030, 0.020, 0.019)
	root.add_child(torn)
	for _crumb in 5:
		var size := rng.randf_range(0.0022, 0.0050)
		var crumb := _box(Vector3(size, size * 0.6, size * 0.8), chip, 0.97)
		crumb.rotation = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), 0)
		crumb.position = Vector3(
			rng.randf_range(0.036, 0.058), size * 0.3, rng.randf_range(0.012, 0.030),
		)
		root.add_child(crumb)


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


## `choir_bloom` in the `weight` form. The Choir grows this on purpose, so a
## 28g "weight" of it is a graft lifted off the substrate, not a pressed brick:
## a fused cluster of caps over a short mycelial foot, with the cut face still
## showing where it came away. Silhouette test — lumps over a stalk is nameable
## across the shed with the colour taken away; a rectangle is not.
static func _build_graft(root: Node3D, fill: Color) -> void:
	var grain: Dictionary = GRAIN["choir_bloom"]
	var chip: Color = grain["chip"]
	var dark: Color = grain["dark"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("graft" + "choir_bloom")

	# The foot: what it was cut off at. Wider at the base, and the cut face is
	# paler than the growth because it is the inside of the thing.
	var foot := _taper(0.020, 0.030, 0.014, fill.lightened(0.18), 0.97)
	foot.position = Vector3(0, 0.007, 0)
	root.add_child(foot)

	# The cluster. Five caps of different sizes leaning off one another - one
	# dome is a mushroom, several fused at different angles is a graft.
	for cap in 5:
		var spread := float(cap) / 4.0
		var angle := rng.randf_range(0.0, TAU)
		var size := 0.030 - spread * 0.011
		var lump := _blob(
			Vector3(size, size * rng.randf_range(0.52, 0.74), size * rng.randf_range(0.82, 1.0)),
			fill.lerp(dark, spread * 0.45), 0.95,
		)
		lump.rotation = Vector3(rng.randf_range(-0.34, 0.34), angle, rng.randf_range(-0.34, 0.34))
		lump.position = Vector3(
			sin(angle) * spread * 0.016, 0.019 + spread * 0.007, cos(angle) * spread * 0.013,
		)
		root.add_child(lump)

	# Spores on the caps, which is the detail that says grown rather than made.
	for _fleck in 10:
		var angle := rng.randf_range(0.0, TAU)
		var reach := rng.randf_range(0.004, 0.020)
		var fleck := _blob(Vector3(0.0022, 0.0012, 0.0022), chip, 0.99, 6)
		fleck.position = Vector3(sin(angle) * reach, 0.030 + rng.randf_range(-0.004, 0.004), cos(angle) * reach * 0.8)
		root.add_child(fleck)


## `static_hymn` in the `tab` form. Greg's rule at the top of this file: a dose
## somebody scrapes off a blown speaker is not a square of card. So it is the
## cone itself - a torn wedge of speaker paper with the dose still coned up on
## it where it was scraped into a pile, and the dust ring it left behind.
static func _build_cone(root: Node3D, fill: Color) -> void:
	var grain: Dictionary = GRAIN["static_hymn"]
	var chip: Color = grain["chip"]
	var dark: Color = grain["dark"]
	var coarse: float = grain["coarse"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cone" + "static_hymn")

	# The paper: a shallow dish, because a speaker cone is a cone even when it
	# is a fragment. Cut off below the table plane so it sits as a sliver.
	var paper := _blob(Vector3(0.026, 0.009, 0.026), CARD.darkened(0.42), 0.98, 18)
	paper.position = Vector3(0, 0.0004, 0)
	root.add_child(paper)

	# The dose, scraped into a cone. 12mm across the base, which is a dose and
	# not a serving.
	var heap := _taper(0.0006, 0.0060, 0.0085, fill, 0.98)
	heap.position = Vector3(0, 0.0043, 0)
	root.add_child(heap)

	# What the card edge pushed aside on the way in.
	for _fleck in 9:
		var angle := rng.randf_range(0.0, TAU)
		var reach := rng.randf_range(0.008, 0.019)
		var size := coarse * rng.randf_range(0.6, 1.4)
		var fleck := _box(
			Vector3(size, size * 0.45, size * rng.randf_range(0.6, 1.2)),
			chip.lerp(dark, rng.randf_range(0.0, 0.6)), 0.99,
		)
		fleck.rotation = Vector3(0, angle, 0)
		fleck.position = Vector3(sin(angle) * reach, 0.0006, cos(angle) * reach)
		root.add_child(fleck)

## Foil-backed card. Named in AU1.2 and used by nothing in the catalogue yet —
## built anyway, because the moment a pharmaceutical enters AU it needs to
## already look like one rather than like a baggie with a different label.
static func _build_blister(root: Node3D, fill: Color, substance_id := "") -> void:
	var grain: Dictionary = GRAIN.get(substance_id, GRAIN["marrow_dust"])
	var chip: Color = grain["chip"]
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

			var pill := _box(Vector3(0.0062, 0.0026, 0.0062), fill.lightened(0.28).lerp(chip, 0.4), 0.9)
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

static func _blob(size: Vector3, tint: Color, roughness: float, segments := 20) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.scale = size
	node.material_override = _material(tint, roughness)
	return node


static func _taper(top_radius: float, bottom_radius: float, height: float, tint: Color, roughness: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(tint, roughness)
	return node


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
