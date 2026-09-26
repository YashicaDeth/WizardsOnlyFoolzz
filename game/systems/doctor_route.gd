class_name DoctorRoute
extends Node3D

## The way on is through his door (Greg, 24 September 2026): "you can go back
## and break down the door with a weapon which shows the destruction physics",
## then "go through and down an actual elevator with an elevator and a door".
##
## Built onto the Growing Floor by `vat_chamber.gd`, which only forwards input
## and asks for a prompt line. This owns the near wall behind the player's vat
## (with the doorway and the observation glass he watched through), the door
## itself (`BreakableDoor`), the fire axe beside it, the examination room, and
## a lift car with doors that rides down to the Support Unit.
##
## Everything the room holds beyond the desk, the monitor showing the vat feed
## and the glass is Greg's to decide (DESIGN/ESCAPE_ROUTES.md), so the room is
## deliberately bare.

const DOOR_ID := "doctor_door"
const ROUTE_ID := "doctor_pursuit"
const ROOM_DISTRICT := "examination_room"
const DESTINATION := "res://support_unit.tscn"
const RESTRAINT_LABEL := "BROKEN MEDICAL RESTRAINT"
const AXE_LABEL := "FIRE AXE"
const GUN_LABEL := "CELL OUTZ BREACH NINE"

const OBJECTIVE_DOOR := "GET REVENGE // HE LEFT THROUGH THAT DOOR\nOR ESCAPE THE FACILITY"
const OBJECTIVE_DOWN := "GET REVENGE // FOLLOW HIM DOWN\nOR ESCAPE THE FACILITY"

## The near wall of the Growing Floor, behind the vat.
const WALL_Z := 3.6
const WALL_DEPTH := 0.5
const WALL_HEIGHT := 4.4
const WALL_HALF_SPAN := 8.0
const DOOR_AT := Vector3(1.6, 0.0, WALL_Z)
const DOOR_SIZE := Vector2(1.2, 2.3)
## The opening is the leaf plus a hair: the gap either side is too narrow for a
## body, so the only way through is the leaf.
const OPENING_HALF := 0.66
const OPENING_TOP := 2.36
## The observation glass, left of the door and straight behind the vat.
const WINDOW_X := Vector2(-2.6, -0.2)
const WINDOW_Y := Vector2(1.0, 2.3)

## The examination room, on the far side of the wall.
const ROOM_X := Vector2(-3.5, 4.5)
const ROOM_Z := Vector2(WALL_Z + WALL_DEPTH * 0.5, 10.5)
const ROOM_HEIGHT := 3.1
## The chamber's own floor slab runs to here; the room's floor starts where it stops.
const CHAMBER_FLOOR_END := 6.2

## The lift: landing doors in the room's back wall, the car in its shaft beyond.
const CAR_AT := Vector3(0.5, 0.0, 11.8)
const CAR_HALF := Vector2(1.0, 1.1)
const CAR_HEIGHT := 2.6
const CAR_OPENING_HALF := 0.8
const DESCENT := 14.0
const RIDE_SECONDS := 6.0
const DOOR_SECONDS := 0.9
const SHAFT_BOTTOM := -18.0

const AXE_AT := Vector3(3.5, 0.0, WALL_Z - WALL_DEPTH * 0.5 - 0.05)
const REACH := 2.4
const CHARGE_REACH := 1.7
const COOLDOWN := {"restraint": 0.45, "axe": 0.7, "body": 0.9, "gun": 0.35}
const BODY_HALF_HEIGHT := 0.85
const LOOK_SECONDS := 2.4

var chamber: Node3D
var door: BreakableDoor
var axe_model: Node3D
var held_axe: Node3D
var carrying_axe := false
var cooldown := 0.0
var room_entered := false
var _graded_as_office := false
var last_hit: Dictionary = {}

## Set by a test to see the hand-off without leaving the scene.
var travel_hook: Callable
var travel_requested := ""
var placeholder_shown := false

var car: Node3D
var car_doors: Array[Node3D] = []
var landing_doors: Array[Node3D] = []
var car_indicator: Label3D
var lift_state := "closed"
var doors_open := 0.0
var doors_target := 0.0
var ride_clock := 0.0
var car_y := 0.0

var feed_viewport: SubViewport
var _was_moving := false
var _look_left := 0.0
var _look_from := Vector2.ZERO
var _look_to := Vector2.ZERO


func build(owner_chamber: Node3D) -> void:
	chamber = owner_chamber
	name = "DoctorRoute"
	_build_near_wall()
	_build_door()
	_build_axe()
	_build_room()
	_build_lift()
	if door.broken:
		_open_up()


# --- Input and prompt, forwarded by the chamber. ---

## True when the event was used here, so the chamber does not also act on it.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		# The player looking for themselves ends the guided turn.
		_look_left = 0.0
		return false
	if not _can_act():
		return false
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return false
		if button.button_index == MOUSE_BUTTON_LEFT:
			return strike(held_weapon())
		if button.button_index == MOUSE_BUTTON_RIGHT and _gun_rounds() > 0:
			return strike("gun")
		return false
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return false
		if key.keycode == KEY_F:
			return strike("body")
		if key.keycode == KEY_E:
			return _use()
	return false


