extends Node3D
const LOOK := preload("res://systems/look_settings.gd")

## THE OLD DRAINS: the second way out of Sublevel 0C (Greg, 24 September:
## "a lower level of tunnels and drain networks, super old, that brings you
## out in a different part of the map, so the overworld begins differently
## depending on how you left"). Reached through a hatch in the Lower Works.
##
## It walks the route FacilityRoutes already describes as the maintenance
## ascent -- waste gallery, maintenance cistern, storm outfall -- which had no
## scene behind it. Crossing into each part files it with the route graph, and
## climbing out of the outfall hands the Hunt its authored arrival point and
## relationship changes, the same way every facility exit does.
##
## Built from primitives on the facility's own scanned concrete and rust,
## darkened and stained so it reads older than anything above it. Art-directed
## now, authored later.

const OPENING := preload("res://systems/opening_director.gd")
const FACILITY_ROUTES := preload("res://systems/facility_routes.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")

const ROUTE := FACILITY_ROUTES.ROUTE_STEALTH
const ENTRY := Vector3(0, 1.0, 2.0)
## Where each part of the route begins, walking -z.
const CISTERN_Z := -26.0
const OUTFALL_Z := -46.0
const EXIT_AT := Vector3(0, 0.0, -62.0)
const TUNNEL_WIDTH := 6.0
const TUNNEL_HEIGHT := 4.2
const CISTERN_WIDTH := 16.0
const CISTERN_HEIGHT := 7.0
const WALK_SPEED := 3.4
const EXIT_REACH := 3.2
const WORLD_BREAK := preload("res://systems/world_break.gd")
## Things the breach tool breaks (`DESIGN/GOAL_LOOP_2.md` 0.2): dumped on the
## gallery walkways against the wall, between the ribs (every 4.2 m from
## z 1.0), leaving a metre and more of walkway beside each.
const PROPS := [
	["barrel", "drains_barrel_1", Vector3(2.55, 0, -1.1), 0.0],
	["crate", "drains_crate_1", Vector3(-2.55, 0, -5.0), 0.0],
	["crate", "drains_crate_2", Vector3(-2.5, 0, -5.9), 0.3],
	["locker", "drains_locker", Vector3(2.62, 0, -9.5), -PI * 0.5],
	["chair", "drains_chair", Vector3(-2.4, 0, -13.7), PI * 0.5],
	["barrel", "drains_barrel_2", Vector3(2.55, 0, -17.9), 0.0],
	["jar", "drains_jar", Vector3(-2.6, 0, -17.6), 0.0],
	["monitor", "drains_monitor", Vector3(-2.55, 0, -22.1), 0.8],
]

const DISTRICT_LABELS := {
	"waste_gallery": "WASTE GALLERY",
	"maintenance_cistern": "MAINTENANCE CISTERN",
	"storm_outfall": "STORM OUTFALL",
}

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.05
var objective: Label
var status: Label
var prompt: Label
var osd: BodyCamOSD
var district := ""
var district_timer := 0.0
var surfaced := false
var surface_requested := false
## Greg, 24 September: something hunts you down here, "a bingyanger, freed
## long ago". See `systems/drain_stalker.gd`.
var stalker: DrainStalker
var sight: Node


func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("old_drains")
	add_child(environment)
	_build_gallery()
	_build_cistern()
	_build_outfall()
	for spec in PROPS:
		BreakableProp.place(self, spec[0], spec[1], spec[2], spec[3])
	_build_player()
	_build_stalker()
	_build_hud()
	_build_sight()
	# The route begins when you drop in. A world that already started it (a
	# resumed run) keeps its steps; begin() refuses a second start.
	if str(FACILITY_ROUTES.ensure().get("active_route", "")) != ROUTE:
		FACILITY_ROUTES.begin(ROUTE)
	WorldHistory.record_event("old_drains_entered", {"location": "old_drains"})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _stained(role: String, tint: Color) -> StandardMaterial3D:
	var material := LabSurface.material(role).duplicate() as StandardMaterial3D
	material.albedo_color = tint
	return material


