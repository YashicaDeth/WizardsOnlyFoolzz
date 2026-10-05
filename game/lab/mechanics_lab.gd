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
## BodyCam, and job 3's `SoulsMover`: tilt to walk or run, Circle/Ctrl to roll
## or crouch, sprint); the three v0.1 weapons through `HunterArsenal`,
## `MeleeDriver` (swing timing, hitstop, heat, shock) and `Ballistics`, the
## pistol aimed down its sights (`AimDownSights`), and R3 lock-on;
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
const SPARRING := preload("res://lab/sparring_partner.gd")
const VEHICLES := preload("res://lab/stations/vehicle_station.gd")
## Where the sparring partner (job 3) stands: the covered half, clear of the
## stations, so a fight has room to move.
const SPARRING_AT := Vector3(0, 0, -12)

const HALF := 20.0
const ROOF_Y := 5.5
const START := Vector3(0, 1.0, 17.0)
## The v0.1 weapons (job 3), in the order NEXT WEAPON steps through them.
## Greg replaced the fire axe and the sword: Brawler carries the HOTLINE
## CLEAVER and the PRODSTAFF, Marksman the MERCY NINE.
const WEAPONS := ["cleaver", "staff", "sidearm"]
const EYE_HEIGHT := 0.77
const LOCK_RANGE := 14.0
## Where a held weapon rests in view, before the swing or the sights move it.
const HELD_REST := {
	"cleaver": [Vector3(0.30, -0.30, -0.50), Vector3(0.10, 0.20, -0.35)],
	"staff": [Vector3(0.26, -0.34, -0.42), Vector3(0.06, 0.10, -0.20)],
	"sidearm": [Vector3(0.20, -0.22, -0.46), Vector3(0.0, 0.0, 0.0)],
}
## Where the destruction station stands; its dig patch cuts the yard floor.
const DESTRUCTION_AT := Vector3(-12, 0, 11)

var player: CharacterBody3D
var camera: Camera3D
var sun: DirectionalLight3D
var ballistics: Ballistics
var arsenal: HunterArsenal
var melee: MeleeDriver
var mover := SoulsMover.new()
var ads := AimDownSights.new()
var held_mount: Node3D
var aiming := false
var aim_blend := 0.0
var player_health := 100.0
var sparring: Node3D
var lock_target: BaselineHuman
var lock_ring: LockRing
var _lock_flick := 0.0
var yaw := 0.0
var pitch := -0.05
var stations: Array[Dictionary] = []
var liquid: Node3D
var weather: Node3D
var destruction: Node3D
var bodies: Node3D
var vehicles: Node3D
## A destruction tool in hand (`DESTRUCTION.TOOLS`) instead of a weapon, or "".
var tool := ""
var menu_open := false
var menu_index := 0
var last_note := ""
var last_hit: Dictionary = {}
var _hud: Label
var _prompt: Label
var _menu: Label
var _note_age := 0.0

# --- lab-48: organs, cybernetics and the X-ray --------------------------------
## The player's own body: the same anatomy as everyone else's, built out of
## sight (the lab's player is a camera on a capsule). Organ failure, shorted
## implants and anything installed from the bag happen to this.
var player_body: BaselineHuman
var carry: Carry
var organ_scan: XrayScanOverlay
## The hand in a body: `OrganSystem.begin_rip()`'s session while it lasts.
var rip: Dictionary = {}
## Tests (and scripts) hold the rip with this; play holds `interact`.
var rip_held := false
var _rip_idle := 0.0
var _rip_home := Vector3.ZERO
## What the aim line is on right now, for the prompt and the press.
var aimed: Dictionary = {}
## What came out, in your hand, and its place in the bag.
var hand: Node3D
var hand_item: Dictionary = {}
var _hand_age := 0.0
var _hand_beat := false
## Fix-58: finishing a downed body with what is in your hand (`ExecutionBeat`).
## R1 / LMB on a body on the floor within reach, any weapon.
var execution: ExecutionBeat
const EXECUTE_REACH := 2.6


