extends Node3D
const LOOK := preload("res://systems/look_settings.gd")

## THE GROWING FLOOR — the opening.
##
## The player surfaces inside a vat: submerged, umbilicals in, fluid over the
## glass, rows of other tanks receding into the dark. The tank voids and leaves
## them hanging in the umbilicals under END ALL SUFFERING; they tear the wires
## out of themselves one by one, the screen answers GET REVENGE, and only then
## does the glass go. They land on the grating in a spreading puddle and walk
## the aisle toward the Service Arcade.
##
## Biomechanical register per ART-DIRECTION.md: ribbed vertebral arches,
## conduits that read as gut rather than pipe, wet everything. Built from
## primitives on the biopunk palette — art-directed now, authored later.

const OPENING := preload("res://systems/opening_director.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")
const ANATOMY := preload("res://systems/anatomy_component.gd")
const LAB_CABLES := preload("res://systems/lab_cables.gd")
const VAT_SMASH := preload("res://systems/vat_smash.gd")
const IMPLANT_CATALOG := preload("res://systems/implant_catalog.gd")
const VAT_INTAKE := preload("res://systems/vat_intake.gd")
const OPENING_AUDIO := preload("res://systems/opening_audio.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")
const BRAIN_INDEX := preload("res://systems/brain_index.gd")
const CARRY := preload("res://systems/carry.gd")
const CLOTHING := preload("res://systems/clothing.gd")
const BASELINE_HUMAN := preload("res://systems/baseline_human.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")
const VAT_REBIRTH := preload("res://systems/vat_rebirth.gd")
const WOUND_CATALOG := preload("res://systems/wound_catalog.gd")
const DOCTOR_ROUTE := preload("res://systems/doctor_route.gd")

const EYE_HEIGHT := 1.62
const BODY_HALF_HEIGHT := 0.85
const STANDING_EYE_OFFSET := EYE_HEIGHT - BODY_HALF_HEIGHT
const VAT_POSITION := Vector3(0, 0, 0)
## P4.3: was 34.0 — a fresh body limps this at mobility_ratio speed (2.7 u/s),
## so the aisle alone cost ~10.6s of forced, agency-free walking after the
## ~19s of locked beats already ahead of it. Cut to the shortest length that
## still reads as a receding row of tanks (see the bay-count derivation below).
const AISLE_LENGTH := 22.0
## The wires beat (Greg, via the handoff and 24 September: END ALL SUFFERING,
## tear the wires out, GET REVENGE, instead of the glass breaking by itself).
## The tank is drained at this clock time; the breach and floor beats count
## from it exactly as they did when the drain broke the glass on its own.
const DRAINED_AT := 5.6
## Tugs it takes to tear one umbilical out. The first ones only hurt.
const WIRE_TUGS := 3
## How long GET REVENGE holds before the glass goes.
const REVENGE_HOLD := 2.8
## How long END ALL SUFFERING owns the screen before the wires can be seen.
const END_CARD_SECONDS := 3.4

var player: CharacterBody3D
var camera: Camera3D
var anatomy: Node
var yaw := 0.0
var pitch := 0.0
var clock := 0.0
var phase := "intake"
var can_move := false
var intake: Control
var opening_audio: Node
var fluid: MeshInstance3D
var vat_glass: MeshInstance3D
var umbilicals: Array[Node3D] = []
## What the lab's wiring built: cable and mesh counts, and how low it hangs.
var cable_report: Dictionary = {}
## The other tanks, which can be smashed once you are out of your own.
var vat_smash
var glass_shards: Array[Dictionary] = []
var door_marker: Node3D
var line_index := -1
var breakout_complete := false
var first_acquisition_complete := false
var objective_text := "ESCAPE THE FACILITY"

## The examination has to end before the escape begins. Filing used to drop
## the player straight into "voiding" with the examiner still standing at his
## terminal, so the objective arrived while the man who put you in the tank
## was watching you leave it. He now walks out of his own staff door and shuts
## it, and only then does the vat fail.
var examiner_node: Node3D
var staff_door_panel: Node3D
## Where the examiner stands at his terminal, and whether his door has been
## heard shutting behind him.
var examiner_post := Vector3.ZERO
var examiner_door_heard := false
var departure_clock := 0.0
var departure_line := -1
var arrival_clock := 0.0
var vat_struts: Array[MeshInstance3D] = []
## How long the breach still shakes the camera. The glass used to simply stop
## being rendered, which Greg described as "I don't even smash out of the glass
## tube" -- there was no event, only an absence.
var breach_shake := 0.0
## Set into the right-hand wall level with the workstation, so he leaves the
## way staff leave rather than walking the player's escape route. It is not the
## pit door at the far end and it is never openable by the player.
const STAFF_DOOR_AT := Vector3(6.95, 0.0, -2.49)
## Greg, 24 September: the examiner and his PC stood in the middle of the vat
## aisle. The workstation is a monitoring post now, off the aisle to the
## right-front of the tank and turned to face it: the screen is the
## subject-facing terminal the intake is shown on, and he works it from the
## end of the desk rather than standing inside it.
const STATION_AT := Vector3(2.7, 0.0, -1.3)
const STATION_YAW := -1.12
const EXAMINER_AT_DESK := Vector3(-1.45, 0.0, 0.05)
const EXAMINER_TURN := 0.6
const DEPARTURE_SECONDS := 4.4

## AX3.1/AX3.6. The Growing Floor's first two objects: the broken restraint
## granted at the breach is inert cargo until the player actually does
## something with it. This is the something — a jammed failure-tank the
## restraint's sheared edge can bite into, the same E verb the door already
## answers to, no separate tutorial prompt inventing a new one. AX3.2 hangs
## its dead subject and their clothing on the same marker once it is open.
const RESTRAINT_LABEL := "BROKEN MEDICAL RESTRAINT"
const RESTRAINT_INSPECT_TEXT := "A hinge sheared clean at the pin. The broken edge is a wedge, if there is a seam to put it in."
const FAILED_SUBJECT_ID := "growing_floor_failed_subject"
const FIRST_OBJECT_REACH := 3.0
var stuck_tank_marker: Node3D
var stuck_tank_shell: MeshInstance3D
var stuck_tank_culture: MeshInstance3D
var failed_subject_visual: Node3D
var stuck_tank_opened := false
var inspect_held := false
## Death is rebirth in a vat (Greg, 24 September). A regrown body wakes here
## with no examination: the record, the preset and the memories are kept.
var rebirth := false
var active_beats: Array = BEATS
var title: Label
## The HUD as body-cam footage (Greg, 24 September).
var osd: BodyCamOSD
## Greg: the task titles "in massive celloutz style font, bloody and bony ...
## moving around 4d, inverting, going crazy, and after that flashes". The
## card bursts in over everything; the flickering `title` label is what stays
## on screen while the player works at the wires.
var mission_card: Control
var wired_clock := 0.0
var revenge_at := -1.0
var jolt := 0.0
## His door behind the vat, his room and the lift down (DoctorRoute).
var doctor_route: Node3D

# 0 submerged, 1 voiding, 2 breach, 3 floor, 4 aisle
const BEATS := [
	{"at": 0.8, "text": "AIRWAY OBSTRUCTED  //  FOREIGN TUBE"},
	{"at": 3.2, "text": "TANK 0C-7  //  CYCLE ABORTED  //  VOIDING"},
	# The two HANDLER lines that used to sit at 5.8 and 7.4 have moved into
	# DEPARTURE_BEATS. He says them on his way out, which is the only time he
	# is still in the room: the vat does not fail until the door shuts behind
	# him. What is left here is the tank talking, not a person.
	#
	# There was a fifth beat that printed "OBJECTIVE // ESCAPE THE FACILITY"
	# across the middle of the screen while `$HUD/Objective` printed the same
	# words in the corner. One objective, one place: the HUD label.
]

## K3.2. "The opening reframed: CellOutz grew you, which is why the debt is in
## the meat" — DESIGN/COSMOLOGY.md. Sparse and played, not a cutscene: he files,
## says two sentences to nobody in particular, and leaves.
const DEPARTURE_BEATS := [
	{"at": 0.25, "text": "EXAMINER: \"Decant is stable. Rack them for the heat.\""},
	{"at": 2.05, "text": "EXAMINER: \"Debt's in the meat. CellOutz owns what it grew.\""},
	{"at": 3.70, "text": "STAFF DOOR  //  SEALED"},
]

@onready var subtitle: Label = $HUD/Subtitle
@onready var prompt: Label = $HUD/Prompt
@onready var vitals: Label = $HUD/Vitals
@onready var fade: ColorRect = $HUD/Fade
@onready var submerge_tint: ColorRect = $HUD/Submerge


