class_name SwordMoveset
extends RefCounted

## Authored third-person sword attacks. Mouse motion never enters this class:
## every arc is swept around the body's yaw, while BladeRead side names keep
## guard/parry resolution compatible with the existing combat stack.

const INPUT_BUFFER_WINDOW := 0.16
const CHAIN_WINDOW := 0.46
const ARC_SAMPLES := 7

const ATTACKS := {
	"light_1": {
		"windup": 0.18, "active": 0.14, "recovery": 0.30,
		"stamina_cost": 14.0, "side": "right",
		"arc_start": -0.92, "arc_end": 0.72, "reach": 2.55, "height": 1.08,
	},
	"light_2": {
		"windup": 0.20, "active": 0.15, "recovery": 0.32,
		"stamina_cost": 14.0, "side": "left",
		"arc_start": 0.88, "arc_end": -0.76, "reach": 2.60, "height": 1.02,
	},
	"light_3": {
		"windup": 0.24, "active": 0.17, "recovery": 0.40,
		"stamina_cost": 17.0, "side": "high",
		"arc_start": -0.58, "arc_end": 0.58, "reach": 2.78, "height": 1.18,
	},
	"heavy": {
		"windup": 0.42, "active": 0.22, "recovery": 0.58,
		"stamina_cost": 28.0, "side": "high",
		"arc_start": -1.02, "arc_end": 0.92, "reach": 2.92, "height": 1.16,
	},
	"running_attack": {
		"windup": 0.25, "active": 0.18, "recovery": 0.46,
		"stamina_cost": 20.0, "side": "right",
		"arc_start": -0.72, "arc_end": 0.58, "reach": 3.10, "height": 1.04,
	},
	"roll_attack": {
		"windup": 0.16, "active": 0.16, "recovery": 0.38,
		"stamina_cost": 18.0, "side": "low",
		"arc_start": 0.62, "arc_end": -0.62, "reach": 2.74, "height": 0.78,
	},
}

var _current_id := ""
var _elapsed := 0.0
var _next_light := 0
var _chain_left := 0.0
var _buffered_attack := ""
var _buffered_stamina := 0.0
var _buffered_roll := Vector3.ZERO


func request_light(stamina: float) -> Dictionary:
	var wanted := "light_%d" % (_next_light + 1)
	if is_attacking() and _current_id.begins_with("light_"):
		var current_step := int(_current_id.trim_prefix("light_"))
		wanted = "light_%d" % (current_step % 3 + 1)
	return _request_attack(wanted, stamina)


func request_heavy(stamina: float) -> Dictionary:
	return _request_attack("heavy", stamina)


func request_running_attack(stamina: float) -> Dictionary:
	return _request_attack("running_attack", stamina)


func request_roll_attack(stamina: float) -> Dictionary:
	return _request_attack("roll_attack", stamina)


func buffer_roll(direction: Vector3) -> bool:
	if not is_attacking() or phase() != "recovery" or time_remaining() > INPUT_BUFFER_WINDOW:
		return false
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() <= 0.0001 or not _buffered_attack.is_empty():
		return false
	_buffered_roll = flat.normalized()
	return true


func tick(delta: float, body_origin := Vector3.ZERO, body_yaw := 0.0) -> Dictionary:
	var report := _report()
	report["hit_points"] = PackedVector3Array()
	report["roll_direction"] = Vector3.ZERO
	report["started_buffered"] = false
	report["stamina_cost"] = 0.0
	var step := maxf(0.0, delta)
	if not is_attacking():
		_chain_left = maxf(0.0, _chain_left - step)
		if _chain_left <= 0.0:
			_next_light = 0
		return _report_merge(report)

	var definition: Dictionary = ATTACKS[_current_id]
	var before := _elapsed
	var after := before + step
	var active_start: float = definition.windup
	var active_end: float = active_start + float(definition.active)
	if after > active_start and before < active_end:
		var from_progress := clampf((maxf(before, active_start) - active_start) / float(definition.active), 0.0, 1.0)
		var to_progress := clampf((minf(after, active_end) - active_start) / float(definition.active), 0.0, 1.0)
		report["hit_points"] = _arc_progress_points(definition, body_origin, body_yaw, from_progress, to_progress)
	_elapsed = after
	var total := _total_duration(definition)
	if _elapsed < total:
		return _report_merge(report)

	var overflow := maxf(0.0, _elapsed - total)
	var finished_id := _current_id
	_finish_current(finished_id)
	if _buffered_roll.length_squared() > 0.0001:
		report["roll_direction"] = _buffered_roll
		report["started_buffered"] = true
		_buffered_roll = Vector3.ZERO
	elif not _buffered_attack.is_empty():
		var buffered_id := _buffered_attack
		var buffered_stamina := _buffered_stamina
		_buffered_attack = ""
		_buffered_stamina = 0.0
		var started := _begin(buffered_id, buffered_stamina)
		report["started_buffered"] = bool(started.accepted)
		report["stamina_cost"] = float(started.stamina_cost)
	else:
		_chain_left = maxf(0.0, _chain_left - overflow)
		if _chain_left <= 0.0:
			_next_light = 0
	return _report_merge(report)