func _ready() -> void:
	_build_world()
	liquid = _station(LIQUID, Vector3(-12, 0, -8), Vector3(0, 0, 0))
	bodies = _station(BODIES, Vector3(10, 0, -8), Vector3(0, 0, 0))
	weather = _station(WEATHER, Vector3(0, 0, 2), Vector3(0, 0, 0))
	destruction = _station(DESTRUCTION, DESTRUCTION_AT, DESTRUCTION.PLINTH)
	vehicles = _station(VEHICLES, Vector3(12, 0, 12), VEHICLES.PLINTH)
	_build_player()
	ballistics = Ballistics.new()
	add_child(ballistics)
	ballistics.round_hit.connect(_on_round_hit)
	arsenal = HunterArsenal.new()
	arsenal.name = "Arsenal"
	add_child(arsenal)
	arsenal.acquire_melee("cleaver")
	arsenal.acquire_melee("staff")
	arsenal.select_weapon("cleaver")
	melee = MeleeDriver.new()
	melee.name = "Melee"
	add_child(melee)
	melee.setup(arsenal, camera, [player.get_rid()])
	melee.struck.connect(_on_melee_struck)
	melee.kicked.connect(func(amount: float) -> void: BODY_CAM.hit(camera, amount))
	arsenal.equipped.connect(func(_id: String) -> void: _hold_current())
	lock_ring = LockRing.new()
	add_child(lock_ring)
	execution = ExecutionBeat.new()
	execution.name = "Execution"
	add_child(execution)
	execution.landed.connect(_on_execution_landed)
	execution.finished.connect(func(report: Dictionary) -> void:
		_note("%s // %s" % [str(report.get("verb", "EXECUTED")), "DEAD" if bool(report.get("dead", false)) else "ALIVE"]))
	sparring = SPARRING.new()
	sparring.name = "SparringPartner"
	sparring.position = SPARRING_AT
	add_child(sparring)
	sparring.build(self)
	melee.staggered.connect(func(rig: Node3D, _report: Dictionary) -> void:
		if sparring.rig == rig:
			sparring.interrupt())
	_hold_current()
	_build_hud()
	_build_organ_kit()
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
	# The destruction station's dig patch (`DigTerrain`) stands in for the
	# yard floor over its own rectangle, so the floor is laid round it.
	var hole := Rect2(DESTRUCTION.DIG_RECT.position + Vector2(DESTRUCTION_AT.x, DESTRUCTION_AT.z), DESTRUCTION.DIG_RECT.size)
	for strip: Rect2 in [
		Rect2(-HALF, 0.0, HALF * 2.0, hole.position.y),
		Rect2(-HALF, hole.end.y, HALF * 2.0, HALF - hole.end.y),
		Rect2(-HALF, hole.position.y, hole.position.x + HALF, hole.size.y),
		Rect2(hole.end.x, hole.position.y, HALF - hole.end.x, hole.size.y),
	]:
		if strip.size.x <= 0.0 or strip.size.y <= 0.0:
			continue
		var ground := _solid(Vector3(strip.size.x, 0.4, strip.size.y), Vector3(strip.get_center().x, -0.2, strip.get_center().y), dirt)
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
	camera.position.y = EYE_HEIGHT
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
	if vehicles.driving():
		# In a car USE gets out; the hands are on the wheel for everything else.
		if event.is_action_pressed("interact"):
			_note(vehicles.press())
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Directional swings follow the mouse's last move.
		melee.set_swing_hint(Vector2(event.relative.x, -event.relative.y).limit_length(12.0) / 12.0)
	if execution.active:
		# The beat owns the body until it ends (always, by DEADLINE): no swing,
		# shot, roll or press can start under it.
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack") and execute_downed():
		get_viewport().set_input_as_handled()
		return
	if _movement_input(event):
		return
	if melee.handle_input(event):
		return
	if event.is_action_pressed("interact"):
		# Lab-48: a hand into an opened body before the plinth button.
		if not begin_rip_aimed():
			if vehicles.try_enter():
				_note(VEHICLES.HINT)
			else:
				use_nearest()
	elif not hand_item.is_empty() and event.is_action_pressed("reload"):
		install_hand_item()
	elif not hand_item.is_empty() and event.is_action_pressed("heal"):
		sell_hand_item()
	elif event.is_action_pressed("attack"):
		attack(false)
	elif event.is_action_pressed("heavy"):
		attack(true)
	elif event.is_action_pressed("lock_on"):
		toggle_lock()
	elif aiming and event.is_action_pressed("sprint"):
		# L3 / Shift while aimed steps further down the sight.
		ads.step_zoom()
	elif event.is_action_pressed("reload"):
		arsenal.reload()
	elif event.is_action_pressed("inspect"):
		next_weapon()
	elif event.is_action_pressed("xray"):
		_note(bodies.press())
	elif JUMP_CLIMB.is_jump_key(event):
		JUMP_CLIMB.press(player, yaw, 1.0, "mechanics_lab_climbed")


