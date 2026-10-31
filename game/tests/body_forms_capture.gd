extends Node3D

## Naked bodies under the body-cam glitch censor, front and back, and the same
## bodies with the censor off. `-- --out=DIR --explicit` for the uncensored.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	var explicit := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		if argument == "--explicit":
			explicit = true
	get_window().size = Vector2i(1400, 900)
	WorldHistory.clear_history()
	AnatomyPresentation.set_mode("EXPLICIT" if explicit else "MOSAIC")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a2d31")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9aa0a8")
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var floor_ := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_.mesh = plane
	var tiles := StandardMaterial3D.new()
	tiles.albedo_color = Color("3b3430")
	floor_.material_override = tiles
	add_child(floor_)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.0, -3.4)
	camera.fov = 38.0
	add_child(camera)
	camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	var at := -1.35
	for anatomy in ["female", "male", "intersex"]:
		var rig := BaselineHuman.new()
		add_child(rig)
		rig.build("naked_" + anatomy, BaselineHuman.config_from_subject({"anatomy_sex": anatomy}))
		rig.position = Vector3(at, 0, 0)
		at += 0.9
	var back := BaselineHuman.new()
	add_child(back)
	back.build("naked_back", BaselineHuman.config_from_subject({"anatomy_sex": "reconstructed"}))
	back.position = Vector3(at, 0, 0)
	back.rotation.y = PI
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/body_forms_%s.png" % [out_dir, "explicit" if explicit else "censored"]
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
	get_tree().quit()
