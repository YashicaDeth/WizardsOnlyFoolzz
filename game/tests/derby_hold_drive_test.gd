extends Node

## Regression for the reported "hold W and the derby freezes" path.  This
## drives the real scene for twenty seconds, including the countdown and the
## active heat, instead of sampling `ArcadeVehicle` in isolation.

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
	var derby: Node = (load("res://rift_derby.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(derby)
	get_tree().current_scene = derby
	Input.action_press("move_forward")
	var hold_frames := int(OS.get_environment("ATG_DRIVE_FRAMES"))
	if hold_frames <= 0:
		hold_frames = 1200
	for frame in hold_frames:
		await get_tree().physics_frame
		if frame % 120 == 0:
			var boat: RigidBody3D = derby.get("boat")
			check(boat != null and is_instance_valid(boat), "hold-W keeps the player chassis alive at frame %d" % frame)
			if boat != null:
				check(not is_nan(boat.global_position.x) and not is_nan(boat.global_position.z), "hold-W never produces an invalid chassis transform at frame %d" % frame)
	Input.action_release("move_forward")
	var final_boat: RigidBody3D = derby.get("boat")
	check(final_boat != null and final_boat.is_inside_tree(), "derby remains running after a sustained forward hold")
	print("DERBY_HOLD_DRIVE_TEST_RESULT failures=", failures.size())
	derby.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)