## Evade (Circle / Ctrl), sprint (L3 / Shift). On the pad Circle also
## carries `crouch` and `dodge`; one press must not count twice.
func _movement_input(event: InputEvent) -> bool:
	var pad := InputProfile.is_joy_event(event)
	var evade_action := "dodge" if pad else "crouch"
	if event.is_action_pressed(evade_action):
		mover.evade_pressed(pad)
		return true
	if event.is_action_released(evade_action):
		mover.evade_released(player, _move_input(), yaw, melee)
		return true
	if pad and (event.is_action("crouch") or event.is_action("grapple")):
		return true
	if not aiming and event.is_action("sprint") and not event.is_echo():
		mover.set_sprint_key(event.is_pressed())
		return event is InputEventKey or event is InputEventAction
	return false


func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


## R3 / Z: lock on to the nearest standing body in front of you, or let go.
func toggle_lock() -> BaselineHuman:
	if lock_target != null:
		lock_target = null
		lock_ring.release()
		return null
	lock_target = _lock_candidate(0)
	return lock_target


func _lock_candidate(side: int) -> BaselineHuman:
	var best: BaselineHuman = null
	var best_score := INF
	var forward := -camera.global_basis.z
	var right := camera.global_basis.x
	var from := lock_target.global_position if lock_target != null else Vector3.ZERO
	for node in get_tree().get_nodes_in_group(&"lab_lockable"):
		var rig := node as BaselineHuman
		if rig == null or rig == lock_target or not rig.is_inside_tree() or rig.anatomy.dead:
			continue
		var to: Vector3 = rig.global_position + Vector3(0, 1.2, 0) - camera.global_position
		if to.length() > LOCK_RANGE:
			continue
		var facing := forward.dot(to.normalized())
		if side == 0:
			if facing < 0.5:
				continue
			var score := to.length() * (2.0 - facing)
			if score < best_score:
				best_score = score
				best = rig
		else:
			var across: float = right.dot(rig.global_position - from) * float(side)
			if across <= 0.05 or facing < 0.0:
				continue
			if across < best_score:
				best_score = across
				best = rig
	return best


func _update_lock(delta: float) -> void:
	if lock_target != null and (not is_instance_valid(lock_target) or lock_target.anatomy.dead):
		lock_target = null
	if lock_target == null:
		lock_ring.release()
		return
	# Right stick flick switches target.
	var flick := Input.get_axis("look_left", "look_right")
	if absf(flick) > 0.75 and absf(_lock_flick) <= 0.75:
		var next := _lock_candidate(1 if flick > 0.0 else -1)
		if next != null:
			lock_target = next
	_lock_flick = flick
	var aim_at := lock_target.global_position + Vector3(0, 1.25, 0)
	var to := aim_at - camera.global_position
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var rate := clampf(delta * 10.0, 0.0, 1.0)
	yaw = lerp_angle(yaw, want_yaw, rate)
	pitch = lerpf(pitch, want_pitch, rate)
	lock_ring.follow(lock_target.global_position)


## Rebuild the held model for the current weapon, parented to the eye.
func _hold_current() -> void:
	if held_mount != null and is_instance_valid(held_mount):
		held_mount.queue_free()
	var id := str(arsenal.current_id)
	held_mount = Node3D.new()
	held_mount.name = "HeldMount"
	camera.add_child(held_mount)
	var gear := HeldGear.build_weapon(id)
	held_mount.add_child(gear)
	var grip := gear.get_node_or_null("anchor_grip") as Node3D
	if grip != null:
		gear.position = -(gear.transform.basis * grip.position)
	var rest: Array = HELD_REST.get(id, HELD_REST.sidearm)
	held_mount.position = rest[0]
	held_mount.rotation = rest[1]
	ads.reset()
	aim_blend = 0.0
	melee.set_model(held_mount if str(arsenal.current().kind) == "melee" else null)


func _pose_held(delta: float) -> void:
	if held_mount == null or not is_instance_valid(held_mount):
		return
	var firearm := str(arsenal.current().kind) == "firearm"
	aiming = firearm and (Input.is_action_pressed("parry") or Input.is_action_pressed("guard"))
	ads.advance(delta, aiming)
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 7.0)
	if not firearm:
		return
	var rest: Array = HELD_REST.get(str(arsenal.current_id), HELD_REST.sidearm)
	held_mount.position = rest[0]
	held_mount.rotation = rest[1]
	ads.pose(held_mount, camera.global_transform, str(arsenal.current_id), aim_blend)
	camera.fov = lerpf(88.0, ads.fov(str(arsenal.current_id)), aim_blend)


