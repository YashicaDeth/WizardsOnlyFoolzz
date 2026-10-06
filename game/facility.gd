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

## Closer than this a hall title is hidden (it fades in over the next 3 m).
const TITLE_HIDE_INSIDE := 8.0

## Job 5's cut-down v0.1 route. Turning this off restores the older room
## scenes and their optional puzzles without deleting them.
const V01_ONE_MAP := true
## OPEN dial: keep removed branches visibly sealed instead of presenting
## misleading dead ends. Greg can flip this without restoring their puzzles.
const V01_DISABLED_ROUTES_AS_SEALED := true
## Greg, 5 Oct: v0.1 ends at the Surface Gate (systems/v01_ending.gd):
## daylight, silence then wind, the title over the first view, TO BE
## CONTINUED, back to the title menu. false = walk on into the Hunt as before.
const V01_ENDS_AT_GATE := true

const JUMP_CLIMB := preload("res://systems/jump_climb.gd")
const BODY_CAM := preload("res://systems/body_cam_feel.gd")
const LOOK := preload("res://systems/look_settings.gd")
const FACILITY_ROUTES := preload("res://systems/facility_routes.gd")
const TUNNEL_NETWORK := preload("res://facility_tunnel_network.tscn")
const TUNNEL_KIT := preload("res://systems/facility_tunnel_kit.gd")
const ZONE_IDENTITY_SCRIPT := preload("res://systems/facility_zone_identity.gd")
const V01_ENDING := preload("res://systems/v01_ending.gd")

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
## Fittings in tall halls hang on rods to this height above the floor.
const LAMP_HANG := 4.6
## Dial (DESIGN/REMASTER_LOG.md, job5 p1): "worn" lays the route as a broken,
## scuffed painted floor line; "off" drops it (the lit thresholds still lead).
const ROUTE_LINE := "worn"
## Dial: caged wall lamps that wash the hall walls at each pool row, so the
## arcade and Lower Works show their bounds. 0 turns them off.
const WALL_WASH_ENERGY := 7.0
## Dial (REMASTER_LOG imp-67): each zone its own surfaces, landmark and story
## props (systems/facility_zone_identity.gd). false = the shared kit look.
const ZONE_IDENTITY := true

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.04
var lifts := {}
var tunnels: Node3D
var prompt: Label
var where: Label
var exit_reached := false
## Tests leave the gate inert; one that wants the real ending sets this.
var play_ending_in_tests := false
## The running ending, once the gate is reached.
var ending: CanvasLayer
## When embedded in vat_chamber the authored opening keeps its one player,
## camera and HUD. This node contributes the connected geometry and lifts.
var embedded := false
## Set by tests and the playbot: a world point to walk to, sprinting.
var bot_goal = null
var _prop_materials := {}
var identity = null


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
	if ZONE_IDENTITY:
		identity = ZONE_IDENTITY_SCRIPT.new()
		identity.name = "ZoneIdentity"
		add_child(identity)
	_build_level_0c()
	_build_level_0d()
	if not embedded:
		_build_doctor_line()
	_build_surface()
	for lift: FacilityElevator in lifts.values():
		TUNNEL_KIT.dress_lift(lift)
	if identity != null:
		identity.apply(self)
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
	# v0.1 removes the pressure-gate scan; the beam stays, its name does not.
	if not (embedded and V01_ONE_MAP):
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
	# The v0.1 ending is blinding daylight: the open gate reads as a white-out
	# from the whole head-house, and the light pours in along the floor.
	var glare := MeshInstance3D.new()
	glare.name = "DaylightGlare"
	var sheet := BoxMesh.new()
	sheet.size = Vector3(14.0, 10.0, 0.05)
	glare.mesh = sheet
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color("fff4e0")
	white.emission_enabled = true
	white.emission = Color("fff4e0")
	white.emission_energy_multiplier = 6.0
	glare.material_override = white
	# Just past the threshold, so the white fills the doorway down to the
	# floor instead of hanging as a card over a dark strip of ground.
	glare.position = Vector3(28, SURFACE_Y + 3.0, -136.3)
	glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glare)
	# Daylight spilling back through the gate lights its jambs and the
	# head-house wall, so the white-out reads as a doorway, not a floating card.
	var spill := OmniLight3D.new()
	spill.name = "GateSpill"
	spill.light_color = Color("fff1d8")
	spill.light_energy = 2.4
	spill.omni_range = 7.0
	spill.omni_attenuation = 1.2
	spill.position = Vector3(28, SURFACE_Y + 2.2, -133.6)
	add_child(spill)
	var shaft := SpotLight3D.new()
	shaft.name = "DaylightShaft"
	shaft.light_color = Color("fff1d8")
	shaft.light_energy = 14.0
	shaft.spot_range = 16.0
	shaft.spot_angle = 24.0
	shaft.shadow_enabled = true
	shaft.position = Vector3(28, SURFACE_Y + 2.2, -139.5)
	shaft.rotation.x = -0.12
	shaft.rotation.y = PI
	add_child(shaft)


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
	# In the heat shaft at any height, the ride is the next thing.
	if at.z < -118.0 and at.x > 25.0 and at.x < 31.0:
		return "RIDE THE HEAT ELEVATOR TO DAYLIGHT"
	if at.y < -6.0:
		return "CROSS LOWER WORKS TO THE HEAT ELEVATOR"
	if at.x < 8.0:
		return "GO THROUGH THE EAST STAFF DOOR"
	if at.z > -57.0:
		return "CROSS THE SERVICE ARCADE TO THE TRANSIT LIFT"
	return "RIDE THE TRANSIT LIFT DOWN"


