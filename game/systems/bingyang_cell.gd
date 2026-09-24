class_name BingyangCell
extends Node3D

## One cell of the Mental and Physical Support Unit's ward (DESIGN/BINGYANG.md:
## "a Support Unit ward on the escape route (cells, restraint beds,
## bingyangas being tortured, cells you can open)").
##
## A concrete box set into the hallway wall, a slot of observation glass, a
## restraint frame at the back with its bingyanga strapped to it, and a
## `BreakableDoor` for a front door: the same door, the same stages and the same
## record as the one behind the player's vat. Breaking it open is the player
## freeing the bingyanga; the cell hands that to its `Bingyanger`.
##
## Local space: the door is in the plane z = 0 and faces +z (the hallway); the
## cell runs back to z = -DEPTH.

signal freed(bingyanger: Bingyanger)
signal noise(at: Vector3, loudness: float)

const WIDTH := 3.4
const DEPTH := 2.9
const HEIGHT := 3.2
const DOOR_SIZE := Vector2(1.2, 2.3)

var cell_id := ""
var door: BreakableDoor
var occupant: Bingyanger
var lamp: OmniLight3D


func build(id: String, seed_value: int) -> void:
	cell_id = id
	_walls()
	door = BreakableDoor.new()
	door.name = "Door"
	add_child(door)
	door.build(cell_id + "_door", DOOR_SIZE, Color("8d8a7c"))
	door.noise.connect(noise.emit)
	door.broke_open.connect(_on_broke_open)
	_restraint_frame()
	occupant = Bingyanger.new()
	occupant.name = "Bingyanga"
	occupant.position = Vector3(0, 0, -DEPTH + 0.75)
	# Facing out through the door, the way the player first sees it.
	occupant.rotation.y = PI
	add_child(occupant)
	occupant.build(cell_id + "_bingyanga", seed_value, not door.broken)
	# Out in the hallway in front of its door is where it hangs about once out.
	occupant.home = to_global(Vector3(0, 0, 1.8))
	# A cell broken open in an earlier life stays open, and whoever was in it
	# is out (or dead) as the record says.
	var label := Label3D.new()
	label.text = "SUPPORT UNIT // %s" % cell_id.to_upper().replace("_", " ")
	label.font_size = 22
	label.outline_size = 6
	label.modulate = Color("c9b8a0")
	label.outline_modulate = Color("120707")
	label.position = Vector3(0, DOOR_SIZE.y + 0.4, 0.2)
	add_child(label)


func _walls() -> void:
	var side_width := (WIDTH - DOOR_SIZE.x) * 0.5
	for side in [-1.0, 1.0]:
		_slab(Vector3(side_width, HEIGHT, 0.3), Vector3(side * (DOOR_SIZE.x * 0.5 + 0.12 + side_width * 0.5), HEIGHT * 0.5, 0))
		_slab(Vector3(0.3, HEIGHT, DEPTH), Vector3(side * (WIDTH * 0.5 + 0.15), HEIGHT * 0.5, -DEPTH * 0.5))
	_slab(Vector3(DOOR_SIZE.x + 0.24, HEIGHT - DOOR_SIZE.y - 0.12, 0.3), Vector3(0, DOOR_SIZE.y + 0.12 + (HEIGHT - DOOR_SIZE.y - 0.12) * 0.5, 0))
	_slab(Vector3(WIDTH + 0.6, 0.3, DEPTH + 0.3), Vector3(0, HEIGHT + 0.15, -DEPTH * 0.5))
	# The observation slot in the front wall: dark glass, lit from inside.
	var glass := MeshInstance3D.new()
	var pane := BoxMesh.new()
	pane.size = Vector3(0.9, 0.34, 0.05)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.35, 0.3, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.05
	material.metallic_specular = 0.9
	pane.material = material
	glass.mesh = pane
	glass.position = Vector3(-(DOOR_SIZE.x * 0.5 + 0.12 + (WIDTH - DOOR_SIZE.x) * 0.25), 1.75, 0.0)
	add_child(glass)
	lamp = OmniLight3D.new()
	lamp.light_color = Color("b5d0a0")
	lamp.light_energy = 1.6
	lamp.omni_range = 3.6
	lamp.position = Vector3(0, HEIGHT - 0.4, -DEPTH * 0.6)
	lamp.shadow_enabled = false
	add_child(lamp)


## The frame the bingyanga is strapped to: two uprights, straps across.
func _restraint_frame() -> void:
	var metal := LabSurface.material("grime")
	for side in [-1.0, 1.0]:
		_decor(Vector3(0.08, 2.1, 0.08), Vector3(side * 0.45, 1.05, -DEPTH + 0.45), metal)
	var strap := WorldLook.surface(Color("3a2a1c"), "dirt", 612)
	for height in [0.55, 1.05, 1.45]:
		_decor(Vector3(0.98, 0.07, 0.04), Vector3(0, height, -DEPTH + 0.52), strap)
	# The drain in the floor, and what has gone down it.
	var stain := WorldLook.surface(Color("2a0f0b"), "dirt", 613)
	_decor(Vector3(1.2, 0.01, 1.0), Vector3(0.1, 0.006, -DEPTH + 0.9), stain)


func _on_broke_open(method: String) -> void:
	if occupant == null or occupant.state != "held":
		return
	lamp.light_color = Color("e0a070")
	occupant.release(method)
	freed.emit(occupant)


func _slab(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = LabSurface.material("wall")
	visual.mesh = mesh
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body


func _decor(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = at
	add_child(mesh_instance)
