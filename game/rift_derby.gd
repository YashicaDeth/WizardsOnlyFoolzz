extends Node3D

## The authored Bone Yard kit was modelled for a 29m bowl, which plays as a
## playpen. The whole venue is scaled up together so the geometry still matches.
const ARENA_SCALE := 1.85
## Kept equal to ARENA_SCALE for now. Greg asked for a bigger arena and a
## uniform multiplier does not deliver one: at 2.15 and 2.45 the wreckers drift
## outward and never engage — measured as first contact 28s in at 2.15 and no
## contact at all inside thirty seconds at 2.45, with the player finishing on a
## full hull in both. Holding the spawn ring tight while the venue grew did not
## fix it either, so the cause is in the authored oval rather than in the
## spacing. See ROADMAP.md; this needs the venue re-authored, not rescaled.
const SPAWN_SCALE := 1.85
const ARENA_LIMIT := 29.0 * ARENA_SCALE
const MAX_SPEED := 24.0
## The derby captain. Generated per save rather than named here — a second
## hardcoded name is the same problem with different letters, and F v10.1
## already says a rival is made by what happened rather than spawned as one.
## Resolved through `CastNames`, which seeds off `WorldHistory.run_salt`, so
## the captain is stable inside a save and different in the next.
const CAPTAIN_SLOT := "derby_captain"
const CAST := preload("res://systems/cast_names.gd")
const SCRAP_SKIFF := preload("res://art/scrap_skiff.glb")
const BONE_YARD_ENVIRONMENT := preload("res://art/bone_yard_environment.glb")
const DERBY_AUDIO := preload("res://systems/procedural_derby_audio.gd")
const VEHICLE := preload("res://systems/arcade_vehicle.gd")
const AI_DRIVER := preload("res://systems/derby_ai_driver.gd")
## At most this many wreckers may hunt the player at once, and not from the
## opening horn: the cap ramps in over ENGAGE_RAMP seconds. Every car targeting
## the player from second one is what made the heat unplayable — measured at
## five cars inside nine metres with eight of twelve wedged motionless.
const MAX_ENGAGED := 3
const ENGAGE_RAMP := 13.0
const REASSIGN_EVERY := 2.6
const KILL_CAM := preload("res://systems/kill_cam.gd")
const PIT_RADIO := preload("res://systems/pit_radio.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")
const SILHOUETTE := preload("res://systems/silhouette.gd")
const INTERIOR := preload("res://systems/vehicle_interior.gd")
const KEYS_CARD := preload("res://systems/keys_card.gd")
const DAMAGE_PORTRAIT := preload("res://systems/damage_portrait.gd")
const CAB_RETICLE := preload("res://systems/cab_reticle.gd")

## The bezel `celloutz_hud.gd` draws for the driver, in its own coordinates, so
## the bust lands inside the frame instead of beside it. Kept next to the
## preload rather than buried in `_ready` because the two have to agree.
const DRIVER_BUST_FRAME := Rect2(Vector2(22, 18), Vector2(150, 178))
## Matches the collider box in arcade_vehicle.gd's `_ready()`. Not read off
## the chassis at spawn time because the collider is built in `_ready()` too,
## so the shape does not exist yet on the frame the car is instanced.
const CHASSIS_DIMENSIONS := Vector3(2.65, 1.3, 4.8)

## Authored props that fight the read at arena scale. Hidden rather than deleted
## from the kit, so a re-export can reinstate them deliberately.
const SUPPRESSED_PROPS := ["launch_ramp_00", "launch_ramp_01", "launch_ramp_02"]

var boat: Node3D
var speed := 0.0
var boat_velocity := Vector3.ZERO
var score := 0
var integrity := 100
var viscera_fx := true
var targets: Array[Node3D] = []
var debris: Array[Dictionary] = []
var respawn_queue: Array[Dictionary] = []
var index_open := false
var crowd_members: Array[Node3D] = []
var crowd_reaction := 0.0
var camera_shake := 0.0
var disabled_count := 0
var active_seconds := 0.0
var reassign_timer := 0.0
var round_state := "countdown"
var countdown := 3.0
var result_countdown := 0.0
var leaving := false
var authored_collision_count := 0
## AG3.2. The cab. M2 built all of this and nothing ever instantiated it outside
## its own capture test, which is why the derby was still a chase camera looking
## at a box with wheels.
var interior: Node3D = null
## Where you are sitting. Third person is the unlocked view, not the default —
## M1 already made that the rule on foot and the derby never followed it.
var in_cab := true
## Where the driver is looking, relative to the car. You steer with the car and
## aim independently of it, which is the whole point of having a gun in the
## other hand.
var aim_yaw := 0.0
var aim_pitch := 0.0
## AG3.3. Getting out takes a moment you can watch. 0 while seated, climbing to
## 1 as the body leaves the car.
var climbing_out := 0.0
var leaving_on_foot := false
## AG3.5. What can be pressed, when somebody asks.
var keys_card: Control
var _cab_seat := Vector3.ZERO
var fire_cooldown := 0.0
var rounds_left := 12
var derby_audio: Node
var kill_cam: Control
var pit_radio: Control

@onready var camera: Camera3D = $Camera3D
@onready var status: Label = $HUD/Status
@onready var score_label: Label = $HUD/ScorePanel/Score
@onready var mode_label: Label = $HUD/Mode
@onready var rival_label: Label = $HUD/RivalPanel/Rival
var world_index: Control
@onready var dynamic_interface: Control = $HUD/DynamicInterface
var driver_bust: SubViewportContainer
var reticle: Control


