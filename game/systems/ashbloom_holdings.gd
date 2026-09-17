class_name AshbloomHoldings
extends RefCounted

## Persistent surface holdings derived from the five settlements that already
## generate the Ashbloom. The boundary is the Voronoi partition of those real
## centres clipped to the real region bounds: no decorative province disagrees
## with where its settlement actually stands.

const SUBJECT := "ashbloom_holdings"
const REGION_SIZE := Vector2(470, 370)
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

const DEFINITIONS := [
	{"id": "black_mile_yards", "record": "ashbloom:black_mile_yards", "at": Vector2(-150, -122), "name": "BLACK MILE YARDS", "note": "raider highway, tolls", "held_by": "black_mile"},
	{"id": "soft_rot_communion", "record": "ashbloom:soft_rot_communion", "at": Vector2(130, -122), "name": "SOFT ROT COMMUNION", "note": "fungal forest, shifting", "held_by": "soft_rot"},
	{"id": "bone_yard", "record": "ashbloom:bone_yard", "at": Vector2(-155, 0), "name": "THE BONE YARD", "note": "quarry, Ashline ground", "held_by": "ashline_wreckers"},
	{"id": "ossuary_works", "record": "ashbloom:ossuary_works", "at": Vector2(135, 0), "name": "OSSUARY WORKS", "note": "sealed anatomy industry", "held_by": "choir_of_marrow"},
	{"id": "tunnel_mouth", "record": "ashbloom:tunnel_mouth", "at": Vector2(65, 115), "name": "TUNNEL MOUTH", "note": "floodlit trade route", "held_by": "gate_lanterns"},
]

