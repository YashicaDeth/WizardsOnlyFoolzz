extends Node3D

## The mechanics lab (DESIGN/BUILD_BRIEFS.md, job 1). Greg: "a demo dev test
## area you can just walk around… here's how the liquid physics, here's how
## the weather works… how the destruction physics works with weapons… then we
## apply that to the actual full game."
##
## A 40 m greybox yard: the north half (-Z) under a roof, the south half open
## to the sky, so weather can be compared under cover and out of it. Five
## stations, each a plinth with a label and one button (USE), each running the
## same system the game runs. Free walk on the facility's own body (JumpClimb,
## BodyCam); the four v0.1 weapons through `HunterArsenal` and `Ballistics`;
## START (pad) or TAB opens a menu that takes you to any plinth.
##
## Nothing here ships: `Start-MechanicsLab.ps1` opens it, the game does not.

const JUMP_CLIMB := preload("res://systems/jump_climb.gd")
const BODY_CAM := preload("res://systems/body_cam_feel.gd")
const LOOK := preload("res://systems/look_settings.gd")
const WORLD_BREAK := preload("res://systems/world_break.gd")
const LIQUID := preload("res://lab/stations/liquid_station.gd")
const WEATHER := preload("res://lab/stations/weather_station.gd")
const DESTRUCTION := preload("res://lab/stations/destruction_station.gd")
const BODIES := preload("res://lab/stations/bodies_station.gd")

const HALF := 20.0
const ROOF_Y := 5.5
const WALK := 3.4
const SPRINT := 1.6
const START := Vector3(0, 1.0, 17.0)
## The v0.1 weapons (job 3), in the order NEXT WEAPON steps through them.
const WEAPONS := ["shiv", "sword", "sidearm", "sniper"]

var player: CharacterBody3D
var camera: Camera3D
var sun: DirectionalLight3D
var ballistics: Ballistics
var arsenal: HunterArsenal
var yaw := 0.0
var pitch := -0.05
var stations: Array[Dictionary] = []
var liquid: Node3D
var weather: Node3D
var destruction: Node3D
var bodies: Node3D
var menu_open := false
var menu_index := 0
var last_note := ""
var last_hit: Dictionary = {}
var _hud: Label
var _prompt: Label
var _menu: Label
var _note_age := 0.0


func _ready() -> void:
	_build_world()
	liquid = _station(LIQUID, Vector3(-12, 0, -8), Vector3(0, 0, 0))
	bodies = _station(BODIES, Vector3(10, 0, -8), Vector3(0, 0, 0))
	weather = _station(WEATHER, Vector3(0, 0, 2), Vector3(0, 0, 0))
	destruction = _station(DESTRUCTION, Vector3(-12, 0, 11), Vector3(0, 0, 0))
	_vehicle_pad(Vector3(12, 0, 12))
	_build_player()
	ballistics = Ballistics.new()
	add_child(ballistics)
	ballistics.round_hit.connect(_on_round_hit)
	arsenal = HunterArsenal.new()
	arsenal.name = "Arsenal"
	add_child(arsenal)
	arsenal.acquire_melee("shiv")
	arsenal.acquire_sniper()
	arsenal.select_weapon("sword")
	_build_hud()
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- the yard ----------------------------------------------------------------

