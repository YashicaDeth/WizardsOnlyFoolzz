extends Node3D

## THE DRY FALLS: where the drains come out. Greg, 24 September:
## "the derby and car route once you crash you can exit the car and or drive
## it through a tunnel system that gate opens up which then u can drive in
## like its gta tunnels and then you can drive to a drain exit at a dried up
## waterfall thats covered with blood and gore rivers of blood and destruction
## of trees" (DESIGN/ESCAPE_ROUTES.md, "the derby and the tunnels").
##
## The drain mouth sits at the lip of a waterfall that stopped running water a
## long time ago. What runs down the rock now is blood: out of the culvert,
## over the lip, down the face in streaks and into a plunge pool that feeds a
## river of it along the gorge floor. The trees down there are smashed,
## snapped and torn out by the roots. A service track cut into the right wall
## takes you (or a car, if one is handed in) down to the floor and along the
## river to the way out, which completes to the overworld.
##
## This scene does not own a route. Whoever sends the player here has already
## completed theirs with `FacilityRoutes` (the old drains file the storm outfall
## before sending you on), so the Hunt still consumes that route's handoff and
## lands the player at its authored point. A route that ends here without a
## handoff of its own (the derby tunnels) gets one from `_complete`, at
## `SURFACE_POSITION`.
##
## Built from primitives and two shaders (`shaders/blood_rock.gdshader`,
## `shaders/blood_river.gdshader`): art-directed now, authored later.

const OPENING := preload("res://systems/opening_director.gd")
const ROCK_SHADER := preload("res://shaders/blood_rock.gdshader")
const RIVER_SHADER := preload("res://shaders/blood_river.gdshader")

const LOCATION := "blood_waterfall"
const DESTINATION := "res://bone_yard_hunt.tscn"
## Where a route that ends here should surface in the Hunt when it has no
## handoff of its own. Assistant proposal, not decided: beside the storm
## outfall's own arrival point, since the drains are what feed these falls.
const SURFACE_POSITION := Vector3(-26.0, 0.0, 12.0)

## Everything is laid out walking -z out of the culvert.
const SPAWN := Vector3(0.0, 1.0, 9.0)
## The drain mouth: where the culvert opens onto the lip.
const MOUTH := Vector3(0.0, 0.0, 0.0)
const LIP_Z := -5.5
const FLOOR_Y := -20.0
const BLOOD_Y := -20.55
const FALLS_LEFT := -16.0
const FALLS_RIGHT := 10.0
const CULVERT_WIDTH := 6.5
const CULVERT_HEIGHT := 4.2
const CULVERT_DEPTH := 14.0
## The track: along the right wall from the lip down to the gorge floor.
const TRACK_X := 13.0
const TRACK_WIDTH := 6.0
const TRACK_TOP := Vector3(TRACK_X, 0.0, -5.5)
const TRACK_BOTTOM := Vector3(TRACK_X, FLOOR_Y, -66.0)
const GORGE_END_Z := -158.0
## The top of the gorge walls, where the ground above them starts.
const RIM_Y := 9.0
const EXIT_AT := Vector3(9.0, FLOOR_Y, -140.0)
const EXIT_REACH := 4.5
## A car is bigger than a person and cannot stop on a coin.
const VEHICLE_EXIT_REACH := 7.0
const WALK_SPEED := 3.4
const PLUNGE_CENTRE := Vector2(-3.0, -15.0)
const PLUNGE_RADII := Vector2(12.0, 9.0)

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.12
var objective: Label
var status: Label
var prompt: Label
## A car handed in from a route that drove here (see `hand_in_vehicle`).
var vehicle: Node3D = null
var completed := false
var completed_by := ""
var travel_requested := false
var rock_material: ShaderMaterial
var wet_rock_material: ShaderMaterial
var blood_material: ShaderMaterial
var noise := FastNoiseLite.new()
## Counted as built, so the test can check the place has what Greg asked for.
var tree_count := 0
var gore_count := 0


