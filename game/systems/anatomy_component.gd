class_name AnatomyComponent
extends Node

const ImplantCatalog := preload("res://systems/implant_catalog.gd")

signal wounded(result: Dictionary)
signal bleeding_changed(rate: float, blood_remaining: float)
signal critical_state_started()
signal organ_ruptured(organ_id: String, organ: Dictionary)
## Defeated but not dead. Every resolution the player can choose — execute,
## spare, recruit, mind-stamp — happens inside this window, so the window is the
## system. It is symmetric: the player goes down the same way anyone else does.
signal went_down()
signal died(cause: Dictionary)

## Organs sit inside zones. A zone tracks whether a limb still works; an organ
## decides how you die. The distinction matters because two torso hits of equal
## damage should not be interchangeable — one through the gut leaves someone
## bleeding for a minute, one through the heart does not leave them anything.
const ORGANS := {
	"brain": {"zone": "head", "health": 18.0, "bleed": 1.2, "fatal": true},
	"heart": {"zone": "torso", "health": 26.0, "bleed": 3.4, "fatal": false},
	"left_lung": {"zone": "torso", "health": 34.0, "bleed": 1.2, "fatal": false},
	"right_lung": {"zone": "torso", "health": 34.0, "bleed": 1.2, "fatal": false},
	"liver": {"zone": "torso", "health": 40.0, "bleed": 1.8, "fatal": false},
	"gut": {"zone": "torso", "health": 52.0, "bleed": 0.9, "fatal": false},
	"spine": {"zone": "torso", "health": 30.0, "bleed": 0.4, "fatal": false},
}

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
## B6.8v2. This is deliberately separate from an open wound. The body loses
## blood either way, but only an X-ray/anatomy inspection may name this source.
var internal_bleed_rate := 0.0
var pain := 0.0
var consciousness := 100.0
var dead := false
var downed := false
var critical := false
var zones: Dictionary = {}
var organs: Dictionary = {}
var installed_parts: Dictionary = {}
var wounds: Array[Dictionary] = []


func configure(id: String, capacity: float = 5000.0, cybernetics: Variant = {}) -> void:
	subject_id = id
	blood_capacity = maxf(100.0, capacity)
	blood_remaining = blood_capacity
	installed_parts = ImplantCatalog.by_zone(cybernetics)
	zones = DEFAULT_ZONES.duplicate(true)
	for zone_id in zones:
		zones[zone_id] = (zones[zone_id] as Dictionary).duplicate(true)
	organs = {}
	for organ_id in ORGANS:
		var organ: Dictionary = (ORGANS[organ_id] as Dictionary).duplicate(true)
		organ["ruptured"] = false
		organs[organ_id] = organ
	set_process(true)


func apply_hit(zone_id: String, damage: float, impulse: float, damage_type: String = "blunt", organ_id: String = "") -> Dictionary:
	if dead:
		return {"accepted": false, "reason": "dead"}
	var resolved_zone := zone_id if zones.has(zone_id) else "torso"
	var zone: Dictionary = zones[resolved_zone]
	var installed: Dictionary = installed_parts.get(resolved_zone, {})
	var hardware_ratio := implant_condition(resolved_zone)
	var armor := float(installed.get("armor", 0.0)) * hardware_ratio
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
	# B6.7v2. A closed break and a compound break are not the same injury. The
	# former is a disabled structure under intact skin; only a penetrating blow
	# at fracture depth opens it to the world.
	if resolved_zone in ["left_arm", "right_arm", "left_leg", "right_leg"] and float(zone.health) <= float(DEFAULT_ZONES[resolved_zone].health) * 0.40:
		var fracture := "compound" if penetrating else "closed"
		if str(zone.get("fracture", "")) != "compound":
			zone["fracture"] = fracture
			zones[resolved_zone] = zone
		wound["fracture"] = fracture
	if not installed.is_empty():
		wound["implant_condition"] = damage_implant(resolved_zone, applied * (0.30 if penetrating else 0.16))
	wounds.append(wound)
	if wounds.size() > 24:
		wounds.pop_front()
	if bool(zone.critical) and float(zone.health) <= 0.0:
		_enter_critical()
		# Losing the head or the chest drops you. It does not kill you on its
		# own, because what happens next is supposed to be someone's decision.
		go_down()
	# Only something that opens the body reaches what is inside it. A blunt hit
	# breaks the ribs; it does not perforate the liver.
	if penetrating and organs.has(organ_id):
		wound["organ"] = damage_organ(organ_id, applied * 0.7)
	var result := wound.duplicate(true)
	result["blood_remaining"] = blood_remaining
	result["pain"] = pain
	wounded.emit(result)
	return result


