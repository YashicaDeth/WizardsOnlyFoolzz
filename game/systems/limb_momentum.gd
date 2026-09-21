class_name LimbMomentum
extends RefCounted

## AN1. The arm has mass.
##
## Greg, to the playtester: *"i wanna make the hands kinda floppy... the combat
## with the floppy arms as swords is so fun, i want to rework that system into
## something new but keeping that fun of the movement"*. TaKeS, on the same
## thread: *"the physics base fighting — like with shooting, the gun swivels
## with where you aim, and sorta moves around with the momentum"*.
##
## None of Half Sword's code is here and none of it needs to be. What is worth
## taking is one principle, and it is a principle about *authorship*, not about
## ragdolls:
##
##   **The blow is something the player performs, not something they request.**
##
## In this game's combat today, LMB plays a swing. The swing has a windup, it
## resolves, and the damage is a number on the weapon. The player's contribution
## is the timing of one keypress. That is why four separate sessions have ended
## with "combat needs reworking" — there is nothing in the swing that belongs to
## the person swinging it.
##
## So: the weapon is a mass on the end of a spring, anchored to the hand. Where
## you point is where the *anchor* goes; where the weapon actually is lags
## behind, overshoots, and swings through. Moving the mouse hard throws it.
## Stopping does not stop it. And the number that matters — `head_speed()` — is
## how fast the business end is genuinely travelling, measured, not declared.
##
## That single change makes a lazy flick weak and a committed sweep lethal
## without a single new input, and it is the same maths for a cleaver, a rifle
## barrel and an empty hand. Heavier things lag further and hit harder, which is
## the entire weapon-balance conversation handled by one number: `mass`.

## Where the hand wants the weapon, in view space: right, up, forward. The
## anchor, not the weapon — the weapon is wherever the physics put it.
var anchor := Vector3(0.26, -0.22, -0.52)

## Kilograms, roughly. A bare hand is about 0.4, a cleaver 1.4, a sledge 6.
## Everything else about how a weapon feels falls out of this.
var mass := 1.4
## How hard the arm pulls the weapon back toward where it should be. A trained
## arm is stiff; an exhausted one is not, which is what `fatigue` reduces.
var stiffness := 58.0
## How much of the swing the arm absorbs. Low values flop, high values are rigid
## and read as animation again. The interesting band is narrow and it is here.
var damping := 7.4
## 0 fresh, 1 spent. Softens the spring and lets the weapon wander, so a tired
## fighter genuinely cannot hold a guard rather than being told they cannot.
var fatigue := 0.0
## How far the tip is from the grip. Longer weapons move their heads faster for
## the same wrist movement, which is why a spear is not a knife.
var reach := 0.55

## Where the weapon actually is, and how fast, in view space.
var at := Vector3.ZERO
var velocity := Vector3.ZERO
## And the same for its angle — a weapon rotates about the grip as well as
## translating, which is most of what reads as "floppy".
var tilt := Vector2.ZERO
var spin := Vector2.ZERO

## Peak head speed since the last time it was read. A blow is judged on its
## fastest moment, not on the speed at the frame contact happened to resolve.
## Below this the weapon is not swinging, it is being carried. Sag and the
## spring settling both sit under it.
const IDLE_SPEED := 0.9
## How fast an abandoned swing stops counting, in metres of travel per second.
const WORK_DECAY := 6.0
## Metres the business end has travelled in this swing. See `advance` — this is
## what a blow is worth, and `commitment()` is it against a reference.
var _work := 0.0
var _peak_decay := 0.0


func _init() -> void:
	at = anchor


