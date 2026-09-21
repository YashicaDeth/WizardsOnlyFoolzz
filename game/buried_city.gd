extends Node3D

## THE LOWER WORKS — the first piece of the buried city between the intake
## facility and the underground heat.  It is deliberately authored from a
## seed vocabulary (arches, pipes, vaults and a landmark lift), not copied map
## geometry and not an infinite procedural maze.  Every visible branch has a
## gameplay role: take a fuse, open a shortcut, descend.

const OPENING := preload("res://systems/opening_director.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")
const RIVAL_TACTICS := preload("res://systems/rival_tactics.gd")

const ENTRY := Vector3(0, 1.0, 16.0)
const FUSE_AT := Vector3(11.2, 0.85, 1.8)
const SHORTCUT_AT := Vector3(-10.2, 0.0, -8.0)
const LIFT_AT := Vector3(0, 0.0, -38.0)
const EXIT_AT := Vector3(0, 0.0, -47.0)

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
var patrol_attack_cooldown := 0.0
var blood := 100.0


func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("ossuary")
	add_child(environment)
	_build_city_shell()
	_build_landmark_lift()
	_build_fuse_branch()
	_build_patrol()
	_build_player()
	_build_hud()
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
		light.position = Vector3(0, 8.7, z)
		light.light_color = Color("b64b2b") if bay % 3 else Color("718d5d")
		light.light_energy = 2.4
		light.omni_range = 10.0
		light.shadow_enabled = false
		add_child(light)
	# Wide side galleries make the world read as a city rather than a hallway.
	for side in [-1.0, 1.0]:
		_build_gallery(side, -2.0)
		_build_gallery(side, -24.0)


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
	eye.position = Vector3(0, 1.45, 0.25)
	eye.light_color = Color("d85131")
	eye.light_energy = 1.5
	eye.omni_range = 4.2
	patrol.add_child(eye)


func _slab(dimensions: Vector3, at: Vector3, kind: String, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = WorldLook.surface(color, kind, int(at.x * 37.0 + at.z * 23.0))
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
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.15, 0.95)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()


func _physics_process(delta: float) -> void:
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	player.velocity.x = move_toward(player.velocity.x, direction.x * 3.65, 17.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * 3.65, 17.0 * delta)
	player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	patrol_phase += delta
	_patrol_step(delta)
	_update_hud()


func _patrol_step(delta: float) -> void:
	if patrol == null or player == null:
		return
	patrol_attack_cooldown = maxf(0.0, patrol_attack_cooldown - delta)
	var difference := player.global_position - patrol.global_position
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
	if distance < 2.0 and patrol_attack_cooldown <= 0.0:
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
		WorldHistory.record_event("lower_works_shortcut_powered", {"location": "lower_works"})
		return
	if _flat_distance(EXIT_AT) <= 4.0 and fuse_taken:
		_record_pit_entry()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Interstitial.travel("res://underground_colosseum.tscn", "lower works elevator // the heat below is awake")


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
	var guard_state := "SENTINEL ENGAGED" if patrol_alert else "SENTINEL PATROL"
	status.text = "BLOOD %03d%%   PAIN 86   LOWER WORKS // %s" % [roundi(blood), guard_state]
	objective.text = "OBJECTIVE // " + ("REACH THE HEAT ELEVATOR" if fuse_taken else "FIND A LIFT FUSE")
	if not fuse_taken and _flat_distance(FUSE_AT) <= 2.4:
		prompt.text = "[E] TAKE LIFT FUSE"
	elif fuse_taken and not shortcut_open and _flat_distance(SHORTCUT_AT) <= 3.0:
		prompt.text = "[E] POWER SERVICE SHORTCUT"
	elif fuse_taken and _flat_distance(EXIT_AT) <= 4.0:
		prompt.text = "[E] DESCEND TO THE UNDERGROUND HEAT"
	else:
		prompt.text = "WASD MOVE   //   MOUSE LOOK   //   E INTERACT"
