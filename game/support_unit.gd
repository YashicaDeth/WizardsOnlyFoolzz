extends Node3D
const JUMP_CLIMB := preload("res://systems/jump_climb.gd")
const HIDDEN_CACHE := preload("res://systems/hidden_cache.gd")
## The closet behind the secret door: against the right wall, clear of the
## cells (-18, -58), the reinforcement doors (-47, -88) and the gate.
const CLOSET_Z := -36.0
const LOOK := preload("res://systems/look_settings.gd")

## THE MENTAL AND PHYSICAL SUPPORT UNIT, after the elevator down (Greg, 24
## September): "massive hallways that you can break the bingyangas [out] and
## are trying to not alert the guards cause the cameras then film and track
## you, a alarm and alertness for the characters system ... and then more
## guards begin piling out ... and they try to kill you".
##
## His question-box answers, all here:
##   - cameras can be broken (loud, stops tracking), sneaked past (a visible
##     sweeping cone) or hacked later (`SecurityCamera.hack`, a hook that
##     refuses for now);
##   - Hollis's biometric gate is the last checkpoint, at the end of the
##     hallways (`FacilityGuardPost`, the same post, reused whole).
##
## The pieces are components in `systems/`: `SecurityCamera`, `AlarmDirector`
## (alertness, the brain-chip flash, the block tracking, the X-ray flash and
## the reinforcements), `SupportGuard`, `BingyangCell` (a `BreakableDoor` on
## each cell) and `Bingyanger`. This scene lays them out and is the player.
##
## Walking -z: the lift car, hallway A, the reinforcement doors, hallway B,
## Hollis's gate, and the way down to the vehicle bay.

const VAT_REBIRTH := preload("res://systems/vat_rebirth.gd")

const LOCATION := "support_unit"
const TOOL_LABEL := "BREACH TOOL"
const HALF_WIDTH := 7.25
const HEIGHT := 9.0
const START_Z := 11.0
const END_Z := -108.0
const ENTRY := Vector3(0, 1.0, 6.0)
const GATE_Z := -94.0
const EXIT_AT := Vector3(0, 0.0, -102.0)
const EXIT_REACH := 3.0
const NEXT_SCENE := "res://doctor_vehicle_bay.tscn"
const WALK_SPEED := 3.4
const SWING_COOLDOWN := 0.65
const SWING_REACH := 2.6
const CAMERA_REACH := 2.8
const RAM_DAMAGE := 55.0
const FIST_DAMAGE := 14.0
const REMAINS_REACH := 2.4

## [id, x side (-1 left wall / 1 right wall), z]
const CELLS := [
	["cell_a1", -1.0, -8.0], ["cell_a2", 1.0, -18.0], ["cell_a3", -1.0, -30.0],
	["cell_b1", 1.0, -58.0], ["cell_b2", -1.0, -68.0], ["cell_b3", 1.0, -78.0],
]
## Cover down the middle of the hall: square columns, floor to ceiling.
const PILLARS := [
	Vector3(-2.2, 0, -2.0), Vector3(2.2, 0, -2.0), Vector3(-2.2, 0, -13.0), Vector3(2.2, 0, -13.0),
	Vector3(-2.2, 0, -24.0), Vector3(2.2, 0, -24.0), Vector3(-2.2, 0, -36.0), Vector3(2.2, 0, -36.0),
	Vector3(-2.2, 0, -52.0), Vector3(2.2, 0, -52.0), Vector3(-2.2, 0, -63.0), Vector3(2.2, 0, -63.0),
	Vector3(-2.2, 0, -73.0), Vector3(2.2, 0, -73.0), Vector3(-2.2, 0, -84.0), Vector3(2.2, 0, -84.0),
]
## Cameras on the pillars' near faces, looking back up the hall at whoever
## comes down it: [id, pillar index, sweep phase].
const CAMERAS := [["support_camera_1", 4, 0.0], ["support_camera_2", 9, 2.1], ["support_camera_3", 14, 4.0]]
## Where reinforcements come out: doors in the side walls.
const DOORS := [Vector3(-HALF_WIDTH, 0, -44.0), Vector3(HALF_WIDTH, 0, -47.0), Vector3(HALF_WIDTH, 0, -88.0)]
const PILLAR_SIZE := 0.9
const CAMERA_HEIGHT := 3.0

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.05
var blood := 100.0
var died := false
var rebirth_request: Dictionary = {}
var holding_ram := false
## Which heavy thing is in hand, best first.
var held_tool := ""
const HEAVY_TOOLS := ["BREACH TOOL", "FIRE AXE", "BROKEN MEDICAL RESTRAINT"]
var tool_visual: Node3D
var director: AlarmDirector
var cameras: Array[SecurityCamera] = []
var guards: Array = []
## K wizard eyes / J depth scan.
var sight: Node
## Stashes and secret doors (HiddenCache records).
var caches: Array = []
var cells: Array[BingyangCell] = []
var bingyangers: Array = []
var guard_post: FacilityGuardPost
var block_tracker: BlockTracker
var xray_flash: AlarmXrayFlash
var alarm_lamps: Array[OmniLight3D] = []
var door_leaves: Array[Node3D] = []
var klaxon: AudioStreamPlayer
var gate_method := ""
var gate_passed := false
var exit_requested := false
var exit_message := ""
var swing_cooldown := 0.0
var post_message := ""
var post_message_timer := 0.0
var remains_nodes: Dictionary = {}
var _reinforcement_serial := 0
var _clock := 0.0

