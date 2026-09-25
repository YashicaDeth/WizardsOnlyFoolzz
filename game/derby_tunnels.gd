extends Node3D

## THE DERBY TUNNELS. Greg, 24 September: "the derby and car route once you
## crash you can exit the car and or drive it through a tunnel system that gate
## opens up which then u can drive in like its gta tunnels and then you can
## drive to a drain exit at a dried up waterfall". Decided: the waterfall is
## where the derby tunnels come out.
##
## You start in the corner of the arena with the car you finished the heat in.
## A portcullis in the arena wall goes up onto the old tunnels: long lit road
## bores with a tiled lower wall, a gutter either side (dirty water on the left,
## blood on the right, running the way out), sodium lamps and ceiling strips
## going past overhead, two junction halls with dead-end bores off them, and
## barricades to go through. The last bore ends at the drain mouth; driving (or
## walking) into it goes on to the dry falls (`blood_waterfall_exit.tscn`), and
## a car driven there is handed over with it (`VehicleDriver.carry`).
##
## Get out with E wherever the car is slow enough, and back in beside it.
##
## Route bookkeeping: the scene begins `FacilityRoutes.ROUTE_DERBY_TUNNELS` at
## the colosseum, traverses `derby_tunnels` passing the gate and `dry_falls` at
## the mouth, which completes the route and leaves the surface handoff the Hunt
## consumes after the falls.
##
## Built from swept primitives and the blood river shader: laid out now,
## authored later.

const BLOOD_SHADER := preload("res://shaders/blood_river.gdshader")
const BREAKABLE_PROP := preload("res://systems/breakable_prop.gd")
const DERBY_AUDIO := preload("res://systems/procedural_derby_audio.gd")
const SCRAP_SKIFF := preload("res://art/scrap_skiff.glb")

const LOCATION := "derby_tunnels"
const DESTINATION := "res://blood_waterfall_exit.tscn"
const CAPTION := "the old drain mouth // out over the dry falls"

## The bore's cross-section, in metres from the road's centre line.
const ROAD_HALF := 5.5
const GUTTER_OUT := 6.7
const GUTTER_DEPTH := -0.5
const WALKWAY_Y := 0.35
const WALL_X := 8.2
const TILE_TOP := 2.4
const SHOULDER_Y := 5.2
const CEILING_Y := 6.4
const CHAMFER_X := 7.0
const SAMPLE_STEP := 3.0
## Sodium lamps down every bore: one every LAMP_EVERY samples (18 m), bright
## and wide enough to overlap, so the road is never a black gap at speed.
const LAMP_EVERY := 6
const LAMP_ENERGY := 4.2
const LAMP_REACH := 24.0
const AMBIENT_LIFT := 2.2
const CHUNK_SAMPLES := 8
const CHAMBER_HALF := 18.0
const CHAMBER_HEIGHT := 10.0

## The arena wall stands across z = 0 with the gate in it; the car starts
## behind it in the arena and everything else runs away down -z.
const GATE_Z := 0.0
const GATE_SECONDS := 2.6
const CAR_START := Vector3(0.0, 0.9, 18.0)
const ENTERED_Z := -4.0
const MOUTH := Vector3(100.0, -10.0, -580.0)
## Where arriving counts: short of the headwall, so a car is not asked to
## thread the culvert itself; the falls start with it in the culvert.
const MOUTH_TRIGGER := Vector3(100.0, -10.0, -568.0)
const MOUTH_REACH := 11.0
const WALK_SPEED := 3.4

## Junction halls, centred on their floor.
const HALLS := {
	"sump_hall": {"centre": Vector3(0.0, -4.0, -238.0), "doors": ["south", "west", "east"], "pillar": true},
	"crossing_hall": {"centre": Vector3(140.0, -8.0, -378.0), "doors": ["north", "east", "south"], "pillar": false},
}
## Every bore, as control points for a Catmull-Rom centre line. `main` bores
## are the way out, in order; the rest end in a collapse.
const BORES := [
	{"name": "gate_bore", "main": true, "points": [
		Vector3(0, 0, 0), Vector3(0, 0, -30), Vector3(8, -1, -80), Vector3(16, -2.5, -130),
		Vector3(8, -4, -180), Vector3(0, -4, -205), Vector3(0, -4, -220)]},
	{"name": "long_bore", "main": true, "points": [
		Vector3(18, -4, -238), Vector3(40, -4, -238), Vector3(80, -5.5, -250), Vector3(118, -7, -285),
		Vector3(140, -8, -330), Vector3(140, -8, -350), Vector3(140, -8, -360)]},
	{"name": "outfall_bore", "main": true, "points": [
		Vector3(140, -8, -396), Vector3(140, -8, -420), Vector3(132, -9, -470), Vector3(108, -10, -520),
		Vector3(100, -10, -550), Vector3(100, -10, -580)]},
	{"name": "sump_west", "main": false, "points": [
		Vector3(-18, -4, -238), Vector3(-40, -4, -238), Vector3(-62, -4, -244), Vector3(-82, -4, -250)]},
	{"name": "crossing_east", "main": false, "points": [
		Vector3(158, -8, -378), Vector3(180, -8, -378), Vector3(204, -8, -385)]},
]
## Barricades on the way out: [bore, metres along it, offset across the road].
const BARRICADES := [
	["gate_bore", 70.0, 0.0], ["gate_bore", 70.0, -3.9], ["gate_bore", 160.0, 1.2],
	# Far enough past the sump hall's right-hander to arrive at speed: at 60 m
	# every car reached them slowly, glanced off and ended up on the walkway.
	["long_bore", 100.0, 0.0], ["long_bore", 100.0, 3.9], ["long_bore", 150.0, -1.6],
	["outfall_bore", 70.0, 0.0], ["outfall_bore", 140.0, 2.4], ["outfall_bore", 140.0, -2.4],
]

