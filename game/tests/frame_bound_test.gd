extends Node

## X1.2 — what the frame is actually bound by.
##
## X1.1 measured the scenes and then flagged its own frame timing as untrusted,
## because it reported 60 fps and a 37 ms process time in the same breath and
## those cannot both be true. Running `frame_profile` on the Hunt today
## reproduces the same shape: 24.07 ms of wall clock against 20.02 ms of
## reported script and 13.66 ms of reported physics, which is 34 ms of work
## inside a 24 ms frame. The monitors are not a budget you can hold anything
## to, so nothing downstream of them is worth writing down.
##
## The fix is not a better monitor. It is to stop asking the engine where the
## time went and to change one thing at a time, timing the whole frame on a
## wall clock either side:
##
## - **Render scale.** Everything the GPU does scales with pixels. Shrinking
##   the 3D buffer to a quarter and getting the same frame time means the
##   pixels were never the cost.
## - **Physics rate.** Dropping the tick rate removes physics work without
##   removing anything else.
##
## Between them those two answer the only question that matters before any
## optimisation is attempted: is this frame bound by the GPU, by physics, or
## by script? Guessing that wrong is how a week gets spent on shaders for a
## frame that was never fill-bound.
##
## Vsync is off throughout. A benchmark behind a present cap measures the
## monitor — `frame_cost_test` learned that the hard way and its comment says
## so; this is the same lesson applied to the scene Greg actually plays.

## Sampled per configuration. This scene is noisy — repeat samples of an
## unchanged configuration land several milliseconds apart — so the window is
## longer than the usual 180. It does not remove the spread, which is why
## `_verdict()` reports a noise floor rather than trusting a single pair.
const FRAMES := 300
## Frames discarded after a change before sampling. A scale change reallocates
## buffers and the first frames after it are the reallocation, not the cost.
const SETTLE := 45

const SCALES := [1.0, 0.75, 0.5, 0.25]
## The default is 60. 10 removes five sixths of the physics work without
## touching anything else in the scene.
const SLOW_PHYSICS := 10