func _ready() -> void:
	noise.seed = 4471
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("bone_yard")
	add_child(environment)
	_build_materials()
	_build_light()
	_build_culvert()
	_build_lip()
	_build_falls()
	_build_gorge()
	_build_track()
	_build_blood()
	_build_trees()
	_build_gore()
	_build_exit()
	_build_player()
	_build_hud()
	var handoff := FacilityRoutes.pending_surface_handoff()
	WorldHistory.record_event("blood_waterfall_reached", {
		"location": LOCATION,
		"route_id": str(handoff.get("route_id", "")),
	})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- materials ---------------------------------------------------------------

func _build_materials() -> void:
	var detail := load("res://art/textures/lab/Concrete034_Color.jpg") as Texture2D
	rock_material = ShaderMaterial.new()
	rock_material.shader = ROCK_SHADER
	rock_material.set_shader_parameter("detail", detail)
	rock_material.set_shader_parameter("streak_amount", 0.7)
	rock_material.set_shader_parameter("streak_top", 9.0)
	# The falls face: the old watercourse down its middle still runs red.
	wet_rock_material = rock_material.duplicate() as ShaderMaterial
	wet_rock_material.set_shader_parameter("streak_amount", 0.8)
	wet_rock_material.set_shader_parameter("streak_top", 1.0)
	wet_rock_material.set_shader_parameter("channel_center_x", -3.0)
	wet_rock_material.set_shader_parameter("channel_half_width", 4.5)
	blood_material = ShaderMaterial.new()
	blood_material.shader = RIVER_SHADER


func _concrete(tint: Color) -> StandardMaterial3D:
	var material := LabSurface.material("wall").duplicate() as StandardMaterial3D
	material.albedo_color = tint
	return material


