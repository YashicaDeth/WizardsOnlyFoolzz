extends Node

## "the gore sandbox is completlyh broken and it crashed after i spammed the gun
## a couple times". Firing alone survives 600 rounds, so this does what spamming
## a sandbox actually looks like: shoot, blast, cut, x-ray, reset, in a mix, and
## watch the error stream rather than only waiting for a segfault. A push_error
## that does not crash is still the thing that is broken.

var demo: Node
var step := 0

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	for _s in 150:
		await get_tree().process_frame

	for round_index in 240:
		if not is_instance_valid(demo):
			print("!!! DEMO INVALID at step %d" % step); break
		var camera_at := Vector3(0, 1.0, 0)
		match step % 8:
			0, 1, 2, 3: demo.call("_fire")
			4: demo.call("_explode", camera_at + Vector3(randf_range(-4, 4), 0.4, randf_range(-4, 4)), 92.0)
			5: demo.call("_cut")
			6: demo.call("_set_xray", step % 16 == 6)
			7:
				if step % 40 == 7:
					demo.call("_reset")
		step += 1
		await get_tree().process_frame
		if step % 60 == 0:
			print("  step %3d | nodes %5d | vram %6.1f MB" % [step,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
	print("survived %d mixed steps" % step)
	print("SANDBOX_CHAOS_RESULT done")
	get_tree().quit(0)