var objective: Label
var status: Label
var prompt: Label
var alert_meter: Label


func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("lower_works")
	add_child(environment)
	director = AlarmDirector.new()
	director.name = "AlarmDirector"
	add_child(director)
	_build_shell()
	_build_lift()
	_build_pillars()
	_build_cells()
	_build_reinforcement_doors()
	_build_gate()
	_build_exit()
	_build_player()
	_build_cameras()
	_build_guards()
	_build_remains()
	_build_hud()
	_build_sight()
	_build_klaxon()
	director.doors = DOORS.duplicate()
	director.spawner = _spawn_reinforcement
	director.xray_flash = xray_flash
	director.alarm_raised.connect(_on_alarm)
	for bingyanger in bingyangers:
		bingyanger.bind(player, director, guards)
	# Harmless until another lane adds the district to the route graph.
	FacilityRoutes.traverse("support_unit")
	WorldHistory.record_event("support_unit_entered", {"location": LOCATION})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Building.

func _slab(size: Vector3, at: Vector3, role := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = LabSurface.material(role) if not role.is_empty() else LabSurface.for_slab(size, at)
	visual.mesh = mesh
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body


func _decor(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = at
	add_child(mesh_instance)
	return mesh_instance


func _lamp(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	add_child(lamp)
	return lamp


## One long, tall hall of tiled floor and poured concrete, ribbed with beams.
func _build_shell() -> void:
	var length := START_Z - END_Z
	var mid := (START_Z + END_Z) * 0.5
	# In 7-metre sections, not one 119-metre slab: a renderer lights each mesh
	# with only its nearest few lamps (Compatibility caps it at eight), and one
	# slab under forty lamps rendered black on the first capture.
	var section := 7.0
	var z0 := START_Z
	while z0 > END_Z + 0.01:
		var span := minf(section, z0 - END_Z)
		var centre := z0 - span * 0.5
		_slab(Vector3(HALF_WIDTH * 2.0, 0.4, span), Vector3(0, -0.2, centre), "floor")
		_slab(Vector3(HALF_WIDTH * 2.0, 0.4, span), Vector3(0, HEIGHT + 0.2, centre), "ceiling")
		for side in [-1.0, 1.0]:
			_slab(Vector3(0.5, HEIGHT, span), Vector3(side * (HALF_WIDTH + 0.25), HEIGHT * 0.5, centre), "wall")
		z0 -= span
	_slab(Vector3(HALF_WIDTH * 2.0, HEIGHT, 0.5), Vector3(0, HEIGHT * 0.5, END_Z - 0.25), "wall")
	var plate := LabSurface.material("plate")
	var rust := LabSurface.material("rust")
	# A stripe of plate along both walls at hand height: the ward's rail.
	for side in [-1.0, 1.0]:
		var rail := _decor(Vector3(0.06, 0.18, length), Vector3(side * (HALF_WIDTH - 0.03), 1.05, mid), plate)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bay := 0
	var z := START_Z - 4.0
	while z > END_Z + 2.0:
		_decor(Vector3(HALF_WIDTH * 2.0, 0.5, 0.45), Vector3(0, HEIGHT - 0.25, z), rust)
		# A strip lamp under every beam: ward light, sickly and even.
		var tube := _decor(Vector3(0.18, 0.06, 2.4), Vector3(0, HEIGHT - 0.55, z - 2.0), WorldLook.emissive(Color("cfe0c0"), 2.2))
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lamp(Vector3(0, HEIGHT - 1.2, z - 2.0), Color("c9dcb8"), 5.5, 14.0)
		# The alarm lamps, dark until the alarm: one every other bay,
		# alternating sides. Dark lamps are hidden, not merely at zero, so
		# they do not spend the renderer's light budget.
		if bay % 2 == 0:
			var side := -1.0 if bay % 4 == 0 else 1.0
			var red := _lamp(Vector3(side * (HALF_WIDTH - 0.5), 4.6, z), Color("ff2a18"), 0.0, 12.0)
			red.visible = false
			alarm_lamps.append(red)
			_decor(Vector3(0.18, 0.3, 0.18), Vector3(side * (HALF_WIDTH - 0.1), 4.6, z), WorldLook.emissive(Color("5a0a06"), 0.6))
		bay += 1
		z -= 8.0
	# Signage stencilled high on the wall.
	for at in [Vector3(-HALF_WIDTH + 0.02, 6.0, -4.0), Vector3(HALF_WIDTH - 0.02, 6.0, -60.0)]:
		var sign := Label3D.new()
		sign.text = "MENTAL AND PHYSICAL\nSUPPORT UNIT"
		sign.font_size = 120
		sign.outline_size = 0
		sign.modulate = Color(0.75, 0.7, 0.6, 0.55)
		sign.position = at
		sign.rotation.y = PI * 0.5 if at.x < 0.0 else -PI * 0.5
		add_child(sign)


## The car the player came down in, doors open behind them.
func _build_lift() -> void:
	var grime := LabSurface.material("grime")
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.3, 3.4, 3.2), Vector3(side * 1.8, 1.7, 9.3), "grime")
		_slab(Vector3(2.5, 3.4, 0.25), Vector3(side * 3.2, 1.7, 7.6), "grime")
	_slab(Vector3(3.9, 0.3, 3.2), Vector3(0, 3.55, 9.3), "grime")
	_slab(Vector3(3.9, 3.4, 0.3), Vector3(0, 1.7, 10.8), "grime")
	for side in [-1.0, 1.0]:
		_decor(Vector3(0.9, 3.2, 0.08), Vector3(side * 2.3, 1.6, 7.9), grime)
	_lamp(Vector3(0, 3.0, 9.3), Color("e0b070"), 1.6, 4.0)
	var sign := Label3D.new()
	sign.text = "LIFT 0C-S // SUPPORT UNIT"
	sign.font_size = 34
	sign.outline_size = 6
	sign.modulate = Color("d8b184")
	sign.outline_modulate = Color("120707")
	sign.position = Vector3(0, 3.9, 7.4)
	add_child(sign)


func _build_pillars() -> void:
	for at in PILLARS:
		_slab(Vector3(PILLAR_SIZE, HEIGHT, PILLAR_SIZE), Vector3(at.x, HEIGHT * 0.5, at.z), "wall")


func _build_cells() -> void:
	for index in CELLS.size():
		var spec: Array = CELLS[index]
		var cell := BingyangCell.new()
		cell.name = str(spec[0])
		var side := float(spec[1])
		cell.position = Vector3(side * (HALF_WIDTH - BingyangCell.DEPTH - 0.15), 0, float(spec[2]))
		# The cell's +z is its door's face; turn it to look into the hall.
		cell.rotation.y = -side * PI * 0.5
		add_child(cell)
		cell.build(str(spec[0]), 4100 + index * 37)
		cell.noise.connect(_on_noise)
		cell.freed.connect(_on_freed)
		cells.append(cell)
		bingyangers.append(cell.occupant)
		cell.occupant.hints = _hints()
		cell.occupant.struck_player.connect(_on_bingyanger_struck)
		cell.occupant.took_item.connect(_on_item_taken)
		cell.occupant.gave_item.connect(_on_item_given)


## True things a friendly bingyanger may tell you, mixed with its prophecy.
func _hints() -> Array[String]:
	return [
		"THE EYES ON THE PILLARS LOOK BACK THE WAY YOU CAME. WALK BEHIND THEM, NOT IN FRONT.",
		"THE MAN AT THE LAST DOOR IS HOLLIS. THE DOOR WANTS HIS HAND, NOT HIS PERMISSION.",
		"THE BIG DOORS IN THE WALLS ARE WHERE THEY KEEP THE SPARE ONES. DON'T MAKE THEM OPEN.",
		"COUNT TO FOUR WHEN THE EYE TURNS. FOUR. NOT FIVE. FIVE IS FOR THE DEAD.",
	]


func _build_reinforcement_doors() -> void:
	for at in DOORS:
		var side := signf(at.x)
		var frame := LabSurface.material("rust")
		var face_x: float = at.x - side * 0.06
		_decor(Vector3(0.12, 3.4, 0.25), Vector3(face_x, 1.7, at.z - 1.45), frame)
		_decor(Vector3(0.12, 3.4, 0.25), Vector3(face_x, 1.7, at.z + 1.45), frame)
		_decor(Vector3(0.12, 0.3, 3.15), Vector3(face_x, 3.45, at.z), frame)
		var leaf := _decor(Vector3(0.1, 3.2, 2.7), Vector3(at.x - side * 0.02, 1.6, at.z), WorldLook.surface(Color("3b2a22"), "metal", 530))
		door_leaves.append(leaf)
		var stripe := _decor(Vector3(0.02, 0.2, 2.6), Vector3(at.x - side * 0.08, 2.9, at.z), WorldLook.emissive(Color("7a1a0c"), 0.8))
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sign := Label3D.new()
		sign.text = "SECURITY // STAFF ONLY"
		sign.font_size = 28
		sign.modulate = Color("c9a488")
		sign.position = Vector3(at.x - side * 0.1, 3.9, at.z)
		sign.rotation.y = -side * PI * 0.5
		add_child(sign)


## Hollis's post, whole, as the last checkpoint (Greg, 24 September).
func _build_gate() -> void:
	guard_post = FacilityGuardPost.new()
	guard_post.name = "HollisGate"
	guard_post.position = Vector3(0, 0, GATE_Z)
	add_child(guard_post)
	guard_post.build()
	guard_post.shot.connect(_on_hollis_shot)
	guard_post.door_opened.connect(_on_gate_opened)
	guard_post.struck.connect(_on_hollis_struck)
	# The post's wall is built to the arcade's height; the hall is taller.
	_slab(Vector3(HALF_WIDTH * 2.0, HEIGHT - FacilityGuardPost.WALL_HEIGHT, 0.5), Vector3(0, FacilityGuardPost.WALL_HEIGHT + (HEIGHT - FacilityGuardPost.WALL_HEIGHT) * 0.5, GATE_Z), "wall")
	if guard_post.door_open:
		gate_method = "restored"


## Beyond the gate: the way down to the doctor's vehicle bay.
func _build_exit() -> void:
	var plate := LabSurface.material("plate")
	_decor(Vector3(4.2, 3.6, 0.12), Vector3(EXIT_AT.x, 1.8, END_Z + 0.1), plate)
	_decor(Vector3(3.6, 0.12, 0.3), Vector3(EXIT_AT.x, 3.7, END_Z + 0.2), WorldLook.emissive(Color("e0a060"), 1.2))
	_lamp(Vector3(0, 4.0, END_Z + 3.0), Color("e8c890"), 3.0, 9.0)
	var sign := Label3D.new()
	sign.text = "VEHICLE BAY // DOWN"
	sign.font_size = 40
	sign.outline_size = 8
	sign.modulate = Color("e8c890")
	sign.outline_modulate = Color("120707")
	sign.position = Vector3(0, 4.3, END_Z + 0.4)
	add_child(sign)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = ENTRY
	add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collider.shape = capsule
	player.add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 0.77
	camera.fov = 88.0
	player.add_child(camera)
	LabSurface.attach_body_cam(camera)
	_refresh_tool()


func _refresh_tool() -> void:
	# The doctor's route never passes the Service Arcade, where the breach tool
	# comes from: you arrive with the restraint off your own vat and perhaps his
	# fire axe. Either is something to meet Hollis with; without this the
	# third route ended at his gate ("YOU HAVE NOTHING TO MEET HIM WITH").
	held_tool = ""
	for label in HEAVY_TOOLS:
		if VAT_REBIRTH.carries(label):
			held_tool = label
			break
	holding_ram = not held_tool.is_empty()
	if holding_ram and tool_visual == null:
		tool_visual = LabSurface.breach_tool()
		add_child(tool_visual)
		LabSurface.hold_in_view(camera, tool_visual)
	elif not holding_ram and tool_visual != null:
		tool_visual.queue_free()
		tool_visual = null


func _build_cameras() -> void:
	for spec in CAMERAS:
		var pillar: Vector3 = PILLARS[int(spec[1])]
		var lens := SecurityCamera.new()
		lens.name = str(spec[0])
		# On the pillar's near face, looking back up the hall (+z).
		lens.position = Vector3(pillar.x, CAMERA_HEIGHT, pillar.z + PILLAR_SIZE * 0.5)
		lens.rotation.y = PI
		# Turned a little in toward the middle of the hall.
		lens.rotation.y -= 0.25 * signf(pillar.x)
		add_child(lens)
		lens.build(str(spec[0]), float(spec[2]))
		lens.ignore(player.get_rid())
		lens.filmed.connect(_on_filmed)
		lens.broke.connect(_on_camera_broke)
		cameras.append(lens)


func _build_guards() -> void:
	var round_a: Array[Vector3] = [Vector3(-0.4, 0, -6.0), Vector3(-0.4, 0, -42.0)]
	var round_b: Array[Vector3] = [Vector3(0.4, 0, -86.0), Vector3(0.4, 0, -54.0)]
	for spec in [["support_guard_a", round_a], ["support_guard_b", round_b]]:
		var guard := SupportGuard.new()
		guard.name = str(spec[0])
		add_child(guard)
		var route: Array[Vector3] = spec[1]
		guard.build(str(spec[0]), route[1], route, director)
		_wire_guard(guard)


func _wire_guard(guard: SupportGuard) -> void:
	guards.append(guard)
	director.register(guard)
	guard.shot.connect(_on_guard_shot.bind(guard))


## The director's spawner: one guard out of a wall door, already hunting.
func _spawn_reinforcement(door_index: int) -> Node:
	var at: Vector3 = DOORS[door_index]
	_reinforcement_serial += 1
	var guard := SupportGuard.new()
	var id := "support_reinforcement_%d" % _reinforcement_serial
	guard.name = id
	add_child(guard)
	var round: Array[Vector3] = []
	guard.build(id, Vector3(at.x - signf(at.x) * 1.2, 0, at.z + float(_reinforcement_serial % 2) * 0.8), round, director, true)
	guard.alerted = true
	guard.certainty = 1.0
	_wire_guard(guard)
	# The door slides up to let them out.
	var leaf := door_leaves[door_index]
	if leaf.position.y < 4.0:
		var lift := create_tween()
		lift.tween_property(leaf, "position:y", 4.9, 0.6)
	return guard


func _build_remains() -> void:
	for remains in VAT_REBIRTH.remains_at(LOCATION):
		var body := BaselineHuman.new()
		body.name = str(remains.id)
		add_child(body)
		body.build(str(remains.id), {"flesh": Color("6b5842"), "variation": int(remains.get("body_number", 1))})
		body.position = VAT_REBIRTH.remains_position(remains)
		body.anatomy.dead = true
		body.rotation.x = -PI * 0.46
		var tag := Label3D.new()
		tag.text = "YOUR OLD BODY"
		tag.font_size = 30
		tag.outline_size = 8
		tag.modulate = Color("d9c3a4")
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = body.position + Vector3(0, 0.9, 0)
		add_child(tag)
		remains_nodes[str(remains.id)] = [body, tag]


func _build_sight() -> void:
	sight = preload("res://systems/signal_sight.gd").new()
	sight.name = "SignalSight"
	add_child(sight)
	sight.call("setup", camera)
	# By the Support Unit the chip has long been yours.
	sight.set("enabled", true)
	sight.set("bodies", func() -> Array:
		var out: Array = []
		for guard in guards:
			if is_instance_valid(guard):
				out.append((guard as Node3D).global_position)
		for occupant in bingyangers:
			if occupant != null and is_instance_valid(occupant):
				out.append((occupant as Node3D).global_position)
		return out)
	var dead: Array = []
	for remains_id in remains_nodes:
		dead.append((remains_nodes[remains_id][0] as Node3D).global_position)
	sight.set("spirits", dead)
	# Wires and power: each camera's feed runs down the nearest wall to a
	# junction at hand height. Seen in the modes, cut it with E and the camera
	# dies quietly, where smashing it is loud.
	var wires: Array = []
	for lens in cameras:
		var eye: Vector3 = lens.eye()
		var wall_x := signf(eye.x if absf(eye.x) > 0.01 else 1.0) * (HALF_WIDTH - 0.15)
		wires.append({"id": "%s_feed" % lens.camera_id, "points": [Vector3(wall_x, 1.3, eye.z), Vector3(wall_x, eye.y, eye.z), eye],
			"on_cut": func() -> void: lens.smash("wire_cut")})
	sight.set("wires", wires)
	_build_hidden()


## Greg, 26 September: stashes and secret doors, found in K or J, opened with
## E. A hatch in the left wall; and on the right, a bulkhead that is really a
## closet door, with a second stash inside.
func _build_hidden() -> void:
	caches.append(HIDDEN_CACHE.place_stash(self, sight, "support_unit_stash", Vector3(-HALF_WIDTH, 1.2, -40.0), Vector3.RIGHT))
	var front_x := HALF_WIDTH - 2.15
	var half := 1.5
	var door_half := 0.6
	var tall := 2.8
	# Front wall either side of the door, a lintel over it, two sides, a roof.
	for side in [-1.0, 1.0]:
		var piece := half - door_half
		_slab(Vector3(0.3, tall, piece), Vector3(front_x, tall * 0.5, CLOSET_Z + side * (door_half + piece * 0.5)), "wall")
		_slab(Vector3(2.15, tall, 0.3), Vector3(front_x + 1.075, tall * 0.5, CLOSET_Z + side * (half + 0.15)), "wall")
	_slab(Vector3(0.3, tall - 2.1, door_half * 2.0), Vector3(front_x, 2.1 + (tall - 2.1) * 0.5, CLOSET_Z), "wall")
	_slab(Vector3(2.15, 0.2, half * 2.0 + 0.6), Vector3(front_x + 1.075, tall + 0.1, CLOSET_Z), "ceiling")
	caches.append(HIDDEN_CACHE.place_door(self, sight, "support_unit_closet", Vector3(front_x, 0.0, CLOSET_Z), Vector3.LEFT))
	caches.append(HIDDEN_CACHE.place_stash(self, sight, "support_unit_closet_stash", Vector3(HALF_WIDTH, 1.1, CLOSET_Z), Vector3.LEFT))
	var bulb := OmniLight3D.new()
	bulb.position = Vector3(front_x + 1.2, 2.3, CLOSET_Z)
	bulb.light_color = Color("c9b98f")
	bulb.light_energy = 0.7
	bulb.omni_range = 2.4
	add_child(bulb)
	sight.connect("hidden_seen", func(id: String) -> void:
		if HIDDEN_CACHE.mark_found(caches, id):
			_flash_message("SOMETHING HIDDEN THERE // THE MODES SEE THE SEAM"))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 10
	add_child(layer)
	block_tracker = BlockTracker.new()
	block_tracker.name = "BlockTracker"
	layer.add_child(block_tracker)
	block_tracker.camera = camera
	xray_flash = AlarmXrayFlash.new()
	xray_flash.name = "AlarmXrayFlash"
	layer.add_child(xray_flash)
	xray_flash.camera = camera
	objective = Label.new()
	objective.position = Vector2(34, 34)
	objective.add_theme_font_size_override("font_size", 18)
	objective.add_theme_color_override("font_color", Color("e4a058"))
	layer.add_child(objective)
	status = Label.new()
	status.position = Vector2(34, 62)
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("a8c58d"))
	layer.add_child(status)
	alert_meter = Label.new()
	alert_meter.position = Vector2(34, 84)
	alert_meter.add_theme_font_size_override("font_size", 15)
	alert_meter.add_theme_color_override("font_color", Color("d8d0c0"))
	layer.add_child(alert_meter)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -55
	prompt.offset_left = -360
	prompt.offset_right = 360
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.add_theme_color_override("font_color", Color("dd9851"))
	layer.add_child(prompt)


