extends Node3D

## Station 3: destruction. A cinder wall of panels, crates, window panes and a
## run of service pipe, every one a `BreakableProp` that every weapon reaches
## through `WorldBreak` (the same door the Hunt, the drains and the arcade
## use). Each prop shows its damage in stages (hairline cracks, wide
## fractures, chips out) and breaks into the Blender cells in `fracture/`.
## The open ground in front takes a hole sized by the round (`GroundHole`,
## through `Ballistics`). The button stands everything back up.

const SLAB := preload("res://lab/stations/fracture/slab_cells.glb")
const PIPE := preload("res://lab/stations/fracture/pipe_cells.glb")
const STAGES := preload("res://lab/stations/crack_stage.gdshader")
const TITLE := "DESTRUCTION"
const VERB := "REBUILD"

var lab: Node3D
var props: Array[BreakableProp] = []
var _stages: Dictionary = {}
var _wall: Dictionary = {}
var _builds := 0


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	for index in 2:
		_frame(Vector3(3.0 + float(index) * 1.15, 0.95, -0.4), Vector2(1.04, 1.26))
	for x in [1.0, 3.0, 5.0, 7.0]:
		_trestle(Vector3(x, 0, 1.8))
	_raise()


func press() -> String:
	_raise()
	return "REBUILT"


func broken_count() -> int:
	return props.filter(func(prop: BreakableProp) -> bool: return is_instance_valid(prop) and prop.broken).size()


func status() -> String:
	return "BROKEN %d/%d" % [broken_count(), props.size()]


func _process(_delta: float) -> void:
	# A wall panel with nothing under it comes down after the one below.
	for key: Vector2i in _wall:
		var above := _wall[key] as BreakableProp
		var below := _wall.get(key - Vector2i(0, 1)) as BreakableProp
		if below != null and is_instance_valid(below) and below.broken and is_instance_valid(above) and not above.broken:
			above.strike(above.integrity + 1.0, Vector3.DOWN)
	for prop in props:
		if not is_instance_valid(prop):
			continue
		var shell := _stages.get(prop) as MeshInstance3D
		if shell == null:
			continue
		shell.visible = not prop.broken and prop.integrity < prop.max_integrity
		if shell.visible:
			(shell.material_override as ShaderMaterial).set_shader_parameter("damage", 1.0 - prop.integrity / prop.max_integrity)


func _raise() -> void:
	for prop in props:
		if is_instance_valid(prop):
			prop.queue_free()
	props.clear()
	_stages.clear()
	_wall.clear()
	_builds += 1
	# The wall: four panels by two, each its own breakable, so it comes down
	# where it is hit and stands where it is not.
	for column in 4:
		for row in 2:
			_wall[Vector2i(column, row)] = _add("wall_panel", "Wall_%d_%d" % [column, row], Vector3(-1.5 + float(column), 0.5 + float(row), -2.0), Vector3(1.0, 1.0, 0.3), SLAB)
	for index in 3:
		_add("crate", "Crate_%d" % index, Vector3(-4.5 + float(index) * 0.95, 0.4, 0.2 + float(index % 2) * 0.3), Vector3.ZERO, SLAB)
	_add("crate", "Crate_top", Vector3(-4.0, 1.2, 0.3), Vector3.ZERO, SLAB)
	# Two panes standing in a steel frame.
	for index in 2:
		var at := Vector3(3.0 + float(index) * 1.15, 0.95, -0.4)
		_add("glass_pane", "Pane_%d" % index, at, Vector3(1.0, 1.2, 0.02), SLAB)
	# A pipe run on trestles at waist height, three lengths end to end.
	for index in 3:
		var prop := _add("pipe", "Pipe_%d" % index, Vector3(2.0 + float(index) * 2.0, 1.0, 1.8), Vector3(0.24, 2.0, 0.24), PIPE)
		prop.rotation.z = PI * 0.5


func _add(kind: String, id: String, centre: Vector3, size: Vector3, cells: PackedScene) -> BreakableProp:
	var prop := BreakableProp.new()
	prop.name = "%s_%d" % [id, _builds]
	prop.build(kind, size)
	prop.prefractured = cells
	prop.position = centre
	add_child(prop)
	props.append(prop)
	var shell := MeshInstance3D.new()
	shell.name = "Stages"
	if kind == "pipe":
		var tube := CylinderMesh.new()
		tube.top_radius = prop.dimensions.x * 0.53
		tube.bottom_radius = prop.dimensions.x * 0.53
		tube.height = prop.dimensions.y * 1.01
		shell.mesh = tube
	else:
		var box := BoxMesh.new()
		box.size = prop.dimensions * 1.03 + Vector3(0.004, 0.004, 0.004)
		shell.mesh = box
	var material := ShaderMaterial.new()
	material.shader = STAGES
	material.set_shader_parameter("seed", float(props.size()) * 3.7)
	shell.material_override = material
	shell.visible = false
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prop.add_child(shell)
	_stages[prop] = shell
	return prop


func _frame(at: Vector3, size: Vector2) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("2b2a28")
	steel.metallic = 0.7
	steel.roughness = 0.45
	for side in [-1.0, 1.0]:
		_bar(at + Vector3(side * size.x * 0.5, 0, 0), Vector3(0.05, size.y, 0.08), steel)
		_bar(at + Vector3(0, side * size.y * 0.5, 0), Vector3(size.x + 0.05, 0.05, 0.08), steel)


func _trestle(at: Vector3) -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("3a2c20")
	timber.roughness = 0.9
	_bar(at + Vector3(0, 0.44, 0), Vector3(0.08, 0.88, 0.5), timber)


func _bar(at: Vector3, size: Vector3, material: Material) -> void:
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	bar.mesh = box
	bar.position = at
	add_child(bar)
