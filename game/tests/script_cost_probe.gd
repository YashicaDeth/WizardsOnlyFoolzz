extends Node

## Which of the `_update_*` calls is actually the frame.
##
## `sandbox_perf_probe` did this for geometry and named
## `ProceduralAshbloomDistricts` as the owner of 2141 meshes. Script time has
## never had the equivalent, so "script cost is unattributed" has been the
## largest open item in the brief since the day it was measured.
##
## One thing this is also checking, which nobody has: the brief says *"`process`
## at 20ms is the ~25 `_update_*` calls in `bone_yard_hunt._physics_process`"*.
## Those two halves cannot both be right. Work done in `_physics_process` is
## counted by `TIME_PHYSICS_PROCESS`, not by `TIME_PROCESS`, and the same
## measurement put physics at 10.94ms against process at 20.16ms. So either the
## calls are not where the 20ms is, or the attribution was wrong from the
## start. The totals below are compared against both monitors to say which.
##
## Run it **windowed**. Headless never calls `_draw()`, so every HUD panel
## measures as free -- and `_update_hud()` is one of the calls under suspicion.

const SETTLE_FRAMES := 120
const SAMPLE_FRAMES := 240


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var scene: PackedScene = load("res://bone_yard_hunt.tscn")
	if scene == null:
		print("SCRIPT_COST_FAILED could not load bone_yard_hunt.tscn")
		get_tree().quit(1)
		return
	var hunt := scene.instantiate()
	add_child(hunt)

	# Settle before measuring: the first frames build the districts and are not
	# what anybody plays.
	for frame in SETTLE_FRAMES:
		await get_tree().process_frame

	ScriptCost.reset()
	ScriptCost.enable()
	var process_ms := 0.0
	var physics_ms := 0.0
	var fps_total := 0.0
	for frame in SAMPLE_FRAMES:
		await get_tree().process_frame
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		fps_total += Performance.get_monitor(Performance.TIME_FPS)
	ScriptCost.disable()

	var samples := float(SAMPLE_FRAMES)
	var process_avg := process_ms / samples
	var physics_avg := physics_ms / samples
	var measured := ScriptCost.measured_ms()
	var headless := DisplayServer.get_name() == "headless"
	print("SCRIPT_COST mode=%s fps=%.1f process=%.2fms physics=%.2fms" % [
		"HEADLESS (draw not counted)" if headless else "windowed",
		fps_total / samples, process_avg, physics_avg,
	])
	print("SCRIPT_COST instrumented=%.2fms over %d physics frames" % [measured, ScriptCost.frames()])
	# The gap is what the laps did not wrap. A small one means the table below
	# is the whole story; a large one means the expensive thing is somewhere
	# else entirely, and printing a ranking without saying so would be the more
	# misleading of the two outcomes.
	print("SCRIPT_COST unaccounted_vs_physics=%.2fms unaccounted_vs_process=%.2fms" % [
		physics_avg - measured, process_avg - measured,
	])

	var ranked: Array = ScriptCost.ranked()
	if ranked.is_empty():
		print("SCRIPT_COST nothing recorded -- the hunt never reached _physics_process")
		get_tree().quit(1)
		return
	print("SCRIPT_COST_TABLE  us/frame  share  calls/frame  label")
	for entry: Dictionary in ranked:
		print("SCRIPT_COST_ROW %9.1f  %5.1f%%  %6.2f       %s" % [
			float(entry.per_frame_us), float(entry.share) * 100.0,
			float(entry.calls_per_frame), str(entry.label),
		])
	var worst: Dictionary = ranked[0]
	print("SCRIPT_COST_WORST %s at %.2fms/frame (%.1f%% of instrumented)" % [
		str(worst.label), float(worst.per_frame_us) / 1000.0, float(worst.share) * 100.0,
	])
	get_tree().quit(0)
