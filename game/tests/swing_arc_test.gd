extends Node

## O5.11 v2 verification. swing_momentum() read only whether you stepped
## toward where you were looking — swing_side alternated every swing and was
## already returned in the same dictionary, but nothing ever compared it
## against how the player actually moved. Moving with the weapon's own arc
## should lend the blow something a straight-line step-in does not capture,
## and moving against it should cost the same amount back.

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
	# Facing +Z, so "right" is whatever the game's own convention says it is —
	# read it back rather than assuming, since the point is consistency with
	# register_swing()'s alternation, not a specific compass direction.
	var look := Vector3(sin(hunt.yaw), 0.0, cos(hunt.yaw))
	var lateral := Vector3(look.z, 0.0, -look.x) * 4.0

	hunt.swing_side = 1
	var with_the_arc: Dictionary = hunt.swing_momentum(lateral)
	hunt.swing_side = -1
	var against_the_arc: Dictionary = hunt.swing_momentum(lateral)

	check(not is_equal_approx(float(with_the_arc.with_arc), float(against_the_arc.with_arc)), "the same lateral step reads differently depending on which way the arc is already moving")
	check(float(with_the_arc.power) > float(against_the_arc.power), "moving with the arc lends more than moving against it, same step (%.2f vs %.2f)" % [with_the_arc.power, against_the_arc.power])
	check(sign(float(with_the_arc.with_arc)) == -sign(float(against_the_arc.with_arc)), "flipping the arc's own direction flips which way the same step counts")

	# A straight-in step with no lateral component at all should not care
	# which way the arc happens to be swinging — this is the case that
	# already worked, and it has to keep working exactly as it did.
	hunt.swing_side = 1
	var straight_in: Dictionary = hunt.swing_momentum(look * 4.0)
	hunt.swing_side = -1
	var straight_in_other_side: Dictionary = hunt.swing_momentum(look * 4.0)
	check(is_equal_approx(float(straight_in.power), float(straight_in_other_side.power)), "a pure step-in with no lateral component is unaffected by which way the arc is swinging")
	check(float(straight_in.into) > 0.0, "and it still reads as stepping in, same as before")

	print("SWING_ARC_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
