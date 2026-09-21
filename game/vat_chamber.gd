extends Node3D

## THE GROWING FLOOR — the opening.
##
## The player surfaces inside a vat: submerged, umbilicals in, fluid over the
## glass, rows of other tanks receding into the dark. The tank voids, the glass
## goes, and they land on the grating in a spreading puddle. From there they
## walk the aisle to the pit and are put in a car.
##
## Biomechanical register per ART-DIRECTION.md: ribbed vertebral arches,
## conduits that read as gut rather than pipe, wet everything. Built from
## primitives on the biopunk palette — art-directed now, authored later.

const OPENING := preload("res://systems/opening_director.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")
const ANATOMY := preload("res://systems/anatomy_component.gd")
const IMPLANT_CATALOG := preload("res://systems/implant_catalog.gd")
const VAT_INTAKE := preload("res://systems/vat_intake.gd")
const OPENING_AUDIO := preload("res://systems/opening_audio.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")
const BRAIN_INDEX := preload("res://systems/brain_index.gd")
const CARRY := preload("res://systems/carry.gd")
const CLOTHING := preload("res://systems/clothing.gd")
const BASELINE_HUMAN := preload("res://systems/baseline_human.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")

const EYE_HEIGHT := 1.62
const BODY_HALF_HEIGHT := 0.85
const STANDING_EYE_OFFSET := EYE_HEIGHT - BODY_HALF_HEIGHT
const VAT_POSITION := Vector3(0, 0, 0)
## P4.3: was 34.0 — a fresh body limps this at mobility_ratio speed (2.7 u/s),
## so the aisle alone cost ~10.6s of forced, agency-free walking after the
## ~19s of locked beats already ahead of it. Cut to the shortest length that
## still reads as a receding row of tanks (see the bay-count derivation below).
const AISLE_LENGTH := 22.0

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
var departure_clock := 0.0
var departure_line := -1
var vat_struts: Array[MeshInstance3D] = []
## How long the breach still shakes the camera. The glass used to simply stop
## being rendered, which Greg described as "I don't even smash out of the glass
## tube" -- there was no event, only an absence.
var breach_shake := 0.0
## Set into the right-hand wall level with the workstation, so he leaves the
## way staff leave rather than walking the player's escape route. It is not the
## pit door at the far end and it is never openable by the player.
const STAFF_DOOR_AT := Vector3(6.95, 0.0, -2.49)
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
	_build_chamber()
	_build_examination_station()
	_build_vat()
	_build_first_objects()
	_build_player()
	_build_intake()
	opening_audio = OPENING_AUDIO.new()
	add_child(opening_audio)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## G6.1/G6.3. Character creation was built but never connected to the opening:
