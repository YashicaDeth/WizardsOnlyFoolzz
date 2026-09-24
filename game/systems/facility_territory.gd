class_name FacilityTerritory
extends RefCounted

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## One persistent account of the opening facility.  Scenes report authored
## milestones here; the MAP, INDEX and CellOutz reaction all read the same
## record back.  No UI owns liberation state and no second quest ledger has to
## be kept in step with WorldHistory.

const SUBJECT := "facility_territory"
const REACTION_SUBJECT := "celloutz_facility_reaction"

const CONTROLLED := "controlled"
const SURVEYED := "surveyed"
const LIBERATED := "liberated"

## CellOutz sells a search area, not omniscience. Snapping to this grid keeps
## the target somewhere inside the published radius even at a cell corner and
## means carrying the Black Mirror across a meaningful distance is what emits
## a new ping—not standing still with the page open.
const TARGET_PING_CELL := 96.0
const TARGET_PING_RADIUS := 72.0

const SECTORS := [
	{
		"id": "growing_floor", "name": "THE GROWING FLOOR",
		"at": Vector2(0.18, 0.34), "owner": "celloutz",
		"objective": "GET OUT OF THE VAT AISLE",
		"record": "facility:growing_floor",
	},
	{
		"id": "pit", "name": "THE UNDERGROUND COLOSSEUM",
		"at": Vector2(0.48, 0.52), "owner": "celloutz",
		"objective": "SINK THE HEAT AND LEAVE THE CAR",
		"record": "facility:underground_colosseum",
	},
	{
		# Stable id kept for save compatibility; the player-facing name says what
		# the machinery does instead of asking them to understand floor-plan lore.
		"id": "service_ring", "name": "THE LOCKDOWN GRID",
		"at": Vector2(0.76, 0.52), "owner": "celloutz",
		"objective": "DESTROY THREE RED RELAYS TO UNSEAL THE EXIT",
		"record": "facility:service_ring",
	},
	{
		"id": "surface_gate", "name": "THE SURFACE GATE",
		"at": Vector2(0.76, 0.80), "owner": "celloutz",
		"objective": "CHOOSE HOW YOU LEAVE",
		"record": "facility:surface_gate",
	},
]

const ROUTES := [
	["growing_floor", "pit"],
	["pit", "service_ring"],
	["service_ring", "surface_gate"],
]


static func _blank_sectors() -> Dictionary:
	var result := {}
	for definition: Dictionary in SECTORS:
		result[str(definition.id)] = {
			"state": CONTROLLED,
			"revealed": false,
			"owner": str(definition.owner),
		}
	return result


static func ensure() -> Dictionary:
	WorldHistory.begin_ledger_batch()
	var current := WorldHistory.subject(SUBJECT)
	if current.is_empty():
		current = WorldHistory.register_subject(SUBJECT, {
			"kind": "territory",
			"name": "CELLOUTZ SUBLEVEL 0C",
			"sectors": _blank_sectors(),
			"active_sector": "growing_floor",
			"liberated_count": 0,
			"surveillance": 1.0,
			"relay_disabled": [],
		})
	var sectors: Dictionary = (current.get("sectors", {}) as Dictionary).duplicate(true)
	var changed := false
	for definition: Dictionary in SECTORS:
		var id := str(definition.id)
		if not sectors.has(id):
			sectors[id] = _blank_sectors()[id]
			changed = true
	if changed:
		current = WorldHistory.amend_subject(SUBJECT, {"sectors": sectors})
	if not current.has("relay_disabled"):
		current = WorldHistory.amend_subject(SUBJECT, {"relay_disabled": []})
	WorldHistory.commit_ledger_batch()
	return current


static func sector(id: String) -> Dictionary:
	var record := ensure()
	return ((record.get("sectors", {}) as Dictionary).get(id, {}) as Dictionary).duplicate(true)


static func sector_def(id: String) -> Dictionary:
	for definition: Dictionary in SECTORS:
		if str(definition.id) == id:
			return definition.duplicate(true)
	return {}


static func overview() -> Dictionary:
	var record := ensure()
	var rows: Array[Dictionary] = []
	for definition: Dictionary in SECTORS:
		var row := definition.duplicate(true)
		row.merge(sector(str(definition.id)), true)
		rows.append(row)
	return {
		"name": str(record.get("name", "CELLOUTZ SUBLEVEL 0C")),
		"active_sector": str(record.get("active_sector", "growing_floor")),
		"liberated_count": int(record.get("liberated_count", 0)),
		"surveillance": float(record.get("surveillance", 1.0)),
		"sectors": rows,
		"routes": ROUTES.duplicate(true),
	}


static func apply_event(event_type: String, details: Dictionary = {}) -> Dictionary:
	# One canonical route event may change several sector, Index and retaliation
	# records. Persist the consequence as one boundary.
	WorldHistory.begin_ledger_batch()
	ensure()
	match event_type:
		"opening_woke":
			_set_sector("growing_floor", SURVEYED, true)
		"opening_entered_pit":
			_set_sector("growing_floor", SURVEYED, true)
			_set_sector("pit", SURVEYED, true)
			_set_sector("service_ring", CONTROLLED, true)
		"derby_round_won":
			_set_sector("pit", LIBERATED, true)
			_set_sector("service_ring", SURVEYED, true)
			_unlock_record("pit")
			_raise_reaction()
		"service_ring_relay_disabled":
			_record_relay(clampi(int(details.get("index", -1)), -1, 2))
		# Out by the heat elevator or the old drains (Greg, 24 September): the
		# same reach of the surface the derby's exit used to grant.
		"ringmaster_joined", "ringmaster_escaped", "ringmaster_challenged", "facility_surfaced":
			_set_sector("surface_gate", SURVEYED, true)
			_unlock_record("surface_gate")
	var result := overview()
	WorldHistory.commit_ledger_batch()
	return result


