extends Node3D

# Ashbloom Expanse vertical slice. World Zero is the development milestone;
# Limbo is the realm; Ashbloom is this first irradiated region.
const PLAYER_SPEED := 7.0
const SPRINT_SPEED := 12.0
const HUNT_ID := "mara_voss"
const FRIEND_ID := "nix_arden"
const HUNT_LOCATION := "ashbloom_bone_yard"

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

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var title: Label = $HUD/Title
@onready var status: Label = $HUD/Status
@onready var vitals: Label = $HUD/VitalsPanel/Vitals
@onready var prompt: Label = $HUD/Prompt
@onready var panel: PanelContainer = $HUD/ArchivePanel
@onready var archive: Label = $HUD/ArchivePanel/Margin/Archive
@onready var field_interface: Control = $HUD/FieldInterface
@onready var character_archive: Control = $HUD/CharacterArchive


func _ready() -> void:
	_build_world()
	_register_people()
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
			KEY_TAB: _toggle_panel("index")
			KEY_M: _toggle_panel("map")
			KEY_T: _toggle_panel("tree")
			KEY_E: _interact()
			KEY_SPACE: _dodge()
			KEY_Q: _use_prosthetic_surge()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clamp(pitch - event.relative.y * 0.0024, -0.75, 0.42)


func _process(delta: float) -> void:
	pulse += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	_update_player(delta)
	_update_rival(delta)
	_update_camera()
	_update_hud()


func _update_player(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := Vector3(sin(yaw), 0, cos(yaw)).normalized()
	var right := Vector3(forward.z, 0, -forward.x)
	var direction := (right * move.x + forward * move.y).normalized()
	var sprinting := Input.is_action_pressed("sprint") and stamina > 1.0 and move.length() > 0.0
	var speed := SPRINT_SPEED if sprinting else PLAYER_SPEED
	player += direction * speed * delta
	player.x = clampf(player.x, -225, 225)
	player.z = clampf(player.z, -175, 175)
	stamina = clampf(stamina + (-26.0 if sprinting else 18.0) * delta, 0, 100)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_attack()


func _attack() -> void:
	if attack_cooldown > 0.0 or stamina < 18.0:
		return
	attack_cooldown = 0.48
	stamina -= 18.0
	if enemy == null or enemy_retreating:
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
	WorldHistory.update_subject(HUNT_ID, {"injury": "cut %s" % body_zone, "grudge": mini(100, int(WorldHistory.subject(HUNT_ID).get("grudge", 0)) + 14), "status": "fighting"}, "rival_injured")
	if enemy_health <= 0:
		_rival_retreats("You left Mara alive. She will return altered.")


func _dodge() -> void:
	if dodge_cooldown > 0.0 or stamina < 25.0:
		return
	dodge_cooldown = 0.75
	stamina -= 25.0
	var forward := Vector3(sin(yaw), 0, cos(yaw)).normalized()
	player -= forward * 4.5
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
	enemy_health = 100
	WorldHistory.update_subject(HUNT_ID, {"status": "hunting", "memory": "Mara came to settle the Bone Yard debt."}, "hunt_arc_started")
	WorldHistory.record_event("canonical_hunt_encounter_started", {"hunter": "player", "target": HUNT_ID, "location": HUNT_LOCATION})
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
	elif sin(pulse * 2.8) > 0.965:
		health = maxi(0, health - 7)
		stamina = maxf(0, stamina - 12)
		WorldHistory.record_event("rival_struck_player", {"rival": HUNT_ID, "location": HUNT_LOCATION})
		if health <= 0:
			health = 65
			player = Vector3(0, 1.5, 19)
			WorldHistory.record_event("player_recovered_by_nix", {"location": HUNT_LOCATION})
	if enemy_health <= 25:
		_rival_retreats("Mara escapes through the tunnel. Her next body will not be the same.")


func _rival_retreats(message: String) -> void:
	if enemy_retreating:
		return
	enemy_retreating = true
	enemy.visible = false
	WorldHistory.update_subject(HUNT_ID, {"status": "escaped", "injury": "fractured left arm", "memory": "You wounded Mara at the tunnel. She is seeking a replacement.", "elo": int(WorldHistory.subject(HUNT_ID).get("elo", 1180)) + 30}, "rival_survived_hunt")
	WorldHistory.record_event("hunt_arc_first_beat_complete", {"target": HUNT_ID, "outcome": "escaped", "location": HUNT_LOCATION})
	prompt.text = message


func _toggle_panel(mode: String) -> void:
	panel_mode = "" if panel_mode == mode else mode
	character_archive.visible = panel_mode == "tree"
	panel.visible = not panel_mode.is_empty() and panel_mode != "tree"
	if character_archive.visible:
		character_archive.open_archive(HUNT_ID)
	else:
		character_archive.close_archive()
	if panel.visible:
		_refresh_archive()


func _refresh_archive() -> void:
	var mara := WorldHistory.subject(HUNT_ID)
	var nix := WorldHistory.subject(FRIEND_ID)
	if panel_mode == "map":
		archive.text = "LIVING MAP // LIMBO: ASHBLOOM EXPANSE\n\n[BONE YARD] Rusted quarry / Ashline territory\n[BLACK MILE] Raider highway beyond the storm pylons\n[SOFT ROT] Irradiated fungal forest / shifting paths\n[OSSUARY] Sealed anatomy works below the ridge\n[TUNNEL] Floodlit trade route under the quarry\n\nThe map expands through witness accounts, tracks and surviving encounters."
	elif panel_mode == "tree":
		archive.text = "CHARACTER TREE // AS ABOVE SO BELOW\n\nPLAYER\n ├─ bond ─ NIX ARDEN (%d)\n └─ grudge ─ MARA VOSS (%d)\n              └─ faction ─ ASHLINE WRECKERS\n\nThe tree changes when history changes." % [int(nix.get("bond", 0)), int(mara.get("grudge", 0))]
	else:
		var recent := WorldHistory.recent_events(7)
		var lines: Array[String] = ["WORLD INDEX // BONE YARD FILE", "", "MARA VOSS - %s" % str(mara.get("role", "unknown")).to_upper(), "Status: %s" % str(mara.get("status", "unknown")), "Injury: %s" % str(mara.get("injury", "unknown")), "Memory: %s" % str(mara.get("memory", "unknown")), "", "RECENT HISTORY:"]
		for event in recent:
			lines.append("- %s" % str(event.get("type", "unknown")).replace("_", " "))
		archive.text = "\n".join(lines)


func _update_hud() -> void:
	title.text = "ALLUSIONS TO GRANDEUR // LIMBO: ASHBLOOM EXPANSE"
	status.text = "WASD MOVE  SHIFT RUN  LMB STRIKE  SPACE DODGE  Q SURGE\nE INTERACT  TAB INDEX  M MAP  T TREE  F CAMERA"
	vitals.text = "BODY  %03d%%\nSTAMINA  %03d%%\nPROSTHETIC  TORQUE ARM\nHUNT  %s" % [health, roundi(stamina), str(WorldHistory.subject(HUNT_ID).get("status", "dormant")).to_upper()]
	if panel.visible:
		_refresh_archive()
	if field_interface.has_method("set_state"):
		field_interface.set_state({
			"health": health,
			"stamina": stamina,
			"rival_status": WorldHistory.subject(HUNT_ID).get("status", "dormant"),
			"menu_open": panel.visible or character_archive.visible,
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
	add_child(enemy)


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
