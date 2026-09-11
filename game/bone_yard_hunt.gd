extends Node3D

# Ashbloom Expanse vertical slice. World Zero is the development milestone;
# Limbo is the realm; Ashbloom is this first irradiated region.
const PLAYER_SPEED := 7.0
const SPRINT_SPEED := 12.0
const HUNT_ID := "mara_voss"
const FRIEND_ID := "nix_arden"
const HUNT_LOCATION := "ashbloom_bone_yard"
const HANDHELD := preload("res://systems/handheld_device.gd")
const ANATOMY_COMPONENT := preload("res://systems/anatomy_component.gd")
const WORLD_GENERATOR := preload("res://systems/ashbloom_world_generator.gd")
const MISFIRE_DIRECTOR := preload("res://systems/reality_misfire_director.gd")
const SCRAP_SKIFF := preload("res://art/scrap_skiff.glb")
const HUNTER_MOTOR := preload("res://systems/hunter_motor.gd")
const HUNTER_ARSENAL := preload("res://systems/hunter_arsenal.gd")
const HUNTER_BODY_MOTION := preload("res://systems/hunter_body_motion.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")
const LIVING_MAP := preload("res://systems/living_map.gd")

var player := Vector3(0, 1.5, 19)
var yaw := PI
var pitch := -0.12
var third_person := true
var stamina := 100.0
var health := 100
var attack_cooldown := 0.0
var dodge_cooldown := 0.0
var story_step := 0
var panel_mode := ""
var enemy: Node3D
var friend: Node3D
var enemy_health := 100
var enemy_retreating := false
var pulse := 0.0
var generated_world: Node3D
var misfire_director: Node3D
var encounter_actors: Array[Dictionary] = []
var loose_loot: Array[Node3D] = []
var mara_encounter_number := 1
var player_body: CharacterBody3D
var player_rig: BaselineHuman
var player_collider: CollisionShape3D
var player_capsule: CapsuleShape3D
var body_motion: Node
var hunter_appearance: Node
var crouching := false
var strike_windup := -1.0
var rival_attack_clock := 0.0
var dodge_remaining := 0.0
var dodge_direction := Vector3.ZERO
var handheld: Control
var pathfinder = preload("res://systems/ashbloom_pathfinder.gd").new()
var social_markers: Array[Node3D] = []
var resolution_ui: Control
var resolution_target := ""
var living_map: Control
var viscera_fx := true
var enemy_rig: BaselineHuman
var grapple_target := ""
var grapple_advantage := 0.0
var grapple_clock := 0.0
var friend_rig: BaselineHuman
var lock_target := ""
var lock_screen := Vector2(-1, -1)
var camera_position := Vector3.ZERO
var camera_ready := false
var kill_cam: Control
var voice_channel: Node
var arsenal: Node
var pending_attack: Dictionary = {}

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var title: Label = $HUD/Title
@onready var status: Label = $HUD/Status
@onready var vitals: Label = $HUD/VitalsPanel/Vitals
@onready var prompt: Label = $HUD/Prompt
@onready var panel: PanelContainer = $HUD/ArchivePanel
@onready var archive: Label = $HUD/ArchivePanel/Margin/Archive
@onready var field_interface: Control = $HUD/FieldInterface
@onready var character_archive: Control = $HUD/CharacterArchive
@onready var allusions_artwork: Control = $HUD/AllusionsArtwork


func _ready() -> void:
	# The gore setting was only ever applied in the derby, so OFF did nothing
	# once the player walked into the Hunt Grounds and REDUCED leaked across as
	# a static the hunt never reset.
	BaselineHuman.clear_gore()
	viscera_fx = BaselineHuman.apply_gore_setting()
	_build_world()
	handheld = HANDHELD.new()
	handheld.name = "Handheld"
	$HUD.add_child(handheld)
	resolution_ui = preload("res://systems/downed_resolution.gd").new()
	resolution_ui.name = "DownedResolution"
	$HUD.add_child(resolution_ui)
	resolution_ui.selected.connect(_resolve_downed)
	resolution_ui.cancelled.connect(_resolution_cancelled)
	resolution_ui.voice_capture_requested.connect(_voice_capture)
	living_map = LIVING_MAP.new()
	living_map.name = "LivingMap"
	$HUD.add_child(living_map)
	kill_cam = preload("res://systems/kill_cam.gd").new()
	kill_cam.name = "KillCam"
	$HUD.add_child(kill_cam)
	voice_channel = preload("res://systems/proximity_voice.gd").new()
	voice_channel.name = "ProximityVoice"
	add_child(voice_channel)
	voice_channel.capture_finished.connect(_voice_captured)
	voice_channel.capture_failed.connect(func(reason: String): resolution_ui.set_voice_state(reason))
	_build_expanse_systems()
	_register_people()
	player_body = CharacterBody3D.new()
	player_body.name = "HunterController"
	player_collider = CollisionShape3D.new()
	player_capsule = CapsuleShape3D.new()
	player_capsule.radius = 0.36
	player_capsule.height = 1.8
	player_collider.shape = player_capsule
	player_body.add_child(player_collider)
	HUNTER_MOTOR.configure(player_body)
	add_child(player_body)
	player_body.position = player - Vector3.UP * 0.6
	_build_player_rig()
	arsenal = HUNTER_ARSENAL.new()
	arsenal.name = "HunterArsenal"
	player_body.add_child(arsenal)
	arsenal.configure(player_rig)
	body_motion = HUNTER_BODY_MOTION.new()
	body_motion.name = "HunterBodyMotion"
	player_body.add_child(body_motion)
	body_motion.configure(player_rig)
	body_motion.set_perspective(not third_person)
	WorldHistory.register_subject("inventory", {"items": []})
	_spawn_friend()
	_spawn_rival()
	_update_camera()
	WorldHistory.record_event("player_entered_hunt_ground", {"location": HUNT_LOCATION, "hunt_id": HUNT_ID})


## The player had no body at all — only a `health` integer, the same defect the
## derby drivers carried. `health` stays the coarse survivability meter the loop
## and HUD are balanced around; the rig records *where* the damage is, renders it
## on the player's own limbs in first person, and persists it. Unifying the two
## numbers means rebalancing the whole hunt loop and is tracked in ROADMAP.md.
func _build_player_rig() -> void:
	player_rig = BaselineHuman.new()
	player_rig.name = "HunterBody"
	player_body.add_child(player_rig)
	# The capsule is centred on the controller origin, so drop the rig by half
	# its height to stand the feet on the floor rather than mid-shin.
	player_rig.position = Vector3(0, -0.9, 0)
	var config := {
		"flesh": Color("7a6350"), "variation": 1, "blood": 5200.0,
		"cybernetics": {"right_arm": {"name": "salvaged torque arm", "armor": 0.22, "restores": 0.72}},
	}
	var saved: Dictionary = WorldHistory.subject("player")
	if saved.get("anatomy_state") is Dictionary:
		config["restore"] = saved.anatomy_state
	player_rig.gore = viscera_fx
	player_rig.build("player", config)
	hunter_appearance = HUNTER_APPEARANCE.new()
	hunter_appearance.name = "HunterAppearance"
	player_rig.add_child(hunter_appearance)
	hunter_appearance.configure(player_rig)


## Damage to the player, routed through the body so it lands on a real zone,
## bleeds from a real organ, and is still there next time.
func _wound_player(from: Vector3, damage: float, damage_type := "cut") -> void:
	if player_rig == null:
		return
	var toward := (from - player)
	toward.y = 0.0
	var aim := player_rig.global_position + Vector3(0, 1.1, 0) + toward.normalized() * 0.3
	var result := player_rig.hit_at(aim, damage, damage * 0.8, damage_type)
	hunter_appearance.sync_from_anatomy()
	WorldHistory.update_subject("player", {"anatomy_state": player_rig.snapshot()}, "anatomy_changed")
	WorldHistory.record_event("player_wounded", {
		"zone": str(result.get("zone", "torso")),
		"organ": str((result.get("organ", {}) as Dictionary).get("zone", "")),
		"location": HUNT_LOCATION,
	})


