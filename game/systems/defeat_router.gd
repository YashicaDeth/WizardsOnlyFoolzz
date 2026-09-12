class_name DefeatRouter
extends RefCounted

## F5. Defeat changes ownership and position in the world; it is not a reload.

const OUTCOMES := {
	"ashline_wreckers": "shackled",
	"choir_of_marrow": "stamped",
	"celloutz": "conscripted",
}


static func route(captor_id: String, location: String) -> Dictionary:
	var captor := WorldHistory.subject(captor_id)
	var faction_id := str(captor.get("faction_id", ""))
	var outcome := str(OUTCOMES.get(faction_id, "shackled"))
	var destination := _destination(faction_id, location)
	var player := WorldHistory.subject("player")
	var defeats := int(player.get("defeats", 0)) + 1
	var state := {
		"outcome": outcome,
		"destination": destination,
		"status": outcome,
		"captor_id": captor_id,
		"captor_faction": faction_id,
		"held_at": destination,
		"defeats": defeats,
		"memory": "Defeated by %s and taken to %s." % [str(captor.get("name", captor_id)), destination],
	}
	WorldHistory.amend_subject("player", state)
	WorldHistory.record_event("player_defeated", {"actor": captor_id, "subject_id": "player", "outcome": outcome, "destination": destination, "location": location})
	WorldHistory.record_event("player_captured", {"captor": captor_id, "faction_id": faction_id, "outcome": outcome, "destination": destination})
	return state


static func _destination(faction_id: String, fallback: String) -> String:
	match faction_id:
		"ashline_wreckers": return "ashline_shackle_pit"
		"choir_of_marrow": return "ossuary_intake"
		"celloutz": return "celloutz_labor_chapel"
	return fallback
