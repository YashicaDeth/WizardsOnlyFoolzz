class_name CombatStance
extends RefCounted

## The poses a fight is made of, as numbers rather than as an animation.
##
## Greg asked for soulslike combat -- guarding, parrying, staggering, circling
## a locked-on target -- and the honest first answer was that this game has no
## `Skeleton3D` and no `AnimationPlayer` anywhere in it, so there was a fork to
## choose before any of it could be written.
##
## It is chosen, and it is procedural, because the absence is not an oversight.
## It is the reason `BodySlice` can cut an arbitrary plane through anybody,
## which is the reason `Cavity`, `SkullBurst`, severed limbs and every chunk
## that carries whose body it came off work at all. Skinned characters would
## buy a higher animation ceiling and cost all of it. The hybrid -- rigged
## while alive, cuttable once dead -- sounds like both until you notice that a
## body which is only cuttable after death cannot show a wound taken while it
## is still standing, and wounds accumulating on someone still fighting is most
## of what this game is.
##
## `HunterBodyMotion` is already a real state machine: twelve states, per-zone
## posing, directional hit reactions, hitboxes kept in step. It does not need
## replacing, it needs the states a fight has. Those live here rather than
## inside it because a pose is a pure function of how far through a move you
## are, and the failures these can have -- a guard that leaves the chest open,
## a parry that never crosses the centre line, a lock-on strafe that turns its
## back on the thing it is locked to -- are worth reading off numbers in a test
## instead of watching a body and deciding whether it looked about right.
##
## Every function returns `{zone_id: {"offset": Vector3, "angles": Vector3}}`,
## in exactly the shape `HunterBodyMotion._set_zone_pose()` already takes, and
## relative to rest the same way. Angles are pitch on X, yaw on Y, roll on Z.
## Inward across the chest is negative roll on the left arm and positive on the
## right, which is the convention the existing poses already use.

## How far the weapon arm crosses the centre line at the height of a parry.
## Further than a guard by a clear margin, because a parry that only looks like
## a slightly firmer guard gives the player nothing to read in the moment they
## have to read it in.
const PARRY_CROSS := 1.35

## Where in a parry the deflection peaks. Early, because the whole move is over
## in a few frames and a symmetric arc would put the meeting point in the
## middle of the swing rather than at the front of it.
const PARRY_PEAK := 0.34


## A guard held up. `amount` is 0 for dropped and 1 for fully raised.
##
## Both arms come in and up rather than only the weapon arm: a one-armed guard
## reads as a shrug. The head tucks behind them, which is what makes the pose
## legible from the distance a fight actually happens at.
static func guard(amount: float, weapon_kind := "melee") -> Dictionary:
	var held := clampf(amount, 0.0, 1.0)
	if held <= 0.0:
		return {}
	# A firearm is brought to the shoulder and a blade is held across the body,
	# so the weapon arm differs while the off hand supports either way.
	var weapon_raise := 1.02 if weapon_kind == "firearm" else 0.74
	var weapon_cross := 0.26 if weapon_kind == "firearm" else 0.62
	return {
		"right_arm": {
			"offset": Vector3(-0.06 * held, 0.09 * held, -0.07 * held),
			"angles": Vector3(weapon_raise * held, -0.22 * held, weapon_cross * held),
		},
		"left_arm": {
			"offset": Vector3(0.05 * held, 0.07 * held, -0.06 * held),
			"angles": Vector3(0.88 * held, 0.20 * held, -0.54 * held),
		},
		# Bladed on, so there is less of you behind the guard.
		"torso": {"offset": Vector3.ZERO, "angles": Vector3(0.10 * held, -0.24 * held, 0.0)},
		"head": {"offset": Vector3(0.0, -0.03 * held, 0.0), "angles": Vector3(0.14 * held, 0.18 * held, 0.0)},
	}


