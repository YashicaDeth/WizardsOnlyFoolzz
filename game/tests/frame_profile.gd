extends Node

## `map_perf_test` measured the map at between nothing and eight milliseconds a
## frame, against a baseline frame of three hundred and nineteen. So the map was
## never the lag. This finds out what is.
##
## Reports the engine's own monitors rather than a stopwatch, because "the frame
## is slow" is not actionable and "the frame is slow in physics, with eleven
## thousand draw calls" is.

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	await tree.process_frame
	var scene_path := "res://bone_yard_hunt.tscn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
	var scene: Node = load(scene_path).instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	for _settle in 120:
		await tree.process_frame

	var frames := 180
	var began := Time.get_ticks_usec()
	var process_total := 0.0
	var physics_total := 0.0
	for _frame in frames:
		await tree.process_frame
		process_total += Performance.get_monitor(Performance.TIME_PROCESS)
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var wall := float(Time.get_ticks_usec() - began) / float(frames) / 1000.0

	print("scene: ", scene_path)
	print("wall clock        %8.2f ms/frame   (%.1f fps)" % [wall, 1000.0 / maxf(wall, 0.001)])
	print("script _process   %8.2f ms" % (process_total / float(frames) * 1000.0))
	print("script _physics   %8.2f ms" % (physics_total / float(frames) * 1000.0))
	print("engine fps        %8.1f" % Engine.get_frames_per_second())
	print("--- what is in the world ---")
	print("nodes             %8d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("objects           %8d" % Performance.get_monitor(Performance.OBJECT_COUNT))
	print("draw calls        %8d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("objects drawn     %8d" % Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("primitives        %8d" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("video memory      %8.1f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	print("physics bodies 3d %8d" % Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	print("collision pairs   %8d" % Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	print("islands           %8d" % Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))
	tree.quit(0)
