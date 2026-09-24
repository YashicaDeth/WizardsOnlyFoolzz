class_name RoamerDetail
extends RefCounted

## AX5.3, the distant half. "Nearby population stays inside the 5-20 fully
## simulated budget; distant population is cheaper."
##
## `population_budget_test` proved the near half and then failed itself on
## purpose to record that the far half did not exist: `_cull_distant_roamers()`
## was a single hard cutoff at 230m with nothing between "fully simulated" and
## "gone". That is not a cheaper tier, it is an absence of one, and the seam is
## visible -- a body you were watching stops existing at a fixed radius.
##
## The rule this follows, from the direction doc's insistence that the world
## remembers what you did: **a roamer stops being expensive long before it
## stops being real.** Only the outermost tier frees anything. Everything
## between keeps the actor in `encounter_actors`, keeps its subject id, and
## keeps whatever the player did to it -- a body you shot at 100m is still a
## body you shot when you walk back at 200m.

enum Tier { SIMULATED, REDUCED, DORMANT, CULLED }

## Ranges in metres. SIMULATED is deliberately smaller than the old cull so the
## fully-simulated set is the 5-20 the budget actually asks for, rather than
## everything inside 230m.
const SIMULATED_RANGE := 90.0
const REDUCED_RANGE := 160.0
const DORMANT_RANGE := 230.0

## How often each tier is allowed to think, in seconds. SIMULATED is every
## frame (0.0). The others are not "worse AI" -- they are the same AI asked
## less often, which is what makes the cost curve smooth instead of a cliff.
const TICK_INTERVAL := {
	Tier.SIMULATED: 0.0,
	Tier.REDUCED: 0.25,
	Tier.DORMANT: 1.5,
	Tier.CULLED: 0.0,
}


static func tier_for(distance: float) -> Tier:
	if distance < SIMULATED_RANGE:
		return Tier.SIMULATED
	if distance < REDUCED_RANGE:
		return Tier.REDUCED
	if distance < DORMANT_RANGE:
		return Tier.DORMANT
	return Tier.CULLED


static func tick_interval(tier: Tier) -> float:
	return float(TICK_INTERVAL.get(tier, 0.0))


## Whether the body is drawn. A dormant roamer is still there and still in the
## ledger; it is simply not worth a draw call at that range.
static func renders(tier: Tier) -> bool:
	return tier == Tier.SIMULATED or tier == Tier.REDUCED


## The only tier that removes anything. Kept as a named function so the
## question "does this forget the player's actions?" has exactly one answer
## in the codebase.
static func frees(tier: Tier) -> bool:
	return tier == Tier.CULLED


## Applies the tier to a live actor node. Returns true if the caller should
## free it. Everything short of that is a reduction, never a deletion.
static func apply(node: Node3D, tier: Tier) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if frees(tier):
		return true
	node.visible = renders(tier)
	node.process_mode = Node.PROCESS_MODE_DISABLED if tier == Tier.DORMANT else Node.PROCESS_MODE_INHERIT
	return false


## Relative per-body cost, for the budget test to assert the curve actually
## descends rather than trusting the constants to be sensible.
static func relative_cost(tier: Tier) -> float:
	match tier:
		Tier.SIMULATED: return 1.0
		Tier.REDUCED: return 0.25
		Tier.DORMANT: return 0.04
		_: return 0.0
