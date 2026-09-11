extends Node3D

const ARENA_LIMIT := 29.0
const MAX_SPEED := 24.0
const IMPACT_SPEED := 9.5
const RIVAL_ID := "mara_voss"
const SCRAP_SKIFF := preload("res://art/scrap_skiff.glb")
const BONE_YARD_ENVIRONMENT := preload("res://art/bone_yard_environment.glb")
const DERBY_AUDIO := preload("res://systems/procedural_derby_audio.gd")
const VEHICLE := preload("res://systems/arcade_vehicle.gd")
const AI_DRIVER := preload("res://systems/derby_ai_driver.gd")

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
var disabled_count := 0
var round_state := "countdown"
var countdown := 3.0
var authored_collision_count := 0
var derby_audio: Node

@onready var camera: Camera3D = $Camera3D
@onready var status: Label = $HUD/Status
@onready var score_label: Label = $HUD/ScorePanel/Score
@onready var mode_label: Label = $HUD/Mode
@onready var rival_label: Label = $HUD/RivalPanel/Rival
@onready var index_panel: PanelContainer = $HUD/WorldIndex
@onready var index_text: Label = $HUD/WorldIndex/Margin/IndexText
@onready var dynamic_interface: Control = $HUD/DynamicInterface


func _ready() -> void:
	_build_world()
	_build_boat()
	_spawn_targets()
	_spawn_crowd()
	derby_audio = DERBY_AUDIO.new()
	derby_audio.name = "DerbyAudio"
	add_child(derby_audio)
	WorldHistory.register_subject(RIVAL_ID, {
		"name": "Mara Voss", "role": "Bone Yard Captain", "faction": "Ashline Wreckers",
		"elo": 1180, "grudge": 0, "injury": "none", "status": "active", "memory": "Watching the derby",
	})
	WorldHistory.record_event("derby_session_started", {
		"venue": "rift_derby_quarry",
		"vehicle": "rift_skiff",
		"target_count": targets.size(),
	})
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset_round()
		elif event.keycode == KEY_V:
			viscera_fx = not viscera_fx
		elif event.keycode == KEY_I:
			index_open = not index_open
			index_panel.visible = index_open
			if index_open:
				_refresh_world_index()
		elif event.keycode == KEY_E:
			WorldHistory.record_event("player_left_derby_vehicle", {"venue": "rift_derby_quarry", "destination": "bone_yard_outskirts"})
			get_tree().change_scene_to_file("res://bone_yard_hunt.tscn")
		elif event.keycode == KEY_ENTER and round_state in ["won", "lost"]:
			WorldHistory.record_event("derby_result_accepted", {"result": round_state, "score": score, "disabled": disabled_count})
			get_tree().change_scene_to_file("res://bone_yard_hunt.tscn")


func _physics_process(delta: float) -> void:
	boat.enabled = round_state == "active" and not index_open
	if index_open:
		return
	if round_state == "countdown":
		countdown -= delta
		mode_label.visible = true
		mode_label.text = "DISABLE EIGHT WRECKERS // %d" % maxi(1, ceili(countdown))
		if countdown <= 0.0:
			round_state = "active"
		return
	if round_state != "active":
		_update_debris(delta)
		_update_hud()
		return
	_update_boat(delta)
	_update_debris(delta)
	_update_wreckers(delta)
	_update_crowd(delta)
	_update_camera(delta)
	_update_respawns(delta)
	_update_hud()


func _build_world() -> void:
	$WorldEnvironment.environment = WorldLook.environment("bone_yard")
	var authored_environment := BONE_YARD_ENVIRONMENT.instantiate()
	authored_environment.name = "AuthoredBoneYard"
	authored_environment.position.y = -0.12
	add_child(authored_environment)
	_add_authored_environment_collision(authored_environment)
	var floor := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(76, 1.0, 76)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.8
	floor.add_child(floor_collision)
	add_child(floor)
	# Floodlights are pools of light in a dim pit, not a uniform wash. Two of the
	# eight cast shadows: enough to anchor the wrecks without eight shadow maps.
	for index in 8:
		var light := OmniLight3D.new()
		var angle := TAU * index / 8.0
		light.position = Vector3(cos(angle) * 18.0, 7.5, sin(angle) * 18.0)
		light.light_color = Color("ff8a3c") if index % 2 == 0 else Color("cdb389")
		light.light_energy = 2.6
		light.omni_range = 21.0
		light.omni_attenuation = 1.6
		light.shadow_enabled = index % 4 == 0
		add_child(light)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -34, 0)
	sun.light_color = Color("ffcf9e")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_boat() -> void:
	boat = VEHICLE.new()
	boat.name = "MercyCountyWrecker"
	boat.position = Vector3(0, 0.75, 12)
	add_child(boat)
	boat.impact.connect(_on_vehicle_impact)
	var authored_skiff := SCRAP_SKIFF.instantiate()
	authored_skiff.name = "AuthoredScrapSkiff"
	authored_skiff.scale = Vector3(1.15, 1.15, 1.15)
	boat.add_child(authored_skiff)


