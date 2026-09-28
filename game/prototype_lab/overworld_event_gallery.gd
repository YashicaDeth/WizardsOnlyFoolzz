extends Node3D

## Plays the overworld random events on a patch of open ground with a ruin.
##
## Interactive: 1 the splinter monks, 2 the crazed driver, 3 a random event
## from the generator, Y / N answer a trade. Mouse-free; the event camera
## frames everything.
##
## `-- --out=DIR` captures a fixed sequence and quits:
##   monks_portrait.png  three monks by daylight, close (the habit, hood, seals)
##   monks_hood.png      the eldest's hood and schema, closer
##   spirit_vision.png   a spirit vision alone at dusk
##   monks_vision.png    the monks' cutscene at its vision beat (letterbox, line)
##   monks_trade.png     the trade offer it ends in
##   driver_charge.png   the crazed driver's skiff coming at the player
##   driver_crazy.png    the skiff spinning out
##   driver_fight.png    the driver out of the cab, a mini-boss

const Generator := preload("res://systems/event_generator.gd")

var director: OverworldEventDirector
var player_camera: Camera3D
var player := Vector3.ZERO
var out_dir := ""
var _sun: DirectionalLight3D
var _env: Environment


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	_build_world()
	player_camera = Camera3D.new()
	player_camera.name = "PlayerCamera"
	add_child(player_camera)
	player_camera.global_position = player + Vector3(0, 1.7, 0)
	player_camera.look_at(player + Vector3(0, 1.5, -10), Vector3.UP)
	player_camera.make_current()
	director = OverworldEventDirector.new()
	director.name = "OverworldEvents"
	add_child(director)
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _capture_sequence()
		get_tree().quit()


func _physics_process(delta: float) -> void:
	if out_dir.is_empty():
		director.tick(delta, player)


func _unhandled_input(input: InputEvent) -> void:
	var key := input as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_restart()
			director.play_signature("splinter_monks", player)
		KEY_2:
			_restart()
			director.play_signature("crazed_driver", player)
		KEY_3:
			_restart()
			director.play(Generator.pick(Time.get_ticks_usec()), player)


func _restart() -> void:
	director.clear_stage()
	director.state = "idle"
	player_camera.make_current()


