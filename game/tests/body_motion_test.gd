extends Node3D

const MOTION := preload("res://systems/hunter_body_motion.gd")
const APPEARANCE := preload("res://systems/hunter_appearance.gd")
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("motion_test", {"cybernetics": {"right_arm": {"name": "torque arm", "armor": 0.2}}})
	var appearance: Node = APPEARANCE.new()
	rig.add_child(appearance)
	appearance.configure(rig)
	check(appearance.details.has("Eye_L") and appearance.details.has("Eye_R") and appearance.details.has("Mouth_Lower"), "hero has asymmetric eyes and an articulated mouth")
	var finger_count := 0
	for detail_name in appearance.details:
		if "Finger" in str(detail_name):
			finger_count += 1
	check(finger_count == 10, "hero has ten distinct visible fingers")
	check(appearance.details.has("left_leg_Boot") and appearance.details.has("right_leg_Boot"), "feet and boots complete the first-person body")
	check(appearance.details.has("right_arm_ServoBand_1"), "installed prosthetic has visible hardware")
	var motion: Node = MOTION.new()
	add_child(motion)
	motion.configure(rig)
	motion.set_perspective(true)
	motion.update(0.1, Vector3(0, 0, 7), true, false, false, false)
	check(motion.state == "walk", "real velocity selects walk locomotion")
	check(rig.parts.right_arm.rotation.x > 0.7 and rig.parts.left_arm.rotation.x > 0.7, "first person raises both real arms into view")
	check(rig.get_node("right_arm_hitbox").position.is_equal_approx(rig.parts.right_arm.position), "animated anatomy hitbox follows visible arm")
	motion.update(0.1, Vector3(0, 0, 3), true, false, true, false)
	check(motion.state == "crouch", "crouch has its own full-body state")
	motion.trigger_attack(0.5, "melee")
	motion.update(0.1, Vector3.ZERO, true, false, false, false)
	check(motion.state == "attack" and absf(rig.parts.right_arm.rotation.z) > 0.2, "attack layers a committed weapon-arm arc")
	motion.trigger_recoil(34.0)
	motion.update(0.016, Vector3.ZERO, true, false, false, false)
	check(motion.recoil_time > 0.0 and motion.camera_offset.length() < 0.2, "weapon recoil moves body and keeps camera motion restrained")
	rig.hit("torso", 18.0, 5.0, "cut")
	appearance.sync_from_anatomy()
	check(appearance.details.has("Wound_0"), "anatomy wounds appear on the same gameplay model")
	check(motion.step_voice is AudioStreamPlayer3D, "locomotion owns positional procedural footsteps")
	print("BODY_MOTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
