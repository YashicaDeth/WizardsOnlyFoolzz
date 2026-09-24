extends Node3D

## THE LOWER WORKS — the first piece of the buried city between the intake
## facility and the underground heat.  It is deliberately authored from a
## seed vocabulary (arches, pipes, vaults and a landmark lift), not copied map
## geometry and not an infinite procedural maze.  Every visible branch has a
## gameplay role: take a fuse, open a shortcut, descend.

const OPENING := preload("res://systems/opening_director.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")
const RIVAL_TACTICS := preload("res://systems/rival_tactics.gd")
const LAB_DRESSING := preload("res://systems/lab_dressing.gd")

const ENTRY := Vector3(0, 1.0, 16.0)
const FUSE_AT := Vector3(11.2, 0.85, 1.8)
const SHORTCUT_AT := Vector3(-10.2, 0.0, -8.0)
const LIFT_AT := Vector3(0, 0.0, -38.0)
## The trigger is the elevator you can see. It sat 9 m past the cage, at
## z -47, so standing at the lift and pressing E did nothing and the prompt
## never showed: the run ended here for Greg on first launch (2026-09-24).
const EXIT_AT := LIFT_AT

## AD3. The third way down.
##
## There were two: spend the fuse on the shortcut, or spend the breach tool on
## the sentinel. Both cost you something you carried in, and a player who
## arrived with neither had no route at all except walking into it.
##
## This one costs time and nerve instead. The west galleries were already
## built, already dressed and doing nothing -- walkways twelve metres long at
## head height with a rail and a row of pods, which the player could look at
## and never stand on. A ramp at each end and a catwalk across the gap turns
## the scenery into the route, and the district does not get any bigger, which
## is the whole constraint: another way through, not another map.
##
## The deck is the top of a gallery floor: they are authored at y=1.9 with a
## 0.35 slab, so their walking surface is 2.075 and everything here matches it
## rather than guessing.
const GANTRY_RUN := -10.0
const GANTRY_DECK := 2.075
## How far above the sentinel puts you out of its reach. It is a ground
## machine on tracks and the gantry is over its head.
const GANTRY_CLEARANCE := 1.4
## The floor the ramps start from and the slab they are cut out of. Named
## because the first pair were placed by eye and the arithmetic that failed was
## invisible in the numbers.
## How the player moves down here.
const WALK_SPEED := 3.65
const SPRINT_SCALE := 1.7
## Enough to clear the 0.45 kerbs and the pipe runs, and not enough to reach
## the gantry deck -- the ramps are the way up and a jump that skipped them
## would make the route pointless the day it was built.
const JUMP_SPEED := 4.6
const GANTRY_FLOOR := 0.005
const GANTRY_THICK := 0.3
## Horizontal reach of each ramp. Long enough that the top end overlaps the
## gallery edge instead of stopping short of it.
const GANTRY_REACH := 7.7
## Where the bay lamps hang and how far they carry.
##
## The range has to clear the height before any of it reaches the floor at all,
## and then clear it by enough to cross the room: reach across the floor is
## `sqrt(range^2 - height^2)`, so 20 against 8.7 carries 18 metres and covers
## a corridor whose walls are 14.4 out from the centre line.
const BAY_LAMP_HEIGHT := 8.7
const BAY_LAMP_RANGE := 20.0

var player: CharacterBody3D
var camera: Camera3D
var objective: Label
var prompt: Label
var status: Label
var yaw := 0.0
var pitch := -0.05
var fuse_taken := false
var shortcut_open := false
var shortcut_gate: StaticBody3D
var fuse_visual: MeshInstance3D
var patrol: Node3D
var patrol_phase := 0.0
var patrol_tactic: Dictionary = {}
var patrol_tree: Resource
var patrol_alert := false
var patrol_disabled := false
var patrol_attack_cooldown := 0.0
var blood := 100.0
var breach_tool_ready := false
var breach_flash: OmniLight3D
var sentinel_disable_reason := ""


