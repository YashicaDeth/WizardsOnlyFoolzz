extends Node3D

## Station 3: destruction. Greg, 5 Oct ~01:45 (replacing the 25 Sep "authored
## stages" answer): "as much like Teardown as possible, including the ground
## being DIGGABLE", with a five-tier toughness scale, so you can "BLAST your
## way into a hidden underground city network or an elite's buried bunker".
##
## - A brick wall (tier 2), a concrete wall (tier 3) and two wood crates
##   (tier 1) of 15 cm voxels (`VoxelStructure`): every weapon reaches them
##   through `WorldBreak`, and each takes only what it can beat
##   (`MaterialToughness`). Unsupported pieces fall.
## - The breach corner: a bunker (tier 4 front, tier 5 sealed shell) with a lit
##   crate inside, and a diggable patch of ground (`DigTerrain`) with a steel
##   hatch (tier 3) buried 1.2 m down over a pocket. Explore, dig, blast,
##   breach.
## - The older pieces stay: crates, panes and a pipe run as `BreakableProp`s
##   breaking into Blender cells, and the open ground's round holes.
## - The lab's last four tools: grenade, demolition charge, thermal drill,
##   shovel. The button stands everything back up.

const SLAB := preload("res://lab/stations/fracture/slab_cells.glb")
const PIPE := preload("res://lab/stations/fracture/pipe_cells.glb")
const STAGES := preload("res://lab/stations/crack_stage.gdshader")
const TITLE := "DESTRUCTION"
const VERB := "REBUILD"
const TOOLS := ["grenade", "charge", "drill", "shovel"]
## The bunker's front-centre and the dig patch's corner, station space.
const BUNKER := Vector3(-5.5, 0, -6.0)
const DIG_CORNER := Vector3(-7.5, -3.0, 2.5)
## Station-space ground the dig patch replaces (x, z, width, depth); the lab
## leaves this out of its yard floor.
const DIG_RECT := Rect2(-7.5, 2.5, 6.0, 6.0)
## The REBUILD plinth, station space: in front of the walls, clear of the dig
## patch, so its sign stands behind the view of the walls, not in it.
const PLINTH := Vector3(1.0, 0, 5.0)
const GRENADE_FUSE := 2.2
const GRENADE := {"radius": 1.1, "damage": 260.0, "source": "explosive"}
const CHARGE_FUSE := 3.0
const CHARGE := {"radius": 0.85, "damage": 520.0, "source": "charge"}
const DRILL_DPS := 55.0
const DRILL_RADIUS := 0.3
const SHOVEL_RADIUS := 0.45

var lab: Node3D
var props: Array[BreakableProp] = []
var voxels: Array[VoxelStructure] = []
var brick_wall: VoxelStructure
var concrete_wall: VoxelStructure
var bunker_front: VoxelStructure
var hatch: VoxelStructure
var terrain: DigTerrain
var charges: Array[Node3D] = []
var _built: Node3D
var _stages: Dictionary = {}
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


## Props that broke, and voxel walls, crates and bunker parts that lost a real
## share of themselves (`VoxelStructure.broken`) or are gone.
func broken_count() -> int:
	var count := props.filter(func(prop: BreakableProp) -> bool: return is_instance_valid(prop) and prop.broken).size()
	return count + voxels.filter(func(structure: VoxelStructure) -> bool: return not is_instance_valid(structure) or structure.broken()).size()


func breakables() -> int:
	return props.size() + voxels.size()


func status() -> String:
	return "BROKEN %d/%d  DUG %d" % [broken_count(), breakables(), terrain.cuts.size() if is_instance_valid(terrain) else 0]


func _process(_delta: float) -> void:
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
	if _built != null:
		_built.queue_free()
	charges.clear()
	voxels.clear()
	_builds += 1
	_built = Node3D.new()
	_built.name = "Built_%d" % _builds
	add_child(_built)
	brick_wall = _voxel("brick", Vector3(4.05, 2.1, 0.3), Vector3(0, 1.05, -2.0))
	concrete_wall = _voxel("concrete", Vector3(1.8, 2.1, 0.3), Vector3(3.5, 1.05, -2.0))
	for index in 2:
		_voxel("wood", Vector3(0.75, 0.75, 0.75), Vector3(-1.8 + float(index) * 0.95, 0.375, 0.9))
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
	# After the props above, which the lab test finds by order.
	_bunker()
	_dig_patch()


func _voxel(material: String, metres: Vector3, centre: Vector3, anchor := "floor") -> VoxelStructure:
	var structure := VoxelStructure.make(_built, material, metres, centre, anchor)
	structure.name = "%s_%d" % [material.capitalize().replace(" ", ""), voxels.size()]
	voxels.append(structure)
	return structure


## A sealed shell (tier 5: only a special charge or the drill) with an
## armoured front (tier 4: explosives get through), a lamp and a crate inside.
func _bunker() -> void:
	bunker_front = _voxel("bunker", Vector3(2.7, 2.4, 0.6), BUNKER + Vector3(0, 1.2, 0))
	for side in [-1.0, 1.0]:
		_voxel("sealed", Vector3(0.3, 2.4, 2.4), BUNKER + Vector3(side * 1.2, 1.2, -1.5))
	_voxel("sealed", Vector3(2.7, 2.4, 0.3), BUNKER + Vector3(0, 1.2, -2.85))
	_voxel("sealed", Vector3(2.7, 0.3, 3.3), BUNKER + Vector3(0, 2.55, -1.35), "rim")
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("c8452e")
	lamp.light_energy = 1.6
	lamp.omni_range = 2.6
	lamp.position = BUNKER + Vector3(0, 2.0, -1.4)
	_built.add_child(lamp)
	_add("crate", "BunkerCrate", BUNKER + Vector3(0, 0.4, -1.6), Vector3.ZERO, SLAB)


