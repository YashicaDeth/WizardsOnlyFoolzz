extends Node3D

const MOVE_SPEED := 8.0
const SPRINT_SPEED := 15.0
const ARENA_RADIUS := 26.0

var player_position := Vector3(0.0, 1.7, 11.0)
var yaw := 0.0
var pitch := -0.12
var third_person := true
var shimmer_time := 0.0

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var title: Label = $HUD/Margin/Title
@onready var subtitle: Label = $HUD/Margin/Subtitle
@onready var reticle: Label = $HUD/Reticle


func _ready() -> void:
	_build_environment()
	_build_arena()
	_build_monoliths()
	_build_fog_lights()
	_update_camera()
	title.text = "ALLUSIONS TOO GRANDEUR"
	subtitle.text = "THE VEIL GARDEN  ·  REMASTER PROTOTYPE\nWASD MOVE  ·  SHIFT RUN  ·  MOUSE LOOK  ·  F PERSPECTIVE"
	reticle.text = "+"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		third_person = not third_person
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0025
		pitch = clamp(pitch - event.relative.y * 0.0025, -0.85, 0.48)


func _process(delta: float) -> void:
	shimmer_time += delta
	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
	var right := Vector3(forward.z, 0.0, -forward.x)
	var direction := (right * move_input.x + forward * move_input.y).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else MOVE_SPEED
	player_position += direction * speed * delta
	player_position.x = clamp(player_position.x, -ARENA_RADIUS, ARENA_RADIUS)
	player_position.z = clamp(player_position.z, -ARENA_RADIUS, ARENA_RADIUS)
	_update_camera()
	for light in get_tree().get_nodes_in_group("shimmer_lights"):
		light.light_energy = 1.7 + sin(shimmer_time * 1.6 + light.position.x) * 0.45


func _update_camera() -> void:
	var look_direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	if third_person:
		camera.global_position = player_position - look_direction * 6.2 + Vector3.UP * 1.1
		camera.look_at(player_position + look_direction * 8.0 + Vector3.UP * 0.5)
		subtitle.text = "THE VEIL GARDEN  ·  THIRD PERSON\nWASD MOVE  ·  SHIFT RUN  ·  F PERSPECTIVE"
	else:
		camera.global_position = player_position
		camera.look_at(player_position + look_direction * 12.0)
		subtitle.text = "THE VEIL GARDEN  ·  FIRST PERSON\nWASD MOVE  ·  SHIFT RUN  ·  F PERSPECTIVE"


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("090518")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("34205c")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.25
	environment.glow_strength = 1.15
	environment.glow_bloom = 0.25
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.045
	environment.volumetric_fog_albedo = Color("48266d")
	$WorldEnvironment.environment = environment


func _build_arena() -> void:
	_add_mesh(CylinderMesh.new(), Vector3(0, -0.3, 0), Vector3(38, 0.4, 38), Color("141027"), 0.15)
	for radius in [8.0, 15.0, 23.0, 31.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius - 0.055
		ring.outer_radius = radius + 0.055
		_add_mesh(ring, Vector3(0, 0.02, 0), Vector3.ONE, Color("b64cff"), 3.5)
	for index in 72:
		var angle := TAU * float(index) / 72.0
		var radius := 33.0 + sin(index * 1.7) * 2.0
		var shard := PrismMesh.new()
		shard.left_to_right = 0.38
		shard.size = Vector3(0.45, 2.0 + float(index % 5), 0.35)
		_add_mesh(shard, Vector3(cos(angle) * radius, 1.2, sin(angle) * radius), Vector3.ONE, Color("39235f"), 0.9, Vector3(0, -angle, 0))


func _build_monoliths() -> void:
	for index in 12:
		var angle := TAU * float(index) / 12.0 + 0.18
		var radius := 19.0
		var height := 5.0 + float(index % 4) * 1.8
		var pillar := BoxMesh.new()
		pillar.size = Vector3(1.4, height, 1.4)
		_add_mesh(pillar, Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius), Vector3.ONE, Color("241342"), 0.3, Vector3(0.0, -angle, 0.0))
		var core := CylinderMesh.new()
		core.top_radius = 0.13
		core.bottom_radius = 0.13
		core.height = height * 0.72
		_add_mesh(core, Vector3(cos(angle) * radius, height * 0.52, sin(angle) * radius), Vector3.ONE, Color("ff4fcf") if index % 2 == 0 else Color("46e3ff"), 6.0)


func _build_fog_lights() -> void:
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var light := OmniLight3D.new()
		light.position = Vector3(cos(angle) * 13.0, 3.0, sin(angle) * 13.0)
		light.light_color = Color("e34cff") if index % 2 == 0 else Color("38cfff")
		light.light_energy = 2.0
		light.omni_range = 10.0
		light.add_to_group("shimmer_lights")
		add_child(light)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	moon.light_color = Color("a5a3ff")
	moon.light_energy = 1.2
	moon.shadow_enabled = true
	add_child(moon)


func _add_mesh(mesh: PrimitiveMesh, position_value: Vector3, scale_value: Vector3, color: Color, emission: float, rotation_value := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.5
	material.roughness = 0.34
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	mesh.material = material
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	instance.rotation = rotation_value
	add_child(instance)