func _ready() -> void:
	var environment := WorldEnvironment.new()
	# Not `ossuary`. It is mauve from zenith to ground and carries the densest
	# fog of any preset in `world_look.gd`, and the note beside that preset
	# already worked out what it does to a district: the fog "is why the street
	# reads as untextured blocks". The front door was moved off it for exactly
	# that; this is a sealed tunnel forty metres underground, where a
	# sky-coloured haze was never the right answer in the first place.
	environment.environment = WorldLook.environment("lower_works")
	add_child(environment)
	_build_city_shell()
	_build_gantry()
	_build_landmark_lift()
	_build_fuse_branch()
	_build_patrol()
	_build_player()
	_build_hud()
	# The arcade's optional breach tool carries forward as a compact, deliberate
	# first combat choice.  The fuse remains the quiet route; neither route is
	# a false pickup that disappears at the next scene swap.
	# Carried, not merely once taken: a death leaves it on the old body.
	breach_tool_ready = VatRebirth.carries("BREACH TOOL")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	WorldHistory.record_event("lower_works_entered", {"location": "lower_works"})


func _build_player() -> void:
	player = CharacterBody3D.new()
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
	if VatRebirth.carries("BREACH TOOL"):
		LabSurface.hold_in_view(camera, LabSurface.breach_tool())
	breach_flash = OmniLight3D.new()
	breach_flash.name = "BreachFlash"
	breach_flash.light_color = Color("f0a24b")
	breach_flash.light_energy = 0.0
	breach_flash.omni_range = 7.0
	breach_flash.position = Vector3(0, 1.2, 0.3)
	player.add_child(breach_flash)


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
	status.add_theme_color_override("font_color", Color("a8c58d"))
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


func _build_city_shell() -> void:
	# Broad stable collision first; all detail hangs from it.  No scattered
	# collider maze means this stays a good place to test combat and movement.
	_slab(Vector3(30, 0.45, 70), Vector3(0, -0.22, -17), "dirt", Color("16130f"))
	_slab(Vector3(30, 0.35, 70), Vector3(0, 11.8, -17), "rust", Color("100c0a"))
	_slab(Vector3(0.55, 12, 70), Vector3(-14.7, 5.8, -17), "rust", Color("201711"))
	_slab(Vector3(0.55, 12, 70), Vector3(14.7, 5.8, -17), "rust", Color("201711"))
	_slab(Vector3(30, 12, 0.55), Vector3(0, 5.8, 17.5), "rust", Color("201711"))
	for bay in 11:
		var z := 13.5 - float(bay) * 5.9
		_build_vault(z, bay)
		if bay % 2 == 0:
			_build_pipe_cluster(Vector3(-11.5 if bay % 4 == 0 else 11.5, 1.1, z - 1.5), bay)
		if bay % 3 == 0:
			_build_hanging_cable(Vector3(0, 10.8, z + 1.1), bay)
		var light := OmniLight3D.new()
		light.name = "BayLamp%d" % bay
		light.position = Vector3(0.0, BAY_LAMP_HEIGHT, z)
		light.light_color = Color("b64b2b") if bay % 3 else Color("718d5d")
		# Hung at 8.7 with a range of 10, which is a lamp that lights almost
		# nothing. An omni range is a sphere, so the reach across the floor is
		# `sqrt(range^2 - height^2)` -- at 10 and 8.7 that is 4.9 metres, in a
		# corridor 28.8 metres wide. The side walls are 16.8 metres away and
		# were outside the sphere entirely, so eleven lamps lit a narrow strip
		# down the centre line and the rest of the district was black.
		#
		# The lift beam next door has always been range 19 at a similar height,
		# which is exactly why it is the one thing in here anybody can see, and
		# why the district's own design note says navigation is by a real
		# object rather than an arrow. It was the only object lit well enough
		# to navigate by.
		light.light_energy = 1.9
		light.omni_range = BAY_LAMP_RANGE
		light.shadow_enabled = false
		add_child(light)
		# Low on the walls, every third bay, alternating sides. The ceiling
		# lamps wash the floor and leave the walls flat; these are what make
		# the panelling and the racking `LabDressing` puts along them read as
		# surfaces rather than as a dark edge to the corridor.
		if bay % 3 == 1:
			var side := 1.0 if (bay / 3) % 2 == 0 else -1.0
			var sconce := OmniLight3D.new()
			sconce.name = "WallSconce%d" % bay
			sconce.position = Vector3(side * 13.4, 3.4, z)
			sconce.light_color = Color("c2662f")
			sconce.light_energy = 1.6
			sconce.omni_range = 9.5
			sconce.shadow_enabled = false
			add_child(sconce)
	# Wide side galleries make the world read as a city rather than a hallway.
	for side in [-1.0, 1.0]:
		_build_gallery(side, -2.0)
		_build_gallery(side, -24.0)

	# The dressing goes on last, over finished architecture. It adds no
	# collider, so every route test that drives this district still drives the
	# same shape it always did -- and it is instanced, so seventy metres of
	# panelling, jars, spatter and hanging meat costs about a dozen draws
	# rather than the two thousand loose meshes the districts already carry.
	#
	# The reserved stretches are the two gallery pairs and the lift floor: the
	# tanks and slabs stand tall enough to grow up through a walkway, and a
	# specimen tank through the floor somebody walks on reads as broken.
	LAB_DRESSING.dress(self, -46.0, 15.0, 14.4, 11.6, 7314, [
		Vector2(-9.0, 5.0), Vector2(-31.0, -17.0), Vector2(-42.0, -33.0),
	])


