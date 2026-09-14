extends Node

## Greg: "the gore sandbox is completlyh broken and it crashed after i spammed
## the gun a couple times". Reproduce it before theorising about it.
##
## Fires as fast as the input path allows rather than on a comfortable cadence,
## because "spammed" is the condition and a shot every half second is a different
## test that would pass.

var demo: Node
var shots := 0

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	for _s in 150:
		await get_tree().process_frame
	print("sandbox up, firing")

	# Every frame, at the bodies, for ten seconds of real frames.
	for burst in 600:
		if not is_instance_valid(demo):
			print("DEMO FREED ITSELF at shot %d" % shots)
			break
		demo.call("_fire")
		shots += 1
		await get_tree().process_frame
		if shots % 100 == 0:
			print("  %d shots, %d nodes, %.1f MB video" % [shots,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
	print("survived %d shots" % shots)
	print("GUN_SPAM_REPRO_RESULT done")
	get_tree().quit(0)