## NEXT steps through the weapons, then the destruction tools, then round.
func next_weapon() -> void:
	var tools: Array = DESTRUCTION.TOOLS
	if not tool.is_empty():
		var after := tools.find(tool) + 1
		tool = tools[after] if after < tools.size() else ""
		if tool.is_empty():
			arsenal.select_weapon(WEAPONS[0])
	elif arsenal.current_id == WEAPONS[-1]:
		tool = tools[0]
	else:
		arsenal.select_weapon(WEAPONS[(WEAPONS.find(arsenal.current_id) + 1) % WEAPONS.size()])
	_note(tool.to_upper() if not tool.is_empty() else str(arsenal.current().label))


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
	if vehicles.driving():
		# The walking body waits where it got in; the car's driver owns the view.
		_note_age += delta
		_update_hud()
		return
	if not menu_open and lock_target == null:
		InputProfile.apply_stick_look(self, delta)
	_update_lock(delta)
	var input := Vector2.ZERO
	if not menu_open and not execution.active:
		input = _move_input()
	if player_body != null:
		mover.winded = bool(OrganSystem.failure(player_body.anatomy).no_sprint)
	if execution.active:
		_face_execution(delta)
	elif not JUMP_CLIMB.busy(player):
		mover.tick(player, input, yaw, delta, melee)
		JUMP_CLIMB.fall(player, delta)
		player.move_and_slide()
	player.rotation.y = yaw
	camera.position.y = EYE_HEIGHT - mover.eye_drop
	BODY_CAM.apply(camera, player, delta, pitch)
	arsenal.tick(delta)
	if input.length_squared() > 0.25:
		melee.set_swing_hint(input * Vector2(1, -1))
	melee.tick(delta)
	_pose_held(delta)
	_pose_execution()
	if tool == "drill" and not menu_open and Input.is_action_pressed("attack"):
		destruction.drill(camera.global_position, -camera.global_basis.z, delta, player)
	var feet := player.global_position - Vector3(0, 0.85, 0)
	liquid.wade(player, feet, player.velocity, delta)
	_organ_frame(delta)
	_note_age += delta
	_update_hud()


# --- weapons -----------------------------------------------------------------

