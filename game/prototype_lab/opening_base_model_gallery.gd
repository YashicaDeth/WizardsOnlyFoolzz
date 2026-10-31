extends Node3D

const KIT := preload("res://systems/opening_base_model_kit.gd")

var shot_path := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			shot_path = argument.trim_prefix("--shot=")

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080606")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6a4035")
	environment.ambient_light_energy = 1.05
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var kit := KIT.new()
	add_child(kit)
	kit.build_vat_crown(Vector3(-5.8, 0, 0))
	kit.build_ritual_plinth(Vector3(-5.8, 0, 0))
	var spine := kit.build_cable_spine(Vector3(0, 3.4, 0), 10.0)
	spine.rotation.y = PI * 0.5
	kit.build_observation_cluster(Vector3(0, 0, 0), 2.0)
	for tier in 7:
		kit.build_pyramid_tier(Vector3(5.0, 0.35 + float(tier) * 0.34, 0), 4.4 - float(tier) * 0.48, tier)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(26.0, 14.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("17110f")
	floor_material.roughness = 0.9
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	floor.position.y = -0.09
	add_child(floor)

	var red := OmniLight3D.new()
	red.position = Vector3(-5.8, 2.4, 1.2)
	red.light_color = Color("cf241b")
	red.light_energy = 7.0
	red.omni_range = 8.0
	add_child(red)
	var green := OmniLight3D.new()
	green.position = Vector3(0, 2.0, 1.5)
	green.light_color = Color("7eaa68")
	green.light_energy = 3.2
	green.omni_range = 6.0
	add_child(green)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-42, -28, 0)
	fill.light_color = Color("d6c5a0")
	fill.light_energy = 2.15
	add_child(fill)
	var front := OmniLight3D.new()
	front.position = Vector3(0, 4.5, 7.5)
	front.light_color = Color("d8b893")
	front.light_energy = 6.5
	front.omni_range = 18.0
	add_child(front)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 3.9, 12.8)
	camera.look_at_from_position(camera.position, Vector3(0, 1.75, 0), Vector3.UP)
	camera.fov = 62.0
	add_child(camera)

	if not shot_path.is_empty():
		_capture()


func _capture() -> void:
	for _frame in 12:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(shot_path)
	print("OPENING_BASE_MODEL_GALLERY_SHOT ", shot_path)
	get_tree().quit(0)