func _flat(colour: Color, roughness := 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


# --- geometry helpers ----------------------------------------------------------

func _slab(dimensions: Vector3, at: Vector3, material: Material, basis := Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, at)
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	return body


## A displaced grid: `place` maps (u, v) in 0..1 to a world point. Shared noise
## is sampled in world space by the callers, so neighbouring sheets meet.
func _sheet(cols: int, rows: int, place: Callable, material: Material, collide := true) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows + 1:
		for col in cols + 1:
			var u := float(col) / float(cols)
			var v := float(row) / float(rows)
			tool.set_uv(Vector2(u, v))
			tool.add_vertex(place.call(u, v))
	for row in rows:
		for col in cols:
			var i := row * (cols + 1) + col
			tool.add_index(i)
			tool.add_index(i + 1)
			tool.add_index(i + cols + 1)
			tool.add_index(i + 1)
			tool.add_index(i + cols + 2)
			tool.add_index(i + cols + 1)
	tool.generate_normals()
	var visual := MeshInstance3D.new()
	visual.mesh = tool.commit()
	visual.material_override = material
	if collide:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := visual.mesh.create_trimesh_shape() as ConcavePolygonShape3D
		shape.backface_collision = true
		collider.shape = shape
		body.add_child(collider)
		visual.add_child(body)
	add_child(visual)
	return visual


func _n(x: float, y: float) -> float:
	return noise.get_noise_2d(x, y) * 0.5 + 0.5


## Where a gorge wall stands at depth `v` (0 at the floor, 1 at the rim) on
## the left (`side` -1) or right (+1), widening downstream.
func wall_x(side: float, z: float, v: float) -> float:
	var y := lerpf(FLOOR_Y - 1.5, RIM_Y, v)
	if side < 0.0:
		return FALLS_LEFT - 0.2 - v * 10.0 - maxf(0.0, -z - 30.0) * 0.07 - _crag(z, y)
	return TRACK_X + TRACK_WIDTH * 0.5 + 0.1 + v * 8.0 + maxf(0.0, -z - 70.0) * 0.05 + _crag(z + 40.0, y)


## How far a gorge wall stands out at a point: broad bulges, a finer break-up,
## and bedding ledges every couple of metres, so it reads as layered rock
## rather than a smooth bank.
func _crag(along: float, y: float) -> float:
	var ledge := fposmod(y, 2.6) / 2.6
	return _n(along, y) * 3.0 + _n(along * 3.1 + 17.0, y * 3.1) * 0.9 + ledge * 0.55


func _lamp(at: Vector3, colour: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = colour
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	add_child(lamp)
	return lamp


# --- the place -------------------------------------------------------------------

func _build_light() -> void:
	# Low and behind the gorge: the evening comes in over the falls, so the
	# face you look back at from downstream is raked, not flat-lit.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffb27a")
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-32.0, 150.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)


## The culvert the drains end in: the same six-and-a-half metre bore, lined in
## the facility's concrete, broken grate lying on the apron.
func _build_culvert() -> void:
	var wall := _concrete(Color(0.34, 0.31, 0.27))
	var floor_material := _concrete(Color(0.28, 0.25, 0.21))
	var mid := CULVERT_DEPTH * 0.5
	_slab(Vector3(CULVERT_WIDTH, 0.4, CULVERT_DEPTH), Vector3(0, -0.2, mid), floor_material)
	_slab(Vector3(CULVERT_WIDTH + 1.0, 0.5, CULVERT_DEPTH), Vector3(0, CULVERT_HEIGHT + 0.25, mid), wall)
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.5, CULVERT_HEIGHT, CULVERT_DEPTH), Vector3(side * (CULVERT_WIDTH * 0.5 + 0.25), CULVERT_HEIGHT * 0.5, mid), wall)
	# The dead end behind the drop in.
	_slab(Vector3(CULVERT_WIDTH + 1.0, CULVERT_HEIGHT + 0.5, 0.5), Vector3(0, CULVERT_HEIGHT * 0.5, CULVERT_DEPTH + 0.25), wall)
	# Headwall round the mouth.
	var head := _concrete(Color(0.40, 0.36, 0.31))
	for side in [-1.0, 1.0]:
		_slab(Vector3(2.4, CULVERT_HEIGHT + 2.0, 0.8), Vector3(side * (CULVERT_WIDTH * 0.5 + 1.2), (CULVERT_HEIGHT + 2.0) * 0.5, -0.2), head)
	_slab(Vector3(CULVERT_WIDTH + 4.8, 1.6, 0.8), Vector3(0, CULVERT_HEIGHT + 0.8, -0.2), head)
	# The grate, burst outward: a few bars still in the frame, the rest bent
	# and lying across the apron.
	var rust := LabSurface.material("rust")
	for bar in 3:
		var rod := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.05
		mesh.height = CULVERT_HEIGHT
		mesh.material = rust
		rod.mesh = mesh
		rod.position = Vector3(-3.0 + float(bar) * 0.55, CULVERT_HEIGHT * 0.5, -0.5)
		add_child(rod)
	for bar in 5:
		var rod := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.05
		mesh.height = CULVERT_HEIGHT * (0.6 + 0.1 * float(bar))
		mesh.material = rust
		rod.mesh = mesh
		rod.position = Vector3(-1.0 + float(bar) * 0.7, 0.08, -1.6 - float(bar % 2) * 0.9)
		rod.rotation = Vector3(PI * 0.5, 0.3 * float(bar) - 0.6, 0.0)
		add_child(rod)
	# Something is still working down here.
	_lamp(Vector3(0, CULVERT_HEIGHT - 0.5, 6.0), Color("c86a2c"), 3.5, 9.0)


## The lip: the concrete spill apron, and the rock shelf either side of it the
## track leaves from. The rock above the culvert rises behind.
func _build_lip() -> void:
	var apron := _concrete(Color(0.36, 0.32, 0.27))
	_slab(Vector3(CULVERT_WIDTH + 1.5, 0.4, absf(LIP_Z) + 0.1), Vector3(0, -0.2, LIP_Z * 0.5), apron)
	_slab(Vector3(36.0, 0.8, absf(LIP_Z) + 0.6), Vector3(-22.0, -0.4, LIP_Z * 0.5 - 0.3), rock_material)
	_slab(Vector3(12.0, 0.8, absf(LIP_Z) + 0.6), Vector3(4.0 + 6.0, -0.4, LIP_Z * 0.5 - 0.3), rock_material)
	# The cliff the drain was cut into, above and either side of the headwall.
	var cliff_z := func(x: float, y: float) -> float: return 0.6 + _n(x * 1.3, y * 1.3) * 1.6
	_sheet(24, 10, func(u: float, v: float) -> Vector3:
		var x := lerpf(-44.0, -4.5, u)
		var y := lerpf(-0.6, 11.0, v)
		return Vector3(x, y, cliff_z.call(x, y)), rock_material)
	_sheet(24, 10, func(u: float, v: float) -> Vector3:
		var x := lerpf(4.5, 44.0, u)
		var y := lerpf(-0.6, 11.0, v)
		return Vector3(x, y, cliff_z.call(x, y)), rock_material)
	_sheet(6, 6, func(u: float, v: float) -> Vector3:
		var x := lerpf(-4.5, 4.5, u)
		var y := lerpf(5.5, 11.0, v)
		return Vector3(x, y, cliff_z.call(x, y)), rock_material)


