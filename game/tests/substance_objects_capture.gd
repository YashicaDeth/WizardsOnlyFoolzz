extends Node3D

## AU1.2/AU3.2. The four carried forms and the five things a shed has around
## them, photographed at real scale on one bench — so the sheet is also the
## proof that a 12mm tab and a 28g weight are the right size next to each other,
## which is what a screenshot catches and a unit test cannot.

const OBJECTS := preload("res://systems/substance_objects.gd")
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
	environment.background_color = Color("090807")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("4a423a")
	environment.ambient_light_energy = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	env.environment = environment
	add_child(env)

	# One bare bulb over a bench, which is the whole lighting design of a shed.
	#
	# It hangs in FRONT of the row rather than behind it. The first version put
	# it at z=0.10 with the objects at z=0.14, so every face the camera could
	# see pointed away from the only light in the scene and the pressed weight
	# photographed as a black slab - which read as a transparency bug and was
	# not one. A catalogue sheet has to light the faces being catalogued.
	var bulb := OmniLight3D.new()
	bulb.light_color = Color("ffd9a8")
	bulb.light_energy = 3.0
	bulb.omni_range = 2.6
	bulb.position = Vector3(0.02, 0.58, 0.42)
	add_child(bulb)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-34, 152, 0)
	fill.light_energy = 0.30
	add_child(fill)

	var bench := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(1.10, 0.024, 0.52)
	bench.mesh = slab
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("39291d")
	wood.roughness = 0.94
	bench.material_override = wood
	bench.position = Vector3(0, -0.012, 0)
	add_child(bench)

	# --- the four carried forms, front row --------------------------------
	var carried := [
		{"form": "baggie", "substance": "marrow_dust", "at": Vector3(-0.34, 0, 0.14)},
		{"form": "weight", "substance": "choir_bloom", "at": Vector3(-0.17, 0, 0.14)},
		{"form": "tab", "substance": "static_hymn", "at": Vector3(-0.02, 0, 0.15)},
		{"form": "blister", "substance": "marrow_dust", "at": Vector3(0.10, 0, 0.14)},
	]
	for entry: Dictionary in carried:
		var node: Node3D = OBJECTS.build(str(entry["form"]), str(entry["substance"]))
		node.position = entry["at"]
		node.rotation = Vector3(0, deg_to_rad(-14.0), 0)
		add_child(node)

	# --- the shed's own kit, back row --------------------------------------
	var props := [
		{"prop": "tray", "at": Vector3(-0.24, 0, -0.10)},
		{"prop": "grinder", "at": Vector3(0.02, 0, -0.06)},
		{"prop": "scales", "at": Vector3(0.20, 0, -0.10)},
		{"prop": "ashtray", "at": Vector3(0.41, 0, -0.07)},
		{"prop": "lighter", "at": Vector3(0.27, 0, 0.15)},
	]
	for entry: Dictionary in props:
		var node: Node3D = OBJECTS.build_prop(str(entry["prop"]))
		node.position = entry["at"]
		node.rotation = Vector3(0, deg_to_rad(9.0), 0)
		add_child(node)

	# A rolled one on the tray, so the two files read as one shed.
	var joint: Node3D = SMOKEABLES.build("joint")
	joint.rotation = Vector3(0, deg_to_rad(96.0), 0)
	joint.position = Vector3(-0.24, 0.008, -0.10)
	add_child(joint)

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.02, 0.40, 0.62)
	camera.look_at(Vector3(0.02, 0.02, -0.02), Vector3.UP)
	camera.fov = 46.0
	camera.current = true
	await get_tree().process_frame
	await _shot(out_dir, "shed_bench")

	camera.position = Vector3(-0.20, 0.155, 0.35)
	camera.look_at(Vector3(-0.20, 0.012, 0.10), Vector3.UP)
	camera.fov = 30.0
	await _shot(out_dir, "shed_carried")

	camera.position = Vector3(0.12, 0.20, 0.16)
	camera.look_at(Vector3(0.12, 0.01, -0.08), Vector3.UP)
	camera.fov = 34.0
	await _shot(out_dir, "shed_kit")

	print("SHED SHEET DONE")
	get_tree().quit()
