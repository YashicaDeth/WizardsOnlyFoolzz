extends Node

## O2.6 v2 verification. The guard used to hold equally in every direction —
## there was no such thing as flanking the player, since guard_absorb never
## knew where the blow was coming from at all.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	hunt.yaw = 0.0
	hunt.guarding = true
	hunt.guard_raised = 5.0
	hunt.stamina = 100.0

	# Facing +Z (yaw 0.0): something in front of you.
	var in_front: Vector3 = hunt.player + Vector3(0, 0, 3.0)
	var front_result: Dictionary = hunt.guard_absorb(20.0, in_front)
	check(bool(front_result.blocked), "a blow from where you are actually facing is still blocked")

	# Something directly behind you: the guard was never raised toward this.
	var behind: Vector3 = hunt.player + Vector3(0, 0, -3.0)
	var behind_result: Dictionary = hunt.guard_absorb(20.0, behind)
	check(not bool(behind_result.blocked), "a blow from directly behind you goes through the guard whole")
	check(is_equal_approx(float(behind_result.damage), 20.0), "and takes none of the reduction a real block would have given it")

	# No attacker position given at all: old behaviour preserved for any
	# caller that cannot supply one.
	var undirected_result: Dictionary = hunt.guard_absorb(20.0)
	check(bool(undirected_result.blocked), "a call with no attacker position still blocks, for backward compatibility")

	print("GUARD_DIRECTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
