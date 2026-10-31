extends Node3D
## The tunnel kit's in-world door: a bulkhead across the cell with a doorway,
## and a heavy panel that slides into the wall when a body comes near and
## shuts behind it. No prompt, no fade: you walk up and it grinds open.

const OPENING := Vector2(2.6, 3.0)
const SLIDE_TIME := 0.9
const SENSE := Vector3(3.6, 3.0, 7.0)

var axis := Vector3(0, 0, 1)
var opened := 0.0
var panel: AnimatableBody3D
var _sense: Area3D
var _inside := 0


## `along` is the direction you walk through the door (the tunnel axis).
func setup(along: Vector3) -> void:
	axis = along
	# The door plane faces along the tunnel; local +X runs across it.
	basis = Basis.looking_at(-along, Vector3.UP)
	var kit := load("res://systems/facility_tunnel_kit.gd")
	var cell: float = kit.CELL
	var height: float = kit.HEIGHT
	var jamb := (cell - OPENING.x) * 0.5
	for side: int in [-1, 1]:
		_block(Vector3(jamb, height, 0.5), Vector3(side * (OPENING.x * 0.5 + jamb * 0.5), height * 0.5, 0), kit.material("door"))
	_block(Vector3(OPENING.x, height - OPENING.y, 0.5), Vector3(0, OPENING.y + (height - OPENING.y) * 0.5, 0), kit.material("door"))
	panel = AnimatableBody3D.new()
	panel.name = "Panel"
	panel.sync_to_physics = false
	add_child(panel)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(OPENING.x + 0.1, OPENING.y, 0.22)
	mesh.mesh = box
	mesh.material_override = kit.material("door", true)
	panel.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collider.shape = shape
	panel.add_child(collider)
	panel.position = Vector3(0, OPENING.y * 0.5, 0)
	var frame := load("res://systems/generated_model.gd").make("tunnel_door_frame") as Node3D
	if frame != null:
		frame.set_meta("kit_model", "tunnel_door_frame")
		add_child(frame)
	_sense = Area3D.new()
	_sense.name = "Sense"
	var zone := CollisionShape3D.new()
	var zone_shape := BoxShape3D.new()
	zone_shape.size = SENSE
	zone.shape = zone_shape
	zone.position.y = SENSE.y * 0.5
	_sense.add_child(zone)
	add_child(_sense)
	_sense.body_entered.connect(func(body: Node3D) -> void:
		if body is CharacterBody3D:
			_inside += 1)
	_sense.body_exited.connect(func(body: Node3D) -> void:
		if body is CharacterBody3D:
			_inside = maxi(0, _inside - 1))


func is_open() -> bool:
	return opened >= 1.0


func _physics_process(delta: float) -> void:
	if panel == null:
		return
	opened = move_toward(opened, 1.0 if _inside > 0 else 0.0, delta / SLIDE_TIME)
	# Slides sideways into the east/south jamb (local +X), a little past full.
	panel.position.x = smoothstep(0.0, 1.0, opened) * (OPENING.x + 0.1)


func _block(size: Vector3, at: Vector3, surface: Material) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.set_meta("surface", "metal")
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = surface
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