func _build_world() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("3b3a3f")
	sky_material.sky_horizon_color = Color("8a7a68")
	sky_material.ground_horizon_color = Color("4a3d31")
	sky_material.ground_bottom_color = Color("1a1511")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssr_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	sun.light_energy = 1.4
	sun.light_color = Color("ffe2c0")
	sun.shadow_enabled = true
	add_child(sun)

	# Covered half: a concrete slab under a roof on pillars.
	var concrete := _surface(Color("4a4640"), 0.85)
	_solid(Vector3(HALF * 2.0, 0.4, HALF), Vector3(0, -0.2, -HALF * 0.5), concrete)
	# Open half: packed dirt, the ground rounds dig into (`GroundHole`). Its
	# material is the one the weather wets.
	var dirt := _surface(Color("5a4a3a"), 0.95)
	var ground := _solid(Vector3(HALF * 2.0, 0.4, HALF), Vector3(0, -0.2, HALF * 0.5), dirt)
	ground.add_to_group(GroundHole.GROUP)
	var roof_material := _surface(Color("2b2825"), 0.8)
	_solid(Vector3(HALF * 2.0, 0.3, HALF), Vector3(0, ROOF_Y + 0.15, -HALF * 0.5), roof_material)
	var pillar := _surface(Color("37332e"), 0.8)
	for x in [-18.0, -9.0, 0.0, 9.0, 18.0]:
		_solid(Vector3(0.5, ROOF_Y, 0.5), Vector3(x, ROOF_Y * 0.5, -0.4), pillar)
	# Perimeter: block walls, high enough to keep you in and low enough to see
	# the sky over.
	var block := _surface(Color("3d3934"), 0.9)
	_solid(Vector3(HALF * 2.0, 3.0, 0.4), Vector3(0, 1.5, -HALF), block)
	_solid(Vector3(HALF * 2.0, 3.0, 0.4), Vector3(0, 1.5, HALF), block)
	_solid(Vector3(0.4, 3.0, HALF * 2.0), Vector3(-HALF, 1.5, 0), block)
	_solid(Vector3(0.4, 3.0, HALF * 2.0), Vector3(HALF, 1.5, 0), block)
	# Particle colliders, so rain stops on the roof and spilt fluid lands.
	_particle_floor(Vector3(HALF * 2.0, 1.0, HALF * 2.0), Vector3(0, -0.5, 0))
	_particle_floor(Vector3(HALF * 2.0, 0.6, HALF), Vector3(0, ROOF_Y + 0.3, -HALF * 0.5))
	# Under the roof it is dark at noon; work lamps over each covered station.
	for at in [Vector3(-12, 4.6, -9), Vector3(10, 4.6, -9), Vector3(0, 4.6, -4), Vector3(-2, 4.6, -12), Vector3(14, 4.6, -15)]:
		var lamp := OmniLight3D.new()
		lamp.position = at
		lamp.light_color = Color("ffb27a")
		lamp.light_energy = 2.2
		lamp.omni_range = 10.0
		add_child(lamp)
	set_meta("open_materials", [dirt, block])