func _ready() -> void:
	$WorldEnvironment.environment = WorldLook.environment("ossuary")
	# The form itself already lays a translucent blood veil over the first shot.
	# Leaving this at the old opaque value made the real examiner and laboratory
	# disappear beneath two stacked UI tints before the player could meet them.
	submerge_tint.color.a = 0.18
	# The form is the opening, not a black loading screen.  Keep just enough
	# fade to hold the red image together while the player sees the real room,
	# doctor and terminal behind it; filing may still cut into the later wake-up.
	fade.color.a = 0.08
	vat_smash = VAT_SMASH.new(self)
	_build_chamber()
	_build_examination_station()
	# The examiner is not born at the keyboard. He enters after the player wakes.
	if examiner_node != null:
		examiner_post = examiner_node.global_position
		examiner_node.visible = false
	_build_vat()
	_build_first_objects()
	_build_player()
	doctor_route = DOCTOR_ROUTE.new()
	add_child(doctor_route)
	doctor_route.build(self)
	_build_title()
	_build_intake()
	osd = BodyCamOSD.new()
	osd.name = "BodyCamOSD"
	$HUD.add_child(osd)
	osd.adopt(vitals, $HUD/Objective, prompt, "SUBLEVEL 0C  //  GROWING FLOOR")
	osd.camera = camera
	osd.visible = intake == null
	opening_audio = OPENING_AUDIO.new()
	add_child(opening_audio)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_title() -> void:
	title = Label.new()
	title.name = "Title"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("c8321e"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.visible = false
	$HUD.add_child(title)
	$HUD.move_child(title, $HUD/Subtitle.get_index())
	mission_card = MissionCard.new()
	mission_card.name = "MissionCard"
	mission_card.visible = false
	$HUD.add_child(mission_card)


## G6.1/G6.3. Character creation was built but never connected to the opening:
## a new game went straight from the front door to the glass breaking. The
## handler now owns the first beat, and filing the sheet is what starts the
## camera sequence rather than a timer running behind the form.
func _build_intake() -> void:
	if VAT_REBIRTH.is_pending():
		_begin_rebirth()
		return
	intake = VAT_INTAKE.new()
	intake.name = "Intake"
	$HUD.add_child(intake)
	intake.filed.connect(_on_intake_filed)


## Regrown, not examined. The world carried on: the tank opens straight onto
## the voiding, and whatever this body's last life opened stays open.
func _begin_rebirth() -> void:
	rebirth = true
	var player_state := WorldHistory.subject("player")
	var body_anatomy: Dictionary = player_state.get("anatomy", {})
	anatomy.call("configure", "player", 5000.0, body_anatomy.get("cybernetics", []))
	anatomy.call("apply_hit", "torso", 26.0, 0.0, "blunt")
	anatomy.call("apply_hit", "head", 14.0, 0.0, "blunt")
	var vat := VAT_REBIRTH.vat_for(VAT_REBIRTH.claimant())
	active_beats = [
		{"at": 0.4, "text": "REGROWTH COMPLETE  //  BODY %d" % int(player_state.get("body_number", 2))},
		{"at": 1.8, "text": "%s  //  YOUR OLD BODY IS WHERE YOU LEFT IT" % str(vat.label)},
		{"at": 3.2, "text": "TANK 0C-7  //  CYCLE ABORTED  //  VOIDING"},
	]
	if WorldHistory.event_count("opening_first_object_used") > 0 and stuck_tank_shell != null:
		stuck_tank_opened = true
		stuck_tank_shell.visible = false
		if stuck_tank_culture != null:
			stuck_tank_culture.visible = false
	clock = 0.0
	line_index = -1
	phase = "submerged"
	WorldHistory.record_event("opening_regrown", {"location": "growing_floor", "claimant": VAT_REBIRTH.claimant(), "body_number": int(player_state.get("body_number", 2))})


func _on_intake_filed(_state: Dictionary) -> void:
	if intake == null:
		return
	intake.queue_free()
	intake = null
	var filed_state := WorldHistory.subject("player")
	var filed_anatomy: Dictionary = filed_state.get("anatomy", {})
	anatomy.call("configure", "player", 5000.0, filed_anatomy.get("cybernetics", []))
	anatomy.call("apply_hit", "torso", 26.0, 0.0, "blunt")
	anatomy.call("apply_hit", "head", 14.0, 0.0, "blunt")
	WorldHistory.register_subject("inventory", {"kind": "inventory", "items": []})
	clock = 0.0
	line_index = -1
	# The examination ends before the escape begins. Filing used to set
	# "submerged" here, so the vat started failing while the man who filed the
	# form was still standing at his terminal watching it happen.
	departure_clock = 0.0
	departure_line = -1
	# Tests and saves can file directly; ensure departure always begins from the
	# terminal even when its arrival beat was skipped.
	if examiner_node != null:
		examiner_node.visible = true
		examiner_node.position = EXAMINER_AT_DESK
		examiner_node.rotation.y = EXAMINER_TURN
	phase = "departure"
	# AP1.3/P10.5. Filing has already written the chosen anatomy by the time this
	# signal arrives. Install the real head hardware now, while the player is
	# still captured and before the wake event, so the sheet cannot overwrite it
	# and the later X-ray discovers something that was already done to the body.
	BRAIN_INDEX.install_chip("player", "celloutz", "growing_floor_intake")
	WorldHistory.begin_ledger_batch()
	OPENING.advance("woke")
	FACILITY_TERRITORY.apply_event("opening_woke")
	WorldHistory.record_event("opening_woke", {"location": "growing_floor"})
	WorldHistory.commit_ledger_batch()


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = BODY_HALF_HEIGHT * 2.0
	collider.shape = capsule
	player.add_child(collider)
	add_child(player)
	player.position = VAT_POSITION + Vector3(0, 1.35, 0)

	camera = Camera3D.new()
	camera.fov = 88.0
	player.add_child(camera)
	LabSurface.attach_body_cam(camera)

	anatomy = ANATOMY.new()
	player.add_child(anatomy)
	anatomy.call("configure", "player", 5000.0, {})
	# Nobody comes out of a tank whole.
	anatomy.call("apply_hit", "torso", 26.0, 0.0, "blunt")
	anatomy.call("apply_hit", "head", 14.0, 0.0, "blunt")
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound",
		"elo": 1000, "grudge": 0, "status": "decanted", "wounds": ["tank scarring", "raw throat"],
		"memory": "Came out of a tank on the Growing Floor owing somebody a heat.",
	})
	for index in 4:
		var cable := _umbilical(index)
		umbilicals.append(cable)


func _umbilical(index: int) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var angle := TAU * float(index) / 4.0 + 0.4
	var anchor := VAT_POSITION + Vector3(cos(angle) * 0.62, 3.05, sin(angle) * 0.62)
	# The inner end used to stop 0.16m from an 88-degree lens, which put 5cm
	# flesh spheres across a third of the opening frame. 0.42 was not far
	# enough either -- the arithmetic is unforgiving at this FOV, where a 3.7cm
	# sphere half a metre out still lands ~100px wide. They enter low on the
	# abdomen instead, roughly 1.1m from the eye, where they read as cables
	# going into a body rather than as objects stuck to the lens.
	# Four cables 90 degrees apart means one of them always points roughly where
	# the player is looking, so they splay instead: the more forward a cable is,
	# the lower and wider it enters the body. The sightline from the tank to the
	# examiner's terminal is the one thing in this shot that must stay clear.
	var forwardness := clampf(-sin(angle), 0.0, 1.0)
	var target := VAT_POSITION + Vector3(
		cos(angle) * lerpf(0.58, 0.74, forwardness),
		lerpf(0.95, 0.52, forwardness),
		sin(angle) * lerpf(0.58, 0.74, forwardness),
	)
	# Drawn as a chain of segments so it reads as gut, not as a straight pipe.
	for segment in 7:
		var t := float(segment) / 6.0
		var point := anchor.lerp(target, t) + Vector3(sin(t * 5.0) * 0.07, 0, cos(t * 4.0) * 0.07)
		var link := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		# Tapering harder toward the body: the wide end is the one hanging from
		# the ceiling, far away, and the near end is the one entering the skin.
		mesh.radius = 0.055 - t * 0.030
		mesh.height = mesh.radius * 2.2
		mesh.material = WorldLook.surface(Color("4a3128") if segment % 2 == 0 else Color("38261f"), "flesh", index * 7 + segment)
		link.mesh = mesh
		link.position = point
		root.add_child(link)
	return root


