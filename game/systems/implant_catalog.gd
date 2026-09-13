extends RefCounted

## Authored hardware definitions. Names are identifiers, never parsing input:
## nothing guesses a zone from the words "jaw", "arm" or "lung" anymore.

const ENTRIES := {
	"salvaged torque arm": {"zone": "right_arm", "profile": "limb_drive", "armor": 0.22, "max_condition": 120.0, "tint": "9c7446"},
	"copper lung bellows": {"zone": "torso", "profile": "bellows", "armor": 0.08, "max_condition": 72.0, "tint": "a26035"},
	"dose counter": {"zone": "left_arm", "profile": "meter", "armor": 0.03, "max_condition": 48.0, "tint": "b6a26c"},
	"jaw telemetry nail": {"zone": "head", "profile": "jaw_nail", "armor": 0.06, "max_condition": 55.0, "tint": "8f8d82"},
	"left clavicle rail": {"zone": "torso", "profile": "bone_rail", "armor": 0.14, "max_condition": 95.0, "tint": "9a7650"},
	"load-bearing spine cage": {"zone": "torso", "profile": "spine_cage", "armor": 0.24, "max_condition": 145.0, "tint": "747b76"},
	"ledger thumb": {"zone": "left_arm", "profile": "digit_tool", "armor": 0.04, "max_condition": 38.0, "tint": "9f8150"},
	"rangefinder eye": {"zone": "head", "profile": "optic", "armor": 0.05, "max_condition": 64.0, "tint": "7f938d"},
	"ceramic sternum": {"zone": "torso", "profile": "chest_plate", "armor": 0.28, "max_condition": 160.0, "tint": "c0b8a0"},
	"optic spool": {"zone": "head", "profile": "optic_spool", "armor": 0.04, "max_condition": 58.0, "tint": "7f6b55"},
	"ankle compass": {"zone": "left_leg", "profile": "joint_dial", "armor": 0.04, "max_condition": 52.0, "tint": "a38a52"},
	"filter trachea": {"zone": "torso", "profile": "filter_stack", "armor": 0.11, "max_condition": 82.0, "tint": "78846b"},
	"quiet-heart regulator": {"zone": "torso", "profile": "regulator", "armor": 0.10, "max_condition": 88.0, "tint": "697d79"},
	"heel anchors": {"zone": "right_leg", "profile": "joint_anchor", "armor": 0.18, "max_condition": 105.0, "tint": "696e68"},
	"six-finger surgical crown": {"zone": "head", "profile": "surgical_crown", "armor": 0.12, "max_condition": 92.0, "tint": "a79671"},
	"blackbox liver": {"zone": "torso", "profile": "organ_box", "armor": 0.16, "max_condition": 110.0, "tint": "403a35"},
	"remote pulse cage": {"zone": "torso", "profile": "pulse_cage", "armor": 0.20, "max_condition": 126.0, "tint": "725247"},
	"ashline industrial arm": {"zone": "left_arm", "profile": "industrial_limb", "armor": 0.34, "max_condition": 180.0, "tint": "c15d2d"},
	# B5.1. Carried in the arm. The pocket version is the same object in
	# `carry.gd`; what it does is in `crystal_ball.gd` and does not care which.
	"scrying ball": {"zone": "left_arm", "profile": "orb", "armor": 0.02, "max_condition": 40.0, "tint": "9fb6c4"},
	"ashline scrap arm": {"zone": "left_arm", "profile": "scrap_limb", "armor": 0.20, "max_condition": 110.0, "tint": "9d542e"},
	# AT1.5/AT1.7. The tower. It is in the head, it is somebody else's, and it
	# is on this list rather than in a field of its own so that every body
	# panel already finds it and pulling it is the same operation as pulling
	# anything else. `brain_index.gd` owns what it does; this owns what it is.
	# Armour 0.0 on purpose: it protects nothing. It is only a way in.
	"wetwire chip": {"zone": "head", "profile": "wetwire_tower", "armor": 0.0, "max_condition": 70.0, "tint": "6b2a2a"},
}


static func resolve(raw: Variant, forced_zone := "") -> Dictionary:
	var supplied: Dictionary = raw.duplicate(true) if raw is Dictionary else {"name": str(raw)}
	var implant_id := str(supplied.get("id", supplied.get("name", "unknown hardware"))).to_lower()
	var result: Dictionary = (ENTRIES.get(implant_id, {
		"zone": forced_zone if forced_zone != "" else "torso", "profile": "salvage",
		"armor": 0.05, "max_condition": 60.0, "tint": "77736a",
	}) as Dictionary).duplicate(true)
	result.merge(supplied, true)
	result["id"] = implant_id
	result["name"] = str(result.get("name", implant_id))
	result["zone"] = str(result.get("zone", forced_zone if forced_zone != "" else "torso"))
	var maximum := maxf(1.0, float(result.get("max_condition", 100.0)))
	result["max_condition"] = maximum
	result["condition"] = clampf(float(result.get("condition", maximum)), 0.0, maximum)
	return result


static func list(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for value in raw:
			out.append(resolve(value))
	elif raw is Dictionary:
		if raw.has("id") or raw.has("name"):
			out.append(resolve(raw))
		else:
			for zone_id in raw:
				out.append(resolve(raw[zone_id], str(zone_id)))
	return out


static func by_zone(raw: Variant) -> Dictionary:
	var out := {}
	for implant in list(raw):
		out[str(implant.zone)] = implant
	return out


static func label(raw: Variant) -> String:
	return str(resolve(raw).name)
