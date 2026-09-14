class_name ImpactFeel
extends Node

## O2.2. The moment of contact.
##
## Greg has said the combat needs reworking in four separate sessions. Three
## previous passes answered it by fixing *what* got hit — aim resolution, lock
## on, which limb the zone resolved to, how much gore came off. All of those
## were real bugs and none of them was the complaint, because the complaint was
## never about accuracy. It was about **weight**.
##
## Measurement found the cause and it is embarrassingly specific: there is no
## hitstop in this game. `Engine.time_scale` is touched in exactly two places —
## `kill_cam.gd` and `radial_menu.gd` — and neither of them is a normal swing.
## So landing a cleaver on somebody's ribs advanced the simulation by exactly
## one ordinary frame, the same as swinging at air. Every action game's sense of
## impact is three things arriving on the same frame: time stops briefly, the
## camera moves, and the sound lands. This project had the third one only.
##
## Hitstop is the cheapest of the three and does the most work. A few frames of
## frozen time at the instant of contact reads to the player as the weapon
## meeting resistance, and its absence reads as swinging through fog.

## O2.9 `v4` — **loud is not the same as satisfying.**
##
## Greg on the Gore Sandbox: *"its quite broken with the shooting being hyper
## violent and loud agressive creen shake without feeling satisfying"*. v3 fired
## every channel it owned at close to full aggression on every single shot, and
## four specific things made that read as noise rather than impact:
##
## 1. **Random camera roll on every hit.** `roll += randf_range(-1, 1) * ...`
##    with a ~110ms recovery. Rolling the horizon is the most disorienting and
##    least informative motion a camera has, the sign was a coin flip so it
##    carried no information about what you hit, and it was slow enough to read
##    as a wobble rather than a blow. It is now reserved for hits that have
##    actually earned it and its direction follows the hit.
## 2. **White-noise shake, and too much of it.** `shake` decayed at 3.4/s, so a
##    routine 0.7 shot bought **206ms** of per-frame uncorrelated jitter — longer
##    than the camera kick it was supposed to be decorating, and the last thing
##    you felt from every shot. Uncorrelated noise has no envelope and no
##    direction; it buzzes. It is now a short enveloped ring, and quadratic, so
##    a routine shot barely spends any of the budget.
## 3. **A decay that called itself a spring.** The comment claimed the camera
##    "settles past centre once instead of sliding home" and then implemented
##    `lerp` toward zero, which mathematically cannot overshoot. So every kick
##    slid home over ~250ms. A slow slide is mush. It is a real spring now.
## 4. **No headroom.** Kick was linear in severity, so the constant 0.7 the
##    sandbox passes on every rifle shot already sat at 78% of maximum. A sever
##    had nowhere left to go. Kick and shake are now quadratic in severity and
##    the ceiling has been raised — routine shots land near where they were,
##    severing blows land far harder than anything did before.
##
## The register is unchanged. The violence is not quieter; it is *sorted*, so
## that the top of the range still means something.

## How long time stops, by how hard the thing was hit. These are small numbers
## on purpose: past about 150ms hitstop stops reading as impact and starts
## reading as a frame drop.
const STOP_GRAZE := 0.035
const STOP_SOLID := 0.075
const STOP_HEAVY := 0.115
const STOP_SEVER := 0.150

## What time slows to rather than stopping outright. A true zero freezes audio
## mid-word and reads as a hitch; a heavy crawl reads as impact.
const STOP_SCALE := 0.08

## How far the camera is knocked, in radians, before it recovers. `KICK_HEAVY`
## is the ceiling for a non-severing blow; a sever multiplies past it, which is
## the headroom v3 did not have.
const KICK_GRAZE := 0.008
const KICK_HEAVY := 0.042
const SEVER_KICK := 1.5
## Nothing may stack the camera past this, however fast the trigger is held.
## v3's `kick +=` was unbounded, so sustained fire walked the view into the sky.
const KICK_CEILING := 0.075
## How much of the kick goes sideways. Small, and — crucially — *signed by the
## hit* rather than by `randf`, so the camera is pushed away from what you
## connected with. Direction is information; jitter is not.
const KICK_LATERAL := 0.22