## What the prompt line should say here, or "" to leave it to the chamber.
func prompt_text() -> String:
	if not _can_act():
		return ""
	if lift_state == "riding" or lift_state == "returning":
		return "GOING DOWN" if lift_state == "riding" else "GOING UP"
	if lift_state == "arrived":
		return "[E] RIDE BACK UP" if placeholder_shown else ""
	if _in_car():
		return "[E] DOWN"
	if _near_landing() and lift_state == "closed":
		return "[E] CALL THE LIFT"
	if _axe_in_reach():
		return "[E] TAKE THE FIRE AXE"
	if not door.broken and _flat_distance(DOOR_AT) <= REACH + 0.6:
		var tool := held_weapon()
		var line := "[F] SHOULDER IT"
		if tool == "axe":
			line = "[CLICK] AXE THE DOOR   //   " + line
		elif tool == "restraint":
			line = "[CLICK] HIT IT WITH THE RESTRAINT   //   " + line
		if _gun_rounds() > 0:
			line += "   //   [RMB] SHOOT (%d)" % _gun_rounds()
		return "HIS DOOR  //  %s  //  %d%%\n%s" % [door.state.to_upper(), roundi(door.condition() * 100.0), line]
	return ""


func held_weapon() -> String:
	if carrying_axe:
		return "axe"
	if _carries(RESTRAINT_LABEL):
		return "restraint"
	return ""


## One blow at the door from where the player stands and looks. The body goes
## in shoulder first along the way they face; everything else lands where the
## crosshair meets the leaf.
func strike(weapon: String) -> bool:
	if weapon == "" or door == null or door.broken or cooldown > 0.0:
		return false
	var camera: Camera3D = chamber.camera
	var eye := camera.global_position
	var forward := -camera.global_transform.basis.z
	var point := Vector3.ZERO
	var direction := forward
	if weapon == "body":
		if _flat_distance(DOOR_AT) > CHARGE_REACH:
			return false
		var flat := Vector3(forward.x, 0.0, forward.z).normalized()
		if flat.dot(Vector3(0, 0, 1)) < 0.5:
			return false
		point = Vector3(clampf(chamber.player.global_position.x, DOOR_AT.x - 0.45, DOOR_AT.x + 0.45), 1.3, WALL_Z)
		direction = flat
		chamber.player.velocity += flat * 3.0
		chamber.breach_shake = maxf(chamber.breach_shake, 0.35)
		chamber.anatomy.call("apply_hit", "torso", 1.0, 0.0, "blunt")
	else:
		var hit := _aim_point(eye, forward)
		if hit == Vector3.INF:
			return false
		point = hit
		if weapon == "gun":
			_spend_round()
		chamber.breach_shake = maxf(chamber.breach_shake, 0.12 if weapon == "restraint" else 0.2)
		_swing_held()
	cooldown = float(COOLDOWN.get(weapon, 0.5))
	last_hit = door.hit(weapon, point, direction)
	if chamber.opening_audio != null:
		chamber.opening_audio.cue("glass" if weapon == "gun" else "tug")
	return true


func _use() -> bool:
	if lift_state == "arrived" and placeholder_shown:
		lift_state = "returning"
		ride_clock = 0.0
		return true
	if _in_car() and lift_state in ["open", "closed"]:
		_ride_down()
		return true
	if _near_landing() and lift_state == "closed":
		lift_state = "open"
		doors_target = 1.0
		if chamber.opening_audio != null:
			chamber.opening_audio.cue("door")
		return true
	if _axe_in_reach():
		_take_axe()
		return true
	return false


# --- Per frame. ---

func _physics_process(delta: float) -> void:
	if chamber == null:
		return
	cooldown = maxf(0.0, cooldown - delta)
	var moving: bool = chamber.can_move and chamber.breakout_complete
	if moving and not _was_moving:
		_on_first_steps()
	_was_moving = moving
	# Walking off ends the guided turn too: the player acting beats being
	# steered, and the turn must never bend a step they already chose.
	if _look_left > 0.0 and Input.get_vector("move_left", "move_right", "move_forward", "move_back").length_squared() > 0.0:
		_look_left = 0.0
	if _look_left > 0.0:
		_look_left = maxf(0.0, _look_left - delta)
		var t := smoothstep(0.0, 1.0, 1.0 - _look_left / LOOK_SECONDS)
		chamber.yaw = lerp_angle(_look_from.x, _look_to.x, t)
		chamber.pitch = lerpf(_look_from.y, _look_to.y, t)
	if not room_entered and door.broken and _in_room():
		room_entered = true
		FacilityRoutes.traverse(ROOM_DISTRICT)
		WorldHistory.record_event("doctor_route_room_entered", {"location": ROOM_DISTRICT})
		chamber.subtitle.text = "HIS ROOM  //  THE GLASS HE WATCHED YOU THROUGH"
	# His room has its own light, so its own grade (HouseLook).
	var in_office := _in_room() or _in_car(true)
	if in_office != _graded_as_office:
		_graded_as_office = in_office
		var look := get_node_or_null("/root/HouseLook")
		if look != null:
			look.set_area("doctor_office" if in_office else "")
	_update_lift(delta)


## Control arrives: the task names his door and the head turns to it, once,
## unless the player takes the look over themselves.
func _on_first_steps() -> void:
	if door.broken:
		chamber.objective_text = OBJECTIVE_DOWN
		return
	chamber.objective_text = OBJECTIVE_DOOR
	var to_door: Vector3 = DOOR_AT + Vector3(0, 1.3, 0) - chamber.camera.global_position
	_look_from = Vector2(chamber.yaw, chamber.pitch)
	_look_to = Vector2(atan2(-to_door.x, -to_door.z), clampf(atan2(to_door.y, Vector2(to_door.x, to_door.z).length()), -0.3, 0.3))
	_look_left = LOOK_SECONDS


