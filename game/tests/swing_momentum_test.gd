extends Node

## O5.1. Until now every swing was identical regardless of what the body was
## doing when it was thrown — the same damage standing still, backpedalling, or
## running somebody down. That is what makes melee read as a button rather than
## as a weight on the end of an arm.

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("O5.1 - a swing carries momentum")
	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 90:
		await get_tree().process_frame

	hunt.set("yaw", 0.0)
	var forward := Vector3(sin(0.0), 0.0, cos(0.0))

	var still: Dictionary = hunt.call("swing_momentum", Vector3.ZERO)
	var into: Dictionary = hunt.call("swing_momentum", forward * 5.0)
	var away: Dictionary = hunt.call("swing_momentum", -forward * 5.0)

	_check(float(into["power"]) > float(still["power"]), "stepping into a blow lends it your mass (%.2f vs %.2f)" % [float(into["power"]), float(still["power"])])
	_check(float(away["power"]) < float(still["power"]), "backing away takes it out again (%.2f)" % float(away["power"]))
	_check(float(into["into"]) > 0.5, "the step-in is measured off the real heading (%.2f)" % float(into["into"]))
	_check(float(away["into"]) < -0.5, "and so is the retreat (%.2f)" % float(away["into"]))

	# Sideways is neither: a blow thrown while strafing is an ordinary blow.
	var side := Vector3(forward.z, 0.0, -forward.x)
	var strafe: Dictionary = hunt.call("swing_momentum", side * 5.0)
	_check(absf(float(strafe["into"])) < 0.2, "strafing is neither stepping in nor backing off (%.2f)" % float(strafe["into"]))

	# Bounded, so no amount of running turns a cleaver into an execution.
	var sprinting: Dictionary = hunt.call("swing_momentum", forward * 40.0)
	_check(float(sprinting["power"]) <= 1.7, "the bonus is capped (%.2f)" % float(sprinting["power"]))
	_check(float(away["power"]) >= 0.5, "and so is the penalty (%.2f)" % float(away["power"]))

	# The arc alternates on its own, so the next swing comes off the other side.
	var first: int = hunt.get("swing_side")
	hunt.call("register_swing")
	var second: int = hunt.get("swing_side")
	_check(first != second, "the arc alternates sides on its own (%d -> %d)" % [first, second])
	hunt.call("register_swing")
	_check(int(hunt.get("swing_side")) == first, "and comes back on the third")

	# A swing thrown straight after another is chained; one from rest is not.
	var chained: Dictionary = hunt.call("swing_momentum", Vector3.ZERO)
	_check(bool(chained["chained"]), "a swing inside the window follows the last one")
	_check(float(chained["power"]) > float(still["power"]) or is_equal_approx(float(chained["power"]), float(still["power"])), "and a cold swing from rest carries less stored momentum")

	print("")
	if failures.is_empty():
		print("O5.1 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
