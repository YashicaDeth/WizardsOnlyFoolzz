extends Node
## Where a scene's frame goes. Loads it, settles, samples the frame, then
## switches off each top-level child in turn and reports how much script and
## physics time came back. `-- --scene=res://bone_yard_hunt.tscn`
## Budget: 160 fps = 6.25 ms a frame.

const SETTLE := 90
const SAMPLE := 90


func _ready() -> void:
	var scene_path := "res://bone_yard_hunt.tscn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
	get_tree().root.size = Vector2i(1280, 720)
	var level: Node = load(scene_path).instantiate()
	add_child(level)
	for _frame in SETTLE:
		await get_tree().process_frame
	var base := await _sample()
	print("PERF %s frame=%.2fms script=%.2fms physics=%.2fms draws=%d objects=%d nodes=%d" % [scene_path, base.frame, base.script, base.physics, base.draws, base.objects, base.nodes])
	var costs := []
	var candidates: Array[Node] = []
	for child in level.get_children():
		candidates.append(child)
		# One level down inside the heavy containers too.
		if child.get_child_count() > 8:
			for grandchild in child.get_children():
				candidates.append(grandchild)
	for node in candidates:
		var mode := node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		var without := await _sample(30)
		node.process_mode = mode
		costs.append([base.script + base.physics - without.script - without.physics, str(level.get_path_to(node)), node.get_class()])
	costs.sort_custom(func(a, b): return a[0] > b[0])
	for index in mini(12, costs.size()):
		print("COST %.2fms %s (%s)" % costs[index])
	get_tree().quit()


func _sample(frames := SAMPLE) -> Dictionary:
	var script := 0.0
	var physics := 0.0
	var frame := 0.0
	for _frame in frames:
		await get_tree().process_frame
		script += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		frame += get_process_delta_time() * 1000.0
	return {
		"frame": frame / frames, "script": script / frames, "physics": physics / frames,
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