func _register_people() -> void:
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound",
		"elo": 1000, "grudge": 0, "status": "awake", "memory": "The derby door opened into Limbo.",
		"wounds": [], "anatomy": {"blood_type": "unresolved", "cybernetics": ["salvaged torque arm"]},
		"relations": {FRIEND_ID: {"kind": "bond", "strength": 12}, HUNT_ID: {"kind": "grudge", "strength": 1}},
	})
	WorldHistory.register_subject(FRIEND_ID, {
		"name": "Nix Arden", "kind": "person", "role": "Scrap medic", "faction": "Gate Lanterns", "faction_id": "gate_lanterns",
		"elo": 930, "bond": 12, "grudge": 0, "status": "waiting", "memory": "Kept a gate open for you.",
		"wounds": ["spore-burned right lung"], "anatomy": {"blood_type": "A-ASH", "cybernetics": ["copper lung bellows", "dose counter"]},
		"relations": {"player": {"kind": "saved", "strength": 22}, "moth_jerrow": {"kind": "ally", "strength": 35}},
	})
	WorldHistory.register_subject("gate_lanterns", {
		"name": "Gate Lanterns", "kind": "faction", "role": "Ascending counter-order", "threat": "LOW", "territory": "Waystations between the tunnels and the surface",
		"doctrine": "Carry a light for whoever comes after. A kept promise outlasts a kept grudge.",
		"relations": {"nix_arden": {"kind": "command", "strength": 40}},
	})
	WorldHistory.register_subject(HUNT_ID, {
		"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers", "elo": 1180,
		"grudge": 0, "injury": "none", "status": "active", "memory": "Watching the derby", "wounds": [],
		"anatomy": {"blood_type": "O-RUST", "cybernetics": ["jaw telemetry nail", "left clavicle rail"]},
		"relations": {"player": {"kind": "hunts", "strength": 8}, "ashline_wreckers": {"kind": "command", "strength": 72}, "rook_sable": {"kind": "grudge", "strength": 31}},
	})
	WorldHistory.register_subject("ashline_wreckers", {
		"name": "Ashline Wreckers", "kind": "faction", "role": "Road murder syndicate", "threat": "SEVERE", "territory": "Bone Yard / Burnt Highway",
		"doctrine": "Every machine is a coffin awaiting an owner. Rank is won by remembered impact.",
		"relations": {"mara_voss": {"kind": "command", "strength": 72}, "rook_sable": {"kind": "enemy", "strength": 46}},
	})
	WorldHistory.register_subject("rook_sable", {
		"name": "Rook Sable", "kind": "person", "role": "Rail-gang adjudicator", "faction": "Black Mile", "faction_id": "black_mile", "elo": 1325,
		"grudge": 18, "status": "unlocated", "memory": "Paid three drivers to lose the same race.", "wounds": ["missing left eye"],
		"anatomy": {"blood_type": "B-9", "cybernetics": ["rangefinder eye", "ceramic sternum"]},
		"relations": {"mara_voss": {"kind": "grudge", "strength": 31}, "iris_coil": {"kind": "command", "strength": 61}},
	})
	WorldHistory.register_subject("iris_coil", {
		"name": "Iris Coil", "kind": "person", "role": "Sporeline scout", "faction": "Black Mile", "faction_id": "black_mile", "elo": 1096,
		"grudge": 0, "status": "roaming", "memory": "Photographed the fungus moving against the wind.", "wounds": ["glass scars"],
		"anatomy": {"blood_type": "AB-", "cybernetics": ["optic spool", "ankle compass"]},
		"relations": {"rook_sable": {"kind": "bond", "strength": 17}, "vale_nine": {"kind": "enemy", "strength": 44}},
	})
	WorldHistory.register_subject("moth_jerrow", {
		"name": "Moth Jerrow", "kind": "person", "role": "Fungus shepherd", "faction": "Soft Rot Communion", "faction_id": "soft_rot", "elo": 1004,
		"grudge": 0, "status": "cultivating", "memory": "Claims the great caps remember rain from before the flash.", "wounds": ["mycelial graft"],
		"anatomy": {"blood_type": "SAP", "cybernetics": ["filter trachea"]},
		"relations": {"nix_arden": {"kind": "ally", "strength": 35}, "vale_nine": {"kind": "bond", "strength": 13}},
	})
	WorldHistory.register_subject("vale_nine", {
		"name": "Vale Nine", "kind": "person", "role": "Storm stalker", "faction": "None", "elo": 1244, "grudge": 7,
		"status": "following", "memory": "Leaves clean footprints through radioactive mud.", "wounds": ["thoracic puncture", "burned fingertips"],
		"anatomy": {"blood_type": "UNKNOWN", "cybernetics": ["quiet-heart regulator", "heel anchors"]},
		"relations": {"moth_jerrow": {"kind": "bond", "strength": 13}, "choir_of_marrow": {"kind": "enemy", "strength": 58}},
	})
	WorldHistory.register_subject("choir_of_marrow", {
		"name": "Choir of Marrow", "kind": "faction", "role": "Anatomical faith", "threat": "UNKNOWN", "territory": "Subsurface ossuary",
		"doctrine": "Metal forgets. Bone records. Their surgeons replace healthy parts to rewrite allegiance.",
		"relations": {"vale_nine": {"kind": "enemy", "strength": 58}, "doctor_vanta": {"kind": "command", "strength": 83}},
	})
	WorldHistory.register_subject("doctor_vanta", {
		"name": "Doctor Vanta", "kind": "person", "role": "Relic anatomist", "faction": "Choir of Marrow", "faction_id": "choir_of_marrow", "elo": 1460,
		"grudge": 0, "status": "rumoured", "memory": "A voice below the quarry is pricing Mara's replacement arm.", "wounds": [],
		"anatomy": {"blood_type": "NULL", "cybernetics": ["six-finger surgical crown", "blackbox liver", "remote pulse cage"]},
		"relations": {"choir_of_marrow": {"kind": "command", "strength": 83}, "mara_voss": {"kind": "known", "strength": 26}},
	})


