extends Node3D

## THE DOCTOR'S VEHICLE BAY: where the third way out ends (Greg, 24 September,
## DESIGN/ESCAPE_ROUTES.md). The chase comes down the support unit to his bay,
## and he is there, by his vehicle, a man in a stained coat. He is not there.
## Questioning him, hitting him or shooting him shows what he is: light from
## an emitter on the floor. Then he calls: a 3D call of himself taking the
## lift up and leaving from the roof by helicopter (`HologramCall`, which will
## play Greg's TouchDesigner render instead when it exists).
##
## What the player leaves with: the fact of it (the_visiting_doctor's record),
## a task (FOLLOW THE DOCTOR // THE ROOF), and, if they pry it out, the
## emitter as a call implant (`Calling`). The bay's ramp is the way up, and
## walking up it completes FacilityRoutes' doctor pursuit into the Hunt.
##
## Built from primitives on the facility's scanned surfaces like the old
## drains. Art-directed now, authored later.

const OPENING := preload("res://systems/opening_director.gd")
const FACILITY_ROUTES := preload("res://systems/facility_routes.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")
const BASELINE_HUMAN := preload("res://systems/baseline_human.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")
const HOLOGRAM_SHADER := preload("res://shaders/hologram.gdshader")
const SCREEN_SPLIT_SHADER := preload("res://shaders/hologram_screen_split.gdshader")

const ROUTE := FACILITY_ROUTES.ROUTE_DOCTOR
const DOCTOR := DoctorExamination.FATE_SUBJECT
const TASK_ID := "task:follow_the_doctor"
const TASK_TEXT := "FOLLOW THE DOCTOR // THE ROOF"
const GUN_LABEL := "CELL OUTZ BREACH NINE"

const ENTRY := Vector3(0, 1.0, 9.0)
const BAY_WIDTH := 18.0
const BAY_HEIGHT := 6.0
const BAY_NEAR_Z := 12.0
const BAY_FAR_Z := -14.0
const VEHICLE_AT := Vector3(-3.0, 0.0, -4.0)
const DOCTOR_AT := Vector3(0.6, 0.0, -2.2)
const EMITTER_AT := Vector3(0.6, 0.0, -3.1)
const RAMP_WIDTH := 6.0
const RAMP_RISE := 4.0
const RAMP_TOP_Z := -26.0
const WALK_SPEED := 3.4
const QUESTION_REACH := 3.6
const STRIKE_REACH := 2.2
const EMITTER_REACH := 2.0
const REVEAL_SECONDS := 2.2

## PLACEHOLDER: what he says while he still looks real.
const QUESTION_LINES := [
	"You came the long way. Most of them go for the lift.",
	"Ask, then. I have a minute. Not two.",
]

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.05
var objective: Label
var status: Label
var prompt: Label
var speech: Label
var contacts_panel: PanelContainer
var contacts_list: Label

var doctor: Node3D
var doctor_rig: BaselineHuman
var emitter: Node3D
var emitter_light: OmniLight3D
var beam: MeshInstance3D
var ramp_door: StaticBody3D
var hologram_material: ShaderMaterial
var screen_split: ColorRect
var holo_call: HologramCall
var mission_card: MissionCard

## "real" -> "questioning" -> "reveal" -> "call" -> "after" -> "surfaced"
var state := "real"
var state_clock := 0.0
var revealed_by := ""
var question_index := 0
var emitter_taken := false
var ramp_open := false
var surface_requested := false
var last_call_result: Dictionary = {}


func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("lower_works")
	add_child(environment)
	_build_bay()
	_build_vehicle()
	_build_ramp()
	_build_doctor()
	_build_emitter()
	_build_player()
	_build_hud()
	_file_approach()
	WorldHistory.record_event("doctor_vehicle_bay_entered", {"location": "doctor_vehicle_bay"})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The chase came through his examination room and the support unit to get
## here. When those rooms file themselves (another lane's door and corridor)
## this finds them already done; until then the bay files them on arrival, so
## the route graph is whole either way. The bay itself is filed by leaving it.
func _file_approach() -> void:
	var record := FACILITY_ROUTES.ensure()
	if not FACILITY_ROUTES.pending_surface_handoff().is_empty():
		return
	if str(record.get("active_route", "")) != ROUTE:
		FACILITY_ROUTES.begin(ROUTE)
	for district_id in ["examination_room", "support_unit"]:
		var steps: Array = FACILITY_ROUTES.ensure().get("route_steps", [])
		if not steps.has(district_id):
			FACILITY_ROUTES.traverse(district_id)


