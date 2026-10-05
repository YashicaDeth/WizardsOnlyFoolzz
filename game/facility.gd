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

## Job 5's cut-down v0.1 route. Turning this off restores the older room
## scenes and their optional puzzles without deleting them.
const V01_ONE_MAP := true
## OPEN dial: keep removed branches visibly sealed instead of presenting
## misleading dead ends. Greg can flip this without restoring their puzzles.
const V01_DISABLED_ROUTES_AS_SEALED := true

const JUMP_CLIMB := preload("res://systems/jump_climb.gd")
const BODY_CAM := preload("res://systems/body_cam_feel.gd")
const LOOK := preload("res://systems/look_settings.gd")
const FACILITY_ROUTES := preload("res://systems/facility_routes.gd")
const TUNNEL_NETWORK := preload("res://facility_tunnel_network.tscn")
const TUNNEL_KIT := preload("res://systems/facility_tunnel_kit.gd")

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
## DESIGN.md 28 Sep / Greg 5 Oct: harsh sick green-white pools, black between,
## red only on danger. Shells wear the tunnel kit's grime, not flat colour.
const LAMP_COLOR := Color("d2ecc0")
const SURFACES := {CONCRETE: "floor", RUST: "wall", CEILING: "ceiling"}
const ROUTE_COLOR := Color("81906f")
const SCREEN_COLOR := Color("b8d49f")
const DANGER_COLOR := Color("a52d20")

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.04
var lifts := {}
var tunnels: Node3D
var prompt: Label
var where: Label
var exit_reached := false
## When embedded in vat_chamber the authored opening keeps its one player,
## camera and HUD. This node contributes the connected geometry and lifts.
var embedded := false
## Set by tests and the playbot: a world point to walk to, sprinting.
var bot_goal = null
var _prop_materials := {}


func _ready() -> void:
	if not embedded:
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
	if not embedded:
		_build_doctor_line()
	_build_surface()
	for lift: FacilityElevator in lifts.values():
		TUNNEL_KIT.dress_lift(lift)
	if not embedded:
		_build_player()
		_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func attach_player(body: CharacterBody3D, view: Camera3D) -> void:
	player = body
	camera = view


# --- 0C: Growing Floor, Examination Room, service artery, Service Arcade -----

func _build_level_0c() -> void:
	# Growing Floor (vat_chamber.tscn), origin at the vat.
	if not embedded:
		_room("GROWING FLOOR", 0.0, Vector2(-8, 8), Vector2(-26, 3.6), 4.4,
			{"e": [[-2.5, 3.0, 3.0]], "s": [[1.6, 1.2, 2.3]]})
		_box(Vector3(2.2, 3.2, 2.2), Vector3(0, 1.6, 0.0), Color("3a1410"))
		_sign("YOUR VAT", Vector3(0, 3.5, -1.2))
		# Examination Room behind the vat (doctor_route.gd), his door in the wall.
		_room("EXAMINATION ROOM", 0.0, Vector2(-3.5, 4.5), Vector2(3.6, 10.5), 3.1,
			{"s": [[0.5, 1.6, 2.3]]}, ["n"])
	# Service artery and its side tunnels: the tunnel kit network, staff door
	# east to the arcade's west wall (facility_tunnel_network.gd).
	tunnels = TUNNEL_NETWORK.instantiate()
	add_child(tunnels)
	# Service Arcade (service_arcade.tscn), origin (28, 0, 0).
	_room("SERVICE ARCADE", 0.0, Vector2(20.75, 35.25), Vector2(-58.5, 5.5), 8.2,
		{"w": [[-2.5, 4.0, 3.4]], "n": [[28.0, 3.0, 3.0]]})
	_box(Vector3(14.5, 0.4, 0.6), Vector3(28, 6.0, -48.0), RUST, false)
	_sign("PRESSURE GATE", Vector3(28, 5.4, -47.6))
	_build_service_arcade_dressing()
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
	var drain_hole := Rect2() if embedded and V01_DISABLED_ROUTES_AS_SEALED else Rect2(36, -120, 2, 2)
	_room("LOWER WORKS", -12.0, Vector2(13, 43), Vector2(-136, -66), 11.8,
		{"s": [[28.0, 3.0, 3.0]]}, [], drain_hole, Rect2(26.2, -123.8, 3.6, 3.6))
	_build_lower_works_dressing()
	var heat := FacilityElevator.new()
	heat.name = "HeatElevator"
	heat.position = Vector3(28, 0, -122)
	add_child(heat)
	heat.setup([-12.0, SURFACE_Y], ["0D LOWER WORKS", "SURFACE"], [1, -1], 0)
	lifts["heat"] = heat
	_sign("HEAT ELEVATOR", Vector3(28, -8.6, -119.9))
	if not embedded:
		_sign("DRAIN GRATE // OLD DRAINS", Vector3(37, -10.6, -119))
		# Old Drains are a later route, outside the v0.1 one-map spine.
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
	_route_strip(Vector3(28, SURFACE_Y + 0.025, -129.4), Vector3(0.55, 0.025, 10.5))
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
	if player == null:
		return
	if embedded:
		if not exit_reached and player.global_position.y > SURFACE_Y - 1.0 and player.global_position.z < GATE_Z:
			_leave()
		return
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


