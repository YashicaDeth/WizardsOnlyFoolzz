extends Node

## O6/O7. Everything you can swing is the same object with a different mass.
##
## What this proves, in order: a person you hold is a weapon by the same table
## as a sword; two-handing changes numbers and not a pose; a blow can take a
## thing off somebody and asks the *same* grip function that decides whether
## they could hold a person; and reach-versus-mass is the whole balance
## conversation without a damage stat anywhere in it.

const WEAPON_BODY := preload("res://systems/weapon_body.gd")
const MOMENTUM := preload("res://systems/limb_momentum.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


## A holder, described the way `AnatomyComponent.snapshot()` describes one.
func _body(left: float, right: float) -> Dictionary:
	return {"zones": {
		"left_arm": {"health": left},
		"right_arm": {"health": right},
	}}


func _ready() -> void:
	print("O6 / O7 - the body is the weapon system")

	var fist: Dictionary = WEAPON_BODY.of("fist")
	var sword: Dictionary = WEAPON_BODY.of("sword")
	var shotgun: Dictionary = WEAPON_BODY.of("shotgun")
	var person: Dictionary = WEAPON_BODY.of("held_person")

	# --- O7.1: one table, no special cases --------------------------------
	for thing: Dictionary in [fist, sword, shotgun, person]:
		_check(thing.has("mass") and thing.has("reach") and thing.has("stiffness"),
			"%s is described by the same three numbers as everything else" % thing.id)
	_check(float(person.mass) > float(sword.mass) * 50.0,
		"a person you have hold of is a weapon, and the difference is the mass (%.0fkg vs %.1fkg)" % [person.mass, sword.mass])
	_check(float(person.stiffness) < float(fist.stiffness),
		"and the arm holding one is far less able to steer it")
	_check(str(WEAPON_BODY.of("something_nobody_defined").id) == "bare_hand",
		"an unknown thing reads as bare hands rather than erroring mid-swing")

	# --- O4.1/O5.1: the arm actually takes it -----------------------------
	var arm: LimbMomentum = MOMENTUM.new()
	var fitted: Dictionary = WEAPON_BODY.fit(arm, "sword")
	_check(is_equal_approx(arm.mass, float(fitted.mass)), "fitting a thing sets the arm's own mass (%.2f)" % arm.mass)
	_check(is_equal_approx(arm.reach, float(fitted.reach)), "and its reach, so the two cannot drift apart")
	WEAPON_BODY.fit(arm, "held_person")
	_check(arm.mass > 50.0, "and swapping to a person re-fits the same arm rather than needing a second system")

	# --- O7.2: two-handing is numbers, not a pose -------------------------
	var two: Dictionary = WEAPON_BODY.of("sword", true)
	_check(is_equal_approx(float(two.mass), float(sword.mass)), "two-handing does not change what the sword weighs")
	_check(float(two.stiffness) > float(sword.stiffness), "it changes how steadily it is held (%.0f vs %.0f)" % [two.stiffness, sword.stiffness])
	_check(float(two.keep) > float(sword.keep), "and how hard it is to take off you (%.2f vs %.2f)" % [two.keep, sword.keep])
	_check(float(two.swing) < 1.0, "and it costs something: slower to whip around (%.2f)" % two.swing)
	_check(WEAPON_BODY.blow(two, 1.0) < WEAPON_BODY.blow(sword, 1.0),
		"so a fully committed two-handed blow is worth less than a one-handed one at the same commitment")
	_check(WEAPON_BODY.blow(two, 0.35) > 0.0 and WEAPON_BODY.blow(sword, 0.0) == 0.0,
		"and a blow with no commitment behind it is worth nothing whatever is in your hands")

	# --- O5.1: the thing sets the ceiling, the swing earns it -------------
	_check(WEAPON_BODY.blow(sword, 1.0) > WEAPON_BODY.blow(fist, 1.0), "a committed sword beats a committed fist")
	_check(WEAPON_BODY.blow(fist, 1.0) > WEAPON_BODY.blow(sword, 0.2), "and a committed fist beats a flicked sword")

	# --- O6.1: disarm, asking the same grip B6.2 built --------------------
	var whole := _body(65.0, 65.0)
	var one_arm := _body(0.0, 65.0)
	var no_arms := _body(0.0, 0.0)

	_check(WEAPON_BODY.disarm_pressure(0.2, sword, whole) == 0.0,
		"a flick does not take anything off anybody")
	var on_whole: float = WEAPON_BODY.disarm_pressure(1.0, sword, whole)
	var on_one: float = WEAPON_BODY.disarm_pressure(1.0, sword, one_arm)
	_check(on_one > on_whole, "the same blow takes a sword off a one-armed holder more easily (%.2f vs %.2f)" % [on_one, on_whole])
	_check(WEAPON_BODY.disarm_pressure(0.6, sword, no_arms) >= 0.6,
		"and a holder with nothing left to hold with loses it to any blow that lands")
	_check(WEAPON_BODY.disarmed(0.6, sword, no_arms, 0.5), "which actually comes loose")
	_check(not WEAPON_BODY.disarmed(0.2, sword, no_arms, 0.0), "while a blow under the floor never does, however bad their arms are")

	# The same blow against the same arms, held two-handed.
	var two_pressure: float = WEAPON_BODY.disarm_pressure(1.0, WEAPON_BODY.of("sword", true), one_arm)
	_check(two_pressure < on_one, "two hands on it survives a blow that would have taken it one-handed (%.2f vs %.2f)" % [two_pressure, on_one])

	# A fist cannot be disarmed, which is the point of having one.
	_check(WEAPON_BODY.disarm_pressure(1.0, fist, whole) == 0.0, "and nobody is ever disarmed of their own fist")

	# --- O6.2: reach opens, mass closes -----------------------------------
	var trade: Dictionary = WEAPON_BODY.trade(sword, fist)
	_check(bool(trade.opens), "the longer thing is expected to touch first")
	_check(float(trade.weight) > 0.5, "and the heavier thing is worth more when it lands")
	var reversed: Dictionary = WEAPON_BODY.trade(fist, sword)
	_check(not bool(reversed.opens), "read the other way round, the shorter thing does not open")
	_check(is_equal_approx(float(trade.reach_edge), -float(reversed.reach_edge)), "and the trade is the same conversation from both sides")

	var sidearm: Dictionary = WEAPON_BODY.of("sidearm")
	var long_light: Dictionary = WEAPON_BODY.trade(sword, shotgun)
	_check(bool(long_light.opens) and float(long_light.weight) < 0.5,
		"a longer, lighter thing wins the opening and loses the exchange - which is the whole balance argument, with no damage stat in it")
	_check(not bool(WEAPON_BODY.trade(sidearm, sword).opens), "a sidearm never opens against a sword")

	print("")
	if failures.is_empty():
		print("O6/O7 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
