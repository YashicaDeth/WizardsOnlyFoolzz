extends Node3D

## Visual reference for the baseline rig. Headless runs prove the body has no
## errors and prove nothing about whether it reads as a body, so this stands
## three of them side by side for tests/capture_scene.tscn to photograph:
## intact, badly damaged with bone showing, and opened up under the X-ray.

func _ready() -> void:
	$WorldEnvironment.environment = WorldLook.environment("ossuary")

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -42, 0)
	key.light_color = Color("ffd9b0")
	key.light_energy = 2.1
	key.shadow_enabled = true
	add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(1.6, 1.6, 2.6)
	fill.light_color = Color("7fd4c6")
	fill.light_energy = 3.4
	fill.omni_range = 9.0
	add_child(fill)

	var ground := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(14, 0.4, 10)
	ground.mesh = slab
	ground.position = Vector3(0, -0.2, 0)
	ground.material_override = WorldLook.surface(Color("2a2030"), "dirt", 4)
	add_child(ground)

	_subject(Vector3(-2.1, 0, 0), "showcase_intact", 0)
	_subject(Vector3(-1.05, 0, 0), "showcase_wrecked", 1)
	# B3.2. Beside the beaten one on purpose. The claim is that a melting injury
	# and a beating are tellable apart at a glance, and a shot of a dosed body
	# on its own proves nothing about that — it has to stand next to the bruise.
	_subject(Vector3(0.0, 0, 0), "showcase_dosed", 3)
	# B4.1 / B4.2. Inked, pierced and grown into something, so the marks and the
	# mutations can be seen on a body rather than only counted in a test.
	_subject(Vector3(1.05, 0, 0), "showcase_marked", 4)
	_subject(Vector3(2.1, 0, 0), "showcase_xray", 2)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.05, 3.9)
	camera.rotation_degrees = Vector3(-4, 0, 0)
	camera.fov = 52.0
	camera.current = true
	add_child(camera)
	_photograph()


## B3.2. Photographs itself rather than waiting for `capture_scene.tscn`, so the
## four bodies can be compared from one run.
func _photograph() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	for _settle in 30:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/body_showcase.png" % out_dir)
	print("SHOWCASE_DONE")
	get_tree().quit()


func _subject(at: Vector3, id: String, mode: int) -> void:
	var body := BaselineHuman.new()
	add_child(body)
	body.position = at
	# Through the config: assigning `body.gore` here is overwritten by build().
	body.build(id, {"flesh": Color("7a6350"), "variation": mode * 3, "gore": false})
	if mode == 4:
		var look := HunterAppearance.new()
		body.add_child(look)
		look.configure(body, {"name": id, "ink": 0.95, "piercings": 0.9, "mutation": 0.85})
	match mode:
		1:
			# Enough damage to put bone through the skin on one side and take an
			# arm off entirely on the other.
			for i in 3:
				body.hit("left_leg", 22.0, 8.0, "blunt")
			for i in 4:
				body.hit("right_arm", 24.0, 8.0, "shear")
			for i in 2:
				body.hit("torso", 30.0, 8.0, "blunt")
		2:
			body.reveal_organs(true)
		3:
			# The same total damage as the beaten body, delivered as dose.
			for i in 3:
				body.hit("left_leg", 22.0, 0.0, "radiation")
			for i in 4:
				body.hit("right_arm", 24.0, 0.0, "radiation")
			for i in 2:
				body.hit("torso", 30.0, 0.0, "radiation")
