class_name BladeRead
extends RefCounted

## Which way a blade is coming, and whether what you are holding up meets it.
##
## Greg wants first-person sword fighting in the register of Mordhau and For
## Honor. Most of Mordhau is already here and was built for other reasons:
## `LimbMomentum` is a real spring-driven arm whose head is moved by the mouse
## (`advance()` takes `look_delta`), and `cut_plane()` reports the plane the
## edge actually swept, which `bone_yard_hunt._melee_cut_plane()` already feeds
## to `hit_at()`. So a swing is already aimed with the mouse and a limb already
## comes off along the line it was struck on rather than square across.
##
## What was missing is the *read* -- the half For Honor is built on. A swing
## has to be classifiable so the defender can be asked to match it, and a guard
## has to either meet it or not. Without that there is nothing to do on defence
## except back away, and a sword fight is two people reading each other.
##
## Four directions rather than For Honor's three, because a first-person fight
## has an underhand and a lock-on duel largely does not.
##
## **Drags come out of this for free.** Mordhau's signature move is changing a
## swing's angle mid-flight to beat the guard that went up to meet it. Nothing
## here implements that: the arm is physical and the mouse keeps moving it, so
## classifying the swing *at the moment of contact* rather than at the moment
## of release means dragging already works. It is a consequence of the arm
## having been built properly, and the only thing that would break it is
## sampling the direction early and remembering it.

## Where a blow came from, and where a guard is held. The same four names for
## both, so meeting one with the other is equality rather than a lookup table
## somebody has to keep correct.
const HIGH := "high"
const LOW := "low"
const LEFT := "left"
const RIGHT := "right"
const SIDES := [HIGH, LOW, LEFT, RIGHT]

## How long after raising a guard it still counts as a parry rather than a
## block. Short enough that it is a read and not a state you can sit in -- the
## whole cost of a guard is that holding it early is worse than timing it.
const PARRY_WINDOW := 0.18

## What a late but correct guard still lets through. Not zero, because a block
## that costs nothing makes the parry window pointless, and not much, because
## reading the direction right is most of the work.
const BLOCK_LEAK := 0.18

## Below this the blade is not really travelling and there is nothing to read.
const MIN_SWING_SPEED := 0.6


## Where a swing is coming from, out of the blade head velocity in view space.
##
## Named for the side it arrives from rather than the way it travels, so a
## guard meets a swing when the two strings are equal. A blade travelling
## downward comes from high; one travelling to the defender right comes from
## their left.
static func swing_side(head_velocity: Vector3) -> String:
	if head_velocity.length() < MIN_SWING_SPEED:
		return ""
	# Vertical wins ties, because an overhead that is slightly off-axis is
	# still read by everybody as an overhead.
	if absf(head_velocity.y) >= absf(head_velocity.x):
		return HIGH if head_velocity.y < 0.0 else LOW
	return LEFT if head_velocity.x > 0.0 else RIGHT


## Where a guard is held, from the mouse.
##
## `aim` is a raw mouse-style delta, so `y` is negative when the player pushes
## up. Taking it in that convention rather than a tidied one keeps the caller
## from having to remember to flip it, which is exactly the sort of thing that
## ends up flipped in one of two call sites.
static func guard_side(aim: Vector2) -> String:
	if aim.length() < 0.001:
		return ""
	if absf(aim.y) >= absf(aim.x):
		return HIGH if aim.y < 0.0 else LOW
	return RIGHT if aim.x > 0.0 else LEFT


## Does this guard meet this swing at all.
static func blocks(guard: String, swing: String) -> bool:
	if guard.is_empty() or swing.is_empty():
		return false
	return guard == swing


## What happens when the two meet.
##
## `guard_age` is how long the guard has been up. `speed` is the blade head
## speed, which decides how badly a parry hurts the attacker -- committing to a
## fast swing and having it turned is the worst thing that can happen to you in
## this kind of fight, and it should be.
##
## Returns `{outcome, through, shock}`: `through` is the fraction of the blow
## that reaches the body, `shock` is what the attacker takes back.
static func resolve(guard: String, guard_age: float, swing: String, speed := 1.0) -> Dictionary:
	if swing.is_empty():
		return {"outcome": "none", "through": 0.0, "shock": 0.0}
	if not blocks(guard, swing):
		# Guarding the wrong side is worth nothing at all. A guard that soaked
		# something regardless of direction would make reading the swing
		# optional, and reading the swing is the game.
		return {"outcome": "open", "through": 1.0, "shock": 0.0}
	if guard_age <= PARRY_WINDOW:
		return {
			"outcome": "parry",
			"through": 0.0,
			# The attacker eats their own commitment.
			"shock": clampf(speed / 6.0, 0.25, 1.6),
		}
	return {"outcome": "block", "through": BLOCK_LEAK, "shock": clampf(speed / 18.0, 0.05, 0.4)}


## Mordhau in first person and Dark Souls in third, out of one decision.
##
## Greg wants both registers: mouse-led and physical up close in first person,
## committed and punishable in third. The whole difference is *when* the swing
## direction is read.
##
## First person samples at contact, so the mouse is still steering the blade
## while it travels and a drag beats the guard that went up to meet it. Third
## person locks the direction at release, so the swing is a commitment -- you
## chose it, you are wearing it, and an opponent who read it correctly gets to
## punish you. That is the Souls read, and it is the same arm and the same
## `cut_plane()` underneath either way.
static func committed_side(released_side: String, contact_side: String, first_person: bool) -> String:
	if first_person:
		# Still steering. Fall back to what was released if the blade has
		# slowed below anything readable by the time it arrives.
		return contact_side if not contact_side.is_empty() else released_side
	return released_side


## Wind-up, active, recovery -- the shape of a committed swing.
##
## Third person needs this and first person largely does not: a physical arm
## already makes its own timing out of how hard you threw it, while a Souls
## swing is an authored commitment whose recovery is the window you get
## punished in. Returns one of `windup`, `active`, `recovery`, `done`.
static func swing_phase(elapsed: float, windup: float, active: float, recovery: float) -> String:
	if elapsed < 0.0:
		return "done"
	if elapsed < windup:
		return "windup"
	if elapsed < windup + active:
		return "active"
	if elapsed < windup + active + recovery:
		return "recovery"
	return "done"


## Whether a swing at this point can be punished.
##
## Recovery only. Being open during your own wind-up would make every trade a
## coin flip, and being open during the active frames would mean the person who
## swung second always wins -- which is the failure everybody who builds this
## has at least once.
static func punishable(phase: String) -> bool:
	return phase == "recovery"


## The stance direction a side reads as, for `CombatStance.guard()`.
##
## A guard is one number there and four names here, so this is where the two
## meet. High is the full raise; the sides are held lower and across; low is
## barely raised at all, which is also why a low guard is the one that gets
## people killed.
static func guard_height(side: String) -> float:
	match side:
		HIGH:
			return 1.0
		LEFT, RIGHT:
			return 0.78
		LOW:
			return 0.46
	return 0.0


## Which way the body leans behind a guard. Left and right are mirrored; high
## and low are square.
static func guard_lean(side: String) -> float:
	match side:
		LEFT:
			return -0.42
		RIGHT:
			return 0.42
	return 0.0