## The body-cam location stamp for a point on the v0.1 route.
func location_for(at: Vector3) -> String:
	if at.y > SURFACE_Y - 2.0:
		return "SURFACE  //  HEAD-HOUSE"
	if at.y < -6.0:
		return "SUBLEVEL 0D  //  LOWER WORKS"
	if at.y < -1.0 or at.z < -58.5:
		return "SUBLEVEL 0C  //  LIFT SHAFT"
	if at.x < 8.0:
		return "SUBLEVEL 0C  //  GROWING FLOOR"
	if at.x < 20.75:
		return "SUBLEVEL 0C  //  SERVICE ARTERY"
	return "SUBLEVEL 0C  //  SERVICE ARCADE"


## The Surface Gate: the first zone exit. Same ledger as the Lower Works' own
## heat elevator (buried_city.gd), so the Ashbloom handoff lands the same way.
func _leave() -> void:
	exit_reached = true
	zone_exit_reached.emit()
	if OS.get_environment("ATG_TEST_MODE") == "1" and not play_ending_in_tests:
		return
	WorldHistory.begin_ledger_batch()
	if str(FACILITY_ROUTES.ensure().get("active_route", "")) != FACILITY_ROUTES.ROUTE_HEAT_ELEVATOR:
		FACILITY_ROUTES.begin(FACILITY_ROUTES.ROUTE_HEAT_ELEVATOR)
	FACILITY_ROUTES.traverse("heat_elevator")
	WorldHistory.record_event("facility_surface_gate_reached", {"location": "surface_head_house"})
	WorldHistory.commit_ledger_batch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if V01_ENDS_AT_GATE:
		# On the tree root: it outlives this scene into the world and the menu.
		ending = V01_ENDING.new()
		get_tree().root.add_child(ending)
		ending.begin()
		return
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
	# A hall's title hangs over its middle: read from the entry, gone before
	# you walk under it, where it rode up into the subtitle line (bughunt-79).
	var title_sign := _sign(title, centre + Vector3(0, minf(height - 0.5, 3.2), 0))
	title_sign.visibility_range_begin = TITLE_HIDE_INSIDE
	title_sign.visibility_range_begin_margin = 3.0
	title_sign.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Pools on a ~10 m grid, hung on drop rods at working height: from an 8 m
	# or 12 m ceiling the old fittings never reached the floor and the arcade
	# and Lower Works rendered black. Black still sits between the pools.
	var steps := Vector2i(maxi(1, int((xs.y - xs.x) / 10.0)), maxi(1, int((zs.y - zs.x) / 10.0)))
	var hang := minf(height - 0.1, LAMP_HANG)
	var count := 0
	for i in steps.x:
		for j in steps.y:
			var at := Vector3(xs.x + (xs.y - xs.x) * (i + 0.5) / steps.x, y + hang, zs.x + (zs.y - zs.x) * (j + 0.5) / steps.y)
			if height - hang > 0.3:
				_drop_rod(at, y + height)
			# Large halls cast shadows from every other fitting only.
			_lamp(at, steps.x * steps.y <= 6 or count % 2 == 0)
			count += 1


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
func _lamp(at: Vector3, shadows := true) -> void:
	var tube := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(1.1, 0.06, 0.14)
	tube.mesh = bar
	var glow := StandardMaterial3D.new()
	glow.albedo_color = LAMP_COLOR
	glow.emission_enabled = true
	glow.emission = LAMP_COLOR
	glow.emission_energy_multiplier = 4.0
	tube.material_override = glow
	tube.position = at
	add_child(tube)
	var hood := MeshInstance3D.new()
	var shade := BoxMesh.new()
	shade.size = Vector3(1.3, 0.12, 0.42)
	hood.mesh = shade
	hood.material_override = _prop_material("duct")
	hood.position = at + Vector3(0, 0.09, 0)
	add_child(hood)
	var lamp := SpotLight3D.new()
	lamp.light_color = LAMP_COLOR
	# Low distance falloff so the pool lands hard on the floor 4.6 m down;
	# the cone edge, not the distance, is what leaves black between pools.
	lamp.light_energy = 14.0
	lamp.spot_range = 9.5
	lamp.spot_angle = 50.0
	lamp.spot_attenuation = 0.45
	lamp.spot_angle_attenuation = 0.6
	lamp.shadow_enabled = shadows
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 26.0
	lamp.distance_fade_length = 10.0
	lamp.position = at + Vector3(0, -0.08, 0)
	lamp.rotation.x = -PI * 0.5
	add_child(lamp)


