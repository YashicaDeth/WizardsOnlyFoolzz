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
var _peak := 0.0
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
	var stretch := at - anchor
	if stretch.length() > 0.42:
		at = anchor + stretch.normalized() * 0.42
		velocity = velocity.slide(stretch.normalized()) * 0.6

	var speed := head_speed()
	if speed > _peak:
		_peak = speed
		_peak_decay = 0.0
	else:
		# The peak is only worth remembering for as long as a blow lasts.
		_peak_decay += eased
		if _peak_decay > 0.22:
			_peak = speed


## How fast the business end is moving, metres per second. The tip travels
## faster than the grip by however much the weapon is rotating, which is why a
## long weapon swung from the wrist still lands hard.
func head_speed() -> float:
	var from_spin := Vector2(spin.y, spin.x).length() * reach
	return velocity.length() + from_spin


## What that blow was worth, 0..1, against `reference` metres per second as a
## solid committed swing. This is the number combat should ask for instead of a
## constant on the weapon: the weapon sets the ceiling, the player decides how
## much of it they earned.
func commitment(reference := 7.0) -> float:
	return clampf(_peak / maxf(reference, 0.1), 0.0, 1.0)


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
	_peak = 0.0
	_peak_decay = 0.0


## Nothing was there. The weapon carries through and the arm has to catch it,
## which is why a miss costs something — O5's footing already reads this.
func whiff() -> void:
	velocity *= 1.12
	spin *= 1.15
	_peak = 0.0


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


## Set the weapon this is carrying. One call rather than four assignments, so a
## weapon swap cannot half-apply.
func carry(weapon_mass: float, weapon_reach: float, arm_stiffness := 58.0) -> void:
	mass = maxf(weapon_mass, 0.05)
	reach = maxf(weapon_reach, 0.05)
	stiffness = arm_stiffness
	# Heavier things damp more in absolute terms or they never settle at all.
	damping = 7.4 + mass * 0.55