## The ramps and the catwalk that make the galleries a route.
##
## Ramps rather than steps because the Lower Works player has no jump and
## `CharacterBody3D` does not climb stairs on its own -- a staircase here would
## be a wall with a pattern on it. Both slopes are about seventeen degrees,
## well inside the forty-five `move_and_slide` will walk up.
func _build_gantry() -> void:
	# Both ramps are derived from the two surfaces they have to meet rather
	# than positioned by eye, because the first version was placed by eye and
	# did not work. Greg: *"the ramps arent working"*. Two faults, and either
	# one alone was enough to stop a player with no jump.
	#
	# The centre sat at half the deck height, which put the slab's *top* a
	# further 0.15 above the floor at the bottom end -- a step, and
	# `CharacterBody3D` does not climb steps by itself, so the route began with
	# a lip that could not be crossed. The surface offset is
	# `(thickness / 2) / cos(angle)` and it has to come out of the centre
	# height, not be ignored.
	#
	# And the top end stopped at z=4.5 while the gallery it was supposed to
	# reach ends at z=4.0, leaving half a metre of air at the top of a climb
	# nobody could make anyway.
	var rise := GANTRY_DECK - GANTRY_FLOOR
	var climb := atan2(rise, GANTRY_REACH)
	var surface := (GANTRY_THICK * 0.5) / cos(climb)
	var length := sqrt(GANTRY_REACH * GANTRY_REACH + rise * rise)
	var centre_y := GANTRY_FLOOR + rise * 0.5 - surface

	# Up: the high end is the -Z one, and a positive rotation about X takes the
	# +Z end down. It overlaps the gallery edge rather than meeting it exactly.
	var up := _slab(Vector3(3.0, GANTRY_THICK, length), Vector3(GANTRY_RUN, centre_y, 7.65), "rust", Color("241a13"))
	up.name = "GantryRampUp"
	up.rotation.x = climb

	# The gap between the two galleries, which sit at z=-2 and z=-24 and so
	# leave ten metres of air between their near edges.
	var span := _slab(Vector3(2.4, 0.3, 10.0), Vector3(GANTRY_RUN, GANTRY_DECK - 0.15, -13.0), "rust", Color("1f1811"))
	span.name = "GantryCatwalk"

	# Down at the far end, landing short of the lift rather than on it.
	var down := _slab(Vector3(3.0, GANTRY_THICK, length), Vector3(GANTRY_RUN, centre_y, -33.65), "rust", Color("241a13"))
	down.name = "GantryRampDown"
	down.rotation.x = -climb

	# Light where the route is. Every lamp in the district hangs on the centre
	# line at x=0 with a ten metre range, so the west galleries -- which is
	# where this whole route runs -- were the darkest ground in the Lower
	# Works, and the ramps were unlit objects in it. A player cannot take a
	# route they cannot find.
	for post in 4:
		var lamp := OmniLight3D.new()
		lamp.name = "GantryLamp%d" % post
		lamp.position = Vector3(GANTRY_RUN + 1.0, GANTRY_DECK + 2.6, 9.0 - float(post) * 14.0)
		# Cooler than the bay lamps on purpose: the route reads as its own
		# thing from the floor rather than as more of the same corridor.
		lamp.light_color = Color("7fa8b8")
		lamp.light_energy = 2.1
		lamp.omni_range = 13.0
		lamp.shadow_enabled = false
		add_child(lamp)

	# A rail on the open side only. It is there to read as a walkway from the
	# floor below and to stop a player stepping off it in the dark, not to box
	# the route in.
	for section in 3:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.12, 0.5, 9.0)
		rail_mesh.material = WorldLook.surface(Color("5d3020"), "metal", 4800 + section)
		rail.mesh = rail_mesh
		rail.position = Vector3(GANTRY_RUN + 1.3, GANTRY_DECK + 0.25, -2.0 - float(section) * 11.0)
		add_child(rail)


