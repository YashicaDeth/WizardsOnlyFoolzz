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

	_subject(Vector3(-1.05, 0, 0), "showcase_intact", 0)
	_subject(Vector3(0.0, 0, 0), "showcase_wrecked", 1)
	_subject(Vector3(1.05, 0, 0), "showcase_xray", 2)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.05, 2.25)
	camera.rotation_degrees = Vector3(-4, 0, 0)
	camera.fov = 52.0
	camera.current = true
	add_child(camera)


func _subject(at: Vector3, id: String, mode: int) -> void:
	var body := BaselineHuman.new()
	add_child(body)
	body.position = at
	# Through the config: assigning `body.gore` here is overwritten by build().
	body.build(id, {"flesh": Color("7a6350"), "variation": mode * 3, "gore": false})
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