func _on_door_broke(method: String) -> void:
	FacilityRoutes.begin(ROUTE_ID)
	WorldHistory.record_event("doctor_route_door_broken", {"method": method, "door_id": DOOR_ID})
	chamber.objective_text = OBJECTIVE_DOWN
	chamber.subtitle.text = "HIS DOOR IS DOWN"
	if chamber.opening_audio != null:
		chamber.opening_audio.cue("door")
	_open_up()


## What the room does once it is open to the player: the monitor shows the vat.
func _open_up() -> void:
	if feed_viewport != null:
		feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


# --- The lift. ---

func _ride_down() -> void:
	lift_state = "riding"
	doors_target = 0.0
	ride_clock = 0.0
	WorldHistory.record_event("doctor_route_elevator_taken", {"from": ROOM_DISTRICT, "to": DESTINATION})
	chamber.subtitle.text = ""
	if chamber.opening_audio != null:
		chamber.opening_audio.cue("door")


func _update_lift(delta: float) -> void:
	doors_open = move_toward(doors_open, doors_target, delta / DOOR_SECONDS)
	for index in car_doors.size():
		var side := -1.0 if index == 0 else 1.0
		car_doors[index].position.x = side * lerpf(CAR_OPENING_HALF * 0.5, CAR_OPENING_HALF * 1.45, doors_open)
		landing_doors[index].position.x = CAR_AT.x + side * lerpf(CAR_OPENING_HALF * 0.5, CAR_OPENING_HALF * 1.45, doors_open * (1.0 if car_y > -0.01 else 0.0))
	match lift_state:
		"riding":
			if doors_open > 0.0:
				_carry_player()
				return
			ride_clock += delta
			var t := clampf(ride_clock / RIDE_SECONDS, 0.0, 1.0)
			_set_car_y(-DESCENT * smoothstep(0.0, 1.0, t))
			_carry_player()
			car_indicator.text = ["0C", "B1", "B2", "B3", "SU"][mini(4, int(t * 4.99))]
			chamber.breach_shake = maxf(chamber.breach_shake, 0.05 * sin(t * PI))
			if t >= 1.0:
				_arrive()
		"returning":
			ride_clock += delta
			var t := clampf(ride_clock / RIDE_SECONDS, 0.0, 1.0)
			_set_car_y(-DESCENT * (1.0 - smoothstep(0.0, 1.0, t)))
			_carry_player()
			car_indicator.text = ["SU", "B3", "B2", "B1", "0C"][mini(4, int(t * 4.99))]
			if t >= 1.0:
				lift_state = "open"
				placeholder_shown = false
				doors_target = 1.0
		"arrived":
			_carry_player()


func _arrive() -> void:
	lift_state = "arrived"
	WorldHistory.record_event("doctor_route_elevator_arrived", {"to": DESTINATION})
	if ResourceLoader.exists(DESTINATION):
		travel_requested = DESTINATION
		if travel_hook.is_valid():
			travel_hook.call(DESTINATION)
		else:
			Interstitial.travel(DESTINATION, "down after him // the support unit")
		return
	# The Support Unit is being built by another lane. Say so plainly rather
	# than open the doors onto nothing.
	placeholder_shown = true
	chamber.subtitle.text = "THE CAR STOPS  //  SUPPORT UNIT NOT BUILT YET  //  THE DOORS STAY SHUT"


func _set_car_y(y: float) -> void:
	car_y = y
	car.position.y = y


## The car holds the body: it goes where the floor goes.
func _carry_player() -> void:
	if not _in_car(true):
		return
	var player: CharacterBody3D = chamber.player
	player.global_position.y = car_y + BODY_HALF_HEIGHT + 0.01
	player.velocity.y = 0.0


# --- Where the player is. ---

func _can_act() -> bool:
	return chamber != null and bool(chamber.can_move) and bool(chamber.breakout_complete)


func _flat_distance(to: Vector3) -> float:
	var offset: Vector3 = to - chamber.player.global_position
	offset.y = 0.0
	return offset.length()


## Nearer the axe than the door, so the two prompts never fight.
func _axe_in_reach() -> bool:
	if carrying_axe or axe_model == null or not axe_model.visible:
		return false
	var to_axe := _flat_distance(AXE_AT)
	return to_axe <= 1.8 and (door.broken or to_axe < _flat_distance(DOOR_AT))


func _in_room() -> bool:
	var at: Vector3 = chamber.player.global_position
	return at.x > ROOM_X.x and at.x < ROOM_X.y and at.z > ROOM_Z.x + 0.3 and at.z < ROOM_Z.y and at.y > -1.0


func _in_car(any_height := false) -> bool:
	var at: Vector3 = chamber.player.global_position
	var inside := absf(at.x - CAR_AT.x) < CAR_HALF.x - 0.1 and at.z > CAR_AT.z - CAR_HALF.y + 0.1 and at.z < CAR_AT.z + CAR_HALF.y
	return inside and (any_height or absf(at.y - (car_y + BODY_HALF_HEIGHT)) < 0.6)