func _drop_rod(at: Vector3, ceiling_y: float) -> void:
	var rod := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, ceiling_y - at.y, 0.05)
	rod.mesh = mesh
	rod.material_override = _prop_material("cable")
	rod.position = Vector3(at.x, (at.y + ceiling_y) * 0.5, at.z)
	add_child(rod)


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
		# Zone identity: vessels are the Lower Works' own; here the stalls
		# are the landmark, and the first tank stood in front of them.
		if identity == null:
			_story_tank(Vector3(23.0, 1.45, z), 0.75, 2.9, "service_arcade")
		_story_monitor(Vector3(33.9, 1.25, z - 2.2), PI * 0.5, "service_arcade", false)
	_story_box("CableTray", Vector3(0.22, 0.16, 55.0), Vector3(33.5, 6.85, -25.5), "cable", "service_arcade", "cable")
	_story_box("CableTray", Vector3(0.16, 0.12, 55.0), Vector3(33.15, 6.78, -25.5), "cable", "service_arcade", "cable")
	_story_monitor(Vector3(28.0, 1.35, -46.8), 0.0, "service_arcade", true)
	_danger_light(Vector3(28.0, 5.7, -47.0), 7.0)
	# Cameras over each threshold: someone watches the route you take.
	_story_cctv(Vector3(21.2, 4.6, -0.6), Vector3(26.0, 0.0, -4.0), "service_arcade")
	_story_cctv(Vector3(30.6, 2.8, -58.2), Vector3(28.0, 0.0, -52.0), "service_arcade")
	_dress_walls("service_arcade", 0.0, Vector2(20.75, 35.25), [-4.0, -14.5, -25.5, -36.0, -46.5, -55.0], 6.4)


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
	_story_cctv(Vector3(30.4, -9.2, -66.6), Vector3(28.0, -12.0, -74.0), "lower_works")
	_story_cctv(Vector3(31.4, -8.4, -119.6), Vector3(28.0, -12.0, -112.0), "lower_works")
	_dress_walls("lower_works", -12.0, Vector2(13.0, 43.0), [-70.0, -78.0, -86.0, -94.0, -102.0, -110.0, -118.0, -126.0], 9.0)


## The painted route line, worn: dashes of uneven length with scuffed-out
## breaks, on the concrete texture so the grime shows through the paint.
func _route_strip(at: Vector3, size: Vector3) -> void:
	if ROUTE_LINE == "off":
		return
	var end := at.z + size.z * 0.5
	var z := at.z - size.z * 0.5
	var index := 0
	while z < end - 0.4:
		var roll := _wear(index)
		var length := minf(1.2 + roll * 2.2, end - z)
		# About one dash in five is worn clean away.
		if roll > 0.18 or index == 0:
			var width := size.x * (0.75 + _wear(index + 31) * 0.25)
			var drift := (_wear(index + 7) - 0.5) * 0.05
			_story_box("RouteStripe", Vector3(width, size.y, length), Vector3(at.x + drift, at.y, z + length * 0.5), "route", "route", "route")
		z += length + 0.35 + _wear(index + 13) * 1.1
		index += 1


