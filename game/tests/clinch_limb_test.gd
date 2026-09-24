extends Node

## B6.1 / B6.2. "Limbs that shoot and grapple, through the anatomy rather than
## around it", and "a grappling limb that is severed stops grappling".
##
## The clinch was a pure number before this: advantage in, hold out. It read the
## held person's pain and consciousness — correctly, that is what the hold costs
## them — and never once asked what the holder had left to hold with. A player
## with both arms on the floor gripped exactly as well as a whole one.
##
## What this proves, in order: an arm's condition comes out of the zone the
## anatomy already damages; a severed arm is worth nothing and a missing one is
## the same thing; two arms beat one and one beats none; the hold is ceilinged
## by the arms rather than topped up by them; and an arm committed to a grip is
## not available to fire, which is the half of B6.1 that is about choice.

const Clinch := preload("res://systems/clinch.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


## A holder, described the way `AnatomyComponent.snapshot()` describes one.
func _body(left: float, right: float, fracture := "") -> Dictionary:
	var zones := {
		"left_arm": {"health": left, "bleed": 0.55, "critical": false},
		"right_arm": {"health": right, "bleed": 0.55, "critical": false},
	}
	if not fracture.is_empty():
		zones["left_arm"]["fracture"] = fracture
	return {"zones": zones}


func _ready() -> void:
	print("B6.1 / B6.2 - the grip is made of arms")
	var held := {"pain": 40.0, "consciousness": 80.0}

	var whole := _body(65.0, 65.0)
	var one_arm := _body(0.0, 65.0)
	var no_arms := _body(0.0, 0.0)
	var broken := _body(65.0, 0.0, "compound")
	var gone := {"zones": {"right_arm": {"health": 65.0}}}

	# --- B6.2: severance ends the grip -------------------------------------
	_check(Clinch.limb_condition(whole, "left_arm") == 1.0, "an untouched arm is whole")
	_check(Clinch.limb_condition(one_arm, "left_arm") == 0.0, "an arm at zero health grips nothing")
	_check(Clinch.limb_condition(gone, "left_arm") == 0.0, "an arm taken off the body is the same as one at zero")
	_check(Clinch.limb_condition(broken, "left_arm") < 1.0, "a compound fracture still grips, but badly (%.2f)" % Clinch.limb_condition(broken, "left_arm"))
	_check(Clinch.limb_condition(broken, "left_arm") > 0.0, "and it is not nothing — the hand on the end still closes")

	var hold_whole: float = Clinch.hold_strength(0.6, held, whole)
	var hold_one: float = Clinch.hold_strength(0.6, held, one_arm)
	var hold_none: float = Clinch.hold_strength(0.6, held, no_arms)
	_check(hold_none == 0.0, "a body with no arms is not holding anybody, however hurt they are")
	_check(hold_one > 0.0 and hold_one < hold_whole, "one arm is a real hold and a worse one (%.2f vs %.2f)" % [hold_one, hold_whole])
	_check(hold_whole - hold_one < hold_one - hold_none, "losing the second arm costs less than losing the last one")

	# The ceiling, not a bonus: somebody unconscious and in agony is still not
	# held by a body with nothing left to hold them with.
	var wrecked := {"pain": 100.0, "consciousness": 0.0}
	_check(Clinch.hold_strength(1.0, wrecked, no_arms) == 0.0, "maximum advantage on a ruined body is still no hold without arms")

	# --- back-compatibility: the older two-argument callers -----------------
	var legacy: float = Clinch.hold_strength(0.6, held)
	_check(is_equal_approx(legacy, hold_whole), "a caller that names no holder still reads as a whole body (%.2f)" % legacy)

	# --- B6.1: an arm doing one job is not doing the other ------------------
	_check(Clinch.usable_limbs(whole).size() == 2, "a whole body has two arms to give a job to")
	_check(Clinch.usable_limbs(one_arm).size() == 1, "a one-armed body has one")
	_check(Clinch.usable_limbs(no_arms).is_empty(), "and a body with none has none")

	_check(not Clinch.can_shoot(whole, ["left_arm", "right_arm"]), "both hands on somebody means nothing is firing")
	_check(Clinch.can_shoot(whole, ["left_arm"]), "one hand on somebody leaves the other free")
	_check(not Clinch.can_shoot(one_arm, ["right_arm"]), "the player's only arm cannot both hold and shoot")

	var two_free: float = Clinch.gun_steadiness(whole, [])
	var one_free: float = Clinch.gun_steadiness(whole, ["left_arm"])
	_check(two_free > one_free, "two hands steady a weapon better than one (%.2f vs %.2f)" % [two_free, one_free])
	_check(Clinch.gun_steadiness(whole, ["left_arm", "right_arm"]) == 0.0, "and no hands point nothing")

	# --- the seam: one answer the prompt and the input handler both read ----
	var opts: Dictionary = Clinch.options(0.6, held, {"bond": 0, "grudge": 0}, 0.0, whole, ["left_arm"])
	_check(opts.has("free_limbs") and opts.has("shoot"), "the options dictionary carries what the body has left")
	_check(bool(opts.get("shoot", false)), "a one-handed hold reports that it can still fire")
	_check(float(opts.get("grip_capacity", 0.0)) > 0.0, "and what the grip is actually made of")

	var broke_opts: Dictionary = Clinch.options(0.6, held, {"bond": 0, "grudge": 0}, 0.0, no_arms)
	_check(not bool(broke_opts.get("rob", true)), "with no arms there is nothing on offer at all")

	print("")
	if failures.is_empty():
		print("B6 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
