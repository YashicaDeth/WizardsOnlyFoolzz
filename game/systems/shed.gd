class_name Shed
extends Node3D

## AU3.1. "A shed, not a void — enclosed, dingy, lit by what is in it."
##
## Everything AU3 needs already existed except the room. `substance_objects.gd`
## builds what is on the bench, `smokeables.gd` builds what you pick up off it,
## and the gore sandbox supplies bodies and a reset. All of it has been sitting
## on a floating slab in a black void, which is a product shot, not a place.
##
## The brief is four words and every one of them is a constraint:
##
## **A shed** — 3.2m by 2.4m, which is a real shed and not a room pretending to
## be one. You can touch both walls. That matters more than any texture: the
## reason a shed feels like a shed is that it is too small for what is in it.
##
## **Not a void** — it is closed. Four walls, a roof with a fall on it, a door,
## and one window with the glass long gone. The seams between the wall sheets
## are left open on purpose (`GAP`), because a shed you can see daylight through
## is the difference between a building and a box.
##
## **Dingy** — nothing in here is clean and nothing is square. Every panel gets
## a seeded nudge off true, so the walls read as sheets somebody screwed up in
## an afternoon rather than as a mesh.
##
## **Lit by what is in it** — one bulb on a flex, and that is the entire
## lighting design. It is the only thing in this file that emits. A lamp you
## carry (AS) and a lit cigarette (AU7.5) are the only other light that will
## ever be in here, which is exactly the point of putting the drugs somewhere
## enclosed: you have to choose between seeing and having a free hand.
##
## Owns no gameplay. It builds geometry and hands back the anchors — `bench`,
## `floor_centre`, `door` — that the lab scene and AU3.5's range hang off.

const SubstanceObjects := preload("res://systems/substance_objects.gd")
const Smokeables := preload("res://systems/smokeables.gd")
const SubstanceStation := preload("res://systems/substance_station.gd")

const WIDTH := 3.2
const DEPTH := 2.4
const WALL_HEIGHT := 2.05
const RIDGE_RISE := 0.34

## Corrugated sheet, in the metric a real one comes in.
const SHEET_WIDTH := 0.76
const CORRUGATION := 0.076
const GAP := 0.006

const TIN := Color("6a6e6c")
const TIN_RUST := Color("6e4526")
const STUD := Color("4a3a29")
const CONCRETE := Color("44423e")
const STAIN := Color("2b2a26")
const BULB := Color("ffd39a")

var bench: Node3D
var door: Node3D
var station: Node3D
var floor_centre := Vector3.ZERO

var _rng := RandomNumberGenerator.new()


## `seed_value` makes the whole shed deterministic — the same shed every time
## you walk back into it, which is the guarantee `seal_strokes()` and
## `roll_strain()` already make for their own objects. A room that re-rolls its
## own dents on every load is a room nobody can learn.
func build(seed_value := 7717) -> void:
	_rng.seed = seed_value
	_build_floor()
	_build_walls()
	_build_roof()
	_build_bench()
	_build_shelf()
	_build_clutter()
	_build_bulb()
	_dress_bench()


func _build_floor() -> void:
	var slab := _box(Vector3(WIDTH, 0.06, DEPTH), CONCRETE, 0.96)
	slab.position = Vector3(0, -0.03, 0)
	add_child(slab)
	# Stains rather than a texture: flat quads a shade darker, pooled where
	# things get spilled — under the bench and by the door.
	for stain in 7:
		var size := _rng.randf_range(0.18, 0.52)
		var patch := _box(Vector3(size, 0.002, size * _rng.randf_range(0.6, 1.3)), STAIN, 0.99)
		patch.position = Vector3(
			_rng.randf_range(-WIDTH * 0.42, WIDTH * 0.42), 0.001,
			_rng.randf_range(-DEPTH * 0.40, DEPTH * 0.40),
		)
		patch.rotation = Vector3(0, _rng.randf_range(0.0, TAU), 0)
		add_child(patch)


