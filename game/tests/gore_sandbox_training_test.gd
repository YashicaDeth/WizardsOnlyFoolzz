extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo: Node = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame
	check(demo.bodies.size() == demo.BODY_COUNT, "the training switch owns the real seven anatomy bodies")
	check(not demo.enemies_enabled and demo.mode_button.text.contains("DUMMIES"), "the safe default is visibly DUMMIES")

	var subject: Dictionary = demo.bodies[0]
	var holder := subject.holder as Node3D
	var motion := subject.motion as HunterBodyMotion
	check(motion != null, "every sandbox body owns the shared gameplay animator")
	holder.global_position = Vector3(demo.eye.x + 5.0, 0.9, demo.eye.z)
	var before := holder.global_position
	demo._set_enemies_enabled(true)
	demo._update_training_bodies(0.5)
	check(demo.mode_button.text.contains("ENEMIES"), "the same physical control visibly switches to ENEMIES")
	check(holder.global_position.distance_to(demo.eye) < before.distance_to(demo.eye), "a live enemy body physically closes on the player")
	check(motion.gait_phase > 0.0 and absf(subject.rig.parts.left_leg.rotation.x) > 0.05,
		"closing distance drives a visible running stride through the real limbs")

	holder.global_position = Vector3(demo.eye.x + 1.0, 0.9, demo.eye.z)
	subject["attack_ready"] = 0.0
	var health_before: int = demo.simulation_health
	demo._update_training_bodies(0.05)
	check(demo.simulation_health < health_before, "a close enemy lands a timed simulation hit")
	check(motion.attack_time > 0.0 and motion.attack_kind == "melee",
		"the simulation hit has a committed anticipation and follow-through animation")
	demo._set_enemies_enabled(false)
	var held := holder.global_position
	demo._update_training_bodies(1.0)
	check(holder.global_position.is_equal_approx(held), "DUMMY mode stops pursuit immediately")

	demo.stance_height = 1.68
	demo.eye.y = 1.68
	demo.jump_queued = true
	demo._physics_process(0.05)
	check(demo.vertical_velocity > 0.0 and demo.eye.y > 1.68, "the sandbox now has a real upward jump state")

	print("GORE_SANDBOX_TRAINING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