func _slab(dimensions: Vector3, at: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
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


func _water(size: Vector2, at: Vector3) -> void:
	# The same wet dark the spilled tank uses: one highlight, no grain.
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("0c1210")
	material.roughness = 0.05
	material.metallic = 0.3
	material.metallic_specular = 0.8
	plane.material = material
	water.mesh = plane
	water.position = at
	add_child(water)


func _lamp(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	add_child(lamp)


## A long brick-and-concrete gallery with a sunk channel down its middle and a
## walkway either side. Everything that flowed out of the facility went this way.
func _build_gallery() -> void:
	var wall := _stained("wall", Color(0.36, 0.33, 0.27))
	var floor_material := _stained("wall", Color(0.30, 0.28, 0.23))
	var length := absf(CISTERN_Z) + 6.0
	var mid := (4.0 + CISTERN_Z) * 0.5
	# Behind the drop point, so the hatch is a dead end, not a void.
	_slab(Vector3(TUNNEL_WIDTH + 1.0, TUNNEL_HEIGHT + 1.0, 0.5), Vector3(0, TUNNEL_HEIGHT * 0.5, 4.2), wall)
	for side in [-1.0, 1.0]:
		# Walkways, raised off the channel.
		_slab(Vector3(2.0, 0.4, length), Vector3(side * 2.0, -0.2, mid), floor_material)
		_slab(Vector3(0.5, TUNNEL_HEIGHT, length), Vector3(side * (TUNNEL_WIDTH * 0.5 + 0.25), TUNNEL_HEIGHT * 0.5, mid), wall)
	# The channel bed sits lower; the water lies in it.
	_slab(Vector3(2.0, 0.4, length), Vector3(0, -0.55, mid), floor_material)
	_water(Vector2(2.0, length), Vector3(0, -0.32, mid))
	_slab(Vector3(TUNNEL_WIDTH + 1.0, 0.4, length), Vector3(0, TUNNEL_HEIGHT + 0.2, mid), wall)
	# Ribs every few metres: the vault is old masonry, not a poured pipe.
	var rust := _stained("rust", Color(0.55, 0.45, 0.36))
	for rib in 7:
		var z := 1.0 - float(rib) * 4.2
		for side in [-1.0, 1.0]:
			var pier := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.35, TUNNEL_HEIGHT, 0.4)
			mesh.material = rust
			pier.mesh = mesh
			pier.position = Vector3(side * (TUNNEL_WIDTH * 0.5 - 0.1), TUNNEL_HEIGHT * 0.5, z)
			add_child(pier)
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(TUNNEL_WIDTH, 0.3, 0.4)
		beam_mesh.material = rust
		beam.mesh = beam_mesh
		beam.position = Vector3(0, TUNNEL_HEIGHT - 0.15, z)
		add_child(beam)
		# Every rib, not every other: the first render measured 8.4/255 here,
		# darker than the Lower Works Greg already called too dark.
		_lamp(Vector3(0, TUNNEL_HEIGHT - 0.6, z - 1.0), Color("a99a62"), 4.0, 10.0)


## The cistern opens out: a tall hall of standing water crossed by one
## causeway, the only way on.
func _build_cistern() -> void:
	var wall := _stained("wall", Color(0.32, 0.31, 0.27))
	var floor_material := _stained("wall", Color(0.28, 0.27, 0.23))
	var length := absf(OUTFALL_Z - CISTERN_Z)
	var mid := (CISTERN_Z + OUTFALL_Z) * 0.5
	# The end walls either side of the openings in and out.
	var shoulder := (CISTERN_WIDTH - TUNNEL_WIDTH) * 0.5
	for end_z in [CISTERN_Z, OUTFALL_Z]:
		for side in [-1.0, 1.0]:
			_slab(Vector3(shoulder, CISTERN_HEIGHT, 0.5), Vector3(side * (TUNNEL_WIDTH * 0.5 + shoulder * 0.5), CISTERN_HEIGHT * 0.5, end_z), wall)
		_slab(Vector3(TUNNEL_WIDTH, CISTERN_HEIGHT - TUNNEL_HEIGHT, 0.5), Vector3(0, TUNNEL_HEIGHT + (CISTERN_HEIGHT - TUNNEL_HEIGHT) * 0.5, end_z), wall)
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.5, CISTERN_HEIGHT, length), Vector3(side * (CISTERN_WIDTH * 0.5 + 0.25), CISTERN_HEIGHT * 0.5, mid), wall)
	_slab(Vector3(CISTERN_WIDTH, 0.4, length), Vector3(0, CISTERN_HEIGHT + 0.2, mid), wall)
	# Deep floor under the water, and the causeway above it.
	_slab(Vector3(CISTERN_WIDTH, 0.4, length), Vector3(0, -1.4, mid), floor_material)
	_water(Vector2(CISTERN_WIDTH, length), Vector3(0, -0.45, mid))
	_slab(Vector3(2.6, 0.4, length + 0.6), Vector3(0, -0.2, mid), floor_material)
	var rust := _stained("rust", Color(0.5, 0.42, 0.34))
	for row in 3:
		for side in [-1.0, 1.0]:
			var column := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.45
			mesh.bottom_radius = 0.55
			mesh.height = CISTERN_HEIGHT + 1.4
			mesh.material = rust
			column.mesh = mesh
			column.position = Vector3(side * 4.2, CISTERN_HEIGHT * 0.5 - 0.7, CISTERN_Z - 4.0 - float(row) * 6.0)
			add_child(column)
	# Measured 5.3/255 on the first render: one high lamp does not reach a
	# hall this size. It gets a second, and working lamps along the causeway.
	_lamp(Vector3(0, CISTERN_HEIGHT - 1.0, mid + 5.0), Color("7f9f7a"), 9.0, 18.0)
	_lamp(Vector3(0, CISTERN_HEIGHT - 1.0, mid - 5.0), Color("7f9f7a"), 9.0, 18.0)
	for index in 3:
		var side := -1.0 if index % 2 == 0 else 1.0
		_lamp(Vector3(side * 3.0, 2.0, CISTERN_Z - 4.0 - float(index) * 6.0), Color("9a7a44"), 5.0, 9.0)