func _surface(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


func _solid(size: Vector3, at: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	return body


func _particle_floor(size: Vector3, at: Vector3) -> void:
	var collider := GPUParticlesCollisionBox3D.new()
	collider.size = size
	collider.position = at
	add_child(collider)


## A station node at `at`, its plinth at `at + plinth`, facing +Z (the
## station's content stands behind its plinth, to the north).
func _station(script: GDScript, at: Vector3, plinth: Vector3) -> Node3D:
	var station: Node3D = script.new()
	station.name = str(script.get("TITLE")).capitalize().replace(" ", "")
	station.position = at
	add_child(station)
	station.build(self)
	_plinth(station.to_global(plinth), str(script.get("TITLE")), str(script.get("VERB")))
	stations.append({"node": station, "title": str(script.get("TITLE")), "plinth": station.to_global(plinth)})
	if script == WEATHER:
		for material in get_meta("open_materials"):
			station.wet_materials.append(material)
	return station


func _plinth(at: Vector3, title: String, verb: String) -> void:
	var stone := _surface(Color("2a2420"), 0.7)
	_solid(Vector3(0.6, 1.0, 0.6), at + Vector3(0, 0.5, 0), stone)
	var button := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 0.12
	cap.bottom_radius = 0.14
	cap.height = 0.06
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("a8281a")
	glow.emission_enabled = true
	glow.emission = Color("e0442a")
	glow.emission_energy_multiplier = 1.6
	cap.material = glow
	button.mesh = cap
	button.position = at + Vector3(0, 1.03, 0)
	add_child(button)
	var label := Label3D.new()
	label.text = "%s\n%s" % [title, verb]
	label.font_size = 56
	label.pixel_size = 0.006
	label.modulate = Color("e0b07a")
	label.outline_modulate = Color("120c09")
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = at + Vector3(0, 1.55, 0)
	add_child(label)


## Station 5: an empty marked pad for the driving work that comes later.
func _vehicle_pad(at: Vector3) -> void:
	var paint := _surface(Color("b0552a"), 0.6)
	for side in [-1.0, 1.0]:
		_stripe(at + Vector3(side * 4.0, 0.01, 0), Vector3(0.18, 0.02, 8.18), paint)
		_stripe(at + Vector3(0, 0.01, side * 4.0), Vector3(8.18, 0.02, 0.18), paint)
	_stripe(at + Vector3(0, 0.01, 0), Vector3(0.18, 0.02, 3.0), paint)
	_stripe(at + Vector3(0, 0.01, 0), Vector3(3.0, 0.02, 0.18), paint)
	var plinth := at + Vector3(-5.2, 0, 4.6)
	_plinth(plinth, "VEHICLE PAD", "RESERVED FOR DRIVING")
	stations.append({"node": null, "title": "VEHICLE PAD", "plinth": plinth})


func _stripe(at: Vector3, size: Vector3, material: Material) -> void:
	var stripe := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	stripe.mesh = box
	stripe.position = at
	add_child(stripe)


# --- the player --------------------------------------------------------------

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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and OS.get_environment("ATG_TEST_MODE") != "1":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not menu_open:
		yaw -= LOOK.dx(event.relative) * 0.0026
		pitch = clampf(pitch - LOOK.dy(event.relative) * 0.0024, -1.15, 0.95)
	# START on the pad; the keyboard's Escape stays with the pause screen.
	var start_pressed: bool = event.is_action_pressed("pause") and InputProfile.is_joy_event(event)
	if start_pressed or event.is_action_pressed("inventory") or (event is InputEventAction and event.is_action_pressed("pause")):
		menu_open = not menu_open
		get_viewport().set_input_as_handled()
		return
	if menu_open:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
			menu_index = (menu_index + 1) % stations.size()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
			menu_index = (menu_index + stations.size() - 1) % stations.size()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			go_to(menu_index)
			menu_open = false
		elif event.is_action_pressed("ui_cancel"):
			menu_open = false
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		use_nearest()
	elif event.is_action_pressed("attack"):
		attack(false)
	elif event.is_action_pressed("heavy"):
		attack(true)
	elif event.is_action_pressed("reload"):
		arsenal.reload()
	elif event.is_action_pressed("inspect"):
		var next: String = WEAPONS[(WEAPONS.find(arsenal.current_id) + 1) % WEAPONS.size()]
		arsenal.select_weapon(next)
		_note(str(arsenal.current().label))
	elif event.is_action_pressed("xray"):
		_note(bodies.press())
	elif JUMP_CLIMB.is_jump_key(event):
		JUMP_CLIMB.press(player, yaw, 1.0, "mechanics_lab_climbed")


## Stand in front of plinth `index`, facing what it shows.
func go_to(index: int) -> void:
	var entry: Dictionary = stations[clampi(index, 0, stations.size() - 1)]
	var plinth: Vector3 = entry.plinth
	player.global_position = plinth + Vector3(0, 1.0, 1.9)
	player.velocity = Vector3.ZERO
	yaw = 0.0
	pitch = -0.12
	_note("AT %s" % str(entry.title))


## Presses the button on the plinth within reach, if there is one.
func use_nearest() -> String:
	var entry := _nearest_plinth()
	if entry.is_empty():
		return ""
	var station = entry.node
	var said: String = station.press() if station != null else "NOTHING TO DRIVE YET"
	_note(said)
	return said


func _nearest_plinth() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 2.4
	for entry in stations:
		var flat := Vector2(player.global_position.x - entry.plinth.x, player.global_position.z - entry.plinth.z).length()
		if flat < best_distance:
			best_distance = flat
			best = entry
	return best


func _physics_process(delta: float) -> void:
	if not menu_open:
		InputProfile.apply_stick_look(self, delta)
	var input := Vector3.ZERO
	if not menu_open:
		input = Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	if not JUMP_CLIMB.busy(player):
		var pace := WALK * (SPRINT if Input.is_action_pressed("sprint") else 1.0)
		player.velocity.x = move_toward(player.velocity.x, direction.x * pace, 26.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * pace, 26.0 * delta)
		JUMP_CLIMB.fall(player, delta)
		player.move_and_slide()
	player.rotation.y = yaw
	BODY_CAM.apply(camera, player, delta, pitch)
	arsenal.tick(delta)
	var feet := player.global_position - Vector3(0, 0.85, 0)
	liquid.wade(feet, Vector2(player.velocity.x, player.velocity.z).length(), delta)
	_note_age += delta
	_update_hud()


# --- weapons -----------------------------------------------------------------

## One attack with the held weapon: a round per pellet for a gun, a blow
## along the view for a blade. Returns the arsenal's answer.
func attack(heavy: bool) -> Dictionary:
	var shot := arsenal.begin_attack(heavy)
	if not bool(shot.get("accepted", false)):
		if str(shot.get("reason", "")) == "empty":
			arsenal.reload()
		return shot
	var forward := -camera.global_basis.z
	if str(shot.kind) == "firearm":
		# A test range: the magazine never runs dry.
		var rounds: Dictionary = arsenal.ammo[arsenal.current_id]
		rounds.loaded = int(arsenal.current().magazine)
		for along in arsenal.shot_directions(forward, camera.global_basis.y):
			ballistics.fire(camera.global_position + along * 0.5, along, str(shot.calibre), 0.0, 1, "lab_player", {
				"damage": float(shot.damage), "impulse": float(shot.impulse),
				"damage_type": str(shot.damage_type), "weapon": str(shot.weapon),
			})
		BODY_CAM.hit(camera, 0.02)
		return shot
	var reach := float(shot.range)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward * reach)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var met := get_world_3d().direct_space_state.intersect_ray(query)
	if met.is_empty():
		return shot
	# A level slash for a light blow, an overhead chop for a heavy one.
	var swing := -camera.global_basis.y if heavy else camera.global_basis.x
	var plane := BodySlice.plane_from_swing(met.position, met.position - swing * 0.4, swing * 6.0)
	_land(met.collider, met.position, forward, shot, "melee", plane)
	BODY_CAM.hit(camera, 0.04)
	return shot


func _on_round_hit(hit: Dictionary) -> void:
	var payload: Dictionary = hit.get("payload", {})
	_land(hit.get("collider"), hit.get("position", Vector3.ZERO), hit.get("direction", Vector3.FORWARD), payload, "firearm", null)
	liquid.touch(hit.get("position", Vector3.ZERO), 1.0)


## Where a blow or a round lands: a body, a station's own surface, or the
## breakable world.
func _land(collider: Object, at: Vector3, direction: Vector3, attack_data: Dictionary, kind: String, plane: Variant) -> void:
	var damage := float(attack_data.get("damage", 20.0))
	var node := collider as Node
	while node != null and node != self:
		if node is BaselineHuman:
			var result := (node as BaselineHuman).hit_at(at, damage, float(attack_data.get("impulse", 0.0)), str(attack_data.get("damage_type", "blunt")), direction, -1.0, plane)
			last_hit = {"what": "body", "zone": str(result.get("zone", "")), "severed": bool(result.get("severed", false))}
			_note("%s // %s" % [str(result.get("zone", "")).to_upper().replace("_", " "), "OFF" if bool(result.get("severed", false)) else "HIT"])
			return
		if node.has_meta("lab_station"):
			var station = node.get_meta("lab_station")
			last_hit = station.strike(at, direction)
			last_hit["what"] = "station"
			return
		node = node.get_parent()
	var broke := WORLD_BREAK.hit(collider, damage, "round" if kind == "firearm" else "melee", at, direction, str(attack_data.get("weapon", "")), kind)
	if not broke.is_empty():
		last_hit = broke
		_note("%s %s" % [str(broke.get("kind", "")).to_upper().replace("_", " "), "BROKEN" if bool(broke.get("broken", false)) else "HIT"])


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = _label(layer, Vector2(24, 18), Color("e0442a"), 15)
	_prompt = _label(layer, Vector2(24, 0), Color("ead4ad"), 18)
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -64
	_menu = _label(layer, Vector2(0, 0), Color("ead4ad"), 22)
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.offset_left = -220
	_menu.offset_top = -120


func _label(layer: CanvasLayer, at: Vector2, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color("0c0806"))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", size)
	layer.add_child(label)
	return label


func _note(text: String) -> void:
	last_note = text
	_note_age = 0.0


func _update_hud() -> void:
	var weapon: Dictionary = arsenal.current()
	var lines := ["MECHANICS LAB", "%s   [%s] NEXT   [%s] FIRE/SWING   [%s] HEAVY" % [str(weapon.label), InputProfile.glyph("inspect"), InputProfile.glyph("attack"), InputProfile.glyph("heavy")]]
	for entry in stations:
		if entry.node != null:
			lines.append("%s  %s" % [str(entry.title), entry.node.status()])
	lines.append("ACID ON YOU %.1f  (x%.2f)" % [weather.player_acid_taken, weather.acid_player_scale])
	if _note_age < 3.0 and not last_note.is_empty():
		lines.append("> " + last_note)
	_hud.text = "\n".join(lines)
	var near := _nearest_plinth()
	_prompt.text = "" if near.is_empty() else "[%s] %s" % [InputProfile.glyph("interact"), str(near.title)]
	_menu.visible = menu_open
	if menu_open:
		var rows := ["STATIONS   [%s] GO" % InputProfile.glyph("ui_accept")]
		for index in stations.size():
			rows.append("%s %s" % [">" if index == menu_index else " ", str(stations[index].title)])
		_menu.text = "\n".join(rows)
