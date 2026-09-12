extends Node

## AD1.2. Windowed-only visual check: a real low wall placed in front of
## the player, before and mid-vault, so the raycast math verified headlessly
## in `vault_test.gd` can also be looked at.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.yaw = 0.0
	hunt.third_person = true
	for _settle in 10:
		await get_tree().physics_frame

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.8, 0.4)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, 0.4, 19.5)
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8a6a3a")
	mesh.material_override = material
	body.add_child(mesh)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var forward: Vector3 = hunt.HUNTER_MOTOR.wish_direction(Vector2(0, -1), hunt.yaw)
	var target: Dictionary = hunt._vault_target(forward)
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/vault_before.png" % out_dir)

	if not target.is_empty():
		hunt._vault(target.landing)
		for _tick in 6:
			hunt._update_player(1.0 / 60.0)
			await get_tree().physics_frame
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/vault_mid.png" % out_dir)
		for _tick in 30:
			hunt._update_player(1.0 / 60.0)
			await get_tree().physics_frame
			if hunt.vaulting_time <= 0.0:
				break
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/vault_after.png" % out_dir)
	print("CAPTURE_DONE target_empty=", target.is_empty())
	get_tree().quit()
