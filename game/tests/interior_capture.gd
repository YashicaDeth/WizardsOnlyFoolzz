extends Node

## M2 verification. The cabin is a look, so it has to be looked at.

const INTERIOR := preload("res://systems/vehicle_interior.gd")
const WorldLookScript := preload("res://systems/world_look.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var env := WorldEnvironment.new()
	env.environment = WorldLookScript.environment("bone_yard")
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_energy = 1.5
	add_child(sun)

	# Something to look at through the glass, so the windscreen has a job.
	for index in 9:
		var block := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0, randf_range(1.4, 4.2), 2.0)
		block.mesh = box
		block.position = Vector3(randf_range(-12, 12), box.size.y * 0.5, -6.0 - float(index) * 3.2)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("3a2f26")
		block.material_override = mat
		add_child(block)
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(90, 0.4, 90)
	ground.mesh = plane
	ground.position = Vector3(0, -0.2, -20)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("241d16")
	ground.material_override = gmat
	add_child(ground)

	var cabin: Node3D = INTERIOR.new()
	add_child(cabin)
	cabin.build(7)

	var camera := Camera3D.new()
	camera.position = INTERIOR.EYE
	camera.fov = 78.0
	camera.current = true
	add_child(camera)

	for shot in [
		{"name": "cabin_straight", "steer": 0.0, "damage": 0},
		{"name": "cabin_turning", "steer": -0.85, "damage": 0},
		{"name": "cabin_wrecked", "steer": 0.4, "damage": 5},
	]:
		cabin.drive(float(shot["steer"]), 1.0)
		for _hit in int(shot["damage"]):
			cabin.take_hit(0.8, randf_range(-0.8, 0.8))
		for _settle in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out_dir, str(shot["name"])]
		if get_viewport().get_texture().get_image().save_png(path) != OK:
			print("CAPTURE_FAILED ", path)
			get_tree().quit(1)
			return
		print("CAPTURED: ", path)
	print("REPORT glass_damage=%.2f" % cabin.glass_damage)
	get_tree().quit()
