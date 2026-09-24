extends Node3D

## AN6.2 — organs are separate bodies behind the opening and fall out under
## physics when the cavity is breached.
##
## `_on_organ_ruptured()` used to spawn a `MeshInstance3D` nudged by hand every
## frame through `baseline_human.gd`'s own `_loose` array — gravity written out
## as a constant, no collision with the world, nothing GoreChunks or CARRY could
## find. `_spill_organ()` now hands the same mesh to a real `RigidBody3D`
## registered with `GoreChunks.register_organ()`, the same identity contract a
## severed limb already has.
##
## A passing assertion that the node exists does not settle whether it actually
## falls, so this follows the organ along its own real trajectory — the instant
## it leaves the body, mid-flight, and at rest on the floor it landed on — and
## prints its position and velocity at each point, so the photograph and the
## physics are the same run rather than two separate claims.

const HUMAN := preload("res://systems/baseline_human.gd")


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	_light()
	_floor()

	var body: BaselineHuman = HUMAN.new()
	add_child(body)
	body.build("organ_capture_subject", {})
	await get_tree().process_frame

	# Explicit organ, explicit damage, no ambiguity about what should rupture —
	# the same call `baseline_human_test.gd` already relies on to guarantee a
	# heart rupture in one hit.
	body.hit("torso", 90.0, 20.0, "cut", "heart", Vector3(0, 0, -1))

	var organ: RigidBody3D = null
	for piece in GoreChunks.from_subject("organ_capture_subject"):
		if bool(GoreChunks.identify(piece).get("whole_organ", false)):
			organ = piece as RigidBody3D
			break
	if organ == null:
		print("AN6_2_ORGAN_CAPTURE_RESULT no organ chunk produced")
		get_tree().quit(1)
		return

	var launch_position := organ.global_position

	for _s in 6:
		await get_tree().physics_frame
	var mid_position := organ.global_position
	var mid_velocity := organ.linear_velocity

	for _s in 120:
		await get_tree().physics_frame
	var rest_position := organ.global_position
	var rest_velocity := organ.linear_velocity

	# Framed after the organ has actually landed rather than at a position
	# guessed in advance — the impulse direction is randomised, so a fixed
	# camera could easily be looking at the wrong side of the body. The
	# highlight and the marker ring are children of the organ itself, not of a
	# remembered position, so they track it exactly regardless of where it
	# actually stopped — and stay legible against a floor it shares a palette
	# with.
	_camera(body.global_position, rest_position)
	var spot := OmniLight3D.new()
	spot.position = Vector3.UP * 0.3
	spot.light_color = Color("ffd9b0")
	spot.light_energy = 3.0
	spot.omni_range = 1.2
	organ.add_child(spot)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.09
	torus.outer_radius = 0.11
	ring.mesh = torus
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffe6a8")
	ring.material_override = glow
	ring.position = Vector3.UP * 0.02
	ring.rotation_degrees = Vector3(90, 0, 0)
	organ.add_child(ring)

	# Printed beside the image so the claim and the run are inseparable: a
	# scripted trajectory does not slow down on its own and does not stop
	# exactly at the floor it was never told about.
	print("launch position: ", launch_position)
	print("mid-flight: ", mid_position, " velocity ", mid_velocity)
	print("at rest: ", rest_position, " velocity ", rest_velocity)
	print("fell: ", snappedf(launch_position.y - rest_position.y, 0.001), "m")
	print("settled speed: ", snappedf(rest_velocity.length(), 0.001), "m/s")

	for _s in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://captures/an6_2_organ_physics.png"))

	print("AN6_2_ORGAN_CAPTURE_RESULT saved")
	get_tree().quit(0)


func _light() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("14100e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b8a898")
	e.ambient_light_energy = 1.1
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, 42, 0)
	key.light_energy = 1.4
	add_child(key)


## A real floor, not the flat "everything is at y=0" assumption a scripted
## trajectory could get away with — the organ has to actually collide with it.
func _floor() -> void:
	var ground := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.4, 10)
	col.shape = box
	col.position = Vector3(0, -0.2, 0)
	ground.add_child(col)
	add_child(ground)
	var plate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(10, 0.02, 10)
	plate.mesh = mesh
	plate.material_override = WorldLook.surface(Color("2a2620"), "rust", 4)
	add_child(plate)


## A wide, elevated three-quarter view rather than one framed tightly around a
## computed midpoint — the scatter impulse is randomised, so a tight frame
## aimed at today's landing spot is tomorrow's shot of a pair of legs with
## nothing else in it. Wide and pulled back covers the whole few-metre radius
## the organ can plausibly have rolled to, whichever direction that turned out
## to be, while still keeping both the body and the floor around it legible.
func _camera(body_at: Vector3, _organ_rest: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 58.0
	cam.position = body_at + Vector3(1.9, 1.85, 2.3)
	add_child(cam)
	cam.look_at(body_at + Vector3(0.0, 0.55, 0.0), Vector3.UP)