## One actionable line for the shared opening HUD. It describes the next
## physical threshold, rather than resurrecting the removed puzzle chain.
func objective_for(at: Vector3) -> String:
	if at.y > SURFACE_Y - 2.0:
		return "OPEN THE SURFACE GATE"
	if at.y < -6.0:
		if at.z > -118.0:
			return "CROSS LOWER WORKS TO THE HEAT ELEVATOR"
		return "RIDE THE HEAT ELEVATOR TO DAYLIGHT"
	if at.x < 8.0:
		return "GO THROUGH THE EAST STAFF DOOR"
	if at.z > -57.0:
		return "CROSS THE SERVICE ARCADE TO THE TRANSIT LIFT"
	return "RIDE THE TRANSIT LIFT DOWN"


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
	# Sparse pools on a ~16 m grid. The unlit spans matter as much as the pools,
	# and the Lower Works stays within the forward-light budget.
	var steps := Vector2i(maxi(1, int((xs.y - xs.x) / 16.0)), maxi(1, int((zs.y - zs.x) / 16.0)))
	for i in steps.x:
		for j in steps.y:
			_lamp(Vector3(xs.x + (xs.y - xs.x) * (i + 0.5) / steps.x, y + height - 0.1, zs.x + (zs.y - zs.x) * (j + 0.5) / steps.y))


## A corridor along X at z, 4 m grid: floor, ceiling, two side walls.
func _corridor_x(y: float, x0: float, x1: float, z: float, width: float, height: float) -> void:
	var rect := Rect2(x0, z - width * 0.5, x1 - x0, width)
	_plate(y - 0.2, rect, Rect2(), CONCRETE)
	_plate(y + height + 0.2, rect, Rect2(), CEILING)
	for side: int in [-1, 1]:
		_box(Vector3(x1 - x0, height, 0.3), Vector3((x0 + x1) * 0.5, y + height * 0.5, z + side * (width * 0.5 + 0.15)), RUST)
	_lamp(Vector3((x0 + x1) * 0.5, y + height - 0.05, z))


func _corridor_z(y: float, x0: float, x1: float, z0: float, z1: float, height: float) -> void:
	var rect := Rect2(x0, z0, x1 - x0, z1 - z0)
	_plate(y - 0.2, rect, Rect2(), CONCRETE)
	_plate(y + height + 0.2, rect, Rect2(), CEILING)
	for x: float in [x0 - 0.15, x1 + 0.15]:
		_box(Vector3(0.3, height, z1 - z0), Vector3(x, y + height * 0.5, (z0 + z1) * 0.5), RUST)
	_lamp(Vector3((x0 + x1) * 0.5, y + height - 0.05, (z0 + z1) * 0.5))


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
	if SURFACES.has(color):
		mesh.material_override = TUNNEL_KIT.material(SURFACES[color])
	else:
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


