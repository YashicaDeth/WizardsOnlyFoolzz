class_name SubstanceStation
extends Node3D

## AU3.2/AU3.5/AU3.6. Everything takeable, in one droppable object.
##
## Greg: *"adding everything accessible to the game in the sandbox in the
## boneyard and same same"*. The last two words are the whole design. Three
## places want this - the shed (AU3), the gore sandbox, and the Hunt Grounds -
## and the obvious way to give it to them is for each scene to lay its own table
## out. That is precisely how E2 ended up with two directors for the same
## seventy-two seals, and how `ritual_ledger.gd` and `ritual_app.gd` spent a
## month not meeting. So the table is a thing, not a procedure that gets copied:
## one manifest, one builder, one pickup rule, and every scene drops the same
## node.
##
## The consequence worth stating plainly: **if a substance is reachable in the
## sandbox it is reachable in the Hunt Grounds, because it is the same object.**
## There is no sandbox-only path to keep in step, and a test asserts two
## stations built independently expose an identical manifest.
##
## Owns the objects and who is near enough to take one. Owns nothing about what
## taking one does - the scene decides that, because the hunt files inventory
## through `WorldHistory` and `carry.gd` and the sandbox does not have to.

const SubstanceObjects := preload("res://systems/substance_objects.gd")
const Smokeables := preload("res://systems/smokeables.gd")
const Substances := preload("res://systems/substances.gd")

## Reach, in metres. Matches the 3.5m the Hunt Grounds already uses for a loot
## cache rather than inventing a second number for the same gesture.
const REACH := 2.6

## The manifest. Everything a player can pick up off a station, in one list, so
## "what is available" is a fact about this file rather than about whichever
## scene happened to lay out the most.
##
## Order is left to right along the table and it is deliberate: what you carry
## away first is nearest the edge you approach from.
const MANIFEST := [
	{"kind": "substance", "form": "baggie", "id": "marrow_dust", "x": -0.86, "z": 0.10},
	{"kind": "substance", "form": "weight", "id": "choir_bloom", "x": -0.58, "z": 0.06},
	{"kind": "substance", "form": "tab", "id": "static_hymn", "x": -0.33, "z": 0.12},
	{"kind": "substance", "form": "blister", "id": "marrow_dust", "x": -0.12, "z": 0.09},
	{"kind": "smokeable", "id": "cigarette", "x": 0.62, "z": 0.16},
	{"kind": "smokeable", "id": "vape", "x": 0.44, "z": 0.20},
	{"kind": "smokeable", "id": "joint", "x": 0.20, "z": 0.02},
	{"kind": "smokeable", "id": "spliff", "x": 0.06, "z": 0.19},
	{"kind": "smokeable", "id": "bong", "x": -1.22, "z": 0.34, "floor": true},
]

## Fixed kit: not takeable, but the reason the table reads as a working surface
## rather than a shop shelf.
const FIXTURES := [
	{"prop": "tray", "x": 0.20, "z": 0.02},
	{"prop": "grinder", "x": 0.52, "z": 0.10},
	{"prop": "scales", "x": 0.78, "z": -0.04},
	{"prop": "ashtray", "x": 1.04, "z": 0.08},
	{"prop": "lighter", "x": 0.36, "z": 0.18},
]

const TOP_Y := 0.879

signal taken(entry: Dictionary)

## Live pickups, in manifest order. An entry that has been taken is dropped from
## here, so `pickups()` is always what is actually still on the table.
var _live: Array[Dictionary] = []
var _fixtures: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## `with_table` is false when something else already supplies the surface - the
## shed has its own bench, and building a second one inside it would put a
## trestle through a workbench.
func build(with_table := true, seed_value := 4093) -> void:
	_rng.seed = seed_value
	if with_table:
		_build_table()
	for raw in FIXTURES:
		var fixture: Dictionary = raw
		var node: Node3D = SubstanceObjects.build_prop(str(fixture["prop"]))
		node.position = Vector3(float(fixture["x"]), TOP_Y, float(fixture["z"]))
		node.rotation = Vector3(0, _rng.randf_range(-0.35, 0.35), 0)
		add_child(node)
		_fixtures.append({
			"source": node,
			"item_id": "station_fixture:%s" % str(fixture["prop"]),
			"kind": "fixture",
			"label": str(fixture["prop"]).replace("_", " ").to_upper(),
			"detail": "WORKING SURFACE",
		})
	for raw in MANIFEST:
		var entry: Dictionary = (raw as Dictionary).duplicate()
		var node := _build_one(entry)
		entry["node"] = node
		entry["label"] = _label(entry)
		_live.append(entry)
	# The bench keeps its shadow; the things on it do not. 168 of the hunt's
	# 3133 visible shadow casters were station goods -- 35 grinder parts, 24
	# baggies, 17 blisters, 16 weights -- and a caster costs a full re-render
	# into every cascade whether it is a warehouse or a pill packet. Done here
	# rather than in the scenes so every station in the game gets it.
	WorldLook.stop_small_shadows(self)