func _build_vault(z: float, index: int) -> void:
	for side in [-1.0, 1.0]:
		var pier := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, 8.7, 0.7)
		mesh.material = WorldLook.surface(Color("3a2b20"), "bone", 1700 + index * 3 + int(side))
		pier.mesh = mesh
		pier.position = Vector3(side * 12.1, 4.35, z)
		add_child(pier)
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(24.8, 0.72, 0.72)
	beam_mesh.material = WorldLook.surface(Color("3a2b20"), "bone", 1800 + index)
	beam.mesh = beam_mesh
	beam.position = Vector3(0, 8.7, z)
	add_child(beam)


func _build_gallery(side: float, z: float) -> void:
	var floor := _slab(Vector3(8.8, 0.35, 12.0), Vector3(side * 10.0, 1.9, z), "dirt", Color("1c1713"))
	floor.name = "GalleryWalkway"
	var rail := MeshInstance3D.new()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(8.6, 0.45, 0.14)
	rail_mesh.material = WorldLook.surface(Color("6d3825"), "metal", int(side * z * 19))
	rail.mesh = rail_mesh
	rail.position = Vector3(side * 10.0, 2.45, z + 5.5)
	add_child(rail)
	for room in 3:
		var pod := MeshInstance3D.new()
		var pod_mesh := CylinderMesh.new()
		pod_mesh.top_radius = 0.88
		pod_mesh.bottom_radius = 0.88
		pod_mesh.height = 3.2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.24, 0.05, 0.035, 0.38)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color("320603")
		pod_mesh.material = mat
		pod.mesh = pod_mesh
		pod.position = Vector3(side * 11.3, 3.65, z - 3.4 + float(room) * 3.4)
		add_child(pod)


func _build_pipe_cluster(at: Vector3, seed: int) -> void:
	for pipe_index in 4:
		var pipe := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.16 + float(pipe_index) * 0.035
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 3.4 + float((seed + pipe_index) % 3)
		mesh.material = WorldLook.surface(Color("3d4e35") if pipe_index % 2 else Color("5d3020"), "metal", seed * 31 + pipe_index)
		pipe.mesh = mesh
		pipe.position = at + Vector3(float(pipe_index) * 0.43 - 0.6, mesh.height * 0.5, 0)
		add_child(pipe)


func _build_hanging_cable(at: Vector3, seed: int) -> void:
	var cable := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.09
	mesh.bottom_radius = 0.09
	mesh.height = 3.5 + float(seed % 3)
	mesh.material = WorldLook.surface(Color("3a4b39"), "flesh", 2110 + seed)
	cable.mesh = mesh
	cable.position = at - Vector3(0, mesh.height * 0.5, 0)
	cable.rotation_degrees.z = -8.0 + float(seed % 4) * 5.0
	add_child(cable)