## The spring the v3 comment promised and did not deliver. ~30 rad/s with
## zeta ~0.55: out on the contact frame, back through centre at ~125ms with a
## 13% counter-swing, gone by ~250ms. That counter-swing is the snap.
const KICK_STIFFNESS := 900.0
const KICK_DAMPING := 33.0
## Roll is damped harder than kick. A camera that rings about its own roll axis
## is nausea, not punch, so it gets one firm return and no second swing.
const ROLL_STIFFNESS := 640.0
const ROLL_DAMPING := 36.0
## The spring is integrated in fixed substeps so a long frame cannot make it
## explode, and a *very* long frame (a scene load, a breakpoint) is simply
## caught up to rather than simulated forever.
const SPRING_STEP := 1.0 / 120.0
const SPRING_CATCHUP := 0.25

## Roll is now a deliberate wrench on blows that earned one, not a tic on every
## contact. Below this severity a non-severing hit gets no roll at all.
const ROLL_THRESHOLD := 0.62
const ROLL_HEAVY := 0.016

## Shake, as an enveloped ring rather than per-frame noise. Amplitude is
## **quadratic** in trauma: a 0.35 trauma spends 12% of the budget and a 1.0
## trauma spends all of it. That curve is the whole escalation story — it is
## what leaves a sever somewhere to go after a hundred ordinary shots.
const SHAKE_REACH := 0.016
const SHAKE_DECAY := 6.5
## Kept under half of a 60Hz sample rate so the trace is coherent motion the eye
## can follow rather than aliased fizz. Deliberately not harmonically related,
## so the two axes do not trace a straight diagonal line.
const SHAKE_HZ_X := 15.0
const SHAKE_HZ_Y := 11.0
const SEVER_SHAKE := 1.35

## How each kind of contact spends the four channels. A bullet and a cleaver
## should not be the same event with a different number on it: a bullet is a
## sharp vertical snap with almost no stop and almost no shake, a blunt weapon
## is the one that is allowed to rattle the camera, and an edge sits between.
const DEFAULT_PROFILE := {"stop": 1.0, "kick": 1.0, "shake": 1.0, "roll": 1.0}
const KIND_PROFILE := {
	# A bullet does not meet resistance the way a blade does, and freezing on
	# every shot turns a firearm into a slideshow. The shake cut is the direct
	# answer to Greg's note — the shot keeps its kick and loses its buzz.
	"ballistic": {"stop": 0.35, "kick": 1.0, "shake": 0.5, "roll": 0.35},
	"cut": {"stop": 1.0, "kick": 0.9, "shake": 0.85, "roll": 1.0},
	"shear": {"stop": 1.0, "kick": 1.0, "shake": 1.0, "roll": 1.15},
	"blunt": {"stop": 1.0, "kick": 1.15, "shake": 1.15, "roll": 0.8},
}

var kick := Vector2.ZERO
var roll := 0.0
var shake := 0.0

## O2.5 `v2`. The first version stopped time with `Engine.time_scale`, which
## works and is wrong: your cleaver landing froze every other fight in the
## region, the traffic, the crowd and the weather along with it. Hitstop is
## supposed to say *this blow met resistance* — a global freeze says *the world
## paused for you*, which is a different and much cheaper feeling.
##
## Godot has no per-node time scale, so the local version is done the only way
## it can be: the participants are named, and whoever ticks them multiplies
## their own delta by `scale_for()`. Everything unnamed keeps running at full
## speed. The camera kick and the shake were always local and are unchanged.
var participants: Dictionary = {}

var _stop_remaining := 0.0
var _held := false
var _kick_velocity := Vector2.ZERO
var _roll_velocity := 0.0
var _shake_time := 0.0
var _shake_phase := 0.0
## Which way the last shot threw the view. Flipped per strike so that a caller
## which cannot tell us where the hit came from still gets a *repeatable*
## pattern rather than noise — the same reason real recoil patterns are
## learnable and satisfying and a random spread is not.
var _recoil_side := 1.0
## Set by whoever else owns time in this scene. The kill cam already slows the
## world deliberately and must not be fought over — an impact inside a kill cam
## is part of the kill cam's own timing.
var blocked_by: Callable = Callable()