## A fixed scatter in 0..1, the same every run (captures compare).
func _wear(index: int) -> float:
	return fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0)


## Each hall wall shows at its pool rows: a caged wall lamp washes the wall
## face, and a service prop stands in that wash, alternating sides, so the dark
## frames a run of bays instead of hiding the room. Kit models and plain
## shapes only; nothing here is named or written on.
func _dress_walls(zone: String, y: float, xs: Vector2, rows: Array, height: float) -> void:
	var kinds := ["pipes", "drums", "crates", "junction", "vent", "pipes", "crates", "drums"]
	for index in rows.size():
		var z: float = rows[index]
		for side: int in [-1, 1]:
			var wall_x := xs.x + 0.15 if side < 0 else xs.y - 0.15
			var inward := float(-side)
			if WALL_WASH_ENERGY > 0.0:
				_wall_lamp(Vector3(wall_x + inward * 0.12, y + minf(height - 1.0, 3.4), z), inward)
			if (index + (0 if side < 0 else 1)) % 2 == 0:
				var at := Vector3(wall_x, y, z - 2.0)
				if identity == null or not identity.wall_slot(zone, at, inward):
					_wall_prop(kinds[(index * 2 + (side + 1) / 2) % kinds.size()], at, inward, zone)


func _wall_lamp(at: Vector3, inward: float) -> void:
	var fitting := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.12, 0.7)
	fitting.mesh = box
	fitting.material_override = _prop_material("wall_tube")
	fitting.position = at
	add_child(fitting)
	var hood := MeshInstance3D.new()
	var shade := BoxMesh.new()
	shade.size = Vector3(0.3, 0.06, 0.9)
	hood.mesh = shade
	hood.material_override = _prop_material("duct")
	hood.position = at + Vector3(-inward * 0.04, 0.09, 0)
	add_child(hood)
	var wash := OmniLight3D.new()
	wash.name = "WallWash"
	wash.light_color = LAMP_COLOR
	wash.light_energy = WALL_WASH_ENERGY
	wash.omni_range = 7.5
	wash.omni_attenuation = 0.8
	wash.distance_fade_enabled = true
	wash.distance_fade_begin = 30.0
	wash.distance_fade_length = 8.0
	wash.position = at + Vector3(inward * 0.9, -0.3, 0)
	add_child(wash)


func _wall_prop(kind: String, at: Vector3, inward: float, zone: String) -> void:
	var out := Vector3(inward, 0, 0)
	match kind:
		"pipes":
			# The kit's pipe run, two lengths end to end along the wall.
			for step: float in [-2.0, 2.0]:
				var model := TUNNEL_KIT.GENERATED_MODEL.make("tunnel_pipe_run")
				if model == null:
					continue
				model.name = "WallPipes"
				model.transform = Transform3D(Basis.looking_at(Vector3(0, 0, inward), Vector3.UP), at + out * 0.27 + Vector3(0, 2.4, step))
				_register_story_prop(model, zone, "pipes")
		"vent":
			var vent := TUNNEL_KIT.GENERATED_MODEL.make("tunnel_vent")
			if vent != null:
				vent.name = "WallVent"
				vent.transform = Transform3D(Basis.looking_at(-out, Vector3.UP), at + out * 0.14 + Vector3(0, 1.05, 0))
				_register_story_prop(vent, zone, "vent")
		"drums":
			for spot: Vector3 in [Vector3(0.55, 0, -0.5), Vector3(0.6, 0, 0.25), Vector3(1.25, 0, -0.1)]:
				var drum := MeshInstance3D.new()
				drum.name = "Drum"
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.3
				cylinder.bottom_radius = 0.3
				cylinder.height = 0.9
				cylinder.radial_segments = 10
				drum.mesh = cylinder
				drum.material_override = _prop_material("drum")
				drum.position = at + Vector3(spot.x * inward, 0.45, spot.z)
				drum.rotation.y = spot.z * 3.0
				_register_story_prop(drum, zone, "drums")
		"crates":
			_story_box("Crate", Vector3(1.1, 0.9, 1.1), at + Vector3(0.75 * inward, 0.45, -0.4), "crate", zone, "crates")
			_story_box("Crate", Vector3(1.0, 0.8, 1.0), at + Vector3(0.8 * inward, 1.3, -0.3), "crate", zone, "crates")
			_story_box("Crate", Vector3(0.9, 0.7, 0.9), at + Vector3(0.7 * inward, 0.35, 0.8), "crate", zone, "crates")
		"junction":
			# A fuse cabinet with its conduit climbing to the ceiling services.
			_story_box("Junction", Vector3(0.35, 1.1, 0.8), at + Vector3(0.18 * inward, 1.5, 0), "console", zone, "junction")
			for offset: float in [-0.25, 0.25]:
				_story_box("Conduit", Vector3(0.1, 4.2, 0.1), at + Vector3(0.1 * inward, 4.15, offset), "cable", zone, "junction")


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
	# A service lamp on each tank: props stand in their own pool.
	var work := SpotLight3D.new()
	work.name = "TankLamp"
	work.light_color = LAMP_COLOR
	work.light_energy = 11.0
	work.spot_range = height + 3.0
	work.spot_angle = 34.0
	work.spot_attenuation = 0.5
	work.distance_fade_enabled = true
	work.distance_fade_begin = 22.0
	work.distance_fade_length = 8.0
	add_child(work)
	work.look_at_from_position(at + Vector3(radius + 0.9, height * 0.5 + 1.6, 0), at + Vector3(0, height * 0.1, 0))


