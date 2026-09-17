class_name AshbloomHoldings
extends RefCounted

## Persistent surface holdings derived from the five settlements that already
## generate the Ashbloom. The boundary is the Voronoi partition of those real
## centres clipped to the real region bounds: no decorative province disagrees
## with where its settlement actually stands.

const SUBJECT := "ashbloom_holdings"
const REGION_SIZE := Vector2(470, 370)

const DEFINITIONS := [
	{"id": "black_mile_yards", "record": "ashbloom:black_mile_yards", "at": Vector2(-150, -122), "name": "BLACK MILE YARDS", "note": "raider highway, tolls", "held_by": "black_mile"},
	{"id": "soft_rot_communion", "record": "ashbloom:soft_rot_communion", "at": Vector2(130, -122), "name": "SOFT ROT COMMUNION", "note": "fungal forest, shifting", "held_by": "soft_rot"},
	{"id": "bone_yard", "record": "ashbloom:bone_yard", "at": Vector2(-155, 0), "name": "THE BONE YARD", "note": "quarry, Ashline ground", "held_by": "ashline_wreckers"},
	{"id": "ossuary_works", "record": "ashbloom:ossuary_works", "at": Vector2(135, 0), "name": "OSSUARY WORKS", "note": "sealed anatomy industry", "held_by": "choir_of_marrow"},
	{"id": "tunnel_mouth", "record": "ashbloom:tunnel_mouth", "at": Vector2(65, 115), "name": "TUNNEL MOUTH", "note": "floodlit trade route", "held_by": "gate_lanterns"},
]


static func ensure() -> Dictionary:
	var record := WorldHistory.subject(SUBJECT)
	var holdings: Dictionary = (record.get("holdings", {}) as Dictionary).duplicate(true)
	var changed := record.is_empty()
	for definition: Dictionary in DEFINITIONS:
		var id := str(definition.id)
		if not holdings.has(id):
			holdings[id] = {
				"revealed": false,
				"held_by": str(definition.held_by),
				"revealed_at": "",
			}
			changed = true
		var holding_entry: Dictionary = holdings[id]
		var current_holder := str(holding_entry.get("held_by", definition.held_by))
		# One place subject is the referent shared by INDEX, the Board, local law
		# and later jobs. The nested territory row is the compact map overview;
		# this registration migrates existing saves from that authoritative row,
		# while all later mutations must update both through this class.
		WorldHistory.register_subject(str(definition.record), {
			"kind": "place",
			"name": str(definition.name),
			"role": "ASHBLOOM HOLDING",
			"territory": SUBJECT,
			"holding_id": id,
			"held_by": current_holder,
			"faction_id": current_holder,
			"revealed": bool(holding_entry.get("revealed", false)),
			"revealed_at": str(holding_entry.get("revealed_at", "")),
			"note": str(definition.note),
			"at": {"x": (definition.at as Vector2).x, "z": (definition.at as Vector2).y},
			"relations": {current_holder: {"kind": "held_by", "strength": 100}},
		})
	if record.is_empty():
		return WorldHistory.register_subject(SUBJECT, {
			"kind": "territory",
			"name": "THE ASHBLOOM EXPANSE",
			"holdings": holdings,
			"active_holding": "",
			"revealed_count": 0,
		})
	if changed:
		return WorldHistory.amend_subject(SUBJECT, {"holdings": holdings})
	return record


static func overview() -> Dictionary:
	var record := ensure()
	var holdings: Dictionary = record.get("holdings", {})
	var rows: Array[Dictionary] = []
	for definition: Dictionary in DEFINITIONS:
		var row := definition.duplicate(true)
		row.merge((holdings.get(str(definition.id), {}) as Dictionary), true)
		rows.append(row)
	return {
		"name": str(record.get("name", "THE ASHBLOOM EXPANSE")),
		"active_holding": str(record.get("active_holding", "")),
		"revealed_count": int(record.get("revealed_count", 0)),
		"holdings": rows,
	}


static func holding(id: String) -> Dictionary:
	return ((ensure().get("holdings", {}) as Dictionary).get(id, {}) as Dictionary).duplicate(true)


