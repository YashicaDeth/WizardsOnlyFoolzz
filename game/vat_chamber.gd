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
const CHECKPOINT := preload("res://systems/facility_checkpoint.gd")

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
var failed_subject_visual: MeshInstance3D
var stuck_tank_opened := false
var inspect_held := false
## Vertebra 5 (Dust to Bones): the tissue-keyed gate and its guard, between
## the aisle and the pit door. See `facility_checkpoint.gd`.
var checkpoint: Node3D

# 0 submerged, 1 voiding, 2 breach, 3 floor, 4 aisle
const BEATS := [
	{"at": 0.8, "text": "AIRWAY OBSTRUCTED  //  FOREIGN TUBE"},
	{"at": 3.2, "text": "TANK 0C-7  //  CYCLE ABORTED  //  VOIDING"},
	{"at": 5.8, "text": "HANDLER: \"Decant is stable. Rack them for the heat.\""},
	{"at": 7.4, "text": "HANDLER: \"Debt's in the meat. CellOutz owns what it grew.\""},
	# K3.2. "The opening reframed: CellOutz grew you, which is why the debt is
	# in the meat" — DESIGN/COSMOLOGY.md. It is one attributed sentence now,
	# rather than two lore lines racing each other while the player is helpless.
	{"at": 9.0, "text": "OBJECTIVE  //  ESCAPE THE FACILITY"},
]

@onready var subtitle: Label = $HUD/Subtitle
@onready var prompt: Label = $HUD/Prompt
@onready var vitals: Label = $HUD/Vitals
@onready var fade: ColorRect = $HUD/Fade
@onready var submerge_tint: ColorRect = $HUD/Submerge


func _ready() -> void:
	$WorldEnvironment.environment = WorldLook.environment("ossuary")
	_build_chamber()
	_build_vat()
	_build_first_objects()
	_build_player()
	_build_checkpoint()
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
	# AX4.5. Coming back from a death: the body on file is grown again and the
	# form is skipped, so dying does not cost the player the examination twice.
	var rebirth := OpeningDeath.consume_pending()
	if not rebirth.is_empty():
		intake.refile_from_preset(str(rebirth.get("preset", "")))


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
	phase = "submerged"
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


func _build_checkpoint() -> void:
	checkpoint = CHECKPOINT.new()
	checkpoint.name = "DSectionGate"
	# Just past the last bay of tanks and 2.2 m short of the pit door, so the
	# door can only be reached through the gate.
	checkpoint.position = Vector3(0, 0, -AISLE_LENGTH + 3.8)
	add_child(checkpoint)
	checkpoint.build(7.35, 4.1)
	checkpoint.bind_player(player, anatomy)
	checkpoint.message.connect(func(text: String) -> void: subtitle.text = text)


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
	anatomy.connect("died", _on_player_died)
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


## AX4.5. Death in the opening is rebirth in a vat (Greg, 24 September).
func _on_player_died(report: Dictionary) -> void:
	if phase == "dead":
		return
	phase = "dead"
	can_move = false
	var rebirth := OpeningDeath.handle(str(report.get("type", "")))
	Interstitial.travel(str(rebirth.scene), "the growing floor // grown again")


func _umbilical(index: int) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var angle := TAU * float(index) / 4.0 + 0.4
	var anchor := VAT_POSITION + Vector3(cos(angle) * 0.62, 3.05, sin(angle) * 0.62)
	var target := VAT_POSITION + Vector3(cos(angle) * 0.16, 1.45, sin(angle) * 0.16)
	# Drawn as a chain of segments so it reads as gut, not as a straight pipe.
	for segment in 7:
		var t := float(segment) / 6.0
		var point := anchor.lerp(target, t) + Vector3(sin(t * 5.0) * 0.07, 0, cos(t * 4.0) * 0.07)
		var link := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.055 - t * 0.018
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
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.38, 0.52, 0.44, 0.26)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	var fluid_material := StandardMaterial3D.new()
	fluid_material.albedo_color = Color(0.16, 0.3, 0.2, 0.5)
	fluid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fluid_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fluid_material.emission_enabled = true
	fluid_material.emission = Color(0.09, 0.2, 0.13)
	fluid_material.emission_energy_multiplier = 0.7
	column.material = fluid_material
	fluid.mesh = column
	fluid.position = VAT_POSITION + Vector3(0, 1.5, 0)
	add_child(fluid)

	# Ribbed collar and base: the tank is grown onto the floor, not bolted to it.
	for rib in 9:
		var height := 0.2 + float(rib) * 0.36
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.06 + (0.05 if rib % 3 == 0 else 0.0)
		torus.material = WorldLook.surface(Color("2e2419") if rib % 2 == 0 else Color("241c15"), "bone", rib)
		ring.mesh = torus
		ring.position = VAT_POSITION + Vector3(0, height, 0)
		ring.rotation_degrees = Vector3(90, 0, 0)
		add_child(ring)

	var glow := OmniLight3D.new()
	glow.position = VAT_POSITION + Vector3(0, 1.6, 0)
	glow.light_color = Color("6fd39a")
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
	shell_material.albedo_color = Color(0.22, 0.24, 0.2, 0.6)
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell_material.roughness = 0.5
	cylinder.material = shell_material
	stuck_tank_shell.mesh = cylinder
	stuck_tank_shell.position = Vector3(0, 1.4, 0)
	stuck_tank_marker.add_child(stuck_tank_shell)

	failed_subject_visual = MeshInstance3D.new()
	var occupant := CapsuleMesh.new()
	occupant.radius = 0.27
	occupant.height = 1.4
	occupant.material = WorldLook.surface(Color("241a16"), "flesh", 41)
	failed_subject_visual.mesh = occupant
	failed_subject_visual.position = Vector3(0, 1.05, 0)
	stuck_tank_marker.add_child(failed_subject_visual)

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