func _build_vat() -> void:
	# The tank: a ribbed cylinder with a fluid column inside it.
	vat_glass = MeshInstance3D.new()
	var glass := CylinderMesh.new()
	glass.top_radius = 0.95
	glass.bottom_radius = 0.95
	glass.height = 3.1
	# A closed cylinder puts a glowing circular cap directly against the trapped
	# camera.  The tank needs walls and ribs, not a red balloon in the player's
	# face, so its ends are open and the ceiling/floor dressing supplies the rest.
	glass.cap_top = false
	glass.cap_bottom = false
	var glass_material := StandardMaterial3D.new()
	# You wake in bloody growth fluid, not green aquarium water. The glass is
	# smoke-brown so the red column still reads as liquid rather than a flat HUD
	# wash over the whole room.
	glass_material.albedo_color = Color(0.34, 0.11, 0.08, 0.34)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# The player is inside this cylinder. Rendering both sides of transparent
	# glass stacks two dark surfaces and turns the laboratory into a smeared
	# black-red blob, so show only the inner face from the trapped viewpoint.
	glass_material.cull_mode = BaseMaterial3D.CULL_FRONT
	glass_material.metallic = 0.4
	glass_material.roughness = 0.12
	glass.material = glass_material
	vat_glass.mesh = glass
	vat_glass.position = VAT_POSITION + Vector3(0, 1.55, 0)
	add_child(vat_glass)

	fluid = MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 0.9
	column.bottom_radius = 0.9
	column.height = 2.9
	# Open-ended for the same reason the glass around it is: a closed alpha
	# cylinder puts its near cap flat against a camera standing inside it.
	column.cap_top = false
	column.cap_bottom = false
	var fluid_material := StandardMaterial3D.new()
	fluid_material.albedo_color = Color(0.36, 0.022, 0.014, 0.48)
	fluid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Show only the far inner wall from the trapped viewpoint, exactly as
	# `glass_material` above does. Rendering both faces stacked two tints and
	# turned the laboratory into a flat smear, which is what the previous fix
	# was reacting to when it hid this volume entirely.
	fluid_material.cull_mode = BaseMaterial3D.CULL_FRONT
	fluid_material.emission_enabled = true
	fluid_material.emission = Color(0.19, 0.008, 0.004)
	fluid_material.emission_energy_multiplier = 1.45
	column.material = fluid_material
	fluid.mesh = column
	fluid.position = VAT_POSITION + Vector3(0, 1.5, 0)
	add_child(fluid)
	# Rendered again. Hiding it left the opening's red as a single flat 2D rect
	# over the whole screen, which is a colour filter rather than a liquid: the
	# far wall and the desk two metres away were tinted identically. With the
	# volume back, distance reads, and the column visibly drains during voiding.

	# Ribbed collar and base: the tank is grown onto the floor, not bolted to it.
	#
	# Nine evenly spaced rings meant three of them sat at the captive camera's
	# own height, a metre away, where a torus seen from inside its own hole
	# reads as an unidentifiable tan mass sweeping across a third of the frame
	# rather than as a rib. Greg's brief: "remove repeated green rings ...
	# floating ribs". They are a collar and a base now, with the eye's band
	# left clear, and they sit tight against the glass instead of hovering
	# 11cm off it.
	# Greg, first launch (2026-09-24): no more stacked rings. A plate-steel
	# base band and crown band, the same hardware as every LabVat.
	_vat_bands(self, VAT_POSITION, 1.02, 3.1)

	# High in the column, not at eye level. An omni light sitting on the
	# cylinder's own axis at the camera's exact height lights the inner wall
	# brightest at that height and nowhere else, which drew a hard bright band
	# straight across the middle of the opening frame, all the way around the
	# player. Raised to the top of the fluid, it reads as light coming down
	# through the medium, which is what it was always meant to be.
	# Greg, playing it: *"There's no vat. I'm still allowed out of the damn
	# vat."* From inside, front-culled glass and front-culled medium are a red
	# haze -- correct for seeing through, useless for knowing you are shut in.
	# Six vertical struts at the glass line fix that: they frame the view like
	# the inside of a cage, they read at every camera angle, and unlike the
	# rings they never cross the middle of the frame. They are also what stays
	# standing after the glass goes, so the breach has something to have broken.
	for strut in 6:
		# Phased so the player's forward view falls exactly in the gap between
		# two struts. At the old 0.32 offset one of them stood 0.2 radians off
		# dead-ahead, straight down the sightline to the examiner's terminal:
		# the bars are meant to frame that view, not block it.
		var angle := TAU * float(strut) / 6.0
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(0.075, 3.05, 0.075)
		bar_mesh.material = WorldLook.surface(Color("3a2e20") if strut % 2 == 0 else Color("2b2118"), "bone", 950 + strut)
		bar.mesh = bar_mesh
		bar.position = VAT_POSITION + Vector3(cos(angle) * 0.97, 1.55, sin(angle) * 0.97)
		vat_struts.append(bar)
		add_child(bar)

	var glow := OmniLight3D.new()
	glow.position = VAT_POSITION + Vector3(0, 2.85, 0)
	glow.light_color = Color("b22a19")
	glow.light_energy = 3.4
	glow.omni_range = 6.0
	add_child(glow)


## AX3.1/AX3.2. One dedicated failure-tank, off the repeating decorative row
## `_build_chamber()` draws, so opening it cannot collide with that loop's own
## geometry or bay bookkeeping. Close enough to the vat that it is the first
## thing worth walking to once the player can move at all.
func _build_first_objects() -> void:
	var at := Vector3(-3.4, 0.0, 2.6)
	stuck_tank_marker = Node3D.new()
	stuck_tank_marker.name = "FirstObjectTank"
	stuck_tank_marker.position = at
	add_child(stuck_tank_marker)

	stuck_tank_shell = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 0.8
	cylinder.height = 2.8
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = Color(0.31, 0.055, 0.035, 0.42)
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell_material.roughness = 0.5
	cylinder.material = shell_material
	stuck_tank_shell.mesh = cylinder
	stuck_tank_shell.position = Vector3(0, 1.4, 0)
	stuck_tank_marker.add_child(stuck_tank_shell)

	# The first tank is not a special low-detail prop.  Its body comes from the
	# same rig as people encountered above ground, so opening it teaches the
	# player what a wounded world body actually looks like.
	failed_subject_visual = _build_cradled_vat_subject(Vector3.ZERO, 2, stuck_tank_marker)
	stuck_tank_culture = MeshInstance3D.new()
	var stuck_column := CylinderMesh.new()
	stuck_column.top_radius = 0.74
	stuck_column.bottom_radius = 0.74
	stuck_column.height = 2.58
	var stuck_culture_material := StandardMaterial3D.new()
	stuck_culture_material.albedo_color = Color(0.38, 0.018, 0.011, 0.31)
	stuck_culture_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stuck_culture_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	stuck_culture_material.emission_enabled = true
	stuck_culture_material.emission = Color(0.16, 0.004, 0.002)
	stuck_column.material = stuck_culture_material
	stuck_tank_culture.mesh = stuck_column
	stuck_tank_culture.position = Vector3(0, 1.38, 0)
	stuck_tank_marker.add_child(stuck_tank_culture)

	_vat_bands(stuck_tank_marker, Vector3.ZERO, 0.86, 2.8)

	# AX3.2. Registered now so the subject exists to strip clothing off of the
	# moment the tank opens — non-destructive on repeat `_ready()` calls
	# (`WorldHistory.register_subject` only fills in missing keys), so a
	# resumed save cannot re-dress a subject the player already looted.
	WorldHistory.register_subject(FAILED_SUBJECT_ID, {
		"name": "SUBJECT 0C-4", "kind": "person", "status": "dead",
		"memory": "Failed the same cycle you walked out of.",
		"worn_layer": "humiliation_smock", "worn_condition": 1.0,
	})


func _build_chamber() -> void:
	# Grated floor and a low wet ceiling.
	_slab(Vector3(16.0, 0.4, AISLE_LENGTH + 8.0), Vector3(0, -0.2, -AISLE_LENGTH * 0.4), "dirt", Color("15120f"))
	_slab(Vector3(16.0, 0.35, AISLE_LENGTH + 8.0), Vector3(0, 4.3, -AISLE_LENGTH * 0.4), "rust", Color("100d0b"))
	_slab(Vector3(0.5, 4.4, AISLE_LENGTH + 8.0), Vector3(-7.6, 2.2, -AISLE_LENGTH * 0.4), "rust", Color("1c1712"))
	_slab(Vector3(0.5, 4.4, AISLE_LENGTH + 8.0), Vector3(7.6, 2.2, -AISLE_LENGTH * 0.4), "rust", Color("1c1712"))
	# The near wall is DoctorRoute's: the same wall in pieces, around his door
	# and the observation glass.
	# Greg, playing the build: "you walk to the end of this room and then
	# there's just a skybox... I just fell out of the skybox."
	#
	# He was right and the geometry says why. The floor runs to z = -34.6 and
	# the side walls run its full length, but the far end was capped only by
	# the door slab on line ~255 — which is 3.4 units wide in a 16-unit
	# corridor. Anywhere outside x +/-1.7 there was simply nothing there, so
	# walking past the door on either side took you off the edge of the world.
	# The near end had had a wall this whole time; the far end never did.
	#
	# The door is opened by proximity in `_interact()`, not by walking through
	# it, so capping the end solid costs nothing and the exit still works.
	_slab(Vector3(16.0, 4.4, 0.5), Vector3(0, 2.2, -AISLE_LENGTH - 0.4), "rust", Color("19140f"))

	# Vertebral arches down the aisle. Repetition is the whole effect.
	# Bay count derived from AISLE_LENGTH (spacing 3.1, same 3.0-unit clearance
	# before the door as the original 11-bay/34.0 layout) so shortening the
	# aisle cannot leave dressing poking past the end wall or the door.
	var bay_count := roundi((AISLE_LENGTH - 3.0) / 3.1) + 1
	var bay_zs: Array = []
	var tank_centres: Array = []
	for bay in bay_count:
		var z := 2.0 - float(bay) * 3.1
		for side in [-1.0, 1.0]:
			# The arches stand at x = 6.9, which is exactly where the examiner's
			# staff door is set into the right-hand wall -- one of them stood
			# squarely in front of it and the seal happened behind a rib. The
			# doorway gets its bay to itself; repetition can spare one.
			if side > 0.0 and absf(z - STAFF_DOOR_AT.z) < 1.8:
				continue
			for vertebra in 5:
				var t := float(vertebra) / 4.0
				var arch := MeshInstance3D.new()
				var bone := CapsuleMesh.new()
				bone.radius = 0.17 - t * 0.05
				bone.height = 0.55
				bone.material = WorldLook.surface(Color("39301f").lerp(Color("241d14"), t), "bone", bay * 5 + vertebra)
				arch.mesh = bone
				arch.position = Vector3(side * (6.9 - t * 1.5), 0.5 + t * 3.3, z)
				arch.rotation_degrees = Vector3(0, 0, side * (8.0 + t * 46.0))
				add_child(arch)

		bay_zs.append(z)
		# Other tanks, most of them failed.
		if bay > 0:
			for side in [-1.0, 1.0]:
				_dead_tank(Vector3(side * 4.4, 0, z), bay)
				tank_centres.append(Vector3(side * 4.4, 0, z))

		var strip := OmniLight3D.new()
		strip.position = Vector3(0, 3.8, z)
		strip.light_color = Color("7fbf95") if bay % 3 else Color("c0703a")
		strip.light_energy = 1.5
		strip.omni_range = 6.5
		add_child(strip)

	# Greg: "intricate Lain / Evangelion wiring, not one long tube". The
	# conduit that ran the length of each side is now bundles of cable, hung
	# from every bay, dropping into every tank and swagged across overhead.
	cable_report = LAB_CABLES.wire(self, bay_zs, tank_centres, 4.12, 7.35, 4417, [STAFF_DOOR_AT])

	# The pit door at the far end.
	door_marker = Node3D.new()
	door_marker.position = Vector3(0, 0, -AISLE_LENGTH + 2.0)
	add_child(door_marker)
	_slab(Vector3(3.4, 3.4, 0.3), Vector3(0, 1.7, -AISLE_LENGTH + 1.6), "rust", Color("3d2a19"))
	# A door you can read (Greg, 2026-09-24: "just supposed to walk through
	# this big white light?"): plate panel, a frame, and a lit sign.
	var panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(2.2, 2.9, 0.08)
	panel_mesh.material = LabSurface.material("plate")
	panel.mesh = panel_mesh
	panel.position = Vector3(0, 1.45, -AISLE_LENGTH + 1.8)
	add_child(panel)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.18, 3.2, 0.24)
		post_mesh.material = LabSurface.material("grime")
		post.mesh = post_mesh
		post.position = Vector3(side * 1.2, 1.6, -AISLE_LENGTH + 1.85)
		add_child(post)
	var sign := Label3D.new()
	sign.text = "SERVICE ARCADE  //  STAFF ONLY\nPIT ACCESS BELOW"
	sign.font_size = 42
	sign.outline_size = 8
	sign.modulate = Color("ff9a4a")
	sign.position = Vector3(0, 3.35, -AISLE_LENGTH + 1.9)
	add_child(sign)
	var exit_glow := OmniLight3D.new()
	exit_glow.position = Vector3(0, 1.2, -AISLE_LENGTH + 2.6)
	exit_glow.light_color = Color("ff8f3c")
	exit_glow.light_energy = 5.5
	exit_glow.omni_range = 8.0
	add_child(exit_glow)


