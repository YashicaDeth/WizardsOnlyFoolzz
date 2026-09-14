class_name LauncherActor
extends RefCounted

## AD3.1. "A melee build can close on a launcher and live — the distance is
## the puzzle."
##
## Greg: *"with the cybernetics and limb enhancements you should be able to
## viably, with melee, at some points fight people with grenade launchers and
## RPGs — through jumping on rockets, or cutting them in half, sniping them,
## through enhanced character builds."*
##
## The item names its own answer in its own last five words, and the answer is
## **not** "a launcher that does less damage". A launcher that is simply
## weaker is a number; a melee build closing on it is a *puzzle* only if range
## is the thing the weapon is good at and the thing it stops being good at.
## So:
##
##   - **It cannot arm inside `MIN_ARMING_METRES`.** A warhead that has not
##     travelled far enough has not armed, which is true of the real objects
##     this is borrowing its shape from and, much more importantly, is the
##     one rule that makes closing the distance *the* counterplay rather than
##     one of several. Inside that ring the launcher is a person holding a
##     tube.
##   - **The round is slow.** `rocket` in `Ballistics.CALIBRES` leaves the
##     tube at a fraction of a bullet's speed, which is what makes AD3.3's
##     `intercept_near()` a real option against it rather than a theoretical
##     one — you can see it coming and answer it.
##   - **It telegraphs.** A wind-up long enough to read and move on, because
##     a puzzle you cannot see the inputs to is a coin flip.
##
## Kept as pure static functions over plain values rather than as a node, so
## the whole decision is testable without a scene — the same shape
## `combat_response.gd` and `clinch.gd` already use for exactly this reason.

## Inside this, the warhead has not armed and the launcher cannot fire. The
## number is the design: it has to be far enough out that closing it is a
## real act under fire, and close enough in that closing it is possible at
## all for a body that has to cross it on foot.
const MIN_ARMING_METRES := 9.0
## Past this it stops bothering — beyond its own useful envelope rather than
## an arbitrary aggro line.
const MAX_ENGAGE_METRES := 42.0
## How long the tube is up before it goes. Deliberately longer than a melee
## wind-up: the whole move is readable on purpose.
const WINDUP_SECONDS := 1.35
const CYCLE_SECONDS := 4.2
const CALIBRE := "rocket"
## What it does if it connects. Heavy — this is the thing the distance is
## protecting you from, and it should be worth crossing ground to shut down.
const DAMAGE := 46.0
const IMPULSE := 34.0


## Is this actor one? Read off the actor dictionary the encounter loop
## already carries rather than a second registry.
static func is_launcher(actor: Dictionary) -> bool:
	return bool(actor.get("launcher", false))


## AD3.1's whole answer, as one predicate. False inside the arming ring — not
## "less accurate", not "reduced damage": it does not fire.
static func armed_at(distance: float) -> bool:
	return distance >= MIN_ARMING_METRES


static func in_envelope(distance: float) -> bool:
	return armed_at(distance) and distance <= MAX_ENGAGE_METRES


## Advance the tube. Returns what the caller should do this frame, so the
## encounter loop holds no launcher logic of its own: `{"state": "idle" |
## "winding" | "fire", "windup": 0..1}`.
##
## Closing inside the ring mid-wind-up **loses the shot** rather than pausing
## it, which is the difference between the distance being a puzzle and the
## distance being a delay.
static func advance(actor: Dictionary, distance: float, delta: float) -> Dictionary:
	if not is_launcher(actor):
		return {"state": "idle", "windup": 0.0}
	if not in_envelope(distance):
		actor["launcher_clock"] = 0.0
		return {"state": "idle", "windup": 0.0}
	var clock := float(actor.get("launcher_clock", 0.0)) + maxf(delta, 0.0)
	if clock >= CYCLE_SECONDS:
		actor["launcher_clock"] = 0.0
		return {"state": "fire", "windup": 1.0}
	actor["launcher_clock"] = clock
	var winding := clock >= CYCLE_SECONDS - WINDUP_SECONDS
	var progress := 0.0
	if winding:
		progress = clampf((clock - (CYCLE_SECONDS - WINDUP_SECONDS)) / WINDUP_SECONDS, 0.0, 1.0)
	return {"state": "winding" if winding else "idle", "windup": progress}


## The payload a launched round carries, in the shape `_on_round_hit()`
## already reads for a fired shot — so a rocket resolves through the same
## anatomy every other round in this game does (AF1.7), rather than being a
## special explosion that knows about bodies on its own.
static func payload(actor: Dictionary) -> Dictionary:
	return {
		"damage": DAMAGE,
		"impulse": IMPULSE,
		"damage_type": "shear",
		"shooter": str(actor.get("subject_id", "launcher")),
		"launcher": true,
	}