# -- building -----------------------------------------------------------------

func _stained(role: String, tint: Color) -> StandardMaterial3D:
	var material := LabSurface.material(role).duplicate() as StandardMaterial3D
	material.albedo_color = tint
	return material


func _slab(dimensions: Vector3, at: Vector3, material: Material, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	(parent if parent != null else self).add_child(body)
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


func _mesh_box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	piece.mesh = mesh
	piece.position = at
	parent.add_child(piece)
	return piece


func _lamp(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	add_child(lamp)
	return lamp


## A private bay: poured floor with painted bays, concrete walls, a steel
## ceiling on beams, the support unit's corridor mouth behind the player and
## the ramp's shutter ahead.
func _build_bay() -> void:
	var wall := _stained("wall", Color(0.42, 0.44, 0.42))
	var floor_material := _stained("wall", Color(0.34, 0.34, 0.32))
	var length := BAY_NEAR_Z - BAY_FAR_Z
	var mid := (BAY_NEAR_Z + BAY_FAR_Z) * 0.5
	_slab(Vector3(BAY_WIDTH, 0.4, length), Vector3(0, -0.2, mid), floor_material)
	_slab(Vector3(BAY_WIDTH, 0.4, length), Vector3(0, BAY_HEIGHT + 0.2, mid), _stained("ceiling", Color(0.30, 0.30, 0.29)))
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.5, BAY_HEIGHT, length), Vector3(side * (BAY_WIDTH * 0.5 + 0.25), BAY_HEIGHT * 0.5, mid), wall)
	# Near wall with the corridor mouth the player came through.
	var shoulder := (BAY_WIDTH - 3.0) * 0.5
	for side in [-1.0, 1.0]:
		_slab(Vector3(shoulder, BAY_HEIGHT, 0.5), Vector3(side * (1.5 + shoulder * 0.5), BAY_HEIGHT * 0.5, BAY_NEAR_Z), wall)
	_slab(Vector3(3.0, BAY_HEIGHT - 3.0, 0.5), Vector3(0, 3.0 + (BAY_HEIGHT - 3.0) * 0.5, BAY_NEAR_Z), wall)
	_slab(Vector3(3.0, 3.0, 0.5), Vector3(0, 1.5, BAY_NEAR_Z + 3.0), wall)
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.3, 3.0, 3.0), Vector3(side * 1.65, 1.5, BAY_NEAR_Z + 1.5), wall)
	# Far wall either side of the ramp shutter.
	var far_shoulder := (BAY_WIDTH - RAMP_WIDTH) * 0.5
	for side in [-1.0, 1.0]:
		_slab(Vector3(far_shoulder, BAY_HEIGHT, 0.5), Vector3(side * (RAMP_WIDTH * 0.5 + far_shoulder * 0.5), BAY_HEIGHT * 0.5, BAY_FAR_Z), wall)
	_slab(Vector3(RAMP_WIDTH, 1.0, 0.5), Vector3(0, BAY_HEIGHT - 0.5, BAY_FAR_Z), wall)
	# Painted parking bay round the vehicle, and hazard stripes at the ramp.
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("c8b24a")
	paint.roughness = 0.8
	for x in [-5.6, -0.4]:
		_mesh_box(self, Vector3(0.12, 0.01, 8.0), Vector3(x, 0.006, VEHICLE_AT.z), paint)
	_mesh_box(self, Vector3(5.3, 0.01, 0.12), Vector3(-3.0, 0.006, VEHICLE_AT.z + 4.0), paint)
	var hazard := StandardMaterial3D.new()
	hazard.albedo_color = Color("a8281a")
	for stripe in 7:
		var piece := _mesh_box(self, Vector3(0.35, 0.012, 1.2), Vector3(-2.7 + float(stripe) * 0.9, 0.007, BAY_FAR_Z + 1.0), hazard)
		piece.rotation.y = 0.6
	# Ceiling beams and sodium work lights.
	var rust := _stained("rust", Color(0.5, 0.42, 0.34))
	for beam_index in 5:
		var z := BAY_NEAR_Z - 2.5 - float(beam_index) * 5.2
		_mesh_box(self, Vector3(BAY_WIDTH, 0.4, 0.35), Vector3(0, BAY_HEIGHT - 0.2, z), rust)
		_lamp(Vector3(0, BAY_HEIGHT - 0.8, z), Color("e0a060"), 5.0, 11.0)
	# A cold light over his parking bay, so the car and the man read.
	_lamp(Vector3(-1.4, BAY_HEIGHT - 1.0, VEHICLE_AT.z + 1.0), Color("c9d6cf"), 2.4, 9.0)
	# Tool wall and fuel drums, so the room is used, not staged.
	var steel := _stained("plate", Color(0.55, 0.56, 0.55))
	_slab(Vector3(0.4, 2.4, 4.0), Vector3(BAY_WIDTH * 0.5 - 0.3, 1.2, 2.0), steel)
	for drum in 3:
		var barrel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.3
		cylinder.bottom_radius = 0.3
		cylinder.height = 0.9
		cylinder.material = _stained("rust", Color(0.62, 0.22, 0.14))
		barrel.mesh = cylinder
		barrel.position = Vector3(BAY_WIDTH * 0.5 - 0.6 - float(drum % 2) * 0.62, 0.45, -6.0 - float(drum) * 0.6)
		add_child(barrel)


