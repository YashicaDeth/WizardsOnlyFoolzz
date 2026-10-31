extends RefCounted
## The facility tunnel kit (art-tunnels-07): modular pieces on the 4 m grid of
## DESIGN/FACILITY.md (4 m wide, 4 m tall inside), so any two pieces placed in
## neighbouring cells meet face to face with no gap.
##
## A piece is a cell with a set of open sides (n = -Z, e = +X, s = +Z, w = -X).
## Its shell (floor, ceiling, solid walls on every closed side, with collision)
## is exact geometry built here; the surfaces wear the house-style tileable
## textures (world-triplanar, so the tiling runs on across pieces), and the
## generated Higgsfield models dress it (ribs at the cell joints, lamp cages,
## pipe runs, vent grates, bulkheads, the door frame). A missing model only
## loses its dressing; the shell still stands.
##
##   straight  two opposite sides      corner    two adjacent sides
##   t         three sides             cross     all four
##   dead_end  one side (a bulkhead)   door      straight + a sliding door
##   pipe_run  straight + pipe/cable run along one wall
##   vent      dead end with a vent grate in the end wall
##
## No class_name on purpose (see generated_model.gd); callers preload this.

const GENERATED_MODEL := preload("res://systems/generated_model.gd")
const DOOR := preload("res://systems/facility_tunnel_door.gd")

const CELL := 4.0
const HEIGHT := 4.0
const WALL := 0.3
const SLAB := 0.4
## Texels: one 512 px tile every 2 m, 256 px a metre: PS2 crunch.
const TILE_METRES := 2.0

const SIDES := {"n": Vector3(0, 0, -1), "e": Vector3(1, 0, 0), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0)}
const KINDS := ["straight", "corner", "t", "cross", "dead_end", "door", "pipe_run", "vent"]

## The authored tunnel models remain, but the large repeating surfaces use the
## existing ambientCG CC0 sets from the mechanics lab: real grime at corridor
## scale instead of a stretched flat box or newly generated imagery.
const TEXTURES := {
	"wall": {
		"albedo": "res://art/textures/lab/Rust004_Color.jpg",
		"normal": "res://art/textures/lab/Rust004_NormalGL.jpg",
		"roughness": "res://art/textures/lab/Rust004_Roughness.jpg",
		"metallic": "res://art/textures/lab/Rust004_Metalness.jpg",
	},
	"floor": {
		"albedo": "res://art/textures/lab/Concrete034_Color.jpg",
		"normal": "res://art/textures/lab/Concrete034_NormalGL.jpg",
		"roughness": "res://art/textures/lab/Concrete034_Roughness.jpg",
	},
	"ceiling": {
		"albedo": "res://art/textures/lab/MetalPlates006_Color.jpg",
		"normal": "res://art/textures/lab/MetalPlates006_NormalGL.jpg",
		"roughness": "res://art/textures/lab/MetalPlates006_Roughness.jpg",
		"metallic": "res://art/textures/lab/MetalPlates006_Metalness.jpg",
	},
	"door": {
		"albedo": "res://art/textures/lab/PaintedMetal009_Color.jpg",
		"normal": "res://art/textures/lab/PaintedMetal009_NormalGL.jpg",
		"roughness": "res://art/textures/lab/PaintedMetal009_Roughness.jpg",
		"metallic": "res://art/textures/lab/PaintedMetal009_Metalness.jpg",
	},
}
const FALLBACK := {"wall": Color("231a14"), "floor": Color("1d1915"), "ceiling": Color("100d0b"), "door": Color("2a1510")}
const LAMP_GAIN := 2.2
## Dial: false restores the generated tunnel_lift_cab cage inside each car.
const V01_PLAIN_CAB := true
const TINT := {"wall": Color("806d60"), "floor": Color("706a63"), "ceiling": Color("605c56"), "door": Color("806b5a")}

static var _materials := {}