## The waterfall with no water: a tiered face, twenty metres, stained from lip
## to pool, with blood still running down the old watercourse.
func _build_falls() -> void:
	_sheet(40, 22, func(u: float, v: float) -> Vector3:
		var x := lerpf(FALLS_LEFT - 16.0, FALLS_RIGHT, u)
		var y := lerpf(0.0, FLOOR_Y - 2.0, v)
		var tier := floorf(v * 4.0) * 0.9
		var z := LIP_Z - 0.1 - v * 3.0 - tier - _n(x, y) * (0.4 + v * 1.4)
		return Vector3(x, y, z), wet_rock_material)


## The gorge: walls either side, widening downstream, and a floor with the
## plunge pool and the river channel cut into it.
func _build_gorge() -> void:
	_sheet(96, 24, func(u: float, v: float) -> Vector3:
		var z := lerpf(1.0, GORGE_END_Z, u)
		return Vector3(wall_x(-1.0, z, v), lerpf(FLOOR_Y - 1.5, RIM_Y, v), z), rock_material)
	_sheet(96, 24, func(u: float, v: float) -> Vector3:
		var z := lerpf(1.0, GORGE_END_Z, u)
		return Vector3(wall_x(1.0, z, v), lerpf(FLOOR_Y - 1.5, RIM_Y, v), z), rock_material)
	# The ground above the gorge either side, where the forest was, meeting
	# each wall exactly along its top edge.
	for side in [-1.0, 1.0]:
		_sheet(48, 6, func(u: float, v: float) -> Vector3:
			var z := lerpf(1.0, GORGE_END_Z, u)
			var x: float = wall_x(side, z, 1.0) + side * v * v * 70.0
			return Vector3(x, RIM_Y + (_n(x, z) - 0.5) * 0.8 * v, z), rock_material)
	_sheet(60, 110, func(u: float, v: float) -> Vector3:
		var x := lerpf(-40.0, 36.0, u)
		var z := lerpf(-3.0, GORGE_END_Z, v)
		return Vector3(x, floor_height(x, z), z), rock_material)
	# The end of the walkable gorge, lost in the haze.
	_slab(Vector3(90.0, 40.0, 1.0), Vector3(0, FLOOR_Y + 10.0, GORGE_END_Z - 1.0), rock_material)


## The gorge floor's height at a point: rough ground, with the plunge pool and
## the river channel sunk below the blood line so the blood shows only there.
func floor_height(x: float, z: float) -> float:
	var y := FLOOR_Y + (_n(x * 2.0, z * 2.0) - 0.5) * 0.7
	var channel := absf(x - river_x(z))
	var half := river_half_width(z)
	var carve := 0.0
	if z < -12.0:
		carve = 1.3 * (1.0 - smoothstep(half - 0.8, half + 1.4, channel))
	var ellipse := Vector2((x - PLUNGE_CENTRE.x) / PLUNGE_RADII.x, (z - PLUNGE_CENTRE.y) / PLUNGE_RADII.y).length()
	carve = maxf(carve, 1.9 * (1.0 - smoothstep(0.65, 1.1, ellipse)))
	return y - carve


## Where the river of blood runs along the gorge.
func river_x(z: float) -> float:
	return -3.0 + 5.0 * sin(z * 0.035) + 2.0 * sin(z * 0.09 + 1.0)


func river_half_width(z: float) -> float:
	return 3.2 + 1.2 * sin(z * 0.05 + 0.4)


