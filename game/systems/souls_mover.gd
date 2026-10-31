class_name SoulsMover
extends RefCounted

## Job 3: first-person movement on the Souls pad base, for any owner with a
## CharacterBody3D (the mechanics lab first; the facility route can take the
## same component). Grounded: walk or run by how far the stick is tilted,
## quick to start and quicker to stop, a dip when you land (BodyCam), and a
## roll with i-frames that costs stamina (`SoulsRoll`).
##
## The evade button is Circle on the pad and Ctrl on the keyboard:
##   tap while moving  -> roll that way      tap standing -> backstep roll
##   hold while moving -> sprint (pad)       hold standing -> crouch
##   keyboard Ctrl held while moving crouch-walks (Shift sprints)
## L3 / Shift also sprint. Stamina comes from the owner's `MeleeDriver`.

const WALK := 2.2
const RUN := 4.2
const SPRINT := 6.6
const CROUCH := 1.6
## Metres per second per second. Stopping is deliberately faster than
## starting (Greg: grounded, quick stops).
const ACCEL := 30.0
const STOP := 52.0
const AIR_CONTROL := 0.25
## Stick tilt below this walks, scaled; above it runs.
const RUN_TILT := 0.62
const HOLD_SECONDS := 0.26
const SPRINT_STAMINA := 16.0
const CROUCH_EYE_DROP := 0.5

var roll := SoulsRoll.new()
var crouched := false
var sprinting := false
## Lab-48. Set by the owner from `OrganSystem.failure()`: a body with a lung
## gone and nothing breathing for it cannot sprint.
var winded := false
var eye_drop := 0.0
var _evade_held := -1.0
var _evade_from_pad := false
var _sprint_key := false


func evade_pressed(from_pad: bool) -> void:
	_evade_held = 0.0
	_evade_from_pad = from_pad


## Returns "roll" when the press was a tap and a roll started.
func evade_released(body: CharacterBody3D, input: Vector2, yaw: float, driver: MeleeDriver) -> String:
	var held := _evade_held
	_evade_held = -1.0
	crouched = false
	if held < 0.0 or held >= HOLD_SECONDS:
		return ""
	return "roll" if start_roll(body, input, yaw, driver) else ""


func set_sprint_key(held: bool) -> void:
	_sprint_key = held


func start_roll(body: CharacterBody3D, input: Vector2, yaw: float, driver: MeleeDriver) -> bool:
	if body == null or not body.is_on_floor():
		return false
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	if direction.length_squared() < 0.04:
		direction = Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	var stamina := driver.stamina if driver != null else MeleeDriver.MAX_STAMINA
	if not roll.start(direction, stamina):
		return false
	if driver != null:
		driver.spend(roll.stamina_cost())
	return true


func invulnerable() -> bool:
	return roll.is_invulnerable()


## One physics step. `input` is the raw left stick / WASD (x right, y back),
## analog length kept. The owner calls move_and_slide afterwards.
func tick(body: CharacterBody3D, input: Vector2, yaw: float, delta: float, driver: MeleeDriver) -> void:
	roll.tick(delta)
	var tilt := clampf(input.length(), 0.0, 1.0)
	if _evade_held >= 0.0:
		_evade_held += delta
		if _evade_held >= HOLD_SECONDS:
			# Held: the pad sprints while moving; standing (or the keyboard's
			# Ctrl) crouches.
			crouched = tilt < 0.2 or not _evade_from_pad
	var want_sprint := (_sprint_key or (_evade_held >= HOLD_SECONDS and _evade_from_pad and tilt >= 0.2)) and not crouched
	var stamina := driver.stamina if driver != null else MeleeDriver.MAX_STAMINA
	sprinting = want_sprint and tilt > 0.3 and stamina > 1.0 and not winded
	if sprinting and driver != null:
		driver.spend(SPRINT_STAMINA * delta)
	eye_drop = move_toward(eye_drop, CROUCH_EYE_DROP if crouched else 0.0, delta * 3.2)
	if roll.is_rolling():
		var along := roll.velocity()
		body.velocity.x = along.x
		body.velocity.z = along.z
		return
	var pace := RUN if tilt >= RUN_TILT else WALK * (tilt / RUN_TILT)
	if sprinting:
		pace = SPRINT
	elif crouched:
		pace = minf(pace, CROUCH)
	if roll.recovering():
		pace *= 0.4
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var target := Vector3.ZERO if tilt < 0.05 else direction.normalized() * pace
	var current := Vector3(body.velocity.x, 0, body.velocity.z)
	var rate := ACCEL if target.length() > current.length() * 0.9 and target.length() > 0.0 else STOP
	if not body.is_on_floor():
		rate *= AIR_CONTROL
	current = current.move_toward(target, rate * delta)
	body.velocity.x = current.x
	body.velocity.z = current.z
