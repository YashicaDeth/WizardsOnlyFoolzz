class_name Knockback
extends RefCounted

## Deterministic, owner-driven knockback. The system computes the shove; the
## CharacterBody (or other holder) remains the only thing allowed to move its
## own transform.

const MAX_POISE := 100.0
const POISE_REGEN_PER_SECOND := 24.0
const POISE_DAMAGE_PER_UNIT_IMPULSE := 3.4
const SHOVE_PER_IMPULSE := 0.025
const POISE_BREAK_THRESHOLD := 0.0
const GROUND_FRICTION := 8.0
const MIN_SHOVE_REMAINDER := 0.0005
var poise := MAX_POISE
var _shove_remaining := Vector3.ZERO


func apply(impulse: float, direction: Vector3, attack: Variant) -> Dictionary:
	var heading := direction
	heading.y = 0.0
	if heading.length_squared() > 0.0001:
		heading = heading.normalized()
	else:
		heading = Vector3.ZERO

	var packet := _attack_packet(attack)
	var poise_multiplier := maxf(0.0, float(packet.get("poise_multiplier", 1.0)))
	var shove_multiplier := maxf(0.0, float(packet.get("knockback_multiplier", 1.0)))
	var strength := maxf(impulse, 0.0)
	var poise_damage := strength * POISE_DAMAGE_PER_UNIT_IMPULSE * poise_multiplier
	poise = POISE_BREAK_THRESHOLD if bool(packet.get("breaks_poise", false)) else maxf(POISE_BREAK_THRESHOLD, poise - poise_damage)
	var metres := strength * SHOVE_PER_IMPULSE * shove_multiplier
	var shove := heading * metres
	_shove_remaining += shove
	var stagger := clampf(poise_damage / MAX_POISE, 0.0, 1.0)
	return {
		"shove": shove,
		"stagger": stagger,
		"knockdown": poise <= POISE_BREAK_THRESHOLD,
		"poise_damage": poise_damage,
		"attack": str(packet.get("attack", "")),
	}


func _attack_packet(attack: Variant) -> Dictionary:
	if attack is Dictionary:
		return (attack as Dictionary).duplicate(true)
	# Temporary compatibility for Claude's read-only sandbox wiring. The
	# fallback still reads values from SwordMoveset's data table; Knockback no
	# longer owns a second attack-id list that can drift away from it.
	if attack is String:
		var packet := SwordMoveset.default_attack_definition(str(attack).strip_edges().to_lower())
		packet["attack"] = str(attack)
		return packet
	return {}


func tick(delta: float) -> Vector3:
	var step := maxf(delta, 0.0)
	poise = minf(MAX_POISE, poise + POISE_REGEN_PER_SECOND * step)
	if _shove_remaining.length_squared() <= MIN_SHOVE_REMAINDER * MIN_SHOVE_REMAINDER:
		_shove_remaining = Vector3.ZERO
		return Vector3.ZERO
	var fraction := 1.0 - exp(-GROUND_FRICTION * step)
	var displacement := _shove_remaining * fraction
	_shove_remaining -= displacement
	return displacement


func reset() -> void:
	poise = MAX_POISE
	_shove_remaining = Vector3.ZERO