signal left_tunnels(by: String)

var materials := {}
var blood_material: ShaderMaterial
var water_material: StandardMaterial3D
var strip_material: StandardMaterial3D
var dash_material: StandardMaterial3D
## Main-route centre line, gate to mouth, through the halls: what a driver
## (or a test) follows.
var drive_line: Array[Vector3] = []
var bore_samples := {}
var lamps: Array[OmniLight3D] = []
var flickering: Array[OmniLight3D] = []
var breakables: Array[Node3D] = []
var gate: StaticBody3D
var gate_open := 0.0

var car: RigidBody3D
var driver: VehicleDriver
var player: CharacterBody3D
var player_collider: CollisionShape3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.05
var audio: Node

var objective: Label
var status: Label
var prompt: Label

var entered := false
var completed := false
var completed_by := ""
var travel_requested := false
var smashed := 0
var top_speed := 0.0
var route_id := ""


func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("lower_works")
	# Measured 2-4/255 mean luminance with the Lower Works' own ambient: the
	# bores are far longer and wider than its rooms. Lifted toward the Lower
	# Works' fixed level (about 15/255); still sky-sourced, since a flat colour
	# wash erases form (WorldLook).
	environment.environment.ambient_light_energy = maxf(environment.environment.ambient_light_energy, 1.0) * AMBIENT_LIFT
	add_child(environment)
	_build_materials()
	_build_arena()
	for bore: Dictionary in BORES:
		_build_bore(bore)
	for hall_name: String in HALLS:
		_build_hall(hall_name, HALLS[hall_name])
	_build_mouth()
	_build_breakables()
	_build_drive_line()
	_build_car()
	_build_player()
	_build_hud()
	_begin_route()
	WorldHistory.record_event("derby_tunnels_gate_opened", {"location": LOCATION, "route_id": route_id})
	# Out of the car already if the player climbed out in the pit.
	if _climbed_out_in_derby():
		driver.attach(car, false)
		_stand_player(car.global_position + Vector3(-2.4, 0.3, 0.0), 0.0)
	else:
		driver.attach(car, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- bookkeeping --------------------------------------------------------------

func _begin_route() -> void:
	var handoff := FacilityRoutes.pending_surface_handoff()
	if not handoff.is_empty():
		# Something already got the player out; the falls and the Hunt use that.
		route_id = str(handoff.get("route_id", ""))
		return
	if str(FacilityRoutes.ensure().get("active_route", "")) != FacilityRoutes.ROUTE_DERBY_TUNNELS:
		FacilityRoutes.begin(FacilityRoutes.ROUTE_DERBY_TUNNELS)
	route_id = str(FacilityRoutes.ensure().get("active_route", ""))


func _climbed_out_in_derby() -> bool:
	for index in range(WorldHistory.events.size() - 1, -1, -1):
		var type := str((WorldHistory.events[index] as Dictionary).get("type", ""))
		if type == "player_left_derby_vehicle":
			return true
		if type == "derby_session_started":
			return false
	return false


# --- materials ----------------------------------------------------------------

func _lab(role: String, tint: Color) -> StandardMaterial3D:
	var material := LabSurface.material(role).duplicate() as StandardMaterial3D
	material.albedo_color = tint
	return material


func _build_materials() -> void:
	materials["road"] = _lab("wall", Color(0.20, 0.19, 0.18))
	materials["gutter"] = _lab("wall", Color(0.17, 0.14, 0.12))
	materials["walkway"] = _lab("wall", Color(0.36, 0.34, 0.30))
	# The old road-tunnel tile band, gone the colour of tea.
	materials["tile"] = _lab("floor", Color(0.62, 0.55, 0.40))
	materials["wall"] = _lab("wall", Color(0.40, 0.38, 0.34))
	materials["ceiling"] = _lab("ceiling", Color(0.30, 0.29, 0.27))
	materials["rust"] = LabSurface.material("rust")
	blood_material = ShaderMaterial.new()
	blood_material.shader = BLOOD_SHADER
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.06, 0.07, 0.05)
	water_material.roughness = 0.04
	water_material.metallic_specular = 0.9
	strip_material = StandardMaterial3D.new()
	strip_material.albedo_color = Color("ffe2b0")
	strip_material.emission_enabled = true
	strip_material.emission = Color("ffc070")
	strip_material.emission_energy_multiplier = 5.0
	dash_material = StandardMaterial3D.new()
	dash_material.albedo_color = Color(0.62, 0.50, 0.18)
	dash_material.roughness = 0.7


func _blood_flowing(direction: Vector3) -> ShaderMaterial:
	var material := blood_material.duplicate() as ShaderMaterial
	var flat := Vector2(direction.x, direction.z).normalized()
	material.set_shader_parameter("flow", flat * 0.8)
	return material


# --- geometry helpers -----------------------------------------------------------

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