## The deflection itself. `progress` runs 0 to 1 across the parry window.
##
## Out and back, peaking early: the arm crosses the centre line hard, meets
## the blow, and recovers. At either end it is nothing, so a parry that is
## never triggered and one that has finished leave the body where they found
## it rather than snapping it.
static func parry(progress: float) -> Dictionary:
	var run := clampf(progress, 0.0, 1.0)
	# Rising fast to the peak and falling slower away from it -- a deflection
	# is a snap followed by a recovery, not a symmetric wave.
	var swing := 0.0
	if run < PARRY_PEAK:
		swing = run / PARRY_PEAK
	else:
		swing = 1.0 - (run - PARRY_PEAK) / maxf(0.0001, 1.0 - PARRY_PEAK)
	swing = clampf(swing, 0.0, 1.0)
	if swing <= 0.0:
		return {}
	return {
		"right_arm": {
			"offset": Vector3(-0.14 * swing, 0.16 * swing, -0.12 * swing),
			"angles": Vector3(0.62 * swing, -0.44 * swing, PARRY_CROSS * swing),
		},
		"left_arm": {
			"offset": Vector3(0.04 * swing, 0.05 * swing, -0.03 * swing),
			"angles": Vector3(0.52 * swing, 0.30 * swing, -0.40 * swing),
		},
		"torso": {"offset": Vector3.ZERO, "angles": Vector3(0.0, -0.40 * swing, -0.12 * swing)},
		"head": {"offset": Vector3.ZERO, "angles": Vector3(0.0, -0.26 * swing, 0.0)},
	}


## Knocked out of shape. `from_local` is where the blow came from in the body's
## own space; `severity` scales how far it folds.
##
## Away from the blow, which is the whole readability of it: a stagger that
## does not say which side it came from is a generic flinch, and a player
## trading hits needs to know whether they were opened up on the left or the
## right. Decays to nothing by the end so recovery is not a second snap.
static func stagger(progress: float, from_local: Vector3, severity := 1.0) -> Dictionary:
	var run := clampf(progress, 0.0, 1.0)
	# Hardest at the moment of contact, easing out. `1 - run` squared reads as
	# a body absorbing a blow rather than sliding back to attention.
	var fold := (1.0 - run) * (1.0 - run) * clampf(severity, 0.0, 2.0)
	if fold <= 0.0:
		return {}
	var push := from_local
	push.y = 0.0
	if push.length_squared() < 0.0001:
		push = Vector3.BACK
	push = push.normalized()
	# The body goes the way the blow was travelling, which is away from where
	# it came from.
	var away := -push
	return {
		"torso": {
			"offset": Vector3(away.x * 0.09 * fold, -0.05 * fold, away.z * 0.09 * fold),
			"angles": Vector3(away.z * 0.42 * fold, 0.0, -away.x * 0.46 * fold),
		},
		"head": {
			"offset": Vector3(away.x * 0.05 * fold, 0.0, away.z * 0.05 * fold),
			"angles": Vector3(away.z * 0.54 * fold, away.x * 0.22 * fold, -away.x * 0.58 * fold),
		},
		# The arms are thrown rather than held: a guard does not survive this.
		"right_arm": {"offset": Vector3.ZERO, "angles": Vector3(-0.34 * fold, 0.0, -0.42 * fold)},
		"left_arm": {"offset": Vector3.ZERO, "angles": Vector3(-0.30 * fold, 0.0, 0.38 * fold)},
		"left_leg": {"offset": Vector3(0.0, 0.0, 0.0), "angles": Vector3(away.z * -0.22 * fold, 0.0, 0.0)},
		"right_leg": {"offset": Vector3(0.0, 0.0, 0.0), "angles": Vector3(away.z * 0.24 * fold, 0.0, 0.0)},
	}


## Circling something you are locked on to.
##
## `lateral` is -1 stepping left through +1 stepping right, `approach` is -1
## backing off through +1 closing. The legs cross over and the hips open, and
## the torso stays square. That last part is the entire point and the one thing
## worth testing: lock-on means you keep facing the thing, so a strafe that
## yaws the torso with the movement has turned its back on what it is locked
## to, and the player loses the read they locked on to get.
static func strafe(lateral: float, approach := 0.0) -> Dictionary:
	var side := clampf(lateral, -1.0, 1.0)
	var toward := clampf(approach, -1.0, 1.0)
	if absf(side) < 0.001 and absf(toward) < 0.001:
		return {}
	# Crossing over: the trailing leg comes across the leading one, so the two
	# take opposite pitch rather than a walk cycle.
	var cross := side * 0.46
	return {
		"left_leg": {
			"offset": Vector3(0.0, maxf(0.0, side) * 0.04, 0.0),
			"angles": Vector3(-cross + toward * 0.20, 0.0, side * 0.14),
		},
		"right_leg": {
			"offset": Vector3(0.0, maxf(0.0, -side) * 0.04, 0.0),
			"angles": Vector3(cross + toward * 0.20, 0.0, side * 0.14),
		},
		# Hips lead the step, shoulders do not follow. No yaw on the torso.
		"torso": {"offset": Vector3(side * 0.03, 0.0, 0.0), "angles": Vector3(toward * 0.08, 0.0, -side * 0.10)},
	}


