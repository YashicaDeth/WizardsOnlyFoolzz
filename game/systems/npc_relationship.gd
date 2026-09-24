class_name NPCRelationship
extends RefCounted

## AI NPC Communication & Relationship System, section 3.
##
## "Do not reduce the relationship to one number internally. Expose a simple
## bar if desired, but retain multiple dimensions so affection, fear and trust
## can diverge."
##
## `WorldHistory.relationship_strength()` is that one number, and half the
## game already reads it. So this does not replace it: the seven dimensions are
## the record, and the legacy strength is derived from them on every write, the
## same way `FaceModel.scalar()` keeps the rig's old integer in step with the
## seven face axes rather than fighting it.
##
## Everything here is deterministic and lives in Godot. The spec's architecture
## rule is the whole point: "The language model performs conversation and
## interpretation. Godot owns truth." A model may classify what happened; it
## never assigns a number. `apply_event()` is the only way a relationship moves
## and it is a lookup table, not a judgement.

## Bounded -100..100, except the two that cannot be negative: you cannot know
## someone less than not at all, and a debt is owed or it is settled.
const DIMENSIONS := {
	"familiarity": {"min": 0.0, "max": 100.0, "label": "FAMILIARITY"},
	"trust": {"min": -100.0, "max": 100.0, "label": "TRUST"},
	"affinity": {"min": -100.0, "max": 100.0, "label": "AFFINITY"},
	"fear": {"min": 0.0, "max": 100.0, "label": "FEAR"},
	"respect": {"min": -100.0, "max": 100.0, "label": "RESPECT"},
	"resentment": {"min": 0.0, "max": 100.0, "label": "RESENTMENT"},
	"debt": {"min": -100.0, "max": 100.0, "label": "DEBT"},
}

## Section 3: "Meaningful events produce deterministic deltas in Godot." The
## model's job is to say which of these happened, never how much it was worth.
## An event this table does not know is refused rather than guessed at, which
## is what stops a model inventing `player_is_wonderful: +90`.
const EVENT_DELTAS := {
	"greeted": {"familiarity": 3.0},
	"conversed": {"familiarity": 2.0},
	"kept_promise": {"familiarity": 2.0, "trust": 14.0, "respect": 8.0},
	"broke_promise": {"familiarity": 2.0, "trust": -22.0, "resentment": 12.0},
	"lied_and_caught": {"trust": -18.0, "respect": -6.0, "resentment": 8.0},
	"told_hard_truth": {"trust": 10.0, "respect": 9.0, "affinity": -3.0},
	"helped": {"familiarity": 3.0, "affinity": 12.0, "trust": 6.0, "debt": 10.0},
	"helped_loved_one": {"familiarity": 3.0, "affinity": 20.0, "debt": 18.0, "trust": 8.0},
	"gave_gift": {"familiarity": 2.0, "affinity": 8.0, "debt": 5.0},
	"insulted": {"familiarity": 2.0, "affinity": -12.0, "resentment": 10.0, "respect": -4.0},
	"threatened_with_weapon": {"familiarity": 2.0, "fear": 26.0, "resentment": 20.0, "trust": -15.0, "affinity": -10.0},
	"robbed": {"fear": 18.0, "resentment": 30.0, "trust": -30.0, "affinity": -20.0},
	"attacked": {"fear": 34.0, "resentment": 38.0, "trust": -40.0, "affinity": -30.0},
	"spared": {"fear": 6.0, "respect": 14.0, "debt": 22.0, "resentment": -8.0},
	"betrayed": {"trust": -45.0, "resentment": 40.0, "affinity": -25.0},
	"witnessed_crime": {"fear": 10.0, "trust": -12.0, "resentment": 6.0},
	"paid_debt": {"debt": -25.0, "trust": 8.0, "respect": 5.0},
	"stood_up_for": {"affinity": 15.0, "respect": 12.0, "debt": 8.0},
	"abandoned_in_danger": {"trust": -28.0, "resentment": 24.0, "affinity": -18.0},
}

## A relationship is between a person and a person, so it is stored on the NPC
## rather than in a global table: an NPC who is never met has no record, and an
## NPC who is deleted takes their opinion with them.
const RELATION_KEY := "npc_relations"

const COMPANION_TRUST := 55.0
const COMPANION_AFFINITY := 50.0


static func blank() -> Dictionary:
	var record := {}
	for dimension in DIMENSIONS:
		record[dimension] = 0.0
	record["companion_unlocked"] = false
	record["met"] = false
	return record


## What this NPC currently feels about one other subject. Always a complete
## record, so no caller has to know which dimensions exist or handle a partial.
static func state(npc_id: String, about_id: String = "player") -> Dictionary:
	var npc: Dictionary = WorldHistory.subject(npc_id)
	var relations: Dictionary = npc.get(RELATION_KEY, {})
	var stored: Dictionary = relations.get(about_id, {})
	var record := blank()
	for dimension in DIMENSIONS:
		if stored.has(dimension):
			record[dimension] = _clamp_dimension(dimension, float(stored[dimension]))
	record["companion_unlocked"] = bool(stored.get("companion_unlocked", false))
	record["met"] = bool(stored.get("met", false))
	return record


