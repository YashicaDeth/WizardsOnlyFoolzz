extends Node

## O3.2. The mechanics of limb damage were already in; what was missing is that
## an injured body did not *look* injured until a limb came off. This asserts
## the pose actually changes, and — more importantly — that posing repeatedly
## does not walk the body into the floor.

const RIG := preload("res://systems/baseline_human.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("O3.2 - an injured body looks injured")
	var rig: Node3D = RIG.new()
	add_child(rig)
	rig.build("injury_pose", {"gore": false})
	await get_tree().process_frame

	var right_arm: Node3D = rig.parts.get("right_arm")
	var left_leg: Node3D = rig.parts.get("left_leg")
	var torso: Node3D = rig.parts.get("torso")
	var head: Node3D = rig.parts.get("head")
	_check(right_arm != null and left_leg != null and torso != null, "the rig has the parts to pose")

	rig.favour_injuries()
	var rest_arm_z: float = right_arm.rotation.z
	var rest_arm_y: float = right_arm.position.y
	var rest_torso_z: float = torso.rotation.z
	_check(is_zero_approx(rest_arm_z), "an unhurt arm hangs at rest")

	# Break the right arm.
	rig.anatomy.apply_hit("right_arm", 40.0, 0.0, "blunt")
	rig.favour_injuries()
	_check(absf(right_arm.rotation.z) > absf(rest_arm_z) + 0.05, "a hurt arm rotates out and down (%.3f)" % right_arm.rotation.z)
	_check(right_arm.position.y < rest_arm_y, "and the whole limb drops")

	# Break a leg and check the body leans off it.
	rig.anatomy.apply_hit("left_leg", 45.0, 0.0, "blunt")
	rig.favour_injuries()
	_check(absf(torso.rotation.z - rest_torso_z) > 0.01, "the body leans off the bad leg (%.3f)" % torso.rotation.z)
	_check(left_leg.rotation.x > 0.01, "and that leg trails")

	# The one that matters: posing is a pose, not an accumulating animation.
	var settled_y: float = right_arm.position.y
	for _repeat in 40:
		rig.favour_injuries()
	_check(is_equal_approx(right_arm.position.y, settled_y), "posing forty times does not sink the body (%.4f vs %.4f)" % [right_arm.position.y, settled_y])

	# Consciousness drives the head, which is the read for "about to go down".
	var upright: float = head.rotation.x
	rig.anatomy.consciousness = 30.0
	rig.favour_injuries()
	_check(head.rotation.x > upright + 0.05, "a fading body stops holding its head up (%.3f)" % head.rotation.x)

	# A severed limb must not be posed — it is not there.
	rig.severed.append("right_arm")
	var before: float = right_arm.rotation.z
	rig.favour_injuries()
	_check(is_equal_approx(right_arm.rotation.z, before), "a severed limb is left alone")

	print("")
	if failures.is_empty():
		print("O3.2 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
