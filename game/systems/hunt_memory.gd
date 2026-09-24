class_name HuntMemory
extends RefCounted

## F10.15. The world that produced a hunter is allowed to end; the fact that
## this person hunted the player belongs to the player. QuantumSaves already
## carries that one subject across, so this compact record lives there rather
## than smuggling the old hunter or faction into a new universe.

const LIMIT := 12


static func remember(hunter_id: String, reason: String, contract_id: String = "") -> Dictionary:
	if hunter_id.is_empty() or WorldHistory.subject("player").is_empty():
		return {}
	var hunter := WorldHistory.subject(hunter_id)
	if hunter.is_empty():
		return {}
	var source_run := WorldHistory.run_salt
	var history: Array = (WorldHistory.subject("player").get("hunted_by", []) as Array).duplicate(true)
	for entry_variant: Variant in history:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		if str(entry.get("hunter_id", "")) == hunter_id and int(entry.get("source_run", 0)) == source_run and str(entry.get("reason", "")) == reason and str(entry.get("contract_id", "")) == contract_id:
			return entry.duplicate(true)
	var memory := {
		"hunter_id": hunter_id,
		"name": str(hunter.get("name", hunter_id)),
		"faction_id": str(hunter.get("faction_id", "")),
		"reason": reason,
		"contract_id": contract_id,
		"source_run": source_run,
		"sequence": WorldHistory.next_sequence,
	}
	history.append(memory)
	while history.size() > LIMIT:
		history.pop_front()
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject("player", {
		"hunted_by": history,
		"last_hunter": memory.duplicate(true),
	})
	WorldHistory.record_event("player_hunted_by", {
		"subject_id": "player", "hunter_id": hunter_id,
		"faction_id": memory.faction_id, "reason": reason,
		"contract_id": contract_id, "source_run": source_run,
	})
	WorldHistory.commit_ledger_batch()
	return memory.duplicate(true)


static func known_by(subject_id: String = "player") -> Array:
	return (WorldHistory.subject(subject_id).get("hunted_by", []) as Array).duplicate(true)
