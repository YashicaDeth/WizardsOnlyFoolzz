extends Node

## Who is running `_process` at all, before anybody instruments anything.
##
## `script_cost_probe` attributed `_physics_process` and found the twenty-nine
## `_update_*` calls come to 6.20ms of a 19.49ms frame -- so the larger half,
## now about 10.9ms after Codex's three skip-work commits, belongs to other
## nodes' `_process` callbacks. `bone_yard_hunt` has no `_process` of its own,
## so none of it is the hunt's.
##
## Instrumenting a guess would mean editing a dozen systems to find out which
## two mattered. This counts first and edits nothing: every node in the scene
## that is actually processing, grouped by the script that makes it process.
## A class with four hundred instances is worth wrapping and a singleton is
## not, and that is knowable without touching either.
##
## Run it **windowed**. Headless never draws, so anything whose `_process`
## exists to feed a `_draw` will look free.

const SETTLE_FRAMES := 120


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var scene: PackedScene = load("res://bone_yard_hunt.tscn")
	if scene == null:
		print("PROCESS_CENSUS_FAILED could not load bone_yard_hunt.tscn")
		get_tree().quit(1)
		return
	var hunt := scene.instantiate()
	add_child(hunt)
	for frame in SETTLE_FRAMES:
		await get_tree().process_frame

	var processing: Dictionary = {}
	var physics: Dictionary = {}
	var total_nodes := 0
	for node in _every(hunt):
		total_nodes += 1
		var who := _script_name(node)
		# `is_processing()` is the honest question: a node with a `_process`
		# that has been switched off costs nothing and must not be counted, and
		# one switched on by something else must be.
		if node.is_processing():
			processing[who] = int(processing.get(who, 0)) + 1
		if node.is_physics_processing():
			physics[who] = int(physics.get(who, 0)) + 1

	var process_total := 0
	for key in processing:
		process_total += int(processing[key])
	var physics_total := 0
	for key in physics:
		physics_total += int(physics[key])
	print("PROCESS_CENSUS nodes=%d processing=%d physics_processing=%d" % [total_nodes, process_total, physics_total])
	print("PROCESS_CENSUS fps=%.1f process=%.2fms physics=%.2fms" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	])
	_rank("PROCESS", processing)
	_rank("PHYSICS", physics)

	# The other half of the frame, and on this evidence the larger one. Eighty
	# processing nodes cannot be 10.9ms, but 5984 draw calls and 3133 visible
	# shadow casters can: every caster makes the scene render again into a
	# shadow map. Charged to the top-level owner the same way
	# `sandbox_perf_probe` charges meshes, so the answer is a thing that can be
	# switched off rather than a number.
	var casters: Dictionary = {}
	var caster_total := 0
	for node in _every(hunt):
		if not (node is MeshInstance3D):
			continue
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var owner_name := _top_owner(mesh, hunt)
		casters[owner_name] = int(casters.get(owner_name, 0)) + 1
		caster_total += 1
	print("PROCESS_CENSUS shadow_casters=%d" % caster_total)
	_rank("CASTER", casters)
	# One level deeper inside the two owners that cannot plausibly need them,
	# so the fix is aimed at nodes rather than at a subsystem name.
	for branch in ["HUD", "SubstanceStation", "ProceduralAshbloomDistricts"]:
		var root := hunt.get_node_or_null(NodePath(branch))
		if root == null:
			continue
		var inner: Dictionary = {}
		for node in _every(root):
			if not (node is MeshInstance3D):
				continue
			var mesh := node as MeshInstance3D
			if not mesh.is_visible_in_tree():
				continue
			var parent := mesh.get_parent()
			inner[str(parent.name) if parent != null else "?"] = int(inner.get(str(parent.name) if parent != null else "?", 0)) + 1
		print("PROCESS_CENSUS_INSIDE %s" % branch)
		_rank("INSIDE", inner)
	get_tree().quit(0)


## The subsystem that built it: the highest ancestor below the scene root.
func _top_owner(node: Node, root: Node) -> String:
	var walk := node
	var last := node.name
	while walk != null and walk.get_parent() != null and walk.get_parent() != root:
		walk = walk.get_parent()
		last = walk.name
	return str(last)


func _rank(label: String, counts: Dictionary) -> void:
	var ranked: Array = []
	for key in counts:
		ranked.append({"who": str(key), "count": int(counts[key])})
	ranked.sort_custom(func(a, b): return int(a.count) > int(b.count))
	for entry in ranked.slice(0, 14):
		print("PROCESS_CENSUS_%s %6d  %s" % [label, int(entry.count), str(entry.who)])


## What makes this node process: its script where it has one, its class where
## it does not. A node with no script running `_process` is the engine's own
## and nothing here can change it.
func _script_name(node: Node) -> String:
	var script: Script = node.get_script() as Script
	if script == null:
		return "(engine) %s" % node.get_class()
	var path := str(script.resource_path)
	return path.get_file() if not path.is_empty() else "(inline script)"


func _every(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_every(child))
	return out
