extends Node

## What the old drains' bingyanger looks like from where you'd first see it.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	var stalker: DrainStalker = drains.stalker
	stalker.set_physics_process(false)
	drains.set_physics_process(false)
	stalker.global_position = Vector3(-1.2, 0, -12)
	stalker.rotation.y = 0.0
	drains.player.global_position = Vector3(0.4, 0.85, -8.5)
	drains.yaw = 0.18
	drains.player.rotation.y = 0.18
	drains.camera.rotation = Vector3(-0.08, 0, 0)
	stalker._say("prowl")
	drains._update_hud()
	for _frame in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/drain_stalker.png" % out_dir)
	get_tree().quit()
