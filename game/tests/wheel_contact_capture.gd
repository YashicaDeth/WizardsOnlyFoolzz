extends Node3D

## A car, on the ground, photographed from the side, before and after. The whole
## complaint was visual and the fix is arithmetic, so the arithmetic has to be
## shown landing on the picture.

const SKIFF := preload("res://art/scrap_skiff.glb")
const VEHICLE := preload("res://systems/arcade_vehicle.gd")
const WHEEL_BOTTOM := 0.030

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 520)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("10131a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9aa6b8")
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -34, 0)
	add_child(sun)

	# The ground, and a bright line exactly on it so the eye has something to
	# judge "on the ground" against rather than a guess.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a3140")
	floor_mesh.material_override = mat
	add_child(floor_mesh)

	var scale_v := 1.15
	# WRONG: parented straight on the chassis, the way it shipped.
	var before := SKIFF.instantiate()
	before.scale = Vector3.ONE * scale_v
	before.position = Vector3(-3.2, 0.0, 0.0)
	add_child(before)
	# RIGHT: seated so the tyres meet the contact patch.
	var after := SKIFF.instantiate()
	after.scale = Vector3.ONE * scale_v
	after.position = Vector3(3.2, VEHICLE.rest_contact_y() - WHEEL_BOTTOM * scale_v, 0.0)
	add_child(after)

	# Both cars are shown relative to a chassis origin sitting at the height the
	# suspension actually holds it: |rest_contact_y| above the floor.
	var lift := -VEHICLE.rest_contact_y()
	before.position.y += lift
	after.position.y += lift

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 9.5)
	cam.fov = 46.0
	add_child(cam)
	cam.look_at(Vector3(0, 0.75, 0), Vector3.UP)

	for _s in 12:
		await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://captures/derby_wheel_contact.png"))
	print("rest_compression %.3f  rest_contact_y %.3f  seat %.3f" % [
		VEHICLE.rest_compression(), VEHICLE.rest_contact_y(), VEHICLE.rest_contact_y() - WHEEL_BOTTOM * scale_v])
	print("WHEEL_CONTACT_CAPTURE_RESULT saved")
	get_tree().quit(0)
