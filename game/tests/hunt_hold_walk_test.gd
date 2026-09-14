extends Node

## The real startup loop needs its own held-W regression.  The derby has a
## vehicle test, but a report of "the main game freezes while driving it" can
## equally describe the first-person Hunt Grounds traversal.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var hunt: Node = (load("res://bone_yard_hunt.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hunt)
	get_tree().current_scene = hunt
	Input.action_press("move_forward")
	var hold_frames := int(OS.get_environment("ATG_WALK_FRAMES"))
	if hold_frames <= 0:
		hold_frames = 1200
	for frame in hold_frames:
		await get_tree().physics_frame
		if frame % 120 == 0:
			var body: CharacterBody3D = hunt.get("player_body")
			check(body != null and body.is_inside_tree(), "held-W keeps the hunter controller alive at frame %d" % frame)
			if body != null:
				check(not is_nan(body.global_position.x) and not is_nan(body.global_position.z), "held-W never produces an invalid hunter transform at frame %d" % frame)
	Input.action_release("move_forward")
	var final_body: CharacterBody3D = hunt.get("player_body")
	check(final_body != null and final_body.is_inside_tree(), "Hunt Grounds remains playable after a sustained forward hold")
	print("HUNT_HOLD_WALK_TEST_RESULT failures=", failures.size())
	hunt.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)