## Called every frame. `look_delta` is the mouse movement in radians this frame —
## the same number the camera is turning by — and it is what throws the weapon,
## because turning your body is how a weapon actually gets its speed.
## `body_velocity` is the player's own movement in view space, so walking into a
## blow adds to it. `delta` should already be scaled by hitstop.
func advance(delta: float, look_delta: Vector2, body_velocity := Vector3.ZERO, gravity := true) -> void:
	if delta <= 0.0:
		return
	var eased := clampf(delta, 0.0, 1.0 / 30.0)

	# Turning throws the weapon. The heavier it is the further it is thrown,
	# because the arm cannot take it with you — this is the whole feel.
	var throw := Vector3(-look_delta.x, look_delta.y, 0.0) * (2.2 + mass * 1.35)
	velocity += throw
	spin += Vector2(look_delta.y, -look_delta.x) * (5.5 + mass * 2.2)

	# Walking into the swing counts. A step forward is real force and the game
	# should not be the only place that is untrue.
	velocity += body_velocity * 0.35 * eased * 60.0 * 0.016

	# The arm pulling it back where it belongs.
	var slack := 1.0 - fatigue * 0.55
	var spring: Vector3 = (anchor - at) * (stiffness * slack)
	var drag: Vector3 = velocity * -(damping * (1.0 - fatigue * 0.35))
	var force := spring + drag
	if gravity:
		# The tip sags. Not world gravity — the fraction of it the arm fails to
		# hold, which is what makes a heavy weapon read as heavy at rest.
		force.y -= 2.4 * mass * (0.4 + fatigue * 0.9)
	velocity += force / maxf(mass, 0.05) * eased
	at += velocity * eased

	# The same spring on the angle, softer, because a wrist gives before an arm.
	var righting := -tilt * (stiffness * 0.42 * slack) - spin * (damping * 0.8)
	spin += righting / maxf(mass, 0.05) * eased
	tilt += spin * eased
	tilt.x = clampf(tilt.x, -1.25, 1.25)
	tilt.y = clampf(tilt.y, -1.25, 1.25)

	# The arm has a length. Past it the weapon is not floppy, it has come off.
	#
	# AN1.4. What happens *at* that limit is the whole design, and the first
	# version got it backwards. It discarded the outward velocity, which meant
	# a hard committed sweep hit the limit early, lost its speed to the clamp,
	# and measured **slower at the head than a gentler swing** — the exact
	# inversion this system exists to prevent. Found by
	# `tests/arm_calibration_test.gd`: 600 deg/s sustained 2.13 m/s against
	# 300 deg/s sustaining 2.52.
	#
	# An arm at full extension does not stop. It starts rotating — the travel
	# becomes a swing about the shoulder. So the outward component is
	# *converted* into spin rather than thrown away, which is both what a body
	# does and what makes a harder swing produce a faster head.
	var stretch := at - anchor
	if stretch.length() > 0.42:
		var outward := stretch.normalized()
		at = anchor + outward * 0.42
		var radial := velocity.project(outward)
		spin += Vector2(-radial.y, radial.x) * (2.6 / maxf(mass, 0.05))
		velocity -= radial

	# AN1.4. **Travel, not speed.** Two measures were tried before this one and
	# both failed the same way, which is worth recording because the failure is
	# the design question.
	#
	# Peak head speed made a single-frame flick worth exactly as much as a
	# committed sweep, because both touch the same top speed. Peak of a smoothed
	# head speed was not much better: a hard sweep spends most of itself at full
	# extension where the spring is fighting it, so the smoothed signal never
	# separated from a gentler swing (2.16 against 2.52 — the wrong way round).
	#
	# What actually distinguishes a blow from a twitch is **how far the business
	# end travelled while it was moving**. That is work done, it is what a blow
	# physically is, and it separates the gestures cleanly because it multiplies
	# speed by duration instead of discarding one of them.
	var speed := head_speed()
	if speed > IDLE_SPEED:
		_work += speed * eased
		_peak_decay = 0.0
	else:
		# A swing that has stopped stops counting, or standing still holding a
		# weapon would slowly become the hardest blow in the game.
		_peak_decay += eased
		if _peak_decay > 0.18:
			_work = maxf(0.0, _work - eased * WORK_DECAY)