## The outfall climbs toward daylight and ends at a rusted grate onto the
## surface. The light at the end is the objective.
func _build_outfall() -> void:
	var wall := _stained("wall", Color(0.38, 0.36, 0.30))
	var floor_material := _stained("wall", Color(0.33, 0.31, 0.26))
	var length := absf(EXIT_AT.z - OUTFALL_Z) + 2.0
	var mid := (OUTFALL_Z + EXIT_AT.z) * 0.5 - 1.0
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.5, TUNNEL_HEIGHT, length), Vector3(side * (TUNNEL_WIDTH * 0.5 + 0.25), TUNNEL_HEIGHT * 0.5, mid), wall)
	_slab(Vector3(TUNNEL_WIDTH, 0.4, length), Vector3(0, -0.2, mid), floor_material)
	_slab(Vector3(TUNNEL_WIDTH + 1.0, 0.4, length), Vector3(0, TUNNEL_HEIGHT + 0.2, mid), wall)
	_water(Vector2(TUNNEL_WIDTH - 1.0, length), Vector3(0, 0.02, mid))
	# The grate: bars across the mouth, the day behind them.
	var rust := _stained("rust", Color(0.6, 0.48, 0.36))
	for bar in 9:
		var rod := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.05
		mesh.height = TUNNEL_HEIGHT
		mesh.material = rust
		rod.mesh = mesh
		rod.position = Vector3(-2.4 + float(bar) * 0.6, TUNNEL_HEIGHT * 0.5, EXIT_AT.z - 1.4)
		add_child(rod)
	var day := MeshInstance3D.new()
	var glow := QuadMesh.new()
	glow.size = Vector2(TUNNEL_WIDTH, TUNNEL_HEIGHT)
	var day_material := StandardMaterial3D.new()
	day_material.albedo_color = Color("dfe6d2")
	day_material.emission_enabled = true
	day_material.emission = Color("dfe6d2")
	day_material.emission_energy_multiplier = 2.4
	day_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material = day_material
	day.mesh = glow
	day.position = Vector3(0, TUNNEL_HEIGHT * 0.5, EXIT_AT.z - 2.0)
	add_child(day)
	_slab(Vector3(TUNNEL_WIDTH + 1.0, TUNNEL_HEIGHT + 1.0, 0.5), Vector3(0, TUNNEL_HEIGHT * 0.5, EXIT_AT.z - 2.3), wall)
	_lamp(Vector3(0, TUNNEL_HEIGHT - 0.8, EXIT_AT.z - 1.0), Color("e8efe0"), 7.0, 16.0)


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


