class_name AnatomyComponent
extends Node

signal wounded(result: Dictionary)
signal bleeding_changed(rate: float, blood_remaining: float)
signal critical_state_started()
signal died(cause: Dictionary)

const DEFAULT_ZONES := {
	"head": {"health": 45.0, "bleed": 0.75, "critical": true},
	"torso": {"health": 120.0, "bleed": 0.42, "critical": true},
	"left_arm": {"health": 65.0, "bleed": 0.55, "critical": false},
	"right_arm": {"health": 65.0, "bleed": 0.55, "critical": false},
	"left_leg": {"health": 75.0, "bleed": 0.62, "critical": false},
	"right_leg": {"health": 75.0, "bleed": 0.62, "critical": false},
}

var subject_id := ""
var blood_capacity := 5000.0
var blood_remaining := 5000.0
var bleed_rate := 0.0
var pain := 0.0
var consciousness := 100.0
var dead := false
var critical := false
var zones: Dictionary = {}
var installed_parts: Dictionary = {}
var wounds: Array[Dictionary] = []


func configure(id: String, capacity: float = 5000.0, cybernetics: Dictionary = {}) -> void:
	subject_id = id
	blood_capacity = maxf(100.0, capacity)
	blood_remaining = blood_capacity
	installed_parts = cybernetics.duplicate(true)
	zones = DEFAULT_ZONES.duplicate(true)
	for zone_id in zones:
		zones[zone_id] = (zones[zone_id] as Dictionary).duplicate(true)
	set_process(true)


func apply_hit(zone_id: String, damage: float, impulse: float, damage_type: String = "blunt") -> Dictionary:
	if dead:
		return {"accepted": false, "reason": "dead"}
	var resolved_zone := zone_id if zones.has(zone_id) else "torso"
	var zone: Dictionary = zones[resolved_zone]
	var armor := float((installed_parts.get(resolved_zone, {}) as Dictionary).get("armor", 0.0))
	var applied := maxf(1.0, damage * (1.0 - clampf(armor, 0.0, 0.85)))
	zone["health"] = maxf(0.0, float(zone.health) - applied)
	zones[resolved_zone] = zone
	var penetrating := damage_type in ["cut", "puncture", "ballistic", "shear"]
	var wound_bleed := applied * float(zone.bleed) * (0.075 if penetrating else 0.018)
	if float(zone.health) <= 0.0:
		wound_bleed *= 2.1
	bleed_rate += wound_bleed
	pain = clampf(pain + applied * 0.72 + impulse * 0.04, 0.0, 100.0)
	var wound := {
		"zone": resolved_zone,
		"damage": snappedf(applied, 0.1),
		"type": damage_type,
		"bleed_rate": snappedf(wound_bleed, 0.01),
		"disabled": float(zone.health) <= 0.0,
		"time_msec": Time.get_ticks_msec(),
	}
	wounds.append(wound)
	if wounds.size() > 24:
		wounds.pop_front()
	if bool(zone.critical) and float(zone.health) <= 0.0:
		_enter_critical()
	var result := wound.duplicate(true)
	result["blood_remaining"] = blood_remaining
	result["pain"] = pain
	wounded.emit(result)
	return result


func treat_wound(zone_id: String, quality: float) -> void:
	var treatment := clampf(quality, 0.0, 1.0)
	bleed_rate *= 1.0 - treatment * 0.82
	pain = maxf(0.0, pain - treatment * 28.0)
	for wound in wounds:
		if str(wound.get("zone", "")) == zone_id:
			wound["treated"] = true
	bleeding_changed.emit(bleed_rate, blood_remaining)


func mobility_ratio() -> float:
	var left: Dictionary = zones.get("left_leg", DEFAULT_ZONES.left_leg)
	var right: Dictionary = zones.get("right_leg", DEFAULT_ZONES.right_leg)
	var limb_ratio := (float(left.health) / 75.0 + float(right.health) / 75.0) * 0.5
	return clampf(limb_ratio * (1.0 - pain * 0.004), 0.18, 1.0)


func combat_ratio() -> float:
	var left: Dictionary = zones.get("left_arm", DEFAULT_ZONES.left_arm)
	var right: Dictionary = zones.get("right_arm", DEFAULT_ZONES.right_arm)
	return clampf((float(left.health) + float(right.health)) / 130.0, 0.15, 1.0)


func snapshot() -> Dictionary:
	return {
		"blood": roundi(blood_remaining),
		"blood_capacity": roundi(blood_capacity),
		"bleed_rate": snappedf(bleed_rate, 0.01),
		"pain": roundi(pain),
		"consciousness": roundi(consciousness),
		"critical": critical,
		"dead": dead,
		"zones": zones.duplicate(true),
		"wounds": wounds.duplicate(true),
		"cybernetics": installed_parts.duplicate(true),
	}


func restore(state: Dictionary) -> void:
	blood_capacity = maxf(100.0, float(state.get("blood_capacity", blood_capacity)))
	blood_remaining = clampf(float(state.get("blood", blood_capacity)), 0.0, blood_capacity)
	bleed_rate = maxf(0.0, float(state.get("bleed_rate", 0.0)))
	pain = clampf(float(state.get("pain", 0.0)), 0.0, 100.0)
	consciousness = clampf(float(state.get("consciousness", 100.0)), 0.0, 100.0)
	critical = bool(state.get("critical", false))
	dead = bool(state.get("dead", false))
	var saved_zones: Dictionary = state.get("zones", {})
	for zone_id in zones:
		if saved_zones.get(zone_id) is Dictionary:
			zones[zone_id].merge(saved_zones[zone_id], true)
	wounds.clear()
	for wound in state.get("wounds", []):
		if wound is Dictionary:
			wounds.append(wound.duplicate(true))


func _process(delta: float) -> void:
	if dead or bleed_rate <= 0.001:
		return
	blood_remaining = maxf(0.0, blood_remaining - bleed_rate * delta)
	consciousness = clampf((blood_remaining / blood_capacity) * 120.0 - pain * 0.22, 0.0, 100.0)
	bleed_rate = maxf(0.0, bleed_rate - delta * 0.012)
	bleeding_changed.emit(bleed_rate, blood_remaining)
	if blood_remaining <= blood_capacity * 0.32:
		_enter_critical()
	if blood_remaining <= 0.0 or consciousness <= 0.0:
		dead = true
		died.emit({"type": "bleed_out", "subject_id": subject_id, "wounds": wounds.duplicate(true)})


func _enter_critical() -> void:
	if critical:
		return
	critical = true
	critical_state_started.emit()