func _box(dimensions: Vector3, at: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = material
	visual.mesh = mesh
	visual.position = at
	parent.add_child(visual)
	return visual


func _lamp(at: Vector3, colour: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = colour
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	add_child(lamp)
	lamps.append(lamp)
	return lamp


func _sign(text: String, at: Vector3, facing: Vector3, colour := Color("e4a058")) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.01
	label.modulate = colour
	label.outline_size = 12
	label.outline_modulate = Color(0.05, 0.03, 0.02)
	add_child(label)
	label.position = at
	label.look_at(at - facing, Vector3.UP)
	return label


## A Catmull-Rom centre line through `points`, resampled every SAMPLE_STEP.
static func sample_line(points: Array) -> Array[Vector3]:
	var dense: Array[Vector3] = []
	for index in points.size() - 1:
		var p0: Vector3 = points[maxi(index - 1, 0)]
		var p1: Vector3 = points[index]
		var p2: Vector3 = points[index + 1]
		var p3: Vector3 = points[mini(index + 2, points.size() - 1)]
		for step in 24:
			var t := float(step) / 24.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(points[points.size() - 1])
	var result: Array[Vector3] = [dense[0]]
	var carried := 0.0
	for index in range(1, dense.size()):
		var a: Vector3 = dense[index - 1]
		var b: Vector3 = dense[index]
		var span := a.distance_to(b)
		while carried + span >= SAMPLE_STEP and span > 0.0001:
			a = a.lerp(b, (SAMPLE_STEP - carried) / span)
			result.append(a)
			span = a.distance_to(b)
			carried = 0.0
		carried += span
	var last: Vector3 = points[points.size() - 1]
	if result[result.size() - 1].distance_to(last) > SAMPLE_STEP * 0.4:
		result.append(last)
	else:
		result[result.size() - 1] = last
	return result


static func forward_at(samples: Array[Vector3], index: int) -> Vector3:
	var from := samples[maxi(index - 1, 0)]
	var to := samples[mini(index + 1, samples.size() - 1)]
	var flat := (to - from).slide(Vector3.UP)
	return flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD


## The cross-section as [from, to, inward normal, material]. The left half;
## the right half is its mirror.
func _profile() -> Array:
	var left := [
		[Vector2(-ROAD_HALF, 0.0), Vector2(-ROAD_HALF, GUTTER_DEPTH), Vector2(-1, 0), "gutter"],
		[Vector2(-ROAD_HALF, GUTTER_DEPTH), Vector2(-GUTTER_OUT, GUTTER_DEPTH), Vector2(0, 1), "gutter"],
		[Vector2(-GUTTER_OUT, GUTTER_DEPTH), Vector2(-GUTTER_OUT, WALKWAY_Y), Vector2(1, 0), "gutter"],
		[Vector2(-GUTTER_OUT, WALKWAY_Y), Vector2(-WALL_X, WALKWAY_Y), Vector2(0, 1), "walkway"],
		[Vector2(-WALL_X, WALKWAY_Y), Vector2(-WALL_X, TILE_TOP), Vector2(1, 0), "tile"],
		[Vector2(-WALL_X, TILE_TOP), Vector2(-WALL_X, SHOULDER_Y), Vector2(1, 0), "wall"],
		[Vector2(-WALL_X, SHOULDER_Y), Vector2(-CHAMFER_X, CEILING_Y), Vector2(0.707, -0.707), "wall"],
	]
	var result := [
		[Vector2(-ROAD_HALF, 0.0), Vector2(ROAD_HALF, 0.0), Vector2(0, 1), "road"],
		[Vector2(-CHAMFER_X, CEILING_Y), Vector2(CHAMFER_X, CEILING_Y), Vector2(0, -1), "ceiling"],
	]
	for segment: Array in left:
		result.append(segment)
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var n: Vector2 = segment[2]
		result.append([Vector2(-a.x, a.y), Vector2(-b.x, b.y), Vector2(-n.x, n.y), segment[3]])
	return result


## One band of the sweep between two profile points over samples [from, to],
## wound clockwise toward its normal (Godot's front face) and collected for
## collision.
func _band(tool: SurfaceTool, faces: PackedVector3Array, samples: Array[Vector3], from: int, to: int, a: Vector2, b: Vector2, n: Vector2) -> void:
	for index in range(from, to):
		var quad: Array[Vector3] = []
		var normals: Array[Vector3] = []
		for which in [index, index + 1]:
			var right := forward_at(samples, which).cross(Vector3.UP).normalized()
			quad.append(samples[which] + right * a.x + Vector3.UP * a.y)
			quad.append(samples[which] + right * b.x + Vector3.UP * b.y)
			var normal := right * n.x + Vector3.UP * n.y
			normals.append(normal)
			normals.append(normal)
		# quad: 0 = (i, a), 1 = (i, b), 2 = (i+1, a), 3 = (i+1, b)
		var order := [0, 1, 2, 1, 3, 2]
		if (quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(normals[0]) > 0.0:
			order = [0, 2, 1, 1, 2, 3]
		for corner: int in order:
			tool.set_normal(normals[corner])
			tool.add_vertex(quad[corner])
			faces.append(quad[corner])


# --- the place --------------------------------------------------------------------

## The corner of the arena the car starts in, and the wall with the gate.
func _build_arena() -> void:
	var sand := WorldLook.surface(Color("4a3526"), "dirt", 7)
	_slab(Vector3(84.0, 1.0, 52.0), Vector3(0.0, -0.5, 26.0), sand)
	var wall := _lab("wall", Color(0.33, 0.30, 0.27))
	var height := 14.0
	var side_width := 42.0 - WALL_X
	for side in [-1.0, 1.0]:
		_slab(Vector3(side_width, height, 1.4), Vector3(side * (WALL_X + side_width * 0.5), height * 0.5, GATE_Z + 0.7), wall)
		_slab(Vector3(1.4, height, 52.0), Vector3(side * 42.0, height * 0.5, 26.0), wall)
	_slab(Vector3(WALL_X * 2.0 + 0.2, height - CEILING_Y, 1.4), Vector3(0.0, CEILING_Y + (height - CEILING_Y) * 0.5, GATE_Z + 0.7), wall)
	_slab(Vector3(84.0, height, 1.4), Vector3(0.0, height * 0.5, 52.0), wall)
	# The heat's leftovers: two wrecks and the stains they made.
	for wreck in 2:
		var shell := SCRAP_SKIFF.instantiate() as Node3D
		shell.scale = Vector3(1.15, 1.15, 1.15)
		shell.position = Vector3(-14.0 + 30.0 * float(wreck), 0.0, 30.0 - 12.0 * float(wreck))
		shell.rotation = Vector3(0.0, 0.8 + 2.1 * float(wreck), (PI * 0.5 + 0.15) if wreck == 1 else 0.12)
		if wreck == 1:
			shell.position.y = 1.4
		add_child(shell)
		WorldLook.regrime(shell, 11 + wreck)
	for stain in 7:
		var pool := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.5 + float(stain % 3) * 1.7, 1.8 + float(stain % 2) * 2.2)
		plane.material = blood_material
		pool.mesh = plane
		pool.position = Vector3(-24.0 + float(stain) * 8.0, 0.02, 8.0 + float((stain * 7) % 5) * 7.0)
		pool.rotation.y = float(stain) * 0.9
		add_child(pool)
	# Floodlights over the pit, and the gate's own warning lamp.
	_lamp(Vector3(-18.0, 11.0, 24.0), Color("ffd7a8"), 3.2, 40.0)
	_lamp(Vector3(18.0, 11.0, 24.0), Color("ffd7a8"), 3.2, 40.0)
	_lamp(Vector3(0.0, 7.4, GATE_Z + 3.0), Color("ff3a1a"), 3.0, 14.0)
	_sign("TUNNELS // OUTFALL", Vector3(0.0, 9.2, GATE_Z + 1.45), Vector3(0, 0, 1))
	_build_gate()


## A portcullis of rusted bars that goes up into the wall above the opening.
func _build_gate() -> void:
	gate = StaticBody3D.new()
	gate.name = "TunnelGate"
	gate.position = Vector3(0.0, 0.0, GATE_Z + 0.7)
	add_child(gate)
	var rust: Material = materials["rust"]
	for bar in 17:
		_box(Vector3(0.14, CEILING_Y, 0.14), Vector3(-WALL_X + 0.5 + float(bar) * ((WALL_X * 2.0 - 1.0) / 16.0), CEILING_Y * 0.5, 0.0), rust, gate)
	for rail in 4:
		_box(Vector3(WALL_X * 2.0, 0.22, 0.2), Vector3(0.0, 0.6 + float(rail) * 1.75, 0.0), rust, gate)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WALL_X * 2.0, CEILING_Y, 0.4)
	collider.shape = shape
	collider.position.y = CEILING_Y * 0.5
	gate.add_child(collider)


func _build_bore(bore: Dictionary) -> void:
	var samples := sample_line(bore.points)
	bore_samples[bore.name] = samples
	var main := bool(bore.main)
	var profile := _profile()
	var chunk_start := 0
	while chunk_start < samples.size() - 1:
		var chunk_end := mini(chunk_start + CHUNK_SAMPLES, samples.size() - 1)
		var mesh := ArrayMesh.new()
		var faces := PackedVector3Array()
		var by_material := {}
		for segment: Array in profile:
			var key := str(segment[3])
			if not by_material.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(materials[key])
				by_material[key] = tool
			# The gutters are grated over for wheels: seen as a channel, driven
			# as road. As a real 0.5 m drop beside a 0.85 m kerb they caught
			# any car knocked sideways by a barricade and never let it out.
			_band(by_material[key], faces if key != "gutter" else PackedVector3Array(), samples, chunk_start, chunk_end, segment[0], segment[1], segment[2])
		var grating := SurfaceTool.new()
		grating.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			_band(grating, faces, samples, chunk_start, chunk_end, Vector2(side * ROAD_HALF, 0.0), Vector2(side * GUTTER_OUT, 0.0), Vector2(0, 1))
			_band(grating, faces, samples, chunk_start, chunk_end, Vector2(side * GUTTER_OUT, 0.0), Vector2(side * GUTTER_OUT, WALKWAY_Y), Vector2(-side, 0))
		for key: String in by_material:
			(by_material[key] as SurfaceTool).commit(mesh)
		var visual := MeshInstance3D.new()
		visual.name = "%s_%02d" % [bore.name, chunk_start / CHUNK_SAMPLES]
		visual.mesh = mesh
		add_child(visual)
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		collider.shape = shape
		body.add_child(collider)
		visual.add_child(body)
		# The gutters: dirty water on the left; on the right, blood running the
		# way out (in a dead end, back toward the hall it drains to).
		var along := forward_at(samples, (chunk_start + chunk_end) / 2) * (1.0 if main else -1.0)
		_liquid(samples, chunk_start, chunk_end, -GUTTER_OUT + 0.05, -ROAD_HALF - 0.05, GUTTER_DEPTH + 0.2, water_material)
		_liquid(samples, chunk_start, chunk_end, ROAD_HALF + 0.05, GUTTER_OUT - 0.05, GUTTER_DEPTH + 0.26, _blood_flowing(along))
		chunk_start = chunk_end
	_dress_bore(bore, samples)


func _liquid(samples: Array[Vector3], from: int, to: int, x0: float, x1: float, y: float, material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var unused := PackedVector3Array()
	_band(tool, unused, samples, from, to, Vector2(x0, y), Vector2(x1, y), Vector2(0, 1))
	var visual := MeshInstance3D.new()
	visual.mesh = tool.commit()
	add_child(visual)


## Lamps, ceiling strips, the painted centre line, rubble, and the collapse
## that ends a dead-end bore.
func _dress_bore(bore: Dictionary, samples: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(bore.name)
	var strips := MultiMesh.new()
	strips.transform_format = MultiMesh.TRANSFORM_3D
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.5, 0.1, 2.6)
	strip_mesh.material = strip_material
	strips.mesh = strip_mesh
	var dashes := MultiMesh.new()
	dashes.transform_format = MultiMesh.TRANSFORM_3D
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.18, 0.02, 2.4)
	dash_mesh.material = dash_material
	dashes.mesh = dash_mesh
	var strip_at: Array[Transform3D] = []
	var dash_at: Array[Transform3D] = []
	for index in samples.size():
		var forward := forward_at(samples, index)
		var basis := Basis.looking_at(forward, Vector3.UP)
		if index % 3 == 1:
			strip_at.append(Transform3D(basis, samples[index] + Vector3.UP * (CEILING_Y - 0.08)))
		if index % 2 == 0 and index > 0 and index < samples.size() - 1:
			dash_at.append(Transform3D(basis, samples[index] + Vector3.UP * 0.012))
		if index % LAMP_EVERY == 4 % LAMP_EVERY:
			var lamp := _lamp(samples[index] + Vector3.UP * (CEILING_Y - 0.9), Color("ffa24a"), LAMP_ENERGY, LAMP_REACH)
			if rng.randf() < 0.22:
				flickering.append(lamp)
	strips.instance_count = strip_at.size()
	for index in strip_at.size():
		strips.set_instance_transform(index, strip_at[index])
	dashes.instance_count = dash_at.size()
	for index in dash_at.size():
		dashes.set_instance_transform(index, dash_at[index])
	for multi in [strips, dashes]:
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		add_child(instance)
	# Rubble along the walkways, and now and then a lump of the ceiling.
	var concrete: Material = materials["walkway"]
	for index in range(4, samples.size() - 2, 5):
		if rng.randf() > 0.55:
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var right := forward_at(samples, index).cross(Vector3.UP).normalized()
		var at := samples[index] + right * side * rng.randf_range(GUTTER_OUT + 0.3, WALL_X - 0.4) + Vector3.UP * (WALKWAY_Y + 0.2)
		var lump := _box(Vector3(rng.randf_range(0.4, 1.3), rng.randf_range(0.3, 0.8), rng.randf_range(0.5, 1.6)), at, concrete)
		lump.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
	if not bool(bore.main):
		_build_collapse(samples)


func _build_collapse(samples: Array[Vector3]) -> void:
	var end := samples[samples.size() - 1]
	var forward := forward_at(samples, samples.size() - 1)
	var basis := Basis.looking_at(forward, Vector3.UP)
	_slab(Vector3(WALL_X * 2.2, CEILING_Y + 1.0, 1.0), end + Vector3.UP * (CEILING_Y * 0.5), materials["wall"], basis)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(end.x * 13.0 + end.z * 7.0)
	for lump in 16:
		var back := rng.randf_range(0.5, 9.0)
		var across := rng.randf_range(-WALL_X + 1.0, WALL_X - 1.0)
		var size := Vector3(rng.randf_range(1.0, 2.8), rng.randf_range(0.6, 2.4) * (1.0 - back / 12.0), rng.randf_range(1.0, 2.6))
		var at := end - forward * back + basis.x * across + Vector3.UP * size.y * 0.4
		_slab(size, at, materials["walkway"], Basis(Vector3.UP, rng.randf_range(0.0, TAU)).rotated(basis.x, rng.randf_range(-0.3, 0.3)))
	_lamp(end - forward * 6.0 + Vector3.UP * 4.5, Color("ff2a18"), 1.8, 12.0)
	_sign("COLLAPSED // NO THROUGH ROAD", end - forward * 11.0 + Vector3.UP * 4.6, -forward, Color("d27a6a"))


## A junction hall: a concrete box with a doorway on each connected side and
## the bores meeting its walls flush.
func _build_hall(hall_name: String, hall: Dictionary) -> void:
	var centre: Vector3 = hall.centre
	var doors: Array = hall.doors
	var floor_material: Material = materials["road"]
	_slab(Vector3(CHAMBER_HALF * 2.0 + 0.4, 0.6, CHAMBER_HALF * 2.0 + 0.4), centre + Vector3(0, -0.3, 0), floor_material)
	_slab(Vector3(CHAMBER_HALF * 2.0 + 2.0, 0.8, CHAMBER_HALF * 2.0 + 2.0), centre + Vector3(0, CHAMBER_HEIGHT + 0.4, 0), materials["ceiling"])
	var sides := {
		"north": [Vector3(0, 0, -1), Basis.IDENTITY],
		"south": [Vector3(0, 0, 1), Basis.IDENTITY],
		"east": [Vector3(1, 0, 0), Basis(Vector3.UP, PI * 0.5)],
		"west": [Vector3(-1, 0, 0), Basis(Vector3.UP, PI * 0.5)],
	}
	for side: String in sides:
		var outward: Vector3 = sides[side][0]
		var basis: Basis = sides[side][1]
		var wall_centre := centre + outward * (CHAMBER_HALF + 0.5)
		if doors.has(side):
			var piece := CHAMBER_HALF + 1.0 - WALL_X
			for along in [-1.0, 1.0]:
				_slab(Vector3(piece, CHAMBER_HEIGHT, 1.0), wall_centre + basis * Vector3(along * (WALL_X + piece * 0.5), CHAMBER_HEIGHT * 0.5, 0), materials["tile"], basis)
			_slab(Vector3(WALL_X * 2.0 + 0.2, CHAMBER_HEIGHT - CEILING_Y, 1.0), wall_centre + Vector3.UP * (CEILING_Y + (CHAMBER_HEIGHT - CEILING_Y) * 0.5), materials["wall"], basis)
		else:
			_slab(Vector3(CHAMBER_HALF * 2.0 + 2.0, CHAMBER_HEIGHT, 1.0), wall_centre + Vector3.UP * (CHAMBER_HEIGHT * 0.5), materials["tile"], basis)
	# Over every doorway, where it goes, facing into the hall.
	for side: String in doors:
		var outward: Vector3 = sides[side][0]
		var text := "OUTFALL"
		if (hall_name == "sump_hall" and side == "south") or (hall_name == "crossing_hall" and side == "north"):
			text = "ARENA"
		elif (hall_name == "sump_hall" and side == "west") or (hall_name == "crossing_hall" and side == "east"):
			text = "NO THROUGH ROAD"
		_sign(text, centre + outward * (CHAMBER_HALF - 0.1) + Vector3.UP * (CEILING_Y + 1.6), -outward)
	if bool(hall.pillar):
		var pillar := _slab(Vector3(3.0, CHAMBER_HEIGHT, 3.0), centre + Vector3.UP * (CHAMBER_HEIGHT * 0.5), materials["tile"])
		pillar.name = "HallPillar"
	else:
		for corner in [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(-11, 0, 11), Vector3(11, 0, 11)]:
			_slab(Vector3(2.0, CHAMBER_HEIGHT, 2.0), centre + corner + Vector3.UP * (CHAMBER_HEIGHT * 0.5), materials["tile"])
	# A pool of blood where the gutters empty into the hall's sump.
	var pool := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14.0, 9.0)
	plane.material = blood_material
	pool.mesh = plane
	pool.position = centre + Vector3(-6.0, 0.02, 6.0)
	add_child(pool)
	_lamp(centre + Vector3(-9.0, CHAMBER_HEIGHT - 1.5, 0.0), Color("ffa24a"), 3.0, 22.0)
	_lamp(centre + Vector3(9.0, CHAMBER_HEIGHT - 1.5, 0.0), Color("ffa24a"), 3.0, 22.0)