## How fast the business end is moving, metres per second. The tip travels
## faster than the grip by however much the weapon is rotating, which is why a
## long weapon swung from the wrist still lands hard.
func head_speed() -> float:
	var from_spin := Vector2(spin.y, spin.x).length() * reach
	return velocity.length() + from_spin


## What that blow was worth, 0..1: metres the head travelled, against the
## metres a committed sweep produces. The reference comes from measurement
## rather than taste — `tests/arm_calibration_test.gd` drives five real
## gestures through this and prints what each one accumulates. At 3.9 metres:
## a slow look scores 0.00, tracking somebody 0.19, a flick 0.48, a deliberate
## swing 0.46, and a hard committed sweep 1.00.
##
## This is the number combat asks for instead of a constant on the weapon: the
## weapon sets the ceiling, the player decides how much of it they earned.
func commitment(reference := 3.9) -> float:
	return clampf(_work / maxf(reference, 0.01), 0.0, 1.0)


## Contact. The weapon stops on what it hit and the arm keeps going, which is
## the feedback that a blow landed on something solid rather than passing
## through it. `resistance` is 0..1 — a throat against a skull.
func strike(resistance := 0.6, normal := Vector3.FORWARD) -> void:
	var bite := clampf(resistance, 0.0, 1.0)
	# Bounce back along what stopped it, keeping the part of the motion that
	# slid along the surface — a blade that skids off a helmet keeps travelling.
	var into := velocity.project(normal)
	var along := velocity - into
	velocity = along * (1.0 - bite * 0.35) - into * (0.15 + bite * 0.55)
	spin *= 1.0 - bite * 0.4
	spin += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * bite * 2.4
	_work = 0.0
	_peak_decay = 0.0


## Nothing was there. The weapon carries through and the arm has to catch it,
## which is why a miss costs something — O5's footing already reads this.
func whiff() -> void:
	velocity *= 1.12
	spin *= 1.15
	_work = 0.0


## Where to draw it. Offset and rotation in view space, for whatever is holding
## the model — the first-person weapon, the cab's gun hand, an empty fist.
func pose() -> Transform3D:
	var basis := Basis(Vector3.RIGHT, tilt.x) * Basis(Vector3.UP, tilt.y)
	return Transform3D(basis, at)


## Bring it back under control — a guard raised, a weapon lowered, a reload. The
## spring is not switched off, it is simply asked for more than usual, so
## settling is still something you watch happen.
func steady(amount := 0.6) -> void:
	var pull := clampf(amount, 0.0, 1.0)
	velocity = velocity.lerp(Vector3.ZERO, pull)
	spin = spin.lerp(Vector2.ZERO, pull)


## The plane the edge swept, in world space.
##
## `BodySlice.plane_from_swing()` wants the line of the cutting edge and the
## direction of travel, and this arm has had both all along: the blade runs from
## the hand at the origin out to the head at `at`, and `velocity` is how that
## head is moving. Both are in view space, so the holder's basis carries them
## into the world the body being cut is standing in.
##
## This is what makes a cut land at the angle it was swung at. Without it the
## rig cuts square across a limb whatever the blow was doing, so an overhead and
## a level slash take an arm off along the same line.
func cut_plane(holder: Basis, through: Vector3) -> Plane:
	return BodySlice.plane_from_swing(through, holder * at, holder * velocity)


## Set the weapon this is carrying. One call rather than four assignments, so a
## weapon swap cannot half-apply.
func carry(weapon_mass: float, weapon_reach: float, arm_stiffness := 58.0) -> void:
	mass = maxf(weapon_mass, 0.05)
	reach = maxf(weapon_reach, 0.05)
	stiffness = arm_stiffness
	# Heavier things damp more in absolute terms or they never settle at all.
	damping = 7.4 + mass * 0.55
