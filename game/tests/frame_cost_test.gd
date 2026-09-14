extends Node

## Greg: "there is alot to fix it is quite quite slow".
##
## The previous attempt at this measured 59.8 / 60.4 / 59.5 fps across three
## quality levels and concluded nothing, because vsync was pinning every one of
## them at 60. A benchmark that cannot go above the refresh rate cannot measure
## a change that only matters above it. Vsync is disabled here first.
##
## Measured on the Hunt Grounds rather than the sandbox, for two reasons: it is
## the scene Greg actually plays, and the sandbox currently cannot be stood up
## at all while `substance_objects.gd` is mid-edit.

const LEVELS := ["ULTRA", "HIGH", "PERFORMANCE"]


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1920, 1080)
	await tree.process_frame

	var scene: Node = load("res://gore_demo.tscn").instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	# Terrain and shaders settle slowly; measuring during that measures loading.
	for _warm in 240:
		await tree.process_frame

	print("vsync: %d (0 = disabled)  size: %s" % [
		DisplayServer.window_get_vsync_mode(), str(get_window().size)])

	var results := {}
	for level: String in LEVELS:
		WorldLook.set_quality_name(level)
		for child in scene.get_children():
			if child is WorldEnvironment and child.environment != null:
				WorldLook.apply_quality(child.environment, WorldLook.PRESETS.get("bone_yard", {}))
		for _settle in 60:
			await tree.process_frame

		var frames := 180
		var start := Time.get_ticks_usec()
		for _s in frames:
			await tree.process_frame
		var seconds := float(Time.get_ticks_usec() - start) / 1000000.0
		var fps := float(frames) / maxf(0.0001, seconds)
		results[level] = fps
		print("  %-12s %7.1f fps   %6.2f ms/frame" % [level, fps, seconds / frames * 1000.0])

	var u: float = results["ULTRA"]
	var p: float = results["PERFORMANCE"]
	print("PERFORMANCE / ULTRA = %.2fx" % (p / maxf(0.0001, u)))
	# What is actually in the scene. A frame cost with no object count beside it
	# is a number nobody can act on.
	var meshes := 0
	var lights := 0
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes += 1
		elif n is Light3D:
			lights += 1
		for c in n.get_children():
			stack.append(c)
	print("scene contains %d MeshInstance3D, %d Light3D" % [meshes, lights])
	print("frame cost: measured")
	tree.quit(0)
