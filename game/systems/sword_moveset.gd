class_name SwordMoveset
extends RefCounted

## Authored third-person sword attacks. Mouse motion never enters this class:
## every arc is swept around the body's yaw, while BladeRead side names keep
## guard/parry resolution compatible with the existing combat stack.

const INPUT_BUFFER_WINDOW := 0.16
const CHAIN_WINDOW := 0.46
const ARC_SAMPLES := 7
const CHARGED_HEAVY_SECONDS := 0.72

## One-hand is the authored baseline. Stance factors and the explicit
## running/roll overrides below produce the selected table once in configure,
## rather than scattering weapon questions through the combat state machine.
const WEAPON_TABLES := {
	"sword": {
	"light_1": {
		"windup": 0.18, "active": 0.14, "recovery": 0.30,
		"stamina_cost": 14.0, "side": "right",
		"arc_start": -0.92, "arc_end": 0.72, "reach": 2.55, "height": 1.08,
		"knockback_multiplier": 1.0, "poise_multiplier": 1.0, "motion": "slash", "damage_type": "cut", "cuts": true,
	},
	"light_2": {
		"windup": 0.20, "active": 0.15, "recovery": 0.32,
		"stamina_cost": 14.0, "side": "left",
		"arc_start": 0.88, "arc_end": -0.76, "reach": 2.60, "height": 1.02,
		"knockback_multiplier": 1.0, "poise_multiplier": 1.0, "motion": "slash", "damage_type": "cut", "cuts": true,
	},
	"light_3": {
		"windup": 0.24, "active": 0.17, "recovery": 0.40,
		"stamina_cost": 17.0, "side": "high",
		"arc_start": -0.58, "arc_end": 0.58, "reach": 2.78, "height": 1.18,
		"knockback_multiplier": 1.2, "poise_multiplier": 1.2, "motion": "overhead", "damage_type": "cut", "cuts": true,
	},
	"heavy": {
		"windup": 0.42, "active": 0.22, "recovery": 0.58,
		"stamina_cost": 28.0, "side": "high",
		"arc_start": -1.02, "arc_end": 0.92, "reach": 2.92, "height": 1.16,
		"knockback_multiplier": 3.6, "poise_multiplier": 3.0, "motion": "overhead", "damage_type": "cut", "cuts": true,
	},
	"charged_heavy": {
		"windup": 0.58, "active": 0.24, "recovery": 0.72,
		"stamina_cost": 36.0, "side": "high",
		"arc_start": -1.08, "arc_end": 0.98, "reach": 3.02, "height": 1.16,
		"knockback_multiplier": 4.4, "poise_multiplier": 3.6, "motion": "overhead", "damage_type": "cut", "cuts": true, "breaks_poise": true,
	},
	"running_attack": {
		"windup": 0.25, "active": 0.18, "recovery": 0.46,
		"stamina_cost": 20.0, "side": "right",
		"arc_start": -0.72, "arc_end": 0.58, "reach": 3.10, "height": 1.04,
		"knockback_multiplier": 2.4, "poise_multiplier": 1.8, "motion": "running_slash", "damage_type": "cut", "cuts": true,
	},
	"roll_attack": {
		"windup": 0.16, "active": 0.16, "recovery": 0.38,
		"stamina_cost": 18.0, "side": "low",
		"arc_start": 0.62, "arc_end": -0.62, "reach": 2.74, "height": 0.78,
		"knockback_multiplier": 2.8, "poise_multiplier": 2.1, "motion": "rising_slash", "damage_type": "cut", "cuts": true,
	},
	},
	"shiv": {
		"light_1": {"windup": 0.11, "active": 0.10, "recovery": 0.20, "stamina_cost": 8.0, "side": "right", "arc_start": -0.16, "arc_end": 0.16, "reach": 1.72, "height": 1.02, "knockback_multiplier": 0.45, "poise_multiplier": 0.42, "motion": "thrust", "damage_type": "puncture", "cuts": true},
		"light_2": {"windup": 0.12, "active": 0.10, "recovery": 0.21, "stamina_cost": 8.0, "side": "left", "arc_start": 0.14, "arc_end": -0.14, "reach": 1.78, "height": 1.08, "knockback_multiplier": 0.48, "poise_multiplier": 0.44, "motion": "thrust", "damage_type": "puncture", "cuts": true},
		"light_3": {"windup": 0.14, "active": 0.11, "recovery": 0.25, "stamina_cost": 10.0, "side": "high", "arc_start": -0.12, "arc_end": 0.12, "reach": 1.86, "height": 1.18, "knockback_multiplier": 0.58, "poise_multiplier": 0.55, "motion": "thrust", "damage_type": "puncture", "cuts": true},
		"heavy": {"windup": 0.28, "active": 0.16, "recovery": 0.38, "stamina_cost": 18.0, "side": "high", "arc_start": -0.24, "arc_end": 0.24, "reach": 2.02, "height": 1.10, "knockback_multiplier": 1.35, "poise_multiplier": 1.25, "motion": "thrust", "damage_type": "puncture", "cuts": true},
		"charged_heavy": {"windup": 0.42, "active": 0.18, "recovery": 0.48, "stamina_cost": 25.0, "side": "high", "arc_start": -0.22, "arc_end": 0.22, "reach": 2.12, "height": 1.10, "knockback_multiplier": 2.0, "poise_multiplier": 1.8, "motion": "thrust", "damage_type": "puncture", "cuts": true, "breaks_poise": true},
		"running_attack": {"windup": 0.15, "active": 0.12, "recovery": 0.29, "stamina_cost": 13.0, "side": "right", "arc_start": -0.18, "arc_end": 0.18, "reach": 2.18, "height": 1.00, "knockback_multiplier": 1.05, "poise_multiplier": 0.9, "motion": "running_thrust", "damage_type": "puncture", "cuts": true},
		"roll_attack": {"windup": 0.10, "active": 0.11, "recovery": 0.26, "stamina_cost": 12.0, "side": "low", "arc_start": 0.18, "arc_end": -0.18, "reach": 1.92, "height": 0.76, "knockback_multiplier": 0.9, "poise_multiplier": 0.8, "motion": "rising_thrust", "damage_type": "puncture", "cuts": true},
	},
	"fists": {
		"light_1": {"windup": 0.10, "active": 0.09, "recovery": 0.18, "stamina_cost": 6.0, "side": "right", "arc_start": -0.12, "arc_end": 0.12, "reach": 1.08, "height": 1.05, "knockback_multiplier": 0.55, "poise_multiplier": 0.58, "motion": "jab", "damage_type": "blunt", "cuts": false},
		"light_2": {"windup": 0.11, "active": 0.09, "recovery": 0.18, "stamina_cost": 6.0, "side": "left", "arc_start": 0.12, "arc_end": -0.12, "reach": 1.06, "height": 1.03, "knockback_multiplier": 0.55, "poise_multiplier": 0.58, "motion": "jab", "damage_type": "blunt", "cuts": false},
		"light_3": {"windup": 0.18, "active": 0.12, "recovery": 0.30, "stamina_cost": 10.0, "side": "right", "arc_start": -0.62, "arc_end": 0.42, "reach": 1.18, "height": 1.12, "knockback_multiplier": 0.82, "poise_multiplier": 0.9, "motion": "hook", "damage_type": "blunt", "cuts": false},
		"heavy": {"windup": 0.30, "active": 0.16, "recovery": 0.42, "stamina_cost": 18.0, "side": "high", "arc_start": -0.24, "arc_end": 0.24, "reach": 1.28, "height": 1.02, "knockback_multiplier": 2.2, "poise_multiplier": 1.0, "motion": "shove", "damage_type": "blunt", "cuts": false, "breaks_poise": true},
		"charged_heavy": {"windup": 0.46, "active": 0.18, "recovery": 0.52, "stamina_cost": 24.0, "side": "high", "arc_start": -0.28, "arc_end": 0.28, "reach": 1.36, "height": 1.02, "knockback_multiplier": 3.0, "poise_multiplier": 1.2, "motion": "shove", "damage_type": "blunt", "cuts": false, "breaks_poise": true},
		"running_attack": {"windup": 0.17, "active": 0.13, "recovery": 0.34, "stamina_cost": 13.0, "side": "right", "arc_start": -0.52, "arc_end": 0.36, "reach": 1.38, "height": 0.96, "knockback_multiplier": 1.25, "poise_multiplier": 1.1, "motion": "running_hook", "damage_type": "blunt", "cuts": false},
		"roll_attack": {"windup": 0.12, "active": 0.12, "recovery": 0.30, "stamina_cost": 11.0, "side": "low", "arc_start": 0.38, "arc_end": -0.38, "reach": 1.22, "height": 0.72, "knockback_multiplier": 1.1, "poise_multiplier": 1.0, "motion": "rising_hook", "damage_type": "blunt", "cuts": false},
	},
}