func fracture_kind(zone_id: String) -> String:
	return str((zones.get(zone_id, {}) as Dictionary).get("fracture", ""))


func damage_organ(organ_id: String, amount: float) -> Dictionary:
	if not organs.has(organ_id):
		return {}
	var organ: Dictionary = organs[organ_id]
	if bool(organ.ruptured):
		return organ
	organ["health"] = maxf(0.0, float(organ.health) - amount)
	if float(organ.health) <= 0.0:
		organ["ruptured"] = true
		internal_bleed_rate += float(organ.bleed) * 14.0
		pain = clampf(pain + 26.0, 0.0, 100.0)
		organs[organ_id] = organ
		organ_ruptured.emit(organ_id, organ)
		_enter_critical()
		if bool(organ.get("fatal", false)):
			dead = true
			died.emit({"type": "organ_destroyed", "organ": organ_id, "subject_id": subject_id})
	organs[organ_id] = organ
	return organ


func go_down() -> void:
	if downed or dead:
		return
	downed = true
	_enter_critical()
	went_down.emit()


## Someone chose to leave them alive. Bleeding is packed, not healed — sparing a
## person costs the winner nothing and leaves the world a witness.
func stabilise() -> void:
	if dead:
		return
	bleed_rate *= 0.12
	pain = maxf(0.0, pain - 34.0)
	consciousness = maxf(consciousness, 24.0)
	downed = false
	bleeding_changed.emit(bleed_rate, blood_remaining)


func finish(cause: String) -> void:
	if dead:
		return
	dead = true
	downed = false
	died.emit({"type": cause, "subject_id": subject_id, "wounds": wounds.duplicate(true)})


func organ_ok(organ_id: String) -> bool:
	return not bool((organs.get(organ_id, {}) as Dictionary).get("ruptured", false))


func install_part(zone_id: String, part_data: Dictionary) -> Dictionary:
	var part := ImplantCatalog.resolve(part_data, zone_id)
	installed_parts[str(part.zone)] = part
	return part.duplicate(true)


func implant_condition(zone_id: String) -> float:
	var part: Dictionary = installed_parts.get(zone_id, {})
	if part.is_empty():
		return 0.0
	return clampf(float(part.get("condition", 0.0)) / maxf(1.0, float(part.get("max_condition", 100.0))), 0.0, 1.0)


func damage_implant(zone_id: String, amount: float) -> float:
	var part: Dictionary = installed_parts.get(zone_id, {})
	if part.is_empty():
		return 0.0
	part["condition"] = maxf(0.0, float(part.get("condition", 0.0)) - maxf(0.0, amount))
	installed_parts[zone_id] = part
	return implant_condition(zone_id)


## A ruptured heart does not let you keep standing while you bleed out on a
## normal clock, and a severed spine is not a limp.
func _organ_consciousness_drain() -> float:
	var drain := 0.0
	if not organ_ok("heart"):
		drain += 34.0
	if not organ_ok("left_lung"):
		drain += 9.0
	if not organ_ok("right_lung"):
		drain += 9.0
	return drain


func treat_wound(zone_id: String, quality: float) -> void:
	var treatment := clampf(quality, 0.0, 1.0)
	bleed_rate *= 1.0 - treatment * 0.82
	pain = maxf(0.0, pain - treatment * 28.0)
	for wound in wounds:
		if str(wound.get("zone", "")) == zone_id:
			wound["treated"] = true
	bleeding_changed.emit(bleed_rate, blood_remaining)