## A two-tone klaxon, synthesised here (not heard: this was built headless).
func _build_klaxon() -> void:
	var rate := 22050
	var data := PackedByteArray()
	data.resize(rate * 2)
	for index in rate:
		var t := float(index) / float(rate)
		var pitch_hz := 620.0 if t < 0.5 else 470.0
		var wave := signf(sin(TAU * pitch_hz * t)) * 0.5 + sin(TAU * pitch_hz * 2.0 * t) * 0.2
		var value := int(clampf(wave * 0.35, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = rate
	klaxon = AudioStreamPlayer.new()
	klaxon.stream = stream
	klaxon.volume_db = -14.0
	add_child(klaxon)


# --- Events.

func _on_filmed(lens: SecurityCamera, at: Vector3) -> void:
	director.trip("camera:" + lens.camera_id, at)


func _on_camera_broke(lens: SecurityCamera, _method: String) -> void:
	# Loud: whoever is near comes to look.
	_on_noise(lens.global_position, 0.9)
	_flash_message("CAMERA DOWN // THAT WAS LOUD")


## A blow, a scream, a door: guards in earshot come and look, and the facility
## gets a little more awake.
func _on_noise(at: Vector3, loudness: float) -> void:
	var heard := false
	for guard in guards:
		if guard.is_down():
			continue
		if (guard.global_position - at).length() <= loudness * 16.0:
			guard.hear(at)
			heard = true
	if heard:
		director.raise(loudness * 0.4, "noise", at)


func _on_alarm(_source: String, _at: Vector3) -> void:
	if klaxon != null and OS.get_environment("ATG_TEST_MODE") != "1":
		klaxon.play()
	_flash_message("ALARM // THEY HAVE YOU ON CAMERA")


func _on_freed(bingyanger: Bingyanger) -> void:
	_flash_message("THE CELL IS OPEN // %s" % ("IT LOOKS AT YOU LIKE A FRIEND" if bingyanger.attitude == "friendly" else "IT LOOKS AT YOU LIKE FOOD"))


func _on_guard_shot(target: Node3D, damage: float, guard: SupportGuard) -> void:
	if target == player:
		_hurt(damage, "shot by Support Unit security", guard.subject_id)
	elif target is Bingyanger:
		(target as Bingyanger).take_hit(damage * 2.5, target.global_position - guard.global_position, "ballistic", guard.subject_id)


func _on_bingyanger_struck(damage: float) -> void:
	_hurt(damage, "torn at by a bingyanger", "bingyanger")


func _on_item_given(label: String) -> void:
	_flash_message("GIVEN // %s" % label)


func _on_hollis_shot(damage: float) -> void:
	_hurt(damage, "shot by Hollis at the last checkpoint", FacilityGuardPost.GUARD_ID)


func _on_gate_opened(method: String) -> void:
	gate_method = method


func _on_hollis_struck(at: Vector3, zone: String, damage: float, kind: String) -> void:
	if block_tracker != null:
		block_tracker.report_hit(at, zone, damage, kind)


func _on_item_taken(label: String) -> void:
	_flash_message("IT TOOK %s AND RAN" % label)
	_refresh_tool()


func _hurt(damage: float, cause: String, killed_by: String) -> void:
	if died:
		return
	blood = maxf(0.0, blood - damage)
	if blood <= 0.0:
		_die(cause, killed_by)


## Death is rebirth in the claimant's vat; what you carried stays here.
func _die(cause: String, killed_by: String) -> void:
	died = true
	var at := player.global_position
	at.y = 0.0
	rebirth_request = VAT_REBIRTH.die(LOCATION, cause, killed_by, at)
	if killed_by == FacilityGuardPost.GUARD_ID:
		guard_post.player_killed()
	_refresh_tool()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Interstitial.travel(str(rebirth_request.scene), "you died // %s grows you back" % str(rebirth_request.vat.label).to_lower())


# --- Input and the frame.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked: bool = event.pressed
		if clicked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			swing()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= LOOK.dx(event.relative) * 0.0026
		pitch = clampf(pitch - LOOK.dy(event.relative) * 0.0024, -1.15, 0.95)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		interact()
	# Greg, 26 September: jump and climb everywhere.
	if not died and JUMP_CLIMB.is_jump_key(event):
		JUMP_CLIMB.press(player, yaw, 1.0, "support_unit_climbed")


func eye() -> Vector3:
	return camera.global_position


func look() -> Vector3:
	return -camera.global_transform.basis.z


func _in_front(at: Vector3, reach: float, half_angle: float) -> bool:
	var to := at - eye()
	if to.length() > reach:
		return false
	var flat := Vector3(to.x, 0, to.z)
	var ahead := Vector3(look().x, 0, look().z)
	return flat.length() < 0.3 or flat.angle_to(ahead) <= half_angle


## LMB: one blow at whatever is in front, nearest first. Returns what it hit.
func swing() -> String:
	if died or swing_cooldown > 0.0:
		return ""
	swing_cooldown = SWING_COOLDOWN
	var damage := RAM_DAMAGE if holding_ram else FIST_DAMAGE
	var method := "breach_tool" if holding_ram else "fists"
	if tool_visual != null:
		var kick := create_tween()
		kick.tween_property(tool_visual, "position:z", tool_visual.position.z - 0.22, 0.05)
		kick.tween_property(tool_visual, "position:z", tool_visual.position.z, 0.25)
	for lens in cameras:
		if not lens.broken and _in_front(lens.eye(), CAMERA_REACH, deg_to_rad(60.0)):
			lens.smash(method)
			return "camera"
	if holding_ram and guard_post.strike(player.global_position):
		return "hollis"
	var forward := Vector3(look().x, 0, look().z).normalized()
	for guard in guards:
		if guard.is_down():
			continue
		var torso: Vector3 = guard.global_position + Vector3(0, 1.1, 0)
		if _in_front(torso, SWING_REACH, deg_to_rad(55.0)):
			var result: Dictionary = guard.take_hit(damage, forward, "blunt", "player")
			block_tracker.report_hit(torso, "torso", float(result.get("damage", damage)), "blunt")
			_on_noise(torso, 0.5)
			return "guard"
	for bingyanger in bingyangers:
		if bingyanger.state != "loose" or bingyanger.is_down():
			continue
		var chest: Vector3 = bingyanger.global_position + Vector3(0, 1.0, 0)
		if _in_front(chest, SWING_REACH, deg_to_rad(55.0)):
			var result: Dictionary = bingyanger.take_hit(damage, forward, "blunt", "player")
			block_tracker.report_hit(chest, "torso", float(result.get("damage", damage)), "blunt")
			return "bingyanger"
	var query := PhysicsRayQueryParameters3D.create(eye(), eye() + look() * SWING_REACH)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var door := BreakableDoor.door_of(hit.get("collider")) if not hit.is_empty() else null
	if door != null:
		door.hit("axe" if holding_ram else "body", hit.position, look())
		return "door"
	return ""


## E: one act, in the order the situation asks for it.
func interact() -> String:
	if died:
		return ""
	var remains_id := _nearest_remains()
	if not remains_id.is_empty():
		var result := VAT_REBIRTH.recover(remains_id)
		if bool(result.get("ok", false)):
			(remains_nodes[remains_id][1] as Label3D).text = "STRIPPED"
			_refresh_tool()
			_flash_message("TAKEN BACK OFF YOUR OLD BODY // %d THINGS" % int(result.get("items", 0)))
			return "remains"
	var said := guard_post.interact(player.global_position, holding_ram)
	if not said.is_empty():
		_flash_message(said)
		return "hollis"
	for bingyanger in bingyangers:
		if bingyanger.is_down() and not bingyanger.holding.is_empty() and _flat_distance(bingyanger.global_position) <= 2.0:
			var label: String = bingyanger.take_back()
			_refresh_tool()
			_flash_message("TAKEN BACK // %s" % label)
			return "take_back"
	match HIDDEN_CACHE.open_near(caches, player.global_position, sight):
		"stash":
			_flash_message("A FIELD DRESSING AND FOUR ROUNDS // SOMEBODY HID THESE")
			return "stash"
		"door":
			_flash_message("THE BULKHEAD SWINGS // A CLOSET BEHIND IT")
			return "secret_door"
	if sight != null and sight.call("cut_wire_near", player.global_position) != "":
		_flash_message("THE FEED DIES // THAT CAMERA IS BLIND")
		return "wire"
	if gate_passed and _flat_distance(EXIT_AT) <= EXIT_REACH:
		_leave()
		return "exit"
	return ""


func _leave() -> void:
	if exit_requested:
		return
	exit_requested = true
	WorldHistory.record_event("support_unit_left", {"location": LOCATION, "to": "vehicle_bay"})
	if ResourceLoader.exists(NEXT_SCENE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if OS.get_environment("ATG_TEST_MODE") != "1":
			Interstitial.travel(NEXT_SCENE, "support unit // down to the vehicle bay")
	else:
		exit_message = "THE VEHICLE BAY IS NOT BUILT YET // THE WAY DOWN ENDS HERE FOR NOW"
		_flash_message(exit_message, 4.0)


func _physics_process(delta: float) -> void:
	_clock += delta
	swing_cooldown = maxf(0.0, swing_cooldown - delta)
	post_message_timer = maxf(0.0, post_message_timer - delta)
	if not died:
		_move(delta)
	var chest := player.global_position + Vector3(0, 0.35, 0)
	var creeping := Input.is_action_pressed("crouch")
	for lens in cameras:
		lens.step(delta, chest, player, director.is_alarm())
	_update_hack(delta)
	for guard in guards:
		guard.step(delta, player, creeping)
	for bingyanger in bingyangers:
		bingyanger.step(delta)
	guard_post.step(delta, player.global_position)
	_check_gate()
	var entries: Array = director.watch_entries()
	entries.append_array(guard_post.watcher_entries())
	block_tracker.watch(entries)
	_update_alarm_lamps()
	_update_hud()


func _move(delta: float) -> void:
	if JUMP_CLIMB.busy(player):
		camera.rotation = Vector3(pitch, 0, 0)
		return
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	var creeping := Input.is_action_pressed("crouch")
	var running := Input.is_action_pressed("sprint")
	var pace := WALK_SPEED * (1.6 if running else 1.0) * (0.45 if creeping else 1.0)
	camera.position.y = move_toward(camera.position.y, 0.3 if creeping else 0.77, delta * 3.0)
	player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 16.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 16.0 * delta)
	JUMP_CLIMB.fall(player, delta)
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	# Running on tile carries; walking does not.
	if running and not creeping and Vector2(player.velocity.x, player.velocity.z).length() > 4.0 and fmod(_clock, 0.5) < delta:
		_on_noise(player.global_position, 0.45)


func _check_gate() -> void:
	if gate_passed or not guard_post.door_open:
		return
	if player.global_position.z < GATE_Z - 1.0:
		gate_passed = true
		WorldHistory.record_event("support_unit_gate_passed", {"location": LOCATION, "method": gate_method, "alarm": director.level})


func _update_alarm_lamps() -> void:
	var energy := 0.0
	if director.is_alarm():
		energy = 3.5 * (0.5 + 0.5 * sin(_clock * TAU * 1.2))
	elif director.level == "suspicious":
		energy = 0.6
	for lamp in alarm_lamps:
		lamp.light_energy = energy
		lamp.visible = energy > 0.01


func _nearest_remains() -> String:
	for remains_id in remains_nodes:
		var body: Node3D = remains_nodes[remains_id][0]
		if (remains_nodes[remains_id][1] as Label3D).text != "STRIPPED" and _flat_distance(body.global_position) <= REMAINS_REACH:
			return str(remains_id)
	return ""


func _flat_distance(at: Vector3) -> float:
	var difference := at - player.global_position
	difference.y = 0.0
	return difference.length()


func _flash_message(text: String, seconds := 2.4) -> void:
	post_message = text
	post_message_timer = seconds


func _update_hud() -> void:
	var standing := 0
	for guard in guards:
		if not guard.is_down():
			standing += 1
	status.text = "BLOOD %03d%%   SUPPORT UNIT // %d SECURITY STANDING%s" % [roundi(blood), standing, ("   //   " + held_tool) if holding_ram else ""]
	var bars := roundi(director.alertness * 10.0)
	alert_meter.text = "ALERT [%s%s] %s" % ["|".repeat(bars), ".".repeat(10 - bars), director.level.to_upper()]
	alert_meter.add_theme_color_override("font_color", Color("ff4a3a") if director.is_alarm() else (Color("f0b050") if director.level == "suspicious" else Color("d8d0c0")))
	if gate_passed:
		objective.text = "OBJECTIVE // DOWN TO THE VEHICLE BAY"
	elif guard_post.door_open:
		objective.text = "OBJECTIVE // THROUGH THE LAST CHECKPOINT"
	elif director.is_alarm():
		objective.text = "OBJECTIVE // SURVIVE // REACH THE LAST CHECKPOINT"
	else:
		objective.text = "OBJECTIVE // REACH THE LAST CHECKPOINT UNSEEN"
	if post_message_timer > 0.0:
		prompt.text = post_message
		return
	var post_prompt := guard_post.prompt_for(player.global_position, holding_ram)
	if not _nearest_remains().is_empty():
		prompt.text = "[E] TAKE YOUR GEAR BACK OFF YOUR OLD BODY"
	elif not post_prompt.is_empty():
		prompt.text = post_prompt
	elif gate_passed and _flat_distance(EXIT_AT) <= EXIT_REACH:
		prompt.text = "[E] GO DOWN TO THE VEHICLE BAY"
	elif not HIDDEN_CACHE.nearest(caches, player.global_position).is_empty():
		prompt.text = "[E] OPEN IT" if str(HIDDEN_CACHE.nearest(caches, player.global_position).kind) == "door" else "[E] OPEN THE HATCH"
	elif sight != null and sight.call("wire_in_reach", player.global_position):
		prompt.text = "[E] CUT THE CAMERA FEED // QUIET"
	elif hack_target != null:
		prompt.text = "[HOLD Q] LOOP ITS FEED  %s" % ("|".repeat(int(hack_hold / SecurityCamera.HACK_HOLD * 10.0)))
	elif _facing_camera():
		prompt.text = "[LMB] SMASH THE CAMERA // LOUD"
	elif _facing_cell():
		prompt.text = "[LMB] BREAK THE CELL OPEN // LET IT OUT"
	else:
		prompt.text = "WASD MOVE   //   CTRL CREEP   //   SHIFT RUN IS LOUD   //   LMB STRIKE   //   E INTERACT"


## Greg: hacking is "look and hold" once earned. Q held on a lens in sight.
var hack_hold := 0.0
var hack_target: SecurityCamera


func _camera_in_sight() -> SecurityCamera:
	var best: SecurityCamera = null
	var best_angle := deg_to_rad(9.0)
	for lens in cameras:
		if lens.broken or lens.is_looped():
			continue
		var to: Vector3 = lens.eye() - eye()
		if to.length() > 16.0:
			continue
		var angle := look().angle_to(to)
		if angle < best_angle:
			best_angle = angle
			best = lens
	return best


func _update_hack(delta: float) -> void:
	var target := _camera_in_sight() if SecurityCamera.hack_earned() else null
	if target == null or not Input.is_key_pressed(KEY_Q) or target != hack_target:
		hack_hold = 0.0
		hack_target = target
		return
	hack_hold += delta
	if hack_hold >= SecurityCamera.HACK_HOLD:
		hack_hold = 0.0
		var result: Dictionary = target.hack("player")
		if bool(result.get("accepted", false)):
			post_message = "THE WETWIRE FEEDS IT AN EMPTY CORRIDOR // %d SECONDS" % int(result.seconds)
			post_message_timer = 2.5


func _facing_camera() -> bool:
	for lens in cameras:
		if not lens.broken and _in_front(lens.eye(), CAMERA_REACH, deg_to_rad(60.0)):
			return true
	return false


func _facing_cell() -> bool:
	for cell in cells:
		if cell.door.broken:
			continue
		if _in_front(cell.door.global_position + Vector3(0, 1.2, 0), SWING_REACH + 0.6, deg_to_rad(45.0)):
			return true
	return false