## The track down: a cut ledge along the right wall, wide enough for a car,
## graded for walking. The embankment under it is solid rock to the floor.
func _build_track() -> void:
	var run := TRACK_BOTTOM - TRACK_TOP
	var length := run.length()
	var angle := -atan2(-run.y, -run.z)
	var basis := Basis(Vector3.RIGHT, angle)
	var depth := 30.0
	var centre := (TRACK_TOP + TRACK_BOTTOM) * 0.5 + basis * Vector3(0, -depth * 0.5, 0)
	_slab(Vector3(TRACK_WIDTH, depth, length), centre, rock_material, basis)
	# The gravel of the track itself, a hand's depth above the rock.
	var gravel := _concrete(Color(0.30, 0.26, 0.22))
	var surface := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TRACK_WIDTH - 0.8, 0.1, length)
	mesh.material = gravel
	surface.mesh = mesh
	surface.transform = Transform3D(basis, (TRACK_TOP + TRACK_BOTTOM) * 0.5 + basis * Vector3(0, 0.03, 0))
	add_child(surface)
	# A short run of the old flood rail, bent over where something went off.
	var rust := LabSurface.material("rust")
	for post in 9:
		var t := float(post) / 8.0
		var at := TRACK_TOP.lerp(TRACK_BOTTOM, t) + Vector3(-TRACK_WIDTH * 0.5 + 0.25, 0.55, 0)
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.05
		pole_mesh.bottom_radius = 0.06
		pole_mesh.height = 1.1
		pole_mesh.material = rust
		pole.mesh = pole_mesh
		pole.position = at
		pole.rotation.x = 0.0 if post % 3 != 1 else 0.9
		add_child(pole)


## Blood: down the culvert floor and over the lip, and a sheet at the pool's
## level that shows wherever the gorge floor dips under it -- the plunge pool
## and the river channel -- so the rivers follow the ground exactly.
func _build_blood() -> void:
	var from_drain := MeshInstance3D.new()
	var strip := PlaneMesh.new()
	strip.size = Vector2(2.6, CULVERT_DEPTH + absf(LIP_Z))
	strip.material = blood_material
	from_drain.mesh = strip
	from_drain.position = Vector3(-1.0, 0.03, (CULVERT_DEPTH + LIP_Z) * 0.5 - 0.3)
	add_child(from_drain)
	var river := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(76.0, absf(GORGE_END_Z) + 4.0)
	sheet.subdivide_width = 0
	sheet.material = blood_material
	river.mesh = sheet
	river.position = Vector3(-2.0, BLOOD_Y, GORGE_END_Z * 0.5 - 1.0)
	add_child(river)
	# Where the falls land, the pool is lit from under the overhang.
	_lamp(Vector3(PLUNGE_CENTRE.x, FLOOR_Y + 3.0, PLUNGE_CENTRE.y), Color("ff3a26"), 2.2, 18.0)


func _bark() -> StandardMaterial3D:
	var material := _concrete(Color(0.24, 0.17, 0.12))
	material.uv1_scale = Vector3(1.4, 0.3, 1.4)
	return material