func _build_walls() -> void:
	# Back and front run the long way; left and right close the ends. The front
	# wall is short by a door.
	_sheet_wall(Vector3(0, 0, -DEPTH * 0.5), 0.0, WIDTH, false)
	_sheet_wall(Vector3(0, 0, DEPTH * 0.5), PI, WIDTH, true)
	_sheet_wall(Vector3(-WIDTH * 0.5, 0, 0), PI * 0.5, DEPTH, false)
	_sheet_wall(Vector3(WIDTH * 0.5, 0, 0), -PI * 0.5, DEPTH, false)


## One wall, built out of sheets with a gap between each. The gaps are the
## point: a solid extrusion reads as a wall in a game, and a row of sheets with
## light between them reads as a shed.
func _sheet_wall(at: Vector3, turn: float, span: float, has_door: bool) -> void:
	var wall := Node3D.new()
	wall.position = at
	wall.rotation = Vector3(0, turn, 0)
	add_child(wall)

	var count := int(ceil(span / SHEET_WIDTH))
	var door_from := span * 0.5 - 1.35
	var door_to := span * 0.5 - 0.42
	for index in count:
		var x := -span * 0.5 + (float(index) + 0.5) * SHEET_WIDTH
		if has_door and x > door_from and x < door_to:
			continue
		_sheet(wall, x, SHEET_WIDTH - GAP)

	# Studs behind the sheets, visible through the gaps.
	for index in count + 1:
		var stud := _box(Vector3(0.045, WALL_HEIGHT, 0.045), STUD, 0.94)
		stud.position = Vector3(-span * 0.5 + float(index) * SHEET_WIDTH, WALL_HEIGHT * 0.5, -0.05)
		add_child_to(wall, stud)

	if has_door:
		_build_door(wall, (door_from + door_to) * 0.5, door_to - door_from)
		# The window: a hole two sheets along with nothing in it.
		var lintel := _box(Vector3(0.62, 0.05, 0.05), STUD, 0.94)
		lintel.position = Vector3(-span * 0.5 + 0.95, 1.52, -0.05)
		add_child_to(wall, lintel)


func _sheet(wall: Node3D, x: float, width: float) -> void:
	var panel := Node3D.new()
	panel.position = Vector3(x, WALL_HEIGHT * 0.5, 0)
	# Nothing is square. A degree and a half is enough to read and not enough to
	# look broken.
	panel.rotation = Vector3(0, 0, _rng.randf_range(-0.026, 0.026))
	add_child_to(wall, panel)

	var ribs := maxi(2, int(width / CORRUGATION))
	var rust := _rng.randf() < 0.34
	for rib in ribs:
		var deep := rib % 2 == 0
		var tint := (TIN_RUST if rust else TIN).lerp(Color.BLACK, _rng.randf_range(0.0, 0.22))
		# Every seam sits behind a stud, so a shed built only of whole sheets
		# has no daylight in it anywhere - which was the first build, and it
		# read as a panelled room rather than as tin. A few ribs are simply
		# gone instead: a slat that has come off leaves a real slot through to
		# the outside, in the middle of a sheet where nothing is framing it.
		if _rng.randf() < 0.07:
			continue
		var slat := _box(
			Vector3(CORRUGATION - 0.004, WALL_HEIGHT - _rng.randf_range(0.0, 0.03), 0.014 if deep else 0.022),
			tint, 0.54, 0.5,
		)
		slat.position = Vector3(
			-width * 0.5 + (float(rib) + 0.5) * CORRUGATION, 0.0,
			-0.004 if deep else 0.0,
		)
		add_child_to(panel, slat)


func _build_door(wall: Node3D, x: float, width: float) -> void:
	door = Node3D.new()
	door.name = "door"
	# Hung off one edge and standing open, because it always is.
	door.position = Vector3(x - width * 0.5, 0, 0)
	door.rotation = Vector3(0, deg_to_rad(-38.0), 0)
	add_child_to(wall, door)

	var leaf := Node3D.new()
	leaf.position = Vector3(width * 0.5, WALL_HEIGHT * 0.5 - 0.06, 0)
	add_child_to(door, leaf)
	var ribs := int(width / CORRUGATION)
	for rib in ribs:
		var slat := _box(Vector3(CORRUGATION - 0.004, WALL_HEIGHT - 0.12, 0.018), TIN.darkened(0.14), 0.9)
		slat.position = Vector3(-width * 0.5 + (float(rib) + 0.5) * CORRUGATION, 0, 0)
		add_child_to(leaf, slat)
	# A brace across it, and a hasp with no lock on it.
	var brace := _box(Vector3(width * 1.02, 0.07, 0.022), STUD, 0.92)
	brace.rotation = Vector3(0, 0, deg_to_rad(19.0))
	brace.position = Vector3(0, 0, 0.019)
	add_child_to(leaf, brace)
	var hasp := _box(Vector3(0.09, 0.035, 0.006), Color("7b7a74"), 0.5)
	hasp.position = Vector3(width * 0.44, -0.10, 0.024)
	add_child_to(leaf, hasp)