## His vehicle: a long black armoured car in a CellOutz stripe. The helicopter
## is how he actually left; this is the one he did not need.
func _build_vehicle() -> void:
	var car := Node3D.new()
	car.name = "DoctorsVehicle"
	car.position = VEHICLE_AT
	add_child(car)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("141516")
	paint.metallic = 0.6
	paint.roughness = 0.28
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("0b1113")
	glass.metallic = 0.4
	glass.roughness = 0.05
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color("8e1714")
	var body := _slab(Vector3(2.2, 1.0, 5.4), Vector3(0, 0.85, 0), paint, car)
	body.name = "Body"
	_mesh_box(car, Vector3(2.0, 0.7, 3.0), Vector3(0, 1.7, 0.3), glass)
	_mesh_box(car, Vector3(2.06, 0.08, 3.06), Vector3(0, 2.08, 0.3), paint)
	_mesh_box(car, Vector3(2.24, 0.14, 5.0), Vector3(0, 0.95, 0), stripe)
	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color("0a0a0a")
	tyre.roughness = 0.9
	for x in [-1.05, 1.05]:
		for z in [-1.8, 1.8]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.42
			cylinder.bottom_radius = 0.42
			cylinder.height = 0.32
			cylinder.material = tyre
			wheel.mesh = cylinder
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(x, 0.42, z)
			car.add_child(wheel)
	var lamp_glass := StandardMaterial3D.new()
	lamp_glass.albedo_color = Color("f2e8c8")
	lamp_glass.emission_enabled = true
	lamp_glass.emission = Color("f2e8c8")
	lamp_glass.emission_energy_multiplier = 3.0
	for x in [-0.72, 0.72]:
		_mesh_box(car, Vector3(0.42, 0.16, 0.05), Vector3(x, 1.0, 2.72), lamp_glass)
	var headlights := SpotLight3D.new()
	headlights.position = Vector3(0, 1.0, 2.9)
	headlights.light_color = Color("f2e8c8")
	headlights.light_energy = 3.0
	headlights.spot_range = 12.0
	headlights.spot_angle = 38.0
	car.add_child(headlights)
	headlights.rotation.y = PI


