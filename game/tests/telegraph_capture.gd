extends Node

## A tiered fighter's telegraph in the real Hunt: the side their swing comes
## from, marked on them in REC red. `-- --out=DIR`.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	var cam: Camera3D = get_viewport().get_camera_3d()
	var forward := -cam.global_transform.basis.z
	forward.y = 0.0
	var at: Vector3 = cam.global_position + forward.normalized() * 3.2
	at.y = hunt.player.y - 1.6
	hunt._spawn_encounter_actor({"instance_id": "tele_captain", "kind": "hostile", "tier": "captain"}, at)
	var captain: Dictionary = hunt.encounter_actors.back()
	captain.node.position = at
	captain["attack_side"] = "left"
	for _i in 3:
		hunt._show_telegraph(captain, captain.node, true)
		captain.telegraph_mark.visible = true
	for _frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/telegraph_left.png")
	print("CAPTURED")
	get_tree().quit()