func _ready() -> void:
	_apply_gore_setting()
	_build_world()
	_build_boat()
	if OS.get_environment("ATG_HUD_CAPTURE") != "1":
		_spawn_targets()
	if OS.get_environment("ATG_HUD_CAPTURE") != "1":
		_spawn_crowd()
	derby_audio = DERBY_AUDIO.new()
	derby_audio.name = "DerbyAudio"
	add_child(derby_audio)
	derby_audio.attach_engine_to(boat)
	kill_cam = KILL_CAM.new()
	kill_cam.name = "KillCam"
	$HUD.add_child(kill_cam)
	pit_radio = PIT_RADIO.new()
	pit_radio.name = "PitRadio"
	$HUD.add_child(pit_radio)
	pit_radio.attach_audio(derby_audio)
	world_index = WORLD_INDEX.new()
	world_index.name = "WorldIndexPanel"
	$HUD.add_child(world_index)
	# Greg: *"there no car hud for hull parts or character model in top right"*.
	# `celloutz_hud.gd` has drawn the bezel for a driver bust since A5.3, with a
	# comment saying the bust is "a 3D viewport owned by another node" — and
	# `DamagePortrait` was written, and then never instantiated anywhere in the
	# project, so every run has drawn an empty frame labelled DRIVER. It is owned
	# here now, and sits inside the bezel rather than next to it.
	driver_bust = DAMAGE_PORTRAIT.new()
	driver_bust.name = "DriverBust"
	driver_bust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(driver_bust)
	# After the add, not before: `DamagePortrait._ready()` sets a 168-square
	# minimum, which silently widens anything sized ahead of it back out past
	# the bezel.
	driver_bust.custom_minimum_size = Vector2.ZERO
	driver_bust.position = DRIVER_BUST_FRAME.position
	driver_bust.size = DRIVER_BUST_FRAME.size
	# The gunsight. Added before the keys card so the card's own panel draws over
	# it rather than under.
	reticle = CAB_RETICLE.new()
	reticle.name = "CabReticle"
	$HUD.add_child(reticle)
	# AG3.5. "Nothing in the derby says what any key does." The status line names
	# three of them and the other six were folded into a sentence nobody reads
	# while a wrecker is coming at them.
	keys_card = KEYS_CARD.new()
	keys_card.name = "KeysCard"
	$HUD.add_child(keys_card)
	keys_card.configure("F1", [
		{"group": "DRIVING", "rows": [
			["WASD", "DRIVE"],
			["MOUSE", "AIM THE GUN"],
			["F", "CAB / CHASE VIEW"],
		]},
		{"group": "THE GUN", "rows": [
			["LMB", "FIRE FROM THE CAB"],
			["R", "RELOAD"],
		]},
		{"group": "GETTING OUT", "rows": [
			["E", "CLIMB OUT OF THE CAR"],
			["ENTER", "ACCEPT THE RESULT"],
			["I", "WORLD INDEX"],
			["ESC", "RELEASE THE MOUSE"],
		]},
	])
	# Outcome text is event-only. The portrait, radar, hull schematic and corner
	# telemetry were rejected; the skiff now sheds its own panels instead.
	# AG3.2. The cab needs the pointer, because aiming is a thing you do with it.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	status.visible = false
	score_label.visible = false
	# A5.5. The last default-font label on the windscreen. The drawn hunt signal
	# carries all three of its numbers, in the display face, as an instrument.
	rival_label.visible = false
	if "show_title" in dynamic_interface:
		dynamic_interface.set("show_title", false)
	var crowd_banks: Array = []
	for index in range(0, crowd_members.size(), 16):
		crowd_banks.append((crowd_members[index] as Node3D).position + Vector3(0, 1.5, 0))
	derby_audio.seed_crowd(crowd_banks)
	CAST.ensure(CAPTAIN_SLOT, {
		"elo": 1180, "grudge": 0, "injury": "none", "status": "active", "memory": "Watching the derby",
	})
	WorldHistory.record_event("derby_session_started", {
		"venue": "rift_derby_quarry",
		"vehicle": "rift_skiff",
		"target_count": targets.size(),
	})
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	# AG3.4. Look and shoot. The car goes where you steer it; the gun goes where
	# you look, which is a different number, and holding both at once badly is
	# the texture Greg asked for.
	if event is InputEventMouseMotion and in_cab and not index_open and not leaving_on_foot:
		var motion := event as InputEventMouseMotion
		aim_yaw = clampf(aim_yaw - motion.relative.x * 0.0022, -1.15, 1.15)
		aim_pitch = clampf(aim_pitch - motion.relative.y * 0.0022, -0.5, 0.42)
	if event is InputEventMouseButton and event.pressed and not leaving_on_foot:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and in_cab and not index_open:
			_fire_from_cab()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_R and in_cab:
			_reload_cab_gun()
		elif event.keycode == KEY_F:
			_toggle_derby_view()
		elif event.keycode == KEY_I:
			index_open = not index_open
			if index_open:
				world_index.open()
			else:
				world_index.close()
		elif event.keycode == KEY_F1:
			keys_card.toggle()
		elif event.keycode == KEY_E:
			_begin_climbing_out()
		elif event.keycode == KEY_ENTER and round_state in ["won", "lost"]:
			_leave_derby(round_state)


func _physics_process(delta: float) -> void:
	# W1.1. A heat takes time out of the day like anything else does.
	WorldClock.advance(delta)
	boat.enabled = round_state == "active" and not index_open and not leaving_on_foot
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if leaving_on_foot:
		# AG3.3. Nothing else runs while the body is getting out. The heat is
		# over for you the moment you open the door.
		_update_climb_out(delta)
		_update_hud()
		return
	if index_open:
		return
	if round_state == "countdown":
		countdown -= delta
		mode_label.visible = true
		mode_label.text = "DISABLE EIGHT WRECKERS // %d" % maxi(1, ceili(countdown))
		if countdown <= 0.0:
			round_state = "active"
		# Greg: *"the cars in the derby ... you still cant shoot ... there no car
		# hud"*. This branch returned here, before the camera and the instruments
		# had run, so the whole countdown — the first thing anybody sees on
		# entering the derby — was rendered from wherever the scene happened to
		# leave the camera, which is the world origin, twenty-two metres from the
		# car. No cab, no wheel, no binnacle, no round count, and a view down the
		# track from nobody's eye. The gun and the cluster were never broken;
		# they were behind the camera. You spend a countdown sitting in the car,
		# so the countdown is rendered from inside it.
		_update_camera(delta)
		_update_hud()
		return
	if round_state != "active":
		_update_result(delta)
		_update_debris(delta)
		_update_camera(delta)
		_update_hud()
		return
	_update_boat(delta)
	_update_debris(delta)
	_update_wreckers(delta)
	_update_crowd(delta)
	_update_camera(delta)
	_update_respawns(delta)
	_update_hud()


## Gore is a settings choice now, not a hotkey over the pit. Read once at scene
## start so every body spawned in this heat agrees.
func _apply_gore_setting() -> void:
	BaselineHuman.clear_gore()
	viscera_fx = BaselineHuman.apply_gore_setting()


func _build_world() -> void:
	$WorldEnvironment.environment = WorldLook.environment("bone_yard")
	if OS.get_environment("ATG_HUD_CAPTURE") != "1":
		var authored_environment := BONE_YARD_ENVIRONMENT.instantiate()
		authored_environment.name = "AuthoredBoneYard"
		authored_environment.position.y = -0.12
		authored_environment.scale = Vector3(ARENA_SCALE, ARENA_SCALE, ARENA_SCALE)
		add_child(authored_environment)
		WorldLook.regrime(authored_environment, 17)
		_suppress_props(authored_environment)
		# Deterministic harnesses do not need hundreds of static mesh faces
		# rebuilt at startup; the simple arena floor below is sufficient.
		# AG1.6 is the exception: the question there is specifically whether
		# tearing down a fully built arena kills the game, so that harness asks
		# for the real one.
		if OS.get_environment("ATG_TEST_MODE") != "1" or OS.get_environment("ATG_FULL_ARENA") == "1":
			_add_authored_environment_collision(authored_environment)
	var floor := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(76.0 * ARENA_SCALE, 1.0, 76.0 * ARENA_SCALE)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.8
	floor.add_child(floor_collision)
	add_child(floor)
	# Floodlights are pools of light in a dim pit, not a uniform wash. Two of the
	# eight cast shadows: enough to anchor the wrecks without eight shadow maps.
	# G3.3. These used to alternate orange and green per light, which painted
	# whatever stood nearest whichever colour was overhead rather than letting
	# the pit's own contamination read — the actual complaint behind "the pit
	# reads close to monochrome": every surface was getting re-tinted twice.
	# `regrime()` and `WorldLook.surface()` already carry the salvage-teal,
	# rust and bloom colour on the materials themselves; a practical floodlight
	# colour lets that stand instead of competing with it.
	for index in 8:
		var light := OmniLight3D.new()
		var angle := TAU * index / 8.0
		light.position = Vector3(cos(angle) * 18.0 * ARENA_SCALE, 7.5 * ARENA_SCALE, sin(angle) * 18.0 * ARENA_SCALE)
		light.light_color = Color("e8d3ab")
		light.light_energy = 3.4
		light.omni_range = 19.0 * ARENA_SCALE
		# The pit lights the pit. A cabin has a roof and a floor and the arena's
		# floodlights should not be reaching the inside of it.
		light.light_cull_mask = 0xFFFFF & ~(1 << (INTERIOR.CAB_LAYER - 1))
		light.omni_attenuation = 1.25
		light.shadow_enabled = index % 4 == 0
		add_child(light)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -34, 0)
	sun.light_color = Color("ffcf9e")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_boat() -> void:
	boat = VEHICLE.new()
	boat.name = "MercyCountyWrecker"
	boat.position = Vector3(0, 0.75, 12.0 * SPAWN_SCALE)
	add_child(boat)
	boat.impact.connect(_on_vehicle_impact)
	var authored_skiff := SCRAP_SKIFF.instantiate()
	authored_skiff.name = "AuthoredScrapSkiff"
	authored_skiff.scale = Vector3(1.15, 1.15, 1.15)
	boat.add_child(authored_skiff)
	WorldLook.regrime(authored_skiff, 3)
	_dress_vehicle_biopunk(boat, 3)
	_add_vehicle_damage_parts(boat as RigidBody3D, 12)
	# AG3.2. Sit the player in it. Parented to the chassis, so the cab rolls and
	# pitches with the suspension for free — the interior does not need to know
	# the physics exist.
	interior = INTERIOR.new()
	interior.name = "Cab"
	boat.add_child(interior)
	interior.build(3)
	_cab_seat = INTERIOR.EYE
	# Everything on the player's car that is not the cab goes on the bodywork
	# layer, which the cab camera does not render. Done after the dressing so
	# the generated greebles are caught too.
	_on_bodywork_layer(boat)
	_apply_view_masks()