## a new game went straight from the front door to the glass breaking. The
## handler now owns the first beat, and filing the sheet is what starts the
## camera sequence rather than a timer running behind the form.
func _build_intake() -> void:
	intake = VAT_INTAKE.new()
	intake.name = "Intake"
	$HUD.add_child(intake)
	intake.filed.connect(_on_intake_filed)


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
	for rib in 9:
		var height := 0.2 + float(rib) * 0.36
		if height > 0.95 and height < 2.55:
			continue
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.01 + (0.03 if rib % 3 == 0 else 0.0)
		torus.material = WorldLook.surface(Color("2e2419") if rib % 2 == 0 else Color("241c15"), "bone", rib)
		ring.mesh = torus
		ring.position = VAT_POSITION + Vector3(0, height, 0)
		ring.rotation_degrees = Vector3(90, 0, 0)
		add_child(ring)

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

	for rib in 4:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.8
		torus.outer_radius = 0.88
		torus.material = WorldLook.surface(Color("241d15"), "bone", 41 + rib)
		ring.mesh = torus
		ring.position = Vector3(0, 0.3 + float(rib) * 0.8, 0)
		ring.rotation_degrees = Vector3(90, 0, 0)
		stuck_tank_marker.add_child(ring)

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
	_slab(Vector3(16.0, 4.4, 0.5), Vector3(0, 2.2, 3.6), "rust", Color("19140f"))
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
			# Conduit running the length, sagging between bays.
			var gut := MeshInstance3D.new()
			var tube := CylinderMesh.new()
			tube.top_radius = 0.11
			tube.bottom_radius = 0.13
			tube.height = 3.1
			tube.material = WorldLook.surface(Color("3a2a22"), "flesh", bay + 3)
			gut.mesh = tube
			gut.position = Vector3(side * 6.2, 3.55 + sin(float(bay)) * 0.12, z - 1.5)
			gut.rotation_degrees = Vector3(90, 0, 0)
			add_child(gut)

		# Other tanks, most of them failed.
		if bay > 0:
			for side in [-1.0, 1.0]:
				_dead_tank(Vector3(side * 4.4, 0, z), bay)

		var strip := OmniLight3D.new()
		strip.position = Vector3(0, 3.8, z)
		strip.light_color = Color("7fbf95") if bay % 3 else Color("c0703a")
		strip.light_energy = 1.5
		strip.omni_range = 6.5
		add_child(strip)

	# The pit door at the far end.
	door_marker = Node3D.new()
	door_marker.position = Vector3(0, 0, -AISLE_LENGTH + 2.0)
	add_child(door_marker)
	_slab(Vector3(3.4, 3.4, 0.3), Vector3(0, 1.7, -AISLE_LENGTH + 1.6), "rust", Color("3d2a19"))
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
	station.position = Vector3(0.0, 0.0, -2.65)
	add_child(station)

	# A low medical desk between the vat and the doctor.
	var desk := MeshInstance3D.new()
	var desk_mesh := BoxMesh.new()
	desk_mesh.size = Vector3(2.25, 0.16, 0.72)
	desk_mesh.material = WorldLook.surface(Color("241a16"), "rust", 913)
	desk.mesh = desk_mesh
	desk.position = Vector3(0.05, 1.05, 0.25)
	station.add_child(desk)

	# The physical monitor gives the player a point of attention in the room;
	# its green code strips are geometry, not a flat title card.
	var monitor := MeshInstance3D.new()
	var monitor_mesh := BoxMesh.new()
	monitor_mesh.size = Vector3(1.06, 0.72, 0.10)
	monitor_mesh.material = WorldLook.surface(Color("171b16"), "metal", 914)
	monitor.mesh = monitor_mesh
	# The screen takes the right half of the desk, the examiner the left, and
	# the keyboard sits between them under his hand. He used to stand 1.7m off
	# to the side, which read as a man near a computer he had nothing to do
	# with; the two now occupy one workstation without overlapping at all.
	monitor.position = Vector3(0.60, 1.88, 0.28)
	station.add_child(monitor)
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
		code.position = Vector3(0.20 + code_width * 0.5, 2.10 - float(line_index) * 0.055, 0.345)
		station.add_child(code)
	var keyboard := MeshInstance3D.new()
	var keyboard_mesh := BoxMesh.new()
	keyboard_mesh.size = Vector3(0.86, 0.045, 0.38)
	keyboard_mesh.material = WorldLook.surface(Color("181612"), "metal", 921)
	keyboard.mesh = keyboard_mesh
	# Between the man and the screen, where a hand can actually reach it.
	keyboard.position = Vector3(0.22, 1.16, 0.54)
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
	examiner.position = Vector3(-0.16, 0.0, 0.16)
	station.add_child(examiner)
	examiner_node = examiner
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.24
	torso_mesh.height = 1.34
	torso_mesh.material = WorldLook.surface(Color("171118"), "cloth", 915)
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 1.35, 0)
	# Leaning in over the keyboard: the posture of somebody filling in a form
	# about a person who is in the room. A narrower capsule under the coat also
	# stops the silhouette reading as a bean.
	torso.rotation_degrees.x = 18.0
	examiner.add_child(torso)
	# A formal, almost ecclesiastical government coat: dark body, hard collar,
	# and a state seal that reads as occult bureaucracy rather than a generic
	# lab coat.  This is intentionally an example texture slot for the future
	# authored uniform, not a second unnamed character.
	var coat := MeshInstance3D.new()
	var coat_mesh := CylinderMesh.new()
	coat_mesh.top_radius = 0.30
	coat_mesh.bottom_radius = 0.40
	coat_mesh.height = 1.20
	coat_mesh.material = WorldLook.surface(Color("21101b"), "cloth", 919)
	coat.mesh = coat_mesh
	coat.position = Vector3(0.0, 1.26, 0.025)
	coat.rotation_degrees.x = 18.0
	examiner.add_child(coat)
	var collar := MeshInstance3D.new()
	var collar_mesh := TorusMesh.new()
	collar_mesh.inner_radius = 0.16
	collar_mesh.outer_radius = 0.225
	collar_mesh.material = WorldLook.surface(Color("5a3b20"), "metal", 920)
	collar.mesh = collar_mesh
	collar.position = Vector3(0.0, 1.91, 0.24)
	collar.rotation_degrees.x = 90.0
	examiner.add_child(collar)
	# A deliberately neutral state seal: copper geometry on a severe coat, not
	# an unrelated faction logo pasted onto the doctor.  It marks an example
	# texture/insignia zone for later authored government art.
	# Six radial spokes inside a ring is a ship's wheel, which is what it read
	# as on screen. Greg, 21 September: "no steering-wheel-like prop." The
	# restrained version is a breast badge, not a medallion: a small dark plate,
	# one thin ring, and a single vertical bar crossed near the top. Esoteric
	# because of what it omits, and small enough to stay a costume detail.
	var seal_material := WorldLook.surface(Color("9a5730"), "metal", 922)
	var badge := MeshInstance3D.new()
	var badge_mesh := BoxMesh.new()
	badge_mesh.size = Vector3(0.115, 0.145, 0.016)
	badge_mesh.material = WorldLook.surface(Color("14090f"), "metal", 923)
	badge.mesh = badge_mesh
	badge.position = Vector3(-0.115, 1.54, 0.345)
	examiner.add_child(badge)
	var seal_ring := MeshInstance3D.new()
	var seal_ring_mesh := TorusMesh.new()
	seal_ring_mesh.inner_radius = 0.030
	seal_ring_mesh.outer_radius = 0.040
	seal_ring_mesh.material = seal_material
	seal_ring.mesh = seal_ring_mesh
	seal_ring.position = Vector3(-0.115, 1.565, 0.356)
	seal_ring.rotation_degrees.x = 90.0
	examiner.add_child(seal_ring)
	var seal_stem := MeshInstance3D.new()
	var seal_stem_mesh := BoxMesh.new()
	seal_stem_mesh.size = Vector3(0.010, 0.095, 0.012)
	seal_stem_mesh.material = seal_material
	seal_stem.mesh = seal_stem_mesh
	seal_stem.position = Vector3(-0.115, 1.518, 0.356)
	examiner.add_child(seal_stem)
	var seal_bar := MeshInstance3D.new()
	var seal_bar_mesh := BoxMesh.new()
	seal_bar_mesh.size = Vector3(0.052, 0.010, 0.012)
	seal_bar_mesh.material = seal_material
	seal_bar.mesh = seal_bar_mesh
	seal_bar.position = Vector3(-0.115, 1.500, 0.356)
	examiner.add_child(seal_bar)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.20
	head_mesh.height = 0.42
	head_mesh.material = WorldLook.surface(Color("5a4235"), "flesh", 916)
	head.mesh = head_mesh
	head.position = Vector3(-0.08, 2.13, 0.15)
	examiner.add_child(head)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.09
		arm_mesh.height = 0.78
		arm_mesh.material = WorldLook.surface(Color("24201a"), "cloth", 917 + int(side))
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.31, 1.45, 0.10)
		arm.rotation_degrees = Vector3(72.0, 0.0, side * 12.0)
		examiner.add_child(arm)
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
	staff_door_panel.position = STAFF_DOOR_AT + Vector3(0.30, 0.0, -1.42)
	add_child(staff_door_panel)
	var panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.12, 2.35, 1.42)
	panel_mesh.material = WorldLook.surface(Color("3a2c1e"), "metal", 931)
	panel.mesh = panel_mesh
	panel.position = Vector3(0, 1.18, 0)
	staff_door_panel.add_child(panel)