## Destruction of trees: snapped trunks with splintered tops, trees torn out
## by the roots with the root plate standing up, and whole trunks thrown down
## across the banks and into the river. Seeded, so every visit is the same.
func _build_trees() -> void:
	var bark := _bark()
	var bloodied := _concrete(Color(0.30, 0.06, 0.05))
	var roots := _flat(Color("2b1e16"), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var placed := 0
	var attempts := 0
	while placed < 40 and attempts < 400:
		attempts += 1
		var z := rng.randf_range(-20.0, GORGE_END_Z + 12.0)
		var left := FALLS_LEFT - 2.0 - maxf(0.0, -z - 30.0) * 0.07
		var x := rng.randf_range(left + 1.0, TRACK_X - TRACK_WIDTH * 0.5 - 1.0)
		var in_river := absf(x - river_x(z)) < river_half_width(z) + 0.6
		# Most stand on the banks; a few thrown trunks lie across the river.
		var kind := rng.randi_range(0, 2)
		if in_river and kind != 2:
			continue
		var ground := Vector3(x, floor_height(x, z), z)
		var yaw_angle := rng.randf_range(0.0, TAU)
		var material: Material = bloodied if rng.randf() < 0.35 else bark
		match kind:
			0:
				_snapped_tree(ground, rng, material)
			1:
				_uprooted_tree(ground, yaw_angle, rng, material, roots)
			_:
				_fallen_tree(ground, yaw_angle, rng, material)
		placed += 1
	# The forest that stood on the rims, broken off and blown over: the
	# skyline you see from the floor and the first thing past the lip.
	for index in 36:
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := rng.randf_range(4.0, GORGE_END_Z + 6.0)
		var x := wall_x(side, z, 1.0) + side * rng.randf_range(2.0, 24.0)
		var ground := Vector3(x, RIM_Y - 0.3, z)
		var material: Material = bloodied if rng.randf() < 0.25 else bark
		if index % 3 == 0:
			_uprooted_tree(ground, rng.randf_range(0.0, TAU), rng, material, roots)
		else:
			_snapped_tree(ground, rng, material, true)
		placed += 1
	# Two up on the lip, either side of the drain, so the first look has them.
	_snapped_tree(Vector3(-9.0, 0.0, -2.5), rng, bark)
	_uprooted_tree(Vector3(7.5, 0.0, -3.0), 2.2, rng, bloodied, roots)
	placed += 2
	tree_count = placed


func _trunk(radius: float, length: float, material: Material) -> MeshInstance3D:
	var trunk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 9
	mesh.material = material
	trunk.mesh = mesh
	return trunk


func _snapped_tree(ground: Vector3, rng: RandomNumberGenerator, material: Material, tall := false) -> void:
	var radius := rng.randf_range(0.3, 0.6)
	var height := rng.randf_range(4.0, 9.0) if tall else rng.randf_range(1.2, 4.5)
	var stump := _trunk(radius, height, material)
	stump.position = ground + Vector3(0, height * 0.5, 0)
	stump.rotation = Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	add_child(stump)
	# Splinters where it snapped.
	for splinter in rng.randi_range(3, 6):
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, rng.randf_range(0.5, 1.3), 0.12)
		mesh.material = material
		shard.mesh = mesh
		var around := float(splinter) / 5.0 * TAU
		shard.position = Vector3(cos(around) * radius * 0.6, height * 0.5 + mesh.size.y * 0.3, sin(around) * radius * 0.6)
		shard.rotation = Vector3(sin(around) * 0.35, around, cos(around) * 0.35)
		stump.add_child(shard)
	# And the top half lying where it came down.
	var top := _trunk(radius * 0.8, rng.randf_range(5.0, 11.0), material)
	var fall := rng.randf_range(0.0, TAU)
	top.position = ground + Vector3(cos(fall), 0.0, sin(fall)) * (top.mesh as CylinderMesh).height * 0.5 + Vector3(0, radius * 0.8, 0)
	top.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	top.rotate_y(-fall + PI * 0.5)
	add_child(top)


func _uprooted_tree(ground: Vector3, yaw_angle: float, rng: RandomNumberGenerator, material: Material, roots: Material) -> void:
	var radius := rng.randf_range(0.3, 0.55)
	var length := rng.randf_range(7.0, 12.0)
	var pivot := Node3D.new()
	pivot.position = ground
	pivot.rotation.y = yaw_angle
	add_child(pivot)
	# Torn out and leaning over at a steep angle.
	var lean := rng.randf_range(1.05, 1.35)
	var trunk := _trunk(radius, length, material)
	trunk.rotation.x = lean
	trunk.position = Vector3(0, cos(lean) * length * 0.5 + 0.6, sin(lean) * length * 0.5)
	pivot.add_child(trunk)
	# The root plate, standing up out of the crater it left.
	var plate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 4.0
	disc.bottom_radius = radius * 3.2
	disc.height = 0.7
	disc.radial_segments = 10
	disc.material = roots
	plate.mesh = disc
	plate.rotation.x = lean
	plate.position = Vector3(0, 0.6 + radius * 2.0, -0.2)
	pivot.add_child(plate)
	for root in 7:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = rng.randf_range(0.9, 2.0)
		cone.radial_segments = 5
		cone.material = roots
		spike.mesh = cone
		var around := float(root) / 7.0 * TAU
		spike.position = plate.position + Vector3(cos(around) * radius * 3.0, sin(around) * radius * 3.0, -0.5)
		spike.rotation = Vector3(-PI * 0.5 + lean + sin(around) * 0.5, 0.0, cos(around) * 0.6)
		pivot.add_child(spike)
	var crater := MeshInstance3D.new()
	var hole := CylinderMesh.new()
	hole.top_radius = radius * 3.6
	hole.bottom_radius = radius * 2.0
	hole.height = 0.2
	hole.material = roots
	crater.mesh = hole
	crater.position = Vector3(0, 0.02, -radius * 2.0)
	pivot.add_child(crater)