## The first thing the player sees through the blood and curved glass is not a
## UI mascot.  It is the one anonymous examiner at a real workstation.  The
## screen is deliberately close enough to read as a screen full of code before
## the character form occupies the right-hand side of the view.
func _build_examination_station() -> void:
	var station := Node3D.new()
	station.name = "UnknownExaminerStation"
	station.position = STATION_AT
	station.rotation.y = STATION_YAW
	add_child(station)

	# A low medical desk between the vat and the doctor.
	var desk := MeshInstance3D.new()
	var desk_mesh := BoxMesh.new()
	desk_mesh.size = Vector3(2.25, 0.07, 0.78)
	desk_mesh.material = LabSurface.material("plate")
	desk.mesh = desk_mesh
	desk.position = Vector3(0.05, 0.86, 0.25)
	station.add_child(desk)
	# Greg, first launch (2026-09-24): "this floating table". It stands now.
	for corner in [Vector2(-1.0, -0.33), Vector2(1.1, -0.33), Vector2(-1.0, 0.6), Vector2(1.1, 0.6)]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.06, 0.84, 0.06)
		leg_mesh.material = LabSurface.material("grime")
		leg.mesh = leg_mesh
		leg.position = Vector3(corner.x, 0.42, corner.y)
		station.add_child(leg)

	# The physical monitor gives the player a point of attention in the room;
	# its green code strips are geometry, not a flat title card.
	var monitor := MeshInstance3D.new()
	var monitor_mesh := BoxMesh.new()
	monitor_mesh.size = Vector3(1.10, 0.76, 0.16)
	monitor_mesh.material = LabSurface.material("plate")
	monitor.mesh = monitor_mesh
	# The screen takes the right half of the desk, the examiner the left, and
	# the keyboard sits between them under his hand. He used to stand 1.7m off
	# to the side, which read as a man near a computer he had nothing to do
	# with; the two now occupy one workstation without overlapping at all.
	monitor.position = Vector3(0.60, 1.50, 0.28)
	station.add_child(monitor)
	var screen := MeshInstance3D.new()
	var screen_mesh := QuadMesh.new()
	screen_mesh.size = Vector2(0.96, 0.62)
	var screen_material := StandardMaterial3D.new()
	screen_material.albedo_color = Color("07120c")
	screen_material.emission_enabled = true
	screen_material.emission = Color("0d2a1a")
	screen_mesh.material = screen_material
	screen.mesh = screen_mesh
	screen.position = Vector3(0.60, 1.50, 0.365)
	screen.rotation_degrees.y = 180.0
	station.add_child(screen)
	var stand := MeshInstance3D.new()
	var stand_mesh := BoxMesh.new()
	stand_mesh.size = Vector3(0.10, 0.30, 0.10)
	stand_mesh.material = LabSurface.material("grime")
	stand.mesh = stand_mesh
	stand.position = Vector3(0.60, 1.03, 0.22)
	station.add_child(stand)
	for line_index in 9:
		var code := MeshInstance3D.new()
		var code_mesh := BoxMesh.new()
		var code_width := 0.22 + float((line_index * 37) % 52) * 0.011
		code_mesh.size = Vector3(code_width, 0.025, 0.018)
		var code_material := StandardMaterial3D.new()
		code_material.albedo_color = Color("86b56c") if line_index % 3 else Color("bd6c43")
		code_material.emission_enabled = true
		code_material.emission = code_material.albedo_color * 0.75
		code_mesh.material = code_material
		code.mesh = code_mesh
		# The text sits on the monitor's camera-facing surface, aligned inside its
		# frame rather than accidentally hovering behind it.
		code.position = Vector3(0.20 + code_width * 0.5, 1.72 - float(line_index) * 0.055, 0.375)
		station.add_child(code)
	var keyboard := MeshInstance3D.new()
	var keyboard_mesh := BoxMesh.new()
	keyboard_mesh.size = Vector3(0.86, 0.045, 0.38)
	keyboard_mesh.material = LabSurface.material("plate")
	keyboard.mesh = keyboard_mesh
	# At his end of the desk, where his hands actually are.
	keyboard.position = Vector3(-0.62, 0.915, 0.32)
	keyboard.rotation.y = 0.35
	station.add_child(keyboard)

	# One examiner, anonymous and physically present.  He is shaped from the
	# same primitive grammar as the rest of this prototype so an authored model
	# can replace these nodes without changing the opening choreography.
	var examiner := Node3D.new()
	examiner.name = "UnknownExaminer"
	# Standing at the left of his own desk, one metre closer in than before, so
	# the man and the terminal read as one workstation. His head spans roughly
	# x -0.36..0.04 and the monitor starts at 0.07: adjacent, never overlapping.
	# Greg, 21 September: "more to the left of the lap and not directly in
	# front of it."
	examiner.position = EXAMINER_AT_DESK
	examiner.rotation.y = EXAMINER_TURN
	station.add_child(examiner)
	examiner_node = examiner
	# The same man the intake's live feed shows (ExaminerFeed): a BaselineHuman
	# in the same build, turned half round because its face is built on -Z and
	# this node's "working" facing is +Z.
	var body := BASELINE_HUMAN.new()
	body.name = "ExaminerBody"
	body.rotation.y = PI
	examiner.add_child(body)
	body.build("intake_examiner", BASELINE_HUMAN.config_from_subject({"race": "decanted"}).merged({"gore": false}, true))
	var look := HUNTER_APPEARANCE.new()
	body.add_child(look)
	look.configure(body, {"axes": {"brow": 0.7, "jaw": 0.6, "cheek": 0.2, "eyes": 0.3, "nose": 0.55, "mouth": 0.4}})
	var screen_light := OmniLight3D.new()
	screen_light.position = Vector3(0.52, 1.6, 0.02)
	screen_light.light_color = Color("8bbd79")
	screen_light.light_energy = 4.4
	screen_light.omni_range = 3.4
	station.add_child(screen_light)
	var examination_light := OmniLight3D.new()
	examination_light.name = "ExaminationLight"
	examination_light.position = Vector3(-0.28, 2.75, 0.34)
	examination_light.light_color = Color("d49162")
	examination_light.light_energy = 3.0
	examination_light.omni_range = 5.2
	station.add_child(examination_light)
	_build_staff_door()
	_hang_cameras()


## "Cameras everywhere" (Greg, 2026-09-24), and the consent notice says the
## examination is recorded: four wall cameras, each turned on the vat, with a
## red tally light.
func _hang_cameras() -> void:
	for mount in [Vector3(-7.2, 3.7, 2.8), Vector3(7.2, 3.7, 2.8), Vector3(-7.2, 3.7, -6.5), Vector3(7.2, 3.7, -6.5)]:
		var rig := Node3D.new()
		rig.name = "Cctv"
		add_child(rig)
		rig.position = mount
		rig.look_at_from_position(mount, VAT_POSITION + Vector3(0, 1.4, 0), Vector3.UP)
		var housing := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.2, 0.46)
		box.material = LabSurface.material("grime")
		housing.mesh = box
		rig.add_child(housing)
		var lens := MeshInstance3D.new()
		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.06
		lens_mesh.bottom_radius = 0.07
		lens_mesh.height = 0.08
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color("0a0c0d")
		glass.metallic = 0.6
		glass.roughness = 0.1
		lens_mesh.material = glass
		lens.mesh = lens_mesh
		lens.rotation_degrees.x = 90.0
		lens.position = Vector3(0, 0, -0.26)
		rig.add_child(lens)
		var tally := OmniLight3D.new()
		tally.light_color = Color("ff2a1a")
		tally.light_energy = 0.6
		tally.omni_range = 0.6
		tally.position = Vector3(0.08, 0.08, -0.22)
		rig.add_child(tally)


