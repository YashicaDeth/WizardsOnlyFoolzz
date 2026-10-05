extends Node3D

## Windowed proof for car-71. Writes the requested entry/exit sequence and a
## torn-door entry under P:/GameDev/Temp/car-71-gta-door-entry.

var shots := "P:/GameDev/Temp/car-71-gta-door-entry"
var car: RigidBody3D
var damage: VehicleDamage
var driver: VehicleDriver
var body: CharacterBody3D
var eyes: Camera3D
var body_visual: BaselineHuman
var proof_camera: Camera3D


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	_build_stage()
	await get_tree().create_timer(0.6).timeout
	body.global_position = driver.standing_point(car, VehicleDriver.DOOR_LEFT)
	proof_camera.current = true
	_show_outside_body(true)
	await _shot("01_at_driver_handle")
	_show_outside_body(false)
	driver.begin_entry(car, VehicleDriver.DOOR_LEFT)
	await get_tree().create_timer(0.42).timeout
	proof_camera.current = true
	await _shot("02_door_open")
	await get_tree().create_timer(0.38).timeout
	proof_camera.current = true
	await _shot("03_body_sitting")
	await get_tree().create_timer(0.5).timeout
	await _shot("04a_cab_view_after_ease")
	proof_camera.current = true
	await _shot("04_door_closed_driver_seated")
	driver.get_out()
	await get_tree().create_timer(0.68).timeout
	proof_camera.current = true
	await _shot("05_exit_through_open_door")
	await get_tree().create_timer(0.54).timeout
	proof_camera.current = true
	_show_outside_body(true)
	await _shot("06_standing_beside_door")
	_show_outside_body(false)
	var part: Dictionary = damage.door_part(VehicleDriver.DOOR_LEFT)
	damage._detach("DoorLeft", -car.global_basis.x, (part.node as Node3D).global_position)
	body.global_position = driver.standing_point(car, VehicleDriver.DOOR_LEFT)
	driver.begin_entry(car, VehicleDriver.DOOR_LEFT)
	await get_tree().create_timer(0.58).timeout
	proof_camera.current = true
	await _shot("07_torn_door_climb_in")
	await get_tree().create_timer(0.84).timeout
	proof_camera.current = true
	await _shot("08_torn_door_seated")
	get_tree().quit(0)


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("15171a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c1b5")
	environment.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.75, -0.55, 0)
	sun.light_color = Color("ffd0a0")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	ground.position.y = -0.5
	add_child(ground)
	var mesh := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(24, 1, 24)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("35332f")
	floor_mat.roughness = 0.9
	floor_mesh.material = floor_mat
	mesh.mesh = floor_mesh
	ground.add_child(mesh)
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = floor_mesh.size
	collision.shape = floor_shape
	ground.add_child(collision)
	car = VehicleDamage.make("sedan", 71, false)
	add_child(car)
	car.teleport(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)))
	damage = car.get_node("Damage") as VehicleDamage
	body = CharacterBody3D.new()
	add_child(body)
	eyes = Camera3D.new()
	eyes.position.y = 0.77
	body.add_child(eyes)
	body_visual = BaselineHuman.new()
	body_visual.name = "PlayerBody"
	add_child(body_visual)
	body_visual.build("car_entry_player", {"gore": false, "blood": 4800.0, "rigged": true})
	body_visual.visible = false
	driver = VehicleDriver.new()
	add_child(driver)
	driver.bind_walker(body, eyes, body_visual)
	proof_camera = Camera3D.new()
	proof_camera.fov = 55.0
	proof_camera.cull_mask &= ~(1 << (VehicleInterior.CAB_LAYER - 1))
	add_child(proof_camera)
	proof_camera.global_position = Vector3(-5.5, 2.4, 3.4)
	proof_camera.look_at(Vector3(-0.4, 0.7, 0.0))


## Play keeps the walking body hidden (first person); the proof shows where
## it stands before entry and after the exit.
func _show_outside_body(show: bool) -> void:
	body_visual.visible = show
	if show:
		body_visual.global_transform = body.global_transform
		body_visual.global_position -= Vector3.UP * 0.85
		body_visual.look_at(body_visual.global_position + (body_visual.global_position - Vector3(0, body_visual.global_position.y, 0)).normalized() * -1.0, Vector3.UP)


func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("CAR_ENTRY_CAPTURE %s: headless, nothing rendered" % label)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [shots, label]
	image.save_png(path)
	print("CAR_ENTRY_CAPTURE ", path)
