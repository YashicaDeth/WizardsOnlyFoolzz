extends Node

## Where the sword actually is versus where the hand actually is.
##
## Two blind guesses at this have now made it worse, so this measures first and
## renders second: it prints the camera, the arm node, the wrist end of the arm
## mesh and the current mount in the same space, then photographs a spread of
## candidate mounts so the choice is made by looking rather than by arithmetic
## about a rig whose conventions are spread over three files.

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	for _settle in 20:
		await get_tree().physics_frame
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	hunt._equip_weapon(0)
	for _tick in 20:
		await get_tree().physics_frame
	hunt._update_camera()
	await get_tree().physics_frame

	var camera: Camera3D = hunt.camera
	var arm: Node3D = hunt.player_rig.parts.get("right_arm")
	var mount: Node3D = hunt.arsenal.models.get("sword")
	print("CAMERA_GLOBAL=", camera.global_position)
	print("ARM_GLOBAL=", arm.global_position, " arm_rot=", arm.rotation)
	print("ARM_SCALE=", arm.global_transform.basis.get_scale())
	print("MOUNT_LOCAL=", mount.position, " MOUNT_GLOBAL=", mount.global_position)
	print("ARM_TO_CAMERA=", camera.to_local(arm.global_position))
	print("MOUNT_TO_CAMERA=", camera.to_local(mount.global_position))
	# The wrist end of the arm mesh, in the arm's own space, per body_mesh.arm()
	# revolving along local Y from shoulder (+h) to wrist (-h).
	for h in [0.31, -0.31]:
		print("ARM_END y=", h, " to_camera=", camera.to_local(arm.to_global(Vector3(0, h, 0))))

	var candidates := [
		{"tag": "x_-108", "pos": Vector3(0.055, -0.196, -0.742), "rot": Vector3(-1.08, -0.26, 0.30)},
		{"tag": "x_-062", "pos": Vector3(0.055, -0.196, -0.742), "rot": Vector3(-0.62, -0.26, 0.30)},
		{"tag": "x_-030", "pos": Vector3(0.055, -0.196, -0.742), "rot": Vector3(-0.30, -0.26, 0.30)},
		{"tag": "x_000", "pos": Vector3(0.055, -0.196, -0.742), "rot": Vector3(0.0, -0.26, 0.30)},
		{"tag": "x_-062_near", "pos": Vector3(0.13, -0.30, -0.52), "rot": Vector3(-0.62, -0.42, 0.42)},
		{"tag": "x_-040_near", "pos": Vector3(0.13, -0.30, -0.52), "rot": Vector3(-0.40, -0.42, 0.42)},
	]
	for entry: Dictionary in candidates:
		# Both metas, because `_pose_weapon` reads its rest from these every
		# frame and would otherwise put the authored values straight back.
		mount.set_meta("rest_position", entry["pos"])
		mount.set_meta("rest_rotation", entry["rot"])
		for _tick in 6:
			await get_tree().physics_frame
		hunt._update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/mount_%s.png" % str(entry["tag"]))
		print("SHOT ", entry["tag"], " local=", mount.position, " rot=", mount.rotation)
	print("SWEEP_DONE")
	get_tree().quit()