static func nearest_id(at: Vector2) -> String:
	var nearest := ""
	var nearest_distance := INF
	for definition: Dictionary in DEFINITIONS:
		var distance := at.distance_squared_to(definition.at)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = str(definition.id)
	return nearest


## The one jurisdiction answer shared by combat, local law and later jobs.
## Looking up where an act happened does not reveal it to the player; MAP still
## owns discovery through `observe()`. The law can know whose ground it is even
## while the player has not surveyed the border yet.
static func jurisdiction_at(at: Vector2) -> Dictionary:
	var id := nearest_id(at)
	var definition := definition_for(id)
	if definition.is_empty():
		return {}
	var live := holding(id)
	return {
		"holding_id": id,
		"place_id": str(definition.record),
		"held_by": str(live.get("held_by", definition.held_by)),
		"name": str(definition.name),
	}


## Crossing into a holding reveals that whole named piece once. Fine-grained
## survey still records streets and structures; this is the land identity that
## arrives with weight rather than one more metre of fog.
static func observe(at: Vector2) -> Dictionary:
	var id := nearest_id(at)
	if id.is_empty():
		return {}
	var record := ensure()
	var holdings: Dictionary = (record.get("holdings", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (holdings.get(id, {}) as Dictionary).duplicate(true)
	if bool(entry.get("revealed", false)):
		if str(record.get("active_holding", "")) != id:
			WorldHistory.amend_subject(SUBJECT, {"active_holding": id})
		return entry
	entry["revealed"] = true
	entry["revealed_at"] = WorldClock.long_stamp()
	holdings[id] = entry
	var count := 0
	for holding_id in holdings:
		if bool((holdings[holding_id] as Dictionary).get("revealed", false)):
			count += 1
	WorldHistory.amend_subject(SUBJECT, {
		"holdings": holdings,
		"active_holding": id,
		"revealed_count": count,
	})
	var definition := definition_for(id)
	if not definition.is_empty():
		WorldHistory.amend_subject(str(definition.record), {
			"revealed": true,
			"revealed_at": str(entry.revealed_at),
			"held_by": str(entry.get("held_by", definition.held_by)),
			"faction_id": str(entry.get("held_by", definition.held_by)),
		})
	WorldHistory.record_event("holding_revealed", {
		"territory": SUBJECT,
		"holding_id": id,
		"subject_id": str(definition.get("record", "")),
		"at": {"x": at.x, "z": at.y},
		"held_by": str(entry.get("held_by", "")),
	})
	return entry


static func definition_for(id: String) -> Dictionary:
	for definition: Dictionary in DEFINITIONS:
		if str(definition.id) == id:
			return definition.duplicate(true)
	return {}


## Convex Voronoi cells for every authored centre. The output uses world X/Z
## coordinates and exactly covers the rectangular generated region.
static func polygons() -> Dictionary:
	var result := {}
	var half := REGION_SIZE * 0.5
	for definition: Dictionary in DEFINITIONS:
		var centre: Vector2 = definition.at
		var polygon := PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])
		for other: Dictionary in DEFINITIONS:
			if str(other.id) == str(definition.id):
				continue
			var other_centre: Vector2 = other.at
			var normal := other_centre - centre
			var limit := (other_centre.length_squared() - centre.length_squared()) * 0.5
			polygon = _clip_half_plane(polygon, normal, limit)
		result[str(definition.id)] = polygon
	return result


static func _clip_half_plane(polygon: PackedVector2Array, normal: Vector2, limit: float) -> PackedVector2Array:
	var clipped := PackedVector2Array()
	if polygon.is_empty():
		return clipped
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var a_inside := a.dot(normal) <= limit + 0.001
		var b_inside := b.dot(normal) <= limit + 0.001
		if a_inside:
			clipped.append(a)
		if a_inside != b_inside:
			var direction := b - a
			var denominator := direction.dot(normal)
			if not is_zero_approx(denominator):
				var travel := clampf((limit - a.dot(normal)) / denominator, 0.0, 1.0)
				clipped.append(a + direction * travel)
	return clipped
