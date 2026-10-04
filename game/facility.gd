extends Node3D

## The underground facility as one place (Greg, 4 October): "one connected
## space (levels, tunnels, rooms, elevators/lifts walked in-world), not a chain
## of separate scenes with splash transitions."
##
## The connective skeleton of DESIGN/FACILITY.md: every room on the first-run
## spine and the doctor's line sits at its true position in one frame, joined
## by corridors and real lifts (`FacilityElevator`), on one player, with no
## scene change until the Surface Gate. Rooms are placeholder shells on the
## 4 m grid with their real footprints; the art-tunnels-07 kit and each room's
## own content replace them piece by piece.

signal zone_exit_reached()

const JUMP_CLIMB := preload("res://systems/jump_climb.gd")
const BODY_CAM := preload("res://systems/body_cam_feel.gd")
const LOOK := preload("res://systems/look_settings.gd")
const FACILITY_ROUTES := preload("res://systems/facility_routes.gd")

## The vat. The player wakes in front of it, facing deeper in (-Z).
const START := Vector3(0, 1.0, -2.4)
const WALK := 3.4
const SPRINT := 1.6
## Past this line on the surface level is the Ashbloom: a true scene boundary.
const SURFACE_Y := 20.0
const GATE_Z := -137.0

const CONCRETE := Color("1d1915")
const RUST := Color("231a14")
const CEILING := Color("100d0b")

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.04
var lifts := {}
var prompt: Label
var where: Label
var exit_reached := false
## Set by tests and the playbot: a world point to walk to, sprinting.
var bot_goal = null


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050404")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("2a2018")
	environment.ambient_light_energy = 0.35
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_build_level_0c()
	_build_level_0d()
	_build_doctor_line()
	_build_surface()
	_build_player()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- 0C: Growing Floor, Examination Room, service artery, Service Arcade -----

func _build_level_0c() -> void:
	# Growing Floor (vat_chamber.tscn), origin at the vat.
	_room("GROWING FLOOR", 0.0, Vector2(-8, 8), Vector2(-26, 3.6), 4.4,
		{"e": [[-2.5, 3.0, 3.0]], "s": [[1.6, 1.2, 2.3]]})
	_box(Vector3(2.2, 3.2, 2.2), Vector3(0, 1.6, 0.0), Color("3a1410"))
	_sign("YOUR VAT", Vector3(0, 3.5, -1.2))
	# Examination Room behind the vat (doctor_route.gd), his door in the wall.
	_room("EXAMINATION ROOM", 0.0, Vector2(-3.5, 4.5), Vector2(3.6, 10.5), 3.1,
		{"s": [[0.5, 1.6, 2.3]]}, ["n"])
	# Service artery: from the staff door east to the arcade's west wall.
	_corridor_x(0.0, 8.0, 20.75, -2.5, 4.0, 3.4)
	_sign("SERVICE ARTERY", Vector3(14, 2.9, -2.5))
	# Service Arcade (service_arcade.tscn), origin (28, 0, 0).
	_room("SERVICE ARCADE", 0.0, Vector2(20.75, 35.25), Vector2(-58.5, 5.5), 8.2,
		{"w": [[-2.5, 4.0, 3.4]], "n": [[28.0, 3.0, 3.0]]})
	_box(Vector3(14.5, 0.4, 0.6), Vector3(28, 6.0, -48.0), RUST, false)
	_sign("PRESSURE GATE", Vector3(28, 5.4, -47.6))
	# Vestibule to Lift A.
	_corridor_z(0.0, 26.5, 29.5, -60.2, -58.5, 3.0)


# --- 0D: Lift A, Lower Works, heat elevator, drain grate --------------------

