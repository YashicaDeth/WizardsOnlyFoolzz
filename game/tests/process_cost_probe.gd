extends Node
## What each processing (or physics-processing) script really costs: every instance of it switched
## off at once, the frame measured with and without. `-- --scene=res://x.tscn`

func _ready() -> void:
	var scene_path := "res://bone_yard_hunt.tscn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
	get_tree().root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var level: Node = load(scene_path).instantiate()
	add_child(level)
	for _frame in 90:
		await get_tree().process_frame
	var by_script := {}
	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if (node.is_processing() or node.is_physics_processing()) and node.get_script() != null:
			var key := str((node.get_script() as Script).resource_path.get_file())
			if not by_script.has(key):
				by_script[key] = []
			by_script[key].append(node)
	var base := await _frame_ms(60)
	print("PROCESS_COST base=%.2fms" % base)
	for key: String in by_script:
		var was := {}
		for node: Node in by_script[key]:
			was[node] = [node.is_processing(), node.is_physics_processing()]
			node.set_process(false)
			node.set_physics_process(false)
		var without := await _frame_ms(40)
		for node: Node in by_script[key]:
			if is_instance_valid(node):
				node.set_process(was[node][0])
				node.set_physics_process(was[node][1])
		print("PROCESS_COST %6.2fms  x%-3d %s" % [base - without, by_script[key].size(), key])
	get_tree().quit()


## Wall clock over N frames (TIME_FPS only updates once a second).
func _frame_ms(frames: int) -> float:
	await get_tree().process_frame
	var start := Time.get_ticks_usec()
	for _frame in frames:
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0 / frames
