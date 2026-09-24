extends Node

## AG5.33. The range teaches the same contact-range C clinch as the Hunt.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame
	demo.set_physics_process(false)

	var subject: Dictionary = demo.bodies[0]
	var holder := subject.holder as Node3D
	var rig := subject.rig as BaselineHuman
	var motion := subject.motion as HunterBodyMotion
	holder.global_position = Vector3(demo.eye.x, 0.9, demo.eye.z - 1.5)
	check(demo._begin_grapple(0), "a living body inside contact range can be clinched")
	check(demo.grapple_index == 0 and motion.grapple_blend == 1.0, "the exact anatomy body enters the shared captive pose")
	check(not demo._begin_dodge(Vector3.RIGHT), "a clinch owns the body and refuses an overlapping dodge")

	demo.eye += Vector3(1.2, 0.0, -0.6)
	var before := holder.global_position
	demo._update_training_bodies(0.1)
	check(holder.global_position.distance_to(before) > 0.25, "moving the player physically drags the captive")
	check(holder.global_position.distance_to(demo.eye) < 2.0, "the captive remains at a stable body-relative hold distance")

	var blood_before := rig.anatomy.blood_remaining
	check(demo._grapple_pressure(), "LMB applies real clinch pressure to the held anatomy")
	check(rig.anatomy.blood_remaining <= blood_before, "clinch pressure resolves through the anatomy component")
	demo._release_grapple("TEST RELEASE")
	check(demo.grapple_index == -1 and motion.grapple_blend == 0.0, "C release returns ownership and clears the captive pose")

	holder.global_position = Vector3(demo.eye.x, 0.9, demo.eye.z - 5.0)
	check(not demo._begin_grapple(0), "a distant body cannot be pulled into a remote grapple")
	check(demo.mode_button.text.begins_with("[H]"), "training mode moved to H so C means grapple everywhere")

	print("GORE_SANDBOX_GRAPPLE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
