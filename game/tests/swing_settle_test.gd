extends Node

## Greg's walkthrough (2026-09-24): the arms flipped back and forth on every
## click. Each melee swing ended a radian away from rest and snapped there the
## frame the action expired. A swing must now hand over to rest without a jump.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _f in 30:
		await get_tree().physics_frame
	var arm: Node3D = hunt.player_rig.parts.get("right_arm")
	var rest := arm.rotation.z
	hunt._attack(false)
	var previous := arm.rotation.z
	var largest_step := 0.0
	var swung := 0.0
	for _f in 50:
		await get_tree().physics_frame
		largest_step = maxf(largest_step, absf(arm.rotation.z - previous))
		swung = maxf(swung, absf(arm.rotation.z - rest))
		previous = arm.rotation.z
	check(swung > 0.8, "the swing still travels (%.2f rad)" % swung)
	check(largest_step < 0.7, "no single frame jumps the arm (largest step %.2f rad)" % largest_step)
	check(absf(arm.rotation.z - rest) < 0.05, "and it comes back to rest")
	print("SWING_SETTLE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