## The end of the line: a headwall across the bore with the old culvert
## through it, and daylight (red) at the far end of the culvert.
func _build_mouth() -> void:
	var samples: Array[Vector3] = bore_samples["outfall_bore"]
	var forward := forward_at(samples, samples.size() - 1)
	var basis := Basis.looking_at(forward, Vector3.UP)
	var head := _lab("wall", Color(0.40, 0.36, 0.31))
	var culvert_half := 3.25
	var culvert_height := 4.2
	var piece := WALL_X + 0.4 - culvert_half
	for side in [-1.0, 1.0]:
		_slab(Vector3(piece, CEILING_Y + 0.4, 1.0), MOUTH + basis * Vector3(side * (culvert_half + piece * 0.5), (CEILING_Y + 0.4) * 0.5, -0.5), head, basis)
	_slab(Vector3(culvert_half * 2.0, CEILING_Y + 0.4 - culvert_height, 1.0), MOUTH + basis * Vector3(0, culvert_height + (CEILING_Y + 0.4 - culvert_height) * 0.5, -0.5), head, basis)
	# The culvert itself, eight metres of it, then the light.
	var neck := 8.0
	var middle := MOUTH + forward * (neck * 0.5 + 1.0)
	_slab(Vector3(culvert_half * 2.0, 0.4, neck), middle + Vector3.UP * -0.2, materials["road"], basis)
	_slab(Vector3(culvert_half * 2.0 + 1.0, 0.5, neck), middle + Vector3.UP * (culvert_height + 0.25), head, basis)
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.5, culvert_height, neck), middle + basis * Vector3(side * (culvert_half + 0.25), culvert_height * 0.5, 0), head, basis)
	var daylight := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(culvert_half * 2.0, culvert_height)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd6b0")
	glow.emission_enabled = true
	glow.emission = Color("ffb48a")
	glow.emission_energy_multiplier = 6.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = glow
	daylight.mesh = plane
	add_child(daylight)
	daylight.global_transform = Transform3D(basis, MOUTH + forward * (neck + 0.9) + Vector3.UP * (culvert_height * 0.5))
	_lamp(MOUTH + forward * (neck - 1.0) + Vector3.UP * 2.0, Color("ffc49a"), 6.0, 34.0)
	# Everything in the gutters runs out through it.
	var out := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(culvert_half * 2.0 - 0.6, neck + 12.0)
	sheet.material = _blood_flowing(forward)
	out.mesh = sheet
	add_child(out)
	out.global_transform = Transform3D(basis, MOUTH + forward * (neck * 0.5 - 5.0) + Vector3.UP * 0.02)
	_sign("OUTFALL // DRY FALLS", MOUTH + Vector3.UP * (culvert_height + 1.1) - forward * 0.05, -forward)