func _near_landing() -> bool:
	var at: Vector3 = chamber.player.global_position
	return door.broken and absf(at.x - CAR_AT.x) < 1.6 and at.z > ROOM_Z.y - 2.2 and at.z < ROOM_Z.y and absf(car_y) < 0.01


## Where the crosshair meets the leaf, or INF when it does not.
func _aim_point(eye: Vector3, forward: Vector3) -> Vector3:
	if absf(forward.z) < 0.05:
		return Vector3.INF
	var t := (WALL_Z - eye.z) / forward.z
	if t < 0.0 or t > REACH:
		return Vector3.INF
	var point := eye + forward * t
	if absf(point.x - DOOR_AT.x) > DOOR_SIZE.x * 0.5 or point.y < 0.0 or point.y > DOOR_SIZE.y:
		return Vector3.INF
	return point


# --- Carry. ---

func _carries(label: String) -> bool:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if entry is Dictionary and str((entry as Dictionary).get("label", "")) == label:
			return true
	return false


func _gun_rounds() -> int:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if entry is Dictionary and str((entry as Dictionary).get("label", "")) == GUN_LABEL:
			return int((entry as Dictionary).get("rounds", 0))
	return 0


func _spend_round() -> void:
	var carry := Carry.new()
	for item in carry.items:
		if str(item.get("label", "")) == GUN_LABEL:
			item["rounds"] = maxi(0, int(item.get("rounds", 0)) - 1)
			break
	carry.save_to_history()


func _take_axe() -> void:
	carrying_axe = true
	axe_model.visible = false
	var carry := Carry.new()
	carry.items.append({"label": AXE_LABEL, "kind": "tool", "mass": 2.6, "perishes": false, "age": 0.0, "from": "growing_floor"})
	carry.save_to_history()
	WorldHistory.record_event("doctor_route_axe_taken", {"location": "growing_floor"})
	held_axe = _axe_mesh()
	LabSurface.hold_in_view(chamber.camera, held_axe)
	held_axe.rotation_degrees = Vector3(18.0, 12.0, -28.0)
	# Full size at arm's length filled a quarter of the first look at it.
	held_axe.scale = Vector3.ONE * 0.75
	held_axe.position += Vector3(0.06, -0.06, 0.0)
	chamber.subtitle.text = "FIRE AXE  //  TAKEN OFF THE WALL"


