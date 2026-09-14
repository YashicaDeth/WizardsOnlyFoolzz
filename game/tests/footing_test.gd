extends Node

## O5.7. Enemies have had a staggered state for a while and the player had
## nothing, which is what made a brawl read as one body hitting statues: you
## could over-commit, whiff, get blocked and take a shove, and still be standing
## exactly as square as when you started.

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("O5.7 - footing, for both of you")
	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 90:
		await get_tree().process_frame

	hunt.set("footing", 1.0)
	_check(not bool(hunt.call("stumbling")), "a body standing in its feet is not stumbling")
	var full_swing: float = hunt.call("_player_swing_scale")
	var full_speed: float = hunt.call("_player_speed_scale")

	# Losing it.
	hunt.call("lose_footing", 0.8, "")
	_check(bool(hunt.call("stumbling")), "enough lost balance and you are stumbling (%.2f)" % float(hunt.get("footing")))
	_check(float(hunt.call("_player_swing_scale")) < full_swing, "a blow thrown off your feet has nothing behind it (%.2f vs %.2f)" % [float(hunt.call("_player_swing_scale")), full_swing])
	_check(float(hunt.call("_player_speed_scale")) < full_speed, "and moving is a negotiation (%.2f vs %.2f)" % [float(hunt.call("_player_speed_scale")), full_speed])

	# A guard cannot be held up by somebody falling over.
	hunt.set("guarding", true)
	for _frame in 4:
		await get_tree().process_frame
	_check(not bool(hunt.get("guarding")), "a stumbling body cannot hold a guard up")

	# It comes back by standing in it.
	var low: float = hunt.get("footing")
	for _recover in 40:
		await get_tree().process_frame
	_check(float(hunt.get("footing")) > low, "footing recovers by standing in it (%.2f -> %.2f)" % [low, float(hunt.get("footing"))])

	# Whiffing costs balance — a miss was already free of damage, it is no
	# longer free of everything.
	hunt.set("footing", 1.0)
	var before_whiff: float = hunt.get("footing")
	hunt.call("lose_footing", hunt.get("FOOTING_WHIFF") if hunt.get("FOOTING_WHIFF") != null else 0.14, "SWUNG AT NOTHING")
	_check(float(hunt.get("footing")) < before_whiff, "swinging at air puts you on your heels")

	# AN2.1. Committing to a heavy blow costs footing whether or not it lands —
	# the vulnerability is in throwing it. Forcing `arm._work` directly (as
	# arm_calibration_test.gd already does) gives a deterministic commitment
	# without driving forty frames of synthetic mouse input.
	hunt.stamina = 100.0
	hunt.set("footing", 1.0)
	hunt.arsenal.cooldown = 0.0
	hunt.arm._work = 10.0
	hunt.call("_attack", false)
	var footing_after_heavy: float = hunt.get("footing")
	_check(footing_after_heavy < 0.8, "a fully committed swing costs real footing just for being thrown (%.2f)" % footing_after_heavy)

	hunt.set("footing", 1.0)
	hunt.arsenal.cooldown = 0.0
	hunt.arm._work = 0.0
	hunt.call("_attack", false)
	var footing_after_flick: float = hunt.get("footing")
	_check(footing_after_flick > footing_after_heavy, "an uncommitted flick costs far less footing than a committed sweep (%.2f vs %.2f)" % [footing_after_flick, footing_after_heavy])

	# Firearms carry no wind-up in this sense — `arm.commitment()` still tracks
	# barrel drift for AN1.7, and that is not the same thing as being off balance.
	hunt.call("_equip_weapon", 1)
	hunt.arsenal.cooldown = 0.0
	hunt.set("footing", 1.0)
	hunt.arm._work = 10.0
	hunt.call("_attack", false)
	_check(is_equal_approx(float(hunt.get("footing")), 1.0), "firing a gun costs no footing from commitment (%.2f)" % float(hunt.get("footing")))

	# Bounded at both ends.
	hunt.call("lose_footing", 99.0, "")
	_check(float(hunt.get("footing")) >= 0.0, "footing cannot go below zero (%.2f)" % float(hunt.get("footing")))
	hunt.set("footing", 1.0)
	hunt.call("lose_footing", -99.0, "")
	_check(float(hunt.get("footing")) <= 1.0, "and cannot be banked above full (%.2f)" % float(hunt.get("footing")))

	print("")
	if failures.is_empty():
		print("O5.7 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