func _dead_tank(at: Vector3, seed_value: int) -> void:
	var shell := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 0.8
	cylinder.height = 2.8
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = Color(0.2, 0.26, 0.22, 0.4)
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell_material.roughness = 0.4
	cylinder.material = shell_material
	shell.mesh = cylinder
	shell.position = at + Vector3(0, 1.4, 0)
	add_child(shell)
	# Whatever is inside is a silhouette and stays one.
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
		if event.pressed and can_move:
			checkpoint.strike()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X and can_move:
		checkpoint.take_arm()
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
	clock += delta
	checkpoint.active = can_move and phase != "dead"
	_update_beats()
	_update_sequence(delta)
	_update_shards(delta)
	if can_move:
		_update_movement(delta)
	_update_hud()


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
			fade.color.a = clampf(1.0 - clock / 2.2, 0.0, 1.0)
			submerge_tint.color.a = 0.42
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
			submerge_tint.color.a = lerpf(0.42, 0.0, t)
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
	for index in 22:
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05 + randf() * 0.11, 0.02, 0.07 + randf() * 0.13)
		var shard_material := StandardMaterial3D.new()
		shard_material.albedo_color = Color(0.4, 0.55, 0.47, 0.5) if index % 3 else Color(0.12, 0.24, 0.16, 0.8)
		shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = shard_material
		shard.mesh = mesh
		shard.position = VAT_POSITION + Vector3(0, 1.1, 0)
		add_child(shard)
		var out := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 0.7), randf_range(-1.0, 1.0)).normalized()
		glass_shards.append({"node": shard, "velocity": out * randf_range(2.5, 6.0), "life": 3.0})
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
	var crouched := Input.is_action_pressed("crouch")
	var speed := 2.7 * float(anatomy.call("mobility_ratio")) * float(checkpoint.burden()) * (0.5 if crouched else 1.0)
	player.velocity.x = move_toward(player.velocity.x, direction.x * speed, 14.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * speed, 14.0 * delta)
	player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	# A body that just came out of a tank does not walk well.
	var stride := Vector2(player.velocity.x, player.velocity.z).length()
	camera.position.y = STANDING_EYE_OFFSET - (0.55 if crouched else 0.0) + sin(Time.get_ticks_msec() * 0.0055) * stride * 0.016
	camera.rotation.z = sin(Time.get_ticks_msec() * 0.0027) * stride * 0.008


func _interact() -> void:
	if not can_move:
		return
	if _try_pry_stuck_tank():
		return
	if _try_take_garment():
		return
	if checkpoint.interact():
		return
	if not checkpoint.is_open:
		return
	var to_door := door_marker.global_position - player.global_position
	to_door.y = 0.0
	if to_door.length() > 3.4:
		return
	if not _record_pit_entry():
		return
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
	if can_move:
		vitals.text += "   //   " + str(checkpoint.status_text())
	if not can_move:
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
	var gate_prompt := str(checkpoint.prompt())
	if gate_prompt != "":
		prompt.text = gate_prompt
		return
	var to_door := door_marker.global_position - player.global_position
	to_door.y = 0.0
	if checkpoint.is_open and to_door.length() <= 3.4:
		prompt.text = "[E] ENTER THE UNDERGROUND HEAT"
		return
	prompt.text = "WASD MOVE   //   CTRL CROUCH   //   MOUSE LOOK   //   E INTERACT   //   HOLD I INSPECT"


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