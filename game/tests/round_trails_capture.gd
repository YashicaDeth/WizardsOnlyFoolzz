extends Node3D

## AN6.7 evidence: a body with three rounds in it and the X-ray up, written to a
## PNG so the trails are looked at rather than only asserted.
##
## Run windowed, not headless — headless uses the dummy renderer and would save
## an empty frame:
##
##   ATG_TEST_MODE=1 Godot --path game res://tests/round_trails_capture.tscn
##
## Writes to `P:/GameDev/Temp/round_trails.png`, outside the repo on purpose.

const OUT := "P:/GameDev/Temp/round_trails.png"


func _ready() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.17, 0.19)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	environment.ambient_light_energy = 0.9
	env.environment = environment
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 28, 0)
	key.light_energy = 1.1
	add_child(key)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0, 0, 0)
	add_child(floor_mesh)

	var body := BaselineHuman.new()
	add_child(body)
	# Gore off on purpose: the surface craters and their cavity meshes are not
	# what this capture is for, and leaving them out shows the trails alone.
	# `_record_wound()` still records — only `_refresh_wounds()` respects `gore`.
	body.build("subject", {"gore": false})
	body.position = Vector3.ZERO

	var camera := Camera3D.new()
	camera.fov = 26.0
	camera.position = Vector3(-0.80, 1.16, -0.30)
	add_child(camera)
	camera.look_at(Vector3(-0.27, 1.10, 0))
	camera.current = true

	await get_tree().process_frame
	await get_tree().physics_frame

	# Front of the body is -Z, so a round aimed into it travels +Z.
	# A rifle round that crosses: both ends of the path and the bone edge.
	body._record_wound("left_arm", Vector3(-0.255, 1.22, -0.03), Vector3(0, 0, 1), 55.0, "ballistic", 0.75)
	# A pistol round that stops inside: a fat stub, faint with shallow depth.
	body._record_wound("left_arm", Vector3(-0.255, 1.12, -0.03), Vector3(0, 0, 1), 34.0, "ballistic", 0.25)
	# Buckshot that barely broke the surface, deliberately overlapping the first.
	body._record_wound("left_arm", Vector3(-0.255, 1.17, -0.03), Vector3(0, 0, 1), 28.0, "ballistic", 0.12)

	# Closed first, so anything wrong in the frame can be attributed: the same
	# body, same camera, only the X-ray differs.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var closed := get_viewport().get_texture().get_image()
	closed.save_png(OUT.replace(".png", "_closed.png"))

	# The verb under test.
	body.reveal_organs(true)
	body.see_through(true)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUT)
	print("CAPTURE ", OUT, " error=", error, " size=", image.get_width(), "x", image.get_height())
	var holder := body.get_node_or_null("left_arm/RoundTrails")
	print("TRAILS_ON_ARM ", holder.get_child_count() if holder != null else 0)
	get_tree().quit(0)