func _build_landmark_lift() -> void:
	# The lift is visible from almost the whole district, so navigation is based
	# on a real object instead of an arrow.
	for ring_index in 5:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 4.7 + float(ring_index) * 0.16
		torus.outer_radius = torus.inner_radius + 0.16
		torus.material = WorldLook.surface(Color("5b3725"), "metal", 2400 + ring_index)
		ring.mesh = torus
		ring.position = LIFT_AT + Vector3(0, 3.0 + float(ring_index) * 1.28, 0)
		ring.rotation_degrees.x = 90
		add_child(ring)
	var cage := MeshInstance3D.new()
	var cage_mesh := CylinderMesh.new()
	cage_mesh.top_radius = 2.7
	cage_mesh.bottom_radius = 2.7
	cage_mesh.height = 7.0
	cage_mesh.radial_segments = 12
	cage_mesh.material = WorldLook.surface(Color("241a17"), "metal", 2499)
	cage.mesh = cage_mesh
	cage.position = LIFT_AT + Vector3(0, 3.5, 0)
	add_child(cage)
	var beam := OmniLight3D.new()
	beam.position = LIFT_AT + Vector3(0, 8.4, 0)
	beam.light_color = Color("d36f34")
	beam.light_energy = 5.5
	beam.omni_range = 19.0
	add_child(beam)
	var label := Label3D.new()
	label.text = "LOWER WORKS // HEAT ELEVATOR"
	label.font_size = 34
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("e8a55a")
	label.position = LIFT_AT + Vector3(0, 8.1, 1.0)
	add_child(label)


func _build_fuse_branch() -> void:
	# A short east branch holds a physical fuse; the west gate becomes the
	# optional fast route once it is installed.
	fuse_visual = MeshInstance3D.new()
	var fuse_mesh := BoxMesh.new()
	fuse_mesh.size = Vector3(0.30, 0.45, 0.75)
	var fuse_mat := StandardMaterial3D.new()
	fuse_mat.albedo_color = Color("d9973d")
	fuse_mat.emission_enabled = true
	fuse_mat.emission = Color("7a360e")
	fuse_mesh.material = fuse_mat
	fuse_visual.mesh = fuse_mesh
	fuse_visual.position = FUSE_AT
	add_child(fuse_visual)
	var fuse_label := Label3D.new()
	fuse_label.text = "LIFT FUSE\n[ E ] TAKE"
	fuse_label.font_size = 32
	fuse_label.outline_size = 7
	fuse_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fuse_label.modulate = Color("efa755")
	fuse_label.position = FUSE_AT + Vector3(0, 0.75, 0)
	add_child(fuse_label)
	shortcut_gate = _slab(Vector3(4.4, 4.6, 0.42), SHORTCUT_AT + Vector3(0, 2.3, 0), "metal", Color("42221a"))
	var gate_label := Label3D.new()
	gate_label.text = "SERVICE SHORTCUT\nLIFT FUSE REQUIRED"
	gate_label.font_size = 28
	gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate_label.modulate = Color("c76a3e")
	gate_label.position = SHORTCUT_AT + Vector3(0, 4.8, 0.4)
	add_child(gate_label)


func _build_patrol() -> void:
	# One Limbo-backed guard is a meaningful pressure beat without turning the
	# district into a crowd simulation.  The behaviour tree stores the stance;
	# this scene supplies movement and one inexpensive melee consequence.
	patrol = Node3D.new()
	patrol.name = "LowerWorksSentinel"
	patrol.position = Vector3(0, 0, -16)
	add_child(patrol)
	patrol_tactic = RIVAL_TACTICS.tactic_for("lower_works_sentinel")
	patrol_tree = RIVAL_TACTICS.build_tree(patrol_tactic)
	if patrol_tree != null:
		patrol.set_meta("behavior_tree", patrol_tree)
	patrol.set_meta("tactic", str(patrol_tactic.get("id", "press")))
	var shell := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 2.0
	mesh.material = WorldLook.surface(Color("493127"), "flesh", 2801)
	shell.mesh = mesh
	shell.position.y = 1.0
	patrol.add_child(shell)
	var eye := OmniLight3D.new()
	eye.name = "Eye"
	eye.position = Vector3(0, 1.45, 0.25)
	eye.light_color = Color("d85131")
	eye.light_energy = 1.5
	eye.omni_range = 4.2
	patrol.add_child(eye)


