class_name FacilityTerritory
extends RefCounted

## One persistent account of the opening facility.  Scenes report authored
## milestones here; the MAP, INDEX and CellOutz reaction all read the same
## record back.  No UI owns liberation state and no second quest ledger has to
## be kept in step with WorldHistory.

const SUBJECT := "facility_territory"
const REACTION_SUBJECT := "celloutz_facility_reaction"

const CONTROLLED := "controlled"
const SURVEYED := "surveyed"
const LIBERATED := "liberated"

const SECTORS := [
	{
		"id": "growing_floor", "name": "THE GROWING FLOOR",
		"at": Vector2(0.18, 0.22), "owner": "celloutz",
		"objective": "GET OUT OF THE VAT AISLE",
		"record": "facility:growing_floor",
	},
	{
		"id": "pit", "name": "THE UNDERGROUND COLOSSEUM",
		"at": Vector2(0.48, 0.48), "owner": "celloutz",
		"objective": "SINK THE HEAT AND LEAVE THE CAR",
		"record": "facility:underground_colosseum",
	},
	{
		"id": "service_ring", "name": "THE SERVICE RING",
		"at": Vector2(0.76, 0.48), "owner": "celloutz",
		"objective": "FIND A ROUTE THROUGH THE THREE TUNNELS",
		"record": "facility:service_ring",
	},
	{
		"id": "surface_gate", "name": "THE SURFACE GATE",
		"at": Vector2(0.76, 0.78), "owner": "celloutz",
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
	var current := WorldHistory.subject(SUBJECT)
	if current.is_empty():
		return WorldHistory.register_subject(SUBJECT, {
			"kind": "territory",
			"name": "CELLOUTZ SUBLEVEL 0C",
			"sectors": _blank_sectors(),
			"active_sector": "growing_floor",
			"liberated_count": 0,
			"surveillance": 1.0,
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


static func apply_event(event_type: String) -> Dictionary:
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
		"ringmaster_joined", "ringmaster_escaped", "ringmaster_challenged":
			_set_sector("surface_gate", SURVEYED, true)
			_unlock_record("service_ring")
			_unlock_record("surface_gate")
	return overview()


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