func _swing_held() -> void:
	if held_axe == null:
		return
	var rest := Vector3(18.0, 12.0, -28.0)
	var tween := create_tween()
	tween.tween_property(held_axe, "rotation_degrees", rest + Vector3(-70.0, -10.0, 20.0), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(held_axe, "rotation_degrees", rest, 0.3).set_trans(Tween.TRANS_QUAD)


# --- Building. ---

## The Growing Floor's near wall, in pieces around the doorway and the glass.
func _build_near_wall() -> void:
	var left := -WALL_HALF_SPAN
	var right := WALL_HALF_SPAN
	var door_left := DOOR_AT.x - OPENING_HALF
	var door_right := DOOR_AT.x + OPENING_HALF
	_wall_piece(Vector2(left, WINDOW_X.x), Vector2(0.0, WALL_HEIGHT))
	_wall_piece(WINDOW_X, Vector2(0.0, WINDOW_Y.x))
	_wall_piece(WINDOW_X, Vector2(WINDOW_Y.y, WALL_HEIGHT))
	_wall_piece(Vector2(WINDOW_X.y, door_left), Vector2(0.0, WALL_HEIGHT))
	_wall_piece(Vector2(door_left, door_right), Vector2(OPENING_TOP, WALL_HEIGHT))
	_wall_piece(Vector2(door_right, right), Vector2(0.0, WALL_HEIGHT))
	# The glass he watched through: dark from the tank's side, solid to a body.
	var glass := StaticBody3D.new()
	glass.name = "ObservationGlass"
	glass.position = Vector3((WINDOW_X.x + WINDOW_X.y) * 0.5, (WINDOW_Y.x + WINDOW_Y.y) * 0.5, WALL_Z)
	add_child(glass)
	var pane := MeshInstance3D.new()
	var pane_mesh := BoxMesh.new()
	pane_mesh.size = Vector3(WINDOW_X.y - WINDOW_X.x, WINDOW_Y.y - WINDOW_Y.x, 0.04)
	var pane_material := StandardMaterial3D.new()
	pane_material.albedo_color = Color(0.09, 0.12, 0.11, 0.42)
	pane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane_material.metallic = 0.6
	pane_material.roughness = 0.08
	pane_mesh.material = pane_material
	pane.mesh = pane_mesh
	glass.add_child(pane)
	var pane_shape := CollisionShape3D.new()
	var pane_box := BoxShape3D.new()
	pane_box.size = pane_mesh.size
	pane_shape.shape = pane_box
	glass.add_child(pane_shape)
	var sill := MeshInstance3D.new()
	var sill_mesh := BoxMesh.new()
	sill_mesh.size = Vector3(WINDOW_X.y - WINDOW_X.x + 0.1, 0.06, WALL_DEPTH + 0.06)
	sill_mesh.material = LabSurface.material("plate")
	sill.mesh = sill_mesh
	sill.position = Vector3(glass.position.x, WINDOW_Y.x, WALL_Z)
	add_child(sill)
	var sign := Label3D.new()
	sign.text = "EXAMINATION 0C  //  OBSERVATION"
	sign.font_size = 34
	sign.outline_size = 6
	sign.modulate = Color("d9d0b7")
	sign.position = Vector3(DOOR_AT.x, OPENING_TOP + 0.35, WALL_Z - WALL_DEPTH * 0.5 - 0.02)
	# Faces the Growing Floor (-Z), where it is read from.
	sign.rotation_degrees.y = 180.0
	sign.pixel_size = 0.004
	add_child(sign)


func _build_door() -> void:
	door = BreakableDoor.new()
	door.name = "DoctorDoor"
	add_child(door)
	door.position = DOOR_AT
	# BreakableDoor's room side is its -Z; his room is +Z of the Growing Floor.
	door.rotation.y = PI
	door.build(DOOR_ID, DOOR_SIZE, Color("b8b4a6"))
	door.broke_open.connect(_on_door_broke)


## A fire axe on a bracket by the door, where a facility keeps one.
func _build_axe() -> void:
	axe_model = Node3D.new()
	axe_model.name = "FireAxe"
	axe_model.position = AXE_AT + Vector3(0, 1.25, 0)
	add_child(axe_model)
	var backing := MeshInstance3D.new()
	var backing_mesh := BoxMesh.new()
	backing_mesh.size = Vector3(0.5, 1.15, 0.03)
	backing_mesh.material = WorldLook.surface(Color("7a1a12"), "paint", 1201)
	backing.mesh = backing_mesh
	backing.position = Vector3(0, 0, 0.03)
	axe_model.add_child(backing)
	var hung := _axe_mesh()
	hung.rotation_degrees = Vector3(0, 0, 12.0)
	axe_model.add_child(hung)
	var label := Label3D.new()
	label.text = "FIRE AXE"
	label.font_size = 28
	label.outline_size = 5
	label.pixel_size = 0.004
	label.modulate = Color("f0e2c8")
	label.position = Vector3(0, 0.7, 0)
	# Read from the Growing Floor side (-Z), like the door's sign.
	label.rotation_degrees.y = 180.0
	axe_model.add_child(label)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ff5a3a")
	lamp.light_energy = 0.9
	lamp.omni_range = 1.4
	lamp.position = Vector3(0, 0.6, -0.3)
	axe_model.add_child(lamp)
	if _carries(AXE_LABEL) or WorldHistory.event_count("doctor_route_axe_taken") > 0:
		axe_model.visible = false


func _axe_mesh() -> Node3D:
	var axe := Node3D.new()
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.018
	handle_mesh.bottom_radius = 0.022
	handle_mesh.height = 0.9
	handle_mesh.material = WorldLook.surface(Color("6b4a2a"), "paint", 1202)
	handle.mesh = handle_mesh
	axe.add_child(handle)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.24, 0.12, 0.025)
	head_mesh.material = WorldLook.surface(Color("a3241a"), "paint", 1203)
	head.mesh = head_mesh
	head.position = Vector3(0.07, 0.4, 0)
	axe.add_child(head)
	var edge := MeshInstance3D.new()
	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(0.04, 0.16, 0.02)
	edge_mesh.material = LabSurface.material("plate")
	edge.mesh = edge_mesh
	edge.position = Vector3(0.2, 0.4, 0)
	axe.add_child(edge)
	return axe