func _dead_tank(at: Vector3, seed_value: int) -> void:
	var shell := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 0.8
	cylinder.height = 2.8
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = Color(0.31, 0.055, 0.035, 0.35)
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell_material.roughness = 0.4
	cylinder.material = shell_material
	shell.mesh = cylinder
	shell.position = at + Vector3(0, 1.4, 0)
	add_child(shell)
	var culture := MeshInstance3D.new()
	var culture_column := CylinderMesh.new()
	culture_column.top_radius = 0.74
	culture_column.bottom_radius = 0.74
	culture_column.height = 2.58
	var culture_material := StandardMaterial3D.new()
	culture_material.albedo_color = Color(0.38, 0.018, 0.011, 0.28)
	culture_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	culture_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	culture_material.emission_enabled = true
	culture_material.emission = Color(0.14, 0.004, 0.002)
	culture_column.material = culture_material
	culture.mesh = culture_column
	culture.position = at + Vector3(0, 1.38, 0)
	add_child(culture)
	# The closest four tanks use the exact same body rig and appearance grammar
	# as people in the overworld.  Farther down the corridor they deliberately
	# collapse back to cheap silhouettes; they are too distant to justify full
	# anatomy and that keeps the opening inside the performance budget.
	if seed_value <= 2:
		_build_cradled_vat_subject(at, seed_value)
	else:
		var occupant := MeshInstance3D.new()
		var body := CapsuleMesh.new()
		body.radius = 0.26
		body.height = 1.5 - float(seed_value % 3) * 0.2
		body.material = WorldLook.surface(Color("241a16"), "flesh", seed_value)
		occupant.mesh = body
		occupant.position = at + Vector3(0, 1.1, 0)
		occupant.rotation_degrees = Vector3(float(seed_value % 5) * 4.0, 0, float(seed_value % 7) * 3.0)
		add_child(occupant)
	for rib in 4:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.8
		torus.outer_radius = 0.88
		torus.material = WorldLook.surface(Color("241d15"), "bone", seed_value + rib)
		ring.mesh = torus
		ring.position = at + Vector3(0, 0.3 + float(rib) * 0.8, 0)
		ring.rotation_degrees = Vector3(90, 0, 0)
		add_child(ring)


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