## Six metres of diggable dirt, three deep, with a steel hatch buried 1.2 m
## down over a pocket holding a crate.
func _dig_patch() -> void:
	terrain = DigTerrain.new()
	terrain.name = "DigPatch"
	terrain.position = DIG_CORNER
	_built.add_child(terrain)
	var middle := Vector3(DIG_RECT.get_center().x, 0, DIG_RECT.get_center().y)
	var hatch_top := -1.2
	var low := middle - DIG_CORNER + Vector3(-0.6, hatch_top - 1.2, -0.6)
	terrain.carve_box(low, middle - DIG_CORNER + Vector3(0.6, hatch_top, 0.6))
	hatch = _voxel("steel_sheet", Vector3(1.2, 0.15, 1.2), middle + Vector3(0, hatch_top - 0.075, 0), "rim")
	_add("crate", "BuriedCrate", middle + Vector3(0, hatch_top - 0.8, 0), Vector3.ZERO, SLAB)


# --- the tools ----------------------------------------------------------------

## FIRE with a tool held. `from`/`along` is the eye; `holder` is left out of
## the ray. The drill is held instead (`drill`).
func use_tool(tool: String, from: Vector3, along: Vector3, holder: CollisionObject3D = null) -> String:
	match tool:
		"grenade":
			throw_grenade(from + along * 0.4, along * 11.0 + Vector3.UP * 2.5, holder)
			return "GRENADE OUT"
		"charge":
			var met := _ray(from, along, 3.0, holder)
			if met.is_empty():
				return "NOTHING TO STICK IT TO"
			place_charge(met.position, met.normal)
			return "CHARGE SET  %.0fs" % CHARGE_FUSE
		"drill":
			return "HOLD TO DRILL"
		"shovel":
			return "DUG %d" % dig(from, along, holder)
	return ""


func throw_grenade(at: Vector3, velocity: Vector3, holder: CollisionObject3D = null) -> RigidBody3D:
	var grenade := RigidBody3D.new()
	grenade.name = "Grenade"
	grenade.mass = 0.4
	grenade.continuous_cd = true
	var visual := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	visual.mesh = ball
	grenade.add_child(visual)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.05
	shape.shape = sphere
	grenade.add_child(shape)
	_built.add_child(grenade)
	grenade.global_position = at
	grenade.linear_velocity = velocity
	if holder != null:
		grenade.add_collision_exception_with(holder)
	_fuse(grenade, GRENADE_FUSE, GRENADE)
	return grenade


func place_charge(at: Vector3, normal: Vector3) -> Node3D:
	var charge := MeshInstance3D.new()
	charge.name = "Charge"
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.14, 0.06)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("8a6a2a")
	paint.emission_enabled = true
	paint.emission = Color("ff3020")
	paint.emission_energy_multiplier = 0.6
	box.material = paint
	charge.mesh = box
	_built.add_child(charge)
	charge.global_position = at + normal * 0.03
	if absf(normal.dot(Vector3.UP)) < 0.99:
		charge.look_at(at + normal, Vector3.UP)
	charge.set_meta("normal", normal)
	charges.append(charge)
	_fuse(charge, CHARGE_FUSE, CHARGE)
	return charge


func _fuse(thing: Node3D, seconds: float, spec: Dictionary) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if is_instance_valid(thing):
			detonate(thing, spec))


## Sets `thing` off now. A charge blows into what it is stuck to.
func detonate(thing: Node3D, spec := CHARGE) -> Dictionary:
	var at := thing.global_position
	if thing.has_meta("normal"):
		at -= (thing.get_meta("normal") as Vector3) * 0.2
	charges.erase(thing)
	thing.queue_free()
	return Blast.explode(self, at, float(spec.radius), float(spec.damage), str(spec.source))


## One physics frame of the thermal drill held against whatever is in front.
## Beats every tier, slowly. Returns the cells (or soil samples) it took.
func drill(from: Vector3, along: Vector3, delta: float, holder: CollisionObject3D = null) -> int:
	var met := _ray(from, along, 1.8, holder)
	if met.is_empty():
		return 0
	var target: Object = met.collider
	if target is VoxelStructure:
		return int((target as VoxelStructure).damage_sphere(met.position + along * 0.05, DRILL_RADIUS, "thermal_drill", DRILL_DPS * delta, along).removed)
	if target is DigTerrain:
		return (target as DigTerrain).carve_sphere(met.position + along * 0.1, DRILL_RADIUS, "thermal_drill")
	return 0


## A scoop of soil where you look (or a dirt cell). Tier 1 only.
func dig(from: Vector3, along: Vector3, holder: CollisionObject3D = null) -> int:
	var met := _ray(from, along, 2.6, holder)
	if met.is_empty():
		return 0
	if met.collider is DigTerrain:
		return (met.collider as DigTerrain).carve_sphere(met.position + along * 0.2, SHOVEL_RADIUS, "dig")
	if met.collider is VoxelStructure:
		return int((met.collider as VoxelStructure).damage_sphere(met.position + along * 0.05, SHOVEL_RADIUS, "dig", 40.0, along).removed)
	return 0


func _ray(from: Vector3, along: Vector3, reach: float, holder: CollisionObject3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + along.normalized() * reach, 1)
	if holder != null:
		query.exclude = [holder.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


# --- the older breakables -----------------------------------------------------

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
