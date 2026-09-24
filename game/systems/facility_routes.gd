class_name FacilityRoutes
extends RefCounted

## Persistent authority for travel through and out of Sublevel 0C.  This is a
## route graph, not a scene-order list: districts are shared between routes and
## an exit is earned by traversing its authored steps.  Combat, locks and NPC
## behaviour remain owned by their respective systems.

const SUBJECT := "facility_escape"
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

const ROUTE_STEALTH := "maintenance_ascent"
const ROUTE_COOPERATION := "undercroft_compact"
const ROUTE_ASSAULT := "executive_breach"
const ROUTE_RECAPTURE := "containment_derby"
## Greg, 24 September: with the derby shelved as an exit, the Lower Works
## heat elevator carries the player up to the surface. It is the demo's first
## route out; the old drains (ROUTE_STEALTH, walked in `old_drains.tscn`) are
## the second.
const ROUTE_HEAT_ELEVATOR := "heat_elevator_ascent"
## Greg, 24 September (DESIGN/ESCAPE_ROUTES.md): the third way out is chasing
## the doctor. Through his examination room, down the support unit corridor to
## his vehicle bay, where he turns out to be a hologram; the bay's ramp is the
## way up. The bay is played in `doctor_vehicle_bay.tscn`.
const ROUTE_DOCTOR := "doctor_pursuit"

const CONTAINMENT_MECHANISMS := {
	"implant_suppression_lattice": "The rewritten brain implant is pinned by a tuned suppression lattice.",
	"anesthetic_flood": "A marked ventilation sector floods with visible anesthetic.",
	"electromagnetic_snare": "A powered floor snare arrests the escaped body's implants.",
}

const DISTRICTS := {
	"growing_floor": {"name": "Growing Floor", "kind": "occult_laboratory"},
	"waste_gallery": {"name": "Waste Gallery", "kind": "trafficking_tunnel"},
	"maintenance_cistern": {"name": "Maintenance Cistern", "kind": "maintenance_network"},
	"storm_outfall": {"name": "Storm Outfall", "kind": "surface_exit"},
	"ossuary_exchange": {"name": "Ossuary Exchange", "kind": "catacombs"},
	"undercroft_settlement": {"name": "Undercroft Settlement", "kind": "underground_settlement"},
	"lantern_lift": {"name": "Lantern Freight Lift", "kind": "surface_exit"},
	"stolen_freight_spur": {"name": "Stolen Freight Spur", "kind": "surface_exit"},
	"containment_concourse": {"name": "Containment Concourse", "kind": "industrial_prison"},
	"executive_transit": {"name": "Executive Transit", "kind": "corporate_laboratory"},
	"blast_shaft": {"name": "Executive Blast Shaft", "kind": "surface_exit"},
	"processing_chute": {"name": "Reprocessing Chute", "kind": "industrial_prison"},
	"underground_colosseum": {"name": "Underground Colosseum", "kind": "occult_entertainment"},
	"lockdown_grid": {"name": "Lockdown Grid", "kind": "maintenance_network"},
	"vehicle_sallyport": {"name": "Vehicle Sallyport", "kind": "surface_exit"},
	# The Lower Works lift. The Service Arcade and Lower Works themselves are
	# not districts of this graph yet, so it hangs off the facility interior.
	"heat_elevator": {"name": "Lower Works Heat Elevator", "kind": "surface_exit"},
	# The doctor's way out: the room he watched from behind the player's vat,
	# the support unit his staff use, and the bay his vehicle waits in.
	"examination_room": {"name": "Examination Room", "kind": "corporate_laboratory"},
	"support_unit": {"name": "Support Unit", "kind": "maintenance_network"},
	"doctor_vehicle_bay": {"name": "The Doctor's Vehicle Bay", "kind": "surface_exit"},
}

