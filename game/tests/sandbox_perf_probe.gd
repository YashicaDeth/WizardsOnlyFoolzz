extends Node

## What the hunt actually costs, per frame, with numbers.
##
## "Insanely laggy" is a symptom with at least four unrelated causes -- script
## time, draw calls, node count, physics -- and they want opposite fixes. This
## loads the sandbox, lets it settle, then samples Godot's own performance
## monitors so the next change is aimed at whichever one is actually large.
##
## Run it windowed, not headless: headless skips rendering entirely, so a scene
## that is GPU-bound reports as perfectly healthy.

const SETTLE_FRAMES := 90
const SAMPLE_FRAMES := 180


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var scene: PackedScene = load("res://bone_yard_hunt.tscn")
	if scene == null:
		print("PROBE_FAILED could not load bone_yard_hunt.tscn")
		get_tree().quit(1)
		return
	var hunt := scene.instantiate()
	add_child(hunt)

	for frame in SETTLE_FRAMES:
		await get_tree().process_frame

	var process_ms := 0.0
	var physics_ms := 0.0
	var draw_calls := 0.0
	var objects := 0.0
	var primitives := 0.0
	var worst_process := 0.0
	var fps_total := 0.0
	for frame in SAMPLE_FRAMES:
		await get_tree().process_frame
		var this_process: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		process_ms += this_process
		worst_process = maxf(worst_process, this_process)
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		fps_total += Performance.get_monitor(Performance.TIME_FPS)

	var samples := float(SAMPLE_FRAMES)
	print("SANDBOX_PERF fps=%.1f process=%.2fms worst_process=%.2fms physics=%.2fms" % [
		fps_total / samples, process_ms / samples, worst_process, physics_ms / samples,
	])
	print("SANDBOX_PERF draw_calls=%d objects=%d primitives=%d nodes=%d orphans=%d" % [
		int(draw_calls / samples), int(objects / samples), int(primitives / samples),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	])
	print("SANDBOX_PERF static_mem=%.1fMB rigid_bodies=%d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
	])
	# Which subsystem owns the geometry. 6280 draw calls over 8133 nodes is
	# near enough one call per node, which is what a scene with no instancing
	# looks like -- but "add instancing" is not actionable until it is known
	# what is being drawn and by whom.
	var owners: Dictionary = {}
	var multi := 0
	var casters := 0
	_attribute(hunt, hunt, owners)
	var hidden := 0
	for node in _every(hunt):
		if node is MultiMeshInstance3D:
			multi += 1
		elif node is MeshInstance3D:
			# Only what is actually drawn. Counting every MeshInstance3D
			# overstated this badly: a body builds its organs and bone frames
			# `visible = false` and they cost nothing until something opens the
			# body, so most of a rig's ~125 meshes are not in the frame at all.
			if not (node as Node3D).is_visible_in_tree():
				hidden += 1
			elif (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				casters += 1
	var ranked: Array = []
	for key in owners:
		ranked.append({"owner": str(key), "meshes": int(owners[key])})
	ranked.sort_custom(func(a, b): return int(a.meshes) > int(b.meshes))
	print("SANDBOX_PERF multimesh=%d visible_shadow_casters=%d hidden_meshes=%d" % [multi, casters, hidden])
	for entry in ranked.slice(0, 12):
		print("SANDBOX_OWNER %-34s %d" % [str(entry.owner), int(entry.meshes)])
	get_tree().quit(0)


## Every MeshInstance3D, charged to the highest ancestor below the scene root.
## That is the subsystem that built it, which is the thing that would have to
## change for it to be drawn differently.
func _attribute(node: Node, root: Node, owners: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (child as Node3D).is_visible_in_tree():
			var owner_name := _top_owner(child, root)
			owners[owner_name] = int(owners.get(owner_name, 0)) + 1
		_attribute(child, root, owners)


func _top_owner(node: Node, root: Node) -> String:
	var walk := node
	var last := node.name
	while walk != null and walk.get_parent() != null and walk.get_parent() != root:
		walk = walk.get_parent()
		last = walk.name
	return str(last)


func _every(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_every(child))
	return out