## The door he leaves by. A lit frame in the right-hand wall with a panel that
## slides shut behind him, so the examination visibly ends before the escape
## begins. The player never opens this one -- their way out is the pit door at
## the far end of the aisle, and this closing is the cue that they are alone.
func _build_staff_door() -> void:
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.18, 2.55, 1.55)
	frame_mesh.material = WorldLook.surface(Color("2b211a"), "rust", 930)
	frame.mesh = frame_mesh
	frame.position = STAFF_DOOR_AT + Vector3(0.42, 1.28, 0)
	add_child(frame)

	var jamb_light := OmniLight3D.new()
	jamb_light.position = STAFF_DOOR_AT + Vector3(-0.15, 2.25, 0)
	jamb_light.light_color = Color("e8d09a")
	jamb_light.light_energy = 4.6
	jamb_light.omni_range = 4.4
	add_child(jamb_light)
	# The doorway has to read from inside the tank, across the room and through
	# the medium, or "he leaves and it shuts" is a subtitle rather than a beat.
	# A lit lintel strip does that without lighting the whole right-hand wall.
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(0.06, 0.07, 1.45)
	var lintel_material := StandardMaterial3D.new()
	lintel_material.albedo_color = Color("e8d09a")
	lintel_material.emission_enabled = true
	lintel_material.emission = Color("e8d09a")
	lintel_material.emission_energy_multiplier = 2.6
	lintel_mesh.material = lintel_material
	lintel.mesh = lintel_mesh
	lintel.position = STAFF_DOOR_AT + Vector3(0.30, 2.46, 0)
	add_child(lintel)

	staff_door_panel = Node3D.new()
	staff_door_panel.name = "StaffDoorPanel"
	# Parked clear of the opening. `_update_sequence`'s departure beat slides it
	# back across once he is through.
	# Shut: since 24 September he comes and goes by his own door behind the vat.
	staff_door_panel.position = STAFF_DOOR_AT + Vector3(0.30, 0.0, 0.0)
	add_child(staff_door_panel)
	var panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.12, 2.35, 1.42)
	panel_mesh.material = WorldLook.surface(Color("3a2c1e"), "metal", 931)
	panel.mesh = panel_mesh
	panel.position = Vector3(0, 1.18, 0)
	staff_door_panel.add_child(panel)


## Open steel bands at a vat's foot and crown. Open-ended so the view from
## inside the tank is through them, not into a lid.
func _vat_bands(parent: Node3D, at: Vector3, radius: float, glass_top: float) -> void:
	var plate := LabSurface.material("plate")
	for band in [[0.2, 0.4], [glass_top - 0.1, 0.36]]:
		var node := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = radius
		tube.bottom_radius = radius
		tube.height = band[1]
		tube.cap_top = false
		tube.cap_bottom = false
		tube.radial_segments = 28
		var material := plate.duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		tube.material = material
		node.mesh = tube
		node.position = at + Vector3(0, band[0], 0)
		parent.add_child(node)


func _dead_tank(at: Vector3, seed_value: int) -> void:
	# LabVat is the hardware (Greg, 2026-09-24: no more ringed cylinders with
	# capsules in them). The nearest three keep their seated adults -- one is
	# still alive and one has visibly failed -- and the rest hold curled bodies.
	var near := seed_value <= 2
	var root := LabVat.build(self, at, seed_value, 2.4, 0.8, not near, seed_value <= 5)
	var cradled: Node3D = null
	if near:
		cradled = _build_cradled_vat_subject(at + Vector3(0, 0.42, 0), seed_value)
	if vat_smash != null:
		vat_smash.register(root, at, seed_value, cradled)


## The Growing Floor's keys, for the pause menu's KEYS page.
func keys_groups() -> Array:
	return [
		{"group": "IN THE TANK", "rows": [["1 2 3", "BLINK ONCE / TWICE / STARE"], ["V", "THINK OUT LOUD"], ["LEFT / RIGHT", "INTAKE TABS"], ["UP / DOWN", "ROWS"], ["ENTER / CLICK", "CONFIRM"], ["F", "FILE THE SHEET"]]},
		{"group": "THE WIRES", "rows": [["MOUSE", "FIND A WIRE"], ["E", "RIP IT OUT (THREE TUGS)"]]},
		{"group": "OUT OF THE TANK", "rows": [["WASD", "MOVE"], ["MOUSE", "LOOK"], ["E", "INTERACT"], ["HOLD I", "INSPECT WHAT YOU HOLD"], ["LMB", "SMASH A TANK / STRIKE HIS DOOR"], ["F", "SHOULDER HIS DOOR"], ["ESC", "PAUSE"]]},
	]


## A freed subject that turned on you hits the body you just got back.
func _on_freed_subject_struck(damage: float) -> void:
	if anatomy != null:
		anatomy.call("apply_hit", "torso", damage, 0.0, "blunt")
	breach_shake = maxf(breach_shake, 0.2)


## A seated BaselineHuman makes the first visible other subjects recognisably
## part of the same world as the player: hands, face, feet, clothing and a
## body which could be wounded later.  Their frozen pose costs no AI, physics
## thinking, or animation work while they remain background specimens.
func _build_cradled_vat_subject(at: Vector3, seed_value: int, parent_node: Node3D = null) -> Node3D:
	var identity := "vat_subject_%d_%d" % [seed_value, int(absf(at.x) * 10.0)]
	var rig = BASELINE_HUMAN.new()
	rig.name = "CradledSubject_%d" % seed_value
	rig.position = at + Vector3(0.0, 0.34, 0.0)
	rig.rotation_degrees = Vector3(0.0, 180.0 if at.x < 0.0 else 0.0, -10.0 if seed_value == 1 else 13.0)
	rig.scale = Vector3.ONE * 0.92
	var host: Node3D = self if parent_node == null else parent_node
	host.add_child(rig)
	rig.build(identity, {
		"gore": false,
		"seated": true,
		"flesh": Color("6a4a43") if seed_value == 1 else Color("4d3833"),
		"variation": 4 + seed_value * 5 + int(absf(at.x)),
		"build": 0.92 + float(seed_value) * 0.04,
	})
	HUNTER_APPEARANCE.style_world_rig(rig, identity, false)
	# Fold the seated pose inward around the tank's centre instead of presenting
	# two relaxed mannequins.  One is still alive; the other is visibly failed.
	for side in [-1.0, 1.0]:
		var arm := rig.parts.get("left_arm" if side < 0.0 else "right_arm") as Node3D
		if arm != null:
			arm.rotation_degrees.z += side * 54.0
			arm.rotation_degrees.x += 24.0
	for leg_id in ["left_leg", "right_leg"]:
		var leg := rig.parts.get(leg_id) as Node3D
		if leg != null:
			leg.rotation_degrees.x -= 38.0
	if seed_value == 2:
		rig.behead()
	return rig


func _slab(dimensions: Vector3, at: Vector3, _kind: String, _color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	# Real lab surfaces (Greg, 2026-09-24), chosen by the slab's shape.
	box.material = LabSurface.for_slab(dimensions, at)
	mesh_instance.mesh = box
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)


func _unhandled_input(event: InputEvent) -> void:
	if intake != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Post creation, any other tank you are looking at up close can be
	# smashed open: the glass, the medium, and whoever is inside.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and breakout_complete and can_move and vat_smash != null:
		var tank: int = vat_smash.aimed(camera)
		if tank >= 0:
			vat_smash.strike(tank, doctor_route.held_weapon() if doctor_route != null else "")
			return
	if doctor_route != null and doctor_route.handle_input(event):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if phase == "wired":
			_tug_wire(_aimed_wire())
		else:
			_interact()
	# AX3.1/AX3.6. The same HOLD-I verb the rest of the game already teaches
	# with (see `bone_yard_hunt.gd`'s keys card), introduced here for the
	# first time by doing rather than by that card, since the card belongs to
	# a scene this run has not reached yet.
	if event is InputEventKey and not event.echo and event.keycode == KEY_I:
		inspect_held = event.pressed
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and phase != "submerged":
		yaw -= LOOK.dx(event.relative) * 0.0026
		pitch = clampf(pitch - LOOK.dy(event.relative) * 0.0024, -1.2, 1.0)


func _physics_process(delta: float) -> void:
	if phase == "intake":
		if opening_audio != null:
			opening_audio.set_phase("intake")
		_update_arrival(delta)
		return
	# Departure runs on its own clock so the vat's beat table keeps the timings
	# it was tuned with instead of every entry needing a +4.4 offset.
	if phase == "departure":
		_update_departure(delta)
		_update_hud()
		return
	# The tank's clock stops while you hang in the wires. Nothing moves on
	# until the player does it themselves.
	if phase == "wired":
		wired_clock += delta
		_update_wired(delta)
		_update_shards(delta)
		_update_hud()
		return
	clock += delta
	_update_beats()
	_update_sequence(delta)
	_update_shards(delta)
	if vat_smash != null:
		vat_smash.step(delta)
	if can_move:
		_update_movement(delta)
	# Applied last, on top of whatever the sequence or the movement code just
	# set, so the breach is felt through both the scripted stand-up and the
	# first steps rather than being overwritten by either.
	if breach_shake > 0.0:
		breach_shake = maxf(0.0, breach_shake - delta)
		var force := breach_shake * breach_shake * 0.16
		camera.rotation.x += sin(clock * 47.0) * force
		camera.rotation.y += sin(clock * 38.0) * force
		camera.rotation.z += sin(clock * 53.0) * force * 1.4
	_update_hud()

