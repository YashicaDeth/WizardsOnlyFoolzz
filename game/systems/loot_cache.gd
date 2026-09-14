class_name LootCache
extends RefCounted

## Greg pointed at an orange box in the Hunt Grounds with "LOOT // gate scrip,
## brass knuckle" floating over it. It was exactly what it looked like:
##
##     _add_mesh_to(cache, BoxMesh.new(), Vector3(0, 0.35, 0), Color("c08134"), 0.35)
##
## A default 1x1x1 `BoxMesh`, scaled down, tinted orange. A placeholder that
## shipped, in a game where everything else — the bodies, the cars, the map, the
## typeface — is built out of authored geometry. It is the single most
## unfinished-looking object in the region, and it stands exactly where the
## player is being rewarded, which is the worst possible place for one.
##
## What replaces it is a dropped stash: a scrap plate on the ground, a canvas
## bundle strapped down, and **the actual items sticking out of it**. That last
## part is the point and the reason this is worth real geometry rather than a
## nicer box — the label already lists what is inside, so the model repeating it
## in silhouette means a player learns to read caches at a distance and stops
## needing the label at all. Greg's own standard, from the checklist: nothing
## about a thing is described in text that could be shown on the thing.
##
## Built from `WorldLook.surface()` like the rest of the world, so it takes the
## region's grime and hour rather than being lit as a different object.

## Rough silhouettes for the things the region actually drops. Keys are matched
## as substrings of the item name, so "gate scrip" and "scrip" both find the
## same shape and a new item falls back to a wrapped parcel rather than to
## nothing.
const ITEM_SHAPES := {
	"scrip": "disc",
	"ledger": "slab",
	"knuckle": "bar",
	"torch": "tube",
	"rag": "cloth",
	"chain": "links",
	"coil": "ring",
	"tinned": "tin",
	"wrench": "bar",
	"battery": "tin",
	"cell": "tin",
}

const CANVAS := Color("5c5340")
const STRAP := Color("2e2721")
const PLATE := Color("47403a")
const BRASS := Color("9a7b3c")
const TIN := Color("6e7378")
const PAPER := Color("bfae86")