func _build_one(entry: Dictionary) -> Node3D:
	var node: Node3D
	if str(entry["kind"]) == "substance":
		node = SubstanceObjects.build(str(entry["form"]), str(entry["id"]))
	else:
		node = Smokeables.build(str(entry["id"]))
	var on_floor := bool(entry.get("floor", false))
	node.position = Vector3(float(entry["x"]), 0.0 if on_floor else TOP_Y, float(entry["z"]))
	node.rotation = Vector3(0, _rng.randf_range(-0.6, 0.6), 0)
	add_child(node)
	return node


func _label(entry: Dictionary) -> String:
	if str(entry["kind"]) == "substance":
		var data: Dictionary = Substances.CATALOG.get(str(entry["id"]), {})
		return "%s (%s)" % [str(data.get("label", entry["id"])).to_upper(), str(entry["form"]).to_upper()]
	return str((Smokeables.CATALOG.get(str(entry["id"]), {}) as Dictionary).get("label", entry["id"])).to_upper()


## Everything still on the table. The manifest minus what has been carried off.
func pickups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _live:
		if is_instance_valid(entry.get("node")):
			out.append(entry)
	return out


## What this station offers, independent of any instance - the thing two
## stations must agree on for "same same" to mean anything.
static func manifest_ids() -> Array[String]:
	var out: Array[String] = []
	for raw in MANIFEST:
		var entry: Dictionary = raw
		out.append("%s:%s:%s" % [entry["kind"], entry["id"], entry.get("form", "-")])
	return out


func nearest(from: Vector3, reach := REACH) -> Dictionary:
	var best := {}
	var best_distance := reach
	for entry in pickups():
		var node: Node3D = entry["node"]
		var distance := from.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = entry
	return best


## I9. Looking at a thing must present the same object the player can take.
## Return its live node and authored identity so the common 3D reliquary can
## copy the geometry already sitting in the world instead of inventing an icon.
func inspection_nearest(from: Vector3, reach := REACH) -> Dictionary:
	var entry := nearest(from, reach)
	var result := {}
	var best_distance := reach
	if not entry.is_empty():
		var pickup_source := entry["node"] as Node3D
		best_distance = from.distance_to(pickup_source.global_position)
		result = {
			"source": pickup_source,
			"item_id": str(entry["id"]),
			"kind": str(entry["kind"]),
			"label": str(entry["label"]),
			"detail": str(entry.get("form", "ground")),
		}
	for fixture: Dictionary in _fixtures:
		var fixture_source := fixture.get("source") as Node3D
		if fixture_source == null or not is_instance_valid(fixture_source):
			continue
		var distance := from.distance_to(fixture_source.global_position)
		if distance < best_distance:
			best_distance = distance
			result = fixture.duplicate()
	return result


## Take the nearest thing. Returns {} when nothing is in reach, so a caller can
## fall through to whatever else its interact key does rather than swallowing
## the press.
func take_nearest(from: Vector3, reach := REACH) -> Dictionary:
	var entry := nearest(from, reach)
	if entry.is_empty():
		return {}
	var node: Node3D = entry["node"]
	_live.erase(entry)
	node.queue_free()
	var carried := entry.duplicate()
	carried.erase("node")
	taken.emit(carried)
	return carried


func _build_table() -> void:
	var top := _box(Vector3(2.30, 0.038, 0.58), Color("4b3826"), 0.95)
	top.position = Vector3(0, TOP_Y - 0.019, 0)
	add_child(top)
	for plank in 5:
		var board := _box(Vector3(2.30, 0.006, 0.108), Color("54402c").lerp(Color("3a2b1d"), _rng.randf()), 0.96)
		board.position = Vector3(0, TOP_Y + 0.002, -0.232 + float(plank) * 0.116)
		add_child(board)
	for side in [-1.0, 1.0]:
		for front in [-1.0, 1.0]:
			var leg := _box(Vector3(0.072, TOP_Y - 0.038, 0.072), Color("4a3a29"), 0.94)
			leg.position = Vector3(side * 1.06, (TOP_Y - 0.038) * 0.5, front * 0.23)
			add_child(leg)


func _box(size: Vector3, tint: Color, roughness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	node.material_override = material
	return node