func _spawn_targets() -> void:
	for index in 12:
		_create_wrecker(index)


func _create_wrecker(index: int) -> void:
	var angle := TAU * index / 12.0 + 0.23
	var lane := 13.5 if index % 2 == 0 else 17.0
	# AI wreckers run the same chassis as the player. They are steered, never
	# teleported, so a ram leaves them spinning instead of snapping back on the
	# following frame.
	var target := VEHICLE.new()
	target.name = "MaraVoss_Wrecker" if index == 0 else "ScrapWrecker_%02d" % index
	target.position = Vector3(cos(angle) * lane * 1.35, 0.8, sin(angle) * lane * 0.78)
	target.set_meta("integrity", 160 if index == 0 else 100)
	target.set_meta("is_rival", index == 0)
	target.set_meta("hit_ready_msec", 0)
	target.set_meta("spawn_index", index)
	add_child(target)
	var ai_driver := AI_DRIVER.new()
	ai_driver.name = "AIDriver"
	target.add_child(ai_driver)
	ai_driver.configure(target, index + 1)
	var authored_skiff := SCRAP_SKIFF.instantiate()
	authored_skiff.name = "ScrapVehicleShell"
	authored_skiff.scale = Vector3(1.05, 1.05, 1.05)
	target.add_child(authored_skiff)
	if index % 3 == 1:
		authored_skiff.rotation.y = PI
	if index == 0:
		authored_skiff.scale *= 1.12
	_add_vehicle_damage_parts(target, index)
	_add_driver_rig(target, index)
	targets.append(target)


func _update_boat(delta: float) -> void:
	var throttle := Input.get_axis("move_back", "move_forward")
	var steering := Input.get_axis("move_left", "move_right")
	boat.throttle = throttle
	boat.steering = steering
	speed = boat.signed_speed
	boat_velocity = boat.linear_velocity
	if boat.position.y < -10.0:
		boat.recover(Vector3(0, 1.2, 12))
	if derby_audio != null:
		derby_audio.call("update_engine", speed, throttle)


func _update_wreckers(delta: float) -> void:
	for target in targets:
		if not is_instance_valid(target):
			continue
		var ai_driver := target.get_node_or_null("AIDriver")
		if ai_driver == null:
			continue
		ai_driver.tick(delta, _wrecker_target_position(target), round_state == "active")


