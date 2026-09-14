extends Node

## Greg, playing the build: *"it's lagging a lot in the Gore Sandbox and we put
## it on full screen ... the FPS is about thirteen. It's fucking terrible."*
##
## This measures it instead of arguing about it. The sandbox is stood up at a
## fullscreen-sized viewport and the frame time is sampled at each quality
## level, because the three effects that were always on — volumetric fog, SSAO
## and glow — are fill-rate bound, and fill-rate bugs are invisible in a window.

const LEVELS := ["ULTRA", "HIGH", "PERFORMANCE"]

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
	get_window().size = Vector2i(1920, 1080)
	await tree.process_frame

	var demo: Node = load("res://gore_demo.tscn").instantiate()
	tree.root.add_child(demo)
	tree.current_scene = demo
	for _warm in 120:
		await tree.process_frame

	var results := {}
	for level: String in LEVELS:
		WorldLook.set_quality_name(level)
		# Re-tune the live environment the same way the settings panel does.
		for child in demo.get_children():
			if child is WorldEnvironment and child.environment != null:
				WorldLook.apply_quality(child.environment, WorldLook.PRESETS.get("bone_yard", {}))
		for _settle in 45:
			await tree.process_frame

		var frames := 90
		var start := Time.get_ticks_usec()
		for _sample in frames:
			await tree.process_frame
		var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
		var fps := float(frames) / maxf(0.0001, elapsed)
		results[level] = fps
		print("  %-12s %6.1f fps  (%.2f ms/frame)" % [level, fps, elapsed / frames * 1000.0])

	var ultra: float = results["ULTRA"]
	var perf: float = results["PERFORMANCE"]
	print("PERFORMANCE is %.2fx ULTRA" % (perf / maxf(0.0001, ultra)))
	check(perf > ultra, "PERFORMANCE is actually faster than ULTRA — the setting does something")

	if failures.is_empty():
		print("sandbox perf: measured")
		tree.quit(0)
	else:
		print("sandbox perf FAILURES: ", failures)
		tree.quit(1)