func _build_level_0d() -> void:
	var lift_a := FacilityElevator.new()
	lift_a.name = "LiftA"
	lift_a.position = Vector3(28, 0, -62)
	add_child(lift_a)
	lift_a.setup([-12.0, 0.0], ["0D LOWER WORKS", "0C SERVICE ARCADE"], [-1, 1], 1)
	lifts["transit"] = lift_a
	_corridor_z(-12.0, 26.5, 29.5, -66.0, -63.8, 3.0)
	# Lower Works (buried_city.tscn), origin (28, -12, -84).
	_room("LOWER WORKS", -12.0, Vector2(13, 43), Vector2(-136, -66), 11.8,
		{"s": [[28.0, 3.0, 3.0]]}, [], Rect2(36, -120, 2, 2), Rect2(26.2, -123.8, 3.6, 3.6))
	_sign("DRAIN GRATE // OLD DRAINS", Vector3(37, -10.6, -119))
	var heat := FacilityElevator.new()
	heat.name = "HeatElevator"
	heat.position = Vector3(28, 0, -122)
	add_child(heat)
	heat.setup([-12.0, SURFACE_Y], ["0D LOWER WORKS", "SURFACE"], [1, -1], 0)
	lifts["heat"] = heat
	_sign("HEAT ELEVATOR", Vector3(28, -8.6, -119.9))
	# Old Drains (old_drains.tscn) under the east floor, 8 m below the grate.
	_room("OLD DRAINS", -20.0, Vector2(34, 40), Vector2(-180, -114), 4.2, {"n": [[37.0, 3.0, 3.0]]})
	_sign("STORM OUTFALL", Vector3(37, -17.0, -179))


# --- The doctor's line: Lift D, Support Unit, Vehicle Bay -------------------

func _build_doctor_line() -> void:
	var lift_d := FacilityElevator.new()
	lift_d.name = "LiftD"
	lift_d.position = Vector3(0.5, 0, 12.6)
	add_child(lift_d)
	lift_d.setup([-14.0, 0.0], ["0D SUPPORT UNIT", "0C EXAMINATION"], [-1, -1], 1)
	lifts["doctor"] = lift_d
	# Support Unit (support_unit.tscn), origin (0.5, -14, 6).
	_room("SUPPORT UNIT", -14.0, Vector2(-6.75, 7.75), Vector2(-102, 10.6), 9.0,
		{"s": [[0.5, 3.6, 3.0]], "n": [[0.5, 4.0, 4.0]]})
	# Doctor's Vehicle Bay (doctor_vehicle_bay.tscn), origin (0.5, -14, -114).
	_room("DOCTOR'S VEHICLE BAY", -14.0, Vector2(-8.5, 9.5), Vector2(-128, -102), 6.0,
		{"s": [[0.5, 4.0, 4.0]], "n": [[0.5, 4.0, 4.0]]})
	_sign("RAMP // SURFACE", Vector3(0.5, -9.5, -127.5))


# --- Surface: the heat elevator head-house and the gate ---------------------

func _build_surface() -> void:
	_room("SURFACE HEAD-HOUSE", SURFACE_Y, Vector2(24, 32), Vector2(-135, -123.8), 4.0,
		{"s": [[28.0, 3.6, 4.0]], "n": [[28.0, 3.0, 3.0]]})
	_sign("SURFACE GATE // THE ASHBLOOM", Vector3(28, SURFACE_Y + 3.4, -134.6))
	_box(Vector3(30, 0.4, 20), Vector3(28, SURFACE_Y - 0.2, -145), Color("3a3026"))
	var day := OmniLight3D.new()
	day.light_color = Color("fff1d8")
	day.light_energy = 4.0
	day.omni_range = 18.0
	day.position = Vector3(28, SURFACE_Y + 6.0, -142)
	add_child(day)


# --- Player -----------------------------------------------------------------

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = START
	player.floor_snap_length = 0.35
	add_child(player)
	player.set_meta("surface", "concrete")
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collider.shape = capsule
	player.add_child(collider)
	camera = Camera3D.new()
	camera.fov = 88.0
	camera.position.y = 0.77
	player.add_child(camera)
	camera.current = true


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	where = Label.new()
	where.position = Vector2(24, 18)
	where.add_theme_color_override("font_color", Color("e0442a"))
	layer.add_child(where)
	prompt = Label.new()
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.position = Vector2(24, -60)
	prompt.add_theme_color_override("font_color", Color("ead4ad"))
	layer.add_child(prompt)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= LOOK.dx(event.relative) * 0.0026
		pitch = clampf(pitch - LOOK.dy(event.relative) * 0.0024, -1.15, 0.95)
	if event.is_action_pressed("interact", false, true):
		interact()
	if JUMP_CLIMB.is_jump_key(event):
		JUMP_CLIMB.press(player, yaw, 1.0, "facility_climbed")