const STANCE_FACTORS := {
	"one_hand": {"timing": 1.0, "stamina": 1.0, "reach": 1.0, "width": 1.0, "knockback": 1.0, "poise": 1.0},
	"two_hand": {"timing": 1.12, "stamina": 1.28, "reach": 1.06, "width": 1.16, "knockback": 1.25, "poise": 1.42},
}

const TWO_HAND_SPECIALS := {
	"running_attack": {"windup_factor": 1.10, "reach_factor": 1.08, "motion_suffix": "_two_hand"},
	"roll_attack": {"windup_factor": 1.06, "poise_factor": 1.16, "motion_suffix": "_two_hand"},
}

## Compatibility for callers that still reference the original public table.
## New combat code should use configure() and attack_definition().
const ATTACKS := WEAPON_TABLES["sword"]

var _current_id := ""
var _elapsed := 0.0
var _next_light := 0
var _chain_left := 0.0
var _buffered_attack := ""
var _buffered_stamina := 0.0
var _buffered_roll := Vector3.ZERO
var weapon_id := "sword"
var stance := "one_hand"
var _attacks: Dictionary = {}


func _init() -> void:
	configure("sword", "one_hand")


func configure(selected_weapon: String, selected_stance: String) -> bool:
	var normalized_weapon := selected_weapon.strip_edges().to_lower()
	if normalized_weapon in ["bare", "bare_hands", "hands", "fist"]:
		normalized_weapon = "fists"
	var normalized_stance := selected_stance.strip_edges().to_lower()
	if not WEAPON_TABLES.has(normalized_weapon) or not STANCE_FACTORS.has(normalized_stance):
		return false
	weapon_id = normalized_weapon
	stance = normalized_stance
	_attacks = _build_table(weapon_id, stance)
	reset()
	return true