func has_internal_bleeding() -> bool:
	return internal_bleed_rate > 0.01


func xray_findings() -> Array[String]:
	var findings: Array[String] = []
	for organ_id in organs:
		if bool((organs[organ_id] as Dictionary).get("ruptured", false)):
			findings.append("INTERNAL BLEED: " + str(organ_id).replace("_", " ").to_upper())
	return findings


func mobility_ratio() -> float:
	var left: Dictionary = zones.get("left_leg", DEFAULT_ZONES.left_leg)
	var right: Dictionary = zones.get("right_leg", DEFAULT_ZONES.right_leg)
	var limb_ratio := (float(left.health) / 75.0 + float(right.health) / 75.0) * 0.5
	# A severed spine is not a limp. It floors mobility below anything two bad
	# legs can produce, and no amount of pain management brings it back.
	if not organ_ok("spine"):
		return 0.05
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
		"internal_bleed_rate": snappedf(internal_bleed_rate, 0.01),
		"pain": roundi(pain),
		"consciousness": roundi(consciousness),
		"critical": critical,
		"dead": dead,
		"downed": downed,
		"zones": zones.duplicate(true),
		"organs": organs.duplicate(true),
		"wounds": wounds.duplicate(true),
		"cybernetics": installed_parts.duplicate(true),
	}


func restore(state: Dictionary) -> void:
	blood_capacity = maxf(100.0, float(state.get("blood_capacity", blood_capacity)))
	blood_remaining = clampf(float(state.get("blood", blood_capacity)), 0.0, blood_capacity)
	bleed_rate = maxf(0.0, float(state.get("bleed_rate", 0.0)))
	internal_bleed_rate = maxf(0.0, float(state.get("internal_bleed_rate", 0.0)))
	pain = clampf(float(state.get("pain", 0.0)), 0.0, 100.0)
	consciousness = clampf(float(state.get("consciousness", 100.0)), 0.0, 100.0)
	critical = bool(state.get("critical", false))
	dead = bool(state.get("dead", false))
	downed = bool(state.get("downed", false))
	var saved_zones: Dictionary = state.get("zones", {})
	for zone_id in zones:
		if saved_zones.get(zone_id) is Dictionary:
			zones[zone_id].merge(saved_zones[zone_id], true)
	# Saves written before organs existed simply have none; the defaults built
	# in configure() stand, which is the same migration rule as subjects.
	var saved_organs: Dictionary = state.get("organs", {})
	for organ_id in organs:
		if saved_organs.get(organ_id) is Dictionary:
			organs[organ_id].merge(saved_organs[organ_id], true)
	if state.has("cybernetics"):
		installed_parts = ImplantCatalog.by_zone(state.cybernetics)
	wounds.clear()
	for wound in state.get("wounds", []):
		if wound is Dictionary:
			wounds.append(wound.duplicate(true))


func _process(delta: float) -> void:
	var total_bleed := bleed_rate + internal_bleed_rate
	if dead or total_bleed <= 0.001:
		return
	blood_remaining = maxf(0.0, blood_remaining - total_bleed * delta)
	consciousness = clampf((blood_remaining / blood_capacity) * 120.0 - pain * 0.22 - _organ_consciousness_drain(), 0.0, 100.0)
	bleed_rate = maxf(0.0, bleed_rate - delta * 0.012)
	internal_bleed_rate = maxf(0.0, internal_bleed_rate - delta * 0.006)
	bleeding_changed.emit(bleed_rate, blood_remaining)
	if blood_remaining <= blood_capacity * 0.32:
		_enter_critical()
	if consciousness <= 0.0:
		go_down()
	# Running out of blood is the one thing nobody gets to decide about.
	if blood_remaining <= 0.0:
		dead = true
		died.emit({"type": "bleed_out", "subject_id": subject_id, "wounds": wounds.duplicate(true)})


func _enter_critical() -> void:
	if critical:
		return
	critical = true
	critical_state_started.emit()