func _slab(dimensions: Vector3, at: Vector3, kind: String, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = WorldLook.surface(color, kind, int(at.x * 31.0 + at.z * 17.0))
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
	# AX3.1/AX3.6. The same HOLD-I verb the rest of the game already teaches
	# with (see `bone_yard_hunt.gd`'s keys card), introduced here for the
	# first time by doing rather than by that card, since the card belongs to
	# a scene this run has not reached yet.
	if event is InputEventKey and not event.echo and event.keycode == KEY_I:
		inspect_held = event.pressed
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and phase != "submerged":
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.2, 1.0)


func _physics_process(delta: float) -> void:
	if phase == "intake":
		if opening_audio != null:
			opening_audio.set_phase("intake")
		return
	# Departure runs on its own clock so the vat's beat table keeps the timings
	# it was tuned with instead of every entry needing a +4.4 offset.
	if phase == "departure":
		_update_departure(delta)
		_update_hud()
		return
	clock += delta
	_update_beats()
	_update_sequence(delta)
	_update_shards(delta)
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
		examiner_node.rotation.y = lerpf(0.0, -PI * 0.5, ease(turn, 0.6))
		var walk := clampf((departure_clock - 0.50) / 2.45, 0.0, 1.0)
		examiner_node.position.x = lerpf(-0.16, STAFF_DOOR_AT.x, ease(walk, 0.85))
		# Through the doorway and out of the room, rather than standing in it
		# while the panel closes across him.
		if walk >= 1.0:
			examiner_node.visible = false

	# The panel slides back across once he is through.
	if staff_door_panel != null and is_instance_valid(staff_door_panel):
		# Starts the instant he is through at 2.95 and is shut by 3.70, so the
		# seal happens while the player is still looking at it rather than
		# behind a head that has already turned back to the tank.
		var shut := clampf((departure_clock - 2.95) / 0.75, 0.0, 1.0)
		staff_door_panel.position.z = STAFF_DOOR_AT.z + lerpf(-1.42, 0.0, ease(shut, 0.4))

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
	for index in BEATS.size():
		if clock >= float(BEATS[index].at) and index > line_index:
			line_index = index
			subtitle.text = str(BEATS[index].text)


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
			if t >= 1.0:
				_breach()
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
			if t >= 1.0:
				phase = "aisle"
				can_move = true
				subtitle.text = ""
				yaw = 0.0
				pitch = 0.0


func _breach() -> void:
	if breakout_complete:
		return
	phase = "floor"
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
		mesh.size = Vector3(0.11 + randf() * 0.22, 0.015, 0.14 + randf() * 0.26)
		var shard_material := StandardMaterial3D.new()
		shard_material.albedo_color = Color(0.52, 0.17, 0.13, 0.62) if index % 3 else Color(0.28, 0.08, 0.06, 0.78)
		shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		shard_material.emission_enabled = true
		shard_material.emission = Color(0.24, 0.05, 0.03)
		shard_material.emission_energy_multiplier = 0.9
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
	disc.material = WorldLook.surface(Color("101a13"), "dirt", 4)
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
	_record_pit_entry()
	opening_audio.cue("door")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Interstitial.travel("res://underground_colosseum.tscn", "racked for the tunnel heat // debt is in the meat")


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
func _record_pit_entry() -> bool:
	if OPENING.reached("entered_pit"):
		return false
	WorldHistory.begin_ledger_batch()
	OPENING.advance("entered_pit")
	FACILITY_TERRITORY.apply_event("opening_entered_pit")
	WorldHistory.amend_subject("player", {"status": "racked for a heat"})
	PLAYER_ACTION_LEDGER.record("opening_entered_pit", {"location": "growing_floor", "destination": "underground_colosseum"})
	WorldHistory.commit_ledger_batch()
	return true


func _update_hud() -> void:
	var snapshot: Dictionary = anatomy.call("snapshot")
	vitals.text = "BLOOD %d%%   PAIN %02d   %s" % [
		roundi(float(snapshot.blood) / maxf(1.0, float(snapshot.blood_capacity)) * 100.0),
		int(snapshot.pain),
		"DECANTED",
	]
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
		return
	if stuck_tank_opened and CLOTHING.worn("player") == "bare" and _near_first_objects():
		prompt.text = "[E] TAKE THE CLOTHING OFF SUBJECT 0C-4"
		return
	var to_door := door_marker.global_position - player.global_position
	to_door.y = 0.0
	prompt.text = "[E] ENTER THE UNDERGROUND HEAT" if to_door.length() <= 3.4 else "WASD MOVE   //   MOUSE LOOK   //   E INTERACT   //   HOLD I INSPECT"


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