## The ramp up to the surface behind a shutter that only lifts after the call.
func _build_ramp() -> void:
	var wall := _stained("wall", Color(0.40, 0.41, 0.39))
	var length := absf(RAMP_TOP_Z - BAY_FAR_Z)
	var slope := atan2(RAMP_RISE, length)
	var ramp := _slab(Vector3(RAMP_WIDTH, 0.4, length / cos(slope) + 0.4), Vector3(0, RAMP_RISE * 0.5 - 0.2, (BAY_FAR_Z + RAMP_TOP_Z) * 0.5), _stained("wall", Color(0.32, 0.32, 0.30)))
	ramp.rotation.x = slope
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.5, BAY_HEIGHT + RAMP_RISE, length + 2.0), Vector3(side * (RAMP_WIDTH * 0.5 + 0.25), (BAY_HEIGHT + RAMP_RISE) * 0.5, (BAY_FAR_Z + RAMP_TOP_Z) * 0.5 - 1.0), wall)
	_slab(Vector3(RAMP_WIDTH, 0.4, length + 2.0), Vector3(0, BAY_HEIGHT + RAMP_RISE - 0.8, (BAY_FAR_Z + RAMP_TOP_Z) * 0.5 - 1.0), wall)
	# The landing at the top and the daylight past it.
	_slab(Vector3(RAMP_WIDTH, 0.4, 3.0), Vector3(0, RAMP_RISE - 0.2, RAMP_TOP_Z - 1.5), _stained("wall", Color(0.32, 0.32, 0.30)))
	var day := MeshInstance3D.new()
	var glow := QuadMesh.new()
	glow.size = Vector2(RAMP_WIDTH, BAY_HEIGHT)
	var day_material := StandardMaterial3D.new()
	day_material.albedo_color = Color("dfe6d2")
	day_material.emission_enabled = true
	day_material.emission = Color("dfe6d2")
	day_material.emission_energy_multiplier = 2.4
	day_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material = day_material
	day.mesh = glow
	day.position = Vector3(0, RAMP_RISE + BAY_HEIGHT * 0.5 - 0.5, RAMP_TOP_Z - 3.0)
	add_child(day)
	_slab(Vector3(RAMP_WIDTH + 1.0, BAY_HEIGHT + 1.0, 0.5), Vector3(0, RAMP_RISE + BAY_HEIGHT * 0.5, RAMP_TOP_Z - 3.3), wall)
	_lamp(Vector3(0, RAMP_RISE + 2.0, RAMP_TOP_Z - 1.0), Color("e8efe0"), 6.0, 16.0)
	# The shutter, ribbed steel with a red warning light over it.
	ramp_door = _slab(Vector3(RAMP_WIDTH, BAY_HEIGHT - 1.0, 0.25), Vector3(0, (BAY_HEIGHT - 1.0) * 0.5, BAY_FAR_Z), _stained("plate", Color(0.46, 0.47, 0.46)))
	ramp_door.name = "RampShutter"
	var rib := _stained("rust", Color(0.4, 0.36, 0.3))
	for rib_index in 8:
		_mesh_box(ramp_door, Vector3(RAMP_WIDTH, 0.06, 0.1), Vector3(0, -2.2 + float(rib_index) * 0.6, 0.15), rib)
	_lamp(Vector3(0, BAY_HEIGHT - 0.6, BAY_FAR_Z + 0.6), Color("ff3a20"), 2.0, 5.0).name = "ShutterWarning"


## He is the examiner's kind of man (`examiner_feed.gd`): a BaselineHuman in a
## clinical coat stained from the procedures, an ordinary face, standing by
## his car facing the way the player comes in.
func _build_doctor() -> void:
	doctor = Node3D.new()
	doctor.name = "Doctor"
	doctor.position = DOCTOR_AT
	add_child(doctor)
	doctor_rig = BASELINE_HUMAN.new()
	doctor_rig.name = "DoctorBody"
	# The rig's face is built on -Z; he faces +Z, toward the corridor mouth.
	doctor_rig.rotation.y = PI
	doctor.add_child(doctor_rig)
	doctor_rig.build("visiting_doctor_hologram", BASELINE_HUMAN.config_from_subject({"race": "decanted"}).merged({"gore": false}, true))
	# The rig is light, not a body: nothing may collide with it or bleed.
	for node in doctor_rig.find_children("*", "CollisionObject3D", true, false):
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	var look := HUNTER_APPEARANCE.new()
	doctor_rig.add_child(look)
	look.configure(doctor_rig, {"axes": {"brow": 0.7, "jaw": 0.6, "cheek": 0.2, "eyes": 0.3, "nose": 0.55, "mouth": 0.4}})
	_dress_as_staff(look)
	hologram_material = ShaderMaterial.new()
	hologram_material.shader = HOLOGRAM_SHADER