## `--soak`: how many times to look, and how many frames to wait between
## looks. Twelve rounds of 600 idle frames is several minutes of a world left
## alone — long enough for an accumulation to separate itself from a world
## that simply takes a while to finish populating.
const SOAK_ROUNDS := 12
const SOAK_GAP := 600


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var scene_path := "res://bone_yard_hunt.tscn"
	var width := 1280
	var height := 720
	var soak := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
		elif argument.begins_with("--width="):
			width = int(argument.trim_prefix("--width="))
		elif argument.begins_with("--height="):
			height = int(argument.trim_prefix("--height="))
		elif argument == "--soak":
			soak = true
	get_window().size = Vector2i(width, height)
	await tree.process_frame

	var scene: Node = load(scene_path).instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	# Terrain, shaders and the spawn settle slowly. Measuring during that
	# measures loading.
	for _warm in 240:
		await tree.process_frame

	var view := get_viewport()
	print("scene: %s at %dx%d, vsync off" % [scene_path, width, height])
	print("")

	if soak:
		await _soak(tree, scene)
		print("FRAME_BOUND_RESULT done")
		tree.quit(0)
		return

	# --- is it the pixels -------------------------------------------------
	#
	# The scene does not hold still while this runs: gore accumulates, bodies
	# spawn, collision pairs climb, so a sample taken later is a sample of a
	# busier world. A sweep with no control reads that drift as if it were the
	# thing being swept. So full scale is measured at both ends and the two are
	# printed against each other — every other number in the sweep has to be
	# read against that drift, not against zero.
	print("render scale sweep — if these are flat, the GPU was never the cost")
	var by_scale := {}
	var order: Array = [1.0] + SCALES.filter(func(s: float) -> bool: return s != 1.0) + [1.0]
	for index in order.size():
		var scale: float = order[index]
		view.scaling_3d_scale = scale
		for _settle in SETTLE:
			await tree.process_frame
		var ms := await _sample(tree)
		var label := "scale %.2f" % scale
		if index == 0:
			label = "scale %.2f (first)" % scale
		elif index == order.size() - 1:
			label = "scale %.2f (control)" % scale
		else:
			by_scale[scale] = ms
		if index == 0:
			by_scale["first"] = ms
		elif index == order.size() - 1:
			by_scale["control"] = ms
		print("  %-22s %4dx%-4d  %7.2f ms   %6.1f fps   %5d draws   %4d pairs" % [
			label, int(width * scale), int(height * scale), ms, 1000.0 / maxf(ms, 0.001),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)])

	var first: float = float(by_scale["first"])
	var control: float = float(by_scale["control"])
	var drift := control - first
	print("")
	print("drift over the sweep: %+.2f ms at the same scale (%.2f -> %.2f)" % [drift, first, control])

	# --- is it the physics ------------------------------------------------
	# Compared against the *control*, not the first sample, so the scene is the
	# same age on both sides of the only change being made.
	Engine.physics_ticks_per_second = SLOW_PHYSICS
	for _settle in SETTLE:
		await tree.process_frame
	var slow_physics := await _sample(tree)
	Engine.physics_ticks_per_second = 60
	print("")
	print("physics rate — 60 Hz %7.2f ms   vs %d Hz %7.2f ms" % [
		control, SLOW_PHYSICS, slow_physics])

	# --- the verdict, stated ----------------------------------------------
	# The quarter-scale sample sits mid-sweep, so it carries roughly half the
	# drift; subtracting that is the fairest reading available without a fresh
	# process per configuration.
	var quarter: float = float(by_scale[0.25]) - drift * 0.5
	var pixel_share := 1.0 - (quarter / maxf(first, 0.001))
	var physics_share := 1.0 - (slow_physics / maxf(control, 0.001))
	print("")
	print("at a quarter of the pixels the frame is %.0f%% shorter (drift-adjusted)" % (pixel_share * 100.0))
	print("at a sixth of the physics rate it is %.0f%% shorter" % (physics_share * 100.0))
	var bound := "SCRIPT"
	if pixel_share >= 0.35 and pixel_share >= physics_share:
		bound = "GPU / fill"
	elif physics_share >= 0.25:
		bound = "PHYSICS"
	print("FRAME_BOUND_BY %s" % bound)

	# --- server work, or script running at the physics rate ---------------
	#
	# Lowering the tick rate removes two things at once: the physics server's
	# own work, and every `_physics_process` in the game, which is where the
	# rigs do their motion and their thinking. "Physics-bound" is therefore
	# ambiguous until the crowd is taken out separately. If silencing the
	# bodies recovers most of what the tick rate recovered, the cost is
	# GDScript on the bodies and no amount of collision tuning will touch it.
	var rigs := _rigs(scene)
	if not rigs.is_empty():
		var crowd_before := await _settle_and_sample(tree)
		_set_ticking(rigs, false)
		var quiet := await _settle_and_sample(tree)
		_set_ticking(rigs, true)
		var crowd_after := await _settle_and_sample(tree)
		print("")
		print("the crowd — %d rigs, physics processing toggled in place" % rigs.size())
		_verdict("the crowd", crowd_before, crowd_after, quiet)

	# --- what the body hitboxes cost -------------------------------------
	#
	# Measured by toggling them in place rather than by comparing two runs.
	# Run-to-run spread on this scene is wider than the effect being looked
	# for, so a before-and-after across processes cannot tell a fix from the
	# weather; toggling inside one process, back to back, with a return to
	# the starting state as the control, can.
	var hitboxes := _hitboxes(scene)
	if not hitboxes.is_empty():
		var off_before := await _settle_and_sample(tree)
		_set_monitoring(hitboxes, true)
		var on_ms := await _settle_and_sample(tree)
		_set_monitoring(hitboxes, false)
		var off_after := await _settle_and_sample(tree)
		print("")
		print("body hitbox monitoring — %d areas" % hitboxes.size())
		_verdict("monitoring", off_before, off_after, on_ms)

	# Reported beside the wall clock rather than instead of it, so the
	# disagreement stays on the record instead of being rediscovered.
	print("")
	print("engine's own monitors, for comparison only:")
	print("  reported script   %7.2f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0))
	print("  reported physics  %7.2f ms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0))
	print("  reported fps      %7.1f" % Engine.get_frames_per_second())
	print("  nodes             %7d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("  draw calls        %7d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("  primitives        %7d" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("  video memory      %7.1f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	print("  collision pairs   %7d" % Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))

	_census(scene)
	print("FRAME_BOUND_RESULT done")
	tree.quit(0)


## Who the physics bodies belong to.
##
## "Physics is the cost" is not actionable; "three hundred of them are gore
## chunks that never despawn" is. Bodies are attributed to the nearest
## ancestor that carries a script, because that is the thing that decided to
## spawn them — grouping by class only ever says `RigidBody3D`, which nobody
## can act on.
func _census(root: Node) -> void:
	var by_class := {}
	var by_owner := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is CollisionObject3D):
			continue
		var cls := node.get_class()
		by_class[cls] = int(by_class.get(cls, 0)) + 1
		by_owner[_blame(node)] = int(by_owner.get(_blame(node), 0)) + 1

	print("")
	print("physics bodies in the scene, by class:")
	for cls: String in _by_count(by_class):
		print("  %-24s %5d" % [cls, by_class[cls]])
	print("physics bodies by the script that owns them:")
	for owner_name: String in _by_count(by_owner):
		print("  %-40s %5d" % [owner_name, by_owner[owner_name]])


## The nearest scripted ancestor, which is the thing that spawned it.
func _blame(node: Node) -> String:
	var walk: Node = node
	while walk != null:
		var script: Script = walk.get_script() as Script
		if script != null:
			return script.resource_path.get_file()
		walk = walk.get_parent()
	return "(unscripted)"


func _by_count(counts: Dictionary) -> Array:
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(counts[a]) > int(counts[b]))
	return keys


## Does standing still get worse, and does it ever stop getting worse?
##
## Every sweep above drifted by six to nine milliseconds at a fixed scale while
## nothing was being asked of the game, with collision pairs climbing the whole
## time. That is either a world settling into its populated state and levelling
## off, which is fine, or an accumulation with no ceiling, which is the
## slowness Greg is describing after a few minutes of play. The difference is
## the shape of this curve and nothing else, so it is measured directly rather
## than argued about.
func _soak(tree: SceneTree, scene: Node) -> void:
	print("soak — nothing is asked of the game, it is just left running")
	print("  %6s %9s %8s %8s %7s %7s" % ["min", "ms/frame", "nodes", "orphans", "pairs", "people"])
	var began := Time.get_ticks_usec()
	var first := 0.0
	for round_index in SOAK_ROUNDS:
		var ms := await _sample(tree)
		if round_index == 0:
			first = ms
		var people := 0
		var stack: Array[Node] = [scene]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.append(child)
			if node is CharacterBody3D:
				people += 1
		print("  %6.1f %9.2f %8d %8d %7d %7d" % [
			float(Time.get_ticks_usec() - began) / 60000000.0,
			ms,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
			people])
		for _idle in SOAK_GAP:
			await tree.process_frame
	print("")
	print("SOAK_DRIFT %+.2f ms from first sample to last" % (await _sample(tree) - first))


## Report one toggled experiment against its own noise.
##
## The scene does not produce the same number twice: samples of an unchanged
## configuration land five milliseconds apart. An A/B that prints only the
## difference invites reading that spread as a result, which is how a change
## that does nothing gets committed with a performance story attached to it.
## So the two control samples set a noise floor, and an effect smaller than
## the floor is reported as what it is — not measurable here — rather than as
## a small win or a small loss.
## `without_it` is the sample taken with the thing switched off, so a frame
## that got shorter means the thing was costing that much.
func _verdict(label: String, control_a: float, control_b: float, without_it: float) -> void:
	var baseline := (control_a + control_b) * 0.5
	# Two controls are a thin estimate of a spread, and on a quiet pair they
	# can read narrower than the run-to-run variation actually is — which lets
	# noise back in wearing a result's clothes. So the floor never goes below
	# a tenth of the frame. That is this harness's honest resolution on this
	# scene: it can settle the physics tick rate, which moves half the frame,
	# and it cannot settle a two-millisecond question. Saying so is more
	# useful than a number that changes sign between runs.
	var floor_ms: float = maxf(absf(control_a - control_b), baseline * 0.10)
	var saved := baseline - without_it
	print("  with it    %7.2f ms and %7.2f ms   (noise floor %.2f ms)" % [control_a, control_b, floor_ms])
	print("  without it %7.2f ms" % without_it)
	if absf(saved) <= floor_ms:
		print("  %s: no cost this can measure — %.2f ms is inside the noise" % [label, absf(saved)])
	elif saved > 0.0:
		print("  %s costs %.2f ms a frame" % [label, saved])
	else:
		print("  %s: removing it made the frame %.2f ms LONGER, which needs explaining" % [label, -saved])


## Every `BaselineHuman` in the scene, found by the script that built it.
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


## Silence a rig and everything hanging off it. Both callbacks, because a rig's
## work is split across `_process` and `_physics_process` and the question is
## what the bodies cost in total, not which half of the frame they spend it in.
func _set_ticking(rigs: Array[Node], value: bool) -> void:
	for rig in rigs:
		var stack: Array[Node] = [rig]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.append(child)
			node.set_physics_process(value)
			node.set_process(value)


## Every body hitbox in the scene. Named rather than typed, because a rig's
## zone hitboxes are the `Area3D`s this is about and other areas in the world
## are not.
func _hitboxes(root: Node) -> Array[Area3D]:
	var found: Array[Area3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is Area3D and node.name.ends_with("_hitbox"):
			found.append(node as Area3D)
	return found


func _set_monitoring(areas: Array[Area3D], value: bool) -> void:
	for area in areas:
		if is_instance_valid(area):
			area.monitoring = value


func _settle_and_sample(tree: SceneTree) -> float:
	for _settle in SETTLE:
		await tree.process_frame
	return await _sample(tree)


## Wall clock milliseconds per frame, averaged over `FRAMES`. Deliberately the
## only timing method in this file: it cannot disagree with itself.
func _sample(tree: SceneTree) -> float:
	var began := Time.get_ticks_usec()
	for _frame in FRAMES:
		await tree.process_frame
	return float(Time.get_ticks_usec() - began) / float(FRAMES) / 1000.0
