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
var strike_windup := -1.0
var rival_attack_clock := 0.0
var dodge_remaining := 0.0
var dodge_direction := Vector3.ZERO
var handheld: Control
var pathfinder = preload("res://systems/ashbloom_pathfinder.gd").new()
var social_markers: Array[Node3D] = []

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
	_build_world()
	handheld = HANDHELD.new()
	handheld.name = "Handheld"
	$HUD.add_child(handheld)
	_build_expanse_systems()
	_register_people()
	player_body = CharacterBody3D.new()
	player_body.name = "HunterController"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	collider.shape = capsule
	player_body.add_child(collider)
	add_child(player_body)
	player_body.position = player - Vector3.UP * 0.6
	WorldHistory.register_subject("inventory", {"items": []})
	_spawn_friend()
	_spawn_rival()
	_update_camera()
	WorldHistory.record_event("player_entered_hunt_ground", {"location": HUNT_LOCATION, "hunt_id": HUNT_ID})


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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				if not panel_mode.is_empty():
					_toggle_panel(panel_mode)
			KEY_F: third_person = not third_person
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
			KEY_E: _interact()
			KEY_SPACE: _dodge()
			KEY_Q: _use_prosthetic_surge()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clamp(pitch - event.relative.y * 0.0024, -0.75, 0.42)


func _physics_process(delta: float) -> void:
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
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	_update_player(delta)
	_update_rival(delta)
	_update_encounter_actors(delta)
	if misfire_director != null:
		misfire_director.call("update_player_position", player)
	_update_camera()
	_update_hud()


