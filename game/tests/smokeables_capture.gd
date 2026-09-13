extends Node3D

## AU1.8. The five objects, photographed. Everything here is built from
## primitives at real scale - a cigarette is 84mm because a cigarette is 84mm -
## so the line-up is also the proof that they are the right size next to each
## other, which is the thing a screenshot catches and a unit test cannot.

const SMOKEABLES := preload("res://systems/smokeables.gd")

const ORDER := ["cigarette", "vape", "spliff", "joint", "bong"]


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
	environment.ambient_light_color = Color("2a2622")
	environment.ambient_light_energy = 0.9
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	env.environment = environment
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -34, 0)
	key.light_energy = 1.3
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, 128, 0)
	fill.light_energy = 0.35
	add_child(fill)

	# A bench for them to sit on, so scale reads against something.
	var bench := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(1.05, 0.02, 0.36)
	bench.mesh = slab
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("2b2019")
	wood.roughness = 0.92
	bench.material_override = wood
	bench.position = Vector3(0, -0.011, 0)
	add_child(bench)

	# --- the line-up -------------------------------------------------------
	var x := -0.32
	for device_id in ORDER:
		var node: Node3D = SMOKEABLES.build(device_id)
		# The rolled ones run down -Z; stand them across the bench instead so
		# the line-up reads as a row of objects rather than a row of dots.
		if device_id != "bong":
			node.rotation = Vector3(0, deg_to_rad(90.0), 0)
			node.position = Vector3(x, 0.006, 0.0)
		else:
			node.position = Vector3(x + 0.02, 0.0, 0.0)
		add_child(node)
		x += 0.16

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 0.33, 0.74)
	camera.look_at(Vector3(0.02, 0.12, 0.0), Vector3.UP)
	camera.fov = 44.0
	camera.current = true
	await get_tree().process_frame
	await _shot(out_dir, "smokeables_lineup")

	# --- close on the burning end -----------------------------------------
	camera.position = Vector3(-0.19, 0.085, 0.125)
	camera.look_at(Vector3(-0.325, 0.008, 0.0), Vector3.UP)
	camera.fov = 28.0
	await _shot(out_dir, "smokeables_ember")

	# --- close on the bong, the only two-handed one ------------------------
	camera.position = Vector3(0.40, 0.22, 0.46)
	camera.look_at(Vector3(0.32, 0.14, 0.0), Vector3.UP)
	camera.fov = 40.0
	await _shot(out_dir, "smokeables_bong")

	print("SMOKEABLES SHEET DONE")
	get_tree().quit()