func phase() -> String:
	if not is_attacking():
		return "done"
	var definition: Dictionary = ATTACKS[_current_id]
	return BladeRead.swing_phase(_elapsed, definition.windup, definition.active, definition.recovery)


func phase_progress() -> float:
	if not is_attacking():
		return 1.0
	var definition: Dictionary = ATTACKS[_current_id]
	match phase():
		"windup":
			return clampf(_elapsed / float(definition.windup), 0.0, 1.0)
		"active":
			return clampf((_elapsed - float(definition.windup)) / float(definition.active), 0.0, 1.0)
		"recovery":
			return clampf((_elapsed - float(definition.windup) - float(definition.active)) / float(definition.recovery), 0.0, 1.0)
	return 1.0


func is_attacking() -> bool:
	return not _current_id.is_empty()


func current_attack() -> String:
	return _current_id


func current_definition() -> Dictionary:
	return ATTACKS.get(_current_id, {}).duplicate(true)


func time_remaining() -> float:
	if not is_attacking():
		return 0.0
	return maxf(0.0, _total_duration(ATTACKS[_current_id]) - _elapsed)


func pose_packet() -> Dictionary:
	return {
		"phase": phase(),
		"progress": phase_progress(),
		"side": str(ATTACKS[_current_id].side) if is_attacking() else "",
		"attack": _current_id,
	}


func full_arc_points(attack_id: String, body_origin := Vector3.ZERO, body_yaw := 0.0) -> PackedVector3Array:
	if not ATTACKS.has(attack_id):
		return PackedVector3Array()
	return _arc_progress_points(ATTACKS[attack_id], body_origin, body_yaw, 0.0, 1.0)


func attack_definition(attack_id: String) -> Dictionary:
	return ATTACKS.get(attack_id, {}).duplicate(true)


func reset() -> void:
	_current_id = ""
	_elapsed = 0.0
	_next_light = 0
	_chain_left = 0.0
	_buffered_attack = ""
	_buffered_stamina = 0.0
	_buffered_roll = Vector3.ZERO


func _request_attack(attack_id: String, stamina: float) -> Dictionary:
	if not ATTACKS.has(attack_id):
		return {"accepted": false, "buffered": false, "stamina_cost": 0.0, "attack": ""}
	var cost := float(ATTACKS[attack_id].stamina_cost)
	if stamina + 0.0001 < cost:
		return {"accepted": false, "buffered": false, "stamina_cost": 0.0, "attack": attack_id}
	if is_attacking():
		if phase() == "recovery" and time_remaining() <= INPUT_BUFFER_WINDOW and _buffered_attack.is_empty() and _buffered_roll.length_squared() <= 0.0001:
			_buffered_attack = attack_id
			_buffered_stamina = stamina
			return {"accepted": false, "buffered": true, "stamina_cost": 0.0, "attack": attack_id}
		return {"accepted": false, "buffered": false, "stamina_cost": 0.0, "attack": attack_id}
	return _begin(attack_id, stamina)


func _begin(attack_id: String, stamina: float) -> Dictionary:
	var cost := float(ATTACKS[attack_id].stamina_cost)
	if stamina + 0.0001 < cost:
		return {"accepted": false, "buffered": false, "stamina_cost": 0.0, "attack": attack_id}
	_current_id = attack_id
	_elapsed = 0.0
	_chain_left = 0.0
	return {"accepted": true, "buffered": false, "stamina_cost": cost, "attack": attack_id}


func _finish_current(finished_id: String) -> void:
	_current_id = ""
	_elapsed = 0.0
	if finished_id.begins_with("light_"):
		var step := int(finished_id.trim_prefix("light_"))
		_next_light = step % 3
		_chain_left = CHAIN_WINDOW
	else:
		_next_light = 0
		_chain_left = 0.0


func _report() -> Dictionary:
	return {
		"attack": _current_id,
		"phase": phase(),
		"phase_progress": phase_progress(),
		"side": str(ATTACKS[_current_id].side) if is_attacking() else "",
	}


func _report_merge(report: Dictionary) -> Dictionary:
	var live := _report()
	for key: String in live:
		report[key] = live[key]
	return report


func _total_duration(definition: Dictionary) -> float:
	return float(definition.windup) + float(definition.active) + float(definition.recovery)


func _arc_progress_points(definition: Dictionary, body_origin: Vector3, body_yaw: float, from_progress: float, to_progress: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var basis := Basis(Vector3.UP, body_yaw)
	var count := maxi(2, ceili(float(ARC_SAMPLES) * maxf(0.12, to_progress - from_progress)))
	for index in count:
		var amount := lerpf(from_progress, to_progress, float(index) / float(count - 1))
		var angle := lerpf(float(definition.arc_start), float(definition.arc_end), amount)
		var local_point := Vector3(sin(angle) * float(definition.reach), float(definition.height), -cos(angle) * float(definition.reach))
		points.append(body_origin + basis * local_point)
	return points
