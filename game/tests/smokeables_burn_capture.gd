extends Node3D

## AU7.6/AU7.8. Two things a unit test cannot show: that a cigarette visibly
## gets shorter as it is used up, and that the hold gauge is the object rather
## than a bar on a screen.
##
## Row one is one cigarette at five burn levels. Row two is one cigarette at
## five points through a single draw - rest, halfway, at the sweet spot, and
## two past it into the harsh band, where the cherry stops getting brighter and
## starts getting whiter.

const SMOKEABLES := preload("res://systems/smokeables.gd")


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
	environment.background_color = Color("070806")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("23211d")
	environment.ambient_light_energy = 1.15
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	env.environment = environment
	add_child(env)

	# Deliberately dim. The coal is the readout, so the scene has to be dark
	# enough that a change in it is the loudest thing in frame.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, 18, 0)
	key.light_energy = 0.5
	add_child(key)

	var bench := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.90, 0.02, 0.46)
	bench.mesh = slab
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("2a1f17")
	wood.roughness = 0.95
	bench.material_override = wood
	bench.position = Vector3(0, -0.011, 0)
	add_child(bench)

	# Row one: burning down.
	var burns := [0.0, 0.25, 0.5, 0.75, 0.95]
	for index in burns.size():
		var node: Node3D = SMOKEABLES.build("cigarette", float(burns[index]))
		node.rotation = Vector3(0, deg_to_rad(90.0), 0)
		node.position = Vector3(-0.30 + float(index) * 0.15, 0.006, -0.105)
		add_child(node)

	# Row two: one draw, held longer and longer. Ideal is 1.6s.
	var holds := [0.0, 0.8, 1.6, 2.6, 4.2]
	for index in holds.size():
		var node: Node3D = SMOKEABLES.build("cigarette", 0.35)
		node.rotation = Vector3(0, deg_to_rad(90.0), 0)
		node.position = Vector3(-0.30 + float(index) * 0.15, 0.006, 0.095)
		add_child(node)
		SMOKEABLES.set_draw(node, SMOKEABLES.draw_heat("cigarette", float(holds[index])))

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 0.40, 0.42)
	camera.look_at(Vector3(0.0, 0.0, -0.02), Vector3.UP)
	camera.fov = 46.0
	camera.current = true
	await get_tree().process_frame
	await _shot(out_dir, "smoke_burn_and_draw")

	camera.position = Vector3(0.02, 0.13, 0.30)
	camera.look_at(Vector3(0.02, 0.012, 0.09), Vector3.UP)
	camera.fov = 34.0
	await _shot(out_dir, "smoke_draw_row")

	print("BURN SHEET DONE")
	get_tree().quit()
