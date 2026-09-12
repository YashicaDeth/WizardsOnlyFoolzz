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

## How far the camera is knocked, in radians, before it recovers.
const KICK_GRAZE := 0.008
const KICK_HEAVY := 0.032

var kick := Vector2.ZERO
var roll := 0.0
var shake := 0.0

var _stop_remaining := 0.0
var _held := false
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
func strike(severity: float, kind := "cut", severed := false) -> void:
	if _busy():
		return
	var weight := clampf(severity, 0.0, 1.0)
	var duration := STOP_GRAZE
	if severed:
		duration = STOP_SEVER
	elif weight > 0.62:
		duration = STOP_HEAVY
	elif weight > 0.24:
		duration = STOP_SOLID
	# Ballistic hits stop less: a bullet does not meet resistance the way a
	# blade does, and freezing on every shot turns a firearm into a slideshow.
	if kind == "ballistic":
		duration *= 0.45
	_hold(duration)

	# The camera moves away from what you hit, because your own weapon stopping
	# is a force that travels back up your arm.
	var strength := lerpf(KICK_GRAZE, KICK_HEAVY, weight)
	kick += Vector2(randf_range(-0.4, 0.4), -1.0) * strength
	roll += randf_range(-1.0, 1.0) * strength * 0.7
	shake = maxf(shake, weight * (1.4 if severed else 1.0))


## A swing that hit nothing. No stop — that is the point, the absence is the
## feedback — but the camera still carries the weight of the weapon through,
## which is what makes a miss feel like a mistake rather than a no-op.
func whiff() -> void:
	kick += Vector2(randf_range(-0.25, 0.25), 0.10) * KICK_GRAZE * 2.2
	roll += randf_range(-1.0, 1.0) * 0.006


func _busy() -> bool:
	if blocked_by.is_valid() and bool(blocked_by.call()):
		return true
	return false


func _hold(duration: float) -> void:
	_stop_remaining = maxf(_stop_remaining, duration)
	if not _held:
		_held = true
		Engine.time_scale = STOP_SCALE


func _process(delta: float) -> void:
	# Counted in real seconds. Using the scaled delta to time a slowdown makes
	# the slowdown last a fixed number of *frames* instead of a fixed duration,
	# so it gets longer the harder it is working.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _held:
		_stop_remaining -= real_delta
		if _stop_remaining <= 0.0:
			_held = false
			_stop_remaining = 0.0
			Engine.time_scale = 1.0
	# The kick springs back rather than decaying to nothing, so the camera
	# settles past centre once instead of sliding home.
	kick = kick.lerp(Vector2.ZERO, clampf(real_delta * 11.0, 0.0, 1.0))
	roll = lerpf(roll, 0.0, clampf(real_delta * 9.0, 0.0, 1.0))
	shake = maxf(0.0, shake - real_delta * 3.4)


## Whatever is holding the camera adds this. Kept as a read rather than the
## feeler reaching into the camera itself, so the derby and the hunt can each
## apply it in their own rig's terms.
func camera_offset() -> Vector2:
	if shake <= 0.0:
		return kick
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.006
	return kick + jitter


## Released whether or not anything else goes wrong. A scene that exits while
## time is held would otherwise leave the whole game in slow motion, which is
## the classic way this feature ships as a bug.
func _exit_tree() -> void:
	if _held:
		Engine.time_scale = 1.0
		_held = false