## His room: the desk facing the glass, the monitor on the vat feed, a lamp,
## and (Greg's office concept, 26 September) the rest of a working office:
## see `_dress_room`.
func _build_room() -> void:
	var width := ROOM_X.y - ROOM_X.x
	var centre_x := (ROOM_X.x + ROOM_X.y) * 0.5
	var depth := ROOM_Z.y - ROOM_Z.x
	var centre_z := (ROOM_Z.x + ROOM_Z.y) * 0.5
	_block(Vector3(width + 0.6, 0.4, ROOM_Z.y - CHAMBER_FLOOR_END + 0.2), Vector3(centre_x, -0.2, (CHAMBER_FLOOR_END + ROOM_Z.y) * 0.5), LabSurface.material("floor"))
	_block(Vector3(width + 0.6, 0.3, depth), Vector3(centre_x, ROOM_HEIGHT + 0.15, centre_z), LabSurface.material("ceiling"))
	_block(Vector3(0.3, ROOM_HEIGHT, depth), Vector3(ROOM_X.x - 0.15, ROOM_HEIGHT * 0.5, centre_z), LabSurface.material("wall"))
	_block(Vector3(0.3, ROOM_HEIGHT, depth), Vector3(ROOM_X.y + 0.15, ROOM_HEIGHT * 0.5, centre_z), LabSurface.material("wall"))
	# The back wall, around the landing doors.
	var lift_left := CAR_AT.x - CAR_OPENING_HALF
	var lift_right := CAR_AT.x + CAR_OPENING_HALF
	_block(Vector3(lift_left - ROOM_X.x, ROOM_HEIGHT, 0.3), Vector3((ROOM_X.x + lift_left) * 0.5, ROOM_HEIGHT * 0.5, ROOM_Z.y), LabSurface.material("wall"))
	_block(Vector3(ROOM_X.y - lift_right, ROOM_HEIGHT, 0.3), Vector3((ROOM_X.y + lift_right) * 0.5, ROOM_HEIGHT * 0.5, ROOM_Z.y), LabSurface.material("wall"))
	_block(Vector3(lift_right - lift_left, ROOM_HEIGHT - 2.3, 0.3), Vector3(CAR_AT.x, 2.3 + (ROOM_HEIGHT - 2.3) * 0.5, ROOM_Z.y), LabSurface.material("wall"))

	# The desk, facing the glass: he sat with his back to his door.
	var desk_at := Vector3((WINDOW_X.x + WINDOW_X.y) * 0.5, 0.0, ROOM_Z.x + 0.75)
	_block(Vector3(2.0, 0.07, 0.8), desk_at + Vector3(0, 0.84, 0), LabSurface.material("plate"), false)
	for corner in [Vector2(-0.92, -0.33), Vector2(0.92, -0.33), Vector2(-0.92, 0.33), Vector2(0.92, 0.33)]:
		_block(Vector3(0.06, 0.82, 0.06), desk_at + Vector3(corner.x, 0.41, corner.y), LabSurface.material("grime"), false)
	var desk_body := StaticBody3D.new()
	desk_body.position = desk_at + Vector3(0, 0.45, 0)
	add_child(desk_body)
	var desk_shape := CollisionShape3D.new()
	var desk_box := BoxShape3D.new()
	desk_box.size = Vector3(2.0, 0.9, 0.8)
	desk_shape.shape = desk_box
	desk_body.add_child(desk_shape)
	# The monitor, turned to his chair, showing the tank you were in.
	var monitor_at := desk_at + Vector3(0.45, 1.2, 0.12)
	_block(Vector3(0.9, 0.58, 0.08), monitor_at, LabSurface.material("plate"), false)
	_block(Vector3(0.08, 0.3, 0.08), desk_at + Vector3(0.45, 0.99, 0.1), LabSurface.material("grime"), false)
	feed_viewport = SubViewport.new()
	feed_viewport.name = "VatFeed"
	feed_viewport.size = Vector2i(256, 160)
	feed_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(feed_viewport)
	var feed_camera := Camera3D.new()
	feed_camera.fov = 58.0
	feed_viewport.add_child(feed_camera)
	feed_camera.look_at_from_position(Vector3(6.8, 3.5, 2.5), Vector3(0, 1.3, 0), Vector3.UP)
	var screen := MeshInstance3D.new()
	screen.name = "VatFeedScreen"
	var screen_mesh := QuadMesh.new()
	screen_mesh.size = Vector2(0.8, 0.5)
	var screen_material := StandardMaterial3D.new()
	screen_material.albedo_texture = feed_viewport.get_texture()
	screen_material.emission_enabled = true
	screen_material.emission_texture = feed_viewport.get_texture()
	screen_material.emission_energy_multiplier = 1.4
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mesh.material = screen_material
	screen.mesh = screen_mesh
	# Facing his chair, which is on the room side (+Z) of the desk.
	screen.position = monitor_at + Vector3(0, 0, 0.045)
	add_child(screen)
	var lamp := OmniLight3D.new()
	lamp.name = "ExamRoomLight"
	lamp.light_color = Color("cfe3da")
	lamp.light_energy = 2.2
	lamp.omni_range = 7.5
	lamp.position = Vector3(centre_x, ROOM_HEIGHT - 0.3, centre_z - 0.8)
	add_child(lamp)
	var tube := MeshInstance3D.new()
	var tube_mesh := BoxMesh.new()
	tube_mesh.size = Vector3(1.4, 0.05, 0.14)
	var tube_material := StandardMaterial3D.new()
	tube_material.albedo_color = Color("dff0e8")
	tube_material.emission_enabled = true
	tube_material.emission = Color("cfe3da")
	tube_material.emission_energy_multiplier = 2.2
	tube_mesh.material = tube_material
	tube.mesh = tube_mesh
	tube.position = lamp.position + Vector3(0, 0.25, 0)
	add_child(tube)
	# The tube is tired and green, not clinical white: the CRTs are what light
	# this room.
	lamp.light_color = Color("b9d3a6")
	lamp.light_energy = 1.5
	_dress_room()