## The same dressing `ExaminerFeed._dress_as_staff` gives the examiner, kept
## here rather than shared because that file belongs to the intake lane.
func _dress_as_staff(appearance: Node) -> void:
	var wardrobe := ClothingShell.fresh_wardrobe()
	wardrobe.erase("head")
	wardrobe["style"] = "clinical"
	ClothingShell.stain(doctor_rig, "torso", 0.55)
	ClothingShell.stain(doctor_rig, "right_arm", 0.5)
	ClothingShell.stain(doctor_rig, "left_arm", 0.35)
	ClothingShell.stain(doctor_rig, "left_leg", 0.2)
	ClothingShell.stain(doctor_rig, "right_leg", 0.15)
	doctor_rig.dress(wardrobe)
	var coat := Color("d8d4c6").lerp(Color("5a1a12"), 0.38)
	var pieces: Dictionary = appearance.get("details")
	for piece_name in ["Coat_Front", "Collar_L", "Collar_R"]:
		var piece := pieces.get(piece_name) as MeshInstance3D
		if piece != null and piece.mesh != null:
			var cloth := StandardMaterial3D.new()
			cloth.albedo_color = coat.darkened(0.08 if piece_name != "Coat_Front" else 0.0)
			cloth.roughness = 0.9
			piece.mesh.material = cloth
	var strap := pieces.get("Torque_Strap") as Node3D
	if strap != null:
		strap.visible = false
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("b79a86")
	skin.roughness = 0.55
	skin.rim_enabled = true
	skin.rim = 0.25
	var head := doctor_rig.parts.get("head") as MeshInstance3D
	if head != null:
		head.material_override = skin
	var sclera := StandardMaterial3D.new()
	sclera.albedo_color = Color("d9d4c8")
	var iris := StandardMaterial3D.new()
	iris.albedo_color = Color("1c1512")
	var lips := StandardMaterial3D.new()
	lips.albedo_color = Color("8a5a4e")
	for piece_name: String in pieces:
		var piece := pieces[piece_name] as MeshInstance3D
		if piece == null or piece.mesh == null or piece.get_parent() != head:
			continue
		if piece_name.begins_with("Eye_"):
			piece.material_override = sclera
		elif piece_name.begins_with("Pupil_"):
			piece.material_override = iris
		elif piece_name.begins_with("Mouth_"):
			piece.material_override = lips
		elif piece_name.begins_with("Tooth_"):
			piece.visible = false
		else:
			piece.material_override = skin


## The emitter: a dark puck on the floor at his feet that nobody looks at
## until he flickers. After the reveal it glows and throws the beam up him.
func _build_emitter() -> void:
	emitter = Node3D.new()
	emitter.name = "HologramEmitter"
	emitter.position = EMITTER_AT
	add_child(emitter)
	var housing := MeshInstance3D.new()
	var puck := CylinderMesh.new()
	puck.top_radius = 0.16
	puck.bottom_radius = 0.2
	puck.height = 0.08
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("1d1f20")
	steel.metallic = 0.7
	steel.roughness = 0.35
	puck.material = steel
	housing.mesh = puck
	housing.position.y = 0.04
	emitter.add_child(housing)
	var lens := MeshInstance3D.new()
	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.05
	lens_mesh.height = 0.05
	var lens_material := StandardMaterial3D.new()
	lens_material.albedo_color = Color("163238")
	lens_material.emission_enabled = true
	lens_material.emission = Color("5fd6e8")
	lens_material.emission_energy_multiplier = 0.3
	lens_mesh.material = lens_material
	lens.mesh = lens_mesh
	lens.name = "Lens"
	lens.position.y = 0.09
	emitter.add_child(lens)
	emitter_light = OmniLight3D.new()
	emitter_light.light_color = Color("5fd6e8")
	emitter_light.light_energy = 0.0
	emitter_light.omni_range = 3.5
	emitter_light.position.y = 0.4
	emitter.add_child(emitter_light)
	beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.55
	cone.bottom_radius = 0.06
	cone.height = 1.9
	beam.mesh = cone
	var beam_material := ShaderMaterial.new()
	beam_material.shader = HOLOGRAM_SHADER
	beam_material.set_shader_parameter("strength", 0.35)
	beam.material_override = beam_material
	# Tipped from the puck up and toward him.
	beam.position = Vector3(0, 0.95, 0.45)
	beam.rotation.x = 0.45
	beam.visible = false
	emitter.add_child(beam)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = ENTRY
	player.floor_max_angle = deg_to_rad(40.0)
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
	player.add_child(camera)
	LabSurface.attach_body_cam(camera)
	if VatRebirth.carries("BREACH TOOL"):
		LabSurface.hold_in_view(camera, LabSurface.breach_tool())