## The player's own bodywork. Only theirs — every other car in the pit stays on
## the default layer, because you are supposed to see those from inside.
const BODYWORK_LAYER := 2


func _on_bodywork_layer(node: Node) -> void:
	if node == interior:
		return
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 << (BODYWORK_LAYER - 1)
	for child in node.get_children():
		_on_bodywork_layer(child)


## One camera, two things it is allowed to see. In the cab: everything except
## your own bodywork. Outside it: everything except the cab.
func _apply_view_masks() -> void:
	var everything := 0xFFFFF
	var bodywork := 1 << (BODYWORK_LAYER - 1)
	var cab := 1 << (INTERIOR.CAB_LAYER - 1)
	camera.cull_mask = (everything & ~bodywork) if in_cab else (everything & ~cab)


func _spawn_targets() -> void:
	for index in 12:
		_create_wrecker(index)


func _create_wrecker(index: int) -> void:
	var angle := TAU * index / 12.0 + 0.23
	var lane := (13.5 if index % 2 == 0 else 17.0) * SPAWN_SCALE
	# AI wreckers run the same chassis as the player. They are steered, never
	# teleported, so a ram leaves them spinning instead of snapping back on the
	# following frame.
	var target := VEHICLE.new()
	target.name = "MaraVoss_Wrecker" if index == 0 else "ScrapWrecker_%02d" % index
	target.position = Vector3(cos(angle) * lane * 1.35, 0.8, sin(angle) * lane * 0.78)
	target.set_meta("integrity", 160 if index == 0 else 100)
	target.set_meta("is_rival", index == 0)
	target.set_meta("hit_ready_msec", 0)
	target.set_meta("player_hit_ready_msec", 0)
	target.set_meta("spawn_index", index)
	add_child(target)
	# G0.2. Physics contacts are not guaranteed to report the useful closing
	# normal on both bodies. A parked player often emitted nothing while the
	# attacking wrecker measured a 17m/s vehicle contact. Listen to the attacker
	# too, otherwise a clean AI ram can be physically real and mechanically mute.
	target.impact.connect(_on_wrecker_impact.bind(target))
	var ai_driver := AI_DRIVER.new()
	ai_driver.name = "AIDriver"
	target.add_child(ai_driver)
	ai_driver.configure(target, index + 1)
	ai_driver.arena_limit = ARENA_LIMIT * 0.9
	var authored_skiff := SCRAP_SKIFF.instantiate()
	authored_skiff.name = "ScrapVehicleShell"
	authored_skiff.scale = Vector3(1.05, 1.05, 1.05)
	target.add_child(authored_skiff)
	if index % 3 == 1:
		authored_skiff.rotation.y = PI
	if index == 0:
		authored_skiff.scale *= 1.12
	WorldLook.regrime(authored_skiff, index + 5)
	_dress_vehicle_biopunk(target, index + 5, false)
	_add_vehicle_damage_parts(target, index)
	_add_driver_rig(target, index)
	targets.append(target)


func _update_boat(_delta: float) -> void:
	var throttle := Input.get_axis("move_back", "move_forward")
	var steering := Input.get_axis("move_left", "move_right")
	boat.throttle = throttle
	boat.steering = steering
	speed = boat.signed_speed
	boat_velocity = boat.linear_velocity
	if boat.position.y < -10.0:
		boat.recover(Vector3(0, 1.2, 12.0 * SPAWN_SCALE))
	if derby_audio != null:
		derby_audio.call("update_engine", speed, throttle)


func _update_wreckers(delta: float) -> void:
	active_seconds += delta
	reassign_timer -= delta
	if reassign_timer <= 0.0:
		reassign_timer = REASSIGN_EVERY
		_assign_wrecker_roles()
	for target in targets:
		if not is_instance_valid(target):
			continue
		var ai_driver := target.get_node_or_null("AIDriver")
		if ai_driver == null:
			continue
		ai_driver.tick(delta, _wrecker_target_position(target), round_state == "active")


## Who is allowed to come at the player right now. Rotated on a timer rather
## than fixed at spawn, so pressure moves around the pit and no single car
## spends the whole heat welded to the player's door.
func _assign_wrecker_roles() -> void:
	# Starts at two, not one. A single hunter across a pit this size left a
	# parked player untouched for a full thirty seconds on some runs — the cap
	# is there to stop a pile-on, not to make the heat passive.
	var allowed := 2 + floori(clampf(active_seconds / ENGAGE_RAMP, 0.0, 1.0) * float(MAX_ENGAGED - 2))
	var live: Array[Node3D] = []
	for target in targets:
		if is_instance_valid(target):
			live.append(target)
	live.sort_custom(func(a, b): return a.global_position.distance_to(boat.global_position) < b.global_position.distance_to(boat.global_position))
	for index in live.size():
		var wrecker := live[index]
		var ai_driver := wrecker.get_node_or_null("AIDriver")
		if ai_driver == null:
			continue
		if index < allowed:
			wrecker.set_meta("wrecker_role", "hunt")
			ai_driver.role = "hunt"
		elif index < allowed + 2:
			# A short ring of cars circling the player, in the fight visually
			# without adding to the pile-up.
			wrecker.set_meta("wrecker_role", "circle")
			ai_driver.role = "circle"
		else:
			# Everyone else fights each other. Each duellist is paired with a
			# different rival so the spare cars do not all converge on one.
			wrecker.set_meta("wrecker_role", "duel")
			ai_driver.role = "duel"
			var rival := live[(index + 1 + index % 3) % live.size()]
			if rival == wrecker:
				rival = live[(index + 1) % live.size()]
			wrecker.set_meta("duel_target", rival.get_path())


func _wrecker_target_position(wrecker: Node3D) -> Vector3:
	if str(wrecker.get_meta("wrecker_role", "hunt")) != "duel":
		return boat.global_position
	var rival := get_node_or_null(wrecker.get_meta("duel_target", NodePath()))
	if rival == null or not is_instance_valid(rival) or rival == wrecker:
		return boat.global_position
	return (rival as Node3D).global_position


func _on_vehicle_impact(other: Node, closing_speed: float, self_share: float) -> void:
	if round_state != "active" or not is_instance_valid(other):
		return
	_shake_camera(closing_speed)
	if targets.has(other):
		_damage_target(other, closing_speed, self_share)
	elif closing_speed > 7.0:
		integrity = maxi(0, integrity - roundi(closing_speed * 0.4))
		_update_player_damage_visual(Vector3.ZERO)
		if pit_radio != null and closing_speed > 11.0:
			pit_radio.transmit("hit_player")
		derby_audio.play_impact(clampf(closing_speed / 24.0, 0.0, 1.0), boat.global_position, "heavy")
		if integrity <= 0:
			_finish_round("lost")