## What Greg's office concept (26 September) has in it, built from the game's
## own boxes and surfaces rather than taken from the picture: a bank of green
## CRTs on a steel bench with a keyboard, a corkboard of his notes above it,
## filing cabinets by the lift, a gurney with an IV stand, and his blood on
## the floor. All against the walls: the way from his door to the lift stays
## clear. Placeholder geometry in the house palette, to swap for authored
## props.
func _dress_room() -> void:
	var crt_green := Color("8bbd79")
	# The bench along the left wall, halfway down the room.
	var bench_at := Vector3(ROOM_X.x + 0.42, 0.0, 7.4)
	_block(Vector3(0.8, 0.9, 2.2), bench_at + Vector3(0, 0.45, 0), _flat(Color("2c2a26")))
	var crt_spots := [Vector3(0, 1.14, -0.55), Vector3(0, 1.14, 0.1), Vector3(0, 1.6, -0.22)]
	for index in crt_spots.size():
		var at: Vector3 = bench_at + crt_spots[index]
		_block(Vector3(0.46, 0.44, 0.5), at, _flat(Color("9c9580")), false)
		var glass := MeshInstance3D.new()
		var glass_mesh := QuadMesh.new()
		glass_mesh.size = Vector2(0.4, 0.3)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = crt_green.darkened(0.55)
		glow.emission_enabled = true
		glow.emission = crt_green
		glow.emission_energy_multiplier = 0.75 - 0.12 * index
		glass_mesh.material = glow
		glass.mesh = glass_mesh
		# Facing into the room (+X).
		glass.rotation_degrees.y = 90.0
		glass.position = at + Vector3(0.24, 0.02, 0)
		add_child(glass)
	_block(Vector3(0.22, 0.03, 0.62), bench_at + Vector3(0.18, 0.915, 0.9), _flat(Color("3a3632")), false)
	var screens := OmniLight3D.new()
	screens.name = "CrtGlow"
	screens.light_color = crt_green
	screens.light_energy = 2.6
	screens.omni_range = 4.2
	screens.position = bench_at + Vector3(0.9, 1.3, -0.2)
	add_child(screens)
	# His notes above the bench.
	var board_at := Vector3(ROOM_X.x + 0.04, 2.05, 7.4)
	_block(Vector3(0.04, 0.8, 1.3), board_at, _flat(Color("4e3620")), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1316
	for index in 6:
		var note := _block(Vector3(0.01, 0.2 + rng.randf() * 0.1, 0.16 + rng.randf() * 0.08), board_at + Vector3(0.03, rng.randf_range(-0.25, 0.25), rng.randf_range(-0.5, 0.5)), _flat(Color("b9ab8a")), false)
		note.rotation.x = rng.randf_range(-0.12, 0.12)
	# Filing cabinets by the lift, on the right.
	for index in 2:
		var cabinet_at := Vector3(ROOM_X.y - 0.34, 0.0, ROOM_Z.y - 0.45 - 0.62 * index)
		_block(Vector3(0.6, 1.32, 0.58), cabinet_at + Vector3(0, 0.66, 0), LabSurface.material("plate"))
		for drawer in 4:
			_block(Vector3(0.02, 0.03, 0.4), cabinet_at + Vector3(-0.31, 0.2 + 0.31 * drawer, 0), _flat(Color("1a1816")), false)
	# The gurney along the right wall, and the drip beside it.
	var gurney_at := Vector3(ROOM_X.y - 0.5, 0.0, 6.2)
	_block(Vector3(0.8, 0.12, 1.9), gurney_at + Vector3(0, 0.68, 0), LabSurface.material("plate"))
	_block(Vector3(0.72, 0.1, 1.8), gurney_at + Vector3(0, 0.79, 0), _flat(Color("6f675a")), false)
	for corner in [Vector2(-0.34, -0.85), Vector2(0.34, -0.85), Vector2(-0.34, 0.85), Vector2(0.34, 0.85)]:
		_block(Vector3(0.04, 0.62, 0.04), gurney_at + Vector3(corner.x, 0.31, corner.y), LabSurface.material("grime"), false)
	var drip_at := gurney_at + Vector3(-0.55, 0.0, 1.15)
	_block(Vector3(0.03, 1.9, 0.03), drip_at + Vector3(0, 0.95, 0), LabSurface.material("plate"), false)
	var bag := _block(Vector3(0.16, 0.26, 0.05), drip_at + Vector3(0.1, 1.72, 0), _flat(Color("4a0c08"), 0.3), false)
	bag.rotation.y = 0.3
	# His blood, old: where he worked and where he lay.
	for spot in [Vector3(-1.2, 0.012, 5.6), Vector3(3.2, 0.012, 6.6), Vector3(0.9, 0.012, 8.9)]:
		var stain := _block(Vector3(0.5 + rng.randf() * 0.4, 0.004, 0.3 + rng.randf() * 0.3), spot, _flat(Color("1c0504"), 0.25), false)
		stain.rotation.y = rng.randf() * TAU


## A plain authored colour: the procedural paint grain reads as camouflage
## under the CRT light at this size.
func _flat(colour: Color, roughness := 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


func _build_lift() -> void:
	# The shaft beyond the back wall, deep enough for the ride.
	var shaft_height := ROOM_HEIGHT - SHAFT_BOTTOM
	var shaft_mid := (ROOM_HEIGHT + SHAFT_BOTTOM) * 0.5
	var concrete := LabSurface.material("wall")
	_block(Vector3(0.2, shaft_height, CAR_HALF.y * 2.0 + 0.5), Vector3(CAR_AT.x - CAR_HALF.x - 0.15, shaft_mid, CAR_AT.z), concrete)
	_block(Vector3(0.2, shaft_height, CAR_HALF.y * 2.0 + 0.5), Vector3(CAR_AT.x + CAR_HALF.x + 0.15, shaft_mid, CAR_AT.z), concrete)
	_block(Vector3(CAR_HALF.x * 2.0 + 0.5, shaft_height, 0.2), Vector3(CAR_AT.x, shaft_mid, CAR_AT.z + CAR_HALF.y + 0.15), concrete)
	_block(Vector3(CAR_HALF.x * 2.0 + 0.5, 0.3, CAR_HALF.y * 2.0 + 0.5), Vector3(CAR_AT.x, SHAFT_BOTTOM, CAR_AT.z), concrete)

	# Landing doors in the room's back wall.
	for side in [-1.0, 1.0]:
		var leaf := _moving_panel(self, Vector3(CAR_OPENING_HALF - 0.015, 2.3, 0.06), Vector3(CAR_AT.x + side * CAR_OPENING_HALF * 0.5, 1.15, ROOM_Z.y - 0.02), LabSurface.material("plate"))
		leaf.name = "LandingDoor_%s" % ("L" if side < 0.0 else "R")
		landing_doors.append(leaf)
	var call_light := OmniLight3D.new()
	call_light.light_color = Color("ff7a2a")
	call_light.light_energy = 1.2
	call_light.omni_range = 1.8
	call_light.position = Vector3(CAR_AT.x + CAR_OPENING_HALF + 0.35, 1.3, ROOM_Z.y - 0.3)
	add_child(call_light)
	_block(Vector3(0.12, 0.22, 0.04), call_light.position + Vector3(0, 0, 0.12), WorldLook.surface(Color("ff7a2a"), "paint", 1210), false)

	# The car. Its own floor, walls, roof and doors all move together.
	car = Node3D.new()
	car.name = "LiftCar"
	car.position = CAR_AT
	add_child(car)
	var plate := LabSurface.material("plate")
	var grime := LabSurface.material("grime")
	_block(Vector3(CAR_HALF.x * 2.0, 0.2, CAR_HALF.y * 2.0), Vector3(0, -0.1, 0), grime, true, car)
	_block(Vector3(CAR_HALF.x * 2.0, 0.12, CAR_HALF.y * 2.0), Vector3(0, CAR_HEIGHT + 0.06, 0), plate, true, car)
	_block(Vector3(0.08, CAR_HEIGHT, CAR_HALF.y * 2.0), Vector3(-CAR_HALF.x + 0.04, CAR_HEIGHT * 0.5, 0), plate, true, car)
	_block(Vector3(0.08, CAR_HEIGHT, CAR_HALF.y * 2.0), Vector3(CAR_HALF.x - 0.04, CAR_HEIGHT * 0.5, 0), plate, true, car)
	_block(Vector3(CAR_HALF.x * 2.0, CAR_HEIGHT, 0.08), Vector3(0, CAR_HEIGHT * 0.5, CAR_HALF.y - 0.04), plate, true, car)
	var stub := CAR_HALF.x - CAR_OPENING_HALF
	for side in [-1.0, 1.0]:
		_block(Vector3(stub, CAR_HEIGHT, 0.08), Vector3(side * (CAR_OPENING_HALF + stub * 0.5), CAR_HEIGHT * 0.5, -CAR_HALF.y + 0.04), plate, true, car)
		var leaf := _moving_panel(car, Vector3(CAR_OPENING_HALF - 0.015, 2.3, 0.05), Vector3(side * CAR_OPENING_HALF * 0.5, 1.15, -CAR_HALF.y + 0.1), grime)
		leaf.name = "CarDoor_%s" % ("L" if side < 0.0 else "R")
		car_doors.append(leaf)
	_block(Vector3(CAR_OPENING_HALF * 2.0, CAR_HEIGHT - 2.3, 0.08), Vector3(0, 2.3 + (CAR_HEIGHT - 2.3) * 0.5, -CAR_HALF.y + 0.04), plate, true, car)
	# A handrail and the button panel, so it reads as a lift from inside.
	_block(Vector3(0.04, 0.04, CAR_HALF.y * 1.6), Vector3(CAR_HALF.x - 0.12, 0.95, 0), grime, false, car)
	_block(Vector3(0.04, 0.04, CAR_HALF.y * 1.6), Vector3(-CAR_HALF.x + 0.12, 0.95, 0), grime, false, car)
	_block(Vector3(0.03, 0.5, 0.22), Vector3(CAR_HALF.x - 0.1, 1.3, -CAR_HALF.y + 0.35), plate, false, car)
	for button in 4:
		_block(Vector3(0.02, 0.05, 0.05), Vector3(CAR_HALF.x - 0.12, 1.45 - float(button) * 0.1, -CAR_HALF.y + 0.35), WorldLook.surface(Color("ffb35a") if button == 3 else Color("5a5650"), "paint", 1220 + button), false, car)
	car_indicator = Label3D.new()
	car_indicator.text = "0C"
	car_indicator.font_size = 64
	car_indicator.outline_size = 8
	car_indicator.pixel_size = 0.004
	car_indicator.modulate = Color("ffb35a")
	# Inside, above the doors, facing back into the car (+Z).
	car_indicator.position = Vector3(0, 2.45, -CAR_HALF.y + 0.13)
	car.add_child(car_indicator)
	var car_light := OmniLight3D.new()
	car_light.light_color = Color("ffd9a8")
	car_light.light_energy = 2.4
	car_light.omni_range = 3.6
	car_light.position = Vector3(0, CAR_HEIGHT - 0.25, 0.1)
	car.add_child(car_light)


func _wall_piece(span_x: Vector2, span_y: Vector2) -> void:
	var size := Vector3(span_x.y - span_x.x, span_y.y - span_y.x, WALL_DEPTH)
	var at := Vector3((span_x.x + span_x.y) * 0.5, (span_y.x + span_y.y) * 0.5, WALL_Z)
	# The same surface the single slab had: `LabSurface.for_slab` reads a
	# standing box as wall whatever its size.
	_block(size, at, LabSurface.material("wall"))


func _block(size: Vector3, at: Vector3, material: Material, solid := true, parent: Node3D = null) -> MeshInstance3D:
	var host: Node3D = self if parent == null else parent
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	if not solid:
		mesh_instance.position = at
		host.add_child(mesh_instance)
		return mesh_instance
	var body := StaticBody3D.new()
	body.position = at
	host.add_child(body)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return mesh_instance


func _moving_panel(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> Node3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.position = at
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body