func _capture_sequence() -> void:
	await get_tree().process_frame
	# 1. Monks by daylight, posed for a portrait.
	_set_light(false)
	var portrait := Node3D.new()
	add_child(portrait)
	var monks: Array[BaselineHuman] = []
	for index in 3:
		var holder := Node3D.new()
		portrait.add_child(holder)
		holder.global_position = Vector3(-1.1 + index * 1.1, 0, -4.0 - (0.4 if index == 1 else 0.0))
		holder.rotation.y = PI + (index - 1) * -0.25
		monks.append(SplinterMonkLook.build_monk("gallery_monk_%d" % index, 11 + index * 5, index == 1, holder))
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.global_position = Vector3(0, 1.55, -0.6)
	cam.look_at(Vector3(0, 1.15, -4.2), Vector3.UP)
	cam.make_current()
	await _shoot("monks_portrait", 6)
	cam.fov = 26
	cam.global_position = Vector3(0.35, 1.7, -2.6)
	cam.look_at(Vector3(0, 1.45, -4.4), Vector3.UP)
	await _shoot("monks_hood", 3)
	portrait.queue_free()

	# 2. A spirit vision alone, at dusk.
	_set_light(true)
	var vision := SpiritVision.new()
	add_child(vision)
	vision.global_position = Vector3(0, 0, -6)
	vision.set_presence_now(1.0)
	cam.fov = 50
	cam.global_position = Vector3(0.6, 1.0, -0.8)
	cam.look_at(Vector3(0, 1.9, -6), Vector3.UP)
	await _shoot("spirit_vision", 20)
	vision.queue_free()
	cam.queue_free()
	player_camera.make_current()

	# 3. The monks' event, at its vision beat and at its trade.
	_set_light(true)
	director.play_signature("splinter_monks", player)
	var guard := 0
	while guard < 600 and not (str(director.current_beat().get("shot", "")) == "vision" and director.beat_time > 1.6 and director.beat_index == 3):
		director.tick(1.0 / 30.0, player)
		guard += 1
		await get_tree().process_frame
	await _shoot("monks_vision", 2)
	guard = 0
	while director.state == "cutscene" and guard < 900:
		director.tick(1.0 / 30.0, player)
		guard += 1
		await get_tree().process_frame
	# The trade is seen from where the player stands.
	player_camera.global_position = player + Vector3(0.8, 1.7, 0.6)
	player_camera.look_at(director.origin + Vector3(0, 1.4, 0), Vector3.UP)
	await _shoot("monks_trade", 4)
	director.accept_trade()
	director.clear_stage()
	director.state = "idle"
	player_camera.make_current()

	# 4. The crazed driver, run on physics frames.
	_set_light(false)
	player_camera.global_position = player + Vector3(0, 1.7, 0)
	player_camera.look_at(player + Vector3(0, 1.5, -10), Vector3.UP)
	director.play_signature("crazed_driver", player)
	var shots := {"driver_charge": 3.15, "driver_crazy": 8.6}
	var t := 0.0
	while director.state == "cutscene" and t < 20.0:
		await get_tree().physics_frame
		director.tick(1.0 / 60.0, player)
		t += 1.0 / 60.0
		for shot_name in shots.keys():
			if t >= float(shots[shot_name]):
				shots.erase(shot_name)
				await _shoot(shot_name, 0)
	# After the hand-off: frame the driver out of the cab from the player.
	if director.boss_rig != null:
		player_camera.global_position = player + Vector3(0, 1.7, 0)
		var at := director.boss_rig.global_position
		var toward := (at - player_camera.global_position)
		toward.y = 0
		player_camera.global_position = at - toward.normalized() * 6.0 + Vector3(0, 1.8, 0)
		player_camera.look_at(at + Vector3(0, 1.2, 0), Vector3.UP)
	await _shoot("driver_fight", 6)
	director.clear_stage()
	director.state = "idle"
	player_camera.make_current()

	# 5. One of the generated (placeholder) events, mid-cutscene.
	var generated := Generator.pick(90210, {"exclude_staging": ["vehicle_ram", "monk_rite"]})
	print("OVERWORLD_EVENT_GALLERY generated ", generated.id)
	player_camera.global_position = player + Vector3(0, 1.7, 0)
	player_camera.look_at(player + Vector3(0, 1.5, -10), Vector3.UP)
	director.play(generated, player)
	guard = 0
	while director.state == "cutscene" and director.beat_index < 1 and guard < 400:
		director.tick(1.0 / 30.0, player)
		guard += 1
		await get_tree().process_frame
	for i in 30:
		director.tick(1.0 / 30.0, player)
		await get_tree().process_frame
	await _shoot("generated_event", 0)
	print("OVERWORLD_EVENT_GALLERY events=%d history_resolved=%d" % [Generator.count(), WorldHistory.event_count("overworld_event_resolved")])


func _shoot(shot_name: String, settle_frames: int) -> void:
	for i in settle_frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	print("OVERWORLD_EVENT_GALLERY shot ", path)


func _set_light(dusk: bool) -> void:
	_sun.light_energy = 0.35 if dusk else 1.25
	_sun.light_color = Color("c07a5a") if dusk else Color("f1e3cc")
	_env.background_color = Color("2a1f25") if dusk else Color("8d8676")
	_env.ambient_light_energy = 0.35 if dusk else 0.75
	_env.fog_light_color = _env.background_color


func _build_world() -> void:
	var world := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("7d766a")
	_env.fog_enabled = true
	_env.fog_density = 0.012
	_env.glow_enabled = true
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = _env
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-38, 35, 0)
	_sun.shadow_enabled = true
	add_child(_sun)
	_set_light(false)
	var ground := StaticBody3D.new()
	add_child(ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	mesh.mesh = plane
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("4a4034")
	earth.roughness = 1.0
	mesh.material_override = earth
	ground.add_child(mesh)
	# A ruined shrine behind where the monks stand: broken piers and a lintel.
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("6d665b")
	stone.roughness = 0.95
	for spec in [[Vector3(-4.5, 1.6, -17), Vector3(1.1, 3.2, 1.1)], [Vector3(4.2, 1.1, -17.5), Vector3(1.1, 2.2, 1.1)], [Vector3(-1.5, 3.3, -17.2), Vector3(5.5, 0.6, 1.0)], [Vector3(6.5, 0.4, -14), Vector3(2.0, 0.8, 1.3)]]:
		var block := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = spec[1]
		block.mesh = cube
		block.material_override = stone
		block.position = spec[0]
		add_child(block)