func _label(layer: Node, at: Vector2, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	layer.add_child(label)
	return label


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	screen_split = ColorRect.new()
	screen_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var split_material := ShaderMaterial.new()
	split_material.shader = SCREEN_SPLIT_SHADER
	screen_split.material = split_material
	screen_split.visible = false
	layer.add_child(screen_split)
	objective = _label(layer, Vector2(34, 34), 18, Color("e4a058"))
	status = _label(layer, Vector2(34, 62), 13, Color("a8c58d"))
	speech = Label.new()
	speech.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	speech.offset_top = -120
	speech.offset_bottom = -80
	speech.offset_left = -420
	speech.offset_right = 420
	speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech.add_theme_font_size_override("font_size", 19)
	speech.add_theme_color_override("font_color", Color("efe6d4"))
	layer.add_child(speech)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -55
	prompt.offset_left = -360
	prompt.offset_right = 360
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.add_theme_color_override("font_color", Color("dd9851"))
	layer.add_child(prompt)
	# The minimal call list. The Brain Index's own screen will read `Calling`
	# the same way; this is the stand-in until it does.
	contacts_panel = PanelContainer.new()
	contacts_panel.position = Vector2(34, 110)
	contacts_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.01, 0.05, 0.06, 0.85)
	panel_style.border_color = Color("5fd6e8")
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(12)
	contacts_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(contacts_panel)
	contacts_list = Label.new()
	contacts_list.add_theme_font_size_override("font_size", 14)
	contacts_list.add_theme_color_override("font_color", Color("bff4ff"))
	contacts_panel.add_child(contacts_list)
	holo_call = HologramCall.new()
	holo_call.name = "HologramCall"
	layer.add_child(holo_call)
	holo_call.finished.connect(_on_call_finished)
	mission_card = MissionCard.new()
	mission_card.name = "MissionCard"
	mission_card.visible = false
	layer.add_child(mission_card)


# -- play ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked: bool = event.pressed
		if clicked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			attack()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.15, 0.95)
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_E:
			interact()
		elif key == KEY_C and Calling.unlocked():
			toggle_contacts()
		elif key == KEY_SPACE and state == "call":
			holo_call.skip()
		elif contacts_panel.visible and key >= KEY_1 and key <= KEY_9:
			call_contact(key - KEY_1)


func _physics_process(delta: float) -> void:
	var busy := state in ["reveal", "call"]
	var input := Vector3.ZERO if busy else Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	var pace := WALK_SPEED * (1.6 if Input.is_action_pressed("sprint") else 1.0)
	player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 16.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 16.0 * delta)
	player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	step(delta)
	_update_hud()


## The encounter's clock, separate from movement so a test can drive it.
func step(delta: float) -> void:
	state_clock += delta
	match state:
		"questioning":
			if state_clock >= 3.2:
				question_index += 1
				state_clock = 0.0
				if question_index >= QUESTION_LINES.size():
					# His mouth keeps moving after the words stop.
					_reveal("questioned")
		"reveal":
			var fade := clampf(state_clock / REVEAL_SECONDS, 0.0, 1.0)
			(screen_split.material as ShaderMaterial).set_shader_parameter("amount", lerpf(1.0, 0.25, fade))
			hologram_material.set_shader_parameter("glitch", lerpf(1.0, 0.2, fade))
			if state_clock >= REVEAL_SECONDS:
				_begin_call()
		"after", "surfaced":
			if ramp_open and ramp_door.position.y < BAY_HEIGHT + 1.1:
				ramp_door.position.y = minf(BAY_HEIGHT + 1.1, ramp_door.position.y + delta * 1.6)
			if state == "after" and player.global_position.z < RAMP_TOP_Z + 1.0 and player.global_position.y > RAMP_RISE - 0.5:
				surface()
	if state in ["reveal", "call", "after"]:
		# Light that forgets to be steady: he stutters out for a frame or two.
		doctor_rig.visible = fmod(state_clock * 7.3, 1.0) > 0.06
	if hologram_material != null and state in ["call", "after"]:
		hologram_material.set_shader_parameter("glitch", 0.5 if fmod(state_clock, 2.7) < 0.15 else 0.1)


func interact() -> void:
	if state == "real" and _flat_distance(DOCTOR_AT) <= QUESTION_REACH:
		question()
	elif state == "after" and not emitter_taken and _flat_distance(EMITTER_AT) <= EMITTER_REACH:
		take_emitter()


## E: you ask him things. He answers like a man, then keeps talking a beat
## after the words stop, and flickers.
func question() -> void:
	if state != "real":
		return
	state = "questioning"
	state_clock = 0.0
	question_index = 0
	PLAYER_ACTION_LEDGER.record("doctor_questioned", {"subject_id": DOCTOR, "location": "doctor_vehicle_bay"})


## LMB. Close enough and it is a blow that goes through him; further off with
## Hollis's gun it is a shot that goes through him and sparks off the car.
func attack() -> void:
	if state not in ["real", "questioning"]:
		return
	var distance := _flat_distance(DOCTOR_AT)
	if distance <= STRIKE_REACH:
		strike()
	elif VatRebirth.carries(GUN_LABEL):
		shoot()