## K wizard eyes / J depth scan: the thing in the water, through the walls.
func _build_sight() -> void:
	sight = preload("res://systems/signal_sight.gd").new()
	sight.name = "SignalSight"
	add_child(sight)
	sight.call("setup", camera)
	sight.set("enabled", true)
	sight.set("bodies", func() -> Array:
		return [stalker.global_position] if stalker != null and is_instance_valid(stalker) else [])
	# Greg, 26 September: a stash in the gallery wall, found in K or J.
	caches.append(HIDDEN_CACHE.place_stash(self, sight, "old_drains_stash", Vector3(TUNNEL_WIDTH * 0.5, 1.5, -8.0), Vector3.LEFT))
	sight.connect("hidden_seen", func(id: String) -> void: HIDDEN_CACHE.mark_found(caches, id))


func _build_stalker() -> void:
	stalker = DrainStalker.new()
	stalker.name = "DrainBingyanger"
	add_child(stalker)
	# Along the walkways and round the cistern, starting far enough in that
	# the drop point is quiet.
	var round: Array[Vector3] = [
		Vector3(-2.0, 0.0, -14.0), Vector3(2.0, 0.0, -22.0), Vector3(-4.5, 0.0, -32.0),
		Vector3(4.5, 0.0, -40.0), Vector3(2.0, 0.0, -24.0), Vector3(-2.0, 0.0, -8.0),
	]
	stalker.build(round)
	stalker.bind(player)
	# Greg, 24 September: it can kill you now, and you wake in the vat.
	stalker.struck.connect(_on_stalker_struck)
	rebirth_site = RebirthSite.new()
	add_child(rebirth_site)
	rebirth_site.setup("old_drains", player)


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
	osd = BodyCamOSD.new()
	osd.name = "BodyCamOSD"
	layer.add_child(osd)
	osd.adopt(status, objective, prompt, "BELOW 0C  //  OLD DRAINS")
	osd.camera = camera


## The attack button with the ram in hand: it breaks what it meets, and still
## stuns the stalker when that is close enough.
func _swing_breach_tool() -> void:
	if not VatRebirth.carries("BREACH TOOL"):
		return
	WORLD_BREAK.swing(camera, FacilityGuardPost.RAM_DAMAGE, "breach_tool", player)
	stalker.discharge(player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked: bool = event.pressed
		if clicked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_swing_breach_tool()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= LOOK.dx(event.relative) * 0.0026
		pitch = clampf(pitch - LOOK.dy(event.relative) * 0.0024, -1.15, 0.95)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		jump_or_climb()


## Greg, 26 September: "you can't jump out of here in the sewers, it's dumb."
## SPACE jumps; facing a ledge up to JumpClimb.MANTLE_REACH above your feet (the
## walkway lip out of the channel, the causeway out of the deep cistern) it
## pulls you up onto it instead. Returns what it did.
const JUMP_CLIMB := preload("res://systems/jump_climb.gd")
const HIDDEN_CACHE := preload("res://systems/hidden_cache.gd")
var caches: Array = []


func jump_or_climb() -> String:
	return JUMP_CLIMB.press(player, yaw, 1.0, "drains_climbed_out")


func _physics_process(delta: float) -> void:
	if JUMP_CLIMB.busy(player):
		camera.rotation = Vector3(pitch, 0, 0)
		_update_hud()
		return
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	var creeping := Input.is_action_pressed("crouch")
	var pace := WALK_SPEED * (1.6 if Input.is_action_pressed("sprint") else 1.0) * (0.45 if creeping else 1.0)
	camera.position.y = move_toward(camera.position.y, 0.3 if creeping else 0.77, delta * 3.0)
	# Greg, 26 September: sprint + Ctrl slides (loud: it hunts by sound).
	if Input.is_action_just_pressed("crouch"):
		JUMP_CLIMB.try_slide(player, yaw, Input.is_action_pressed("sprint"))
	if not JUMP_CLIMB.slide_step(player, delta):
		player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 16.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 16.0 * delta)
	JUMP_CLIMB.fall(player, delta)
	player.move_and_slide()
	var fall_hurt := JUMP_CLIMB.landing_damage(player)
	if fall_hurt > 0.0:
		stalker.blood = maxf(1.0, stalker.blood - fall_hurt)
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	_file_progress()
	district_timer = maxf(0.0, district_timer - delta)
	_update_hud()