## Which open-side patterns each kind accepts (any rotation of them).
static func valid_openings(kind: String, open: String) -> bool:
	var count := open.length()
	var opposite := (open.contains("n") and open.contains("s")) or (open.contains("e") and open.contains("w"))
	match kind:
		"straight", "door", "pipe_run":
			return count == 2 and opposite
		"corner":
			return count == 2 and not opposite
		"t":
			return count == 3
		"cross":
			return count == 4
		"dead_end", "vent":
			return count == 1
	return false


## `moving` = for a part that slides (a door leaf): mapped on the object, not
## the world, so its plate does not swim as it moves.
static func material(surface: String, moving := false) -> StandardMaterial3D:
	var key := surface + ("_moving" if moving else "")
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.roughness = 0.88
	made.metallic = 0.15 if surface != "floor" else 0.05
	var set: Dictionary = TEXTURES[surface]
	var path: String = set["albedo"]
	if ResourceLoader.exists(path):
		made.albedo_color = TINT[surface]
		made.albedo_texture = load(path)
		if set.has("normal") and ResourceLoader.exists(set["normal"]):
			made.normal_enabled = true
			made.normal_texture = load(set["normal"])
		if set.has("roughness") and ResourceLoader.exists(set["roughness"]):
			made.roughness_texture = load(set["roughness"])
		if set.has("metallic") and ResourceLoader.exists(set["metallic"]):
			made.metallic_texture = load(set["metallic"])
		made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		made.uv1_triplanar = true
		made.uv1_world_triplanar = not moving
		made.uv1_scale = Vector3.ONE / TILE_METRES
	else:
		made.albedo_color = FALLBACK[surface]
	_materials[key] = made
	return made


## One piece, centred on its cell at floor height (origin = floor centre).
## `reach` extends the floor, ceiling and side walls past each open side that
## meets a room rather than another cell: {"w": 0.75} closes a 0.75 m collar.
## `lamp` > 0 hangs a lamp of that energy (0 = a dark cell between pools).
static func build(kind: String, open: String, reach := {}, lamp := 1.8) -> Node3D:
	assert(KINDS.has(kind) and valid_openings(kind, open), "%s cannot open %s" % [kind, open])
	var piece := Node3D.new()
	piece.name = kind
	piece.set_meta("kind", kind)
	piece.set_meta("open", open)
	var half := CELL * 0.5
	var lo := Vector2(-half, -half)
	var hi := Vector2(half, half)
	for side: String in reach:
		match side:
			"w": lo.x -= float(reach[side])
			"e": hi.x += float(reach[side])
			"n": lo.y -= float(reach[side])
			"s": hi.y += float(reach[side])
	var size := hi - lo
	var mid := (lo + hi) * 0.5
	_slab(piece, Vector3(size.x, SLAB, size.y), Vector3(mid.x, -SLAB * 0.5, mid.y), "floor")
	_slab(piece, Vector3(size.x, SLAB, size.y), Vector3(mid.x, HEIGHT + SLAB * 0.5, mid.y), "ceiling")
	for side: String in SIDES:
		if open.contains(side):
			continue
		var normal: Vector3 = SIDES[side]
		# Closed side: a wall on the cell edge, running the cell's (reached) length.
		if normal.x != 0.0:
			_slab(piece, Vector3(WALL, HEIGHT, size.y), Vector3(normal.x * (half + WALL * 0.5), HEIGHT * 0.5, mid.y), "wall")
		else:
			_slab(piece, Vector3(size.x, HEIGHT, WALL), Vector3(mid.x, HEIGHT * 0.5, normal.z * (half + WALL * 0.5)), "wall")
	_dress(piece, kind, open)
	if lamp > 0.0:
		_lamp(piece, lamp)
	return piece