func strike() -> void:
	if state not in ["real", "questioning"]:
		return
	_reveal("struck")


func shoot() -> void:
	if state not in ["real", "questioning"]:
		return
	var flash := _lamp(player.global_position + Vector3(0, 0.8, 0), Color("ffb35a"), 6.0, 5.0)
	get_tree().create_timer(0.08).timeout.connect(flash.queue_free)
	var spark := _lamp(VEHICLE_AT + Vector3(2.0, 1.2, 0.5), Color("ffd08a"), 5.0, 2.5)
	get_tree().create_timer(0.12).timeout.connect(spark.queue_free)
	_reveal("shot")


## The moment he stops being a man. The blow, the question or the bullet goes
## through; the coat and face become cyan scanlines; the screen splits.
func _reveal(how: String) -> void:
	if state not in ["real", "questioning"]:
		return
	state = "reveal"
	state_clock = 0.0
	revealed_by = how
	speech.text = {
		"struck": "Your blow goes through him. There is nothing there.",
		"shot": "The round goes through him and sparks off the car.",
		"questioned": "His mouth keeps moving after the words stop.",
	}.get(how, "")
	for node in doctor_rig.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = hologram_material
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hologram_material.set_shader_parameter("glitch", 1.0)
	screen_split.visible = true
	(screen_split.material as ShaderMaterial).set_shader_parameter("amount", 1.0)
	emitter_light.light_energy = 2.5
	beam.visible = true
	var lens := emitter.get_node("Lens") as MeshInstance3D
	((lens.mesh as SphereMesh).material as StandardMaterial3D).emission_energy_multiplier = 4.0
	# DoctorExamination's pursuit window: catching him is recorded if it was
	# still open, and silent if not (AX2.5: missing it is never announced).
	var caught := DoctorExamination.catch_up()
	WorldHistory.begin_ledger_batch()
	WorldHistory.register_subject(DOCTOR, {"kind": "person", "name": "THE VISITING DOCTOR", "role": "Visiting doctor"})
	WorldHistory.amend_subject(DOCTOR, {"seen_as_hologram": true, "met_player": true})
	PLAYER_ACTION_LEDGER.record("doctor_hologram_revealed", {
		"subject_id": DOCTOR, "how": how, "location": "doctor_vehicle_bay",
		"in_window": bool(caught.get("ok", false)),
	})
	WorldHistory.commit_ledger_batch()


func _begin_call() -> void:
	state = "call"
	state_clock = 0.0
	speech.text = ""
	(screen_split.material as ShaderMaterial).set_shader_parameter("amount", 0.12)
	holo_call.play("doctor_call", "THE VISITING DOCTOR")


## After the call: what the player now knows, the task it leaves them, and
## the ramp shutter lifting.
func _on_call_finished(_call_id: String) -> void:
	if state != "call":
		return
	state = "after"
	state_clock = 0.0
	screen_split.visible = false
	WorldHistory.begin_ledger_batch()
	WorldHistory.update_subject(DOCTOR, {
		"status": "left the facility from the roof by helicopter",
		"left_by": "helicopter",
		"left_from": "roof",
		"last_seen": "as a hologram in his vehicle bay",
		"memory": "Was never in the bay. Projected himself by his car, then called to show the lift, the roof and the helicopter.",
	}, "doctor_departure_learned")
	WorldHistory.register_subject(TASK_ID, {
		"kind": "task", "name": "FOLLOW THE DOCTOR", "objective": TASK_TEXT,
		"status": "open", "given_by": DOCTOR, "source": "doctor_vehicle_bay",
		"given_at_minute": WorldClock.minutes(),
	})
	PLAYER_ACTION_LEDGER.record("doctor_call_received", {"subject_id": DOCTOR, "location": "doctor_vehicle_bay", "task": TASK_ID})
	WorldHistory.record_event("task_given", {"task_id": TASK_ID, "objective": TASK_TEXT, "given_by": DOCTOR})
	WorldHistory.commit_ledger_batch()
	mission_card.play("follow_the_doctor", TASK_TEXT, 4.2)
	open_ramp()


func open_ramp() -> void:
	if ramp_open:
		return
	ramp_open = true
	# Out of the way at once for collision; the steel itself rolls up in step().
	for child in ramp_door.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	var warning := get_node_or_null("ShutterWarning") as OmniLight3D
	if warning != null:
		warning.light_color = Color("7fe07a")
	WorldHistory.record_event("doctor_bay_ramp_opened", {"location": "doctor_vehicle_bay"})