func _build_breakables() -> void:
	for entry: Array in BARRICADES:
		var samples: Array[Vector3] = bore_samples[str(entry[0])]
		var index := clampi(int(float(entry[1]) / SAMPLE_STEP), 1, samples.size() - 2)
		var forward := forward_at(samples, index)
		var right := forward.cross(Vector3.UP).normalized()
		var prop: BreakableProp = BREAKABLE_PROP.new()
		prop.name = "TunnelBarricade_%02d" % breakables.size()
		prop.build("scrap_barricade" if breakables.size() % 2 == 0 else "timber_barricade", Vector3(3.6, 1.3, 0.46), 18.0)
		add_child(prop)
		prop.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), samples[index] + right * float(entry[2]) + Vector3.UP * 0.65)
		breakables.append(prop)


## The way out, gate to mouth: each main bore's centre line, joined through
## the halls (a right turn through the sump hall, straight across the
## crossing hall).
func _build_drive_line() -> void:
	drive_line.clear()
	drive_line.append(CAR_START - Vector3(0.0, 0.9, 0.0))
	drive_line.append(Vector3(0.0, 0.0, 6.0))
	drive_line.append_array(bore_samples["gate_bore"])
	var sump: Vector3 = HALLS.sump_hall.centre
	drive_line.append(sump + Vector3(0.0, 0.0, 12.0))
	drive_line.append(sump + Vector3(5.0, 0.0, 7.0))
	drive_line.append(sump + Vector3(11.0, 0.0, 2.5))
	drive_line.append_array(bore_samples["long_bore"])
	var crossing: Vector3 = HALLS.crossing_hall.centre
	drive_line.append(crossing + Vector3(0.0, 0.0, -8.0))
	drive_line.append(crossing)
	drive_line.append(crossing + Vector3(0.0, 0.0, 8.0))
	drive_line.append_array(bore_samples["outfall_bore"])