static func _dress(piece: Node3D, kind: String, open: String) -> void:
	# One steel rib on every joint between two cells, so the seam reads as
	# structure: each piece rings its own east and south openings (its
	# neighbour rings the other two), sitting exactly on the cell edge.
	for side: String in ["e", "s"]:
		if open.contains(side):
			var normal: Vector3 = SIDES[side]
			_model(piece, "tunnel_rib", normal * CELL * 0.5, _facing(normal))
	var along := "ns" if open.contains("n") or open.contains("s") else "ew"
	match kind:
		"pipe_run":
			# Along the east (or north) wall, its top at shoulder height.
			var wall_normal := Vector3(1, 0, 0) if along == "ns" else Vector3(0, 0, -1)
			var run_dir := Vector3(0, 0, 1) if along == "ns" else Vector3(1, 0, 0)
			_model(piece, "tunnel_pipe_run", wall_normal * (CELL * 0.5 - 0.27) + Vector3(0, 2.4, 0), _facing(run_dir))
		"dead_end":
			var back: Vector3 = -SIDES[open]
			_model(piece, "tunnel_bulkhead", back * (CELL * 0.5 - 0.22), _facing(-back))
		"vent":
			var back: Vector3 = -SIDES[open]
			_model(piece, "tunnel_vent", back * (CELL * 0.5 - 0.14) + Vector3(0, 1.05, 0), _facing(-back))
		"door":
			var axis := Vector3(0, 0, 1) if along == "ns" else Vector3(1, 0, 0)
			var door := DOOR.new()
			door.name = "Door"
			piece.add_child(door)
			door.setup(axis)


## Dresses a FacilityElevator in the kit: shaft walls and landing frames wear
## the tunnel wall texture, landing door leaves the door plate, and the cab
## gets the generated cage inside its walls. Light strips and the floor
## indicators keep their own materials; nothing about the ride changes.
static func dress_lift(lift: Node3D) -> void:
	for child in lift.get_children():
		if child is StaticBody3D:
			for part in child.get_children():
				# The Cab is an AnimatableBody3D (a StaticBody3D) too; the
				# floor readout's lit panel keeps its own glass (map-84).
				if part is MeshInstance3D and not part.has_meta("own_material"):
					(part as MeshInstance3D).material_override = material("wall")
		elif child is AnimatableBody3D and child.name != "Cab":
			for part in child.get_children():
				if part is MeshInstance3D:
					(part as MeshInstance3D).material_override = material("door", true)
	# The generated cab cage read as torn foil and blocked the side slots the
	# shaft is meant to pass by in; the car wears the kit's steel instead.
	var cab := lift.get("cab") as Node3D
	if cab != null:
		for part in cab.get_children():
			if part is MeshInstance3D and not part.has_meta("own_material"):
				(part as MeshInstance3D).material_override = material("wall", true)
			elif part is AnimatableBody3D:
				for leaf in part.get_children():
					if leaf is MeshInstance3D:
						(leaf as MeshInstance3D).material_override = material("door", true)
		if not V01_PLAIN_CAB:
			var cage := GENERATED_MODEL.make("tunnel_lift_cab")
			if cage != null:
				cab.add_child(cage)


## A world-facing basis: local +Z looks along `forward`, +Y stays up.
static func _facing(forward: Vector3) -> Basis:
	return Basis.looking_at(-forward, Vector3.UP)


static func _model(piece: Node3D, model_name: String, at: Vector3, turn: Basis) -> void:
	var model := GENERATED_MODEL.make(model_name)
	if model == null:
		return
	model.transform = Transform3D(turn, at)
	model.set_meta("kit_model", model_name)
	piece.add_child(model, true)


static func _lamp(piece: Node3D, energy: float) -> void:
	_model(piece, "tunnel_lamp", Vector3(0, HEIGHT, 0), Basis.IDENTITY)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = Color("d2ecc0")
	# Layout energies were set for a steep falloff that left the artery black
	# in render; the low-falloff pool needs about twice the energy.
	lamp.light_energy = energy * LAMP_GAIN
	# Short reach and a steep falloff: pools of light with dark between them
	# (the Shade's light/dark visibility reads these).
	lamp.omni_range = 5.0
	lamp.omni_attenuation = 0.9
	lamp.shadow_enabled = true
	lamp.position = Vector3(0, HEIGHT - 0.7, 0)
	piece.add_child(lamp)


static func _slab(piece: Node3D, size: Vector3, at: Vector3, surface: String) -> void:
	var body := StaticBody3D.new()
	body.name = surface.capitalize()
	body.position = at
	body.set_meta("surface", "metal" if surface == "wall" else "concrete")
	piece.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material(surface)
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
