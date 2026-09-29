extends Node3D
## The examiner's skin, looked at: idle, mid-walk, a wind-up with the scalpel in
## his hand, and after a cut on the arm (that arm is the rig's own again).
##   Godot --path game res://tests/model_skin_capture.tscn -- --out=P:/GameDev/Temp/skin

const SKIN := preload("res://systems/model_skin.gd")
var rig: BaselineHuman
var skin: Node3D
var camera: Camera3D


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp/skin"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.09, 0.085, 0.1)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.45, 0.45, 0.5)
	settings.ambient_light_energy = 0.8
	var environment := WorldEnvironment.new()
	environment.environment = settings
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.4
	add_child(key)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 38.0
	add_child(camera)
	camera.make_current()

	rig = BaselineHuman.new()
	add_child(rig)
	rig.build("skin_capture", BaselineHuman.config_from_subject({"race": "decanted"}).merged({"gore": true}, true))
	ExaminerLook.dress(rig, false)
	rig.rotation.y = 0.5
	var scalpel := _tool(rig.parts["right_arm"], Vector3(0.012, 0.012, 0.16), Color("c9ccc8"))
	var syringe := _tool(rig.parts["left_arm"], Vector3(0.022, 0.022, 0.14), Color("dfe8e0"))
	skin = SKIN.attach(rig)
	print("SKIN ", skin != null, " tris ", skin.triangles_by_zone if skin != null else {})
	skin.hold_tools(scalpel, syringe)
	await _settle(40)
	for pair: Array in [["scalpel", scalpel, "RightHand"], ["syringe", syringe, "LeftHand"]]:
		var tool := pair[1] as Node3D
		var bone: int = skin.skeleton.find_bone(str(pair[2]))
		var hand: Vector3 = skin.skeleton.global_transform * skin.skeleton.get_bone_global_pose(bone).origin
		print("TOOL %s parent=%s visible=%s world=%s scale=%s | %s bone world=%s | attachment world=%s" % [pair[0], tool.get_parent().name, tool.is_visible_in_tree(), tool.global_position.snapped(Vector3.ONE * 0.001), tool.global_transform.basis.get_scale().snapped(Vector3.ONE * 0.001), pair[2], hand.snapped(Vector3.ONE * 0.001), (tool.get_parent() as Node3D).global_position.snapped(Vector3.ONE * 0.001)])
	await _shoot("%s/skin_1_idle.png" % out_dir)
	# The idle clip over its length: is its stance a stance?
	for step in [["skin_5_idle_a", 1.0], ["skin_6_idle_b", 2.0], ["skin_7_idle_c", 3.0]]:
		skin.player.play("idle")
		skin.player.seek(float(step[1]), true)
		skin.player.pause()
		await _settle(3)
		await _shoot("%s/%s.png" % [out_dir, step[0]])
	skin.player.play("idle")

	# Walking: he moves, so the walk clip plays.
	for _frame in 50:
		rig.position.x += 0.03
		await get_tree().process_frame
	await _shoot("%s/skin_2_walk.png" % out_dir)

	# Standing again, then the wind-up (both arms, the syringe one).
	await _settle(50)
	skin.set_windup(1.0, true)
	await _settle(8)
	await _shoot("%s/skin_3_windup.png" % out_dir)
	skin.set_windup(0.0, false)

	# What the player sees: front-on at fighting distance, scalpel arm winding up.
	rig.rotation.y = 0.0
	skin.set_windup(0.0, false)
	await _settle(6)
	await _shoot("%s/skin_8_front_rest.png" % out_dir, Vector3(0.0, 1.5, -2.6), 1.0)
	for amount in [0.5, 1.0]:
		skin.set_windup(amount, false)
		await _settle(6)
		await _shoot("%s/skin_9_front_windup_%d.png" % [out_dir, int(amount * 10.0)], Vector3(0.0, 1.5, -2.6), 1.0)
	skin.set_windup(0.0, false)
	await _settle(6)
	await _shoot("%s/skin_10_hand.png" % out_dir, Vector3(-0.9, 1.1, -1.3), 0.95)

	# A tight look at the right hand, with the scalpel made loud.
	var loud := StandardMaterial3D.new()
	loud.albedo_color = Color(1, 0.1, 0.1)
	loud.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(scalpel as MeshInstance3D).material_override = loud
	await _shoot("%s/skin_11_righthand.png" % out_dir, Vector3(0.32, 1.25, -0.9), 1.03)
	(scalpel as MeshInstance3D).material_override = null

	# A cut on the right arm and a bruise on the torso.
	rig.hit("torso", 14.0, 1.0, "blunt")
	rig.hit("right_arm", 30.0, 2.0, "cut")
	await _settle(10)
	print("MODES ", skin.modes)
	await _shoot("%s/skin_4_wounded.png" % out_dir)
	get_tree().quit()


func _tool(arm: Node3D, size: Vector3, colour: Color) -> Node3D:
	var tool := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.6
	material.roughness = 0.35
	mesh.material = material
	tool.mesh = mesh
	tool.position = Vector3(0.0, -0.36, -0.08)
	arm.add_child(tool)
	return tool


func _settle(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _shoot(path: String, offset := Vector3(2.4, 1.6, -3.4), aim_y := 0.95) -> void:
	camera.global_position = rig.global_position + offset
	camera.look_at(rig.global_position + Vector3(0, aim_y, 0), Vector3.UP)
	for _frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "FAILED: ", path)
