extends Node

## AG5.34. Sandbox targets visibly answer impact direction and severity using
## the same HunterBodyMotion handoff as live Hunt enemies.

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
	var rig := subject.rig as BaselineHuman
	var motion := subject.motion as HunterBodyMotion
	check(demo._trigger_body_hit_reaction(rig, Vector3.RIGHT, "torso", 28.0), "a sandbox anatomy hit finds its exact shared body animator")
	var right_direction := motion.hit_react_direction
	var mild_strength := motion.hit_react_strength
	check(motion.state == "hit" and motion.hit_react_time > 0.0, "impact commits a visible timed hit state")
	motion.update(0.016, Vector3.ZERO, true, false, false, false)
	var torso := rig.parts.get("torso") as Node3D
	check(torso != null and torso.rotation.length() > 0.01, "the hit state deforms the actual target rig rather than only updating data")

	check(demo._trigger_body_hit_reaction(rig, Vector3.LEFT, "torso", 90.0), "an opposite impact can retrigger the same living target")
	check(motion.hit_react_direction.dot(right_direction) < -0.8, "opposite world-space hits produce opposite local reactions")
	check(motion.hit_react_strength > mild_strength and motion.hit_react_duration > 0.14, "heavier damage produces a stronger and longer answer")
	check(not demo._trigger_body_hit_reaction(null, Vector3.FORWARD, "torso", 10.0), "missing targets fail safely without animating another body")

	print("GORE_SANDBOX_HIT_REACTION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
