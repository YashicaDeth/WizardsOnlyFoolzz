class_name WeaponBody
extends RefCounted

## O6/O7. Everything you can swing is the same object with a different mass.
##
## `limb_momentum.gd` already made the blow something the player performs rather
## than requests: the weapon is a mass on the end of a spring, `head_speed()` is
## measured rather than declared, and `commitment()` is how much of the swing you
## actually earned. What it never had was a table of *things* — the arm could
## carry a mass and a reach, but nothing said what a sword weighed against a fist,
## or against a person you have hold of.
##
## That table is this file, and it is one table on purpose. O7.1 asks for grapple,
## shove and bare hands to be the same object with a different mass, and the
## honest reading of that is stronger than it sounds: **a person you are holding
## is a weapon you are holding.** Same spring, same overshoot, same commitment
## curve — eighty kilos on the end of your arm instead of one and a half. Nothing
## here special-cases it.
##
## Two things follow that were not reachable before:
##
## **O6.1, disarm.** A blow can knock a thing out of a hand. The question "how
## well are you holding it" already has an answer in this project, and it is
## `Clinch.grip_capacity()` — the arms you have left, which B6.2 built for holding
## people. A hand is a hand. So disarm asks the same function that decides whether
## you can hold somebody, and a player with one arm ruined loses their sword for
## the same reason, and by the same number, as they lose their grip on a person.
##
## **O7.2, two-handing changes the numbers rather than the pose.** `held_gear.gd`
## already has a `two_hand` grip and it is a hand position. Here it is a different
## weapon: the same mass, better held — stiffer, steadier, much harder to take off
## you, and slower to whip around, which is the cost.

const Clinch := preload("res://systems/clinch.gd")

## `mass` in kilograms, `reach` in metres from the hand, `stiffness` for the arm
## spring, `keep` is how hard it is to knock loose before grip is considered.
##
## The numbers are deliberately real. A longsword is about 1.4 kg and people are
## consistently surprised by that; a pump shotgun is about 3.2; a whole person is
## eighty, which is why swinging one is a different verb rather than a big number.
const THINGS := {
	# `attached` is the one distinction the mass table cannot express: these are
	# not held, they are part of you. A severed arm you picked up can be knocked
	# out of your hand; the hand cannot. It is also why an unarmed fighter is a
	# floor rather than a weakness — you cannot be taken below your own fists.
	"bare_hand": {"mass": 0.45, "reach": 0.62, "stiffness": 74.0, "keep": 1.0, "hands": 1, "attached": true},
	"fist": {"mass": 0.60, "reach": 0.58, "stiffness": 80.0, "keep": 1.0, "hands": 1, "attached": true},
	"sword": {"mass": 1.40, "reach": 1.05, "stiffness": 58.0, "keep": 0.52, "hands": 1},
	"shotgun": {"mass": 3.20, "reach": 0.96, "stiffness": 46.0, "keep": 0.44, "hands": 2},
	"sidearm": {"mass": 0.95, "reach": 0.44, "stiffness": 66.0, "keep": 0.58, "hands": 1},
	# O7.1. A person you have hold of. Not a special case — a mass and a reach
	# like everything else, and the reason a grapple feels nothing like a swing
	# is the first number, not a separate system.
	"held_person": {"mass": 80.0, "reach": 0.70, "stiffness": 26.0, "keep": 0.30, "hands": 2},
	"severed_arm": {"mass": 3.80, "reach": 0.74, "stiffness": 40.0, "keep": 0.36, "hands": 1},
}

## What two hands buy, as multipliers on the thing's own numbers. The pose is
## `held_gear.gd`'s business; this is what changes about the fight.
const TWO_HAND_STIFFNESS := 1.45
const TWO_HAND_KEEP := 1.9
## And what it costs. A two-handed grip is steadier and slower to redirect — the
## arm spring is stiffer, so the head lags less and overshoots less, which is
## exactly what makes a committed sweep easier and a flick worse.
const TWO_HAND_SWING := 0.86

## Below this a blow has not earned the right to take anything off anybody.
const DISARM_FLOOR := 0.35