static func default_attack_definition(attack_id: String) -> Dictionary:
	return (WEAPON_TABLES["sword"] as Dictionary).get(attack_id, {}).duplicate(true)


func request_light(stamina: float) -> Dictionary:
	var wanted := "light_%d" % (_next_light + 1)
	if is_attacking() and _current_id.begins_with("light_"):
		var current_step := int(_current_id.trim_prefix("light_"))
		wanted = "light_%d" % (current_step % 3 + 1)
	return _request_attack(wanted, stamina)


func request_heavy(stamina: float) -> Dictionary:
	return _request_attack("heavy", stamina)


func request_heavy_release(held_seconds: float, stamina := INF) -> Dictionary:
	var wanted := "charged_heavy" if held_seconds >= CHARGED_HEAVY_SECONDS else "heavy"
	return _request_attack(wanted, stamina)


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

	var definition: Dictionary = _attacks[_current_id]
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
	var definition: Dictionary = _attacks[_current_id]
	return BladeRead.swing_phase(_elapsed, definition.windup, definition.active, definition.recovery)


func phase_progress() -> float:
	if not is_attacking():
		return 1.0
	var definition: Dictionary = _attacks[_current_id]
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
	return _attacks.get(_current_id, {}).duplicate(true)


func time_remaining() -> float:
	if not is_attacking():
		return 0.0
	return maxf(0.0, _total_duration(_attacks[_current_id]) - _elapsed)