## The only way a relationship moves.
##
## Returns what actually changed, including the refusal, so the caller can show
## it in a debug HUD and so `GAME_RESULT` can tell the dialogue layer the truth
## about whether anything happened.
static func apply_event(npc_id: String, event_kind: String, about_id: String = "player") -> Dictionary:
	if not EVENT_DELTAS.has(event_kind):
		# Refused, not approximated. An unknown event kind is almost always a
		# model inventing one, and the failure has to be visible rather than
		# silently scoring zero.
		return {"ok": false, "reason": "unknown_event", "event": event_kind, "changed": {}}

	var before := state(npc_id, about_id)
	var after := before.duplicate(true)
	var deltas: Dictionary = EVENT_DELTAS[event_kind]
	var changed := {}
	for dimension in deltas:
		if not DIMENSIONS.has(dimension):
			continue
		var was := float(before[dimension])
		var now := _clamp_dimension(dimension, was + float(deltas[dimension]))
		if not is_equal_approx(was, now):
			after[dimension] = now
			changed[dimension] = {"from": was, "to": now}

	after["met"] = true
	# Section 3: "Acquaintance -> trusted contact -> friend -> companion, where
	# narrative conditions permit." Godot decides this, on the numbers, once --
	# it never un-unlocks, because a companion who leaves is a story beat and
	# not a threshold being crossed back over.
	if not bool(after["companion_unlocked"]):
		after["companion_unlocked"] = float(after["trust"]) >= COMPANION_TRUST and float(after["affinity"]) >= COMPANION_AFFINITY

	_write(npc_id, about_id, after)
	WorldHistory.record_event("npc_relationship_changed", {
		"npc": npc_id, "about": about_id, "event": event_kind, "changed": changed,
	})
	return {"ok": true, "event": event_kind, "changed": changed, "state": after}


## Section 3 again: faction reputation and individual relationship are separate,
## "A person may like the player while distrusting the player's faction." So
## this reports the individual only, and any caller wanting the other half asks
## `WorldHistory.faction_disposition()` for it and weighs the two itself.
static func disposition(npc_id: String, about_id: String = "player") -> String:
	var record := state(npc_id, about_id)
	if not bool(record["met"]):
		return "stranger"
	var fear := float(record["fear"])
	var resentment := float(record["resentment"])
	var trust := float(record["trust"])
	var affinity := float(record["affinity"])
	# Fear first, and deliberately: section 3 notes that "high fear can produce
	# temporary compliance without friendship", so a terrified NPC reads as
	# cowed no matter how much they used to like the player.
	if fear >= 60.0:
		return "cowed"
	if resentment >= 55.0:
		return "hostile"
	if bool(record["companion_unlocked"]):
		return "companion"
	if trust >= 30.0 and affinity >= 25.0:
		return "friendly"
	if trust <= -25.0:
		return "wary"
	return "acquainted"


## The line that goes in the prompt. Short on purpose -- section 2 warns against
## dumping unlimited state at the model, and a dimension sitting at zero is not
## information, it is noise.
static func summary(npc_id: String, about_id: String = "player") -> String:
	var record := state(npc_id, about_id)
	if not bool(record["met"]):
		return "You have never met this person."
	var parts: Array[String] = []
	for dimension in DIMENSIONS:
		var value := float(record[dimension])
		if absf(value) < 8.0:
			continue
		parts.append("%s %s" % [str((DIMENSIONS[dimension] as Dictionary).label).to_lower(), _band(value)])
	var line := "You regard them as %s" % disposition(npc_id, about_id)
	if not parts.is_empty():
		line += " (" + ", ".join(parts) + ")"
	return line + "."


## The legacy single number, derived rather than stored. Trust and affinity pull
## it up, resentment and fear pull it down, and fear counts for less than
## resentment because being frightened of someone is not the same as disliking
## them.
static func derived_strength(record: Dictionary) -> int:
	var value := float(record.get("trust", 0.0)) * 0.35
	value += float(record.get("affinity", 0.0)) * 0.35
	value += float(record.get("respect", 0.0)) * 0.15
	value -= float(record.get("resentment", 0.0)) * 0.30
	value -= float(record.get("fear", 0.0)) * 0.10
	return int(roundf(clampf(value, -100.0, 100.0)))


static func _band(value: float) -> String:
	var magnitude := absf(value)
	var word := "slight"
	if magnitude >= 70.0:
		word = "profound"
	elif magnitude >= 45.0:
		word = "strong"
	elif magnitude >= 20.0:
		word = "moderate"
	return word if value > 0.0 else "negative-" + word


static func _clamp_dimension(dimension: String, value: float) -> float:
	var spec: Dictionary = DIMENSIONS.get(dimension, {"min": -100.0, "max": 100.0})
	return clampf(value, float(spec.min), float(spec.max))


static func _write(npc_id: String, about_id: String, record: Dictionary) -> void:
	var npc: Dictionary = WorldHistory.subject(npc_id)
	var relations: Dictionary = (npc.get(RELATION_KEY, {}) as Dictionary).duplicate(true)
	relations[about_id] = record.duplicate(true)
	# Both records, written together. `relations` is what the rest of the game
	# already reads through `WorldHistory.relationship_strength()`, and letting
	# the two drift apart would mean a shopkeeper pricing off one opinion while
	# talking from another.
	var legacy: Dictionary = (npc.get("relations", {}) as Dictionary).duplicate(true)
	var legacy_entry: Dictionary = (legacy.get(about_id, {}) as Dictionary).duplicate(true)
	legacy_entry["strength"] = derived_strength(record)
	legacy[about_id] = legacy_entry
	WorldHistory.amend_subject(npc_id, {RELATION_KEY: relations, "relations": legacy})
