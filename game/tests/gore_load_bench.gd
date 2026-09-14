extends Node

## Greg: *"gore sandbox is just m,ad laggy have alook"*.
##
## The sandbox measures 124-153 fps at idle, so the cost is not the arena — it
## arrives with the gore. This drives real gore through the sandbox's own
## `_explode()` and measures either side, reporting draw calls and object counts
## alongside frame time, because "it got slower" is not a finding and "it went
## from 900 to 4000 draw calls" is.
##
## Run windowed, not headless: a headless run has no renderer and every number
## here would be a lie.

const SAMPLE_FRAMES := 120

var demo: Node


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = Vector2i(1920, 1080)

	demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	for _settle in 180:
		await get_tree().process_frame

	var idle := await _sample("IDLE")

	# Each blast is the F key: a 92-force explosion at the camera, which is the
	# single most gore the sandbox can produce in one input.
	var rounds := 6
	for i in rounds:
		var at: Vector3 = Vector3(0, 0.6, 0)
		if demo.has_method("_explode"):
			demo.call("_explode", at, 92.0)
		for _spread in 45:
			await get_tree().process_frame
		var tag := "AFTER BLAST %d" % (i + 1)
		var s := await _sample(tag)
		print("  delta vs idle: %+.2f ms/frame, %+d draw calls, %+d objects" % [
			s["ms"] - idle["ms"], s["draws"] - idle["draws"], s["objects"] - idle["objects"]])

	print("GORE_LOAD_BENCH_RESULT done")
	get_tree().quit(0)


func _sample(label: String) -> Dictionary:
	# Warm up so the first frame after a spawn burst is not counted as the
	# steady state — allocation spikes are real but they are a different bug.
	for _warm in 20:
		await get_tree().process_frame
	var total := 0.0
	var worst := 0.0
	for _frame in SAMPLE_FRAMES:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		total += dt
		worst = maxf(worst, dt)
	var ms := (total / float(SAMPLE_FRAMES)) * 1000.0
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var nodes := _count_nodes(demo)
	var meshes := _count_meshes(demo)
	print("%-16s %6.2f ms  %5.1f fps  worst %6.2f ms | draws %5d  objects %5d  prims %8d | nodes %5d  meshinstances %5d" % [
		label, ms, 1000.0 / maxf(ms, 0.001), worst * 1000.0, draws, objects, prims, nodes, meshes])
	return {"ms": ms, "draws": draws, "objects": objects, "nodes": nodes, "meshes": meshes}


func _count_nodes(root: Node) -> int:
	var n := 1
	for child in root.get_children():
		n += _count_nodes(child)
	return n


func _count_meshes(root: Node) -> int:
	var n := 1 if root is MeshInstance3D else 0
	for child in root.get_children():
		n += _count_meshes(child)
	return n
