class_name AscentEntities
extends RefCounted

## E5. "Ascent entities are not a shop. They are the lower ranks of the thing
## the player is trying to reach, and they run on the same nemesis machinery as
## any rival. Getting their attention is the mechanic." — DESIGN/COSMOLOGY.md
##
## `RivalRegistry` (Codex's file) proves a rival from recorded *harm*: contact,
## survival, an adaptation read off the wound. That specific mechanism does not
## transplant here — nobody wounds an entity into existing. What mirrors is the
## shape: a subject nobody authored a scripted appearance for, whose notice is
## a conclusion drawn from the log rather than a menu you open, and who then
## remembers you and is met again. `regard()` below is that shape, run over the
## acts that already carry positive `KARMA` weight instead of harm events.
##
## E5.2, "wash away sins for positive quests": there is no quest system yet
## (E2/E3/E6 are unbuilt), so the quest this stands in for is the same one
## RivalRegistry already runs on the other axis — a real pattern of recorded
## acts, not a purchase. `wash()` only pays out after `regard()` has actually
## granted attention, and spends that attention on the way out, so the next
## wash has to be earned again rather than bought twice with the same acts.
## E5.3 (route endings) is deliberately not attempted here — it needs the E7
## ending content this system does not have anywhere to hand off to yet.

const MERCY_EVENTS := ["misfire_bond", "bond_strengthened", "npc_spared"]
const MERCY_OUTCOMES := ["spare", "recruit"]
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## The lower ranks, per COSMOLOGY.md — not gods, the rank below them. Each
## entity's `faction_id` is `wizardsonlyfoolz` so pricing and the Tree axis
## already treat them as part of that order without a second lookup table.
const ENTITIES := {
	"clear_frequency": {
		"name": "The Clear Frequency", "role": "Lowest ascending rank — a signal, not yet a voice",
		"threshold": 3, "memory": "Answers nothing until it has heard enough of you to bother.",
	},
	"still_ledger": {
		"name": "The Still Ledger", "role": "Keeps the account of what mercy has cost you",
		"threshold": 5, "memory": "Counts what you spared more carefully than what you took.",
	},
}


static func seed_entities() -> void:
	WorldHistory.begin_ledger_batch()
	for entity_id in ENTITIES:
		var data: Dictionary = ENTITIES[entity_id]
		WorldHistory.register_subject(entity_id, {
			"name": str(data.name), "kind": "entity", "role": str(data.role),
			"faction": "wizardsonlyfoolz", "faction_id": "wizardsonlyfoolz",
			"threat": "NONE", "status": "waiting", "memory": str(data.memory),
			"has_noticed": false, "washed_at_sequence": -1, "wash_count": 0,
			"relations": {},
		})
	WorldHistory.commit_ledger_batch()


## Draws the same conclusion `RivalRegistry.consider()` draws on the other
## axis — attention is earned by a real pattern, not granted for one act — but
## reads mercy instead of harm, and only over events since the last wash, so a
## spent run of mercy cannot pay twice.
static func regard(entity_id: String, subject_id: String = "player") -> Dictionary:
	var entity := WorldHistory.subject(entity_id)
	if entity.is_empty() or str(entity.get("kind", "")) != "entity":
		return {}
	if bool(entity.get("has_noticed", false)):
		return entity
	var since := int(entity.get("washed_at_sequence", -1))
	var count := 0
	var counted_acts: Dictionary = {}
	for event in WorldHistory.events:
		if int(event.get("sequence", 0)) <= since:
			continue
		if WorldHistory.event_actor(event) != subject_id:
			continue
		var event_type := str(event.get("type", ""))
		var details: Dictionary = event.get("details", {}) as Dictionary
		var outcome := str(details.get("outcome", ""))
		if MERCY_EVENTS.has(event_type) or (event_type == "npc_resolution" and MERCY_OUTCOMES.has(outcome)):
			# Production sparing writes a subject state change (`npc_spared`) and
			# its canonical witnessed act (`npc_resolution`). Those are two rows
			# describing one person spared, not two mercies. Prefer the exact
			# subject as the act key; events without one remain distinct acts.
			var mercy_subject_id := str(details.get("subject_id", ""))
			var act_key := "subject:%s" % mercy_subject_id if not mercy_subject_id.is_empty() else "event:%d" % int(event.get("sequence", 0))
			if not counted_acts.has(act_key):
				counted_acts[act_key] = true
				count += 1
	var threshold := int((ENTITIES.get(entity_id, {}) as Dictionary).get("threshold", 4))
	if count < threshold:
		return entity
	WorldHistory.begin_ledger_batch()
	var updated := WorldHistory.amend_subject(entity_id, {"has_noticed": true})
	WorldHistory.record_event("entity_took_notice", {"entity_id": entity_id, "subject_id": subject_id, "mercy_count": count})
	WorldHistory.commit_ledger_batch()
	return updated


## E5.2. Refused outright if the entity has not noticed you — "they will not
## take you seriously" is the design's own line about this order, applied
## mechanically. Spends the notice on success, so getting it again costs a
## fresh run of the acts above rather than the same ones twice.
static func wash(entity_id: String, subject_id: String = "player") -> Dictionary:
	var entity := WorldHistory.subject(entity_id)
	if entity.is_empty() or str(entity.get("kind", "")) != "entity":
		return {"ok": false, "reason": "NO SUCH ENTITY"}
	if not bool(entity.get("has_noticed", false)):
		return {"ok": false, "reason": "IT HAS NOT NOTICED YOU YET"}
	WorldHistory.begin_ledger_batch()
	var details := {"entity_id": entity_id, "subject_id": subject_id, "actor": subject_id}
	if subject_id == "player":
		PLAYER_ACTION_LEDGER.record("sin_washed", details)
	else:
		WorldHistory.record_event("sin_washed", details)
	WorldHistory.amend_subject(entity_id, {
		"has_noticed": false,
		"washed_at_sequence": WorldHistory.next_sequence - 1,
		"wash_count": int(entity.get("wash_count", 0)) + 1,
	})
	WorldHistory.commit_ledger_batch()
	return {"ok": true, "karma_after": float(WorldHistory.subject(subject_id).get("karma", 0.0))}


## E6.3. "Substances are the access verb for the entity layer... reached by
## taking something, not by finding an altar." A glimpse is not `regard()` —
## it costs nothing of the entity's attention and cannot be spent on `wash()`.
## It is a real recorded contact for whatever reads history later (a ritual,
## a line of dialogue), earned by the body cost `systems/substances.gd`
## already charged to get here rather than by anything this function checks.
static func glimpse(entity_id: String, subject_id: String = "player") -> Dictionary:
	var entity := WorldHistory.subject(entity_id)
	if entity.is_empty() or str(entity.get("kind", "")) != "entity":
		return {}
	WorldHistory.record_event("entity_glimpsed", {"entity_id": entity_id, "subject_id": subject_id})
	return entity