func _on_wrecker_impact(other: Node, closing_speed: float, self_share: float, wrecker: Node3D) -> void:
	if round_state != "active" or other != boat or not is_instance_valid(wrecker):
		return
	var now := Time.get_ticks_msec()
	if now < int(wrecker.get_meta("player_hit_ready_msec", 0)):
		return
	wrecker.set_meta("player_hit_ready_msec", now + 520)
	var attacker_share := clampf(self_share, 0.0, 1.0)
	var damage := clampi(roundi(closing_speed * 0.55 * (0.4 + attacker_share * 0.6)), 1, 18)
	integrity = maxi(0, integrity - damage)
	_update_player_damage_visual((boat.global_position - wrecker.global_position).normalized())
	_shake_camera(closing_speed)
	if pit_radio != null and closing_speed > 11.0:
		pit_radio.transmit("hit_player")
	if derby_audio != null:
		derby_audio.play_impact(clampf(closing_speed / 24.0, 0.0, 1.0), boat.global_position, "heavy")
	WorldHistory.record_event("derby_player_impact", {
		"attacker": wrecker.name,
		"closing_speed": snappedf(closing_speed, 0.1),
		"damage": damage,
		"hull_after": integrity,
	})
	if integrity <= 0:
		_finish_round("lost")


func _damage_target(target: Node3D, collision_speed: float = 0.0, self_share: float = 1.0) -> void:
	if round_state != "active":
		return
	var now: int = Time.get_ticks_msec()
	if now < int(target.get_meta("hit_ready_msec", 0)):
		return
	target.set_meta("hit_ready_msec", now + 520)
	var impact_energy: int = roundi(collision_speed * 10.0)
	# Damage rises with the square of closing speed so a committed ram strips
	# panels on the first contact instead of the fifth, and the share of the
	# closing speed each car brought decides which of them wears it.
	var force := clampf(collision_speed / 18.0, 0.0, 1.8)
	var energy := 10.0 + force * force * 46.0
	var damage: int = clampi(roundi(energy * (0.35 + 0.65 * self_share)), 6, 95)
	var target_integrity: int = maxi(0, int(target.get_meta("integrity", 100)) - damage)
	target.set_meta("integrity", target_integrity)
	score += damage * 5
	integrity = maxi(0, integrity - clampi(roundi(energy * 0.22 * (0.35 + 0.65 * (1.0 - self_share))), 1, 34))
	var impact_direction := (target.global_position - boat.global_position).normalized()
	_update_player_damage_visual(-impact_direction)
	_update_wrecker_damage_visual(target, target_integrity, impact_direction)
	_update_detachable_parts(target, target_integrity, impact_direction)
	if damage >= 28:
		@warning_ignore("integer_division")
		_spawn_impact_debris(target.global_position, impact_direction, mini(10, damage / 8))
	# Once the bumper and hood are gone there is nothing between the player's
	# front end and the cab, so a fast hit there reaches the driver directly.
	var detached: Array = target.get_meta("detached_parts", [])
	var front_stripped: bool = detached.has("BumperFront") and detached.has("Hood")
	var ram_crush: bool = front_stripped and collision_speed > 13.0
	_injure_driver(target, damage, impact_direction, ram_crush)
	crowd_reaction = clampf(crowd_reaction + damage / 22.0, 0.0, 2.0)
	if derby_audio != null:
		derby_audio.call("play_impact", clampf(float(damage) / 34.0, 0.0, 1.0), target.global_position, "heavy" if ram_crush else "panel")
	if dynamic_interface.has_method("announce_impact"):
		dynamic_interface.announce_impact(damage, bool(target.get_meta("is_rival", false)))
	WorldHistory.record_event("derby_vehicle_hit", {
		"venue": "rift_derby_quarry", "target_id": target.name, "damage": damage,
		"target_integrity": target_integrity, "impact_energy": impact_energy,
	})
	if pit_radio != null:
		pit_radio.transmit("took_hit" if damage < 30 else "player_winning")
	if bool(target.get_meta("is_rival", false)):
		var current := WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT))
		var grudge := mini(100, int(current.get("grudge", 0)) + 8)
		var injury := "bruised ribs" if target_integrity > 0 else "fractured left arm"
		WorldHistory.update_subject(CAST.id_for(CAPTAIN_SLOT), {
			"grudge": grudge, "injury": injury, "elo": int(current.get("elo", 1180)) + 12,
			"status": "injured" if target_integrity <= 0 else "engaged",
			"memory": "You rammed her Wrecker at the Bone Yard.",
		}, "rival_memory_formed")
	if target_integrity <= 0:
		_wreck_target(target, impact_energy)
	if integrity <= 0:
		_finish_round("lost")


func _wreck_target(target: Node3D, impact_energy: int) -> void:
	for index in 18:
		var chunk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22 + (index % 3) * 0.14, 0.22 + (index % 2) * 0.22, 0.22)
		var is_viscera := viscera_fx and index % 3 == 0
		var color := Color("641611") if is_viscera else Color("6b5340")
		mesh.material = _material(color, 0.0, "flesh" if is_viscera else "rust", index + 1)
		chunk.mesh = mesh
		add_child(chunk)
		chunk.global_position = target.global_position + Vector3(0, 0.8, 0)
		var outward := (chunk.global_position - boat.global_position).normalized()
		debris.append({"node": chunk, "velocity": outward * (5.0 + index % 5) + Vector3.UP * (3.0 + index % 4), "life": 2.6})
	targets.erase(target)
	disabled_count += 1
	if disabled_count < 8:
		respawn_queue.append({"seconds": 5.5, "spawn_index": int(target.get_meta("spawn_index", 0))})
	target.queue_free()
	WorldHistory.record_event("derby_vehicle_disabled", {
		"venue": "rift_derby_quarry",
		"vehicle": "rift_skiff",
		"target_id": target.name,
		"impact_energy": impact_energy,
		"remaining_integrity": integrity,
		"score_after_impact": score,
	})
	if disabled_count >= 8:
		_finish_round("won")


func _update_wrecker_damage_visual(target: Node3D, target_integrity: int, impact_direction := Vector3.ZERO) -> void:
	var shell := target.get_node_or_null("ScrapVehicleShell") as Node3D
	if shell == null:
		return
	var crush := clampf(float(100 - target_integrity) / 100.0, 0.0, 0.72)
	shell.scale = Vector3(1.05 + crush * 0.1, 1.05 - crush * 0.2, 1.05 - crush * 0.08)
	# Fold the shell away from the side the hit came from. Uniform scaling reads
	# as a car shrinking; an asymmetric fold reads as a car taking a beating.
	var local := target.global_transform.basis.inverse() * impact_direction
	shell.rotation.z = clampf(-local.x, -1.0, 1.0) * crush * 0.22
	shell.rotation.x = clampf(local.z, -1.0, 1.0) * crush * 0.16
	shell.position = Vector3(local.x, 0.0, local.z) * crush * 0.18


