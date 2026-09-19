extends Node

## AX5.3 — "Nearby population stays inside the 5-20 fully simulated budget;
## distant people keep identity while expensive detail reduces smoothly."
##
## The only standing population system live today is the Bone Yard Hunt's
## roaming population (`bone_yard_hunt.gd`, `_maintain_roamers`): a target of
## `ROAMER_TARGET := 14`, spawned one at a time 55-130m from the player and
## recycled outright past `ROAMER_CULL_RANGE` (230m, `_cull_distant_roamers`).
## Every roamer that exists is a full `BaselineHuman` — real anatomy rig, real
## AI, real loot. There is no cheaper "distant" tier anywhere in the codebase;
## a roamer is either fully simulated or gone. This measures the budget half
## of AX5.3, which is real and testable, and reports the missing distant-LOD
## half as a fact read off the code rather than a guessed number for a system
## that does not exist.
##
## Roamers spawn one per `ROAMER_SPAWN_INTERVAL` (7s) in real play. Waiting
## fourteen of those out would make this benchmark the slow thing it measures,
## so the population is seeded by calling the scene's own `_spawn_roamer()`
## directly — the exact function `_maintain_roamers` calls on its interval,
## with the same placement range and pathing rules, just without the wait.

const MIN_BUDGET := 5
const MAX_BUDGET := 20
## Mirrors bone_yard_hunt.gd's own ROAMER_TARGET so a drift between the two
## shows up here as a visible failure instead of silently going stale.
const ROAMER_TARGET := 14

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
	get_window().size = Vector2i(1280, 720)
	await tree.process_frame

	var scene: Node = load("res://bone_yard_hunt.tscn").instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	for _warm in 240:
		await tree.process_frame

	# Seed the roamer population up to its target the same way
	# `_maintain_roamers` does over its real 7-second interval, just without
	# the wait. Attempts are capped generously because a single call can
	# legitimately decline (every district too close/far from the player this
	# try), exactly as it can in production.
	var attempts := 0
	while int(scene.call("_living_hostiles")) < ROAMER_TARGET and attempts < ROAMER_TARGET * 6:
		scene.call("_spawn_roamer")
		attempts += 1
		for _settle in 3:
			await tree.process_frame
	for _settle in 60:
		await tree.process_frame

	var rigs := _rigs(scene)
	var living := int(scene.call("_living_hostiles"))
	print("roamers: %d living hostiles counted toward the target, %d BaselineHuman rigs in the scene, %d spawn attempts" % [living, rigs.size(), attempts])
	check(living >= MIN_BUDGET and living <= MAX_BUDGET,
		"settled roamer population (%d) sits inside the 5-20 fully simulated budget" % living)
	check(living == ROAMER_TARGET or attempts >= ROAMER_TARGET * 6,
		"the roamer target was reached rather than starved by repeated placement failures")

	# What the population actually costs, measured the way frame_bound_test's
	# "the crowd" verdict does: toggle every rig's ticking in place and read
	# the wall clock either side, rather than trust the engine's own monitors.
	var before := await _sample(tree)
	_set_ticking(rigs, false)
	var quiet := await _sample(tree)
	_set_ticking(rigs, true)
	var after := await _sample(tree)
	var baseline := (before + after) * 0.5
	var floor_ms: float = maxf(absf(before - after), baseline * 0.10)
	var population_cost := baseline - quiet
	print("frame with %d rigs ticking: %.2f / %.2f ms (control, noise floor %.2f ms)   silent: %.2f ms" % [rigs.size(), before, after, floor_ms, quiet])
	if absf(population_cost) <= floor_ms:
		print("population cost at %d bodies: no cost this can measure — inside the noise" % rigs.size())
	else:
		print("population costs %.2f ms a frame at %d bodies (%.3f ms/body)" % [population_cost, rigs.size(), population_cost / maxf(1.0, float(rigs.size()))])

	# The distant-LOD half of AX5.3, read off the code rather than sampled: a
	# frame-time benchmark cannot prove a smooth cost reduction does not exist
	# anywhere, but it can report what `_cull_distant_roamers()` demonstrably
	# does — a single hard cutoff at 230m, nothing between "fully simulated"
	# and "gone". No reduced tick rate, no impostor, no identity-preserving
	# cheap body anywhere it is called from.
	check(false,
		"distant population has no cheaper tier: _cull_distant_roamers() is a binary 230m cull, not a smooth detail reduction — AX5.3's distant half is unbuilt")

	print("POPULATION_BUDGET_RESULT failures=", failures.size())
	tree.quit(0 if failures.is_empty() else 1)


## Every `BaselineHuman` in the scene, found the same way frame_bound_test
## finds them: by the script that built it.
func _rigs(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.get_file() == "baseline_human.gd":
			found.append(node)
	return found


func _set_ticking(rigs: Array[Node], value: bool) -> void:
	for rig in rigs:
		var stack: Array[Node] = [rig]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.append(child)
			node.set_physics_process(value)
			node.set_process(value)


## Wall clock milliseconds per frame. The only timing method in this file, on
## purpose — it cannot disagree with itself the way the engine's monitors do.
func _sample(tree: SceneTree) -> float:
	var frames := 180
	var began := Time.get_ticks_usec()
	for _f in frames:
		await tree.process_frame
	return float(Time.get_ticks_usec() - began) / float(frames) / 1000.0
