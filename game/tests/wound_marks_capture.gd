extends Node3D

## Wounds are a look, so they get looked at. Two bodies, one clean and one shot
## repeatedly in specific places, photographed close enough to judge.

const HUMAN := preload("res://systems/baseline_human.gd")

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
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
	key.rotation_degrees = Vector3(-34, 38, 0)
	key.light_energy = 1.5
	add_child(key)

	# A floor, so the gore that bursts out of the hits falls away instead of
	# hanging in front of the body being photographed.
	var ground := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.4, 30)
	col.shape = box
	col.position = Vector3(0, -0.2, 0)
	ground.add_child(col)
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground_mesh.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("241c18")
	ground_mesh.material_override = gm
	ground.add_child(ground_mesh)
	add_child(ground)

	var clean: BaselineHuman = HUMAN.new()
	add_child(clean)
	clean.build("clean_body", {})
	clean.position = Vector3(-0.75, 0, 0)

	var shot: BaselineHuman = HUMAN.new()
	add_child(shot)
	shot.build("shot_body", {})
	shot.position = Vector3(0.75, 0, 0)
	await get_tree().process_frame
	await get_tree().process_frame

	# A burst across the chest, then the shoulder, then a shotgun to one arm —
	# three different weapons leaving three different kinds of opening.
	var torso := shot.parts.get("torso") as Node3D
	for i in 6:
		var at: Vector3 = torso.global_position + Vector3(-0.06 + 0.024 * float(i), 0.14 - 0.035 * float(i), 0.17)
		shot.hit_at(at, 9.0, 1.2, "ballistic", Vector3(0, -0.1, -1))
	for i in 3:
		var at: Vector3 = torso.global_position + Vector3(0.02, -0.05 - 0.05 * float(i), 0.17)
		shot.hit_at(at, 11.0, 1.4, "ballistic", Vector3(0, 0, -1))
	var arm := shot.parts.get("right_arm") as Node3D
	if arm != null:
		for i in 4:
			shot.hit_at(arm.global_position + Vector3(0.02 * float(i), 0.06 - 0.04 * float(i), 0.10), 10.0, 1.5, "shear", Vector3(0.3, 0, -1))

	# Let the burst fall and settle, or the photograph is of airborne chunks.
	for _s in 150:
		await get_tree().process_frame

	var cam := Camera3D.new()
	cam.position = Vector3(1.35, 1.25, 1.30)
	cam.fov = 36.0
	add_child(cam)
	cam.look_at(Vector3(0.75, 1.02, 0), Vector3.UP)
	for _s in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/b10_4_wounds_standing.png"))

	cam.position = Vector3(0, 1.30, 3.6)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	for _s in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/b10_4_wounds_standing_pair.png"))

	print("torso wounds: ", (shot.wound_marks.get("torso", []) as Array).size())
	print("WOUND_CAPTURE_RESULT saved")
	get_tree().quit(0)
