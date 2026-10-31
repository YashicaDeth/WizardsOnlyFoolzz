class_name SoulsRoll
extends RefCounted

## A deterministic, owner-driven Souls roll. The caller supplies a direction
## in its chosen movement frame (camera-relative or lock-relative), spends the
## returned stamina cost, and applies velocity() to its authoritative body.

const DURATION := 0.58
const I_FRAME_START := 0.08
const I_FRAME_END := 0.34
const DISTANCE := 4.8
const STAMINA_COST := 25.0
const RECOVERY := 0.22
const BUFFER_WINDOW := 0.16

var _direction := Vector3.ZERO
var _elapsed := 0.0
var _recovery_left := 0.0
var _rolling := false


func start(direction: Vector3, stamina: float) -> bool:
	if _rolling or recovering() or stamina + 0.0001 < STAMINA_COST:
		return false
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() <= 0.0001:
		return false
	_direction = flat.normalized()
	_elapsed = 0.0
	_recovery_left = 0.0
	_rolling = true
	return true


func tick(delta: float) -> void:
	var remaining_delta := maxf(0.0, delta)
	if _rolling:
		var roll_left := maxf(0.0, DURATION - _elapsed)
		if remaining_delta < roll_left:
			_elapsed += remaining_delta
			return
		_elapsed = DURATION
		_rolling = false
		_recovery_left = RECOVERY
		remaining_delta -= roll_left
	if _recovery_left > 0.0:
		_recovery_left = maxf(0.0, _recovery_left - remaining_delta)


func is_invulnerable() -> bool:
	return _rolling and _elapsed >= I_FRAME_START and _elapsed < I_FRAME_END


func is_rolling() -> bool:
	return _rolling


func recovering() -> bool:
	return not _rolling and _recovery_left > 0.0


func velocity() -> Vector3:
	if not _rolling:
		return Vector3.ZERO
	# Starts hard and eases without changing the authored total distance: this
	# linear profile averages to exactly one over the roll.
	var speed_scale := lerpf(1.35, 0.65, progress())
	return _direction * (DISTANCE / DURATION) * speed_scale


func direction() -> Vector3:
	return _direction


func progress() -> float:
	return clampf(_elapsed / DURATION, 0.0, 1.0)


func recovery_progress() -> float:
	if _rolling:
		return 0.0
	return clampf(1.0 - _recovery_left / RECOVERY, 0.0, 1.0)


func stamina_cost() -> float:
	return STAMINA_COST


func cancel() -> void:
	_direction = Vector3.ZERO
	_elapsed = 0.0
	_recovery_left = 0.0
	_rolling = false
