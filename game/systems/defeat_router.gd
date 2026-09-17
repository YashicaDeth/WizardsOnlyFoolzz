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
	# A commissioned local-law actor already carries the canonical holding that
	# issued their warrant. Unknown factions used to fall back to the scene id,
	# so a Gate Lantern arrest claimed the player was "held at bone_yard" and
	# forgot which jurisdiction had actually taken them. Named faction prisons
	# still win; the issuing holding is the honest fallback for local custody.
	var local_custody := str(captor.get("contract_place", ""))
	var destination := _destination(faction_id, local_custody if not local_custody.is_empty() else location)
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


static func redecant() -> Dictionary:
	var player := WorldHistory.subject("player")
	if str(player.get("status", "")) not in ["shackled", "stamped", "conscripted"]:
		return {}
	var inventory := WorldHistory.subject("inventory")
	var forfeited: Array = (inventory.get("items", []) as Array).duplicate(true)
	var old_body: Dictionary = (player.get("anatomy_state", {}) as Dictionary).duplicate(true)
	WorldHistory.amend_subject("inventory", {"items": []})
	var result := {
		"status": "redecanted",
		"captor_id": "",
		"captor_faction": "",
		"held_at": "",
		"previous_body": old_body,
		"anatomy_state": {},
		"redecants": int(player.get("redecants", 0)) + 1,
		"memory": "Died deliberately in captivity and came back out of the tar empty-handed.",
	}
	WorldHistory.amend_subject("player", result)
	WorldHistory.record_event("player_deliberate_death", {"subject_id": "player", "forfeited": forfeited, "held_at": player.get("held_at", "")})
	WorldHistory.record_event("player_redecanted", {"subject_id": "player", "body_number": result.redecants + 1, "retained_identity": true})
	result["forfeited"] = forfeited
	return result


static func _destination(faction_id: String, fallback: String) -> String:
	match faction_id:
		"ashline_wreckers": return "ashline_shackle_pit"
		"choir_of_marrow": return "ossuary_intake"
		"celloutz": return "celloutz_labor_chapel"
	return fallback
