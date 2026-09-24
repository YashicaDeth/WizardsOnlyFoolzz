class_name PlayerActionLedger
extends RefCounted

## One inexpensive receipt path for concrete player acts. Existing event names
## remain intact because the Index, factions and tests already read them; this
## adds a stable action id and a compact per-kind summary without inventing a
## parallel history. Subject amendment + event append are persisted once.

const SUBJECT := "player_action_ledger"
const VERSION := 1


static func record(event_type: String, details: Dictionary = {}) -> Dictionary:
	if event_type.is_empty():
		return {}
	WorldHistory.begin_ledger_batch()
	var ledger := WorldHistory.subject(SUBJECT)
	if ledger.is_empty():
		ledger = WorldHistory.register_subject(SUBJECT, {
			"kind": "action_ledger",
			"version": VERSION,
			"next_action": 1,
			"counts": {},
			"last": {},
		})
	var sequence := maxi(1, int(ledger.get("next_action", 1)))
	var action_id := "action_%06d" % sequence
	var payload := details.duplicate(true)
	payload["action_id"] = action_id
	payload["action_sequence"] = sequence
	if not payload.has("subject_id"):
		payload["subject_id"] = "player"
	var counts: Dictionary = (ledger.get("counts", {}) as Dictionary).duplicate(true)
	counts[event_type] = int(counts.get(event_type, 0)) + 1
	WorldHistory.amend_subject(SUBJECT, {
		"version": VERSION,
		"next_action": sequence + 1,
		"counts": counts,
		"last": {
			"id": action_id,
			"type": event_type,
			"subject_id": str(payload.subject_id),
			"location": str(payload.get("location", "")),
		},
	})
	var event := WorldHistory.record_event(event_type, payload)
	WorldHistory.commit_ledger_batch()
	return event


static func count(event_type: String) -> int:
	return int((WorldHistory.subject(SUBJECT).get("counts", {}) as Dictionary).get(event_type, 0))