## From his door behind the vat, round the tank's right side, to his terminal
## (`inbound`), or the reverse. `t` is 0..1 along the whole walk.
func _examiner_path(t: float, inbound: bool) -> Vector3:
	var door: Vector3 = DoctorRoute.DOOR_AT
	# From the end of his desk, round its near corner, past the tank on its
	# right and out through his door behind it.
	var points: Array[Vector3] = [
		examiner_post,
		Vector3(1.25, examiner_post.y, -1.8),
		Vector3(1.55, examiner_post.y, 0.2),
		Vector3(door.x, examiner_post.y, door.z - 0.6),
		Vector3(door.x, examiner_post.y, door.z + 0.9),
	]
	if inbound:
		points.reverse()
	var total := 0.0
	for index in points.size() - 1:
		total += points[index].distance_to(points[index + 1])
	var along := clampf(t, 0.0, 1.0) * total
	for index in points.size() - 1:
		var leg := points[index].distance_to(points[index + 1])
		if along <= leg or index == points.size() - 2:
			return points[index].lerp(points[index + 1], clampf(along / maxf(leg, 0.001), 0.0, 1.0))
		along -= leg
	return points[-1]


## The intake does not begin as a menu. You wake, the examiner enters, looks
## through the glass, and only then wakes the terminal that engages the chip.
func _update_arrival(delta: float) -> void:
	arrival_clock += delta
	if examiner_node == null or not is_instance_valid(examiner_node):
		return
	if arrival_clock >= 0.35:
		examiner_node.visible = true
	var walk := clampf((arrival_clock - 0.35) / 2.15, 0.0, 1.0)
	# Greg, 24 September: he comes and goes by the door behind the vat -- the
	# one the player will break down to follow him.
	examiner_node.global_position = _examiner_path(ease(walk, 0.78), true)
	if doctor_route != null and doctor_route.door != null:
		doctor_route.door.set_ajar(1.0 - clampf((walk - 0.08) / 0.14, 0.0, 1.0) if arrival_clock >= 0.2 else 0.0)
	# He first faces the tank, then turns into his own terminal. The object of
	# attention changes before the UI arrives, which makes the intake a result
	# of something he physically did in the room.
	var turn := clampf((arrival_clock - 2.55) / 0.85, 0.0, 1.0)
	examiner_node.rotation.y = lerpf(PI, EXAMINER_TURN, ease(turn, 0.55))
	if arrival_clock >= 0.70 and arrival_clock < 2.45:
		subtitle.text = "EXAMINER // SUBJECT CONSCIOUS"
	elif arrival_clock >= 3.15 and arrival_clock < 5.5:
		subtitle.text = "NEURALACE TERMINAL // LINK ESTABLISHING"
	else:
		subtitle.text = ""


## He turns away, walks out of his own door, and the door shuts. The player is
## still in the tank for all of it and still cannot act -- that is the point of
## the beat. Only when the panel is closed does `phase` hand over to the vat.
func _update_departure(delta: float) -> void:
	departure_clock += delta
	if opening_audio != null:
		opening_audio.set_phase("intake")
	for index in DEPARTURE_BEATS.size():
		if departure_clock >= float(DEPARTURE_BEATS[index].at) and index > departure_line:
			departure_line = index
			subtitle.text = str(DEPARTURE_BEATS[index].text)

	# He straightens, turns to the door, then walks. Station-local x, because
	# the examiner hangs off the workstation node rather than off the chamber.
	if examiner_node != null and is_instance_valid(examiner_node):
		var turn := clampf(departure_clock / 0.50, 0.0, 1.0)
		examiner_node.rotation.y = lerpf(EXAMINER_TURN, EXAMINER_TURN - PI * 0.5, ease(turn, 0.6))
		var walk := clampf((departure_clock - 0.50) / 2.45, 0.0, 1.0)
		examiner_node.global_position = _examiner_path(ease(walk, 0.85), false)
		var heading := _examiner_path(minf(1.0, ease(walk, 0.85) + 0.05), false) - examiner_node.global_position
		if walk > 0.02 and heading.length() > 0.001:
			examiner_node.global_rotation.y = atan2(-heading.x, -heading.z)
		# His door swings for him and shuts behind him.
		if doctor_route != null and doctor_route.door != null:
			doctor_route.door.set_ajar(clampf((walk - 0.72) / 0.12, 0.0, 1.0) - clampf((departure_clock - 3.1) / 0.5, 0.0, 1.0))
		if walk >= 0.97 and not examiner_door_heard:
			examiner_door_heard = true
			if opening_audio != null:
				opening_audio.cue("door")
		# Through the doorway and out of the room, rather than standing in it
		# while the panel closes across him.
		if walk >= 1.0:
			examiner_node.visible = false

	# You are still tied into the tank, so you cannot look away from it, but the
	# head does turn to watch the one person in the room leave.
	if camera != null and examiner_node != null and is_instance_valid(examiner_node):
		var to_him := examiner_node.global_position - camera.global_position
		# Clamped to a head-turn. Tracking him all the way to the door meant a
		# ninety-degree swivel that put the nearest vertebral arch across the
		# whole frame -- and a body suspended in a tank with a tube in its mouth
		# does not swivel anyway. He walks out of the edge of your vision.
		var want_yaw := clampf(atan2(-to_him.x, -to_him.z), -0.95, 0.95)
		var hold := clampf((departure_clock - 3.80) / 0.60, 0.0, 1.0)
		camera.rotation.y = lerp_angle(camera.rotation.y, lerpf(want_yaw, 0.0, hold), clampf(delta * 3.4, 0.0, 1.0))
		camera.rotation.x = -0.1 + sin(departure_clock * 0.7) * 0.03

	if departure_clock >= DEPARTURE_SECONDS:
		phase = "submerged"
		clock = 0.0
		line_index = -1
		subtitle.text = ""
		WorldHistory.record_event("opening_examiner_departed", {"location": "growing_floor"})


func _update_beats() -> void:
	for index in active_beats.size():
		if clock >= float(active_beats[index].at) and index > line_index:
			line_index = index
			subtitle.text = str(active_beats[index].text)


func _update_sequence(_delta: float) -> void:
	match phase:
		"submerged":
			# Suspended, drifting, breathing something thicker than air.
			var t := clampf(clock / 3.2, 0.0, 1.0)
			# This used to ramp from fully black, because "submerged" was what
			# filing cut to and the fade covered that cut. The examiner's
			# departure runs between them now, so the player has been watching
			# this room without interruption -- and blacking out on entry put a
			# full-screen fade over the exact frame where his door seals.
			fade.color.a = 0.08
			submerge_tint.color.a = 0.26
			camera.rotation = Vector3(sin(clock * 0.7) * 0.09 - 0.1, sin(clock * 0.4) * 0.16, cos(clock * 0.55) * 0.07)
			camera.fov = 92.0 + sin(clock * 1.6) * 3.5
			player.position.y = 1.35 + sin(clock * 0.8) * 0.06
			opening_audio.set_phase("submerged", t)
			if clock >= 3.2:
				phase = "voiding"
				opening_audio.cue("drain")
		"voiding":
			# The column drops. You come down with it.
			var t := clampf((clock - 3.2) / 2.4, 0.0, 1.0)
			var height := lerpf(2.9, 0.25, ease(t, 0.7))
			fluid.mesh.height = height
			fluid.position.y = height * 0.5
			submerge_tint.color.a = lerpf(0.26, 0.0, t)
			camera.fov = lerpf(92.0, 78.0, t)
			player.position.y = lerpf(1.35, 0.95, ease(t, 0.6))
			camera.rotation = Vector3(sin(clock * 0.9) * 0.06 * (1.0 - t) - 0.1 * (1.0 - t), sin(clock * 0.5) * 0.1 * (1.0 - t), 0)
			opening_audio.set_phase("voiding", t)
			if clock >= DRAINED_AT:
				_begin_wired()
		"floor":
			# On hands and knees on the grating.
			var t := clampf((clock - 5.6) / 3.2, 0.0, 1.0)
			# Keep the capsule grounded while the eye rises from hands and knees.
			# Raising the capsule to eye height made gravity undo the stand-up
			# as soon as movement began, leaving the eye at waist height.
			player.position.y = BODY_HALF_HEIGHT
			camera.position.y = lerpf(0.62, EYE_HEIGHT, ease(t, 0.45)) - BODY_HALF_HEIGHT
			camera.rotation = Vector3(lerpf(-0.95, 0.0, ease(t, 0.5)), 0, lerpf(0.22, 0.0, ease(t, 0.5)))
			camera.fov = lerpf(78.0, 74.0, t) + sin(clock * 2.4) * (1.0 - t) * 4.0
			if title.visible:
				title.modulate.a = clampf(1.0 - t * 2.5, 0.0, 1.0)
				title.visible = title.modulate.a > 0.0
			if t >= 1.0:
				phase = "aisle"
				can_move = true
				subtitle.text = ""
				yaw = 0.0
				pitch = 0.0


## The drain leaves the body hanging in an empty tank with the wires still in
## it. Ending that is the first thing the player chooses to do.
func _begin_wired() -> void:
	phase = "wired"
	clock = DRAINED_AT
	wired_clock = 0.0
	revenge_at = -1.0
	yaw = 0.0
	# The umbilicals enter low on the abdomen; the head is already bowed to them.
	pitch = -0.55
	player.position.y = 0.95
	title.text = "END ALL SUFFERING"
	title.modulate.a = 1.0
	title.visible = true
	mission_card.play("end_all_suffering", "END ALL SUFFERING", END_CARD_SECONDS)
	subtitle.text = "The wires are still in you."
	opening_audio.set_phase("wired")
	WorldHistory.record_event("opening_wired", {"tank": "0C-7"})


