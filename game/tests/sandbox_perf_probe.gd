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
	get_tree().quit(0)