## E at the puck after the call: pry his link out and wire it into yourself.
func take_emitter() -> Dictionary:
	if emitter_taken or state not in ["after", "surfaced"]:
		return {"ok": false}
	var result := Calling.install_emitter("doctor_vehicle_bay")
	if bool(result.get("ok", false)):
		emitter_taken = true
		emitter.visible = false
		doctor.visible = false
		speech.text = "You pry the emitter out and it finds the socket in your head. [C] CALL SOMEONE"
	return result


func toggle_contacts() -> void:
	contacts_panel.visible = not contacts_panel.visible
	_refresh_contacts()


func call_contact(index: int) -> Dictionary:
	var rows := Calling.contacts()
	if index < 0 or index >= rows.size():
		return {"ok": false}
	last_call_result = Calling.invite(str(rows[index].id))
	_refresh_contacts()
	return last_call_result


func _refresh_contacts() -> void:
	var lines: Array[String] = ["CALL // WHO DO YOU KNOW", ""]
	var rows := Calling.contacts()
	for index in mini(rows.size(), 9):
		lines.append("[%d] %s  %s" % [index + 1, str(rows[index].name), str(rows[index].disposition).to_upper()])
	if rows.is_empty():
		lines.append("NOBODY. YOU HAVE NOT MET ANYONE YET.")
	if not last_call_result.is_empty():
		lines.append("")
		lines.append("%s // %s" % [str(last_call_result.get("outcome", "")).to_upper().replace("_", " "), str(last_call_result.get("line", ""))])
	contacts_list.text = "\n".join(lines)


## The top of the ramp. Files the bay with the route graph, which completes
## the doctor pursuit and hands the Hunt its arrival point.
func surface() -> bool:
	if state != "after":
		return false
	_file_approach()
	if not FACILITY_ROUTES.traverse("doctor_vehicle_bay"):
		return false
	state = "surfaced"
	WorldHistory.begin_ledger_batch()
	OPENING.advance("left_facility")
	FACILITY_TERRITORY.apply_event("facility_surfaced")
	WorldHistory.amend_subject("player", {"status": "out up the doctor's ramp", "left_facility_by": "doctor_vehicle_bay"})
	WorldHistory.record_event("doctor_bay_surfaced", {"location": "doctor_vehicle_bay"})
	WorldHistory.commit_ledger_batch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	surface_requested = true
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Interstitial.travel("res://bone_yard_hunt.tscn", "the doctor's ramp // up into the ashbloom expanse")
	return true


func _flat_distance(at: Vector3) -> float:
	var difference := at - player.global_position
	difference.y = 0.0
	return difference.length()


func _update_hud() -> void:
	status.text = "SUPPORT UNIT // THE DOCTOR'S VEHICLE BAY"
	match state:
		"real", "questioning":
			objective.text = "OBJECTIVE // GET REVENGE"
		"reveal", "call":
			objective.text = "OBJECTIVE // ..."
		_:
			objective.text = "OBJECTIVE // " + TASK_TEXT
	if state == "questioning":
		speech.text = "\"%s\"" % QUESTION_LINES[mini(question_index, QUESTION_LINES.size() - 1)]
	var near_doctor := _flat_distance(DOCTOR_AT)
	if state == "real" and near_doctor <= STRIKE_REACH:
		prompt.text = "[E] QUESTION HIM   //   LMB HIT HIM"
	elif state == "real" and near_doctor <= QUESTION_REACH:
		prompt.text = "[E] QUESTION HIM" + ("   //   LMB SHOOT HIM" if VatRebirth.carries(GUN_LABEL) else "")
	elif state == "real":
		prompt.text = "HE IS BY HIS CAR" + ("   //   LMB SHOOT HIM" if VatRebirth.carries(GUN_LABEL) else "")
	elif state == "call":
		prompt.text = "[SPACE] HANG UP"
	elif state == "after" and not emitter_taken and _flat_distance(EMITTER_AT) <= EMITTER_REACH:
		prompt.text = "[E] PRY OUT THE EMITTER // HIS CALL LINK"
	elif state == "after":
		prompt.text = "THE RAMP IS OPEN // WALK UP" + ("   //   [C] CALL" if Calling.unlocked() else "")
	else:
		prompt.text = ""