func _update_player_damage_visual(impact_direction: Vector3) -> void:
	_update_detachable_parts(boat, integrity, impact_direction)
	var shell := boat.get_node_or_null("AuthoredScrapSkiff") as Node3D
	if shell == null:
		return
	var crush := clampf(float(100 - integrity) / 100.0, 0.0, 0.55)
	var local := boat.global_transform.basis.inverse() * impact_direction
	shell.scale = Vector3(1.15 + crush * 0.05, 1.15 - crush * 0.16, 1.15 - crush * 0.05)
	shell.rotation.z = clampf(-local.x, -1.0, 1.0) * crush * 0.16
	shell.rotation.x = clampf(local.z, -1.0, 1.0) * crush * 0.10


func _spawn_impact_debris(at: Vector3, direction: Vector3, count: int) -> void:
	if debris.size() > 220:
		return
	for index in count:
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.16 + randf() * 0.2, 0.05 + randf() * 0.09, 0.14 + randf() * 0.18)
		mesh.material = _material(Color("55402c") if index % 2 == 0 else Color("2b3328"), 0.0, "rust", index + 7)
		shard.mesh = mesh
		add_child(shard)
		shard.global_position = at + Vector3(randf_range(-0.6, 0.6), 0.7 + randf() * 0.6, randf_range(-0.6, 0.6))
		var spray := (direction + Vector3(randf_range(-0.7, 0.7), randf_range(0.4, 1.1), randf_range(-0.7, 0.7))).normalized()
		debris.append({"node": shard, "velocity": spray * (4.0 + randf() * 5.0), "life": 1.8})


func _shake_camera(closing_speed: float) -> void:
	camera_shake = clampf(maxf(camera_shake, closing_speed / 22.0), 0.0, 1.35)


func _update_respawns(delta: float) -> void:
	if round_state != "active":
		return
	for pending in respawn_queue.duplicate():
		pending.seconds -= delta
		if pending.seconds <= 0.0:
			_create_wrecker(int(pending.spawn_index))
			respawn_queue.erase(pending)


func _update_debris(delta: float) -> void:
	for piece in debris.duplicate():
		if not is_instance_valid(piece.node) or not piece.node.is_inside_tree():
			debris.erase(piece)
			continue
		piece.velocity.y -= 12.0 * delta
		piece.node.position += piece.velocity * delta
		piece.node.rotate(Vector3(1, 0.7, 0.3).normalized(), delta * 7.0)
		piece.life -= delta
		if piece.life <= 0.0:
			piece.node.queue_free()
			debris.erase(piece)


## A7.6. The camera has to answer the new physics or the suspension work is
## invisible from the driver's seat: speed pulls the frame back and widens the
## lens, and a wheel letting go shakes it. Both read off the chassis rather than
## off the input, so they respond to what the car is *doing*.
const CAMERA_FOV_REST := 70.0
const CAMERA_FOV_FLAT := 88.0


## AG3.2. Two views, one of which has to be earned. M1 made third person the
## thing you unlock on foot; the derby is the same body and the same rule.
func _toggle_derby_view() -> void:
	if in_cab and not _third_person_earned():
		if pit_radio != null:
			pit_radio.transmit("hit_player")
		WorldHistory.record_event("derby_third_person_refused", {"venue": "rift_derby_quarry"})
		return
	in_cab = not in_cab
	_apply_view_masks()
	WorldHistory.record_event("derby_view_changed", {"view": "cab" if in_cab else "chase"})


## The same condition the Hunt Grounds uses, read off the record rather than
## duplicated as a flag: you have put a named rival down.
func _third_person_earned() -> bool:
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) != "npc_resolution":
			continue
		var details: Dictionary = event.get("details", {})
		if str(details.get("resolution", "")) == "killed" and str(details.get("subject_id", "")) != "":
			return true
	return int(WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT)).get("grudge", 0)) >= 40


func _update_camera(delta: float) -> void:
	camera_shake = maxf(0.0, camera_shake - delta * 2.4)
	if in_cab:
		_update_cab_camera(delta)
		return
	var forward := -boat.global_transform.basis.z
	var pace := clampf(absf(float(boat.get("signed_speed"))) / 24.0, 0.0, 1.0)
	# Further back and higher with speed, so the horizon opens up as it matters.
	var desired := boat.global_position - forward * lerpf(13.0, 17.0, pace) + Vector3.UP * lerpf(6.8, 8.0, pace)
	camera.global_position = camera.global_position.lerp(desired, min(delta * 4.5, 1.0))
	camera.fov = lerpf(camera.fov, lerpf(CAMERA_FOV_REST, CAMERA_FOV_FLAT, pace * pace), min(delta * 3.0, 1.0))
	# A wheel breaking traction is worth feeling. Small, continuous, and separate
	# from the impact jolt so a slide does not read as a collision.
	var slip := float(boat.get("wheel_slip"))
	var beat := float(Time.get_ticks_msec()) * 0.001
	if slip > 0.02:
		camera.global_position += Vector3(sin(beat * 83.0), cos(beat * 71.0), 0.0) * slip * 0.09
	if camera_shake > 0.0:
		# Applied after the follow lerp; smoothing a jolt at 4.5/s erases it.
		camera.global_position += Vector3(sin(beat * 47.0), cos(beat * 61.0), sin(beat * 39.0)) * camera_shake * 0.7
	camera.look_at(boat.global_position + forward * 8.0 + Vector3.UP * 1.2)


## The view from the seat. The camera is not following the car — it *is* in the
## car, so every jolt the suspension takes arrives without being smoothed, which
## is most of why a chase camera never feels like driving.
func _update_cab_camera(_delta: float) -> void:
	var seat := boat.global_transform * _cab_seat
	camera.global_position = seat
	# Look where the car looks, plus where the driver is looking. Multiplying in
	# this order keeps the aim in car space, so a slide moves your aim with the
	# car instead of leaving it pointing at the horizon.
	var basis := boat.global_transform.basis * Basis(Vector3.UP, aim_yaw) * Basis(Vector3.RIGHT, aim_pitch)
	camera.global_transform = Transform3D(basis.orthonormalized(), seat)
	# M4.3. The first-person value, not the chase pair. Godot's fov is vertical,
	# so 78 here is roughly 110 across at 16:9.
	camera.fov = lerpf(camera.fov, 78.0, minf(_delta * 4.0, 1.0))
	if camera_shake > 0.0:
		var beat := float(Time.get_ticks_msec()) * 0.001
		camera.global_position += Vector3(sin(beat * 47.0), cos(beat * 61.0), sin(beat * 39.0)) * camera_shake * 0.10
	if interior != null and is_instance_valid(interior):
		interior.drive(float(boat.get("steering")), float(boat.get("throttle")))


## AG3.4. A round leaves the gun, goes through your own windscreen, and lands on
## something. The glass keeps the hole for the rest of the heat.
func _fire_from_cab() -> void:
	if fire_cooldown > 0.0:
		return
	# Greg: *"you still cant shoot"*. Half of that was the camera being outside
	# the car (b5afadb) and half was this: before the flag dropped, the trigger
	# did nothing at all and said nothing about it, which from the seat is
	# exactly what a broken key looks like. The sight answers now.
	if round_state != "active":
		if reticle != null and is_instance_valid(reticle):
			reticle.call("refuse")
		if derby_audio != null:
			derby_audio.play_impact(0.04, boat.global_position, "light")
		return
	if rounds_left <= 0:
		if reticle != null and is_instance_valid(reticle):
			reticle.call("refuse")
		if derby_audio != null:
			derby_audio.play_impact(0.05, boat.global_position, "light")
		return
	rounds_left -= 1
	fire_cooldown = 0.16
	# The hole goes where you were aiming, in glass-local terms.
	if interior != null and is_instance_valid(interior):
		interior.punch_through(Vector2(-aim_yaw / 1.15, aim_pitch / 0.5))
	var from := camera.global_position
	var along := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from + along * 1.4, from + along * 140.0)
	query.exclude = [boat.get_rid()]
	var hit := space.intersect_ray(query)
	if derby_audio != null:
		derby_audio.play_impact(0.55, boat.global_position, "light")
	camera_shake = maxf(camera_shake, 0.16)
	if hit.is_empty():
		return
	var struck: Node = hit.get("collider")
	if struck != null and targets.has(struck):
		# A bullet is not a ram. It does less, and it does it from further away,
		# which is the trade the gun exists to offer.
		_damage_target(struck as Node3D, 9.0, 1.0)
		WorldHistory.record_event("derby_shot_landed", {"venue": "rift_derby_quarry", "target": struck.name})


