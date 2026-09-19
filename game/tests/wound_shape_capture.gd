extends Node3D

## AN6.5 visual proof. Damage, depth, radius and seed are held constant across
## all three openings. Only weapon class and impact angle move, so the capture
## cannot credit size or random rim noise for the silhouette change.

const MARKS := preload("res://systems/wound_marks.gd")


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	_build_stage()
	for _frame in 8:
		await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures/an6_5_weapon_angle_wounds.png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("AN6_5_WOUND_SHAPE_CAPTURE_RESULT saved" if error == OK else "AN6_5_WOUND_SHAPE_CAPTURE_RESULT failed=%d" % error)
	get_tree().quit(0 if error == OK else 1)


func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("090706")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8f7768")
	settings.ambient_light_energy = 0.72
	environment.environment = settings
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, -24.0, 0.0)
	light.light_color = Color("ffd1ad")
	light.light_energy = 2.4
	light.shadow_enabled = true
	add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.05, 3.8)
	camera.fov = 30.0
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var profiles := [
		{"label": "ROUND / STRAIGHT", "type": "ballistic", "travel": Vector3(0.0, 0.0, -1.0)},
		{"label": "ROUND / GRAZING", "type": "ballistic", "travel": Vector3(0.9, 0.0, -0.16)},
		{"label": "BLADE / STRAIGHT", "type": "cut", "travel": Vector3(0.0, 0.0, -1.0)},
	]
	for index in profiles.size():
		var profile: Dictionary = profiles[index]
		var x := (float(index) - 1.0) * 0.72
		var backing := MeshInstance3D.new()
		var backing_mesh := BoxMesh.new()
		backing_mesh.size = Vector3(0.56, 0.72, 0.07)
		backing.mesh = backing_mesh
		backing.position = Vector3(x, 0.05, -0.06)
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color("775445")
		skin.roughness = 0.78
		backing.material_override = skin
		add_child(backing)

		var wound: Dictionary = MARKS.make(Vector3.ZERO, Vector3(0.0, 0.0, 1.0), 40.0, str(profile.type), 2, profile.travel)
		wound["radius"] = 0.13
		wound["depth"] = 0.78
		wound["seed"] = 319
		var opening := MARKS.build(wound, Color("8b3730"))
		opening.position = Vector3(x, 0.08, 0.0)
		add_child(opening)

		var label := Label3D.new()
		label.text = str(profile.label)
		label.font_size = 34
		label.modulate = Color("dfc69d")
		label.outline_modulate = Color("160e0b")
		label.outline_size = 7
		label.position = Vector3(x, -0.46, 0.03)
		label.pixel_size = 0.0018
		add_child(label)