## Uses whichever lift the player stands in or in front of.
func interact() -> bool:
	for lift: FacilityElevator in lifts.values():
		if lift.use(player.global_position):
			return true
	return false


func _physics_process(delta: float) -> void:
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	var sprinting := Input.is_action_pressed("sprint")
	if bot_goal != null:
		var to: Vector3 = bot_goal - player.global_position
		to.y = 0.0
		direction = to.normalized() if to.length() > 0.25 else Vector3.ZERO
		sprinting = true
		if direction != Vector3.ZERO:
			yaw = atan2(-direction.x, -direction.z)
	if not JUMP_CLIMB.busy(player):
		var pace := WALK * (SPRINT if sprinting else 1.0)
		player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 26.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 26.0 * delta)
		JUMP_CLIMB.fall(player, delta)
		player.move_and_slide()
	player.rotation.y = yaw
	BODY_CAM.apply(camera, player, delta, pitch)
	_update_hud()
	if not exit_reached and player.global_position.y > SURFACE_Y - 1.0 and player.global_position.z < GATE_Z:
		_leave()


func _update_hud() -> void:
	var at := player.global_position
	var line := ""
	for lift: FacilityElevator in lifts.values():
		line = lift.prompt_for(at)
		if line != "":
			break
	prompt.text = line
	where.text = "SUBLEVEL %s" % ("SURFACE" if at.y > SURFACE_Y - 2.0 else "0C" if at.y > -6.0 else "0E" if at.y < -18.0 else "0D")


## The Surface Gate: the first zone exit. Same ledger as the Lower Works' own
## heat elevator (buried_city.gd), so the Ashbloom handoff lands the same way.
func _leave() -> void:
	exit_reached = true
	zone_exit_reached.emit()
	if OS.get_environment("ATG_TEST_MODE") == "1":
		return
	WorldHistory.begin_ledger_batch()
	if str(FACILITY_ROUTES.ensure().get("active_route", "")) != FACILITY_ROUTES.ROUTE_HEAT_ELEVATOR:
		FACILITY_ROUTES.begin(FACILITY_ROUTES.ROUTE_HEAT_ELEVATOR)
	FACILITY_ROUTES.traverse("heat_elevator")
	WorldHistory.record_event("facility_surface_gate_reached", {"location": "surface_head_house"})
	WorldHistory.commit_ledger_batch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Interstitial.travel("res://bone_yard_hunt.tscn", "surface gate // out into the ashbloom expanse")


# --- Geometry helpers (placeholder shells on the grid) ----------------------

## A room shell: floor, ceiling and four walls. `gaps` maps a face (n = -Z,
## s = +Z, e = +X, w = -X) to [[centre along the wall, width, height], ...].
## `skip` drops faces another room already provides. Optional holes cut the
## floor (a grate) and the ceiling (a shaft passing up).
func _room(title: String, y: float, xs: Vector2, zs: Vector2, height: float, gaps: Dictionary, skip: Array = [], floor_hole := Rect2(), ceiling_hole := Rect2()) -> void:
	var rect := Rect2(xs.x, zs.x, xs.y - xs.x, zs.y - zs.x)
	_plate(y - 0.2, rect, floor_hole, CONCRETE)
	_plate(y + height + 0.2, rect, ceiling_hole, CEILING)
	if not skip.has("n"):
		_wall_x(zs.x, xs, y, height, gaps.get("n", []))
	if not skip.has("s"):
		_wall_x(zs.y, xs, y, height, gaps.get("s", []))
	if not skip.has("w"):
		_wall_z(xs.x, zs, y, height, gaps.get("w", []))
	if not skip.has("e"):
		_wall_z(xs.y, zs, y, height, gaps.get("e", []))
	var centre := Vector3((xs.x + xs.y) * 0.5, y, (zs.x + zs.y) * 0.5)
	_sign(title, centre + Vector3(0, minf(height - 0.5, 3.2), 0))
	# Lighting pools on a ~10 m grid.
	var steps := Vector2i(maxi(1, int((xs.y - xs.x) / 10.0)), maxi(1, int((zs.y - zs.x) / 10.0)))
	for i in steps.x:
		for j in steps.y:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color("ffb27a")
			lamp.light_energy = 1.6
			lamp.omni_range = 9.0
			lamp.position = Vector3(xs.x + (xs.y - xs.x) * (i + 0.5) / steps.x, y + height - 0.6, zs.x + (zs.y - zs.x) * (j + 0.5) / steps.y)
			add_child(lamp)