func _wrecker_target_position(wrecker: Node3D) -> Vector3:
	# Most of the pit hunts the player; the rest pick fights with each other so
	# the arena keeps moving even when the player hangs back.
	if int(wrecker.get_meta("spawn_index", 0)) % 3 != 0:
		return boat.global_position
	var closest := boat.global_position
	var closest_distance := 99999.0
	for other in targets:
		if other == wrecker or not is_instance_valid(other):
			continue
		var distance: float = wrecker.global_position.distance_to(other.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = other.global_position
	return closest


func _on_vehicle_impact(other: Node, closing_speed: float) -> void:
	if round_state != "active" or not is_instance_valid(other):
		return
	if targets.has(other):
		_damage_target(other, closing_speed)
	elif closing_speed > 7.0:
		integrity = maxi(0, integrity - roundi(closing_speed * 0.3))
		derby_audio.play_impact(clampf(closing_speed / 24.0, 0.0, 1.0))
		if integrity <= 0:
			_finish_round("lost")


func _damage_target(target: Node3D, collision_speed: float = 0.0) -> void:
	if round_state != "active":
		return
	var now: int = Time.get_ticks_msec()
	if now < int(target.get_meta("hit_ready_msec", 0)):
		return
	target.set_meta("hit_ready_msec", now + 650)
	var impact_energy: int = roundi(collision_speed * 10.0)
	var damage: int = clampi(roundi(collision_speed * 1.25), 5, 45)
	var target_integrity: int = maxi(0, int(target.get_meta("integrity", 100)) - damage)
	target.set_meta("integrity", target_integrity)
	score += damage * 5
	integrity = max(0, integrity - roundi(collision_speed * 0.24))
	var impact_direction := (target.global_position - boat.global_position).normalized()
	_update_wrecker_damage_visual(target, target_integrity)
	_update_detachable_parts(target, target_integrity, impact_direction)
	_injure_driver(target, damage, impact_direction)
	crowd_reaction = clampf(crowd_reaction + damage / 22.0, 0.0, 2.0)
	if derby_audio != null:
		derby_audio.call("play_impact", clampf(float(damage) / 34.0, 0.0, 1.0))
	if dynamic_interface.has_method("announce_impact"):
		dynamic_interface.announce_impact(damage, bool(target.get_meta("is_rival", false)))
	WorldHistory.record_event("derby_vehicle_hit", {
		"venue": "rift_derby_quarry", "target_id": target.name, "damage": damage,
		"target_integrity": target_integrity, "impact_energy": impact_energy,
	})
	if bool(target.get_meta("is_rival", false)):
		var current := WorldHistory.subject(RIVAL_ID)
		var grudge := mini(100, int(current.get("grudge", 0)) + 8)
		var injury := "bruised ribs" if target_integrity > 0 else "fractured left arm"
		WorldHistory.update_subject(RIVAL_ID, {
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
		chunk.global_position = target.global_position + Vector3(0, 0.8, 0)
		add_child(chunk)
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


func _update_wrecker_damage_visual(target: Node3D, target_integrity: int) -> void:
	var shell := target.get_node_or_null("ScrapVehicleShell") as Node3D
	if shell == null:
		return
	var crush := clampf(float(100 - target_integrity) / 100.0, 0.0, 0.65)
	shell.scale = Vector3(1.05 + crush * 0.08, 1.05 - crush * 0.16, 1.05 - crush * 0.06)
	shell.rotation.z = sin(float(target_integrity) * 0.31) * crush * 0.08


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
		piece.velocity.y -= 12.0 * delta
		piece.node.position += piece.velocity * delta
		piece.node.rotate(Vector3(1, 0.7, 0.3).normalized(), delta * 7.0)
		piece.life -= delta
		if piece.life <= 0.0:
			piece.node.queue_free()
			debris.erase(piece)


func _update_camera(delta: float) -> void:
	var forward := -boat.global_transform.basis.z
	var desired := boat.global_position - forward * 10.5 + Vector3.UP * 6.3
	camera.global_position = camera.global_position.lerp(desired, min(delta * 4.5, 1.0))
	camera.look_at(boat.global_position + forward * 5.0 + Vector3.UP * 0.5)


func _update_hud() -> void:
	status.text = "BONE YARD DERBY  //  %s\nWASD DRIVE  ·  R RESET  ·  V VISCERA FX  ·  I WORLD INDEX  ·  E LEAVE VEHICLE" % round_state.to_upper()
	score_label.text = "IMPACT SCORE  %05d\nHULL INTEGRITY  %03d%%\nACTIVE WRECKERS  %02d\nWORLD MEMORY  %03d" % [score, integrity, targets.size(), WorldHistory.event_count()]
	mode_label.text = ("VICTORY — ENTER: EXIT INTO ASHBLOOM" if round_state == "won" else "WRECKED — ENTER: CRAWL INTO ASHBLOOM" if round_state == "lost" else "VISCERA FX: %s  ·  RUST / OIL / BLOOD" % ("ON" if viscera_fx else "OFF"))
	var rival := WorldHistory.subject(RIVAL_ID)
	rival_label.text = "HUNT ARC  //  MARA VOSS\n%s  ·  GRUDGE %03d  ·  ELO %04d\n[I] WORLD INDEX" % [str(rival.get("status", "active")).to_upper(), int(rival.get("grudge", 0)), int(rival.get("elo", 1180))]
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
		})


func _refresh_world_index() -> void:
	var rival := WorldHistory.subject(RIVAL_ID)
	var memories := WorldHistory.recent_events(5)
	var lines: Array[String] = [
		"WORLD INDEX  //  BONE YARD FILE", "",
		"MARA VOSS - %s" % str(rival.get("role", "unknown")).to_upper(),
		"Faction: %s" % str(rival.get("faction", "unknown")),
		"Condition: %s" % str(rival.get("injury", "unknown")),
		"Memory: %s" % str(rival.get("memory", "no confirmed contact")), "", "RECENT HISTORY:"
	]
	for entry in memories:
		lines.append("- %s" % str(entry.get("type", "unknown event")).replace("_", " "))
	index_text.text = "\n".join(lines)


func _reset_round() -> void:
	for target in targets:
		if is_instance_valid(target):
			target.queue_free()
	targets.clear()
	respawn_queue.clear()
	disabled_count = 0
	round_state = "active"
	countdown = 3.0
	round_state = "countdown"
	score = 0
	integrity = 100
	speed = 0.0
	boat_velocity = Vector3.ZERO
	boat.position = Vector3(0, 0.75, 12)
	boat.recover(Vector3(0, 1.2, 12))
	_spawn_targets()
	WorldHistory.record_event("derby_round_reset", {"venue": "rift_derby_quarry"})


func _finish_round(result: String) -> void:
	if round_state != "active":
		return
	round_state = result
	mode_label.visible = true
	speed = 0.0
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


func _add_vehicle_damage_parts(target: RigidBody3D, index: int) -> void:
	var damage_root := Node3D.new()
	damage_root.name = "DamageParts"
	target.add_child(damage_root)
	var color := Color("286b68") if index % 2 == 0 else Color("743021")
	_add_damage_part(damage_root, "DoorLeft", Vector3(-1.38, 0.25, 0.15), Vector3(0.16, 0.82, 1.65), color)
	_add_damage_part(damage_root, "DoorRight", Vector3(1.38, 0.25, 0.15), Vector3(0.16, 0.82, 1.65), color)
	_add_damage_part(damage_root, "Hood", Vector3(0, 0.7, -1.55), Vector3(2.25, 0.16, 1.2), color.darkened(0.12))
	_add_damage_part(damage_root, "BumperFront", Vector3(0, 0.0, -2.48), Vector3(2.65, 0.22, 0.25), Color("684a34"))
	_add_damage_part(damage_root, "BumperRear", Vector3(0, 0.0, 2.48), Vector3(2.65, 0.22, 0.25), Color("684a34"))
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
	var driver := Node3D.new()
	driver.name = "DriverRig"
	driver.position = Vector3(0, 0.25, 0.3)
	target.add_child(driver)
	_add_mesh_to(driver, CapsuleMesh.new(), Vector3(0, 0.55, 0), Color("8c6d50"), 0.0, Vector3.ZERO, "DriverBody")
	for zone_data in [{"name": "HeadHitbox", "position": Vector3(0, 1.45, 0), "size": Vector3(0.48, 0.48, 0.48), "zone": "head"}, {"name": "TorsoHitbox", "position": Vector3(0, 0.72, 0), "size": Vector3(0.7, 0.95, 0.45), "zone": "torso"}, {"name": "LegHitbox", "position": Vector3(0, 0.05, -0.2), "size": Vector3(0.65, 0.6, 0.5), "zone": "legs"}]:
		var area := Area3D.new()
		area.name = str(zone_data.name)
		area.position = zone_data.position
		area.set_meta("body_zone", zone_data.zone)
		driver.add_child(area)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = zone_data.size
		shape_node.shape = shape
		area.add_child(shape_node)
	target.set_meta("driver_health", 100)
	target.set_meta("driver_subject", RIVAL_ID if index == 0 else "derby_driver_%02d" % index)


func _injure_driver(target: Node3D, damage: int, impact_direction: Vector3) -> void:
	var driver_health := maxi(0, int(target.get_meta("driver_health", 100)) - roundi(damage * 0.55))
	target.set_meta("driver_health", driver_health)
	var zone := "torso" if absf(impact_direction.z) > absf(impact_direction.x) else "head"
	WorldHistory.record_event("derby_driver_injured", {"subject_id": target.get_meta("driver_subject", "unknown"), "zone": zone, "damage": damage, "health": driver_health})
	if viscera_fx and damage >= 24:
		var driver := target.get_node_or_null("DriverRig") as Node3D
		if driver != null:
			for index in 4:
				var droplet := MeshInstance3D.new()
				var mesh := SphereMesh.new()
				mesh.radius = 0.05 + index * 0.012
				mesh.height = mesh.radius * 2.0
				mesh.material = _material(Color("701310"), 0.0, "flesh", index + 3)
				droplet.mesh = mesh
				droplet.position = driver.position + Vector3(randf_range(-0.4, 0.4), 1.0 + randf() * 0.5, randf_range(-0.3, 0.3))
				target.add_child(droplet)


func _spawn_crowd() -> void:
	for index in 64:
		var spectator := Node3D.new()
		spectator.name = "CrowdSilhouette_%02d" % index
		var side := -1.0 if index % 2 == 0 else 1.0
		var row := float((index / 2) % 4)
		spectator.position = Vector3(-30.0 + float(index % 32) * 1.95, 2.0 + row * 0.85, side * (30.0 + row * 1.2))
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
