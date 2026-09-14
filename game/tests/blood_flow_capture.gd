extends Node3D

## Blood running from real wounds, over time. Shot, then left to bleed, then
## photographed — the point is the streaks on the skin and the pool underneath,
## and neither of those exists on the frame the round lands.

const HUMAN := preload("res://systems/baseline_human.gd")

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("120e0c")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c0ad9c")
	e.ambient_light_energy = 1.15
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 30, 0)
	key.light_energy = 1.6
	add_child(key)

	var ground := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.4, 30)
	col.shape = box
	col.position = Vector3(0, -0.2, 0)
	ground.add_child(col)
	var gm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	gm.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a201b")
	gm.material_override = mat
	ground.add_child(gm)
	add_child(ground)

	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("bleeder", {})
	await get_tree().process_frame
	await get_tree().process_frame

	# Survivable hits, so it stays standing and bleeds rather than falling in a
	# heap — the run down the leg is the thing being photographed.
	var torso := rig.parts.get("torso") as Node3D
	for i in 4:
		rig.hit_at(torso.global_position + Vector3(-0.04 + 0.03 * float(i), 0.12 - 0.03 * float(i), 0.16), 10.0, 1.2, "ballistic", Vector3(0, 0, -1))
	var arm := rig.parts.get("left_arm") as Node3D
	if arm != null:
		rig.hit_at(arm.global_position + Vector3(0, 0.04, 0.09), 11.0, 1.4, "ballistic", Vector3(0, 0, -1))

	var cam := Camera3D.new()
	cam.position = Vector3(0.95, 1.15, 1.15)
	cam.fov = 38.0
	add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)

	# Let it bleed. The streaks grow at 0.055 m/s of bleeding, so a few seconds
	# is the difference between nothing and a real run.
	for _s in 60:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/b10_5_bleeding_early.png"))
	for _s in 480:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/b10_5_bleeding_late.png"))

	print("bleed_rate %.2f  seconds %.1f" % [rig.anatomy.bleed_rate, float(rig.get("_bleed_seconds"))])
	print("BLOOD_CAPTURE_RESULT saved")
	get_tree().quit(0)
