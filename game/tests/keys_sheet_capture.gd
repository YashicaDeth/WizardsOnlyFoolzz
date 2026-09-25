extends Node

## The pause menu's KEYS page, in the Hunt (its own keys card) and on the
## Growing Floor (its keys_groups()). Run: ... -- --out=DIR

func _ready() -> void:
	# The pause menu pauses the tree; this harness has to keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	for scene_path in ["res://bone_yard_hunt.tscn", "res://vat_chamber.tscn"]:
		var scene = load(scene_path).instantiate()
		# Deferred: the root is still setting up its children during _ready.
		get_tree().root.add_child.call_deferred(scene)
		await get_tree().process_frame
		get_tree().current_scene = scene
		for _frame in 30:
			await get_tree().process_frame
		# The Hunt loads over several frames; wait until its keys card exists.
		var waited := 0
		while scene.get("keys_card") == null and scene.name.begins_with("Bone") and waited < 600:
			await get_tree().process_frame
			waited += 1
		var gate = get_node("/root/PauseGate")
		gate.open_gate()
		gate.page = "keys"
		gate.keys_page = 0
		for _frame in 20:
			await get_tree().process_frame
		var shot_name: String = scene_path.get_file().get_basename()
		get_viewport().get_texture().get_image().save_png("%s/keys_%s.png" % [out_dir, shot_name])
		print("CAPTURED keys ", shot_name, " pages ", gate.key_page_count())
		gate.close()
		get_tree().paused = false
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit()
