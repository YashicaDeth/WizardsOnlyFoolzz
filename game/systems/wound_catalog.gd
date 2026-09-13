extends RefCounted

## Authored legacy/story wounds. Combat wounds already arrive as dictionaries
## from AnatomyComponent; prose wounds are migrated through this exact table.

const ENTRIES := {
	"tank scarring": {"zone": "torso", "type": "chemical", "severity": 0.20},
	"raw throat": {"zone": "torso", "type": "chemical", "severity": 0.24},
	"spore-burned right lung": {"zone": "torso", "organ": "right_lung", "type": "chemical", "severity": 0.55},
	"fractured left clavicle": {"zone": "torso", "bone": "left_clavicle", "type": "blunt", "severity": 0.48},
	"crushed right hand": {"zone": "right_arm", "type": "blunt", "severity": 0.62},
	"burst eardrum": {"zone": "head", "organ": "ear", "type": "blunt", "severity": 0.38},
	"missing left eye": {"zone": "head", "organ": "left_eye", "type": "sever", "severity": 1.0},
	"missing right eye": {"zone": "head", "organ": "right_eye", "type": "sever", "severity": 1.0},
	"broken jaw": {"zone": "head", "bone": "jaw", "type": "blunt", "severity": 0.72},
	"glass scars": {"zone": "head", "type": "cut", "severity": 0.25},
	"mycelial graft": {"zone": "torso", "type": "graft", "severity": 0.34},
	"thoracic puncture": {"zone": "torso", "type": "puncture", "severity": 0.68},
	"burned fingertips": {"zone": "right_arm", "type": "burn", "severity": 0.32},
	"fractured left arm": {"zone": "left_arm", "type": "blunt", "severity": 0.70},
}


static func resolve(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		var shaped: Dictionary = raw.duplicate(true)
		shaped["label"] = str(shaped.get("label", shaped.get("type", "wound")))
		shaped["zone"] = str(shaped.get("zone", "torso"))
		shaped["severity"] = clampf(float(shaped.get("severity", 0.4)), 0.0, 1.0)
		return shaped
	var wound_id := str(raw).to_lower()
	var result: Dictionary = (ENTRIES.get(wound_id, {"zone": "torso", "type": "legacy", "severity": 0.4}) as Dictionary).duplicate(true)
	result["id"] = wound_id
	result["label"] = str(raw)
	return result


static func list(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for wound in raw:
			out.append(resolve(wound))
	return out


static func label(raw: Variant) -> String:
	return str(resolve(raw).label)