## A caged ceiling tube and the hard pool straight under it.
func _lamp(at: Vector3) -> void:
	var tube := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(1.1, 0.06, 0.14)
	tube.mesh = bar
	var glow := StandardMaterial3D.new()
	glow.albedo_color = LAMP_COLOR
	glow.emission_enabled = true
	glow.emission = LAMP_COLOR
	glow.emission_energy_multiplier = 2.5
	tube.material_override = glow
	tube.position = at
	add_child(tube)
	var lamp := SpotLight3D.new()
	lamp.light_color = LAMP_COLOR
	lamp.light_energy = 6.0
	lamp.spot_range = 7.0
	lamp.spot_angle = 52.0
	lamp.spot_attenuation = 1.4
	lamp.shadow_enabled = true
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 18.0
	lamp.distance_fade_length = 8.0
	lamp.position = at + Vector3(0, -0.08, 0)
	lamp.rotation.x = -PI * 0.5
	add_child(lamp)


# --- Authored route dressing -----------------------------------------------

## The arcade's thirteen structural bays are its navigational rhythm. Tanks,
## cable trays and service monitors explain the space without adding lore.
func _build_service_arcade_dressing() -> void:
	_route_strip(Vector3(28, 0.025, -27.0), Vector3(0.34, 0.025, 61.0))
	for bay in 13:
		var z := 2.5 - bay * 4.55
		_story_box("ArcadeFrame", Vector3(0.34, 5.4, 0.34), Vector3(22.0, 2.7, z), "frame", "service_arcade", "frame")
		_story_box("ArcadeFrame", Vector3(0.34, 5.4, 0.34), Vector3(34.0, 2.7, z), "frame", "service_arcade", "frame")
		_story_box("ArcadeFrame", Vector3(12.35, 0.34, 0.34), Vector3(28.0, 5.4, z), "frame", "service_arcade", "frame")
	for z: float in [-8.5, -25.0, -41.5]:
		_story_tank(Vector3(23.0, 1.45, z), 0.75, 2.9, "service_arcade")
		_story_monitor(Vector3(33.9, 1.25, z - 2.2), PI * 0.5, "service_arcade", false)
	_story_box("CableTray", Vector3(0.22, 0.16, 55.0), Vector3(33.5, 6.85, -25.5), "cable", "service_arcade", "cable")
	_story_box("CableTray", Vector3(0.16, 0.12, 55.0), Vector3(33.15, 6.78, -25.5), "cable", "service_arcade", "cable")
	_story_monitor(Vector3(28.0, 1.35, -46.8), 0.0, "service_arcade", true)
	_danger_light(Vector3(28.0, 5.7, -47.0), 7.0)


## Lower Works reads across its full height: a clear painted run to the heat
## lift, heavy edge machinery, hanging services and one red danger landmark.
func _build_lower_works_dressing() -> void:
	_route_strip(Vector3(28, -11.975, -94.5), Vector3(0.48, 0.025, 55.0))
	for z: float in [-74.0, -90.0, -106.0, -130.0]:
		for x: float in [15.5, 40.5]:
			_story_box("WorksColumn", Vector3(0.9, 9.5, 0.9), Vector3(x, -7.25, z), "frame", "lower_works", "frame")
		_story_box("WorksTruss", Vector3(25.8, 0.55, 0.7), Vector3(28.0, -2.8, z), "frame", "lower_works", "frame")
	for at: Vector3 in [Vector3(18.0, -10.1, -82.0), Vector3(38.0, -10.1, -98.0), Vector3(18.0, -10.1, -114.0)]:
		_story_tank(at, 1.35, 3.8, "lower_works")
	_story_box("OverheadDuct", Vector3(1.25, 1.1, 51.0), Vector3(18.0, -3.9, -95.0), "duct", "lower_works", "cable")
	_story_box("OverheadCable", Vector3(0.24, 0.18, 49.0), Vector3(38.0, -4.8, -96.0), "cable", "lower_works", "cable")
	_story_monitor(Vector3(24.2, -10.65, -72.0), -PI * 0.5, "lower_works", false)
	_story_monitor(Vector3(31.8, -10.65, -116.8), PI * 0.5, "lower_works", true)
	_danger_light(Vector3(28.0, -3.0, -119.0), 9.0)


