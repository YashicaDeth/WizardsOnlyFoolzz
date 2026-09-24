extends Node3D

## THE GROWING FLOOR — the opening.
##
## The player surfaces inside a vat: submerged, umbilicals in, fluid over the
## glass, rows of other tanks receding into the dark. The tank voids and leaves
## them hanging on the umbilicals under END ALL SUFFERING; they tear the wires
## out of themselves one by one, the screen answers GET REVENGE, and the glass
## goes. They land on the grating in a spreading puddle, walk the aisle to the
## pit and are put in a car.
##
## Biomechanical register per ART-DIRECTION.md: ribbed vertebral arches,
## conduits that read as gut rather than pipe, wet everything. Built from
## primitives on the biopunk palette — art-directed now, authored later.

const OPENING := preload("res://systems/opening_director.gd")
const ANATOMY := preload("res://systems/anatomy_component.gd")
const VAT_INTAKE := preload("res://systems/vat_intake.gd")
const OPENING_AUDIO := preload("res://systems/opening_audio.gd")

const EYE_HEIGHT := 1.62
const VAT_POSITION := Vector3(0, 0, 0)
const AISLE_LENGTH := 34.0
## Tugs it takes to tear one umbilical out. The first ones only hurt.
const WIRE_TUGS := 3
## How long GET REVENGE holds before the glass goes.
const REVENGE_HOLD := 1.8
## The drained tank's clock time; the breach and floor beats count from here.
const DRAINED_AT := 8.6
const UMBILICAL_LINKS := 13

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
var title: Label
var wired_clock := 0.0
var revenge_at := -1.0
var jolt := 0.0

# 0 submerged, 1 voiding, 2 breach, 3 floor, 4 aisle
const BEATS := [
	{"at": 1.4, "text": "Something is in your throat. It is not yours."},
	{"at": 5.2, "text": "TANK 0C-7 // CYCLE ABORTED — VOIDING"},
	{"at": 9.6, "text": "HANDLER: \"That one's finished growing. Rack it for the heat.\""},
	{"at": 14.5, "text": "HANDLER: \"Debt's in the meat, friend. Win a round and it's yours to keep.\""},
	# K3.2. "The opening reframed: CellOutz grew you, which is why the debt is
	# in the meat" — DESIGN/COSMOLOGY.md. The line above already said the debt
	# was in the meat; nothing before this said whose meat it started as.
	{"at": 16.5, "text": "HANDLER: \"CellOutz grew you. CellOutz owns what it grew. Read your own contract sometime.\""},
	{"at": 19.0, "text": "Walk the aisle. The car is at the end of it."},
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
	_build_player()
	_build_intake()
	_build_title()
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


func _on_intake_filed(_state: Dictionary) -> void:
	if intake == null:
		return
	intake.queue_free()
	intake = null
	clock = 0.0
	line_index = -1
	phase = "submerged"
	OPENING.advance("woke")
	WorldHistory.record_event("opening_woke", {"location": "growing_floor"})


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
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
	root.set_meta("index", index)
	# Drawn as a chain of segments so it reads as gut, not as a straight pipe.
	for segment in UMBILICAL_LINKS:
		var t := float(segment) / float(UMBILICAL_LINKS - 1)
		var link := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.055 - t * 0.018
		mesh.height = mesh.radius * 2.2
		mesh.material = WorldLook.surface(Color("4a3128") if segment % 2 == 0 else Color("38261f"), "flesh", index * 7 + segment)
		link.mesh = mesh
		root.add_child(link)
	_route_umbilical(root, VAT_POSITION + Vector3(0, 1.45, 0), 0.16)
	root.set_meta("pulls", 0)
	return root


## Lays a wire from its anchor in the tank collar down into the body at
## `socket`, spread `spread` around it so the four do not enter at one point.
func _route_umbilical(root: Node3D, socket: Vector3, spread: float) -> void:
	var angle := TAU * float(root.get_meta("index", 0)) / 4.0 + 0.4
	var anchor := VAT_POSITION + Vector3(cos(angle) * 0.62, 3.05, sin(angle) * 0.62)
	var target := socket + Vector3(cos(angle) * spread, 0, sin(angle) * spread)
	var count := root.get_child_count()
	for segment in count:
		var t := float(segment) / float(maxi(1, count - 1))
		var sway := sin(t * PI) * 0.09
		(root.get_child(segment) as Node3D).position = anchor.lerp(target, t) + Vector3(sin(t * 5.0) * sway, 0, cos(t * 4.0) * sway)


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
		# TorusMesh already lies flat around Y; tilting it stood each collar
		# ring up as a hoop through the tank, a pillar from the inside.
		ring.position = VAT_POSITION + Vector3(0, height, 0)
		add_child(ring)

	var glow := OmniLight3D.new()
	glow.position = VAT_POSITION + Vector3(0, 1.6, 0)
	glow.light_color = Color("6fd39a")
	glow.light_energy = 3.4
	glow.omni_range = 6.0
	add_child(glow)


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
	for bay in 11:
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if phase == "wired":
			_tug_wire(_aimed_wire())
		else:
			_interact()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and phase != "submerged":
		yaw -= event.relative.x * 0.0026
		# The wires come down from above; hanging in them you have to look up.
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.2, 1.4 if phase == "wired" else 1.0)