## One thing's numbers. An unknown id reads as bare hands rather than erroring —
## an unarmed fighter is the safe failure here, not a crash mid-swing.
static func of(thing_id: String, two_hands := false) -> Dictionary:
	var base: Dictionary = THINGS.get(thing_id, THINGS["bare_hand"])
	var out := base.duplicate(true)
	out["id"] = thing_id if THINGS.has(thing_id) else "bare_hand"
	out["two_handed"] = two_hands
	if two_hands:
		out["stiffness"] = float(base.stiffness) * TWO_HAND_STIFFNESS
		out["keep"] = float(base.keep) * TWO_HAND_KEEP
		out["swing"] = TWO_HAND_SWING
	else:
		out["swing"] = 1.0
	return out


## Hand it to the arm. The only place `LimbMomentum.carry()` should be called
## from, so mass and reach cannot drift apart from the table that owns them.
static func fit(arm: LimbMomentum, thing_id: String, two_hands := false) -> Dictionary:
	var thing := of(thing_id, two_hands)
	arm.carry(float(thing.mass), float(thing.reach), float(thing.stiffness))
	return thing


## O6.1. How much this blow is trying to take the thing off them.
##
## Three terms and each one is somebody's decision: how committed the blow was,
## how hard the thing is to hold at all, and how much arm the holder has left to
## hold it with — which is `Clinch.grip_capacity()`, the same function that
## decides whether they could hold a person. An empty `holder` reads as whole,
## exactly as it does there.
static func disarm_pressure(blow_commitment: float, thing: Dictionary, holder: Dictionary = {}) -> float:
	# Part of you, so there is nothing to take. This is checked before the floor
	# because it is not a matter of degree.
	if bool(thing.get("attached", false)):
		return 0.0
	var committed := clampf(blow_commitment, 0.0, 1.0)
	if committed < DISARM_FLOOR:
		return 0.0
	var grip := Clinch.grip_capacity(holder) * float(thing.get("keep", 1.0))
	if grip <= 0.0:
		# Nothing left to hold it with. A blow that lands at all takes it.
		return committed
	# Past the floor, what is left of the blow is what has to beat the grip.
	var earned := (committed - DISARM_FLOOR) / (1.0 - DISARM_FLOOR)
	return clampf(earned - grip * 0.72, 0.0, 1.0)


## Whether it actually comes loose. Kept separate from the pressure so a caller
## can show the number before it rolls, and so a test does not have to fight an
## RNG to assert on it.
static func disarmed(blow_commitment: float, thing: Dictionary, holder: Dictionary = {}, roll := -1.0) -> bool:
	var pressure := disarm_pressure(blow_commitment, thing, holder)
	if pressure <= 0.0:
		return false
	var against := roll if roll >= 0.0 else randf()
	return against < pressure


## O6.2. Mass and reach are the whole balance conversation, so here is the
## conversation as numbers rather than a stat block.
##
## Reach decides who lands first; mass decides what it does when it lands. A
## longer, lighter thing wins the opening and loses the exchange, and that trade
## is the entire argument — nothing here needs a damage stat to express it.
static func trade(thing: Dictionary, against: Dictionary) -> Dictionary:
	var reach_edge := float(thing.get("reach", 0.6)) - float(against.get("reach", 0.6))
	var mass_edge := float(thing.get("mass", 0.5)) - float(against.get("mass", 0.5))
	return {
		"reach_edge": reach_edge,
		"mass_edge": mass_edge,
		# Who is expected to touch first.
		"opens": reach_edge > 0.0,
		# What a landed blow is worth relative to theirs, before commitment.
		"weight": clampf(0.5 + mass_edge * 0.18, 0.15, 1.0),
	}


## O5.1 in one line: the thing sets the ceiling, the swing earns it — with
## two-handing folded in as a number rather than a pose.
static func blow(thing: Dictionary, blow_commitment: float) -> float:
	var committed := clampf(blow_commitment, 0.0, 1.0) * float(thing.get("swing", 1.0))
	# Mass times reach is the ceiling. A fully committed fist is still a fist.
	var ceiling := float(thing.get("mass", 0.5)) * float(thing.get("reach", 0.6))
	return ceiling * committed