func _reload_cab_gun() -> void:
	if rounds_left >= 12 or round_state != "active":
		return
	rounds_left = 12
	fire_cooldown = 0.9
	if derby_audio != null:
		derby_audio.play_impact(0.12, boat.global_position, "light")


## AG3.3. You climb out. Greg: *"not progressing out of the car animation"* —
## pressing E used to swap the scene on the same frame, which reads as the game
## closing rather than as you leaving.
func _begin_climbing_out() -> void:
	if leaving_on_foot or leaving:
		return
	leaving_on_foot = true
	climbing_out = 0.0
	if index_open:
		index_open = false
		world_index.close()
	WorldHistory.record_event("player_left_derby_vehicle", {"venue": "rift_derby_quarry", "destination": "bone_yard_outskirts"})


func _update_climb_out(delta: float) -> void:
	climbing_out = minf(1.0, climbing_out + delta * 0.85)
	# Out of the seat, through where the door is, and up onto your feet. Three
	# points rather than a straight line, because a person leaving a car does
	# not travel in one.
	var seat := boat.global_transform * _cab_seat
	var sill := boat.global_transform * Vector3(-1.55, 0.18, -0.06)
	var standing := boat.global_transform * Vector3(-2.35, 0.52, 0.2)
	var eased := ease(climbing_out, 0.72)
	var at: Vector3 = seat.lerp(sill, minf(eased * 2.0, 1.0))
	if eased > 0.5:
		at = sill.lerp(standing, (eased - 0.5) * 2.0)
	camera.global_position = at
	# The head turns back toward the pit as you straighten up, so the last thing
	# you see is what you are walking away from.
	var look := boat.global_position + boat.global_transform.basis.z * lerpf(-6.0, 3.0, eased) + Vector3.UP * 1.1
	camera.look_at(look, Vector3.UP)
	camera.fov = lerpf(camera.fov, 70.0, minf(delta * 3.0, 1.0))
	if climbing_out >= 0.3:
		# Once you are out of the seat you are looking at your own car again, so
		# the bodywork comes back and the cab goes away.
		camera.cull_mask = 0xFFFFF & ~(1 << (INTERIOR.CAB_LAYER - 1))
	if climbing_out >= 1.0 and not leaving:
		leaving = true
		Interstitial.travel("res://bone_yard_hunt.tscn", "walking out into the ashbloom expanse")


func _update_hud() -> void:
	# AG3.1. The instruments. These are the readouts `_ready` used to switch off
	# outright; they live on the dashboard now, where you can look at them.
	if interior != null and is_instance_valid(interior):
		var rival_subject := WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT))
		var rival_running := false
		for target in targets:
			if is_instance_valid(target) and bool(target.get_meta("is_rival", false)):
				rival_running = true
				break
		interior.report({
			"hull": float(integrity),
			"pace": clampf(absf(float(boat.get("signed_speed"))) / MAX_SPEED, 0.0, 1.0),
			"impacts": score,
			"wreckers_left": maxi(0, 8 - disabled_count),
			"wreckers_total": 8,
			"rival_grudge": int(rival_subject.get("grudge", 0)),
			"rival_here": rival_running,
			"rounds": rounds_left,
			"rounds_full": 12,
		})
	# The bust takes the damage the car takes, which is what makes it a readout
	# rather than an ornament.
	if driver_bust != null and is_instance_valid(driver_bust):
		driver_bust.call("set_damage", clampf(1.0 - float(integrity) / 100.0, 0.0, 1.0))
	# The sight is up only when the gun would actually answer: in the cab, round
	# live, nothing else on screen. Anywhere else it would be a promise the game
	# does not keep, which is the complaint it exists to fix.
	if reticle != null and is_instance_valid(reticle):
		var cab_clear := in_cab and not index_open and not leaving_on_foot
		reticle.call("report",
			cab_clear and round_state == "active",
			# Caged rather than gone during the countdown: a sight that vanishes
			# teaches there is no gun, which is the thing it exists to unteach.
			cab_clear and round_state == "countdown",
			rounds_left <= 0,
			clampf(fire_cooldown / 0.16, 0.0, 1.0))
	status.text = "BONE YARD DERBY  //  %s\nWASD DRIVE  ·  I WORLD INDEX  ·  E LEAVE VEHICLE" % round_state.to_upper()
	score_label.text = "IMPACT SCORE  %05d\nHULL INTEGRITY  %03d%%\nACTIVE WRECKERS  %02d\nWORLD MEMORY  %03d" % [score, integrity, targets.size(), WorldHistory.event_count()]
	# Only speaks when it has something to say. Left visible during play it sat
	# on top of the control ribbon repeating what the ribbon already showed.
	mode_label.visible = round_state != "active"
	# The countdown case is here rather than only in `_physics_process`: now that
	# the countdown runs the HUD (so the player can see the cab they are sitting
	# in), this line runs during it too and used to blank the objective straight
	# back out on the same frame it was set.
	mode_label.text = ("VICTORY  //  HAULED OUT TO ASHBLOOM IN %d" % maxi(1, ceili(result_countdown)) if round_state == "won" else "WRECKED  //  DRAGGED INTO ASHBLOOM IN %d" % maxi(1, ceili(result_countdown)) if round_state == "lost" else "DISABLE EIGHT WRECKERS  //  %d" % maxi(1, ceili(countdown)) if round_state == "countdown" else "")
	var rival := WorldHistory.subject(CAST.id_for(CAPTAIN_SLOT))
	rival_label.text = "HUNT ARC  //  %s\n%s  ·  GRUDGE %03d  ·  ELO %04d\n[I] WORLD INDEX" % [str(rival.get("name", "THE CAPTAIN")).to_upper(), str(rival.get("status", "active")).to_upper(), int(rival.get("grudge", 0)), int(rival.get("elo", 1180))]
	# Computed once for both readouts. It used to live inside the cab-screen
	# branch, which is why the windscreen radar had no contacts to draw.
	var contacts: Array = []
	var forward := -boat.global_transform.basis.z
	var right := boat.global_transform.basis.x
	for target in targets:
		if not is_instance_valid(target):
			continue
		var delta_position := target.global_position - boat.global_position
		contacts.append({
			"offset": Vector2(delta_position.dot(right), -delta_position.dot(forward)),
			"integrity": int(target.get_meta("integrity", 100)),
			"rival": bool(target.get_meta("is_rival", false)),
		})
	if dynamic_interface.has_method("set_telemetry"):
		dynamic_interface.set_telemetry({
			"speed": speed,
			"score": score,
			"integrity": integrity,
			"active_wreckers": targets.size(),
			"memory_count": WorldHistory.event_count(),
			"rival_status": rival.get("status", "active"),
			"rival_grudge": rival.get("grudge", 0),
			"rival_elo": rival.get("elo", 1180),
			# The radar needs the same contacts the cab screens already get. The
			# data existed; the windscreen simply never received it.
			"contacts": contacts,
			"arena_limit": ARENA_LIMIT,
		})