func pose_packet() -> Dictionary:
	return {
		"phase": phase(),
		"progress": phase_progress(),
		"side": str(_attacks[_current_id].side) if is_attacking() else "",
		"attack": _current_id,
		"weapon": weapon_id,
		"stance": stance,
		"motion": str(_attacks[_current_id].get("motion", "slash")) if is_attacking() else "",
	}


func full_arc_points(attack_id: String, body_origin := Vector3.ZERO, body_yaw := 0.0) -> PackedVector3Array:
	if not _attacks.has(attack_id):
		return PackedVector3Array()
	return _arc_progress_points(_attacks[attack_id], body_origin, body_yaw, 0.0, 1.0)


func attack_definition(attack_id: String) -> Dictionary:
	var definition: Dictionary = _attacks.get(attack_id, {}).duplicate(true)
	if not definition.is_empty():
		definition["attack"] = attack_id
		definition["weapon"] = weapon_id
		definition["stance"] = stance
	return definition


func reset() -> void:
	_current_id = ""
	_elapsed = 0.0
	_next_light = 0
	_chain_left = 0.0
	_buffered_attack = ""
	_buffered_stamina = 0.0
	_buffered_roll = Vector3.ZERO


func _request_attack(attack_id: String, stamina: float) -> Dictionary:
	if not _attacks.has(attack_id):
		return {"accepted": false, "buffered": false, "stamina_cost": 0.0, "attack": ""}
	var cost := float(_attacks[attack_id].stamina_cost)
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
	var cost := float(_attacks[attack_id].stamina_cost)
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
		"side": str(_attacks[_current_id].side) if is_attacking() else "",
		"weapon": weapon_id,
		"stance": stance,
		"motion": str(_attacks[_current_id].get("motion", "slash")) if is_attacking() else "",
		"attack_data": attack_definition(_current_id) if is_attacking() else {},
	}


func _report_merge(report: Dictionary) -> Dictionary:
	var live := _report()
	for key: String in live:
		report[key] = live[key]
	return report


func _total_duration(definition: Dictionary) -> float:
	return float(definition.windup) + float(definition.active) + float(definition.recovery)


func _build_table(selected_weapon: String, selected_stance: String) -> Dictionary:
	var table: Dictionary = (WEAPON_TABLES[selected_weapon] as Dictionary).duplicate(true)
	var factors: Dictionary = STANCE_FACTORS[selected_stance]
	for attack_id: String in table:
		var attack: Dictionary = table[attack_id]
		attack["windup"] = float(attack.windup) * float(factors.timing)
		attack["active"] = float(attack.active) * float(factors.timing)
		attack["recovery"] = float(attack.recovery) * float(factors.timing)
		attack["stamina_cost"] = float(attack.stamina_cost) * float(factors.stamina)
		attack["reach"] = float(attack.reach) * float(factors.reach)
		attack["arc_start"] = float(attack.arc_start) * float(factors.width)
		attack["arc_end"] = float(attack.arc_end) * float(factors.width)
		attack["knockback_multiplier"] = float(attack.get("knockback_multiplier", 1.0)) * float(factors.knockback)
		attack["poise_multiplier"] = float(attack.get("poise_multiplier", 1.0)) * float(factors.poise)
		attack["breaks_poise"] = bool(attack.get("breaks_poise", false))
		table[attack_id] = attack
	if selected_stance == "two_hand":
		for attack_id: String in TWO_HAND_SPECIALS:
			var attack: Dictionary = table[attack_id]
			var special: Dictionary = TWO_HAND_SPECIALS[attack_id]
			attack["windup"] = float(attack.windup) * float(special.get("windup_factor", 1.0))
			attack["reach"] = float(attack.reach) * float(special.get("reach_factor", 1.0))
			attack["poise_multiplier"] = float(attack.poise_multiplier) * float(special.get("poise_factor", 1.0))
			attack["motion"] = str(attack.motion) + str(special.get("motion_suffix", ""))
			table[attack_id] = attack
	return table


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
