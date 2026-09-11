class_name AshbloomWorldGenerator
extends Node3D

const REGION_SIZE := Vector2(470, 370)
const ROAD := Color("27221c")
const WALLS := [Color("392a20"), Color("403326"), Color("2c3028"), Color("442722")]
const SIGNS := ["EAT AT VANTA'S", "NO GODS OVER 8FT", "NIX FIX", "SOFT ROT MOTEL", "BLACK MILE TAX", "CELLOUTZ RELAY"]

var generated_buildings: Array[Node3D] = []
var lots: Array[Rect2] = []


func generate(seed_value: int = 774013) -> void:
	# Regeneration replaces only this generator's owned geometry.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	generated_buildings.clear()
	lots.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_road(Vector3(0, -0.32, 0), Vector3(18, 0.24, REGION_SIZE.y))
	_build_road(Vector3(0, -0.28, -72), Vector3(REGION_SIZE.x, 0.22, 15))
	_build_road(Vector3(-112, -0.27, 74), Vector3(12, 0.22, 170))
	for district in 5:
		var centers := [Vector3(-150, 0, -122), Vector3(130, 0, -122), Vector3(-155, 0, 0), Vector3(135, 0, 0), Vector3(65, 0, 115)]
		var district_center: Vector3 = centers[district]
		for lot in 8 + district * 2:
			var offset := Vector3(float(lot % 4) * 24.0 - 36.0, 0, float(lot / 4) * 22.0 - 33.0)
			var width := rng.randf_range(8.0, 17.0)
			var depth := rng.randf_range(7.0, 15.0)
			var height := rng.randf_range(3.8, 8.5)
			var lot_center := Vector2(district_center.x + offset.x, district_center.z + offset.z)
			lots.append(Rect2(lot_center - Vector2(width, depth) * 0.5, Vector2(width, depth)))
			_build_enterable_shell(district_center + offset, Vector3(width, height, depth), WALLS[rng.randi_range(0, WALLS.size() - 1)], SIGNS[rng.randi_range(0, SIGNS.size() - 1)])


func _build_road(at: Vector3, dimensions: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = _material(ROAD, 0.0, "dirt")
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


func _build_enterable_shell(at: Vector3, dimensions: Vector3, color: Color, sign_text: String) -> void:
	var building := Node3D.new()
	building.name = "Enterable_%03d" % generated_buildings.size()
	building.position = at
	add_child(building)
	generated_buildings.append(building)
	var wall_thickness := 0.45
	var half_x := dimensions.x * 0.5
	var half_z := dimensions.z * 0.5
	var door_width := minf(2.4, dimensions.x * 0.28)
	_add_wall(building, Vector3(-half_x + (dimensions.x - door_width) * 0.25, dimensions.y * 0.5, half_z), Vector3((dimensions.x - door_width) * 0.5, dimensions.y, wall_thickness), color)
	_add_wall(building, Vector3(half_x - (dimensions.x - door_width) * 0.25, dimensions.y * 0.5, half_z), Vector3((dimensions.x - door_width) * 0.5, dimensions.y, wall_thickness), color)
	_add_wall(building, Vector3(0, dimensions.y * 0.5, -half_z), Vector3(dimensions.x, dimensions.y, wall_thickness), color)
	_add_wall(building, Vector3(-half_x, dimensions.y * 0.5, 0), Vector3(wall_thickness, dimensions.y, dimensions.z), color)
	_add_wall(building, Vector3(half_x, dimensions.y * 0.5, 0), Vector3(wall_thickness, dimensions.y, dimensions.z), color)
	_add_wall(building, Vector3(0, -0.12, 0), Vector3(dimensions.x, 0.22, dimensions.z), Color("211a16"))
	_add_wall(building, Vector3(0, dimensions.y, 0), Vector3(dimensions.x + 0.7, 0.32, dimensions.z + 0.7), color.darkened(0.18))
	var sign := Label3D.new()
	sign.text = sign_text
	sign.position = Vector3(0, dimensions.y * 0.72, half_z + 0.35)
	sign.font_size = 28
	sign.modulate = Color("e26a36")
	sign.outline_size = 5
	building.add_child(sign)


func _add_wall(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = _material(color, 0.0)
	mesh_instance.mesh = box
	body.add_child(mesh_instance)


## The whole region was built with its own flat material function and never
## touched `WorldLook` at all, so every wall, road and shell in the Ashbloom
## was a single untextured colour. That — not the box geometry — is why the
## region reads as a grey-box prototype: the same boxes with contaminated
## surfaces on them read as a ruined town.
var _surface_index := 0

func _material(color: Color, emission: float, kind := "rust") -> StandardMaterial3D:
	_surface_index += 1
	var material: StandardMaterial3D = WorldLook.surface(color, kind, _surface_index)
	material.emission_enabled = emission > 0.0
	if emission > 0.0:
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