## One attack with the held weapon: a round per pellet for a gun, a blow
## along the view for a blade. Returns the arsenal's answer.
func attack(heavy: bool) -> Dictionary:
	if not tool.is_empty():
		_note(destruction.use_tool(tool, camera.global_position, -camera.global_basis.z, player))
		return {"accepted": true, "kind": "tool", "tool": tool}
	if str(arsenal.current().kind) == "melee":
		# Pressed outside the event path (a test, a script): the same verbs.
		if heavy:
			melee.press_heavy()
			melee.release_heavy()
		else:
			melee.press_light()
		return {"accepted": true, "kind": "melee", "weapon": arsenal.current_id}
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
		var origin := camera.global_position
		if aiming and ads.has_line:
			# Aimed rounds leave along the line through both sights.
			forward = ads.line_direction
			origin = ads.line_origin
		ads.add_kick(1.0)
		for along in arsenal.shot_directions(forward, camera.global_basis.y, 0.35 if aiming else 1.0):
			ballistics.fire(origin + along * 0.5, along, str(shot.calibre), 0.0, 1, "lab_player", {
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


## The nearest body on the floor in front of you and within reach, or null.
func downed_in_reach() -> BaselineHuman:
	var best: BaselineHuman = null
	var best_distance := EXECUTE_REACH
	var forward := -camera.global_basis.z
	forward.y = 0.0
	for rig: BaselineHuman in organ_rigs():
		if rig == null or not is_instance_valid(rig) or not rig.is_downed():
			continue
		var to := rig.global_position - player.global_position
		to.y = 0.0
		var distance := to.length()
		if distance > best_distance:
			continue
		if distance > 0.5 and forward.length_squared() > 0.01 and forward.normalized().dot(to.normalized()) < 0.2:
			continue
		best_distance = distance
		best = rig
	return best


## R1 / LMB on a downed body in reach: the finisher for whatever is in hand.
func execute_downed() -> bool:
	if execution.active or not tool.is_empty() or not rip.is_empty():
		return false
	var rig := downed_in_reach()
	if rig == null:
		return false
	if lock_target == rig:
		lock_target = null
	return execution.begin(player, rig, str(arsenal.current_id))


func _on_execution_landed(report: Dictionary) -> void:
	BODY_CAM.hit(camera, float((ExecutionBeat.STYLES.get(str(report.style), {}) as Dictionary).get("kick", 0.06)))
	last_hit = {"what": "body", "zone": str(report.zone), "executed": true}
	var taken: Dictionary = report.get("taken", {})
	if not taken.is_empty():
		var node := execution.victim.organ_parts.get("heart") as MeshInstance3D if execution.victim != null else null
		var item := OrganSystem.carry_item(carry, taken)
		_put_in_hand(node.mesh if node != null else null, node.material_override if node != null else null, item, true)
	liquid.touch(report.get("at", player.global_position), 0.6)


## The view turns onto the body and looks down at it while the beat runs.
func _face_execution(delta: float) -> void:
	player.velocity = Vector3.ZERO
	var rate := clampf(delta * 14.0, 0.0, 1.0)
	yaw = lerp_angle(yaw, execution.view_yaw, rate)
	pitch = lerpf(pitch, -0.62, rate)


## The held weapon is drawn back over the body and brought down on it.
func _pose_execution() -> void:
	if not execution.active or held_mount == null or not is_instance_valid(held_mount):
		return
	var draw := execution.wind()
	var rest: Array = HELD_REST.get(str(arsenal.current_id), HELD_REST.sidearm)
	held_mount.position = (rest[0] as Vector3) + Vector3(0, 0.14, 0.12) * draw
	held_mount.rotation = (rest[1] as Vector3) + Vector3(0.9, 0, 0) * draw


## A blow from `MeleeDriver` met something. Cuts slice along the swing: a
## level blade for a side swing, a downward one over the top.
func _on_melee_struck(collider: Object, at: Vector3, direction: Vector3, packet: Dictionary) -> void:
	var definition: Dictionary = packet.get("attack_data", {})
	var swing := -camera.global_basis.y if str(definition.get("side", "")) == "high" else camera.global_basis.x * (-1.0 if bool(packet.get("mirror", false)) else 1.0)
	var plane: Variant = null
	if bool(definition.get("cuts", false)):
		plane = BodySlice.plane_from_swing(at, at - swing * 0.4, swing * 6.0)
	_land(collider, at, direction, packet, "melee", plane)
	if bool(packet.get("shock", false)):
		_note("SHOCK")
	liquid.touch(at, 0.5)


func _on_round_hit(hit: Dictionary) -> void:
	var payload: Dictionary = hit.get("payload", {})
	_land(hit.get("collider"), hit.get("position", Vector3.ZERO), hit.get("direction", Vector3.FORWARD), payload, "firearm", null)
	liquid.touch(hit.get("position", Vector3.ZERO), 1.0)


## Where a blow or a round lands: a body, a station's own surface, or the
## breakable world.
func _land(collider: Object, at: Vector3, direction: Vector3, attack_data: Dictionary, kind: String, plane: Variant) -> void:
	var damage := float(attack_data.get("damage", 20.0))
	var node := collider as Node
	# A knocked-down body's parts hang under its RagdollBody, not the rig.
	var owner_rig := MeleeDriver.rig_of(collider)
	if owner_rig != null:
		node = owner_rig
	while node != null and node != self:
		if node is BaselineHuman:
			var body := node as BaselineHuman
			var damage_type := str(attack_data.get("damage_type", "blunt"))
			var result := body.hit_at(at, damage, float(attack_data.get("impulse", 0.0)), damage_type, direction, -1.0, plane)
			last_hit = {"what": "body", "zone": str(result.get("zone", "")), "severed": bool(result.get("severed", false))}
			_note("%s // %s" % [str(result.get("zone", "")).to_upper().replace("_", " "), "OFF" if bool(result.get("severed", false)) else "HIT"])
			# Lab-48: a deep enough torso wound opens the chest; the PRODSTAFF
			# shorts whatever powered hardware is in the body it touches.
			if not OrganSystem.after_hit(body, result, direction, damage_type).is_empty():
				last_hit["opened"] = true
				_note("CHEST OPEN")
			if bool(attack_data.get("shock", false)):
				var shorted := OrganSystem.shock_rig(body, 1.0)
				last_hit["shorted"] = shorted
				if not shorted.is_empty():
					var tags: Array[String] = []
					for entry in shorted:
						tags.append("%s%s" % [str(entry.tag), " OVERLOADED" if bool(entry.overloaded) else ""])
					_note("SHORTED // " + ", ".join(tags))
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
	var lines := ["MECHANICS LAB", "%s   [%s] NEXT   [%s] FIRE/SWING   [%s] HEAVY" % [tool.to_upper() if not tool.is_empty() else str(weapon.label), InputProfile.glyph("inspect"), InputProfile.glyph("attack"), InputProfile.glyph("heavy")]]
	for entry in stations:
		if entry.node != null:
			lines.append("%s  %s" % [str(entry.title), entry.node.status()])
	# Acid rain is a lab demo, off by default (Greg): its line only while it falls.
	if weather.state == "acid":
		lines.append("ACID ON YOU %.1f  (x%.2f)" % [weather.player_acid_taken, weather.acid_player_scale])
	var extra := ""
	if arsenal.current_id == "cleaver":
		extra = "   HEAT %d%%%s" % [roundi(melee.heat * 100.0), "  VENTING" if melee.vent_left > 0.0 else ""]
	lines.append("HP %d   STAMINA %d%s   [%s] BLOCK  [%s] PARRY/AIM  [%s] LOCK  [%s] ROLL" % [roundi(player_health), roundi(melee.stamina), extra, InputProfile.glyph("guard"), InputProfile.glyph("parry"), InputProfile.glyph("lock_on"), InputProfile.glyph("crouch" if InputProfile.device_family() == "keyboard" else "dodge")])
	if player_body != null:
		lines.append(_body_line())
	if _note_age < 3.0 and not last_note.is_empty():
		lines.append("> " + last_note)
	_hud.text = "\n".join(lines)
	var near := _nearest_plinth()
	_prompt.text = "" if near.is_empty() else "[%s] %s" % [InputProfile.glyph("interact"), str(near.title)]
	var organ_prompt := _organ_prompt()
	if not organ_prompt.is_empty():
		_prompt.text = organ_prompt
	if execution.active:
		_prompt.text = ""
	elif tool.is_empty() and rip.is_empty():
		var downed := downed_in_reach()
		if downed != null:
			_prompt.text = "[%s] %s" % [InputProfile.glyph("attack"), "TAKE THE HEART" if ExecutionBeat.style_for(downed, str(arsenal.current_id)) == "rip" else "EXECUTE"]
	_menu.visible = menu_open
	if menu_open:
		var rows := ["STATIONS   [%s] GO" % InputProfile.glyph("ui_accept")]
		for index in stations.size():
			rows.append("%s %s" % [">" if index == menu_index else " ", str(stations[index].title)])
		_menu.text = "\n".join(rows)


# --- lab-48: organs, cybernetics and the X-ray --------------------------------

func _build_organ_kit() -> void:
	carry = Carry.new()
	player_body = BaselineHuman.new()
	player_body.name = "PlayerBody"
	add_child(player_body)
	player_body.position = Vector3(0, -40, 0)
	player_body.build("lab_player", {"gore": false, "blood": 4800.0})
	player_body.visible = false
	player_body.anatomy.undying = true
	# The decanting loadout: the regulator keeps a burst heart beating until
	# a shock stops it. The arm stays empty, as on the real route.
	player_body.anatomy.install_factory_loadout(["left_arm"] as Array[String])
	OrganSystem.attach(player_body)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	organ_scan = XrayScanOverlay.new()
	organ_scan.name = "XrayScan"
	layer.add_child(organ_scan)
	organ_scan.visible = false


## Every body a hand can reach in the lab.
func organ_rigs() -> Array:
	var out: Array = bodies.rigs()
	if sparring != null and sparring.rig != null and is_instance_valid(sparring.rig):
		out.append(sparring.rig)
	return out


## The PRODSTAFF landed on you: your own powered hardware shorts.
func on_player_shocked() -> void:
	if player_body == null:
		return
	var shorted := OrganSystem.shock(player_body.anatomy, 1.0)
	if not shorted.is_empty():
		_note("YOUR %s SHORTED" % str(shorted[0].tag))


## The press: start a rip on the part the aim line is on, if a hand can get
## in. Returns true when the press was used (a refusal is still said).
func begin_rip_aimed() -> bool:
	if not rip.is_empty():
		return true
	aimed = OrganSystem.aimed_part(organ_rigs(), camera.global_position, -camera.global_basis.z)
	if aimed.is_empty() or not _aimed_visible():
		return false
	var rig := aimed.rig as BaselineHuman
	var refusal := OrganSystem.rip_refusal(rig, str(aimed.id))
	if refusal != "":
		_note("%s // %s" % [OrganSystem.label_of(rig, str(aimed.id)), refusal])
		return true
	rip = OrganSystem.begin_rip(rig, str(aimed.id))
	_rip_idle = 0.0
	var node := _rip_node()
	_rip_home = node.position if node != null else Vector3.ZERO
	_note("RIPPING %s" % OrganSystem.label_of(rig, str(aimed.id)))
	return true


## Only what can be seen can be grabbed: an organ is seen through the X-ray or
## an opening, hardware through its own piece showing.
func _aimed_visible() -> bool:
	var rig := aimed.get("rig") as BaselineHuman
	if rig == null:
		return false
	return bodies.xray or OrganSystem.is_opened(rig, OrganSystem.zone_of(rig, str(aimed.id)))


func _rip_node() -> Node3D:
	if rip.is_empty():
		return null
	var rig := rip.rig as BaselineHuman
	if rig == null or not is_instance_valid(rig):
		return null
	var id := str(rip.id)
	if id.begins_with("implant:"):
		var zone_node := rig.parts.get(str(rip.zone)) as Node3D
		return zone_node.get_node_or_null("Implant_%s" % id.trim_prefix("implant:")) as Node3D if zone_node != null else null
	return rig.organ_parts.get(id) as Node3D


func _organ_frame(delta: float) -> void:
	if player_body == null:
		return
	aimed = OrganSystem.aimed_part(organ_rigs(), camera.global_position, -camera.global_basis.z)
	_tick_rip(delta)
	_tick_hand(delta)
	_tick_scan()


func _tick_rip(delta: float) -> void:
	if rip.is_empty():
		return
	var rig := rip.rig as BaselineHuman
	if rig == null or not is_instance_valid(rig):
		rip = {}
		return
	var holding := rip_held or Input.is_action_pressed("interact")
	var before := float(rip.tension)
	OrganSystem.tug(rip, delta, holding)
	var node := _rip_node()
	if node != null and is_instance_valid(node):
		# Out through the hole toward the hand, jerking on each tug.
		var toward := (camera.global_position - node.global_position).normalized()
		var parent := node.get_parent() as Node3D
		node.position = _rip_home + parent.global_basis.inverse() * toward * OrganSystem.pull_offset(rip)
	if holding and before > 0.5 and float(rip.tension) <= 0.5:
		BODY_CAM.hit(camera, 0.012)
	if not holding:
		_rip_idle += delta
		if float(rip.progress) <= 0.0 and _rip_idle > 0.3:
			if node != null:
				node.position = _rip_home
			rip = {}
			return
	else:
		_rip_idle = 0.0
	if bool(rip.complete):
		if node != null:
			node.position = _rip_home
		var source_mesh: Mesh = (node as MeshInstance3D).mesh if node is MeshInstance3D else null
		var source_material: Material = (node as MeshInstance3D).material_override if node is MeshInstance3D else null
		var id := str(rip.id)
		var label := OrganSystem.label_of(rig, id)
		var info := OrganSystem.finish_rip(rip)
		rip = {}
		if info.is_empty():
			return
		var item := OrganSystem.carry_item(carry, info)
		_put_in_hand(source_mesh, source_material, item, str(info.get("organ_id", "")) == "heart")
		BODY_CAM.hit(camera, 0.05)
		_note("%s IN HAND // %d%% // SELLS %d" % [label, roundi(float(item.get("condition", 0.0)) * 100.0), int(item.get("value", 0))])


func _put_in_hand(mesh: Mesh, material: Material, item: Dictionary, beating: bool) -> void:
	if hand != null and is_instance_valid(hand):
		hand.queue_free()
	hand_item = item
	_hand_age = 0.0
	_hand_beat = beating
	hand = null
	if mesh == null:
		return
	var held := MeshInstance3D.new()
	held.name = "HandItem"
	held.mesh = mesh.duplicate(true)
	if material != null:
		held.material_override = (material as Material).duplicate()
		if held.material_override is BaseMaterial3D:
			(held.material_override as BaseMaterial3D).no_depth_test = false
			(held.material_override as BaseMaterial3D).render_priority = 0
	elif held.mesh.get_surface_count() > 0 and held.mesh.surface_get_material(0) is BaseMaterial3D:
		var own := (held.mesh.surface_get_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
		own.no_depth_test = false
		own.render_priority = 0
		held.material_override = own
	held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Up close it is the size it is: a fist-sized heart in the lower right.
	held.position = Vector3(0.12, -0.13, -0.34)
	held.rotation = Vector3(0.3, -0.6, 0.15)
	camera.add_child(held)
	hand = held


func _tick_hand(delta: float) -> void:
	if held_mount != null:
		# One hand: what came out of somebody, or the weapon.
		held_mount.visible = hand == null or not is_instance_valid(hand)
	if hand == null or not is_instance_valid(hand):
		return
	_hand_age += delta
	if _hand_beat:
		# Still going for a few seconds after it came out.
		var fade := clampf(1.0 - _hand_age / 5.0, 0.0, 1.0)
		var beat := pow(maxf(0.0, sin(_hand_age * TAU * 1.3)), 6.0) * 0.12 * fade
		hand.scale = Vector3.ONE * (1.0 + beat)


## The thing in your hand, into your body (`OrganSystem.install_into_self`).
func install_hand_item() -> Dictionary:
	var index := carry.items.find(hand_item)
	if index < 0:
		return {}
	var done := OrganSystem.install_into_self(carry, index, player_body)
	if not done.is_empty():
		_note("INSTALLED IN YOU // %s" % str(done.get("organ", done.get("implant", ""))).to_upper().replace("_", " "))
		_drop_hand()
	return done


## The thing in your hand, sold for its value (`Carry.sell`).
func sell_hand_item() -> Dictionary:
	var index := carry.items.find(hand_item)
	if index < 0:
		return {}
	var sold := carry.sell(index)
	if not sold.is_empty():
		_note("SOLD // %d SCRIP" % int(sold.price))
		_drop_hand()
	return sold


func _drop_hand() -> void:
	hand_item = {}
	if hand != null and is_instance_valid(hand):
		hand.queue_free()
	hand = null


## X-ray on: the body nearest the middle of the view, in reach, is scanned.
func _tick_scan() -> void:
	if organ_scan == null:
		return
	if not bodies.xray:
		if organ_scan.visible:
			organ_scan.show_scan(null, camera)
		return
	var target: BaselineHuman = lock_target if lock_target != null and is_instance_valid(lock_target) else null
	if target == null:
		var best := 0.93
		var forward := -camera.global_basis.z
		for rig: BaselineHuman in organ_rigs():
			var to := rig.global_position + Vector3.UP * 1.1 - camera.global_position
			if to.length() > 12.0:
				continue
			var facing := forward.dot(to.normalized())
			if facing > best:
				best = facing
				target = rig
	if target != organ_scan.rig or organ_scan.camera != camera:
		organ_scan.show_scan(target, camera)


func _organ_prompt() -> String:
	if not rip.is_empty():
		var bar := roundi(float(rip.progress) * 10.0)
		return "[%s] HOLD // RIPPING %s  %s" % [InputProfile.glyph("interact"), OrganSystem.label_of(rip.rig, str(rip.id)), "#".repeat(bar) + "-".repeat(10 - bar)]
	if not hand_item.is_empty() and hand != null:
		return "%s IN HAND   [%s] INSTALL IN YOU   [%s] SELL %d" % [str(hand_item.get("label", "")), InputProfile.glyph("reload"), InputProfile.glyph("heal"), int(hand_item.get("value", 0))]
	if aimed.is_empty() or not _aimed_visible():
		return ""
	var rig := aimed.rig as BaselineHuman
	var refusal := OrganSystem.rip_refusal(rig, str(aimed.id))
	if refusal != "":
		return "%s // %s" % [OrganSystem.label_of(rig, str(aimed.id)), refusal]
	return "[%s] HOLD // RIP OUT %s" % [InputProfile.glyph("interact"), OrganSystem.label_of(rig, str(aimed.id))]


func _body_line() -> String:
	var state := OrganSystem.failure(player_body.anatomy)
	var words: Array[String] = []
	if bool(state.breathless):
		words.append("BREATHLESS")
	if bool(state.heart_failing):
		words.append("HEART STOPPING %.1f" % maxf(0.0, OrganSystem.HEART_DEATH_SECONDS - float(player_body.anatomy.get_meta("heart_stopped_for", 0.0))))
	if bool(state.slow_bleed):
		words.append("BLEEDING INSIDE")
	if player_body.anatomy.failed:
		words.append("BODY FAILED")
	for site_id in player_body.anatomy.installed_parts:
		if OrganSystem.is_shorted(player_body.anatomy.installed_parts[site_id]):
			words.append("%s SHORTED" % OrganSystem.tag_of(player_body.anatomy.installed_parts[site_id]))
	return "BODY  BLOOD %d  %s   BAG %d" % [roundi(player_body.anatomy.blood_remaining), "OK" if words.is_empty() else " ".join(words), carry.items.size()]
