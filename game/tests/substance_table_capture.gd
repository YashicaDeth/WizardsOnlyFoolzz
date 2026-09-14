extends Node3D

## AU3.2/AU3.5. The station photographed next to a standing body, because the
## complaint it answers was a perspective one and a perspective complaint cannot
## be settled by a unit test. Two things have to be true in the frame: the bench
## reads as a bench a person could work at (top at the hand, not at the knee or
## the chest), and every substance on it is a different object at a glance
## rather than the same rectangle in a different colour.

const STATION := preload("res://systems/substance_station.gd")


func _shot(out_dir: String, shot_name: String) -> void:
	for _settle in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot_name]
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "FAILED: ", path)


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0a09")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("4e463c")
	environment.ambient_light_energy = 1.1
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	env.environment = environment
	add_child(env)

	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(14.0, 0.1, 14.0)
	ground.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("241f1a")
	dirt.roughness = 0.98
	ground.material_override = dirt
	ground.position = Vector3(0, -0.05, 0)
	add_child(ground)

	# A bare bulb above the bench plus a low key, so the objects are lit from
	# the side the camera is on. A top-only light flattens every lid and rim on
	# the table into the surface it sits on.
	var bulb := OmniLight3D.new()
	bulb.light_color = Color("ffd9a8")
	bulb.light_energy = 5.0
	bulb.omni_range = 6.0
	bulb.position = Vector3(0.0, 2.05, 0.55)
	add_child(bulb)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 154, 0)
	key.light_energy = 0.9
	add_child(key)

	var station: Node3D = STATION.new()
	add_child(station)
	station.build()

	# The scale reference. A standing rig at the working side of the bench, with
	# the bench's own top height printed beside it in the log so the frame and
	# the number can be checked against each other.
	var standing := BaselineHuman.new()
	standing.position = Vector3(1.72, 0.0, 0.30)
	standing.rotation = Vector3(0, deg_to_rad(200.0), 0)
	add_child(standing)
	standing.build("scale_ref", {"gore": false})

	var second := BaselineHuman.new()
	second.position = Vector3(-1.78, 0.0, 0.34)
	second.rotation = Vector3(0, deg_to_rad(160.0), 0)
	add_child(second)
	second.build("scale_ref_b", {"gore": false, "build": 1.12})

	print("TOP_Y=", STATION.TOP_Y, " head_top=", BaselineHuman.STANDING.head.at.y + BaselineHuman.STANDING.head.size.y * 0.5)

	var camera := Camera3D.new()
	add_child(camera)

	# 1. The scale shot: standing eye height, a couple of paces back, the whole
	# bench and both bodies in frame.
	camera.fov = 55.0
	camera.position = Vector3(0.15, 1.62, 3.35)
	camera.look_at(Vector3(0.0, 0.86, 0.0), Vector3.UP)
	camera.current = true
	await _shot(out_dir, "substance_table_scale")

	# 2. What a person standing at the bench actually sees of it.
	camera.fov = 62.0
	camera.position = Vector3(-0.12, 1.60, 0.92)
	camera.look_at(Vector3(-0.12, 0.88, 0.05), Vector3.UP)
	await _shot(out_dir, "substance_table_worker")

	# 3. Close on the substances themselves, which is where "distinct at a
	# glance" is either true or it is not.
	camera.fov = 34.0
	camera.position = Vector3(-0.46, 1.16, 0.62)
	camera.look_at(Vector3(-0.46, 0.90, 0.06), Vector3.UP)
	await _shot(out_dir, "substance_table_goods")

	print("SUBSTANCE TABLE SHEET DONE")
	get_tree().quit()