func _update_wired(delta: float) -> void:
	jolt = maxf(0.0, jolt - delta * 3.0)
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, sin(wired_clock * 41.0) * 0.06 * jolt)
	camera.fov = 80.0 + jolt * 6.0
	player.position.y = 0.95 + sin(wired_clock * 1.3) * 0.02
	if revenge_at < 0.0:
		# It flickers like a readout that has been saying this for years.
		title.modulate.a = 0.55 + 0.45 * absf(sin(wired_clock * 2.2 + sin(wired_clock * 13.0) * 0.4))
		return
	title.modulate.a = 1.0
	if wired_clock - revenge_at >= REVENGE_HOLD:
		_breach()


## The wire nearest the centre of view, or null when none is being looked at.
func _aimed_wire() -> Node3D:
	var forward := -camera.global_transform.basis.z
	var best: Node3D = null
	var best_dot := 0.94
	for cable in umbilicals:
		for link in cable.get_children():
			var to_link := ((link as Node3D).global_position - camera.global_position).normalized()
			var dot := forward.dot(to_link)
			if dot > best_dot:
				best_dot = dot
				best = cable
	return best


func _tug_wire(cable: Node3D) -> void:
	if phase != "wired" or revenge_at >= 0.0 or cable == null or not umbilicals.has(cable):
		return
	# Reaching for a wire cuts the card short: the player acting beats the
	# screen telling them to.
	if mission_card != null and mission_card.playing:
		mission_card.skip()
	var pulls := int(cable.get_meta("pulls", 0)) + 1
	cable.set_meta("pulls", pulls)
	jolt = 1.0
	if pulls < WIRE_TUGS:
		# It stretches toward you and holds. It is anchored in you, too.
		anatomy.call("apply_hit", "torso", 3.0, 0.0, "blunt")
		cable.position = (camera.global_position - cable.global_position).normalized() * 0.05 * pulls
		opening_audio.cue("tug")
		return
	_rip_wire(cable)


func _rip_wire(cable: Node3D) -> void:
	umbilicals.erase(cable)
	anatomy.call("apply_hit", "torso", 7.0, 0.0, "shear")
	opening_audio.cue("rip")
	# It comes out wet and whips back up toward its anchor.
	var tween := create_tween()
	tween.tween_property(cable, "position", Vector3(0, 1.6, 0), 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cable, "scale", Vector3(0.3, 0.3, 0.3), 0.35)
	tween.tween_callback(cable.queue_free)
	for index in 7:
		var drop := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.02 + randf() * 0.025
		mesh.height = mesh.radius * 2.0
		mesh.material = WorldLook.surface(Color("5a1410") if index % 2 else Color("1f3a26"), "flesh", index)
		drop.mesh = mesh
		drop.position = camera.global_position + Vector3(randf_range(-0.2, 0.2), -0.25, randf_range(-0.2, 0.2))
		add_child(drop)
		var out := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
		glass_shards.append({"node": drop, "velocity": out * randf_range(1.2, 3.0), "life": 1.4})
	WorldHistory.record_event("opening_wire_torn", {"remaining": umbilicals.size()})
	if umbilicals.is_empty():
		_all_wires_out()


func _all_wires_out() -> void:
	revenge_at = wired_clock
	title.text = "GET REVENGE"
	mission_card.play("get_revenge", "GET REVENGE", REVENGE_HOLD)
	subtitle.text = ""
	opening_audio.cue("revenge")
	# Wounds are catalogue dictionaries once WorldHistory has normalised them
	# (WoundCatalog), not prose strings; a string here is rejected by the typed
	# array and the wound silently never lands.
	var wounds: Array = (WorldHistory.subject("player").get("wounds", []) as Array).duplicate(true)
	var has_sockets := wounds.any(func(wound) -> bool: return WOUND_CATALOG.label(wound) == "torn wire sockets")
	if not has_sockets:
		wounds.append({"label": "torn wire sockets", "zone": "torso", "type": "tear", "severity": 0.3})
	WorldHistory.amend_subject("player", {"wounds": wounds})
	PLAYER_ACTION_LEDGER.record("opening_wires_torn_out", {"tank": "0C-7", "location": "growing_floor"})


func _breach() -> void:
	if breakout_complete:
		return
	phase = "floor"
	clock = maxf(clock, DRAINED_AT)
	# Hanging in the wires turned the body; the stand-up faces down the aisle.
	yaw = 0.0
	pitch = 0.0
	player.rotation.y = 0.0
	opening_audio.cue("glass")
	vat_glass.visible = false
	fluid.visible = false
	for cable in umbilicals:
		cable.queue_free()
	umbilicals.clear()
	WorldHistory.record_event("opening_tank_breached", {"tank": "0C-7"})
	# Glass and fluid go outward across the grating.
	#
	# This used to be 22 pale two-centimetre boxes in desaturated green, thrown
	# from one point at the player's waist. On screen that is confetti, and the
	# tank simply stopped existing on the same frame. The shards are bigger, red
	# like the glass they came from, launched from all around the player at the
	# radius the wall actually stood at, and the camera is hit hard enough to
	# know something broke. The struts stay up, so what is left afterwards is a
	# broken tank rather than an empty floor.
	breach_shake = 0.9
	for index in 46:
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		# Wide size spread and real thinness: 46 shards all within a whisker of
		# the same size read as a pattern, not as something that shattered.
		var span := randf()
		mesh.size = Vector3(0.05 + span * 0.30, 0.008, 0.06 + span * span * 0.34)
		var shard_material := StandardMaterial3D.new()
		# Emission at 0.9 over a 0.62 alpha made these read as flat opaque red
		# cards rather than glass -- the glow cancelled out the transparency the
		# alpha was buying. Held low, and tinted toward the smoke-brown of the
		# glass they came off rather than pure blood.
		shard_material.albedo_color = Color(0.46, 0.20, 0.15, 0.34) if index % 3 else Color(0.30, 0.12, 0.09, 0.46)
		shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		shard_material.metallic = 0.35
		shard_material.roughness = 0.14
		shard_material.emission_enabled = true
		shard_material.emission = Color(0.16, 0.04, 0.03)
		shard_material.emission_energy_multiplier = 0.22
		mesh.material = shard_material
		shard.mesh = mesh
		# From the wall, not from a point inside the player's chest.
		var around := TAU * randf()
		shard.position = VAT_POSITION + Vector3(cos(around) * 0.92, 0.5 + randf() * 2.3, sin(around) * 0.92)
		add_child(shard)
		var out := Vector3(cos(around), randf_range(0.05, 0.55), sin(around)).normalized()
		glass_shards.append({"node": shard, "velocity": out * randf_range(3.2, 7.5), "life": 3.4})
	# Spreading puddle.
	var puddle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.7
	disc.bottom_radius = 1.7
	disc.height = 0.02
	# The floor light glitch Greg saw (Dust to Bones, 24 September): this used
	# WorldLook's "dirt", whose unfiltered grain and rim light turned a
	# near-black puddle into a pale disc of green and yellow pixel blocks under
	# the body-cam lamp. What spilled out of a tank is fluid: dark, and wet
	# enough to hold the lamp as one highlight instead of lighting up.
	var spill := StandardMaterial3D.new()
	spill.albedo_color = Color("0b120d")
	spill.roughness = 0.07
	spill.metallic = 0.25
	spill.metallic_specular = 0.7
	disc.material = spill
	puddle.name = "Puddle"
	puddle.mesh = disc
	puddle.position = VAT_POSITION + Vector3(0, 0.02, 0)
	add_child(puddle)
	_record_breakout()


## The first supernatural act remains physical: the player's suffering seizes
## the implanted wetwire, the tube comes out, and a usable restraint enters the
## shared carry model for later inventory readers.
func _record_breakout() -> void:
	breakout_complete = true
	var player_state := WorldHistory.subject("player")
	var anatomy_state: Dictionary = player_state.get("anatomy", {})
	# WorldHistory migrates filed hardware to typed catalogue dictionaries. Keep
	# the breakout on that same representation; appending the implant id string
	# directly makes Godot reject the value and leaves the first implant absent.
	var grown: Array = []
	for part in IMPLANT_CATALOG.list(anatomy_state.get("cybernetics", [])):
		grown.append(part)
	var has_wetwire := grown.any(func(part: Dictionary) -> bool: return str(part.get("id", "")) == "wetwire chip")
	if not has_wetwire:
		grown.append(IMPLANT_CATALOG.resolve({"id": "wetwire chip", "name": "wetwire chip"}))
	anatomy_state["cybernetics"] = grown
	WorldHistory.begin_ledger_batch()
	anatomy.call("configure", "player", 5000.0, grown)
	anatomy.call("apply_hit", "torso", 26.0, 0.0, "blunt")
	anatomy.call("apply_hit", "head", 14.0, 0.0, "blunt")
	# AX2.2/AX2.3. The seizure is not narrated here, it is performed, and it is
	# paid for by what the player actually did upstairs. `examination_refusals`
	# was counted in vat_intake.gd every time they declined a procedure; the
	# wounds above are the suffering. A player who refused nothing does not get
	# this, and SoulBreakthrough is what says so rather than a branch here.
	var endured := int(player_state.get("torture_cycles", 4))
	var refused := int(player_state.get("examination_refusals", 0))
	var seizure := SoulBreakthrough.seize("player", endured, refused)
	var memory := "The soul seized the wetwire and broke the vat."
	if not bool(seizure.get("ok", false)):
		# It still breaks -- the glass is physical and the tube comes out either
		# way. What a player who never refused does not get is the chip.
		memory = "The vat broke. The chip still answers to them."
	WorldHistory.amend_subject("player", {"status": "broke free", "anatomy": anatomy_state, "anatomy_state": anatomy.call("snapshot"), "memory": memory, "implant_seized": bool(seizure.get("ok", false))})
	var carry := CARRY.new()
	var item := {"label": "BROKEN MEDICAL RESTRAINT", "kind": "tool", "mass": 0.0, "perishes": false, "age": 0.0, "from": "growing_floor"}
	carry.items.append(item)
	carry.save_to_history()
	first_acquisition_complete = true
	PLAYER_ACTION_LEDGER.record("opening_breakout", {"location": "growing_floor", "implant": "wetwire chip", "acquisition": item.label})
	OPENING.advance("broke_free")
	WorldHistory.record_event("opening_breakout", {"location": "growing_floor", "implant": "wetwire chip", "item": item})
	WorldHistory.commit_ledger_batch()
	VAT_REBIRTH.complete()
	subtitle.text = "THE WETWIRE ANSWERS  //  RESTRAINT BROKEN"