func _suppress_props(root: Node) -> void:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if current is MeshInstance3D and SUPPRESSED_PROPS.has(current.name):
			(current as MeshInstance3D).visible = false


## The player's shed panels are tracked on the chassis the same way the AI cars
## track theirs, so the dash schematic reads from real state.
func _player_parts_lost() -> Array:
	return boat.get_meta("detached_parts", [])


## The index reads `WorldHistory` directly now. This used to assemble a list of
## prose strings and push them into a `Label`, which is why it could only ever
## show one rival: the panel had no access to anything it was not handed.
func _refresh_world_index() -> void:
	if world_index:
		world_index.refresh()


## The heat resolves on its own. Making the player press a key to acknowledge an
## outcome the world already decided reads as a test harness, not a game.
func _update_result(delta: float) -> void:
	if leaving or not (round_state in ["won", "lost"]):
		return
	result_countdown = maxf(0.0, result_countdown - delta)
	if result_countdown <= 0.0:
		_leave_derby(round_state)


func _leave_derby(result: String) -> void:
	if leaving:
		return
	leaving = true
	WorldHistory.record_event("derby_result_accepted", {"result": result, "score": score, "disabled": disabled_count})
	Interstitial.travel("res://bone_yard_hunt.tscn", "walking out into the ashbloom expanse")


func _finish_round(result: String) -> void:
	if round_state != "active":
		return
	round_state = result
	mode_label.visible = true
	speed = 0.0
	result_countdown = 5.0
	respawn_queue.clear()
	WorldHistory.record_event("derby_round_%s" % result, {"venue": "rift_derby_quarry", "score": score, "disabled": disabled_count, "integrity": integrity})


func _add_authored_environment_collision(root_node: Node) -> void:
	var keywords := ["outer_quarry", "quarry_base", "arena_floor", "inner_barrier", "stand_", "mechanic_shop", "exit_gate", "launch_ramp", "freight_container", "mercy_highway", "limbo_building", "mercy_servo", "servo_canopy", "dead_signal_motel", "tunnel_ridge", "tunnel_mouth"]
	var pending: Array[Node] = [root_node]
	while not pending.is_empty() and authored_collision_count < 180:
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if current is MeshInstance3D:
			var lowered := current.name.to_lower()
			var should_collide := false
			for keyword in keywords:
				if lowered.contains(keyword):
					should_collide = true
					break
			if should_collide:
				(current as MeshInstance3D).create_trimesh_collision()
				authored_collision_count += 1
	WorldHistory.record_event("authored_collision_built", {"venue": "rift_derby_quarry", "mesh_count": authored_collision_count})


## G2.1-G2.3. `regrime()` only ever remaps the toybox material names already
## baked into the glTF, which is a colour fix. It cannot add a strut, a bloom
## or a scab, because there is nothing in the authored mesh to remap onto
## one. Silhouette's vehicle kit hangs those on afterward, parented to the
## chassis body itself so the greebles sit in real chassis-local metres
## regardless of whatever scale the authored shell renders at.
func _dress_vehicle_biopunk(target: Node3D, seed_value: int, include_spatter: bool = true) -> void:
	SILHOUETTE.dress_vehicle(target, CHASSIS_DIMENSIONS, VEHICLE.WHEEL_ANCHORS, seed_value, Callable(self, "_vehicle_surface"), include_spatter)


func _vehicle_surface(tint: Color, kind: String, seed_value: int) -> StandardMaterial3D:
	return WorldLook.surface(tint, kind, seed_value)


func _add_vehicle_damage_parts(target: RigidBody3D, index: int) -> void:
	var damage_root := Node3D.new()
	damage_root.name = "DamageParts"
	target.add_child(damage_root)
	var color := Color("2b3328") if index % 2 == 0 else Color("3d1c11")
	_add_damage_part(damage_root, "DoorLeft", Vector3(-1.38, 0.25, 0.15), Vector3(0.16, 0.82, 1.65), color)
	_add_damage_part(damage_root, "DoorRight", Vector3(1.38, 0.25, 0.15), Vector3(0.16, 0.82, 1.65), color)
	_add_damage_part(damage_root, "Hood", Vector3(0, 0.7, -1.55), Vector3(2.25, 0.16, 1.2), color.darkened(0.12))
	_add_damage_part(damage_root, "BumperFront", Vector3(0, 0.0, -2.48), Vector3(2.65, 0.22, 0.25), Color("46331f"))
	_add_damage_part(damage_root, "BumperRear", Vector3(0, 0.0, 2.48), Vector3(2.65, 0.22, 0.25), Color("46331f"))
	for wheel_index in 4:
		var x := -1.42 if wheel_index % 2 == 0 else 1.42
		var z := -1.55 if wheel_index < 2 else 1.55
		_add_damage_part(damage_root, "Wheel%d" % wheel_index, Vector3(x, -0.42, z), Vector3(0.42, 0.78, 0.78), Color("181515"))
	target.set_meta("detached_parts", [])