func _slab(dimensions: Vector3, at: Vector3, _kind: String, _color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	# Real lab surfaces (Greg, 2026-09-24), chosen by the slab's shape.
	mesh.material = LabSurface.for_slab(dimensions, at)
	visual.mesh = mesh
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	return body


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_discharge_breach_tool()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.15, 0.95)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()


func _physics_process(delta: float) -> void:
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	# Greg: *"maybe jumping and running should maybe be unlocked"*. They should.
	# This district walked at one speed with no way off the ground, which is
	# slow to cross and gives the player nothing to do about a machine that
	# follows them. `sprint` is already an action in the project; jump is Space,
	# read directly the way every other key in this scene is.
	var pace := WALK_SPEED * (SPRINT_SCALE if Input.is_action_pressed("sprint") else 1.0)
	player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 17.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 17.0 * delta)
	if player.is_on_floor():
		# The downward bias keeps them on slopes rather than skipping off the
		# ramps, so the jump has to be written after it rather than into it.
		player.velocity.y = -2.0
		if Input.is_key_pressed(KEY_SPACE):
			player.velocity.y = JUMP_SPEED
	else:
		player.velocity.y -= 18.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	patrol_phase += delta
	if breach_flash != null:
		breach_flash.light_energy = move_toward(breach_flash.light_energy, 0.0, delta * 18.0)
	_patrol_step(delta)
	_update_hud()


func _patrol_step(delta: float) -> void:
	if patrol == null or player == null:
		return
	if patrol_disabled:
		patrol_alert = false
		return
	patrol_attack_cooldown = maxf(0.0, patrol_attack_cooldown - delta)
	var difference := player.global_position - patrol.global_position
	# How far over its head you are, taken before the height is flattened out.
	#
	# The flattening is right for a chase across a floor and wrong for
	# everything else: it meant the sentinel could strike a player standing on
	# a walkway two metres above it, because to this function they were in the
	# same place. With the gantry there to walk on, that stopped being a corner
	# case and became the route.
	var overhead: float = player.global_position.y - patrol.global_position.y
	difference.y = 0.0
	var distance := difference.length()
	patrol_alert = distance < 11.0
	if not patrol_alert:
		patrol.position.x = sin(patrol_phase * 0.55) * 6.2
		patrol.rotation.y = cos(patrol_phase * 0.55) * 0.45
		return
	var action := RIVAL_TACTICS.approach(patrol_tactic, distance)
	if distance > 0.1:
		var direction := difference.normalized()
		if action == "close":
			patrol.global_position += direction * 1.55 * delta
		elif action == "withdraw":
			patrol.global_position -= direction * 1.1 * delta
		patrol.global_position.x = clampf(patrol.global_position.x, -12.1, 12.1)
		patrol.global_position.z = clampf(patrol.global_position.z, -35.0, 14.0)
		patrol.look_at(patrol.global_position + direction, Vector3.UP, true)
	# It follows you along the floor and cannot touch you while you are up
	# there. That is the trade the gantry offers: safe passage, in the open,
	# with the thing that wants you keeping pace underneath and waiting at the
	# bottom of the far ramp.
	if distance < 2.0 and patrol_attack_cooldown <= 0.0 and overhead <= GANTRY_CLEARANCE:
		patrol_attack_cooldown = 1.25
		blood = maxf(25.0, blood - 6.0)
		WorldHistory.record_event("lower_works_sentinel_strike", {"location": "lower_works", "damage": 6})