func _unhandled_input(event: InputEvent) -> void:
	if resolution_ui.visible or kill_cam.active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		_toggle_lock()
	if event is InputEventMouseButton and event.pressed and not lock_target.is_empty():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_lock(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_lock(-1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_attack(true)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _equip_weapon(0)
			KEY_2: _equip_weapon(1)
			KEY_3: _equip_weapon(2)
			KEY_R: _reload_weapon()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				if not panel_mode.is_empty():
					_toggle_panel(panel_mode)
			KEY_F:
				third_person = not third_person
				body_motion.set_perspective(not third_person)
				_update_camera()
			KEY_G: handheld.toggle_device()
			KEY_TAB:
				# The handheld owns Tab while raised: one object, modes on it.
				if handheld.is_open:
					handheld.cycle_mode(1)
				else:
					_toggle_panel("index")
			KEY_M: _toggle_panel("map")
			KEY_T: _toggle_panel("tree")
			KEY_J: _toggle_artwork()
			KEY_C: _start_grapple()
			KEY_Z: _toggle_lock()
			KEY_E: _interact()
			KEY_SPACE:
				if not grapple_target.is_empty():
					_break_grapple("YOU LET GO")
				else:
					_dodge()
			KEY_Q: _use_prosthetic_surge()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clamp(pitch - event.relative.y * 0.0024, -0.75, 0.42)


func _physics_process(delta: float) -> void:
	if kill_cam.active:
		return
	# The resolution window does not stop the world. Standing over someone
	# deciding what to do with them is supposed to be a risk, so everyone else
	# keeps moving and the body under the form keeps bleeding — only the
	# player's own combat input is suspended, in `_update_player` and `_attack`.
	if resolution_ui.visible:
		_update_resolution_window()
	if not panel_mode.is_empty():
		_update_hud()
		return
	pulse += delta
	dodge_remaining = maxf(0.0, dodge_remaining - delta)
	if strike_windup >= 0.0:
		strike_windup -= delta
		if strike_windup < 0.0:
			_resolve_strike()
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	arsenal.tick(delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	_update_player(delta)
	_update_rival(delta)
	_update_encounter_actors(delta)
	if misfire_director != null:
		misfire_director.call("update_player_position", player)
	if not grapple_target.is_empty():
		_update_grapple(delta)
	_steer_lock(delta)
	_update_camera()
	_update_hud()
	# Charted by walking, not by opening the map.
	living_map.observe(player, yaw)


func _update_player(delta: float) -> void:
	if player_rig.is_downed() or player_rig.anatomy.dead:
		return
	# Standing over a downed body with the form open costs you your footwork,
	# and so does having hold of someone.
	if resolution_ui.visible or not grapple_target.is_empty():
		player_body.velocity = Vector3.ZERO
		return
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = HUNTER_MOTOR.wish_direction(move, yaw)
	crouching = Input.is_action_pressed("crouch") and dodge_remaining <= 0.0
	var sprinting := Input.is_action_pressed("sprint") and not crouching and stamina > 1.0 and move.length() > 0.0
	var speed := 3.4 if crouching else (SPRINT_SPEED if sprinting else PLAYER_SPEED)
	player_capsule.height = move_toward(player_capsule.height, 1.2 if crouching else 1.8, delta * 4.0)
	player_collider.position.y = (player_capsule.height - 1.8) * 0.5
	HUNTER_MOTOR.move_body(player_body, direction, speed, delta, dodge_direction if dodge_remaining > 0.0 else Vector3.ZERO, 16.0)
	if player_body.position.y < -10.0:
		player_body.position = Vector3(0, 1.0, 19)
	player = player_body.position + Vector3.UP * 0.6
	stamina = clampf(stamina + (-26.0 if sprinting else 18.0) * delta, 0, 100)
	body_motion.update(delta, player_body.velocity, player_body.is_on_floor(), sprinting, crouching, dodge_remaining > 0.0)
	hunter_appearance.set_mouth(player_rig.anatomy.pain / 180.0, sin(pulse * 0.7) * player_rig.anatomy.pain / 100.0)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_attack()


func _attack(heavy := false) -> void:
	if resolution_ui.visible or kill_cam.active or player_rig.is_downed() or player_rig.anatomy.dead:
		return
	# In a clinch the strike button is the press, not a swing.
	if not grapple_target.is_empty():
		return
	if not panel_mode.is_empty():
		return
	var report: Dictionary = arsenal.begin_attack(heavy)
	if not bool(report.get("accepted", false)):
		if str(report.get("reason", "")) == "empty":
			prompt.text = "DRY / [R] RELOAD"
		return
	var cost := float(report.get("stamina", 0.0))
	if stamina < cost:
		# Refund a firearm round if a future ranged weapon gains a stamina cost.
		if str(report.kind) == "firearm":
			var rounds: Dictionary = arsenal.ammo[arsenal.current_id]
			rounds.loaded = int(rounds.loaded) + 1
			arsenal.ammo[arsenal.current_id] = rounds
		return
	stamina -= cost
	attack_cooldown = arsenal.cooldown
	pending_attack = report
	body_motion.trigger_attack(maxf(float(report.get("windup", 0.0)), arsenal.cooldown * 0.62), str(report.kind))
	if str(report.kind) == "firearm":
		body_motion.trigger_recoil(float(report.impulse))
		_resolve_firearm(report)
		pending_attack = {}
	else:
		strike_windup = float(report.windup)


func _resolve_strike() -> void:
	var report := pending_attack
	if report.is_empty():
		report = {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"}
	pending_attack = {}
	if _attack_nearest_encounter_actor(report):
		return
	if enemy == null or not enemy.visible or enemy_retreating:
		return
	var distance := player.distance_to(enemy.global_position)
	if distance > 4.1:
		return
	var facing := Vector3(sin(yaw), 0, cos(yaw)).normalized().dot((enemy.global_position - player).normalized())
	if facing < 0.18:
		return
	var damage := 22 if story_step > 0 else 15
	# Mara's wounds used to be picked from her remaining health — "left arm"
	# below 55, "leg" below 28 — so where the player aimed never mattered and
	# nothing landed on her body. She has a rig now, so the blow resolves
	# against it exactly the way it does for everyone else in the region.
	var body_zone := "torso"
	if enemy_rig != null and is_instance_valid(enemy_rig):
		var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
		var along := player + look * clampf((enemy.global_position - player).dot(look), 0.6, 4.1)
		var lateral := along - enemy.global_position
		lateral.y = 0.0
		if lateral.length() > 0.45:
			lateral = lateral.normalized() * 0.45
		var aim := enemy.global_position + Vector3(lateral.x, look.y * 4.1 * 1.2, lateral.z)
		var wound := enemy_rig.hit_at(aim, float(damage), float(damage) * 0.8, "cut")
		body_zone = str(wound.get("zone", "torso"))
		WorldHistory.update_subject(HUNT_ID, {"anatomy_state": enemy_rig.snapshot()}, "anatomy_changed")
	enemy_health = maxi(0, enemy_health - damage)
	_spawn_blood(enemy.global_position + Vector3(0, 1.2, 0), damage)
	WorldHistory.record_event("melee_body_hit", {"target": HUNT_ID, "body_zone": body_zone, "damage": damage, "location": HUNT_LOCATION})
	var wounds: Array = WorldHistory.subject(HUNT_ID).get("wounds", []).duplicate()
	var wound := "cut %s" % body_zone
	if not wounds.has(wound):
		wounds.append(wound)
	WorldHistory.update_subject(HUNT_ID, {"injury": wound, "wounds": wounds, "grudge": mini(100, int(WorldHistory.subject(HUNT_ID).get("grudge", 0)) + 14), "status": "fighting"}, "rival_injured")
	if enemy_health <= 0:
		_rival_retreats("You left Mara alive. She will return altered.")


func _attack_nearest_encounter_actor(attack: Dictionary = {}) -> bool:
	if attack.is_empty():
		attack = {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"}
	var nearest_index := -1
	var nearest_distance := 99999.0
	for index in encounter_actors.size():
		var actor: Dictionary = encounter_actors[index]
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		if actor.anatomy.downed or str(actor.get("disposition", "hostile")) != "hostile":
			continue
		var distance := player.distance_to(node.global_position)
		# A locked target wins regardless of who has wandered closer, which is
		# the entire reason to have a lock.
		if not lock_target.is_empty() and str(actor.subject_id) == lock_target:
			nearest_distance = distance
			nearest_index = index
			break
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	var reach := float(attack.get("range", 4.1))
	if nearest_index < 0 or nearest_distance > reach:
		return false
	var actor: Dictionary = encounter_actors[nearest_index]
	var target: Node3D = actor.node as Node3D
	var facing := Vector3(sin(yaw), 0, cos(yaw)).normalized().dot((target.global_position - player).normalized())
	if facing < 0.12:
		return false
	var anatomy: Node = actor.anatomy as Node
	var rig := actor.get("rig") as BaselineHuman
	var zone := "torso"
	var result: Dictionary = {}
	if rig != null and is_instance_valid(rig):
		# Where you are looking decides what you open. The zone used to come from
		# (event_count + index) % 6 — a round-robin, so aiming at a head and
		# aiming at a knee produced the same sequence of wounds.
		var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
		# A melee swing connects with the body in front of you; what the aim
		# chooses is *where on that body*. Resolving a free world-space point
		# instead made the zone depend on how far off-axis or how much higher
		# the target happened to be standing, so a level swing at someone on a
		# kerb opened an arm when the player was looking at a head.
		var along := player + look * clampf((target.global_position - player).dot(look), 0.6, reach)
		var lateral := along - target.global_position
		lateral.y = 0.0
		if lateral.length() > 0.45:
			lateral = lateral.normalized() * 0.45
		var aim := target.global_position + Vector3(lateral.x, look.y * reach * 1.2, lateral.z)
		result = rig.hit_at(aim, float(attack.damage), float(attack.impulse), str(attack.damage_type))
		zone = str(result.get("zone", "torso"))
	else:
		result = anatomy.call("apply_hit", zone, float(attack.damage), float(attack.impulse), str(attack.damage_type))
	var organ_hit := str((result.get("organ", {}) as Dictionary).get("zone", ""))
	if not organ_hit.is_empty() and bool((result.get("organ", {}) as Dictionary).get("ruptured", false)):
		prompt.text = "%s IS OPENED UP" % str(actor.display_name).to_upper()
	WorldHistory.update_subject(str(actor.subject_id), {"anatomy_state": anatomy.call("snapshot")}, "anatomy_changed")
	_spawn_blood(target.global_position + Vector3(0, 1.1, 0), roundi(float(attack.damage)))
	WorldHistory.record_event("npc_anatomy_hit", {"subject_id": actor.subject_id, "weapon": attack.weapon, "zone": zone, "result": result, "location": HUNT_LOCATION})
	if bool(result.get("disabled", false)) and zone in ["left_arm", "right_arm", "left_leg", "right_leg"]:
		_spawn_severed_part(target.global_position + Vector3(0, 1.0, 0), zone)
	if anatomy.critical or anatomy.pain >= 68.0:
		actor.state = "fleeing"
		actor.loot_at_risk = true
		prompt.text = "%s IS BLEEDING OUT AND ESCAPING — CHASE FOR THEIR LOOT OR LET THEM GO." % str(actor.display_name).to_upper()
	if anatomy.dead:
		_kill_encounter_actor(nearest_index, "combat_trauma")
	return true


func _resolve_firearm(attack: Dictionary) -> void:
	var forward := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var origin := camera.global_position + forward * 0.48
	var impacts: Dictionary = {}
	for direction in arsenal.shot_directions(forward, Vector3.UP):
		var hit := _trace_actor(origin, direction, float(attack.range))
		if hit.is_empty():
			continue
		var actor: Dictionary = hit.actor
		var rig := actor.rig as BaselineHuman
		var result := rig.hit_at(hit.position, float(attack.damage), float(attack.impulse), str(attack.damage_type))
		var id := str(actor.subject_id)
		if not impacts.has(id):
			impacts[id] = {"actor": actor, "zones": [], "damage": 0.0, "ruptures": []}
		var summary: Dictionary = impacts[id]
		summary.zones.append(str(result.get("zone", "torso")))
		summary.damage = float(summary.damage) + float(result.get("damage", 0.0))
		var organ := result.get("organ", {}) as Dictionary
		if bool(organ.get("ruptured", false)):
			summary.ruptures.append(str(organ.get("zone", "internal")))
		impacts[id] = summary
		(actor.node as CharacterBody3D).velocity += direction * minf(6.0, float(attack.impulse) * 0.075)
	for id in impacts:
		var summary: Dictionary = impacts[id]
		var actor: Dictionary = summary.actor
		WorldHistory.update_subject(id, {"anatomy_state": actor.rig.snapshot()}, "anatomy_changed")
		WorldHistory.record_event("firearm_anatomy_hit", {
			"subject_id": id, "weapon": attack.weapon, "zones": summary.zones,
			"damage": snappedf(float(summary.damage), 0.1), "ruptures": summary.ruptures,
			"location": HUNT_LOCATION,
		})
		if actor.anatomy.dead:
			_kill_encounter_actor(encounter_actors.find(actor), str(attack.weapon))
		elif actor.anatomy.downed:
			actor.state = "downed"
		elif actor.anatomy.critical or actor.anatomy.pain >= 68.0:
			actor.state = "fleeing"
			actor.loot_at_risk = true
	if impacts.is_empty():
		prompt.text = "%s / MISS" % str(arsenal.current().label)
	else:
		prompt.text = "%s / %d BODY%s HIT" % [str(arsenal.current().label), impacts.size(), "IES" if impacts.size() != 1 else ""]
	WorldHistory.record_event("weapon_fired", {"weapon": attack.weapon, "hits": impacts.keys(), "location": HUNT_LOCATION})


func _trace_actor(origin: Vector3, direction: Vector3, distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance)
	query.exclude = _player_collision_exclusions()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider := hit.collider as Node
	for actor in encounter_actors:
		if not is_instance_valid(actor.node) or actor.anatomy.dead:
			continue
		var cursor := collider
		while cursor != null:
			if cursor == actor.node:
				return {"actor": actor, "position": hit.position, "normal": hit.normal}
			cursor = cursor.get_parent()
	return {}


func _player_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [player_body.get_rid()]
	for zone_id in BaselineHuman.ZONES:
		var hitbox := player_rig.get_node_or_null("%s_hitbox" % zone_id) as CollisionObject3D
		if hitbox != null:
			exclusions.append(hitbox.get_rid())
	return exclusions


func _equip_weapon(slot: int) -> void:
	if arsenal.select_slot(slot):
		pending_attack = {}
		strike_windup = -1.0
		prompt.text = "%s / READY" % str(arsenal.current().label)


func _reload_weapon() -> void:
	if arsenal.reload():
		body_motion.trigger_reload(float(arsenal.current().reload))
		prompt.text = "%s / RELOADING" % str(arsenal.current().label)


func _dodge() -> void:
	if not panel_mode.is_empty() or dodge_cooldown > 0.0 or stamina < 25.0:
		return
	dodge_cooldown = 0.75
	stamina -= 25.0
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	dodge_direction = HUNTER_MOTOR.dodge_direction(move, yaw)
	dodge_remaining = 0.28
	WorldHistory.record_event("player_dodged", {"location": HUNT_LOCATION})


func _use_prosthetic_surge() -> void:
	if stamina < 35.0:
		return
	stamina -= 35.0
	WorldHistory.record_event("prosthetic_surge_used", {"implant": "salvaged torque arm", "location": HUNT_LOCATION})
	if enemy != null and not enemy_retreating and player.distance_to(enemy.global_position) < 7.0:
		enemy_health = maxi(0, enemy_health - 30)
		_spawn_blood(enemy.global_position + Vector3(0, 1.0, 0), 30)
		if enemy_health <= 0:
			_rival_retreats("Mara's arm breaks. Her crew drag her into the tunnel.")


func _interact() -> void:
	if not panel_mode.is_empty():
		return
	body_motion.trigger_interaction()
	var downed := _nearest_downed()
	if not downed.is_empty():
		_open_resolution(downed)
		return
	for marker in social_markers.duplicate():
		if is_instance_valid(marker) and player.distance_to(marker.global_position) < 4.0:
			var kind := str(marker.get_meta("kind"))
			var inventory: Array = WorldHistory.subject("inventory").get("items", []).duplicate()
			if kind == "trade":
				if not inventory.has("rust scrip"):
					prompt.text = "SOFT ROT BROKER: ONE RUST SCRIP FOR A FIELD DRESSING."
					return
				inventory.erase("rust scrip")
				inventory.append("field dressing")
				prompt.text = "TRADE COMPLETE // FIELD DRESSING ACQUIRED"
			elif kind in ["friendly", "bond"]:
				health = mini(100, health + 25)
				var bond := int(WorldHistory.subject(FRIEND_ID).get("bond", 0))
				WorldHistory.update_subject(FRIEND_ID, {"bond": bond + 5}, "misfire_bond")
				prompt.text = "A SMALL KINDNESS // BODY RESTORED; NIX HEARS OF IT."
			else:
				inventory.append("impossible testimony")
				prompt.text = "TESTIMONY RECORDED // YOUR WORLD INDEX REMEMBERS."
			WorldHistory.update_subject("inventory", {"items": inventory}, "misfire_reward")
			misfire_director.resolve(str(marker.get_meta("instance_id")), "interacted")
			social_markers.erase(marker)
			marker.queue_free()
			return
	for cache in loose_loot.duplicate():
		if is_instance_valid(cache) and player.distance_to(cache.global_position) < 3.5:
			var items: Array = WorldHistory.subject("inventory").get("items", []).duplicate()
			items.append_array(cache.get_meta("items", []))
			WorldHistory.update_subject("inventory", {"items": items}, "loot_collected")
			loose_loot.erase(cache)
			cache.queue_free()
			prompt.text = "SALVAGE SECURED // %d ITEMS" % items.size()
			return
	if friend != null and player.distance_to(friend.global_position) < 4.0:
		var bond := int(WorldHistory.subject(FRIEND_ID).get("bond", 12)) + 10
		WorldHistory.update_subject(FRIEND_ID, {"bond": bond, "status": "ally", "memory": "You listened at the Bone Yard gate."}, "bond_strengthened")
		prompt.text = "NIX: Mara is not the quarry. Something below is paying for her repairs."
		story_step = maxi(story_step, 1)
		return
	if player.distance_to(Vector3(0, 0, -24)) < 7.0 and story_step >= 1:
		_begin_canonical_encounter()
		return
	prompt.text = "Nothing answers. Find Nix or follow the floodlights to the tunnel."


func _begin_canonical_encounter() -> void:
	if story_step >= 2:
		return
	story_step = 2
	enemy_retreating = false
	enemy.visible = true
	enemy.global_position = Vector3(0, 1.2, -16)
	var mara := WorldHistory.subject(HUNT_ID)
	mara_encounter_number = 2 if not str(mara.get("next_adaptation", "")).is_empty() else 1
	enemy_health = 150 if mara_encounter_number == 2 else 100
	WorldHistory.update_subject(HUNT_ID, {"status": "hunting", "encounter_number": mara_encounter_number, "memory": "Mara returned rebuilt to settle the Bone Yard debt." if mara_encounter_number == 2 else "Mara came to settle the Bone Yard debt."}, "hunt_arc_started")
	WorldHistory.record_event("canonical_hunt_encounter_started", {"hunter": "player", "target": HUNT_ID, "location": HUNT_LOCATION, "encounter_number": mara_encounter_number})
	if mara_encounter_number == 2:
		_spawn_ashline_reinforcements()
		prompt.text = "SECOND HUNT // MARA VOSS: INDUSTRIAL ARM, REBUILT WRECKER, TWO ASHLINE KNIVES."
	else:
		prompt.text = "HUNT ARC: MARA VOSS has found you. Do not kill the story; make her remember."


func _update_rival(delta: float) -> void:
	if enemy == null or enemy_retreating or story_step < 2:
		return
	var to_player := player - enemy.global_position
	to_player.y = 0
	var distance := to_player.length()
	if distance > 3.2:
		enemy.global_position += to_player.normalized() * delta * 4.3
		enemy.look_at(player, Vector3.UP)
	else:
		rival_attack_clock += delta
		if rival_attack_clock < 1.25:
			if rival_attack_clock > 0.8:
				prompt.text = "MARA DRAWS BACK — DODGE"
			return
		rival_attack_clock = 0.0
		if dodge_remaining > 0.0:
			return
		health = maxi(0, health - 7)
		stamina = maxf(0, stamina - 12)
		_wound_player(enemy.global_position, 17.0, "cut")
		WorldHistory.record_event("rival_struck_player", {"rival": HUNT_ID, "location": HUNT_LOCATION})
		if health <= 0:
			health = 65
			player = Vector3(0, 1.5, 19)
			player_body.position = player - Vector3.UP * 0.6
			WorldHistory.record_event("player_recovered_by_nix", {"location": HUNT_LOCATION})
	if enemy_health <= 25:
		_rival_retreats("Mara escapes through the tunnel. Her next body will not be the same.")


func _update_encounter_actors(delta: float) -> void:
	for index in range(encounter_actors.size() - 1, -1, -1):
		var actor: Dictionary = encounter_actors[index]
		var node := actor.get("node") as Node3D
		var anatomy: Node = actor.get("anatomy") as Node
		if node == null or not is_instance_valid(node) or anatomy == null:
			encounter_actors.remove_at(index)
			continue
		if anatomy.dead and not bool(actor.get("dead", false)):
			_kill_encounter_actor(index, "bleed_out")
			continue
		if anatomy.downed:
			(node as CharacterBody3D).velocity = Vector3.ZERO
			actor.attack_time = 0.0
			if str(actor.get("state", "")) != "downed":
				actor.state = "downed"
				WorldHistory.update_subject(str(actor.subject_id), {"status": "downed", "anatomy_state": actor.rig.snapshot()}, "npc_downed")
			if player.distance_to(node.global_position) <= 4.0:
				prompt.text = "[E] %s / DOWNED, ALIVE — DECIDE THEIR FATE" % str(actor.display_name).to_upper()
			continue
		if str(actor.get("disposition", "hostile")) != "hostile":
			actor.attack_time = 0.0
			continue
		var offset := player - node.global_position
		offset.y = 0
		var distance := offset.length()
		if str(actor.get("state", "idle")) == "fleeing":
			var away := -offset.normalized() if distance > 0.1 else Vector3.FORWARD
			_move_actor_on_route(actor, node.global_position + away * 40.0, delta)
			if distance > 72.0:
				misfire_director.resolve(str(actor.get("encounter_id", "")), "escaped")
				WorldHistory.update_subject(str(actor.subject_id), {"status": "escaped", "memory": "Escaped the Hunter while bleeding.", "anatomy_state": anatomy.call("snapshot")}, "npc_escaped_bleeding")
				node.queue_free()
				encounter_actors.remove_at(index)
		elif str(actor.get("disposition", "hostile")) == "hostile" and distance < 24.0 and distance > 3.0:
			_move_actor_on_route(actor, player, delta)
		elif distance <= 3.0:
			actor["attack_time"] = float(actor.get("attack_time", 0.0)) + delta
			if float(actor.attack_time) > 0.8:
				prompt.text = "%s RAISES THEIR WEAPON" % str(actor.display_name).to_upper()
			if float(actor.attack_time) >= 1.4:
				actor.attack_time = 0.0
				if dodge_remaining <= 0.0:
					health = maxi(1, health - 9)
					_wound_player(node.global_position, 15.0, "cut")

func _move_actor_on_route(actor: Dictionary, destination: Vector3, delta: float) -> void:
	var body := actor.node as CharacterBody3D
	actor["route_time"] = float(actor.get("route_time", 0.0)) - delta
	if float(actor.route_time) <= 0.0:
		actor.route_time = 0.8
		actor["route"] = pathfinder.route(body.position, destination)
		actor["waypoint"] = 1
	var points: PackedVector2Array = actor.get("route", PackedVector2Array())
	var waypoint := int(actor.get("waypoint", 1))
	if waypoint >= points.size():
		return
	var target := Vector3(points[waypoint].x, body.position.y, points[waypoint].y)
	if body.position.distance_to(target) < 0.8:
		actor.waypoint = waypoint + 1
	var direction := (target - body.position).normalized()
	var mobility := float(actor.anatomy.call("mobility_ratio"))
	body.velocity = direction * float(actor.speed) * mobility
	body.velocity.y = -2.0
	body.move_and_slide()
	if direction.length_squared() > 0.01:
		body.look_at(body.position + direction, Vector3.UP)


func _kill_encounter_actor(index: int, cause: String) -> void:
	if index < 0 or index >= encounter_actors.size():
		return
	var actor: Dictionary = encounter_actors[index]
	actor.dead = true
	misfire_director.resolve(str(actor.get("encounter_id", "")), "defeated")
	var node := actor.node as Node3D
	var anatomy: Node = actor.anatomy as Node
	WorldHistory.update_subject(str(actor.subject_id), {"status": "dead", "memory": "The Hunter caught them before escape.", "anatomy_state": anatomy.call("snapshot")}, "npc_killed")
	WorldHistory.record_event("loot_dropped", {"subject_id": actor.subject_id, "items": actor.loot, "cause": cause})
	_spawn_loot_cache(node.global_position, actor.loot)
	var label := node.get_node_or_null("Identity") as Label3D
	if label != null:
		label.text = "%s // DEAD\nLOOT DROPPED" % str(actor.display_name).to_upper()
	encounter_actors.remove_at(index)

func _actor_by_id(id: String) -> Dictionary:
	for actor in encounter_actors:
		if str(actor.subject_id) == id and is_instance_valid(actor.node):
			return actor
	return {}

func _nearest_downed() -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 4.0
	for actor in encounter_actors:
		if is_instance_valid(actor.node) and actor.rig.is_downed():
			var candidate: float = player.distance_to(actor.node.global_position)
			if candidate <= distance:
				distance = candidate
				nearest = actor
	return nearest

func _accepts_recruitment(subject: Dictionary) -> bool:
	return int(subject.get("bond", 0)) >= 20 or bool(subject.get("recruitment_consent", false)) or float(subject.get("debt_to_player", 0)) > 0


func _recruitment_reason(subject: Dictionary) -> String:
	if int(subject.get("grudge", 0)) >= 40:
		return "They hate you too much to take the offer."
	return "No bond, no debt, no reason to follow you."


## Which zone the finishing blow goes into, and the organ inside it. Executing
## someone reads as finishing the wound that dropped them rather than as a
## generic heart shot, so the kill cam plate differs per victim.
func _execution_target(actor: Dictionary) -> Array:
	var worst := "torso"
	var lowest := 2.0
	for zone_id in AnatomyComponent.DEFAULT_ZONES:
		var ceiling := float((AnatomyComponent.DEFAULT_ZONES[zone_id] as Dictionary).health)
		var ratio: float = float(actor.rig.zone_health(zone_id)) / ceiling
		if ratio < lowest:
			lowest = ratio
			worst = zone_id
	if worst == "head":
		return ["head", "brain"]
	if worst in ["torso", "left_arm", "right_arm"]:
		return ["torso", "heart"]
	# A ruined leg is not where you finish someone; the spine is the nearest
	# structure that ends it from behind a kneeling body.
	return ["torso", "spine"]


func _open_resolution(actor: Dictionary) -> void:
	resolution_target = str(actor.subject_id)
	strike_windup = -1.0
	dodge_remaining = 0.0
	player_body.velocity = Vector3.ZERO
	if handheld.is_open:
		handheld.close_device()
	var identity := actor.node.get_node_or_null("Identity") as Label3D
	if identity != null:
		identity.visible = false
	var subject := WorldHistory.subject(resolution_target)
	resolution_ui.open_for(str(actor.display_name), actor.rig.snapshot(), {
		"subject_id": resolution_target,
		"role": str(subject.get("role", actor.get("disposition", "unfiled"))),
		"recruit": _accepts_recruitment(subject),
		"recruit_reason": _recruitment_reason(subject),
	})
	_update_resolution_window()


func _resolution_cancelled() -> void:
	var actor := _actor_by_id(resolution_target)
	if not actor.is_empty():
		var identity := actor.node.get_node_or_null("Identity") as Label3D
		if identity != null:
			identity.visible = true
	voice_channel.cancel()
	resolution_target = ""


## Keeps the open form honest while the world runs underneath it: the readout
## follows the real body, and the window closes itself if the subject dies of
## their wounds or the player walks away mid-decision.
func _update_resolution_window() -> void:
	var target := _actor_by_id(resolution_target)
	if target.is_empty() or not target.rig.is_downed():
		resolution_ui.cancel_menu()
		prompt.text = "THEY WERE DECIDED FOR YOU."
		return
	if player.distance_to(target.node.global_position) > 5.5:
		resolution_ui.cancel_menu()
		prompt.text = "OUT OF REACH / DECISION ABANDONED"
		return
	resolution_ui.anatomy = target.rig.snapshot()
	resolution_ui.set_voice_state(voice_channel.status, voice_channel.level)
	var head: Node3D = target.rig.head_anchor
	var at: Vector3 = head.global_position if head != null and is_instance_valid(head) else target.node.global_position + Vector3.UP
	if camera.is_position_behind(at):
		resolution_ui.set_world_anchor(Vector2(-1, -1))
	else:
		resolution_ui.set_world_anchor(camera.unproject_position(at))


func _resolve_downed(outcome: String) -> void:
	voice_channel.cancel()
	var actor := _actor_by_id(resolution_target)
	resolution_target = ""
	if actor.is_empty() or not actor.rig.is_downed() or player.distance_to(actor.node.global_position) > 5.5:
		return
	var identity := actor.node.get_node_or_null("Identity") as Label3D
	if identity != null:
		identity.visible = true
	var id := str(actor.subject_id)
	var subject := WorldHistory.subject(id)
	if outcome == "recruit" and not _accepts_recruitment(subject):
		return
	if outcome not in ["execute", "spare", "recruit"]:
		return
	if outcome == "execute":
		var finish := _execution_target(actor)
		actor.rig.hit(str(finish[0]), 100.0, 30.0, "puncture", str(finish[1]))
		actor.rig.execute()
		var snapshot: Dictionary = actor.rig.snapshot()
		WorldHistory.record_event("npc_resolution", {"subject_id": id, "outcome": outcome, "actor": "player", "zone": finish[0], "organ": finish[1], "anatomy_state": snapshot})
		kill_cam.trigger(str(actor.display_name), str(finish[0]), actor.node.global_position - player, "EXECUTION / %s" % str(finish[1]).to_upper().replace("_", " "), snapshot)
		_kill_encounter_actor(encounter_actors.find(actor), "execution")
	else:
		actor.rig.spare()
		actor.state = "recruited" if outcome == "recruit" else "spared"
		actor.disposition = "ally" if outcome == "recruit" else "neutral"
		actor.attack_time = 0.0
		var relations: Dictionary = subject.get("relations", {}).duplicate(true)
		if outcome == "recruit":
			relations["player"] = {"kind": "bond", "strength": maxi(20, int(subject.get("bond", 0))), "consensual": true}
		WorldHistory.update_subject(id, {"status": actor.state, "disposition": actor.disposition, "relations": relations, "grudge": int(subject.get("grudge", 0)) + (5 if outcome == "spare" else 0), "memory": "The Hunter offered shelter; I agreed to join." if outcome == "recruit" else "The Hunter spared me. I remember the wounds.", "anatomy_state": actor.rig.snapshot()}, "npc_recruited" if outcome == "recruit" else "npc_spared")
		WorldHistory.record_event("npc_resolution", {"subject_id": id, "outcome": outcome, "actor": "player", "witnesses": [id]})
		misfire_director.resolve(str(actor.get("encounter_id", "")), actor.state)
		var label := actor.node.get_node_or_null("Identity") as Label3D
		if label != null:
			label.text = "%s / %s" % [str(actor.display_name).to_upper(), str(actor.state).to_upper()]
	prompt.text = "DISPOSITION RECORDED / " + outcome.to_upper()
	attack_cooldown = 0.72


func _voice_capture(holding: bool) -> void:
	var actor := _actor_by_id(resolution_target)
	if actor.is_empty() or player.distance_to(actor.node.global_position) > 5.5:
		resolution_ui.set_voice_state("NO SUBJECT IN VOICE RANGE")
		return
	if holding:
		voice_channel.begin(str(actor.subject_id), actor.rig.head_anchor)
	else:
		voice_channel.finish()


func _voice_captured(subject_id: String, result: Dictionary) -> void:
	var actor := _actor_by_id(subject_id)
	if actor.is_empty() or not bool(result.get("sent", false)):
		resolution_ui.set_voice_state(voice_channel.status)
		return
	var subject := WorldHistory.subject(subject_id)
	var reply := "You have my attention. Make the offer." if _accepts_recruitment(subject) else "I heard you. It changes nothing yet."
	if int(subject.get("grudge", 0)) >= 40:
		reply = "I know your voice. I still hate you."
	WorldHistory.record_event("proximity_voice_addressed", {"speaker": "player", "listener": subject_id, "duration": result.duration, "location": HUNT_LOCATION, "raw_audio_saved": false})
	WorldHistory.update_subject(subject_id, {"last_voice_contact": WorldHistory.event_count(), "memory": "The Hunter spoke to me while I was downed."}, "voice_contact_remembered")
	voice_channel.play_positional_acknowledgement(actor.rig.head_anchor)
	resolution_ui.set_voice_state("VOICE RECEIVED / POSITIONAL REPLY", float(result.peak), reply)


func _rival_retreats(message: String) -> void:
	if enemy_retreating:
		return
	enemy_retreating = true
	enemy.visible = false
	var lasting_wounds: Array = WorldHistory.subject(HUNT_ID).get("wounds", []).duplicate()
	if not lasting_wounds.has("fractured left arm"):
		lasting_wounds.append("fractured left arm")
	WorldHistory.update_subject(HUNT_ID, {"status": "escaped", "injury": "fractured left arm", "wounds": lasting_wounds, "next_adaptation": "industrial left-arm replacement", "memory": "You wounded Mara at the tunnel. She is seeking a replacement.", "elo": int(WorldHistory.subject(HUNT_ID).get("elo", 1180)) + 30}, "rival_survived_hunt")
	WorldHistory.record_event("hunt_arc_first_beat_complete", {"target": HUNT_ID, "outcome": "escaped", "location": HUNT_LOCATION})
	prompt.text = message


## Live contacts for the map, expressed as plain data so the map never reaches
## into the hunt loop for them.
func _map_contacts() -> Array:
	var contacts: Array = []
	for actor in encounter_actors:
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		var state := str(actor.get("disposition", "hostile"))
		if actor.get("anatomy") != null and bool(actor.anatomy.downed):
			state = "downed"
		contacts.append({"at": Vector2(node.global_position.x, node.global_position.z), "state": state, "name": str(actor.get("display_name", ""))})
	for cache in loose_loot:
		if is_instance_valid(cache):
			contacts.append({"at": Vector2(cache.global_position.x, cache.global_position.z), "state": "loot", "name": ""})
	if enemy != null and is_instance_valid(enemy) and enemy.visible and not enemy_retreating:
		contacts.append({"at": Vector2(enemy.global_position.x, enemy.global_position.z), "state": "hostile", "name": "MARA VOSS"})
	return contacts


## Lock-on. The Souls verb the third person was missing: combat could only be
## aimed with the free camera, so a swing at someone circling you was guesswork.
## Locked, the camera holds the pair, the body faces the target and the strike
## resolves against them rather than against whoever happens to be nearest.
func _lock_node() -> Node3D:
	if lock_target.is_empty():
		return null
	var actor := _actor_by_id(lock_target)
	if not actor.is_empty():
		var node := actor.node as Node3D
		if is_instance_valid(node) and not bool(actor.get("dead", false)):
			return node
	if lock_target == HUNT_ID and enemy != null and is_instance_valid(enemy) and enemy.visible and not enemy_retreating:
		return enemy
	lock_target = ""
	return null


func _lock_candidates() -> Array:
	var found: Array = []
	for actor in encounter_actors:
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		var gap: float = player.distance_to(node.global_position)
		if gap <= 26.0:
			found.append({"id": str(actor.subject_id), "node": node, "gap": gap})
	if enemy != null and is_instance_valid(enemy) and enemy.visible and not enemy_retreating:
		var mara_gap: float = player.distance_to(enemy.global_position)
		if mara_gap <= 26.0:
			found.append({"id": HUNT_ID, "node": enemy, "gap": mara_gap})
	found.sort_custom(func(a, b): return float(a.gap) < float(b.gap))
	return found


func _toggle_lock() -> void:
	if not lock_target.is_empty():
		lock_target = ""
		prompt.text = "LOCK RELEASED"
		return
	var candidates := _lock_candidates()
	if candidates.is_empty():
		prompt.text = "NOTHING TO LOCK"
		return
	# Prefer what the player is already looking at; fall back to the nearest.
	var forward := Vector3(sin(yaw), 0, cos(yaw)).normalized()
	var best: Dictionary = candidates[0]
	var best_score := -2.0
	for candidate in candidates:
		var toward: Vector3 = (candidate.node.global_position - player)
		toward.y = 0.0
		var score: float = forward.dot(toward.normalized()) - float(candidate.gap) * 0.012
		if score > best_score:
			best_score = score
			best = candidate
	lock_target = str(best.id)
	prompt.text = "LOCKED / %s" % lock_target.to_upper().replace("_", " ")


func _cycle_lock(direction: int) -> void:
	var candidates := _lock_candidates()
	if candidates.size() < 2:
		return
	var index := 0
	for position in candidates.size():
		if str(candidates[position].id) == lock_target:
			index = position
			break
	lock_target = str(candidates[(index + direction + candidates.size()) % candidates.size()].id)


## Locked, the camera is steered rather than mouse-driven, which is what makes
## circling a target readable. Mouse input still nudges it so it never feels
## taken away from the player.
func _steer_lock(delta: float) -> void:
	var node := _lock_node()
	lock_screen = Vector2(-1, -1)
	if node == null:
		return
	if player.distance_to(node.global_position) > 30.0:
		lock_target = ""
		prompt.text = "LOCK LOST"
		return
	var toward := node.global_position - player
	var desired_yaw := atan2(toward.x, toward.z)
	var flat := Vector2(toward.x, toward.z).length()
	var desired_pitch := clampf(-atan2(toward.y + 0.6, maxf(flat, 0.5)) - 0.06, -0.75, 0.42)
	yaw = lerp_angle(yaw, desired_yaw, clampf(delta * 7.0, 0.0, 1.0))
	pitch = lerpf(pitch, desired_pitch, clampf(delta * 5.0, 0.0, 1.0))
	if camera != null and not camera.is_position_behind(node.global_position + Vector3.UP * 1.1):
		lock_screen = camera.unproject_position(node.global_position + Vector3.UP * 1.1)


## The clinch. Half Sword's register is bodies actually colliding, and this
## combat had no equivalent: everything resolved at sword range or not at all,
## so two people standing on top of each other just swung through one another.
##
## A grapple is a stamina contest at contact range. It costs a lot, it can be
## lost, and winning it puts the other person in the downed window rather than
## killing them — which makes it the unarmed route into the execute / spare /
## recruit decision the game is built around.
const GRAPPLE_RANGE := 2.5
const GRAPPLE_DRAIN := 22.0


func _grapple_candidate() -> Dictionary:
	var forward := Vector3(sin(yaw), 0, cos(yaw)).normalized()
	for actor in encounter_actors:
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		if actor.anatomy.downed or str(actor.get("disposition", "hostile")) != "hostile":
			continue
		var toward := node.global_position - player
		toward.y = 0.0
		if toward.length() > GRAPPLE_RANGE:
			continue
		if forward.dot(toward.normalized()) < 0.25:
			continue
		return actor
	return {}


func _start_grapple() -> void:
	if not grapple_target.is_empty() or resolution_ui.visible or kill_cam.active:
		return
	if player_rig.is_downed() or player_rig.anatomy.dead or stamina < 20.0:
		prompt.text = "NOT ENOUGH LEFT IN YOU TO TAKE HOLD"
		return
	var actor := _grapple_candidate()
	if actor.is_empty():
		prompt.text = "NOTHING IN REACH TO GRAB"
		return
	grapple_target = str(actor.subject_id)
	grapple_advantage = 0.0
	grapple_clock = 0.0
	strike_windup = -1.0
	WorldHistory.record_event("grapple_started", {"subject_id": grapple_target, "location": HUNT_LOCATION})


func _break_grapple(message := "") -> void:
	grapple_target = ""
	grapple_advantage = 0.0
	if not message.is_empty():
		prompt.text = message


## Advantage runs from -1 to 1. The player pushes by holding the strike button;
## the opponent pushes back with whatever their arms and their pain leave them.
func _update_grapple(delta: float) -> void:
	var actor := _actor_by_id(grapple_target)
	if actor.is_empty() or bool(actor.get("dead", false)) or actor.anatomy.downed:
		_break_grapple()
		return
	var node := actor.node as Node3D
	var gap := player.distance_to(node.global_position)
	if gap > GRAPPLE_RANGE + 1.2:
		_break_grapple("THEY TORE FREE")
		return
	grapple_clock += delta

	# Locked together: both bodies hold position and face each other, which is
	# what makes a clinch read as a clinch rather than two people overlapping.
	var toward := node.global_position - player
	toward.y = 0.0
	if toward.length() > 0.01:
		yaw = atan2(toward.x, toward.z)
	player_body.velocity = Vector3.ZERO
	(node as CharacterBody3D).velocity = Vector3.ZERO
	actor.attack_time = 0.0

	var pushing := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_C)
	var player_force: float = player_rig.anatomy.combat_ratio() * (1.35 if pushing else 0.3)
	var their_force: float = float(actor.anatomy.combat_ratio()) * (1.0 - float(actor.anatomy.pain) * 0.006)
	grapple_advantage = clampf(grapple_advantage + (player_force - their_force) * delta * 0.85, -1.0, 1.0)
	stamina = maxf(0.0, stamina - (GRAPPLE_DRAIN if pushing else GRAPPLE_DRAIN * 0.35) * delta)
	if stamina <= 0.0:
		grapple_advantage -= delta * 0.9

	prompt.text = "CLINCH / %s   [LMB] PRESS   [SPACE] BREAK   %+d" % [str(actor.display_name).to_upper(), roundi(grapple_advantage * 100.0)]

	if grapple_advantage >= 1.0:
		_finish_grapple(actor)
	elif grapple_advantage <= -1.0:
		# Losing a clinch is not merely failing to win one.
		health = maxi(1, health - 11)
		_wound_player(node.global_position, 16.0, "blunt")
		player_body.velocity = (player - node.global_position).normalized() * 7.0
		_break_grapple("THEY PUT YOU DOWN AND STEPPED BACK")


## Winning drops them into the downed window rather than killing them. The
## takedown itself is blunt trauma to the head and torso, so the body carries a
## record of how it was beaten and the resolution form shows it.
func _finish_grapple(actor: Dictionary) -> void:
	var rig := actor.rig as BaselineHuman
	rig.hit("head", 26.0, 18.0, "blunt")
	rig.hit("torso", 30.0, 20.0, "blunt")
	if not actor.anatomy.downed and not actor.anatomy.dead:
		actor.anatomy.go_down()
	WorldHistory.record_event("grapple_takedown", {"subject_id": str(actor.subject_id), "location": HUNT_LOCATION})
	WorldHistory.update_subject(str(actor.subject_id), {"anatomy_state": rig.snapshot()}, "anatomy_changed")
	_break_grapple("%s IS ON THE GROUND — [E] DECIDE" % str(actor.display_name).to_upper())
	attack_cooldown = 0.5


func _toggle_panel(mode: String) -> void:
	allusions_artwork.close_artwork()
	panel_mode = "" if panel_mode == mode else mode
	character_archive.visible = panel_mode == "tree"
	# The map is a chart now, not a paragraph, so it owns its own surface.
	living_map.visible = panel_mode == "map"
	if living_map.visible:
		living_map.open_map()
	# The chart is a full sheet; the field labels underneath it are just noise.
	for label in [title, status, vitals, prompt]:
		label.visible = not living_map.visible
	panel.visible = not panel_mode.is_empty() and panel_mode not in ["tree", "map"]
	if character_archive.visible:
		character_archive.open_archive(HUNT_ID)
	else:
		character_archive.close_archive()
	if panel.visible:
		_refresh_archive()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if panel_mode.is_empty() else Input.MOUSE_MODE_VISIBLE


func _toggle_artwork() -> void:
	if allusions_artwork.visible:
		allusions_artwork.close_artwork()
		panel_mode = ""
	else:
		panel.visible = false
		character_archive.close_archive()
		living_map.close_map()
		panel_mode = "artwork"
		allusions_artwork.open_artwork()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if panel_mode.is_empty() else Input.MOUSE_MODE_VISIBLE


func _refresh_archive() -> void:
	var mara := WorldHistory.subject(HUNT_ID)
	var nix := WorldHistory.subject(FRIEND_ID)
	if panel_mode == "tree":
		var player := WorldHistory.subject("player")
		var player_axis := WorldHistory.tree_alignment(player)
		var nix_axis := WorldHistory.tree_alignment(nix)
		var mara_axis := WorldHistory.tree_alignment(mara)
		archive.text = "CHARACTER TREE // AS ABOVE SO BELOW\n\nPLAYER — %s\n ├─ bond ─ NIX ARDEN (%d) — %s\n └─ grudge ─ MARA VOSS (%d) — %s (%s)\n              └─ faction ─ ASHLINE WRECKERS\n\nThe axis reads the same standing shown on the Deep X-ray scan. The tree changes when history changes." % [WorldHistory.tree_axis_label(player_axis), int(nix.get("bond", 0)), WorldHistory.tree_axis_label(nix_axis), int(mara.get("grudge", 0)), WorldHistory.tree_axis_label(mara_axis), WorldHistory.tree_descriptor(mara)]
	else:
		var recent := WorldHistory.recent_events(7)
		var derby_result := "LOCAL DRIVER WRECKS OUT; WALKS INTO ASHBLOOM" if WorldHistory.event_count("derby_round_lost") > 0 else "UNKNOWN DRIVER TAKES THE BONE YARD CROWN" if WorldHistory.event_count("derby_round_won") > 0 else "BONE YARD FEED REMAINS LIVE"
		var lines: Array[String] = ["WORLD INDEX // BONE YARD FILE", "", "CELLOUTZ WIRE // REACTIVE REPORT", derby_result, "Mara Voss response: %s" % str(mara.get("status", "unknown")), "", "MARA VOSS - %s" % str(mara.get("role", "unknown")).to_upper(), "Injury: %s" % str(mara.get("injury", "unknown")), "Memory: %s" % str(mara.get("memory", "unknown")), "", "RECENT HISTORY:"]
		for event in recent:
			lines.append("- %s" % str(event.get("type", "unknown")).replace("_", " "))
		archive.text = "\n".join(lines)


func _update_hud() -> void:
	title.text = "ALLUSIONS TO GRANDEUR // LIMBO: ASHBLOOM EXPANSE"
	status.text = "WASD MOVE  SHIFT RUN  LMB STRIKE  SPACE DODGE  Q SURGE\nE INTERACT  TAB INDEX  M MAP  T TREE  J ALLUSIONS  F CAMERA"
	vitals.text = "BODY  %03d%%\nSTAMINA  %03d%%\nPROSTHETIC  TORQUE ARM\nHUNT  %s" % [health, roundi(stamina), str(WorldHistory.subject(HUNT_ID).get("status", "dormant")).to_upper()]
	prompt.visible = not resolution_ui.visible and not living_map.visible
	if panel.visible:
		_refresh_archive()
	if field_interface.has_method("set_state"):
		field_interface.set_state({
			"health": health,
			"stamina": stamina,
			"rival_status": WorldHistory.subject(HUNT_ID).get("status", "dormant"),
			"menu_open": panel.visible or character_archive.visible or allusions_artwork.visible or living_map.visible,
			"menu_mode": panel_mode,
			"weapon": arsenal.state() if arsenal != null else {},
			"lock_screen": lock_screen,
		})


func _update_camera() -> void:
	if resolution_ui != null and resolution_ui.visible:
		camera.fov = 72.0
		var subject := _actor_by_id(resolution_target)
		if not subject.is_empty():
			var focus: Vector3 = subject.node.global_position + Vector3.UP * 0.65
			var away := player - focus
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.BACK
			away = away.normalized()
			var shoulder := Vector3(-away.z, 0, away.x) * 1.05
			var desired := player + away * 3.1 + shoulder * 0.85 + Vector3.UP * 1.55
			var ray := PhysicsRayQueryParameters3D.create(focus, desired)
			var excluded: Array[RID] = [player_body.get_rid()]
			if subject.node is CollisionObject3D:
				excluded.append((subject.node as CollisionObject3D).get_rid())
			ray.exclude = excluded
			var obstruction := get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstruction.is_empty():
				desired = obstruction.position + (focus - obstruction.position).normalized() * 0.35
			camera.global_position = desired
			camera.look_at(focus, Vector3.UP)
			var player_head := player_rig.parts.get("head") as Node3D
			if player_head != null and is_instance_valid(player_head):
				player_head.visible = false
			return
	var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var physical_offset := Vector3.ZERO
	if body_motion != null:
		var local_offset: Vector3 = body_motion.camera_offset
		var flat_forward := Vector3(sin(yaw), 0, cos(yaw))
		var flat_right := Vector3(flat_forward.z, 0, -flat_forward.x)
		physical_offset = flat_right * local_offset.x + Vector3.UP * local_offset.y + flat_forward * local_offset.z
		camera.fov = 72.0 + body_motion.fov_add
	if third_person:
		# Souls framing rather than a chase cam parked behind the head: the body
		# sits off-centre over one shoulder and low in frame, the rig is close
		# enough to read a swing on, and the whole thing is spring-damped so it
		# trails the player instead of snapping to a computed point each frame.
		var locked := _lock_node()
		var focus := player + Vector3.UP * 0.95
		var shoulder := Vector3(cos(yaw), 0, -sin(yaw)) * 0.62
		var distance := 4.4 if locked != null else 3.8
		if locked != null:
			# Framing holds the pair, so backing off a locked target widens the
			# shot instead of losing them behind the player's own shoulder.
			var gap: float = player.distance_to(locked.global_position)
			distance = clampf(3.6 + gap * 0.22, 3.6, 6.2)
			focus = focus.lerp(locked.global_position + Vector3.UP * 0.9, 0.32)
		var desired := player - look * distance + Vector3.UP * 0.85 + shoulder + physical_offset * 0.35
		if not camera_ready:
			camera_position = desired
			camera_ready = true
		var responsiveness := 15.0 if locked != null else 11.0
		camera_position = camera_position.lerp(desired, clampf(get_physics_process_delta_time() * responsiveness, 0.0, 1.0))
		# The wall test is the last thing that happens, on the position actually
		# used. Testing the *target* and then smoothing toward it let the camera
		# sit inside a building for every frame of the blend, which is how the
		# spawn view ended up as a wall of brown.
		camera.global_position = HUNTER_MOTOR.collision_safe_camera(
			get_world_3d().direct_space_state,
			focus,
			camera_position,
			[player_body.get_rid()]
		)
		if locked != null:
			# Locked, the shot is about the pair, so aim between them.
			camera.look_at(focus, Vector3.UP)
		else:
			# Unlocked, aim parallel to the look heading rather than at the
			# player. Aiming *at* the player cancels the shoulder offset and
			# re-centres the body, which is what made this read as a chase cam
			# parked behind the head instead of an over-the-shoulder shot.
			camera.look_at(camera.global_position + look * 12.0, Vector3.UP)
	else:
		camera.global_position = player + physical_offset
		camera.look_at(player + look * 12.0)
	if body_motion != null:
		camera.rotation.z += body_motion.camera_roll * (0.45 if third_person else 1.0)
	if player_rig != null and is_instance_valid(player_rig):
		var facing := yaw + PI
		var locked_body := _lock_node()
		if locked_body != null and third_person:
			var toward := locked_body.global_position - player
			facing = atan2(toward.x, toward.z) + PI
		player_rig.rotation.y = lerp_angle(player_rig.rotation.y, facing, clampf(get_physics_process_delta_time() * 12.0, 0.0, 1.0))
		# The first-person camera sits inside the skull, so the head would fill
		# the view. Everything else stays on: looking down at your own ruined
		# arm is the entire point of the player having a body.
		var head := player_rig.parts.get("head") as Node3D
		if head != null and is_instance_valid(head):
			head.visible = third_person


func _build_world() -> void:
	# Was a hand-rolled Environment on a near-black background with a flat colour
	# ambient, which rendered the Expanse as an unreadable brown murk — the same
	# fault the menu had. The roadmap already listed this scene as un-migrated.
	$WorldEnvironment.environment = WorldLook.environment("ashbloom")
	_add_mesh(BoxMesh.new(), Vector3(0, -0.6, 0), Vector3(470, 1, 370), Color("17150f"), 0.0)
	var floor_body := StaticBody3D.new()
	var floor_collider := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(470, 1, 370)
	floor_collider.shape = floor_shape
	floor_body.position.y = -0.6
	floor_body.add_child(floor_collider)
	add_child(floor_body)
	_add_mesh(BoxMesh.new(), Vector3(0, 0, -24), Vector3(13, 5, 1.5), Color("2b2119"), 0.0)
	for index in 26:
		var x := -31.0 + float(index % 9) * 7.5
		var z := -24.0 + float(index / 9) * 22.0
		_add_mesh(BoxMesh.new(), Vector3(x, 1.1 + float(index % 3), z), Vector3(2.0 + float(index % 2), 2.0 + float(index % 4), 2.0), Color("3d291d"), 0.0)
	# Vast readable landmarks: original fungal towers, shattered pylons and
	# radioactive caps turn the former circular test pen into a traversable region.
	for index in 72:
		var angle := float(index) * 2.39996
		var radius := 45.0 + float((index * 47) % 145)
		var fungus_pos := Vector3(cos(angle) * radius * 1.25, 2.0, sin(angle) * radius)
		var stalk_height := 4.0 + float(index % 8) * 1.4
		_add_mesh(CylinderMesh.new(), fungus_pos, Vector3(1.2 + float(index % 3) * 0.3, stalk_height, 1.2), Color("59603b"), 0.0)
		_add_mesh(SphereMesh.new(), fungus_pos + Vector3(0, stalk_height + 1.2, 0), Vector3(3.2 + float(index % 4), 0.8, 3.2 + float(index % 4)), Color("8da442"), 0.25 if index % 6 == 0 else 0.0)
	for index in 34:
		var side := -1.0 if index % 2 == 0 else 1.0
		var pylon_pos := Vector3(side * (58 + (index % 5) * 25), 5, -155 + index * 9)
		_add_mesh(BoxMesh.new(), pylon_pos, Vector3(2.2, 12 + index % 7, 2.2), Color("352b26"), 0.0)
	for index in 9:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-24 + index * 6, 6, -17 + (index % 2) * 23)
		lamp.light_color = Color("ec6d2e")
		lamp.light_energy = 3.5
		lamp.omni_range = 13
		add_child(lamp)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_color = Color("c89572")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)


func _build_expanse_systems() -> void:
	generated_world = WORLD_GENERATOR.new()
	generated_world.name = "ProceduralAshbloomDistricts"
	add_child(generated_world)
	generated_world.call("generate", 774013)
	pathfinder.build(generated_world.lots)
	misfire_director = MISFIRE_DIRECTOR.new()
	misfire_director.name = "RealityMisfires"
	add_child(misfire_director)
	misfire_director.connect("misfire_triggered", _on_reality_misfire)
	misfire_director.call("generate", 774013, Vector2(470, 370), 18)
	if living_map != null:
		living_map.bind(generated_world, misfire_director, _map_contacts)


func _on_reality_misfire(encounter: Dictionary, at: Vector3) -> void:
	WorldHistory.record_event("reality_misfire_triggered", {"encounter": encounter.duplicate(true), "location": HUNT_LOCATION})
	var title_text := str(encounter.get("title", "REALITY MISFIRE"))
	var summary := str(encounter.get("summary", "Something impossible notices you."))
	prompt.text = "REALITY MISFIRE // %s\n%s" % [title_text, summary]
	var kind := str(encounter.get("kind", "mystery"))
	if kind in ["hostile", "boss"]:
		_spawn_encounter_actor(encounter, at)
	else:
		_spawn_misfire_marker(title_text, summary, at, kind, str(encounter.instance_id))


func _spawn_encounter_actor(encounter: Dictionary, at: Vector3) -> void:
	var subject_id := "%s_actor" % str(encounter.get("instance_id", "misfire"))
	var saved_actor := WorldHistory.subject(subject_id)
	if str(saved_actor.get("status", "")) in ["dead", "escaped"]:
		return
	var display_name := "Ashline Tollkeeper" if str(encounter.kind) == "hostile" else "Dead Weather Saint"
	var actor := CharacterBody3D.new()
	actor.name = subject_id
	actor.position = pathfinder.safe_position(at + Vector3.UP)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	actor.add_child(collision)
	add_child(actor)
	var identity := Label3D.new()
	identity.name = "Identity"
	identity.text = "%s\nELO %04d" % [display_name.to_upper(), 1110 if str(encounter.kind) == "hostile" else 1510]
	identity.position = Vector3(0, 3.1, 0)
	identity.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.add_child(identity)
	# Was a bare capsule with an anatomy component bolted on and no hit geometry
	# at all, which is why melee had to pick a zone by round-robin. The rig gives
	# them a real body to aim at.
	var rig := BaselineHuman.new()
	rig.name = "Body"
	actor.add_child(rig)
	rig.position = Vector3(0, -0.9, 0)
	var rig_config := {
		"flesh": Color("70201c") if str(encounter.kind) == "hostile" else Color("586c3a"),
		"variation": subject_id.length(),
		"blood": 5200.0 if str(encounter.kind) == "boss" else 4300.0,
		"cybernetics": {"torso": {"armor": 0.18}},
	}
	if saved_actor.get("anatomy_state") is Dictionary:
		rig_config["restore"] = saved_actor.anatomy_state
	rig.gore = viscera_fx
	rig.build(subject_id, rig_config)
	var anatomy: Node = rig.anatomy
	var loot := ["Ashline toll teeth", "rust scrip"] if str(encounter.kind) == "hostile" else ["weather-heart filament", "dead god relay"]
	encounter_actors.append({"subject_id": subject_id, "display_name": display_name, "node": actor, "rig": rig, "anatomy": anatomy, "state": "hunting", "disposition": "hostile", "speed": 3.7, "loot": loot, "loot_at_risk": false, "dead": false})
	encounter_actors.back()["encounter_id"] = str(encounter.get("instance_id", ""))
	if str(saved_actor.get("status", "")) in ["spared", "recruited"]:
		encounter_actors.back().state = str(saved_actor.status)
		encounter_actors.back().disposition = "ally" if str(saved_actor.status) == "recruited" else "neutral"
	WorldHistory.register_subject(subject_id, {"name": display_name, "kind": "person", "role": str(encounter.kind), "elo": 1110 if str(encounter.kind) == "hostile" else 1510, "status": "encountered", "memory": summary_from(encounter), "wounds": [], "anatomy": anatomy.call("snapshot"), "relations": {"player": {"kind": "enemy", "strength": 35}}})


func summary_from(encounter: Dictionary) -> String:
	return str(encounter.get("summary", "Encountered in the Ashbloom Expanse."))


func _spawn_misfire_marker(title_text: String, summary: String, at: Vector3, kind: String, instance_id: String = "") -> void:
	var marker := Node3D.new()
	marker.position = pathfinder.safe_position(at)
	marker.set_meta("kind", kind)
	marker.set_meta("instance_id", instance_id)
	social_markers.append(marker)
	add_child(marker)
	_add_mesh_to(marker, SphereMesh.new(), Vector3(0, 1.2, 0), Color("35b7a7") if kind == "friendly" else Color("b8d94a"), 0.8)
	var label := Label3D.new()
	label.text = "%s\n%s" % [title_text, summary]
	label.position = Vector3(0, 3.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	marker.add_child(label)


func _spawn_severed_part(at: Vector3, zone: String) -> void:
	var part := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.72
	mesh.material = _material(Color("6b1714"), 0.0)
	part.mesh = mesh
	part.position = at + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
	part.rotation = Vector3(randf(), randf(), randf())
	add_child(part)
	WorldHistory.record_event("limb_severed", {"zone": zone, "location": HUNT_LOCATION})
	get_tree().create_timer(18.0).timeout.connect(part.queue_free)


func _spawn_loot_cache(at: Vector3, items: Array) -> void:
	var cache := Node3D.new()
	cache.position = at
	add_child(cache)
	loose_loot.append(cache)
	cache.set_meta("items", items.duplicate())
	_add_mesh_to(cache, BoxMesh.new(), Vector3(0, 0.35, 0), Color("c08134"), 0.35)
	var label := Label3D.new()
	label.text = "LOOT // %s" % ", ".join(PackedStringArray(items))
	label.position = Vector3(0, 1.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cache.add_child(label)


func _spawn_friend() -> void:
	friend = Node3D.new()
	friend.position = Vector3(19, 1.0, 5)
	# Nix was a bare capsule while every procedurally spawned nobody in the
	# region got a full anatomy rig. The two named characters in the game were
	# the only two people in it without bodies.
	friend_rig = BaselineHuman.new()
	friend_rig.name = "Body"
	friend_rig.position = Vector3(0, -0.95, 0)
	friend.add_child(friend_rig)
	friend_rig.gore = viscera_fx
	var nix: Dictionary = WorldHistory.subject(FRIEND_ID)
	var nix_config := {"flesh": Color("6f7a52"), "variation": 5, "blood": 5000.0}
	if nix.get("anatomy_state") is Dictionary:
		nix_config["restore"] = nix.anatomy_state
	friend_rig.build(FRIEND_ID, nix_config)
	var label := Label3D.new()
	label.text = "NIX ARDEN\n[E] TALK"
	label.position = Vector3(0, 3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	friend.add_child(label)
	add_child(friend)


func _spawn_rival() -> void:
	enemy = Node3D.new()
	enemy.visible = false
	# Mara is the character the whole Hunt System exists to produce, and she was
	# a capsule with a box stuck to her shoulder. On a real rig her recorded
	# wounds and her replacement arm are *on her body*, which is the difference
	# between "bodies remember" being a pillar and being a line in a dossier.
	enemy_rig = BaselineHuman.new()
	enemy_rig.name = "Body"
	enemy_rig.position = Vector3(0, -1.15, 0)
	enemy.add_child(enemy_rig)
	enemy_rig.gore = viscera_fx
	var mara_record: Dictionary = WorldHistory.subject(HUNT_ID)
	var mara_config := {"flesh": Color("7a4a3a"), "variation": 2, "blood": 5400.0}
	if mara_record.get("anatomy_state") is Dictionary:
		mara_config["restore"] = mara_record.anatomy_state
	enemy_rig.build(HUNT_ID, mara_config)
	var label := Label3D.new()
	label.text = "MARA VOSS // ASHLINE CAPTAIN"
	label.position = Vector3(0, 3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	enemy.add_child(label)
	var mara := WorldHistory.subject(HUNT_ID)
	if not str(mara.get("next_adaptation", "")).is_empty():
		label.text = "MARA VOSS // REBUILT ASHLINE CAPTAIN"
		# The industrial arm is now an actual prosthetic in the anatomy record,
		# so it restores function, changes her combat ratio and shows on the rig
		# rather than being a cylinder parented next to her.
		enemy_rig.install_prosthetic("left_arm", {
			"name": "Ashline industrial arm", "armor": 0.34, "restores": 0.82, "tint": Color("c15d2d"),
		})
		var altered_vehicle := SCRAP_SKIFF.instantiate()
		altered_vehicle.name = "MarasRebuiltWrecker"
		altered_vehicle.position = Vector3(4.0, -0.45, 1.8)
		altered_vehicle.rotation.y = -0.7
		altered_vehicle.scale = Vector3(0.78, 0.78, 0.78)
		enemy.add_child(altered_vehicle)
	add_child(enemy)


func _spawn_ashline_reinforcements() -> void:
	for index in 2:
		var encounter := {"instance_id": "mara_reinforcement_%d" % index, "kind": "hostile", "summary": "An Ashline knife came to keep Mara's second body alive."}
		_spawn_encounter_actor(encounter, enemy.global_position + Vector3(-6.0 if index == 0 else 6.0, 0, 4.0 + index * 2.0))


func _spawn_blood(at: Vector3, amount: int) -> void:
	for index in mini(8, amount / 4):
		var piece := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.08 + float(index) * 0.012
		mesh.height = mesh.radius * 2
		mesh.material = _material(Color("6d100d"), 0.0)
		piece.mesh = mesh
		piece.position = at + Vector3(randf_range(-0.7, 0.7), randf_range(-0.2, 0.8), randf_range(-0.7, 0.7))
		add_child(piece)
		var timer := get_tree().create_timer(3.0 + randf())
		timer.timeout.connect(piece.queue_free)


func _add_mesh(mesh: PrimitiveMesh, position_value: Vector3, scale_value: Vector3, color: Color, emission: float) -> void:
	_add_mesh_to(self, mesh, position_value, color, emission, scale_value)


func _add_mesh_to(parent: Node3D, mesh: PrimitiveMesh, position_value: Vector3, color: Color, emission: float, scale_value := Vector3.ONE) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	mesh.material = _material(color, emission)
	parent.add_child(instance)


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.38
	material.roughness = 0.7
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material