func _update_shards(delta: float) -> void:
	for shard in glass_shards.duplicate():
		shard.velocity.y -= 11.0 * delta
		(shard.node as Node3D).position += (shard.velocity as Vector3) * delta
		(shard.node as Node3D).rotate(Vector3(1, 0.6, 0.3).normalized(), delta * 6.0)
		shard.life = float(shard.life) - delta
		if float(shard.life) <= 0.0:
			(shard.node as Node3D).queue_free()
			glass_shards.erase(shard)


func _update_movement(delta: float) -> void:
	var input := Vector3(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_forward", "move_back"),
	)
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	var speed := 2.7 * float(anatomy.call("mobility_ratio"))
	player.velocity.x = move_toward(player.velocity.x, direction.x * speed, 14.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * speed, 14.0 * delta)
	player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	# A body that just came out of a tank does not walk well.
	var stride := Vector2(player.velocity.x, player.velocity.z).length()
	camera.position.y = STANDING_EYE_OFFSET + sin(Time.get_ticks_msec() * 0.0055) * stride * 0.016
	camera.rotation.z = sin(Time.get_ticks_msec() * 0.0027) * stride * 0.008


func _interact() -> void:
	if not can_move:
		return
	if _try_pry_stuck_tank():
		return
	if _try_take_garment():
		return
	var to_door := door_marker.global_position - player.global_position
	to_door.y = 0.0
	if to_door.length() > 3.4:
		return
	# Filing the stage can legitimately refuse -- it is write-once and a resumed
	# world may already have it -- but that is not a reason to refuse the door.
	# It used to `return` here, which left a player whose world already recorded
	# `entered_pit` standing at the only exit pressing E at nothing.
	_record_service_arcade_entry()
	opening_audio.cue("door")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The pit does not begin at the end of one short vat aisle. The player now
	# emerges into the Service Arcade first: a real, collision-safe facility
	# district with a staff card and pressure gate before the vehicle heat.
	Interstitial.travel("res://service_arcade.tscn", "service artery unlocked // find a way below")


## AX3.1. What using the restraint actually does. Refused rather than silently
## ignored when the tool is not yet carried, so E near the tank before the
## breach reads as "nothing here yet" rather than as a broken prompt.
func _carries_restraint() -> bool:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if str((entry as Dictionary).get("label", "")) == RESTRAINT_LABEL:
			return true
	return false


func _near_first_objects() -> bool:
	if stuck_tank_marker == null:
		return false
	var to_tank := stuck_tank_marker.global_position - player.global_position
	to_tank.y = 0.0
	return to_tank.length() <= FIRST_OBJECT_REACH


func _try_pry_stuck_tank() -> bool:
	if stuck_tank_marker == null or stuck_tank_opened:
		return false
	if not _carries_restraint() or not _near_first_objects():
		return false
	stuck_tank_opened = true
	# The shell that hid the occupant is what the restraint actually defeats;
	# the occupant underneath was always real geometry, not a reveal that
	# pops into existence on the prompt.
	stuck_tank_shell.visible = false
	if stuck_tank_culture != null:
		stuck_tank_culture.visible = false
	subtitle.text = "THE BROKEN RESTRAINT BITES THE SEAM AND IT GIVES"
	WorldHistory.record_event("opening_first_object_used", {"tool": RESTRAINT_LABEL, "target": FAILED_SUBJECT_ID})
	return true


## AX3.2. "Take clothing off a dead subject." Only reachable once the
## restraint has actually opened the tank, and refused if the player is
## already dressed — this is the one garment this beat, not a general strip
## verb over every corpse the facility will ever contain.
func _try_take_garment() -> bool:
	if not stuck_tank_opened or not _near_first_objects():
		return false
	if CLOTHING.worn("player") != "bare":
		return false
	var result := CLOTHING.take_worn(FAILED_SUBJECT_ID, "player")
	if not bool(result.get("ok", false)):
		return false
	subtitle.text = "%s // TAKEN, ALREADY TORN FROM THE PULL" % CLOTHING.worn_label("player")
	return true


## The door press changes the player's status, the opening route and two
## territory sectors. It is still one authored act and must not be filed again
## while the asynchronous scene handoff is in flight.
func _record_service_arcade_entry() -> bool:
	if OPENING.reached("entered_arcade"):
		return false
	WorldHistory.begin_ledger_batch()
	OPENING.advance("entered_arcade")
	WorldHistory.amend_subject("player", {"status": "loose in the service arcade"})
	PLAYER_ACTION_LEDGER.record("opening_entered_arcade", {"location": "growing_floor", "destination": "service_arcade"})
	WorldHistory.commit_ledger_batch()
	return true


func _update_hud() -> void:
	if osd != null:
		osd.visible = intake == null
	var snapshot: Dictionary = anatomy.call("snapshot")
	vitals.text = "BLOOD %d%%   PAIN %02d   %s" % [
		roundi(float(snapshot.blood) / maxf(1.0, float(snapshot.blood_capacity)) * 100.0),
		int(snapshot.pain),
		"WIRED" if phase == "wired" else "DECANTED",
	]
	if phase == "wired":
		$HUD/Objective.text = ""
		if revenge_at >= 0.0:
			prompt.text = ""
		elif _aimed_wire() != null:
			prompt.text = "[E] RIP IT OUT   //   %d LEFT" % umbilicals.size()
			osd.point_at((_aimed_wire().get_child(3) as Node3D).global_position)
		else:
			prompt.text = "MOUSE LOOK   //   FIND THE WIRES   //   %d LEFT" % umbilicals.size()
		return
	# The objective belongs to the escape, and the escape does not exist until
	# the tank has actually broken. Gated on the breakout rather than on
	# movement alone so no future phase can hand back control early and put
	# ESCAPE THE FACILITY on screen while the examiner is still in the room.
	if not can_move or not breakout_complete:
		prompt.text = ""
		$HUD/Objective.text = ""
		return
	$HUD/Objective.text = "OBJECTIVE\n" + objective_text
	# AX3.1/AX3.6. INSPECT is a held state, not a menu, so it wins the prompt
	# line for as long as it is held rather than opening anything separate.
	if inspect_held:
		prompt.text = _inspect_text()
		return
	if not stuck_tank_opened and _carries_restraint() and _near_first_objects():
		prompt.text = "[E] PRY THE JAMMED TANK WITH THE BROKEN RESTRAINT"
		osd.point_at(stuck_tank_marker.global_position + Vector3(0, 1.3, 0))
		return
	if stuck_tank_opened and CLOTHING.worn("player") == "bare" and CLOTHING.worn(FAILED_SUBJECT_ID) != "bare" and _near_first_objects():
		prompt.text = "[E] TAKE THE CLOTHING OFF SUBJECT 0C-4"
		osd.point_at(stuck_tank_marker.global_position + Vector3(0, 1.1, 0))
		return
	var smash_prompt: String = vat_smash.prompt_for(camera, doctor_route.held_weapon() if doctor_route != null else "") if vat_smash != null and breakout_complete else ""
	if smash_prompt != "":
		prompt.text = smash_prompt
		return
	var route_prompt: String = doctor_route.prompt_text() if doctor_route != null else ""
	if route_prompt != "":
		prompt.text = route_prompt
		return
	# The door he left by: locked, and it says so (Greg, 2026-09-24: you should
	# be able to interact with it). Staff access is found further on.
	var to_staff := STAFF_DOOR_AT - player.global_position
	to_staff.y = 0.0
	if to_staff.length() <= 2.4:
		prompt.text = "STAFF DOOR // SEALED // STAFF ACCESS REQUIRED"
		return
	var to_door := door_marker.global_position - player.global_position
	to_door.y = 0.0
	# HOLD I is only offered when something is in hand to look at.
	var inspect_hint := "   //   HOLD I INSPECT" if _inspect_text() != "NOTHING IN HAND TO INSPECT" else ""
	prompt.text = "[E] ENTER THE UNDERGROUND HEAT" if to_door.length() <= 3.4 else "WASD MOVE   //   MOUSE LOOK   //   E INTERACT" + inspect_hint
	if to_door.length() <= 3.4:
		osd.point_at(door_marker.global_position + Vector3(0, 1.6, 0))


## AX3.1/AX3.6. What HOLD I actually shows — the same held object every time,
## named for what it is rather than a generic "inspecting..." placeholder, so
## the verb teaches by answering a real question instead of just consuming a
## key.
func _inspect_text() -> String:
	if _carries_restraint():
		return "%s // %s" % [RESTRAINT_LABEL, RESTRAINT_INSPECT_TEXT]
	if CLOTHING.worn("player") != "bare":
		return "%s // TAKEN OFF SOMEBODY WHO DID NOT SURVIVE THE CYCLE" % CLOTHING.worn_label("player")
	return "NOTHING IN HAND TO INSPECT"