func _build_car() -> void:
	car = VehicleDriver.make_car(3)
	car.position = CAR_START
	add_child(car)
	car.impact.connect(_on_car_impact)
	driver = VehicleDriver.new()
	driver.name = "Driver"
	add_child(driver)
	driver.got_out.connect(_on_got_out)
	driver.got_in.connect(_on_got_in)
	audio = DERBY_AUDIO.new()
	audio.name = "TunnelAudio"
	add_child(audio)
	audio.attach_engine_to(car)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = CAR_START + Vector3(-2.4, 0.3, 0.0)
	add_child(player)
	player_collider = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	player_collider.shape = capsule
	player.add_child(player_collider)
	camera = Camera3D.new()
	camera.position.y = 0.77
	camera.fov = 80.0
	camera.far = 700.0
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

func in_car() -> bool:
	return driver != null and driver.driving


## E: out of the car when it is slow enough, back in when standing beside it.
func toggle_vehicle() -> bool:
	if completed:
		return false
	if in_car():
		return driver.get_out()
	if driver.can_get_in(player.global_position):
		return driver.get_in()
	return false


func _on_got_out(standing: Vector3, facing_yaw: float) -> void:
	_stand_player(standing, facing_yaw)
	WorldHistory.record_event("derby_tunnels_got_out", {"location": LOCATION, "vehicle": str(car.name), "entered": entered})


