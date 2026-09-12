extends Node

## Greg, second playtest: *"the map is incredibly laggy right now"*. This
## measures it rather than trusting that a fix helped — frame time with the map
## shut, then with it open, at three zooms, so the cost of the map is the
## difference rather than a number with nothing to compare it to.

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
	await tree.process_frame
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	tree.root.add_child(hunt)
	tree.current_scene = hunt
	for _settle in 90:
		await tree.process_frame

	var map: Control = hunt.get("living_map")
	# Walk, so the veil has a real edge to compute rather than a uniform field.
	for step in 40:
		map.observe(Vector3(float(step) * 5.0, 0.0, 22.0 - float(step) * 3.0), 0.4)

	var shut := await _sample(tree, 90)
	print("closed:  %.2f ms/frame" % shut)

	hunt.call("_toggle_panel", "map")
	for _settle in 20:
		await tree.process_frame

	var worst := 0.0
	for zoom in [0.7, 1.25, 2.6]:
		map.set("zoom", zoom)
		for _settle in 12:
			await tree.process_frame
		var open := await _sample(tree, 90)
		worst = maxf(worst, open)
		print("open  @%.2f zoom:  %.2f ms/frame   (map costs %.2f ms)" % [zoom, open, open - shut])

	# The bar: the map must not cost more than the whole rest of the frame.
	# A panel you opened should not halve the framerate.
	check(worst - shut < shut, "the map costs less than the game it is drawn over")
	check(worst < 33.0, "the map holds above 30fps at every zoom")
	if failures.is_empty():
		print("map perf: fine")
		tree.quit(0)
	else:
		print("map perf FAILURES: ", failures)
		tree.quit(1)


func _sample(tree: SceneTree, frames: int) -> float:
	# Discard the first few: the first redraw after a state change rebuilds
	# caches and is not what the player experiences while looking at it.
	for _warm in 10:
		await tree.process_frame
	var began := Time.get_ticks_usec()
	for _frame in frames:
		await tree.process_frame
	return float(Time.get_ticks_usec() - began) / float(frames) / 1000.0
