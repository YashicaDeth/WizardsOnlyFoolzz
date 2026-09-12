class_name GoeticSeals
extends RefCounted

## E2.2. The Goetia roster is data, not a bag of textures or a switch statement.
##
## Names and ranks follow the public-domain 72-spirit catalogue; every displayed
## mark is a project-native stroke construction generated from the stable ordinal.
## It deliberately does not reproduce any printed scan. E2.3 may place original
## Ashbloom seals beside these without changing the renderer or its callers.

const ROSTER: Array[Dictionary] = [
	{"id": 1, "name": "BAEL", "rank": "KING"}, {"id": 2, "name": "AGARES", "rank": "DUKE"},
	{"id": 3, "name": "VASSAGO", "rank": "PRINCE"}, {"id": 4, "name": "SAMIGINA", "rank": "MARQUIS"},
	{"id": 5, "name": "MARBAS", "rank": "PRESIDENT"}, {"id": 6, "name": "VALEFOR", "rank": "DUKE"},
	{"id": 7, "name": "AMON", "rank": "MARQUIS"}, {"id": 8, "name": "BARBATOS", "rank": "DUKE"},
	{"id": 9, "name": "PAIMON", "rank": "KING"}, {"id": 10, "name": "BUER", "rank": "PRESIDENT"},
	{"id": 11, "name": "GUSION", "rank": "DUKE"}, {"id": 12, "name": "SITRI", "rank": "PRINCE"},
	{"id": 13, "name": "BELETH", "rank": "KING"}, {"id": 14, "name": "LERAJE", "rank": "MARQUIS"},
	{"id": 15, "name": "ELIGOS", "rank": "DUKE"}, {"id": 16, "name": "ZEPAR", "rank": "DUKE"},
	{"id": 17, "name": "BOTIS", "rank": "PRESIDENT"}, {"id": 18, "name": "BATHIN", "rank": "DUKE"},
	{"id": 19, "name": "SALLOS", "rank": "DUKE"}, {"id": 20, "name": "PURSON", "rank": "KING"},
	{"id": 21, "name": "MARAX", "rank": "PRESIDENT"}, {"id": 22, "name": "IPOS", "rank": "PRINCE"},
	{"id": 23, "name": "AIM", "rank": "DUKE"}, {"id": 24, "name": "NABERIUS", "rank": "MARQUIS"},
	{"id": 25, "name": "GLASYA-LABOLAS", "rank": "PRESIDENT"}, {"id": 26, "name": "BUNE", "rank": "DUKE"},
	{"id": 27, "name": "RONOVE", "rank": "MARQUIS"}, {"id": 28, "name": "BERITH", "rank": "DUKE"},
	{"id": 29, "name": "ASTAROTH", "rank": "DUKE"}, {"id": 30, "name": "FORNEUS", "rank": "MARQUIS"},
	{"id": 31, "name": "FORAS", "rank": "PRESIDENT"}, {"id": 32, "name": "ASMODAY", "rank": "KING"},
	{"id": 33, "name": "GAAP", "rank": "PRINCE"}, {"id": 34, "name": "FURFUR", "rank": "EARL"},
	{"id": 35, "name": "MARCHOSIAS", "rank": "MARQUIS"}, {"id": 36, "name": "STOLAS", "rank": "PRINCE"},
	{"id": 37, "name": "PHENEX", "rank": "MARQUIS"}, {"id": 38, "name": "HALPHAS", "rank": "EARL"},
	{"id": 39, "name": "MALPHAS", "rank": "PRESIDENT"}, {"id": 40, "name": "RAUM", "rank": "EARL"},
	{"id": 41, "name": "FOCALOR", "rank": "DUKE"}, {"id": 42, "name": "VEPAR", "rank": "DUKE"},
	{"id": 43, "name": "SABNOCK", "rank": "MARQUIS"}, {"id": 44, "name": "SHAX", "rank": "MARQUIS"},
	{"id": 45, "name": "VINE", "rank": "KING"}, {"id": 46, "name": "BIFRONS", "rank": "EARL"},
	{"id": 47, "name": "VUAL", "rank": "DUKE"}, {"id": 48, "name": "HAAGENTI", "rank": "PRESIDENT"},
	{"id": 49, "name": "CROCELL", "rank": "DUKE"}, {"id": 50, "name": "FURCAS", "rank": "KNIGHT"},
	{"id": 51, "name": "BALAM", "rank": "KING"}, {"id": 52, "name": "ALLOCES", "rank": "DUKE"},
	{"id": 53, "name": "CAIM", "rank": "PRESIDENT"}, {"id": 54, "name": "MURMUR", "rank": "DUKE"},
	{"id": 55, "name": "OROBAS", "rank": "PRINCE"}, {"id": 56, "name": "GREMORY", "rank": "DUKE"},
	{"id": 57, "name": "OSE", "rank": "PRESIDENT"}, {"id": 58, "name": "AMY", "rank": "PRESIDENT"},
	{"id": 59, "name": "ORIAS", "rank": "MARQUIS"}, {"id": 60, "name": "VAPULA", "rank": "DUKE"},
	{"id": 61, "name": "ZAGAN", "rank": "KING"}, {"id": 62, "name": "VALAC", "rank": "PRESIDENT"},
	{"id": 63, "name": "ANDRAS", "rank": "MARQUIS"}, {"id": 64, "name": "HAURES", "rank": "DUKE"},
	{"id": 65, "name": "ANDREALPHUS", "rank": "MARQUIS"}, {"id": 66, "name": "CIMEIES", "rank": "MARQUIS"},
	{"id": 67, "name": "AMDUSIAS", "rank": "DUKE"}, {"id": 68, "name": "BELIAL", "rank": "KING"},
	{"id": 69, "name": "DECARABIA", "rank": "MARQUIS"}, {"id": 70, "name": "SEERE", "rank": "PRINCE"},
	{"id": 71, "name": "DANTALION", "rank": "DUKE"}, {"id": 72, "name": "ANDROMALIUS", "rank": "EARL"},
]