func _stand_player(standing: Vector3, facing_yaw: float) -> void:
	player.global_position = standing
	player.velocity = Vector3.ZERO
	player_collider.disabled = false
	yaw = facing_yaw
	pitch = -0.05
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	camera.current = true


func _on_got_in() -> void:
	player_collider.disabled = true


## A car grinding against a barricade at walking pace shoves it over in the
## end: the impact rule only counts closing speed, so a car that came round a
## hall corner slowly and caught one on its wing was stuck there for good.
## How far the car's centre can be from a barricade's edge and still be
## pressed against it (half a car width, and some).
const SHOVE_REACH := 2.4
## Share of its closing speed a car keeps when it breaks through a barricade.
const BREAKTHROUGH_KEEP := 0.8
const SHOVE_SECONDS := 1.2
var _shove_time := {}


func _shove(delta: float) -> void:
	var pushing := float(car.throttle) > 0.2 and absf(driver.speed()) < 4.0
	for prop in breakables:
		if not is_instance_valid(prop) or (prop as BreakableProp).broken:
			continue
		# Measured from the barricade's own edges, not its centre: a car pressed
		# against the end of a 3.6 m barricade is well away from its middle.
		var local: Vector3 = prop.global_transform.affine_inverse() * car.global_position
		var outside := Vector2(maxf(0.0, absf(local.x) - 1.8), maxf(0.0, absf(local.z) - 0.23))
		var near := outside.length() < SHOVE_REACH
		if not (pushing and near):
			_shove_time.erase(prop.name)
			continue
		_shove_time[prop.name] = float(_shove_time.get(prop.name, 0.0)) + delta
		if float(_shove_time[prop.name]) < SHOVE_SECONDS:
			continue
		_shove_time.erase(prop.name)
		var result := (prop as BreakableProp).strike((prop as BreakableProp).integrity + 1.0, car.global_position.direction_to(prop.global_position))
		if bool(result.get("broken", false)):
			smashed += 1
			WorldHistory.record_event("derby_tunnels_debris_smashed", {"location": LOCATION, "prop": str(prop.name), "speed": 0.0, "shoved": true})


func _on_car_impact(other: Node, closing_speed: float, self_share: float) -> void:
	if not is_instance_valid(other):
		return
	if other is BreakableProp:
		var result: Dictionary = (other as BreakableProp).impact(closing_speed, car.global_position.direction_to(other.global_position), self_share)
		if bool(result.get("broken", false)) and bool(result.get("accepted", true)):
			# Through it, not stopped by it: the barricade was solid until the
			# frame it broke, so the physics took the car's whole speed off. It
			# keeps most of it, the way driving through one should feel.
			var heading := -car.global_transform.basis.z.slide(Vector3.UP).normalized()
			var kept := maxf(car.linear_velocity.length(), closing_speed * BREAKTHROUGH_KEEP)
			car.linear_velocity = heading * kept + Vector3.UP * car.linear_velocity.y
			smashed += 1
			WorldHistory.record_event("derby_tunnels_debris_smashed", {"location": LOCATION, "prop": str(other.name), "speed": snappedf(closing_speed, 0.1)})
		if audio != null:
			audio.play_impact(clampf(closing_speed / 20.0, 0.25, 1.0), other.global_position, "panel")
	elif closing_speed > 6.0 and audio != null:
		audio.play_impact(clampf(closing_speed / 24.0, 0.1, 1.0), car.global_position, "heavy")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not in_car():
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.15, 0.95)
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_E:
				toggle_vehicle()
			elif key.keycode == KEY_R:
				reset_car()
			elif key.keycode == KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	var beat := Time.get_ticks_msec() * 0.001
	for index in flickering.size():
		var lamp := flickering[index]
		var buzz := sin(beat * (31.0 + index * 7.0)) + sin(beat * (7.3 + index * 3.1))
		lamp.light_energy = 0.3 if buzz > 1.3 else LAMP_ENERGY


