class_name FacilityRoutes
extends RefCounted

## Persistent authority for travel through and out of Sublevel 0C.  This is a
## route graph, not a scene-order list: districts are shared between routes and
## an exit is earned by traversing its authored steps.  Combat, locks and NPC
## behaviour remain owned by their respective systems.

const SUBJECT := "facility_escape"
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

const ROUTE_STEALTH := "maintenance_ascent"

const DISTRICTS := {
	"growing_floor": {"name": "Growing Floor", "kind": "occult_laboratory"},
	"waste_gallery": {"name": "Waste Gallery", "kind": "trafficking_tunnel"},
	"maintenance_cistern": {"name": "Maintenance Cistern", "kind": "maintenance_network"},
	"storm_outfall": {"name": "Storm Outfall", "kind": "surface_exit"},
}

const CONNECTIONS := [
	["growing_floor", "waste_gallery"],
	["waste_gallery", "maintenance_cistern"],
	["maintenance_cistern", "storm_outfall"],
]

const ROUTES := {
	ROUTE_STEALTH: {
		"approach": "stealth_exploration",
		"label": "MAINTENANCE ASCENT",
		"steps": ["waste_gallery", "maintenance_cistern", "storm_outfall"],
		"exit": "storm_outfall",
		"surface_position": Vector3(-26.0, 0.0, 12.0),
		"surface_relationships": {"gate_lanterns": 4, "celloutz": -8},
		"mastery_route": true,
		"avoids_derby": true,
	},
}


static func ensure() -> Dictionary:
	var record := WorldHistory.subject(SUBJECT)
	if record.is_empty():
		record = WorldHistory.register_subject(SUBJECT, {
			"kind": "route_network",
			"name": "SUBLEVEL 0C ESCAPE NETWORK",
			"current_district": "growing_floor",
			"active_route": "",
			"route_steps": [],
			"completed_routes": [],
			"pending_surface_handoff": {},
		})
	return record


static func route(route_id: String) -> Dictionary:
	return (ROUTES.get(route_id, {}) as Dictionary).duplicate(true)


static func available_routes() -> Array[String]:
	var result: Array[String] = []
	for route_id: String in ROUTES:
		result.append(route_id)
	return result


static func begin(route_id: String) -> bool:
	var definition := route(route_id)
	if definition.is_empty():
		return false
	var record := ensure()
	if not (record.get("pending_surface_handoff", {}) as Dictionary).is_empty():
		return false
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(SUBJECT, {
		"active_route": route_id,
		"route_steps": [],
	})
	PLAYER_ACTION_LEDGER.record("facility_route_begun", {
		"subject_id": "player",
		"route_id": route_id,
		"approach": definition.approach,
	})
	WorldHistory.commit_ledger_batch()
	return true


static func traverse(district_id: String) -> bool:
	var record := ensure()
	var route_id := str(record.get("active_route", ""))
	var definition := route(route_id)
	if definition.is_empty() or not DISTRICTS.has(district_id):
		return false
	var steps: Array = (record.get("route_steps", []) as Array).duplicate()
	var expected: Array = definition.steps
	if steps.size() >= expected.size() or str(expected[steps.size()]) != district_id:
		return false
	var from_id := str(record.get("current_district", "growing_floor"))
	if not _connected(from_id, district_id):
		return false
	steps.append(district_id)
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(SUBJECT, {
		"current_district": district_id,
		"route_steps": steps,
	})
	PLAYER_ACTION_LEDGER.record("facility_district_traversed", {
		"subject_id": "player", "route_id": route_id,
		"from": from_id, "to": district_id,
	})
	if steps.size() == expected.size():
		_complete(route_id, definition)
	WorldHistory.commit_ledger_batch()
	return true


static func pending_surface_handoff() -> Dictionary:
	return (ensure().get("pending_surface_handoff", {}) as Dictionary).duplicate(true)


static func consume_surface_handoff() -> Dictionary:
	var handoff := pending_surface_handoff()
	if handoff.is_empty():
		return {}
	WorldHistory.begin_ledger_batch()
	_apply_relationships(handoff.get("relationships", {}))
	WorldHistory.amend_subject(SUBJECT, {"pending_surface_handoff": {}})
	PLAYER_ACTION_LEDGER.record("facility_surface_arrival", {
		"subject_id": "player", "route_id": handoff.route_id,
		"exit_id": handoff.exit_id, "surface_position": handoff.surface_position,
	})
	WorldHistory.commit_ledger_batch()
	return handoff


static func _complete(route_id: String, definition: Dictionary) -> void:
	var record := ensure()
	var completed: Array = (record.get("completed_routes", []) as Array).duplicate()
	if not completed.has(route_id):
		completed.append(route_id)
	var at: Vector3 = definition.surface_position
	var handoff := {
		"route_id": route_id,
		"exit_id": str(definition.exit),
		"surface_position": [at.x, at.y, at.z],
		"relationships": (definition.surface_relationships as Dictionary).duplicate(true),
		"avoided_derby": bool(definition.get("avoids_derby", false)),
	}
	WorldHistory.amend_subject(SUBJECT, {
		"active_route": "",
		"completed_routes": completed,
		"pending_surface_handoff": handoff,
	})
	PLAYER_ACTION_LEDGER.record("facility_route_completed", {
		"subject_id": "player", "route_id": route_id,
		"exit_id": definition.exit, "avoided_derby": handoff.avoided_derby,
	})


static func _connected(from_id: String, to_id: String) -> bool:
	for edge: Array in CONNECTIONS:
		if (str(edge[0]) == from_id and str(edge[1]) == to_id) or (str(edge[1]) == from_id and str(edge[0]) == to_id):
			return true
	return false


static func _apply_relationships(changes: Dictionary) -> void:
	for faction_id: String in changes:
		var faction := WorldHistory.subject(faction_id)
		if faction.is_empty():
			faction = WorldHistory.register_subject(faction_id, {
				"kind": "faction", "name": faction_id.replace("_", " ").capitalize(),
				"standing": 0,
			})
		WorldHistory.amend_subject(faction_id, {
			"standing": int(faction.get("standing", 0)) + int(changes[faction_id]),
		})