func _build_roof() -> void:
	# A fall on it, not a flat lid. Two planes meeting off-centre, because a
	# lean-to is what a shed this size actually has.
	for side in [-1.0, 1.0]:
		var plane := Node3D.new()
		var pitch := atan2(RIDGE_RISE, DEPTH * 0.5)
		plane.rotation = Vector3(side * pitch, 0, 0)
		plane.position = Vector3(0, WALL_HEIGHT + RIDGE_RISE * 0.5, side * DEPTH * 0.25)
		add_child(plane)
		var length := sqrt(pow(DEPTH * 0.5, 2.0) + pow(RIDGE_RISE, 2.0))
		var ribs := int(WIDTH / CORRUGATION)
		for rib in ribs:
			var deep := rib % 2 == 0
			var slat := _box(
				Vector3(CORRUGATION - 0.004, 0.016 if deep else 0.024, length),
				TIN_RUST.lerp(TIN, _rng.randf_range(0.2, 0.9)), 0.58, 0.45,
			)
			slat.position = Vector3(-WIDTH * 0.5 + (float(rib) + 0.5) * CORRUGATION, 0, 0)
			add_child_to(plane, slat)


func _build_bench() -> void:
	bench = Node3D.new()
	bench.name = "bench"
	bench.position = Vector3(0, 0, -DEPTH * 0.5 + 0.34)
	add_child(bench)

	var top := _box(Vector3(2.30, 0.038, 0.58), Color("4b3826"), 0.95)
	top.position = Vector3(0, 0.86, 0)
	add_child_to(bench, top)
	# Planks, so the top is boards and not a slab.
	for plank in 5:
		var board := _box(Vector3(2.30, 0.006, 0.108), Color("54402c").lerp(Color("3a2b1d"), _rng.randf()), 0.96)
		board.position = Vector3(0, 0.881, -0.232 + float(plank) * 0.116)
		add_child_to(bench, board)
	for side in [-1.0, 1.0]:
		for front in [-1.0, 1.0]:
			var leg := _box(Vector3(0.072, 0.86, 0.072), STUD, 0.94)
			leg.position = Vector3(side * 1.06, 0.43, front * 0.23)
			add_child_to(bench, leg)
	var rail := _box(Vector3(2.10, 0.05, 0.05), STUD, 0.94)
	rail.position = Vector3(0, 0.24, 0.20)
	add_child_to(bench, rail)
	floor_centre = Vector3(0, 0, 0.25)


func _build_shelf() -> void:
	for level in 2:
		var shelf := _box(Vector3(1.30, 0.028, 0.26), Color("4b3826"), 0.95)
		shelf.position = Vector3(-WIDTH * 0.5 + 0.68, 1.32 + float(level) * 0.42, -DEPTH * 0.5 + 0.15)
		add_child(shelf)
		for bracket in [-0.55, 0.55]:
			var arm := _box(Vector3(0.03, 0.16, 0.22), Color("55534d"), 0.6)
			arm.position = shelf.position + Vector3(bracket, -0.09, 0.0)
			add_child(arm)
		# Tins on the shelf, in a row that is not a row.
		for tin_index in 4:
			var tin := _cylinder(_rng.randf_range(0.042, 0.062), _rng.randf_range(0.11, 0.17),
				Color("6c6a5e").lerp(TIN_RUST, _rng.randf()), 0.86)
			tin.position = shelf.position + Vector3(
				-0.48 + float(tin_index) * 0.29 + _rng.randf_range(-0.03, 0.03),
				0.085, _rng.randf_range(-0.03, 0.03),
			)
			add_child(tin)