func _physics_process(delta: float) -> void:
	if gate_open < 1.0:
		gate_open = minf(1.0, gate_open + delta / GATE_SECONDS)
		gate.position.y = smoothstep(0.0, 1.0, gate_open) * (CEILING_Y + 0.4)
	if completed:
		return
	if in_car():
		player.global_position = car.global_position + Vector3.UP * 0.4
		top_speed = maxf(top_speed, absf(driver.speed()))
		if audio != null:
			audio.update_engine(driver.speed(), float(car.throttle), float(car.condition))
		if car.global_position.y < -40.0:
			var nearest := _nearest_on_line(car.global_position)
			car.recover(drive_line[nearest] + Vector3.UP * 1.2)
		_shove(delta)
	else:
		if audio != null:
			audio.update_engine(0.0, 0.0, float(car.condition))
		var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
		var direction := (Basis(Vector3.UP, yaw) * input).normalized()
		var pace := WALK_SPEED * (1.6 if Input.is_action_pressed("sprint") else 1.0)
		player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 16.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 16.0 * delta)
		player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
		player.move_and_slide()
		player.rotation.y = yaw
		camera.rotation = Vector3(pitch, 0, 0)
	_check_progress()
	_update_hud()


func _body() -> Node3D:
	return car if in_car() else player


func _check_progress() -> void:
	if completed:
		return
	var at := _body().global_position
	if not entered and at.z < GATE_Z + ENTERED_Z:
		entered = true
		FacilityRoutes.traverse("derby_tunnels")
		WorldHistory.record_event("derby_tunnels_entered", {
			"location": LOCATION,
			"by": "driving" if in_car() else "walking",
			"vehicle": str(car.name) if in_car() else "",
			"route_id": route_id,
		})
	if entered and Vector2(at.x - MOUTH_TRIGGER.x, at.z - MOUTH_TRIGGER.z).length() <= MOUTH_REACH and absf(at.y - MOUTH_TRIGGER.y) < 6.0:
		_leave("driving" if in_car() else "walking")


## Into the culvert and on to the dry falls. The route is filed here, so the
## handoff is waiting for the Hunt whatever happens at the falls.
func _leave(by: String) -> void:
	completed = true
	completed_by = by
	WorldHistory.begin_ledger_batch()
	FacilityRoutes.traverse("dry_falls")
	WorldHistory.record_event("derby_tunnels_left", {
		"location": LOCATION,
		"by": by,
		"vehicle": str(car.name) if by == "driving" else "",
		"left_behind": "" if by == "driving" else str(car.name),
		"smashed": smashed,
		"destination": DESTINATION,
		"route_id": str(FacilityRoutes.pending_surface_handoff().get("route_id", route_id)),
	})
	WorldHistory.commit_ledger_batch()
	if by == "driving":
		driver.driving = false
		VehicleDriver.carry(car)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	travel_requested = true
	left_tunnels.emit(by)
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Interstitial.travel(DESTINATION, CAPTION)


## R: stuck against a kerb or nosed into a wall, the car is put back on the
## road at the nearest point of the way out, facing along it.
func reset_car() -> bool:
	if completed or not in_car() or driver == null:
		return false
	var nearest := _nearest_on_line(car.global_position)
	var ahead := drive_line[mini(nearest + 1, drive_line.size() - 1)]
	var at := drive_line[nearest]
	var facing := (ahead - at).slide(Vector3.UP)
	car.recover(at + Vector3.UP * 1.2, Basis.looking_at(facing.normalized(), Vector3.UP) if facing.length() > 0.01 else Basis.IDENTITY)
	WorldHistory.record_event("derby_tunnels_car_reset", {"location": LOCATION, "at": [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)]})
	return true


func _nearest_on_line(at: Vector3) -> int:
	var best := 0
	var best_distance := INF
	for index in drive_line.size():
		var distance := at.distance_squared_to(drive_line[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _update_hud() -> void:
	if completed:
		objective.text = ""
		status.text = ""
		prompt.text = ""
		return
	objective.text = "OBJECTIVE // FOLLOW THE BLOOD TO THE OUTFALL"
	var at := _body().global_position
	var left_to_go := drive_line.size() - _nearest_on_line(at)
	status.text = "THE DERBY TUNNELS // OUTFALL %d M" % maxi(0, left_to_go * int(SAMPLE_STEP))
	if in_car():
		status.text += "   //   %03d KM/H" % int(absf(driver.speed()) * 3.6)
		prompt.text = "WASD DRIVE   //   E GET OUT   //   R RESET" if absf(driver.speed()) <= VehicleDriver.GET_OUT_SPEED else "WASD DRIVE"
		if gate_open < 1.0:
			prompt.text = "THE GATE IS GOING UP"
	elif driver.can_get_in(player.global_position):
		prompt.text = "E // GET IN"
	else:
		prompt.text = "WASD MOVE   //   SHIFT RUN"
