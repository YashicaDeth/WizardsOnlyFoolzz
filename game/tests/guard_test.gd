extends Node

## O2.4. Evading already worked and was already consulted on incoming damage,
## which made it real — but it was the only defensive option, and one option is
## a reflex rather than a decision. This asserts the second one.

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("O2.4 - a guard you can hold, and a parry you can time")
	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 90:
		await get_tree().process_frame

	# Nothing raised: damage arrives whole.
	hunt.set("guarding", false)
	var open: Dictionary = hunt.call("guard_absorb", 20.0)
	_check(is_equal_approx(float(open["damage"]), 20.0), "with no guard up, all of it lands")
	_check(not bool(open["blocked"]), "and nothing is blocked")

	# Raised late: a block. Some of it still arrives, and it costs stamina.
	hunt.set("guarding", true)
	hunt.set("guard_raised", 0.9)
	hunt.set("stamina", 100.0)
	var blocked: Dictionary = hunt.call("guard_absorb", 20.0)
	_check(bool(blocked["blocked"]) and not bool(blocked["parried"]), "held late, it is a block")
	_check(float(blocked["damage"]) < 20.0, "which takes the edge off (%.1f of 20)" % float(blocked["damage"]))
	_check(float(blocked["damage"]) > 0.0, "but not all of it — a block is not a parry")
	_check(float(hunt.get("stamina")) < 100.0, "and it spends stamina instead of blood")

	# Timed: a parry. Nothing gets through.
	hunt.set("guard_raised", 0.05)
	var parried: Dictionary = hunt.call("guard_absorb", 20.0)
	_check(bool(parried["parried"]), "caught inside the window, it is a parry")
	_check(is_zero_approx(float(parried["damage"])), "and nothing gets through")

	# O5.9. The body decides what it can hold up.
	var rig = hunt.get("player_rig")
	_check(float(hunt.call("guard_strength")) > 0.9, "an unhurt pair of arms guards fully")
	rig.anatomy.apply_hit("left_arm", 60.0, 0.0, "blunt")
	rig.anatomy.apply_hit("right_arm", 60.0, 0.0, "blunt")
	var hurt_strength: float = hunt.call("guard_strength")
	_check(hurt_strength < 0.6, "two broken arms guard badly (%.2f)" % hurt_strength)
	hunt.set("guard_raised", 0.9)
	var weak: Dictionary = hunt.call("guard_absorb", 20.0)
	_check(float(weak["damage"]) > float(blocked["damage"]), "so more gets through a broken guard (%.1f vs %.1f)" % [float(weak["damage"]), float(blocked["damage"])])

	rig.severed.append("left_arm")
	rig.severed.append("right_arm")
	_check(is_zero_approx(float(hunt.call("guard_strength"))), "with no arms at all there is no guard")

	print("")
	if failures.is_empty():
		print("O2.4 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