func _route_strip(at: Vector3, size: Vector3) -> void:
	_story_box("RouteStripe", size, at, "route", "route", "route")


func _story_tank(at: Vector3, radius: float, height: float, zone: String) -> void:
	var tank := MeshInstance3D.new()
	tank.name = "ProcessTank"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.88
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	tank.mesh = cylinder
	tank.material_override = _prop_material("tank")
	tank.position = at
	_register_story_prop(tank, zone, "tank")
	_story_box("TankBand", Vector3(radius * 2.12, 0.16, radius * 2.12), at + Vector3(0, height * 0.22, 0), "frame", zone, "tank")
	_story_box("TankBand", Vector3(radius * 2.12, 0.16, radius * 2.12), at - Vector3(0, height * 0.22, 0), "frame", zone, "tank")


func _story_monitor(at: Vector3, heading: float, zone: String, danger: bool) -> void:
	var console := Node3D.new()
	console.name = "DangerMonitor" if danger else "ServiceMonitor"
	console.position = at
	console.rotation.y = heading
	add_child(console)
	console.set_meta("facility_story_prop", "monitor")
	console.set_meta("facility_zone", zone)
	console.add_to_group("facility_story_props")
	_story_box_local(console, "Console", Vector3(0.9, 1.4, 0.48), Vector3(0, 0, 0), "console")
	_story_box_local(console, "Screen", Vector3(0.62, 0.45, 0.035), Vector3(0, 0.25, -0.26), "danger_screen" if danger else "screen")
	_story_box_local(console, "Foot", Vector3(0.48, 0.12, 0.56), Vector3(0, -0.76, 0.02), "frame")


func _story_box(name: String, size: Vector3, at: Vector3, material_key: String, zone: String, kind: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _prop_material(material_key)
	mesh.position = at
	_register_story_prop(mesh, zone, kind)


func _story_box_local(parent: Node3D, name: String, size: Vector3, at: Vector3, material_key: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _prop_material(material_key)
	mesh.position = at
	parent.add_child(mesh)


func _register_story_prop(prop: Node3D, zone: String, kind: String) -> void:
	add_child(prop)
	prop.set_meta("facility_story_prop", kind)
	prop.set_meta("facility_zone", zone)
	prop.add_to_group("facility_story_props")


func _prop_material(key: String) -> StandardMaterial3D:
	if _prop_materials.has(key):
		return _prop_materials[key]
	var material := StandardMaterial3D.new()
	material.roughness = 0.82
	match key:
		"route":
			material.albedo_color = ROUTE_COLOR
			material.roughness = 0.62
		"screen":
			material.albedo_color = SCREEN_COLOR
			material.emission_enabled = true
			material.emission = SCREEN_COLOR
			material.emission_energy_multiplier = 1.8
		"danger_screen":
			material.albedo_color = DANGER_COLOR
			material.emission_enabled = true
			material.emission = DANGER_COLOR
			material.emission_energy_multiplier = 2.4
		"cable":
			material.albedo_color = Color("0b0c0a")
			material.roughness = 0.72
		"duct":
			material.albedo_color = Color("322f2a")
			material.metallic = 0.65
		"tank":
			material.albedo_color = Color("40372f")
			material.metallic = 0.4
		"console":
			material.albedo_color = Color("292722")
			material.metallic = 0.25
		_:
			material = TUNNEL_KIT.material("wall")
	_prop_materials[key] = material
	return material


func _danger_light(at: Vector3, reach: float) -> void:
	var light := SpotLight3D.new()
	light.name = "DangerPool"
	light.light_color = DANGER_COLOR
	light.light_energy = 3.4
	light.spot_range = reach
	light.spot_angle = 43.0
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 18.0
	light.distance_fade_length = 6.0
	light.position = at
	light.rotation.x = -PI * 0.5
	add_child(light)


func _sign(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = Color("c8a070")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)