## Leaning out of cover. -1 is hard left, +1 is hard right.
##
## Exactly mirrored, because a lean that is stronger one way than the other
## gives an advantage to whichever side the author happened to tune, and a
## player will find it.
static func lean(amount: float) -> Dictionary:
	var out := clampf(amount, -1.0, 1.0)
	if absf(out) < 0.001:
		return {}
	return {
		"torso": {"offset": Vector3(out * 0.22, -0.05 * absf(out), 0.0), "angles": Vector3(0.0, 0.0, -out * 0.40)},
		"head": {"offset": Vector3(out * 0.06, 0.0, 0.0), "angles": Vector3(0.0, out * 0.12, -out * 0.22)},
		"left_arm": {"offset": Vector3(out * 0.04, 0.0, 0.0), "angles": Vector3(0.0, 0.0, -out * 0.18)},
		"right_arm": {"offset": Vector3(out * 0.04, 0.0, 0.0), "angles": Vector3(0.0, 0.0, -out * 0.18)},
	}


## Gone to ground. `amount` is 0 standing through 1 flat.
##
## This is the per-zone half only. A body actually lying down is a rotation of
## the whole rig, not six parts each pretending -- see `prone_root_pitch()`,
## which the caller applies to the rig itself. Splitting it that way keeps this
## function pure and keeps the caller honest about the fact that going prone
## moves the thing the zones hang off.
static func prone(amount: float) -> Dictionary:
	var down := clampf(amount, 0.0, 1.0)
	if down <= 0.0:
		return {}
	return {
		"torso": {"offset": Vector3(0.0, -0.18 * down, 0.0), "angles": Vector3(0.14 * down, 0.0, 0.0)},
		# Head up off the floor, because the eyeline is the reason to be here.
		"head": {"offset": Vector3(0.0, 0.05 * down, 0.06 * down), "angles": Vector3(-0.52 * down, 0.0, 0.0)},
		"left_arm": {"offset": Vector3(0.0, -0.04 * down, -0.16 * down), "angles": Vector3(1.24 * down, 0.0, -0.30 * down)},
		"right_arm": {"offset": Vector3(0.0, -0.04 * down, -0.16 * down), "angles": Vector3(1.24 * down, 0.0, 0.30 * down)},
		"left_leg": {"offset": Vector3(-0.05 * down, 0.0, 0.10 * down), "angles": Vector3(-0.22 * down, 0.0, -0.16 * down)},
		"right_leg": {"offset": Vector3(0.05 * down, 0.0, 0.10 * down), "angles": Vector3(-0.22 * down, 0.0, 0.16 * down)},
	}


## The rig pitch that actually puts a body on the floor, in radians.
##
## Kept apart from `prone()` because it is the caller's to apply to the rig
## root. Nearly flat rather than flat: a body perfectly parallel to the ground
## clips into it on any slope the district happens to have.
static func prone_root_pitch(amount: float) -> float:
	return -1.42 * clampf(amount, 0.0, 1.0)


## Lay one pose over another. `over` wins by `weight`, and zones only `base`
## mentions survive untouched.
##
## Poses arrive from different places in the same frame -- a guard held while
## staggering, a lean while strafing -- and without this the last one written
## simply erased the others, which is how a procedural rig ends up snapping
## between states instead of moving through them.
static func blend(base: Dictionary, over: Dictionary, weight: float) -> Dictionary:
	var mix := clampf(weight, 0.0, 1.0)
	if mix <= 0.0:
		return base.duplicate(true)
	var out := base.duplicate(true)
	for zone_id: String in over:
		var layer: Dictionary = over[zone_id]
		var layer_offset: Vector3 = layer.get("offset", Vector3.ZERO)
		var layer_angles: Vector3 = layer.get("angles", Vector3.ZERO)
		if not out.has(zone_id):
			out[zone_id] = {"offset": layer_offset * mix, "angles": layer_angles * mix}
			continue
		var held: Dictionary = out[zone_id]
		out[zone_id] = {
			"offset": (held.get("offset", Vector3.ZERO) as Vector3).lerp(layer_offset, mix),
			"angles": (held.get("angles", Vector3.ZERO) as Vector3).lerp(layer_angles, mix),
		}
	return out
