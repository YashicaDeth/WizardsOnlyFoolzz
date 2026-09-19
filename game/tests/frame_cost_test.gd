extends Node

## Greg: "there is alot to fix it is quite quite slow".
##
## The previous attempt at this measured 59.8 / 60.4 / 59.5 fps across three
## quality levels and concluded nothing, because vsync was pinning every one of
## them at 60. A benchmark that cannot go above the refresh rate cannot measure
## a change that only matters above it. Vsync is disabled here first.
##
## Measured in the Gore Sandbox, the scene from the 13 FPS report. This must
## exercise the complete tier — Environment effects, render scale and AA — or
## it measures a different setting from the one the player selects.

const PASSES := [
	["ULTRA", "HIGH", "PERFORMANCE"],
	["PERFORMANCE", "ULTRA", "HIGH"],
	["HIGH", "PERFORMANCE", "ULTRA"],
]
const SAMPLE_FRAMES := 90

var samples := {"ULTRA": [], "HIGH": [], "PERFORMANCE": []}
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


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

	# Three rotated passes stop shader warm-up, heat and fixed-order drift from
	# being mistaken for a quality difference. Each pass applies the whole
	# player-facing preset, including render scale and antialiasing.
	for pass_levels: Array in PASSES:
		for level: String in pass_levels:
			WorldLook.set_quality_name(level)
			WorldLook.apply_viewport_quality(get_viewport())
			for child in scene.get_children():
				if child is WorldEnvironment and child.environment != null:
					WorldLook.apply_quality(child.environment, WorldLook.PRESETS.get("bone_yard", {}))
			for _settle in 30:
				await tree.process_frame
			for _sample in SAMPLE_FRAMES:
				var began := Time.get_ticks_usec()
				await tree.process_frame
				(samples[level] as Array).append(float(Time.get_ticks_usec() - began) / 1000.0)

	var medians := {}
	for level: String in samples:
		var timings: Array = samples[level]
		timings.sort()
		var median := float(timings[timings.size() / 2])
		var p95_index := mini(timings.size() - 1, ceili(float(timings.size()) * 0.95) - 1)
		var p95 := float(timings[p95_index])
		medians[level] = median
		print("  %-12s median %6.2f ms  p95 %6.2f ms  %6.1f fps" % [level, median, p95, 1000.0 / maxf(0.001, median)])

	var ultra_ms: float = medians["ULTRA"]
	var performance_ms: float = medians["PERFORMANCE"]
	print("PERFORMANCE / ULTRA COST = %.2fx" % (performance_ms / maxf(0.0001, ultra_ms)))
	check(performance_ms <= WorldLook.FRAME_BUDGET_MS,
		"PERFORMANCE median holds the 16.67 ms / 60 FPS frame budget (%.2f ms)" % performance_ms)
	check(performance_ms < ultra_ms,
		"the complete PERFORMANCE preset costs less than ULTRA (%.2f vs %.2f ms)" % [performance_ms, ultra_ms])
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
	print("FRAME_COST_TEST_RESULT failures=%d" % failures.size())
	tree.quit(0 if failures.is_empty() else 1)
