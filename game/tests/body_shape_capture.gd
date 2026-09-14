extends Node3D

## Greg: "make better shoulder neck realistic body models". The rig is generated
## from profiles in `body_mesh.gd`, so the only way to judge a profile change is
## to stand a clean body up and look at it from more than one angle — a front
## view hides everything wrong with the depth of a chest.

const HUMAN := preload("res://systems/baseline_human.gd")

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("10100f")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8f97a6")
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	# Raking key from one side: flat front light hides exactly the shoulder and
	# neck forms this change is about.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-26, 52, 0)
	key.light_energy = 2.2
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, -128, 0)
	fill.light_energy = 0.5
	fill.light_color = Color("9fb6cc")
	add_child(fill)

	var angles := [0.0, 0.9, 2.1]
	for index in angles.size():
		var rig: BaselineHuman = HUMAN.new()
		add_child(rig)
		rig.gore = false
		rig.build("shape_%d" % index, {"gore": false, "flesh": Color("8a7361")})
		rig.position = Vector3(-0.9 + 0.9 * float(index), 0, 0)
		rig.rotation.y = angles[index]

	await get_tree().process_frame
	await get_tree().process_frame

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.28, 2.5)
	cam.fov = 40.0
	add_child(cam)
	cam.look_at(Vector3(0, 1.12, 0), Vector3.UP)
	for _s in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/b10_body_shape.png"))

	# And one close on the shoulder/neck, which is the actual subject.
	cam.position = Vector3(0.42, 1.62, 0.92)
	cam.fov = 32.0
	cam.look_at(Vector3(0.0, 1.45, 0), Vector3.UP)
	for _s in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/b10_body_shoulder.png"))
	print("BODY_SHAPE_CAPTURE_RESULT saved")
	get_tree().quit(0)