func _flat_distance(at: Vector3) -> float:
	var difference := at - player.global_position
	difference.y = 0
	return difference.length()


func _interact() -> void:
	if not fuse_taken and _flat_distance(FUSE_AT) <= 2.4:
		fuse_taken = true
		fuse_visual.visible = false
		WorldHistory.record_event("lower_works_lift_fuse_taken", {"location": "lower_works"})
		return
	if fuse_taken and not shortcut_open and _flat_distance(SHORTCUT_AT) <= 3.0:
		shortcut_open = true
		shortcut_gate.queue_free()
		# The fuse has a tactical job as well as a route job: shunting this
		# side circuit drops the only sentinel's local relay.  It turns the
		# optional walk to the west gallery into a real safer route, instead of
		# an impressive-looking gate that changes nothing once opened.
		_disable_sentinel("relay_disabled")
		WorldHistory.record_event("lower_works_shortcut_powered", {"location": "lower_works", "sentinel_relay": "disabled"})
		return
	if _flat_distance(EXIT_AT) <= 4.0 and fuse_taken:
		_record_pit_entry()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Interstitial.travel("res://underground_colosseum.tscn", "lower works elevator // the heat below is awake")


func _discharge_breach_tool() -> void:
	if not breach_tool_ready or patrol == null or patrol_disabled:
		return
	var separation := patrol.global_position - player.global_position
	separation.y = 0.0
	# The tool is an interruption, not a free long-range gun.  It has to be
	# used during the sentinel's actual pressure beat.
	if separation.length() > 8.0:
		return
	_disable_sentinel("breach_interrupted")
	if breach_flash != null:
		breach_flash.light_energy = 7.0
	WorldHistory.record_event("lower_works_sentinel_breached", {"location": "lower_works", "range": snappedf(separation.length(), 0.1)})


func _disable_sentinel(reason: String) -> void:
	patrol_disabled = true
	sentinel_disable_reason = reason
	if patrol == null:
		return
	patrol.set_meta("state", reason)
	var eye := patrol.get_node_or_null("Eye") as OmniLight3D
	if eye != null:
		eye.light_color = Color("4d7044")
		eye.light_energy = 0.35


func _record_pit_entry() -> void:
	if OPENING.reached("entered_pit"):
		return
	WorldHistory.begin_ledger_batch()
	OPENING.advance("entered_pit")
	FACILITY_TERRITORY.apply_event("opening_entered_pit")
	WorldHistory.amend_subject("player", {"status": "racked for a heat"})
	WorldHistory.record_event("lower_works_entered_pit", {"location": "lower_works"})
	WorldHistory.commit_ledger_batch()


func _update_hud() -> void:
	var guard_state := ("SENTINEL INTERRUPTED" if sentinel_disable_reason == "breach_interrupted" else "SENTINEL RELAY DOWN") if patrol_disabled else ("SENTINEL ENGAGED" if patrol_alert else "SENTINEL PATROL")
	status.text = "BLOOD %03d%%   PAIN 86   LOWER WORKS // %s" % [roundi(blood), guard_state]
	objective.text = "OBJECTIVE // " + ("REACH THE HEAT ELEVATOR" if fuse_taken else "FIND A LIFT FUSE")
	if not fuse_taken and _flat_distance(FUSE_AT) <= 2.4:
		prompt.text = "[E] TAKE LIFT FUSE"
	elif fuse_taken and not shortcut_open and _flat_distance(SHORTCUT_AT) <= 3.0:
		prompt.text = "[E] POWER SHORTCUT // DISABLE SENTINEL"
	elif fuse_taken and _flat_distance(EXIT_AT) <= 4.0:
		prompt.text = "[E] DESCEND TO THE UNDERGROUND HEAT"
	elif breach_tool_ready and patrol_alert and not patrol_disabled:
		prompt.text = "[LMB] DISCHARGE BREACH TOOL // INTERRUPT SENTINEL"
	else:
		prompt.text = "WASD MOVE   //   MOUSE LOOK   //   E INTERACT"