## The generated CCTV (the one SecurityCamera wears), as a still prop: no
## cone, no alarm. v0.1 has no "creep past it".
func _story_cctv(at: Vector3, watching: Vector3, zone: String) -> void:
	var model := TUNNEL_KIT.GENERATED_MODEL.make("cctv")
	if model == null:
		return
	model.name = "WatchingCamera"
	_register_story_prop(model, zone, "cctv")
	model.look_at_from_position(at, watching)
	# The model looks along +Z; look_at aims -Z.
	model.rotate_object_local(Vector3.UP, PI)


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
	# The screen lights its own console and the floor in front of it.
	var spill := OmniLight3D.new()
	spill.name = "ScreenSpill"
	spill.light_color = DANGER_COLOR if danger else SCREEN_COLOR
	# Low and close: the console body round the screen shows, so the screen
	# sits in a cabinet instead of floating as a pale card.
	spill.light_energy = 0.9
	spill.omni_range = 2.4
	spill.omni_attenuation = 1.2
	spill.position = Vector3(0, -0.1, -0.45)
	console.add_child(spill)


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
			# Paint over the floor's own concrete: grime and wear show through.
			material = TUNNEL_KIT.material("floor").duplicate() as StandardMaterial3D
			material.albedo_color = ROUTE_COLOR.lerp(Color("6a6258"), 0.45).darkened(0.2)
		"screen":
			# A dim CRT, not a lamp: at 1.8x the screens floated as white quads.
			material.albedo_color = Color("1c2418")
			material.emission_enabled = true
			material.emission = SCREEN_COLOR
			material.emission_energy_multiplier = 0.12
			# Rolling bands on the tube, so it reads as a screen, not a slab.
			var bands := NoiseTexture2D.new()
			bands.width = 64
			bands.height = 64
			bands.noise = FastNoiseLite.new()
			bands.noise.frequency = 0.08
			material.emission_texture = bands
			material.uv1_scale = Vector3(0.4, 3.0, 1.0)
		"danger_screen":
			material.albedo_color = Color("2a0d0a")
			material.emission_enabled = true
			material.emission = DANGER_COLOR
			material.emission_energy_multiplier = 0.9
		"wall_tube":
			material.albedo_color = LAMP_COLOR
			material.emission_enabled = true
			material.emission = LAMP_COLOR
			material.emission_energy_multiplier = 1.2
		"cable":
			material.albedo_color = Color("0b0c0a")
			material.roughness = 0.72
		# Props wear the kit's ambientCG grime, not flat colour.
		"duct", "console":
			material = TUNNEL_KIT.material("ceiling").duplicate() as StandardMaterial3D
			material.albedo_color = Color("5a554c") if key == "duct" else Color("7a7468")
		"tank", "drum", "crate":
			material = TUNNEL_KIT.material("door").duplicate() as StandardMaterial3D
			material.albedo_color = {"tank": Color("6e6052"), "drum": Color("5a5c48"), "crate": Color("6a5a48")}[key]
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


func _sign(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = Color("c8a070")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)
	return label