func _ready() -> void:
	name = "ImpactFeel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


## Called the instant something connects. `severity` is 0-1 against the zone's
## own health, `kind` colours it, and `severed` is the one case that earns the
## longest stop because a limb coming off should be the heaviest thing in the
## game short of a kill.
##
## `from_direction` is the screen-space direction *toward what was hit* — pass
## it and the camera is thrown away from the contact, which tells the player
## where the blow landed without a single pixel of UI. Left at zero it falls
## back to the alternating recoil pattern, so no existing caller breaks.
func strike(severity: float, kind := "cut", severed := false, involved: Array = [], from_direction := Vector2.ZERO) -> void:
	if _busy():
		return
	# Who is in this exchange. Anything not named here carries on at full speed.
	participants.clear()
	for id in involved:
		participants[str(id)] = true
	var weight := clampf(severity, 0.0, 1.0)
	var profile: Dictionary = KIND_PROFILE.get(kind, DEFAULT_PROFILE)
	var stop_scale := float(profile.get("stop", 1.0))
	var kick_scale := float(profile.get("kick", 1.0))
	var shake_scale := float(profile.get("shake", 1.0))
	var roll_scale := float(profile.get("roll", 1.0))

	var duration := STOP_GRAZE
	if severed:
		duration = STOP_SEVER
	elif weight > 0.62:
		duration = STOP_HEAVY
	elif weight > 0.24:
		duration = STOP_SOLID
	# A limb leaving the body is the heaviest thing the game does, and it earns
	# the full stop whatever took it off. Only the routine ballistic hit is
	# shortened — that is the case that was turning full auto into a slideshow.
	if not severed:
		duration *= stop_scale
	_hold(duration)

	# The camera moves away from what you hit, because your own weapon stopping
	# is a force that travels back up your arm. Quadratic in severity so the
	# constant mid-range severity most callers pass sits well below the ceiling
	# and a sever has somewhere to go.
	var strength := lerpf(KICK_GRAZE, KICK_HEAVY, weight * weight) * kick_scale
	if severed:
		strength *= SEVER_KICK
	var lateral := _lateral_for(from_direction)
	kick += Vector2(lateral * KICK_LATERAL, -1.0) * strength
	if kick.length() > KICK_CEILING:
		kick = kick.normalized() * KICK_CEILING

	# Roll only for blows that earned it, and wound the same way the kick went,
	# so it reads as the view being wrenched off the contact rather than as the
	# horizon coming loose.
	if severed or weight > ROLL_THRESHOLD:
		var roll_weight := weight * weight * (SEVER_KICK if severed else 1.0)
		roll += -lateral * ROLL_HEAVY * roll_scale * clampf(roll_weight, 0.0, 1.0)

	var trauma := weight * shake_scale
	if severed:
		trauma *= SEVER_SHAKE
	trauma = clampf(trauma, 0.0, 1.0)
	if trauma > shake:
		shake = trauma
		# A fresh phase per blow, so two hits in quick succession do not
		# continue one another's oscillation and cancel out.
		_shake_phase = randf() * TAU


## A swing that hit nothing. No stop — that is the point, the absence is the
## feedback — but the camera still carries the weight of the weapon through,
## which is what makes a miss feel like a mistake rather than a no-op.
##
## v4 removed the random roll this used to add. A miss is already the weakest
## event in the game; spending a third of the roll budget on it was pure noise.
func whiff() -> void:
	kick += Vector2(_lateral_for(Vector2.ZERO) * 0.18, 0.10) * KICK_GRAZE * 2.2


