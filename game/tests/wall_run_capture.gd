extends Node

## AD1.3. Windowed-only visual check: a real tall wall, a real triggered
## run, and what the camera actually sees mid-run compared to the moment
## the kickoff sends the body away from it.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.record_event("player_vaulted", {})
	WorldHistory.record_event("player_vaulted", {})
	WorldHistory.record_event("player_vaulted", {})
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.yaw = 0.0
	hunt.third_person = true
	for _settle in 10:
		await get_tree().physics_frame

	var forward: Vector3 = hunt.HUNTER_MOTOR.wish_direction(Vector2(0, -1), hunt.yaw)
	var side: Vector3 = Vector3(forward.z, 0.0, -forward.x)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 3.0, 20.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, 1.4, 19) + side * 0.9
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6a7a8a")
	mesh.material_override = material
	body.add_child(mesh)
	await get_tree().physics_frame
	await get_tree().physics_frame

	hunt._jump()
	hunt._update_player(1.0 / 60.0)
	hunt.player_body.velocity.x = forward.x * 8.0
	hunt.player_body.velocity.z = forward.z * 8.0
	var start: Dictionary = hunt._wall_run_surface(forward)
	if not start.is_empty():
		hunt._begin_wall_run(start)
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/wallrun_start.png" % out_dir)

	for _tick in 15:
		hunt._update_player(1.0 / 60.0)
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/wallrun_mid.png" % out_dir)

	hunt.wall_run_kickoff_queued = true
	hunt._update_player(1.0 / 60.0)
	for _tick in 8:
		hunt._update_player(1.0 / 60.0)
	hunt._update_camera()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/wallrun_kickoff.png" % out_dir)

	print("CAPTURE_DONE wall_running=", hunt.wall_running_time, " unlocked=", hunt.wall_run_unlocked())
	get_tree().quit()