const CONNECTIONS := [
	["growing_floor", "waste_gallery"],
	["waste_gallery", "maintenance_cistern"],
	["maintenance_cistern", "storm_outfall"],
	["growing_floor", "ossuary_exchange"],
	["ossuary_exchange", "undercroft_settlement"],
	["undercroft_settlement", "lantern_lift"],
	["undercroft_settlement", "stolen_freight_spur"],
	["growing_floor", "containment_concourse"],
	["containment_concourse", "executive_transit"],
	["executive_transit", "blast_shaft"],
	["growing_floor", "processing_chute"],
	["processing_chute", "underground_colosseum"],
	["underground_colosseum", "lockdown_grid"],
	["lockdown_grid", "vehicle_sallyport"],
	["growing_floor", "heat_elevator"],
	["growing_floor", "examination_room"],
	["examination_room", "support_unit"],
	["support_unit", "doctor_vehicle_bay"],
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
	ROUTE_COOPERATION: {
		"approach": "cooperation_betrayal",
		"label": "UNDERCROFT COMPACT",
		"steps": ["ossuary_exchange", "undercroft_settlement"],
		"choice_required": true,
		"mastery_route": true,
		"avoids_derby": true,
		"outcomes": {
			"honour": {
				"final_step": "lantern_lift", "exit": "lantern_lift",
				"surface_position": Vector3(-8.0, 0.0, 26.0),
				"surface_relationships": {"gate_lanterns": 14, "undercroft_freehold": 10, "celloutz": -6},
			},
			"betray": {
				"final_step": "stolen_freight_spur", "exit": "stolen_freight_spur",
				"surface_position": Vector3(18.0, 0.0, 20.0),
				"surface_relationships": {"gate_lanterns": -12, "undercroft_freehold": -20, "ashline_wreckers": 8},
			},
		},
	},
	ROUTE_ASSAULT: {
		"approach": "direct_assault",
		"label": "EXECUTIVE BREACH",
		"steps": ["containment_concourse", "executive_transit", "blast_shaft"],
		"exit": "blast_shaft",
		"surface_position": Vector3(30.0, 0.0, -14.0),
		"surface_relationships": {"celloutz": -30, "ashline_wreckers": 5},
		"required_control_points": ["concourse", "transit", "shaft"],
		"mastery_route": true,
		"avoids_derby": true,
	},
	ROUTE_HEAT_ELEVATOR: {
		"approach": "heat_elevator",
		"label": "HEAT ELEVATOR",
		"steps": ["heat_elevator"],
		"exit": "heat_elevator",
		# The sallyport's arrival point: the derby used to surface the player
		# here, and the lift that replaced it as the way up comes out beside it.
		"surface_position": Vector3(4.0, 0.0, -24.0),
		"surface_relationships": {},
		"mastery_route": false,
		"avoids_derby": true,
	},
	ROUTE_DOCTOR: {
		"approach": "pursuit",
		"label": "CHASING THE DOCTOR",
		"steps": ["examination_room", "support_unit", "doctor_vehicle_bay"],
		"exit": "doctor_vehicle_bay",
		# Assistant placement, not Greg's: north-west of the start, clear of
		# the outfall (west), the sallyport (south) and the ridge (east).
		"surface_position": Vector3(-20.0, 0.0, -30.0),
		# Breaking into a CellOutz officer's private bay is noticed.
		"surface_relationships": {"celloutz": -12},
		"mastery_route": false,
		"avoids_derby": true,
	},
	ROUTE_RECAPTURE: {
		"approach": "recapture_into_derby",
		"label": "CONTAINMENT / UNDERGROUND DERBY",
		"steps": ["processing_chute", "underground_colosseum", "lockdown_grid", "vehicle_sallyport"],
		"exit": "vehicle_sallyport",
		"surface_position": Vector3(4.0, 0.0, -24.0),
		"surface_relationships": {"ashline_wreckers": 12, "celloutz": -18},
		"mastery_route": false,
		"avoids_derby": false,
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
			"route_choice": "",
			"assault_control_points": [],
			"derby_exit_earned": false,
			"containment_mechanism": "",
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
	# The derby is an institutional consequence, never a route selected from a
	# menu.  Only `apply_recapture()` can enter it, with a demonstrated cause.
	if definition.is_empty() or route_id == ROUTE_RECAPTURE:
		return false
	var record := ensure()
	if not (record.get("pending_surface_handoff", {}) as Dictionary).is_empty():
		return false
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(SUBJECT, {
		"active_route": route_id,
		# Every chosen route starts from the Growing Floor. Without this a
		# route abandoned halfway left `current_district` deep in another
		# branch, and the next route's first step was refused as unconnected.
		"current_district": "growing_floor",
		"route_steps": [],
		"route_choice": "",
		"assault_control_points": [],
		"derby_exit_earned": false,
		"containment_mechanism": "",
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
	var expected := _expected_steps(definition, str(record.get("route_choice", "")))
	if steps.size() >= expected.size() or str(expected[steps.size()]) != district_id:
		return false
	if route_id == ROUTE_ASSAULT:
		var required: Array = definition.required_control_points
		var control_points: Array = record.get("assault_control_points", [])
		if steps.size() >= control_points.size() or str(required[steps.size()]) != str(control_points[steps.size()]):
			return false
	if route_id == ROUTE_RECAPTURE and district_id == "lockdown_grid" and not bool(record.get("derby_exit_earned", false)):
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
	var choice_ready := not bool(definition.get("choice_required", false)) or not str(record.get("route_choice", "")).is_empty()
	if steps.size() == expected.size() and choice_ready:
		_complete(route_id, definition)
	WorldHistory.commit_ledger_batch()
	return true


static func apply_recapture(mechanism_id: String, demonstrated_in_play: bool) -> bool:
	if not demonstrated_in_play or not CONTAINMENT_MECHANISMS.has(mechanism_id):
		return false
	var record := ensure()
	if not (record.get("pending_surface_handoff", {}) as Dictionary).is_empty():
		# A successful escape is already true. It cannot be revoked to preserve
		# the derby spine; any later pursuit belongs to the surface world.
		return false
	var interrupted_route := str(record.get("active_route", ""))
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(SUBJECT, {
		"active_route": ROUTE_RECAPTURE,
		"current_district": "processing_chute",
		"route_steps": ["processing_chute"],
		"route_choice": "",
		"containment_mechanism": mechanism_id,
		"derby_exit_earned": false,
	})
	PLAYER_ACTION_LEDGER.record("facility_player_recaptured", {
		"subject_id": "player", "route_id": ROUTE_RECAPTURE,
		"interrupted_route": interrupted_route, "mechanism_id": mechanism_id,
		"demonstrated_cause": CONTAINMENT_MECHANISMS[mechanism_id],
		"destination": "res://underground_colosseum.tscn",
	})
	WorldHistory.commit_ledger_batch()
	return true


static func earn_derby_exit(demonstrated_cause: String) -> bool:
	var record := ensure()
	if str(record.get("active_route", "")) != ROUTE_RECAPTURE or demonstrated_cause.is_empty():
		return false
	var steps: Array = record.get("route_steps", [])
	if steps != ["processing_chute", "underground_colosseum"]:
		return false
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(SUBJECT, {"derby_exit_earned": true})
	PLAYER_ACTION_LEDGER.record("facility_derby_exit_earned", {
		"subject_id": "player", "route_id": ROUTE_RECAPTURE,
		"cause": demonstrated_cause,
	})
	WorldHistory.commit_ledger_batch()
	return true


static func record_assault_breakthrough(control_point: String, demonstrated_cause: String) -> bool:
	var definition := route(ROUTE_ASSAULT)
	var required: Array = definition.required_control_points
	var record := ensure()
	if str(record.get("active_route", "")) != ROUTE_ASSAULT or demonstrated_cause.is_empty():
		return false
	var cleared: Array = (record.get("assault_control_points", []) as Array).duplicate()
	if cleared.size() >= required.size() or str(required[cleared.size()]) != control_point:
		return false
	cleared.append(control_point)
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(SUBJECT, {"assault_control_points": cleared})
	PLAYER_ACTION_LEDGER.record("facility_assault_breakthrough", {
		"subject_id": "player", "route_id": ROUTE_ASSAULT,
		"control_point": control_point, "cause": demonstrated_cause,
	})
	WorldHistory.commit_ledger_batch()
	return true


static func choose_cooperation_outcome(outcome: String) -> bool:
	if outcome not in ["honour", "betray"]:
		return false
	var record := ensure()
	if str(record.get("active_route", "")) != ROUTE_COOPERATION:
		return false
	var steps: Array = record.get("route_steps", [])
	if steps != ["ossuary_exchange", "undercroft_settlement"]:
		return false
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(SUBJECT, {"route_choice": outcome})
	PLAYER_ACTION_LEDGER.record("facility_compact_resolved", {
		"subject_id": "player", "route_id": ROUTE_COOPERATION,
		"outcome": outcome,
	})
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


## A place that sends you up with no route handoff of its own (the dry
## falls, reached through the derby tunnels) files one here, so the Hunt
## still lands you where you came out. A route's own handoff always wins.
static func hand_off_at(exit_id: String, at: Vector3) -> bool:
	if not pending_surface_handoff().is_empty():
		return false
	var record := ensure()
	var route_id := str(record.get("active_route", ""))
	if route_id.is_empty():
		route_id = "derby_tunnels"
	WorldHistory.amend_subject(SUBJECT, {
		"active_route": "",
		"pending_surface_handoff": {
			"route_id": route_id,
			"exit_id": exit_id,
			"surface_position": [at.x, at.y, at.z],
			"relationships": {},
			"avoided_derby": false,
		},
	})
	return true


static func _complete(route_id: String, definition: Dictionary) -> void:
	var record := ensure()
	if bool(definition.get("choice_required", false)):
		var choice := str(record.get("route_choice", ""))
		definition = (definition.get("outcomes", {}).get(choice, {}) as Dictionary).merged({
			"avoids_derby": bool(definition.get("avoids_derby", false)),
		})
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


static func _expected_steps(definition: Dictionary, choice: String) -> Array:
	var result: Array = (definition.get("steps", []) as Array).duplicate()
	if bool(definition.get("choice_required", false)):
		var outcome: Dictionary = definition.get("outcomes", {}).get(choice, {})
		if not outcome.is_empty():
			result.append(str(outcome.final_step))
	return result


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
