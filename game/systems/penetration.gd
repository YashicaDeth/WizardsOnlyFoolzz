class_name Penetration
extends RefCounted

## Greg, on what a bullet should actually do to a body:
##
## > *"say, you shot them in the middle of their hand, you could shoot a hole
## > into their hand because there's not enough there. So a hole shoots. You
## > move down on their arm. You shoot. A hole, it only goes halfway through
## > ... and then blood starts pouring out, running down the arm, dripping
## > down ... if you got shot ten bullets onto the chest, you have all these
## > different holes in your body, like, gaping holes ... certain bullets will
## > only make so much of a penetration wound and a flesh wound."*
##
## One idea covers all of that: **penetration is a budget.** A round arrives with
## a fixed amount of it, spends some getting through whatever is worn, spends the
## rest crossing tissue, and what is left when it reaches the far side decides
## whether there is an exit wound or a hole that stops inside.
##
## That is why the same round does different things to a hand and an upper arm
## without anything being special-cased about hands: a hand is thin, so the
## budget outlasts it and the round goes through; an upper arm is not, so the
## round stops inside and the wound is a crater rather than a tunnel.
##
## `Ballistics.CALIBRES` has carried a `penetration` figure since it was written
## — 0.12 for buckshot up to 0.85 for a rocket — and `fire()` has been putting it
## in every round's payload. Nothing has ever read it. This is what reads it.
##
## Thickness comes from `BodyMesh`'s own profiles rather than a table of its own,
## so a limb that is reshaped is automatically a limb that is a different
## thickness to shoot through.

## How much tissue one point of penetration crosses, in metres. Calibrated so the
## numbers already in `CALIBRES` land where Greg described: buckshot at 0.12
## crosses 54mm and stops inside a forearm; a rifle round at 0.75 crosses 338mm
## and leaves a body through the far side.
const METRES_PER_POINT := 0.45

## Penetration spent getting through a worn layer, before any tissue at all.
## Armour is not a damage reduction here — it is a thickness the round has to
## pay for, which is why a heavy plate can stop a light round outright and barely
## inconvenience a rifle.
const ARMOUR_COST_PER_POINT := 0.55

## Below this much budget left on arrival, the round has nothing to open a wound
## with and has been stopped by what the target is wearing.
const STOPPED := 0.02

## Wound shapes, in the order they get worse.
enum Result {
	STOPPED_BY_ARMOUR,  ## Never reached flesh.
	GRAZE,              ## Broke the surface and no more.
	BLIND,              ## Stopped inside. A crater, and the round is still in there.
	THROUGH,            ## Out the far side. Entry and exit, and the exit is worse.
}


## The whole model, as one call.
##
## `at` is where up the limb it hit, -1 at the bottom to +1 at the top, which is
## the coordinate `BodyMesh`'s profiles use. `across` is which way the round was
## travelling relative to the limb, so a shot front-to-back through a chest
## crosses its shallow axis and one side-to-side crosses its wide one.
static func resolve(zone_id: String, at: float, across_wide_axis: bool, calibre_penetration: float, armour_points: float, limb_length: float) -> Dictionary:
	var profile: Array = BodyMesh.profile_for(zone_id)
	var half: Vector2 = BodyMesh.half_width_at(profile, at)
	# Which way through. A torso is 0.232 wide and 0.113 deep at the shoulder, so
	# the same round is crossing twice as much body one way as the other.
	var thickness: float = (half.x if across_wide_axis else half.y) * 2.0

	var budget := maxf(calibre_penetration, 0.0)
	var spent_on_armour := minf(budget, maxf(armour_points, 0.0) * ARMOUR_COST_PER_POINT)
	budget -= spent_on_armour

	if budget <= STOPPED:
		return _report(Result.STOPPED_BY_ARMOUR, 0.0, thickness, spent_on_armour, limb_length)

	var reach := budget * METRES_PER_POINT
	if reach >= thickness:
		return _report(Result.THROUGH, thickness, thickness, spent_on_armour, limb_length)
	# A round that barely breaks the surface is a graze, not a hole. Without this
	# an armour-sapped round leaves a full crater with a millimetre of depth,
	# which reads as a hit that should have been stopped.
	if reach < thickness * 0.12:
		return _report(Result.GRAZE, reach, thickness, spent_on_armour, limb_length)
	return _report(Result.BLIND, reach, thickness, spent_on_armour, limb_length)


static func _report(result: int, depth: float, thickness: float, armour_spent: float, limb_length: float) -> Dictionary:
	return {
		"result": result,
		"depth": depth,
		"thickness": thickness,
		# 0 at the surface, 1 out the other side. This is the number the wound's
		# appearance scales off, so a hole that nearly went through looks nearly
		# like one that did.
		"fraction": clampf(depth / maxf(thickness, 0.0001), 0.0, 1.0),
		"through": result == Result.THROUGH,
		"armour_spent": armour_spent,
		"limb_length": limb_length,
	}


## What an exit wound is, relative to its entry.
##
## Bigger, and rougher. A round that has crossed a body is tumbling and carrying
## tissue with it, which is the reason an exit is the one people recognise, and
## the reason making it merely "the same hole on the other side" would be the
## one detail that gives the whole system away.
const EXIT_SPREAD := 1.85


## Whether a shot is crossing the wide axis of a limb.
##
## Limbs are built around their own Y, so a round's direction in the limb's local
## space says which way through it is going: mostly along local X is the wide
## way through a torso, mostly along local Z is the shallow way.
static func across_wide_axis(local_direction: Vector3) -> bool:
	return absf(local_direction.x) >= absf(local_direction.z)


## Where up the limb a local point sits, as the -1..1 the profiles use.
static func height_fraction(local_point: Vector3, limb_length: float) -> float:
	return clampf(local_point.y / maxf(limb_length * 0.5, 0.0001), -1.0, 1.0)


## What the worn layers are worth, in penetration points.
##
## Greg wants biopunk/Mad Max outfits with real layers — "then those could have
## layers, then when we get the bullet wounds there can be more layers and
## protection on the actual body". This is the seam that makes that possible
## later without touching anything here: garments and installed hardware both
## report a number, the numbers add, and the round pays the total. Nothing in
## the wound model needs to know what a helmet is.
static func armour_points(garment_values: Array, implant_armour: float) -> float:
	var total := maxf(implant_armour, 0.0)
	for value: float in garment_values:
		total += maxf(value, 0.0)
	return total
