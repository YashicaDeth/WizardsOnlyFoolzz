extends Node3D

## AN6.1 visual proof: the same wound, once as the old closed crater and once
## opened onto the gut mesh from a real BaselineHuman. Radius, depth, seed,
## surface and lighting are identical, so the only visual difference is the
## separate body behind the inner rim.

const HUMAN := preload("res://systems/baseline_human.gd")
const MARKS := preload("res://systems/wound_marks.gd")


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	_build_stage()
	for _frame in 8:
		await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures/an6_1_cavity_contents.png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("AN6_1_CAVITY_CAPTURE_RESULT saved" if error == OK else "AN6_1_CAVITY_CAPTURE_RESULT failed=%d" % error)
	get_tree().quit(0 if error == OK else 1)


func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("080605")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8f7768")
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	light.light_color = Color("ffd1ad")
	light.light_energy = 2.7
	light.shadow_enabled = true
	add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.04, 3.6)
	camera.fov = 28.0
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var donor: BaselineHuman = HUMAN.new()
	add_child(donor)
	donor.build("cavity_capture_donor", {})
	var gut_mesh := (donor.organ_parts["gut"] as MeshInstance3D).mesh
	donor.visible = false

	for index in 2:
		var x := -0.48 if index == 0 else 0.48
		var backing := MeshInstance3D.new()
		var backing_mesh := BoxMesh.new()
		backing_mesh.size = Vector3(0.72, 0.82, 0.08)
		backing.mesh = backing_mesh
		backing.position = Vector3(x, 0.03, -0.07)
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color("775445")
		skin.roughness = 0.78
		backing.material_override = skin
		add_child(backing)

		var wound := MARKS.make(Vector3.ZERO, Vector3(0.0, 0.0, 1.0), 40.0, "ballistic", GoreChunks.Layer.ORGAN, Vector3(0.0, 0.0, -1.0))
		wound["radius"] = 0.18
		wound["depth"] = 0.9
		wound["seed"] = 611
		var opening := MARKS.build(wound, Color("6d100e"), gut_mesh if index == 1 else null)
		opening.position = Vector3(x, 0.08, 0.0)
		add_child(opening)

		var label := Label3D.new()
		label.text = "CLOSED CRATER" if index == 0 else "ORGAN BEHIND OPENING"
		label.font_size = 32
		label.modulate = Color("dfc69d")
		label.outline_modulate = Color("160e0b")
		label.outline_size = 7
		label.position = Vector3(x, -0.50, 0.03)
		label.pixel_size = 0.0018
		add_child(label)