## Each part of the drain is filed with the route graph the moment you cross
## into it, in order. The outfall is filed by climbing out, not by walking up.
func _file_progress() -> void:
	var z := player.global_position.z
	if z < ENTRY.z - 1.0:
		_enter("waste_gallery")
	if z < CISTERN_Z - 1.0:
		_enter("maintenance_cistern")


func _enter(district_id: String) -> void:
	var steps: Array = FACILITY_ROUTES.ensure().get("route_steps", [])
	if steps.has(district_id):
		return
	if FACILITY_ROUTES.traverse(district_id):
		district = district_id
		district_timer = 3.0


var rebirth_site: RebirthSite


func _on_stalker_struck(_damage: float) -> void:
	if stalker.blood <= 0.0:
		rebirth_site.die("taken by the bingyanger in the old drains", DrainStalker.SUBJECT_ID)


func _interact() -> void:
	if not rebirth_site.try_recover().is_empty():
		return
	if HIDDEN_CACHE.open_near(caches, player.global_position, sight) != "":
		return
	if surfaced or _flat_distance(EXIT_AT) > EXIT_REACH:
		return
	_enter("waste_gallery")
	_enter("maintenance_cistern")
	if not FACILITY_ROUTES.traverse("storm_outfall"):
		return
	surfaced = true
	WorldHistory.begin_ledger_batch()
	OPENING.advance("left_facility")
	FACILITY_TERRITORY.apply_event("facility_surfaced")
	WorldHistory.amend_subject("player", {"status": "out through the storm outfall", "left_facility_by": "old_drains"})
	WorldHistory.record_event("old_drains_surfaced", {"location": "storm_outfall"})
	WorldHistory.commit_ledger_batch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	surface_requested = true
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Interstitial.travel("res://bone_yard_hunt.tscn", "storm outfall // out into the ashbloom expanse")


func _flat_distance(at: Vector3) -> float:
	var difference := at - player.global_position
	difference.y = 0.0
	return difference.length()


func _update_hud() -> void:
	var hunted := "SOMETHING IS HUNTING YOU" if stalker.state == "hunt" else ("IT IS STUNNED" if stalker.state == "stunned" else "SOMETHING IS DOWN HERE")
	status.text = "BLOOD %03d%%   OLD DRAINS // %s   //   %s" % [roundi(stalker.blood), str(DISTRICT_LABELS.get(district, "BELOW THE LOWER WORKS")), hunted]
	objective.text = "OBJECTIVE // FOLLOW THE WATER OUT"
	if surfaced:
		prompt.text = ""
	elif not rebirth_site.nearest().is_empty():
		prompt.text = "[E] TAKE BACK WHAT YOUR OLD BODY HOLDS"
	elif not HIDDEN_CACHE.nearest(caches, player.global_position).is_empty():
		prompt.text = "[E] OPEN THE HATCH"
	elif _flat_distance(EXIT_AT) <= EXIT_REACH:
		prompt.text = "[E] FORCE THE GRATE // CLIMB OUT"
		osd.point_at(EXIT_AT + Vector3(0, 1.8, -1.2))
	elif district_timer > 0.0:
		prompt.text = str(DISTRICT_LABELS.get(district, ""))
	else:
		prompt.text = "WASD MOVE   //   SPACE JUMP / CLIMB   //   CTRL CREEP, IT HUNTS BY SOUND   //   E INTERACT" + ("   //   LMB DISCHARGE THE BREACH TOOL" if VatRebirth.carries("BREACH TOOL") else "")