func _add_damage_part(parent: Node3D, part_name: String, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = _material(color, 0.0)
	part.mesh = mesh
	part.position = at
	parent.add_child(part)


func _update_detachable_parts(target: Node3D, target_integrity: int, impact_direction: Vector3) -> void:
	var thresholds := {75: "BumperFront", 62: "DoorLeft", 49: "Hood", 36: "DoorRight", 24: "Wheel0", 12: "BumperRear"}
	for threshold in thresholds:
		if target_integrity <= int(threshold):
			_detach_vehicle_part(target, str(thresholds[threshold]), impact_direction)


func _detach_vehicle_part(target: Node3D, part_name: String, impact_direction: Vector3) -> void:
	var detached: Array = target.get_meta("detached_parts", [])
	if detached.has(part_name):
		return
	var part := target.get_node_or_null("DamageParts/%s" % part_name) as MeshInstance3D
	if part == null:
		return
	detached.append(part_name)
	target.set_meta("detached_parts", detached)
	var loose := RigidBody3D.new()
	loose.name = "%s_Detached" % part_name
	loose.mass = 16.0 if not part_name.begins_with("Wheel") else 28.0
	add_child(loose)
	loose.global_transform = part.global_transform
	var visual := MeshInstance3D.new()
	visual.mesh = part.mesh
	loose.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = part.get_aabb().size
	collision.shape = shape
	loose.add_child(collision)
	loose.apply_central_impulse(impact_direction * 210.0 + Vector3.UP * 95.0)
	loose.apply_torque_impulse(Vector3(35, 80, 24))
	part.queue_free()
	get_tree().create_timer(14.0).timeout.connect(loose.queue_free)
	WorldHistory.record_event("vehicle_part_detached", {"vehicle": target.name, "part": part_name})


func _add_driver_rig(target: RigidBody3D, index: int) -> void:
	var subject_id := CAST.id_for(CAPTAIN_SLOT) if index == 0 else "derby_driver_%02d" % index
	var driver := BaselineHuman.new()
	driver.name = "DriverRig"
	driver.position = Vector3(0, -0.15, 0.25)
	target.add_child(driver)
	var config := {
		"seated": true,
		"flesh": Color("6b5842"),
		"variation": index + 2,
		"blood": 5600.0 if index == 0 else 5000.0,
	}
	# Bodies remember. A driver who left the last heat with a ruined arm starts
	# this one with it, because the rig restores from their recorded anatomy.
	var saved: Dictionary = WorldHistory.subject(subject_id)
	if saved.get("anatomy_state") is Dictionary:
		config["restore"] = saved.anatomy_state
	driver.build(subject_id, config)
	target.set_meta("driver_subject", subject_id)


func _injure_driver(target: Node3D, damage: int, impact_direction: Vector3, ram_crush: bool = false) -> void:
	var rig := target.get_node_or_null("DriverRig") as BaselineHuman
	if rig == null or rig.anatomy.dead:
		return
	var transfer := 1.45 if ram_crush else 0.42
	var subject_id := str(target.get_meta("driver_subject", "unknown"))
	# A front end through the cab takes the chest. Everything else lands where
	# the geometry says it landed, rather than on a coin flip between two zones.
	var zone := "torso" if ram_crush else rig.zone_nearest(rig.global_position + Vector3(0, 0.55, 0) - impact_direction * 0.5)
	rig.gore = viscera_fx
	rig.hit(zone, float(damage) * transfer, float(damage) * 2.0, "shear" if ram_crush else "blunt")
	WorldHistory.record_event("derby_driver_injured", {
		"subject_id": subject_id, "zone": zone, "damage": damage,
		"blood": roundi(rig.anatomy.blood_remaining), "ram_crush": ram_crush,
	})
	WorldHistory.update_subject(subject_id, {"anatomy_state": rig.snapshot()}, "anatomy_changed")
	if viscera_fx and damage >= 24:
		var driver := rig as Node3D
		if driver != null:
			for index in (10 if ram_crush else 4):
				var droplet := MeshInstance3D.new()
				var mesh := SphereMesh.new()
				mesh.radius = 0.05 + index * 0.012
				mesh.height = mesh.radius * 2.0
				mesh.material = _material(Color("701310"), 0.0, "flesh", index + 3)
				droplet.mesh = mesh
				droplet.position = driver.position + Vector3(randf_range(-0.4, 0.4), 1.0 + randf() * 0.5, randf_range(-0.3, 0.3))
				target.add_child(droplet)
	# Losing the head or the chest kills outright; anything else has to bleed
	# you out, which the anatomy component runs on its own clock.
	if rig.anatomy.dead or rig.zone_health("head") <= 0.0 or rig.zone_health("torso") <= 0.0:
		_crush_driver(target, subject_id, impact_direction, ram_crush)


## The rival survives the derby by design: her Hunt Arc depends on escalating
## encounters, so she is wounded and escapes rather than dying in a heat.
func _crush_driver(target: Node3D, subject_id: String, impact_direction: Vector3, ram_crush: bool) -> void:
	if bool(target.get_meta("is_rival", false)):
		return
	var driver := target.get_node_or_null("DriverRig") as BaselineHuman
	var origin := target.global_position + Vector3(0, 1.1, 0)
	if driver != null:
		driver.anatomy.dead = true
		origin = driver.head_anchor.global_position
		# Collapse the occupant into the crushed cab rather than deleting them.
		for zone_id in ["torso", "head"]:
			var part := driver.parts.get(zone_id) as Node3D
			if part != null and is_instance_valid(part):
				part.scale = Vector3(1.25, 0.28, 1.1)
				part.position.y -= 0.4
	if viscera_fx:
		for index in 26:
			var chunk := MeshInstance3D.new()
			var wet := index % 3 != 0
			if wet:
				var blob := SphereMesh.new()
				blob.radius = 0.05 + randf() * 0.07
				blob.height = blob.radius * 2.0
				blob.material = _material(Color("6b0f0c") if index % 2 == 0 else Color("3d0907"), 0.0, "flesh", index + 11)
				chunk.mesh = blob
			else:
				var shard := BoxMesh.new()
				shard.size = Vector3(0.09, 0.07, 0.12) + Vector3.ONE * randf() * 0.08
				shard.material = _material(Color("7a6048"), 0.0, "bone", index + 5)
				chunk.mesh = shard
			chunk.global_position = origin
			add_child(chunk)
			var spray := Vector3(randf_range(-1.0, 1.0), randf_range(0.25, 1.0), randf_range(-1.0, 1.0)).normalized()
			debris.append({"node": chunk, "velocity": spray * (3.5 + randf() * 6.5) + impact_direction * 4.5, "life": 3.4})
	score += 220 if ram_crush else 140
	crowd_reaction = 2.0
	if derby_audio != null:
		derby_audio.call("play_impact", 1.0, origin, "meat")
	if dynamic_interface.has_method("announce_impact"):
		dynamic_interface.announce_impact(999, false)
	mode_label.visible = true
	mode_label.text = "DRIVER CRUSHED IN THE CAB" if ram_crush else "DRIVER KILLED"
	if kill_cam != null:
		var zone := "torso" if ram_crush else "head"
		kill_cam.trigger(
			"DERBY DRIVER", zone, impact_direction,
			"FRONT END THROUGH THE CAB" if ram_crush else "IMPACT TRAUMA",
		)
	WorldHistory.update_subject(subject_id, {
		"name": "Derby driver", "kind": "person", "status": "dead",
		"memory": "Crushed in the cab of their own wrecker at the Bone Yard.",
	}, "derby_driver_killed")
	if pit_radio != null:
		pit_radio.transmit("death")
	WorldHistory.record_event("derby_driver_crushed", {
		"venue": "rift_derby_quarry", "subject_id": subject_id,
		"target_id": target.name, "ram_crush": ram_crush,
	})


func _spawn_crowd() -> void:
	for index in 64:
		var spectator := Node3D.new()
		spectator.name = "CrowdSilhouette_%02d" % index
		var side := -1.0 if index % 2 == 0 else 1.0
		@warning_ignore("integer_division")
		var row := float((index / 2) % 4)
		spectator.position = Vector3((-30.0 + float(index % 32) * 1.95) * ARENA_SCALE, (2.0 + row * 0.85) * ARENA_SCALE, side * (30.0 + row * 1.2) * ARENA_SCALE)
		spectator.set_meta("rest_y", spectator.position.y)
		spectator.set_meta("phase", float(index) * 0.71)
		add_child(spectator)
		_add_mesh_to(spectator, CapsuleMesh.new(), Vector3.ZERO, Color("150d0d") if index % 3 else Color("263a34"), 0.0, Vector3(0.42, 0.8, 0.42), "Body", "dirt", index + 1)
		crowd_members.append(spectator)


func _update_crowd(delta: float) -> void:
	crowd_reaction = maxf(0.0, crowd_reaction - delta * 0.72)
	for spectator in crowd_members:
		if not is_instance_valid(spectator):
			continue
		var phase := float(spectator.get_meta("phase", 0.0))
		var rest_y := float(spectator.get_meta("rest_y", spectator.position.y))
		spectator.position.y = rest_y + maxf(0.0, sin(Time.get_ticks_msec() * 0.012 + phase)) * crowd_reaction * 0.48
		spectator.rotation.z = sin(Time.get_ticks_msec() * 0.006 + phase) * (0.04 + crowd_reaction * 0.12)


func _add_mesh(mesh: PrimitiveMesh, position_value: Vector3, scale_value: Vector3, color: Color, emission: float, rotation_value := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	instance.rotation = rotation_value
	mesh.material = _material(color, emission)
	add_child(instance)


func _add_mesh_to(parent: Node3D, mesh: PrimitiveMesh, position_value: Vector3, color: Color, emission: float, rotation_value := Vector3.ZERO, node_name := "", kind := "rust", variation_seed := 0) -> void:
	var instance := MeshInstance3D.new()
	if not node_name.is_empty():
		instance.name = node_name
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation = rotation_value
	mesh.material = _material(color, emission, kind, variation_seed)
	parent.add_child(instance)


func _material(color: Color, emission: float, kind: String = "rust", variation_seed: int = 0) -> StandardMaterial3D:
	if emission > 0.0:
		return WorldLook.emissive(color, emission)
	return WorldLook.surface(color, kind, variation_seed)