static func all() -> Array[Dictionary]:
	var seals: Array[Dictionary] = []
	for entry in ROSTER:
		var seal := entry.duplicate()
		seal["strokes"] = strokes_for(int(entry.id))
		seals.append(seal)
	return seals


static func find(seal_id: int) -> Dictionary:
	if seal_id < 1 or seal_id > ROSTER.size():
		return {}
	var seal := ROSTER[seal_id - 1].duplicate()
	seal["strokes"] = strokes_for(seal_id)
	return seal


## Stable authored construction grammar. The ordinal is the authored identity;
## callers receive ordinary path data and never need to know how it was made.
static func strokes_for(seal_id: int) -> Array:
	if seal_id < 1 or seal_id > ROSTER.size():
		return []
	var state := seal_id * 7919 + 104729
	var strokes: Array = []
	var arms := 3 + _next(state) % 4
	state = _next(state)
	var ring := 0.46 + float(_next(state) % 20) / 100.0
	state = _next(state)
	for arm in arms:
		state = _next(state)
		var angle := TAU * (float(arm) / float(arms) + float(state % 17) / 79.0)
		state = _next(state)
		var inner := 0.08 + float(state % 22) / 100.0
		state = _next(state)
		var bend := angle + (0.32 if state % 2 == 0 else -0.32)
		strokes.append([_polar(angle, inner), _polar(bend, ring * 0.58), _polar(angle, ring)])
	# A closed hook gives every construction an intentional centre, while the
	# broken arm paths preserve the stencil grammar from CellOutzType.
	state = _next(state)
	var hook_angle := TAU * float(state % 360) / 360.0
	strokes.append([_polar(hook_angle, ring * 0.4), _polar(hook_angle + 0.7, ring * 0.58), _polar(hook_angle + 1.25, ring * 0.4)])
	return strokes


static func _next(state: int) -> int:
	return int((int(state) * 1103515245 + 12345) & 0x7fffffff)


static func _polar(angle: float, distance: float) -> Array[float]:
	return [cos(angle) * distance, sin(angle) * distance]