func _fallen_tree(ground: Vector3, yaw_angle: float, rng: RandomNumberGenerator, material: Material) -> void:
	var radius := rng.randf_range(0.3, 0.6)
	var length := rng.randf_range(8.0, 14.0)
	var trunk := _trunk(radius, length, material)
	trunk.position = ground + Vector3(0, radius * 0.7, 0)
	trunk.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	trunk.rotate_y(yaw_angle)
	add_child(trunk)
	# Broken-off limbs sticking up out of it.
	for limb in rng.randi_range(2, 4):
		var branch := _trunk(radius * 0.3, rng.randf_range(1.2, 2.6), material)
		branch.position = Vector3(0, rng.randf_range(-length * 0.4, length * 0.4), radius * 0.9)
		branch.rotation = Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(1.0, 1.8) * (1.0 if limb % 2 == 0 else -1.0))
		trunk.add_child(branch)


## Gore: what came down with the blood. Clots and lumps on the banks and the
## ledges, and pale bone, thickest where the falls land and thinning out along
## the river.
func _build_gore() -> void:
	var meat := StandardMaterial3D.new()
	meat.albedo_color = Color("5a0a10")
	meat.roughness = 0.25
	meat.metallic_specular = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2a0508")
	dark.roughness = 0.35
	var bone := _flat(Color("cdbfa2"), 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6660
	var placed := 0
	for index in 70:
		# Weighted toward the pool.
		var z := lerpf(-8.0, GORGE_END_Z + 20.0, pow(rng.randf(), 1.8))
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := river_x(z) + side * (river_half_width(z) + rng.randf_range(-0.2, 2.8))
		if z > -24.0:
			x = PLUNGE_CENTRE.x + side * rng.randf_range(4.0, PLUNGE_RADII.x + 1.0)
		var at := Vector3(x, maxf(floor_height(x, z), BLOOD_Y), z)
		var lump := MeshInstance3D.new()
		if index % 5 == 4:
			var capsule := CapsuleMesh.new()
			capsule.radius = rng.randf_range(0.04, 0.08)
			capsule.height = rng.randf_range(0.5, 1.1)
			capsule.material = bone
			lump.mesh = capsule
			lump.rotation = Vector3(PI * 0.5, rng.randf_range(0.0, TAU), 0.0)
			lump.position = at + Vector3(0, 0.06, 0)
		else:
			var sphere := SphereMesh.new()
			sphere.radius = rng.randf_range(0.12, 0.45)
			sphere.height = sphere.radius * rng.randf_range(0.8, 1.6)
			sphere.radial_segments = 10
			sphere.rings = 6
			sphere.material = meat if rng.randf() < 0.6 else dark
			lump.mesh = sphere
			lump.scale = Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.4, 0.8), rng.randf_range(0.8, 1.6))
			lump.rotation.y = rng.randf_range(0.0, TAU)
			lump.position = at
		add_child(lump)
		placed += 1
	# A few on the lip and down the culvert floor, in the flow.
	for index in 8:
		var lump := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.08, 0.2)
		sphere.height = sphere.radius
		sphere.material = dark
		lump.mesh = sphere
		lump.scale = Vector3(1.4, 0.4, 1.0)
		lump.position = Vector3(rng.randf_range(-2.2, 0.2), 0.04, rng.randf_range(LIP_Z + 0.4, 8.0))
		add_child(lump)
		placed += 1
	gore_count = placed