## Work belongs to the place that caused it. Every revealed holding publishes
## the same two legible verbs while the names, issuer and coordinates come from
## that holding's canonical record: a physical crew to dislodge and a physical
## cache to recover. These are deliberately modest local orders, not the later
## moral choice about who receives the land.
const WORK_TEMPLATES := [
	{
		"suffix": "claim_crew", "type": "raid", "required": 2,
		"offset": Vector2(30, 28), "label": "DISLODGE THE CLAIM CREW",
		"brief": "A two-person crew is enforcing an unrecorded claim on this ground.",
	},
	{
		"suffix": "field_recovery", "type": "collection", "required": 1,
		"offset": Vector2(-30, -24), "label": "RECOVER THE FIELD CACHE",
		"brief": "A sealed local evidence cache remains somewhere inside the holding.",
	},
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
		if bool(holding_entry.get("revealed", false)):
			_ensure_work(id)
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
	var live := ((ensure().get("holdings", {}) as Dictionary).get(id, {}) as Dictionary).duplicate(true)
	var definition := definition_for(id)
	if not definition.is_empty():
		var place := WorldHistory.subject(str(definition.record))
		for key in ["local_work_completed", "local_work_required", "local_work_state"]:
			if place.has(key):
				live[key] = place[key]
	return live


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
		_ensure_work(id)
	WorldHistory.record_event("holding_revealed", {
		"territory": SUBJECT,
		"holding_id": id,
		"subject_id": str(definition.get("record", "")),
		"at": {"x": at.x, "z": at.y},
		"held_by": str(entry.get("held_by", "")),
	})
	return entry


## The stable jobs attached to one place. Calling this for unknown ground does
## not leak it into INDEX: work is published only after the place was revealed.
static func work_orders(id: String) -> Array[Dictionary]:
	ensure()
	var place := WorldHistory.subject(str(definition_for(id).get("record", "")))
	if not bool(place.get("revealed", false)):
		return []
	_ensure_work(id)
	var rows: Array[Dictionary] = []
	for job_id in place.get("work_orders", []):
		var job := WorldHistory.subject(str(job_id))
		if not job.is_empty():
			var row := job.duplicate(true)
			row["id"] = str(job_id)
			rows.append(row)
	return rows


static func accept_work(job_id: String) -> Dictionary:
	var job := WorldHistory.subject(job_id)
	if str(job.get("kind", "")) != "job" or str(job.get("job_class", "")) != "holding_work":
		return {}
	if str(job.get("status", "")) != "offered":
		return job
	var accepted_at := WorldClock.long_stamp()
	# One player decision touches the contract, history and compact receipt.
	# Keep every existing event name, but flush the complete act once.
	WorldHistory.begin_ledger_batch()
	job = WorldHistory.update_subject(job_id, {
		"status": "active", "accepted_at": accepted_at,
	}, "holding_work_accepted")
	PLAYER_ACTION_LEDGER.record("holding_work_started", {
		"subject_id": job_id, "place_id": str(job.get("place_id", "")),
		"holding_id": str(job.get("holding_id", "")), "work_type": str(job.get("work_type", "")),
	})
	WorldHistory.commit_ledger_batch()
	return job


static func complete_work(job_id: String, evidence: Dictionary = {}) -> Dictionary:
	var job := WorldHistory.subject(job_id)
	if str(job.get("status", "")) != "active":
		return job
	var completed_at := WorldClock.long_stamp()
	# Completion may also update the place and open its land decision. All of
	# those facts belong to this one physical resolution and persist together.
	WorldHistory.begin_ledger_batch()
	job = WorldHistory.update_subject(job_id, {
		"status": "completed", "progress": int(job.get("required", 1)),
		"completed_at": completed_at, "evidence": evidence.duplicate(true),
	}, "holding_work_completed")
	PLAYER_ACTION_LEDGER.record("holding_work_resolved", {
		"subject_id": job_id, "place_id": str(job.get("place_id", "")),
		"holding_id": str(job.get("holding_id", "")), "work_type": str(job.get("work_type", "")),
	})
	_refresh_local_work(str(job.get("place_id", "")))
	WorldHistory.commit_ledger_batch()
	return job


static func active_work() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for subject_id in WorldHistory.all_subjects():
		var subject := WorldHistory.subject(str(subject_id))
		if str(subject.get("job_class", "")) != "holding_work" or str(subject.get("status", "")) != "active":
			continue
		var row := subject.duplicate(true)
		row["id"] = str(subject_id)
		active.append(row)
	return active


static func _ensure_work(id: String) -> void:
	var definition := definition_for(id)
	if definition.is_empty():
		return
	var place_id := str(definition.record)
	var place := WorldHistory.subject(place_id)
	if not bool(place.get("revealed", false)):
		return
	var job_ids: Array[String] = []
	for template: Dictionary in WORK_TEMPLATES:
		var job_id := "holding_job:%s:%s" % [id, str(template.suffix)]
		job_ids.append(job_id)
		var target: Vector2 = (definition.at as Vector2) + (template.offset as Vector2)
		WorldHistory.register_subject(job_id, {
			"kind": "job", "job_class": "holding_work",
			"name": "%s // %s" % [str(definition.name), str(template.label)],
			"role": "LOCAL %s ORDER" % str(template.type).to_upper(),
			"status": "offered", "work_type": str(template.type),
			"holding_id": id, "place_id": place_id,
			"issued_by": str(place.get("held_by", definition.held_by)),
			"brief": str(template.brief), "required": int(template.required), "progress": 0,
			"target": {"x": target.x, "z": target.y}, "target_subjects": [],
		})
	var first_publication := not bool(place.get("work_published", false))
	# INDEX asks for these rows while drawing. Do not turn a read into a save on
	# every frame: migrate the place once, then leave the persisted row alone.
	if first_publication or place.get("work_orders", []) != job_ids:
		WorldHistory.amend_subject(place_id, {"work_orders": job_ids, "work_published": true})
	if first_publication:
		WorldHistory.record_event("holding_work_published", {
			"subject_id": place_id, "holding_id": id, "job_ids": job_ids.duplicate(),
		})
	_refresh_local_work(place_id)


## Connected work weakens one local claim without deciding who inherits it.
## The later ascent/corruption act reads `ready_for_decision`; it must still
## charge its own cost and write the actual ownership change.
static func _refresh_local_work(place_id: String) -> void:
	if place_id.is_empty():
		return
	var place := WorldHistory.subject(place_id)
	var orders: Array = place.get("work_orders", [])
	if orders.is_empty():
		return
	var completed := 0
	for job_id in orders:
		if str(WorldHistory.subject(str(job_id)).get("status", "")) == "completed":
			completed += 1
	var state := "held"
	if completed >= orders.size():
		state = "ready_for_decision"
	elif completed > 0:
		state = "disrupted"
	var previous := str(place.get("local_work_state", ""))
	var changes := {
		"local_work_completed": completed, "local_work_required": orders.size(),
		"local_work_state": state,
	}
	if int(place.get("local_work_completed", -1)) != completed or int(place.get("local_work_required", -1)) != orders.size() or previous != state:
		WorldHistory.amend_subject(place_id, changes)
	if state == "ready_for_decision" and previous != state:
		WorldHistory.record_event("holding_claim_disrupted", {
			"subject_id": place_id, "holding_id": str(place.get("holding_id", "")),
			"completed_jobs": orders.duplicate(),
		})


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