## Which way this blow throws the view, as a signed lateral in -1..1. A caller
## that knows where the hit came from gets real directionality; one that does
## not gets an alternating pattern with a touch of slop, which is repeatable
## enough to learn and irregular enough not to read as a metronome.
func _lateral_for(from_direction: Vector2) -> float:
	if from_direction.length() > 0.001:
		return clampf(-from_direction.normalized().x, -1.0, 1.0)
	_recoil_side = -_recoil_side
	return clampf(_recoil_side * 0.85 + randf_range(-0.12, 0.12), -1.0, 1.0)


func _busy() -> bool:
	if blocked_by.is_valid() and bool(blocked_by.call()):
		return true
	return false


func _hold(duration: float) -> void:
	_stop_remaining = maxf(_stop_remaining, duration)
	_held = true


## What a given body's delta should be multiplied by this frame. 1.0 for anybody
## not in the exchange, which is the entire point of v2.
func scale_for(id := "") -> float:
	if not _held:
		return 1.0
	if participants.is_empty():
		# Named nobody: treat it as the player's own exchange, which is the
		# common case for a swing that hit scenery.
		return STOP_SCALE
	return STOP_SCALE if participants.has(str(id)) else 1.0


## True while a hit is being felt at all, for anything that needs to know
## without caring who is in it.
func holding() -> bool:
	return _held


func _process(delta: float) -> void:
	# Counted in real seconds. Using the scaled delta to time a slowdown makes
	# the slowdown last a fixed number of *frames* instead of a fixed duration,
	# so it gets longer the harder it is working.
	# v2: `delta` is already real time, because the engine clock is no longer
	# being bent. That also removes the v1 trap where a slowdown timed with a
	# scaled delta lasted a fixed number of frames rather than a fixed duration.
	var real_delta := delta
	if _held:
		_stop_remaining -= real_delta
		if _stop_remaining <= 0.0:
			_held = false
			_stop_remaining = 0.0
			participants.clear()
	_settle(real_delta)
	# Wrapped rather than accumulated forever: a session-long float fed into
	# `sin()` is a precision bug waiting for a long playtest.
	_shake_time = fmod(_shake_time + real_delta, 1024.0)
	shake = maxf(0.0, shake - real_delta * SHAKE_DECAY)


## The spring, integrated in fixed substeps. v3 lerped toward zero and called it
## a spring in the comment; a lerp is a decay and decays never cross centre, so
## every blow slid home instead of snapping back. This actually overshoots once.
func _settle(delta: float) -> void:
	var remaining := minf(delta, SPRING_CATCHUP)
	while remaining > 0.0:
		var step := minf(remaining, SPRING_STEP)
		remaining -= step
		_kick_velocity += (kick * -KICK_STIFFNESS - _kick_velocity * KICK_DAMPING) * step
		kick += _kick_velocity * step
		_roll_velocity += (roll * -ROLL_STIFFNESS - _roll_velocity * ROLL_DAMPING) * step
		roll += _roll_velocity * step
	# Anything writing `kick` directly is held to the same ceiling as `strike()`.
	if kick.length() > KICK_CEILING:
		kick = kick.normalized() * KICK_CEILING


## Whatever is holding the camera adds this. Kept as a read rather than the
## feeler reaching into the camera itself, so the derby and the hunt can each
## apply it in their own rig's terms.
##
## v4: the ring is a pure function of `shake` and the accumulated time, not a
## pair of `randf` calls. Two frames in a row now describe continuous motion —
## which is what an eye reads as a camera being struck, where per-frame noise
## reads as a signal fault. It also makes the trace testable.
func camera_offset() -> Vector2:
	if shake <= 0.0:
		return kick
	var amount := shake * shake * SHAKE_REACH
	var ring := Vector2(
		sin(_shake_time * TAU * SHAKE_HZ_X + _shake_phase),
		sin(_shake_time * TAU * SHAKE_HZ_Y + _shake_phase * 1.7),
	)
	return kick + ring * amount


## Released whether or not anything else goes wrong. A scene that exits while
## time is held would otherwise leave the whole game in slow motion, which is
## the classic way this feature ships as a bug.
func _exit_tree() -> void:
	# v2 no longer touches the global clock, so there is nothing to restore —
	# but the flag is cleared so anything still holding a reference reads 1.0.
	_held = false
	participants.clear()