## The way out: the track leaves the gorge floor between two old gate posts
## with a lamp still burning on one.
func _build_exit() -> void:
	var rust := LabSurface.material("rust")
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.35, 3.4, 0.35)
		mesh.material = rust
		post.mesh = mesh
		post.position = EXIT_AT + Vector3(side * 3.2, 1.7, 0)
		post.rotation.z = side * 0.08
		add_child(post)
	var lamp_housing := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.18
	bulb.height = 0.36
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd49a")
	glow.emission_enabled = true
	glow.emission = Color("ffb35c")
	glow.emission_energy_multiplier = 4.0
	bulb.material = glow
	lamp_housing.mesh = bulb
	lamp_housing.position = EXIT_AT + Vector3(3.2, 3.5, 0)
	add_child(lamp_housing)
	_lamp(EXIT_AT + Vector3(3.2, 3.3, 0), Color("ffb35c"), 5.0, 16.0)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = SPAWN
	add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collider.shape = capsule
	player.add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 0.77
	camera.fov = 80.0
	camera.far = 600.0
	player.add_child(camera)
	if VatRebirth.carries("BREACH TOOL"):
		LabSurface.hold_in_view(camera, LabSurface.breach_tool())


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	objective = Label.new()
	objective.position = Vector2(34, 34)
	objective.add_theme_font_size_override("font_size", 18)
	objective.add_theme_color_override("font_color", Color("e4a058"))
	layer.add_child(objective)
	status = Label.new()
	status.position = Vector2(34, 62)
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("d27a6a"))
	layer.add_child(status)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -55
	prompt.offset_left = -310
	prompt.offset_right = 310
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.add_theme_color_override("font_color", Color("dd9851"))
	layer.add_child(prompt)


# --- play --------------------------------------------------------------------------

## A route that drove here hands its car in. It is placed at the drain mouth
## facing out; driving it is the car's own business (the vehicle lane), and
## this scene only watches for it reaching the way out.
func hand_in_vehicle(car: Node3D) -> void:
	vehicle = car
	if car.get_parent() == null:
		add_child(car)
	car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.9, 5.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.15, 0.95)


func _physics_process(delta: float) -> void:
	if vehicle == null:
		var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
		var direction := (Basis(Vector3.UP, yaw) * input).normalized()
		var pace := WALK_SPEED * (1.6 if Input.is_action_pressed("sprint") else 1.0)
		player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 16.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 16.0 * delta)
		player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
		player.move_and_slide()
		player.rotation.y = yaw
		camera.rotation = Vector3(pitch, 0, 0)
	_check_exit()
	_update_hud()


func _check_exit() -> void:
	if completed:
		return
	if vehicle != null and is_instance_valid(vehicle):
		if _flat_distance(vehicle.global_position, EXIT_AT) <= VEHICLE_EXIT_REACH:
			_complete("driving")
		return
	if _flat_distance(player.global_position, EXIT_AT) <= EXIT_REACH:
		_complete("walking")


## Out of the gorge and on to the overworld. The Hunt consumes whatever route
## handoff sent the player here, so the arrival point and relationships are
## the route's own; this only records how the player left the falls.
func _complete(by: String) -> void:
	completed = true
	completed_by = by
	WorldHistory.begin_ledger_batch()
	FacilityRoutes.hand_off_at("blood_waterfall", SURFACE_POSITION)
	OPENING.advance("left_facility")
	WorldHistory.amend_subject("player", {"status": "out past the dry falls"})
	WorldHistory.record_event("blood_waterfall_left", {
		"location": LOCATION,
		"by": by,
		"vehicle": str(vehicle.name) if vehicle != null and is_instance_valid(vehicle) else "",
		"destination": DESTINATION,
		"route_id": str(FacilityRoutes.pending_surface_handoff().get("route_id", "")),
	})
	WorldHistory.commit_ledger_batch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	travel_requested = true
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Interstitial.travel(DESTINATION, "the dry falls // up out of the gorge")


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_hud() -> void:
	objective.text = "OBJECTIVE // FOLLOW THE BLOOD DOWN AND OUT"
	status.text = "THE DRY FALLS // WHERE THE OLD DRAINS EMPTY"
	var body := vehicle if vehicle != null and is_instance_valid(vehicle) else player
	if completed:
		prompt.text = ""
	elif _flat_distance(body.global_position, EXIT_AT) <= 20.0:
		prompt.text = "THE TRACK OUT // KEEP GOING"
	elif body.global_position.z > LIP_Z + 1.0 and body.global_position.y > -1.0:
		prompt.text = "THE TRACK DOWN IS ON YOUR RIGHT"
	else:
		prompt.text = "WASD MOVE   //   SHIFT RUN"