func _physics_process(delta: float) -> void:
	if phase == "intake":
		if opening_audio != null:
			opening_audio.set_phase("intake")
		return
	if phase == "wired":
		# The handler's clock stops while you hang here. Nothing moves on
		# until you do it yourself.
		wired_clock += delta
		_update_wired(delta)
		_update_shards(delta)
		_update_hud()
		return
	clock += delta
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
			var t := clampf(clock / 5.2, 0.0, 1.0)
			fade.color.a = clampf(1.0 - clock / 2.2, 0.0, 1.0)
			submerge_tint.color.a = 0.42
			camera.rotation = Vector3(sin(clock * 0.7) * 0.09 - 0.1, sin(clock * 0.4) * 0.16, cos(clock * 0.55) * 0.07)
			camera.fov = 92.0 + sin(clock * 1.6) * 3.5
			player.position.y = 1.35 + sin(clock * 0.8) * 0.06
			opening_audio.set_phase("submerged", t)
			if clock >= 5.2:
				phase = "voiding"
				opening_audio.cue("drain")
		"voiding":
			# The column drops. You come down with it.
			var t := clampf((clock - 5.2) / 3.4, 0.0, 1.0)
			var height := lerpf(2.9, 0.25, ease(t, 0.7))
			fluid.mesh.height = height
			fluid.position.y = height * 0.5
			submerge_tint.color.a = lerpf(0.42, 0.0, t)
			camera.fov = lerpf(92.0, 78.0, t)
			player.position.y = lerpf(1.35, 0.95, ease(t, 0.6))
			camera.rotation = Vector3(sin(clock * 0.9) * 0.06 * (1.0 - t) - 0.1 * (1.0 - t), sin(clock * 0.5) * 0.1 * (1.0 - t), 0)
			opening_audio.set_phase("voiding", t)
			if clock >= DRAINED_AT:
				_begin_wired()
		"floor":
			# On hands and knees on the grating.
			var t := clampf((clock - DRAINED_AT) / 4.2, 0.0, 1.0)
			if title.visible:
				title.modulate.a = clampf(1.0 - t * 2.5, 0.0, 1.0)
				title.visible = title.modulate.a > 0.0
			player.position.y = lerpf(0.62, EYE_HEIGHT, ease(t, 0.45))
			camera.rotation = Vector3(lerpf(-0.95, 0.0, ease(t, 0.5)), 0, lerpf(0.22, 0.0, ease(t, 0.5)))
			camera.fov = lerpf(78.0, 74.0, t) + sin(clock * 2.4) * (1.0 - t) * 4.0
			if t >= 1.0:
				phase = "aisle"
				can_move = true
				yaw = 0.0
				pitch = 0.0


## The drain leaves you hanging in an empty tank with the wires still in you.
## Ending it is the first thing the player chooses to do.
func _begin_wired() -> void:
	phase = "wired"
	clock = DRAINED_AT
	wired_clock = 0.0
	revenge_at = -1.0
	yaw = 0.0
	pitch = 0.5
	# Drained, the body has sunk and the wires hang taut into its chest.
	player.position.y = 0.95
	for cable in umbilicals:
		_route_umbilical(cable, player.position + Vector3(0, -0.38, 0), 0.2)
	title.text = "END ALL SUFFERING"
	title.modulate.a = 1.0
	title.visible = true
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
		# The title flickers like a readout that has been saying this for years.
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
	subtitle.text = ""
	opening_audio.cue("revenge")
	WorldHistory.update_subject("player", {
		"wounds": ["tank scarring", "raw throat", "torn wire sockets"],
		"memory": "Tore its own wires out in tank 0C-7 and came out of it wanting somebody to pay.",
	}, "opening_wires_ripped")
	WorldHistory.record_event("opening_wires_ripped", {"tank": "0C-7"})


func _breach() -> void:
	phase = "floor"
	clock = maxf(clock, DRAINED_AT)
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
	camera.position.y = sin(Time.get_ticks_msec() * 0.0055) * stride * 0.016
	camera.rotation.z = sin(Time.get_ticks_msec() * 0.0027) * stride * 0.008


func _interact() -> void:
	if not can_move:
		return
	var to_door := door_marker.global_position - player.global_position
	to_door.y = 0.0
	if to_door.length() > 3.4:
		return
	opening_audio.cue("door")
	OPENING.advance("entered_pit")
	WorldHistory.update_subject("player", {"status": "racked for a heat"}, "opening_entered_pit")
	WorldHistory.record_event("opening_entered_pit", {"location": "growing_floor"})
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Interstitial.travel("res://rift_derby.tscn", "racked for the heat // debt is in the meat")


func _update_hud() -> void:
	var snapshot: Dictionary = anatomy.call("snapshot")
	vitals.text = "BLOOD %d%%   PAIN %02d   %s" % [
		roundi(float(snapshot.blood) / maxf(1.0, float(snapshot.blood_capacity)) * 100.0),
		int(snapshot.pain),
		"WIRED" if phase == "wired" else "DECANTED",
	]
	if phase == "wired":
		if revenge_at >= 0.0:
			prompt.text = ""
		elif _aimed_wire() != null:
			prompt.text = "[E] RIP IT OUT   %d LEFT" % umbilicals.size()
		else:
			prompt.text = "MOUSE LOOK   FIND THE WIRES   %d LEFT" % umbilicals.size()
		return
	if not can_move:
		prompt.text = ""
		return
	var to_door := door_marker.global_position - player.global_position
	to_door.y = 0.0
	prompt.text = "[E] INTO THE PIT" if to_door.length() <= 3.4 else "WASD MOVE   MOUSE LOOK   WALK THE AISLE"