## A corridor along X at z, 4 m grid: floor, ceiling, two side walls.
func _corridor_x(y: float, x0: float, x1: float, z: float, width: float, height: float) -> void:
	var rect := Rect2(x0, z - width * 0.5, x1 - x0, width)
	_plate(y - 0.2, rect, Rect2(), CONCRETE)
	_plate(y + height + 0.2, rect, Rect2(), CEILING)
	for side: int in [-1, 1]:
		_box(Vector3(x1 - x0, height, 0.3), Vector3((x0 + x1) * 0.5, y + height * 0.5, z + side * (width * 0.5 + 0.15)), RUST)
	_lamp(Vector3((x0 + x1) * 0.5, y + height - 0.4, z))


func _corridor_z(y: float, x0: float, x1: float, z0: float, z1: float, height: float) -> void:
	var rect := Rect2(x0, z0, x1 - x0, z1 - z0)
	_plate(y - 0.2, rect, Rect2(), CONCRETE)
	_plate(y + height + 0.2, rect, Rect2(), CEILING)
	for x: float in [x0 - 0.15, x1 + 0.15]:
		_box(Vector3(0.3, height, z1 - z0), Vector3(x, y + height * 0.5, (z0 + z1) * 0.5), RUST)
	_lamp(Vector3((x0 + x1) * 0.5, y + height - 0.4, (z0 + z1) * 0.5))


## A horizontal slab over `rect` (x, z), with an optional rectangular hole.
func _plate(y: float, rect: Rect2, hole: Rect2, color: Color) -> void:
	var pieces: Array[Rect2] = [rect]
	if hole.size != Vector2.ZERO:
		pieces = [
			Rect2(rect.position.x, rect.position.y, hole.position.x - rect.position.x, rect.size.y),
			Rect2(hole.end.x, rect.position.y, rect.end.x - hole.end.x, rect.size.y),
			Rect2(hole.position.x, rect.position.y, hole.size.x, hole.position.y - rect.position.y),
			Rect2(hole.position.x, hole.end.y, hole.size.x, rect.end.y - hole.end.y),
		]
	for piece in pieces:
		if piece.size.x > 0.01 and piece.size.y > 0.01:
			_box(Vector3(piece.size.x, 0.4, piece.size.y), Vector3(piece.get_center().x, y, piece.get_center().y), color)


func _wall_x(z: float, xs: Vector2, y: float, height: float, gaps: Array) -> void:
	for run in _runs(xs, y, height, gaps):
		_box(Vector3(run[1] - run[0], run[3] - run[2], 0.3), Vector3((run[0] + run[1]) * 0.5, (run[2] + run[3]) * 0.5, z), RUST)


func _wall_z(x: float, zs: Vector2, y: float, height: float, gaps: Array) -> void:
	for run in _runs(zs, y, height, gaps):
		_box(Vector3(0.3, run[3] - run[2], run[1] - run[0]), Vector3(x, (run[2] + run[3]) * 0.5, (run[0] + run[1]) * 0.5), RUST)


## Splits a wall span into solid pieces [from, to, bottom, top] around gaps.
func _runs(span: Vector2, y: float, height: float, gaps: Array) -> Array:
	var runs: Array = []
	var cursor := span.x
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	for gap in sorted:
		var from: float = gap[0] - gap[1] * 0.5
		var to: float = gap[0] + gap[1] * 0.5
		if from > cursor:
			runs.append([cursor, from, y, y + height])
		if gap[2] < height:
			runs.append([from, to, y + gap[2], y + height])
		cursor = to
	if span.y > cursor:
		runs.append([cursor, span.y, y, y + height])
	return runs


func _box(size: Vector3, at: Vector3, color: Color, solid := true) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	if not solid:
		mesh.position = at
		add_child(mesh)
		return
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)


func _lamp(at: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffb27a")
	lamp.light_energy = 1.2
	lamp.omni_range = 7.0
	lamp.position = at
	add_child(lamp)


func _sign(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = Color("c8a070")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)