## The Black Mirror is the agency's instrument as much as the player's. Once a
## repossession order exists, consulting it publishes the carrier's coarse area
## to that same order. The result is JSON-safe persistent data for MAP, jobs and
## later hunter routing to share.
static func publish_target_ping(world_position: Vector2, source := "black_mirror") -> Dictionary:
	var reaction := WorldHistory.subject(REACTION_SUBJECT)
	if reaction.is_empty():
		return {}
	var centre := Vector2(
		roundf(world_position.x / TARGET_PING_CELL) * TARGET_PING_CELL,
		roundf(world_position.y / TARGET_PING_CELL) * TARGET_PING_CELL)
	var previous: Dictionary = reaction.get("target_area", {})
	if is_equal_approx(float(previous.get("x", INF)), centre.x) and is_equal_approx(float(previous.get("z", INF)), centre.y):
		return previous.duplicate(true)
	var area := {
		"x": centre.x,
		"z": centre.y,
		"radius": TARGET_PING_RADIUS,
		"source": source,
		"sequence": int(previous.get("sequence", 0)) + 1,
	}
	# Opening the corporate satellite is one player act even though it mutates
	# the bounty and publishes a history event. Route both through one receipt
	# and one persistence transaction; an unchanged cell returns above for free.
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(REACTION_SUBJECT, {"target_area": area})
	PLAYER_ACTION_LEDGER.record("celloutz_target_area_published", {
		"subject_id": REACTION_SUBJECT,
		"target_id": "player",
		"area": area.duplicate(true),
	})
	WorldHistory.commit_ledger_batch()
	return area


static func target_area() -> Dictionary:
	return (WorldHistory.subject(REACTION_SUBJECT).get("target_area", {}) as Dictionary).duplicate(true)


static func _set_sector(id: String, state: String, revealed: bool) -> void:
	var record := ensure()
	var sectors: Dictionary = (record.get("sectors", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (sectors.get(id, {}) as Dictionary).duplicate(true)
	var order := [CONTROLLED, SURVEYED, LIBERATED]
	var before := order.find(str(entry.get("state", CONTROLLED)))
	var after := order.find(state)
	if after >= before:
		entry["state"] = state
	entry["revealed"] = bool(entry.get("revealed", false)) or revealed
	sectors[id] = entry
	var count := 0
	for sector_id in sectors:
		if str((sectors[sector_id] as Dictionary).get("state", "")) == LIBERATED:
			count += 1
	WorldHistory.amend_subject(SUBJECT, {
		"sectors": sectors,
		"active_sector": id,
		"liberated_count": count,
	})


static func _unlock_record(id: String) -> void:
	var definition := sector_def(id)
	if definition.is_empty():
		return
	var territory := sector(id)
	WorldHistory.register_subject(str(definition.record), {
		"kind": "facility_sector",
		"name": str(definition.name),
		"role": "CELLOUTZ TERRITORY FILE",
		"faction": "CellOutz",
		"faction_id": "celloutz",
		"territory_id": id,
		"status": str(territory.get("state", CONTROLLED)),
		"objective": str(definition.objective),
		"memory": "Recovered from the Black Mirror after the pit changed hands.",
	})


static func _record_relay(index: int) -> void:
	if index < 0:
		return
	var record := ensure()
	var disabled: Array = (record.get("relay_disabled", []) as Array).duplicate()
	if disabled.has(index):
		return
	disabled.append(index)
	disabled.sort()
	WorldHistory.amend_subject(SUBJECT, {"relay_disabled": disabled})
	WorldHistory.record_event("service_ring_relay_disabled", {
		"territory": SUBJECT,
		"sector": "service_ring",
		"relay": index,
		"remaining": 3 - disabled.size(),
	})
	if disabled.size() < 3:
		return
	_set_sector("service_ring", LIBERATED, true)
	_unlock_record("service_ring")
	_escalate_reaction()


static func _escalate_reaction() -> void:
	_raise_reaction()
	var reaction := WorldHistory.subject(REACTION_SUBJECT)
	if bool(reaction.get("service_ring_escalated", false)):
		return
	WorldHistory.update_subject(REACTION_SUBJECT, {
		"status": "priority",
		"service_ring_escalated": true,
		"threat": "LOCKDOWN GRID LOST; RECOVER ASSET INTACT ENOUGH TO INTERROGATE",
	}, "celloutz_repossession_escalated")
	WorldHistory.record_event("celloutz_service_ring_retaliation", {
		"subject_id": REACTION_SUBJECT,
		"target_id": "player",
		"territory": SUBJECT,
	})


static func _raise_reaction() -> void:
	var current := WorldHistory.subject(REACTION_SUBJECT)
	if not current.is_empty():
		return
	WorldHistory.register_subject(REACTION_SUBJECT, {
		"kind": "job",
		"name": "REPOSSESSION ORDER 0C-7",
		"role": "OPEN CORPORATE BOUNTY",
		"faction": "CellOutz",
		"faction_id": "celloutz",
		"status": "circulating",
		"target_id": "player",
		"threat": "RECOVER COMPANY MEAT; ASSET MAY BE DISASSEMBLED",
		"memory": "CellOutz lists the escaped body as inventory and pays any account that returns it.",
	})
	WorldHistory.record_event("celloutz_repossession_order_posted", {
		"subject_id": REACTION_SUBJECT,
		"target_id": "player",
		"territory": SUBJECT,
	})
