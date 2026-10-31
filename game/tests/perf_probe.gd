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
	# Uncapped, or every frame reads 16.7 ms on a 60 Hz screen.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var level: Node = load(scene_path).instantiate()
	add_child(level)
	for _frame in SETTLE:
		await get_tree().process_frame
	var base := await _sample()
	print("PERF %s frame=%.2fms script=%.2fms physics=%.2fms render_cpu=%.2fms gpu=%.2fms draws=%d objects=%d nodes=%d" % [scene_path, base.frame, base.script, base.physics, base.render_cpu, base.gpu, base.draws, base.objects, base.nodes])
	var costs := []
	var candidates: Array[Node] = []
	# Meshes under each top-level child: where the draw calls come from.
	var meshes := []
	for child in level.get_children():
		candidates.append(child)
		meshes.append([_count_meshes(child), str(child.name)])
	meshes.sort_custom(func(x, y): return x[0] > y[0])
	for index in mini(10, meshes.size()):
		print("MESHES %d %s" % meshes[index])
	for node in candidates:
		var mode := node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		var without := await _sample(15)
		node.process_mode = mode
		var saved: float = base.frame - without.frame
		costs.append([saved, str(level.get_path_to(node)), node.get_class()])
		if saved > 0.5:
			print("COST %.2fms %s (%s)" % [saved, str(level.get_path_to(node)), node.get_class()])
	get_tree().quit()


func _count_meshes(node: Node) -> int:
	var total := int(node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree())
	if node is MultiMeshInstance3D:
		total += 1
	for child in node.get_children():
		total += _count_meshes(child)
	return total


func _sample(frames := SAMPLE) -> Dictionary:
	var script := 0.0
	var physics := 0.0
	var render_cpu := 0.0
	var gpu := 0.0
	var rid := get_viewport().get_viewport_rid()
	# Wall clock, not TIME_FPS: that monitor updates once a second, so a short
	# sample read 1 fps (1000 ms) on scenes that were running fine.
	await get_tree().process_frame
	var start := Time.get_ticks_usec()
	for _frame in frames:
		await get_tree().process_frame
		script += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return {
		"frame": float(Time.get_ticks_usec() - start) / 1000.0 / frames, "render_cpu": render_cpu / frames, "gpu": gpu / frames, "script": script / frames, "physics": physics / frames,
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