## The whole cache, parented under `root`. Returns how many pieces it built, in
## the same shape `Silhouette.dress_vehicle` reports, so a caller can budget.
static func build(root: Node3D, items: Array, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var made := 0

	# The plate it sits on — a bit of torn decking, so the stash has a footprint
	# on the ground rather than hovering at an arbitrary height the way the box
	# did (it sat at y 0.35 with nothing under it).
	made += _piece(root, BoxMesh.new(), Vector3(0, 0.035, 0), Vector3(0.52, 0.05, 0.44), PLATE, "rust", rng.randi())

	# The bundle: wider at the base, because a bagged stash slumps. Three
	# stepped-in courses rather than two, and each rotated a little off the last,
	# so the silhouette breaks up instead of reading as a stack of cuboids —
	# which is exactly what the first render came out as.
	made += _stepped(root, Vector3(0, 0.15, 0), Vector3(0.42, 0.21, 0.36), 0.0, rng)
	made += _stepped(root, Vector3(0.01, 0.28, -0.01), Vector3(0.33, 0.12, 0.28), 0.18, rng)
	made += _stepped(root, Vector3(-0.01, 0.355, 0.01), Vector3(0.22, 0.07, 0.19), -0.26, rng)

	# Two straps over the top, crossing. Thin boxes rather than a texture,
	# because everything else in this project is geometry and a painted strap
	# would be the one thing that stops reading at close range.
	# Proud of the canvas, not flush with it — at 0.045 inside a 0.40 bundle they
	# came out as dark slots cut into the side rather than as bands over the top.
	# Tall enough to clear the top course. At 0.235 they topped out at 0.3175,
	# inside the bundle, so they read as dark slots down the flanks rather than
	# as something holding the stash shut.
	made += _piece(root, BoxMesh.new(), Vector3(0, 0.215, 0), Vector3(0.455, 0.375, 0.055), STRAP, "rust", rng.randi())
	made += _piece(root, BoxMesh.new(), Vector3(0, 0.215, 0), Vector3(0.055, 0.375, 0.395), STRAP, "rust", rng.randi())

	# What is in it, sticking out of the top. Spread across the bundle so two
	# items do not occupy the same spot.
	var count: int = mini(items.size(), 3)
	for index in count:
		var name := str(items[index]).to_lower()
		# On top of the stash, not in it. The first pass put these at y 0.33 when
		# the bundle's top surface was 0.355, so every item was buried inside the
		# canvas and only the tallest ones poked out at all.
		var offset := Vector3(
			lerpf(-0.13, 0.13, (float(index) + 0.5) / float(maxi(count, 1))),
			0.42,
			rng.randf_range(-0.04, 0.04))
		made += _item(root, _shape_for(name), offset, rng)

	return made


static func _shape_for(item_name: String) -> String:
	for key: String in ITEM_SHAPES:
		if item_name.contains(key):
			return str(ITEM_SHAPES[key])
	# Anything unrecognised is a wrapped parcel — legible as "something", which
	# is honest, rather than as a specific thing it is not.
	return "parcel"


static func _item(root: Node3D, shape: String, at: Vector3, rng: RandomNumberGenerator) -> int:
	match shape:
		"disc":
			# Scrip: a short stack of stamped discs, standing on edge.
			var made := 0
			for layer in 3:
				var disc := CylinderMesh.new()
				disc.top_radius = 0.062
				disc.bottom_radius = 0.062
				disc.height = 0.013
				made += _mesh(root, disc, at + Vector3(0, 0.01 * float(layer), 0.004 * float(layer)),
					Vector3(0.5, 1.0, 0.0), BRASS, "chrome", rng.randi())
			return made
		"slab":
			return _piece(root, BoxMesh.new(), at, Vector3(0.17, 0.045, 0.13), PAPER, "paper", rng.randi())
		"bar":
			return _piece(root, BoxMesh.new(), at, Vector3(0.15, 0.05, 0.06), BRASS, "chrome", rng.randi())
		"tube":
			var tube := CylinderMesh.new()
			tube.top_radius = 0.034
			tube.bottom_radius = 0.040
			tube.height = 0.26
			return _mesh(root, tube, at, Vector3(0.35, 1.0, 0.0), TIN, "chrome", rng.randi())
		"tin":
			var tin := CylinderMesh.new()
			tin.top_radius = 0.052
			tin.bottom_radius = 0.052
			tin.height = 0.105
			return _mesh(root, tin, at, Vector3.ZERO, TIN, "chrome", rng.randi())
		"ring":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.042
			ring.outer_radius = 0.072
			return _mesh(root, ring, at, Vector3(0.4, 0.0, 0.2), TIN, "chrome", rng.randi())
		"links":
			var made := 0
			for link in 4:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.014
				ring.outer_radius = 0.026
				made += _mesh(root, ring, at + Vector3(0.028 * float(link), -0.012 * float(link), 0.0),
					Vector3(0.0, 0.0, 1.2), TIN, "rust", rng.randi())
			return made
		"cloth":
			return _piece(root, BoxMesh.new(), at, Vector3(0.11, 0.02, 0.09), CANVAS.lightened(0.1), "cloth", rng.randi())
		_:
			return _piece(root, BoxMesh.new(), at, Vector3(0.09, 0.07, 0.075), CANVAS.darkened(0.12), "cloth", rng.randi())


static func _piece(root: Node3D, mesh: BoxMesh, at: Vector3, size: Vector3, tint: Color, finish: String, salt: int) -> int:
	mesh.size = size
	return _mesh(root, mesh, at, Vector3.ZERO, tint, finish, salt)


static func _mesh(root: Node3D, mesh: Mesh, at: Vector3, tilt: Vector3, tint: Color, finish: String, salt: int) -> int:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	if tilt.length_squared() > 0.0001:
		node.rotation = tilt
	node.material_override = WorldLook.surface(tint, finish, salt)
	root.add_child(node)
	return 1


## One course of the bundle, turned slightly off axis. The turn is the whole
## point: three axis-aligned boxes stacked read as a stack of boxes, and the
## same three at a few degrees to each other read as something bagged.
static func _stepped(root: Node3D, at: Vector3, size: Vector3, turn: float, rng: RandomNumberGenerator) -> int:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation = Vector3(rng.randf_range(-0.05, 0.05), turn, rng.randf_range(-0.04, 0.04))
	node.material_override = WorldLook.surface(CANVAS, "cloth", rng.randi())
	root.add_child(node)
	return 1