func _build_clutter() -> void:
	# A stool, a jerry can and two boxes. Enough that the floor is not empty and
	# little enough that you can still get to the bench.
	var stool_top := _cylinder(0.155, 0.032, Color("4b3826"), 0.94)
	stool_top.position = Vector3(0.42, 0.56, 0.30)
	add_child(stool_top)
	for leg_index in 3:
		var angle := TAU * float(leg_index) / 3.0
		var leg := _cylinder(0.018, 0.56, STUD, 0.94)
		leg.rotation = Vector3(sin(angle) * 0.09, 0, -cos(angle) * 0.09)
		leg.position = Vector3(0.42 + sin(angle) * 0.10, 0.28, 0.30 + cos(angle) * 0.10)
		add_child(leg)

	var can := _box(Vector3(0.17, 0.34, 0.11), Color("4d5a3f"), 0.82)
	can.position = Vector3(-WIDTH * 0.5 + 0.22, 0.17, DEPTH * 0.5 - 0.34)
	can.rotation = Vector3(0, deg_to_rad(23.0), 0)
	add_child(can)
	var spout := _cylinder(0.022, 0.09, Color("3f4a35"), 0.8)
	spout.rotation = Vector3(deg_to_rad(30.0), 0, 0)
	spout.position = can.position + Vector3(0.0, 0.19, 0.03)
	add_child(spout)

	for box_index in 2:
		var carton := _box(
			Vector3(_rng.randf_range(0.32, 0.44), _rng.randf_range(0.22, 0.30), _rng.randf_range(0.26, 0.36)),
			Color("7a6446").lerp(STAIN, _rng.randf_range(0.1, 0.4)), 0.97,
		)
		carton.position = Vector3(
			WIDTH * 0.5 - 0.34, 0.13 + float(box_index) * 0.25, DEPTH * 0.5 - 0.48 + float(box_index) * 0.06,
		)
		carton.rotation = Vector3(0, _rng.randf_range(-0.4, 0.4), 0)
		add_child(carton)


## The whole lighting design. One bulb on a flex, off-centre because nobody
## measured, and the only emitter in the file.
func _build_bulb() -> void:
	var flex := _cylinder(0.004, 0.42, Color("1b1b1b"), 0.9)
	flex.position = Vector3(0.18, WALL_HEIGHT + RIDGE_RISE * 0.5 - 0.21, -0.12)
	add_child(flex)

	var holder := _cylinder(0.026, 0.055, Color("d8d2c4"), 0.6)
	holder.position = Vector3(0.18, WALL_HEIGHT + RIDGE_RISE * 0.5 - 0.44, -0.12)
	add_child(holder)

	var glass := SphereMesh.new()
	glass.radius = 0.031
	glass.height = 0.070
	glass.radial_segments = 14
	glass.rings = 8
	var bulb := MeshInstance3D.new()
	bulb.mesh = glass
	var hot := StandardMaterial3D.new()
	hot.albedo_color = BULB
	hot.emission_enabled = true
	hot.emission = BULB
	hot.emission_energy_multiplier = 7.0
	bulb.material_override = hot
	bulb.position = Vector3(0.18, WALL_HEIGHT + RIDGE_RISE * 0.5 - 0.50, -0.12)
	bulb.name = "bulb"
	add_child(bulb)

	var light := OmniLight3D.new()
	light.name = "bulb_light"
	light.light_color = BULB
	light.light_energy = 3.4
	light.omni_range = 4.6
	light.shadow_enabled = true
	light.position = bulb.position
	add_child(light)


## AU3.2. The bench is dressed by the same `SubstanceStation` the sandbox and
## the Hunt Grounds drop, with its own table suppressed because the shed already
## has one. This used to lay the objects out itself, which meant the shed and
## every other place that wanted them were three lists that had to be kept in
## agreement by hand - the exact shape of the E2 problem.
func _dress_bench() -> void:
	station = SubstanceStation.new()
	bench.add_child(station)
	station.build(false)


## --- primitives ----------------------------------------------------------

func add_child_to(parent: Node3D, node: Node3D) -> void:
	parent.add_child(node)


func _box(size: Vector3, tint: Color, roughness: float, metallic := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(tint, roughness, metallic)
	return node


func _cylinder(radius: float, height: float, tint: Color, roughness: float, metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(tint, roughness, metallic)
	return node


func _material(tint: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = metallic
	return material