func _update_player(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := Vector3(sin(yaw), 0, cos(yaw)).normalized()
	var right := Vector3(forward.z, 0, -forward.x)
	var direction := (right * move.x + forward * move.y).normalized()
	var sprinting := Input.is_action_pressed("sprint") and stamina > 1.0 and move.length() > 0.0
	var speed := SPRINT_SPEED if sprinting else PLAYER_SPEED
	var desired := direction * speed
	if dodge_remaining > 0.0:
		desired = dodge_direction * 16.0
	player_body.velocity.x = move_toward(player_body.velocity.x, desired.x, 50.0 * delta)
	player_body.velocity.z = move_toward(player_body.velocity.z, desired.z, 50.0 * delta)
	player_body.velocity.y = -1.0 if player_body.is_on_floor() else player_body.velocity.y - 22.0 * delta
	player_body.move_and_slide()
	if player_body.position.y < -10.0:
		player_body.position = Vector3(0, 1.0, 19)
	player = player_body.position + Vector3.UP * 0.6
	stamina = clampf(stamina + (-26.0 if sprinting else 18.0) * delta, 0, 100)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_attack()


func _attack() -> void:
	if not panel_mode.is_empty() or attack_cooldown > 0.0 or stamina < 18.0:
		return
	attack_cooldown = 0.72
	stamina -= 18.0
	strike_windup = 0.18


func _resolve_strike() -> void:
	if _attack_nearest_encounter_actor():
		return
	if enemy == null or not enemy.visible or enemy_retreating:
		return
	var distance := player.distance_to(enemy.global_position)
	if distance > 4.1:
		return
	var facing := Vector3(sin(yaw), 0, cos(yaw)).normalized().dot((enemy.global_position - player).normalized())
	if facing < 0.18:
		return
	var body_zone := "torso"
	if enemy_health < 55:
		body_zone = "left arm"
	if enemy_health < 28:
		body_zone = "leg"
	var damage := 22 if story_step > 0 else 15
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


func _attack_nearest_encounter_actor() -> bool:
	var nearest_index := -1
	var nearest_distance := 99999.0
	for index in encounter_actors.size():
		var actor: Dictionary = encounter_actors[index]
		var node := actor.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(actor.get("dead", false)):
			continue
		var distance := player.distance_to(node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	if nearest_index < 0 or nearest_distance > 4.1:
		return false
	var actor: Dictionary = encounter_actors[nearest_index]
	var target: Node3D = actor.node as Node3D
	var facing := Vector3(sin(yaw), 0, cos(yaw)).normalized().dot((target.global_position - player).normalized())
	if facing < 0.12:
		return false
	var zones := ["torso", "left_arm", "right_arm", "left_leg", "right_leg", "head"]
	var zone: String = zones[(WorldHistory.event_count("npc_anatomy_hit") + nearest_index) % zones.size()]
	var anatomy: Node = actor.anatomy as Node
	var result: Dictionary = anatomy.call("apply_hit", zone, 24.0, 18.0, "cut")
	WorldHistory.update_subject(str(actor.subject_id), {"anatomy_state": anatomy.call("snapshot")}, "anatomy_changed")
	_spawn_blood(target.global_position + Vector3(0, 1.1, 0), 28)
	WorldHistory.record_event("npc_anatomy_hit", {"subject_id": actor.subject_id, "zone": zone, "result": result, "location": HUNT_LOCATION})
	if bool(result.get("disabled", false)) and zone in ["left_arm", "right_arm", "left_leg", "right_leg"]:
		_spawn_severed_part(target.global_position + Vector3(0, 1.0, 0), zone)
	if anatomy.critical or anatomy.pain >= 68.0:
		actor.state = "fleeing"
		actor.loot_at_risk = true
		prompt.text = "%s IS BLEEDING OUT AND ESCAPING — CHASE FOR THEIR LOOT OR LET THEM GO." % str(actor.display_name).to_upper()
	if anatomy.dead:
		_kill_encounter_actor(nearest_index, "combat_trauma")
	return true


func _dodge() -> void:
	if not panel_mode.is_empty() or dodge_cooldown > 0.0 or stamina < 25.0:
		return
	dodge_cooldown = 0.75
	stamina -= 25.0
	var forward := Vector3(sin(yaw), 0, cos(yaw)).normalized()
	dodge_direction = -forward
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


func _toggle_panel(mode: String) -> void:
	allusions_artwork.close_artwork()
	panel_mode = "" if panel_mode == mode else mode
	character_archive.visible = panel_mode == "tree"
	panel.visible = not panel_mode.is_empty() and panel_mode != "tree"
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
		panel_mode = "artwork"
		allusions_artwork.open_artwork()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if panel_mode.is_empty() else Input.MOUSE_MODE_VISIBLE


func _refresh_archive() -> void:
	var mara := WorldHistory.subject(HUNT_ID)
	var nix := WorldHistory.subject(FRIEND_ID)
	if panel_mode == "map":
		archive.text = "LIVING MAP // LIMBO: ASHBLOOM EXPANSE\n\n[BONE YARD] Rusted quarry / Ashline territory\n[BLACK MILE] Raider highway beyond the storm pylons\n[SOFT ROT] Irradiated fungal forest / shifting paths\n[OSSUARY] Sealed anatomy works below the ridge\n[TUNNEL] Floodlit trade route under the quarry\n\nThe map expands through witness accounts, tracks and surviving encounters."
	elif panel_mode == "tree":
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
	if panel.visible:
		_refresh_archive()
	if field_interface.has_method("set_state"):
		field_interface.set_state({
			"health": health,
			"stamina": stamina,
			"rival_status": WorldHistory.subject(HUNT_ID).get("status", "dormant"),
			"menu_open": panel.visible or character_archive.visible or allusions_artwork.visible,
			"menu_mode": panel_mode,
		})


func _update_camera() -> void:
	var look := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	if third_person:
		camera.global_position = player - look * 6.5 + Vector3.UP * 1.4
		camera.look_at(player + look * 8.0 + Vector3.UP * 0.6)
	else:
		camera.global_position = player
		camera.look_at(player + look * 12.0)


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0908")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("503022")
	environment.ambient_light_energy = 0.7
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.024
	environment.volumetric_fog_albedo = Color("586042")
	$WorldEnvironment.environment = environment
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
	_add_mesh_to(actor, CapsuleMesh.new(), Vector3(0, 1, 0), Color("70201c") if str(encounter.kind) == "hostile" else Color("586c3a"), 0.0)
	var identity := Label3D.new()
	identity.name = "Identity"
	identity.text = "%s\nELO %04d" % [display_name.to_upper(), 1110 if str(encounter.kind) == "hostile" else 1510]
	identity.position = Vector3(0, 3.1, 0)
	identity.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.add_child(identity)
	var anatomy: Node = ANATOMY_COMPONENT.new()
	actor.add_child(anatomy)
	anatomy.call("configure", subject_id, 5200.0 if str(encounter.kind) == "boss" else 4300.0, {"torso": {"armor": 0.18}})
	if saved_actor.get("anatomy_state") is Dictionary:
		anatomy.call("restore", saved_actor.anatomy_state)
	var loot := ["Ashline toll teeth", "rust scrip"] if str(encounter.kind) == "hostile" else ["weather-heart filament", "dead god relay"]
	encounter_actors.append({"subject_id": subject_id, "display_name": display_name, "node": actor, "anatomy": anatomy, "state": "hunting", "disposition": "hostile", "speed": 3.7, "loot": loot, "loot_at_risk": false, "dead": false})
	encounter_actors.back()["encounter_id"] = str(encounter.get("instance_id", ""))
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
	_add_mesh_to(friend, CapsuleMesh.new(), Vector3(0, 1, 0), Color("376d68"), 0.0)
	var label := Label3D.new()
	label.text = "NIX ARDEN\n[E] TALK"
	label.position = Vector3(0, 3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	friend.add_child(label)
	add_child(friend)


func _spawn_rival() -> void:
	enemy = Node3D.new()
	enemy.visible = false
	_add_mesh_to(enemy, CapsuleMesh.new(), Vector3(0, 1, 0), Color("7a221a"), 0.0)
	_add_mesh_to(enemy, BoxMesh.new(), Vector3(-0.55, 1.2, 0), Color("9d7f5c"), 0.2)
	var label := Label3D.new()
	label.text = "MARA VOSS // ASHLINE CAPTAIN"
	label.position = Vector3(0, 3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	enemy.add_child(label)
	var mara := WorldHistory.subject(HUNT_ID)
	if not str(mara.get("next_adaptation", "")).is_empty():
		label.text = "MARA VOSS // REBUILT ASHLINE CAPTAIN"
		_add_mesh_to(enemy, CylinderMesh.new(), Vector3(-0.72, 1.15, 0), Color("c15d2d"), 0.25, Vector3(0.34, 0.85, 0.34))
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
