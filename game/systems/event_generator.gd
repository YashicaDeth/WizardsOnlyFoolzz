class_name OverworldEventGenerator
extends RefCounted

## Combines `OverworldEventParts` (who, what they want, where, what they do,
## how it escalates) into every coherent overworld random event, and picks one
## deterministically from a seed. DESIGN/OVERWORLD_EVENTS.md: "Hundreds of
## GTA / RDR2-style random events, made by a generator from written parts."
##
## Pure data: no nodes, no WorldHistory writes. The director plays what this
## returns. The same seed always returns the same event, and `all_events()`
## always lists the same events in the same order, so an event id written into
## WorldHistory can be looked up again next session.
##
## An event id is `actor.want.place.act.escalation`.

const Parts := preload("res://systems/event_parts.gd")

static var _all: Array[Dictionary] = []
static var _by_id: Dictionary = {}


## Every distinct coherent event, in a fixed order (parts sorted by id).
static func all_events() -> Array[Dictionary]:
	if _all.is_empty():
		_build()
	return _all


static func count() -> int:
	return all_events().size()


## How many raw combinations exist before the coherence filter, for the
## report to Greg ("this many parts make this many events").
static func raw_combinations() -> int:
	return Parts.ACTORS.size() * Parts.WANTS.size() * Parts.PLACES.size() * Parts.ACTS.size() * Parts.ESCALATIONS.size()


static func event_by_id(event_id: String) -> Dictionary:
	all_events()
	return (_by_id.get(event_id, {}) as Dictionary).duplicate(true)


## The authored ("written in full") event for an actor that has one, else {}.
static func signature_event(actor_id: String) -> Dictionary:
	var actor: Dictionary = Parts.ACTORS.get(actor_id, {})
	var sig: Dictionary = actor.get("signature", {})
	if sig.is_empty():
		return {}
	return event_by_id(_id_of(actor_id, str(sig.want), str(sig.place), str(sig.act), str(sig.escalation)))


## Deterministic pick. The actor is chosen first by its `weight`, so an actor
## with many coherent combinations does not crowd out one with few; then one
## of that actor's events uniformly. `filter` may hold `actor`, `place`,
## `outcome` to narrow the pool (the director passes a drivable-only filter
## when there is no ground a car could use).
static func pick(seed_value: int, filter: Dictionary = {}) -> Dictionary:
	var pool := events_matching(filter)
	if pool.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value) & 0x7fffffffffff
	var by_actor := {}
	for event in pool:
		var actor_id := str(event.actor)
		if not by_actor.has(actor_id):
			by_actor[actor_id] = []
		(by_actor[actor_id] as Array).append(event)
	var actor_ids := by_actor.keys()
	actor_ids.sort()
	var total := 0
	for actor_id in actor_ids:
		total += int((Parts.ACTORS[actor_id] as Dictionary).get("weight", 1))
	var roll := rng.randi_range(1, total)
	var chosen: String = actor_ids[0]
	for actor_id in actor_ids:
		roll -= int((Parts.ACTORS[actor_id] as Dictionary).get("weight", 1))
		if roll <= 0:
			chosen = actor_id
			break
	var options: Array = by_actor[chosen]
	return (options[rng.randi_range(0, options.size() - 1)] as Dictionary).duplicate(true)


static func events_matching(filter: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in all_events():
		if filter.has("actor") and str(event.actor) != str(filter.actor):
			continue
		if filter.has("place") and str(event.place) != str(filter.place):
			continue
		if filter.has("outcome") and str((event.outcome as Dictionary).kind) != str(filter.outcome):
			continue
		if filter.has("exclude_staging") and str(event.staging) in (filter.exclude_staging as Array):
			continue
		out.append(event)
	return out


## The coherence rules, stated once. See the header of event_parts.gd.
static func is_coherent(actor_id: String, want_id: String, place_id: String, act_id: String, escalation_id: String) -> bool:
	var actor: Dictionary = Parts.ACTORS.get(actor_id, {})
	var want: Dictionary = Parts.WANTS.get(want_id, {})
	var place: Dictionary = Parts.PLACES.get(place_id, {})
	var act: Dictionary = Parts.ACTS.get(act_id, {})
	var escalation: Dictionary = Parts.ESCALATIONS.get(escalation_id, {})
	if actor.is_empty() or want.is_empty() or place.is_empty() or act.is_empty() or escalation.is_empty():
		return false
	var tags: Array = actor.get("tags", [])
	for part in [want, act, escalation]:
		if not _tags_allow(tags, part):
			return false
	for needed in actor.get("needs_place", []):
		if not (place.get("tags", []) as Array).has(needed):
			return false
	var outcome := str(escalation.outcome)
	if not (actor.get("outcomes", []) as Array).has(outcome):
		return false
	if not (want.get("leads_to", []) as Array).has(outcome):
		return false
	# Trades need something to give: an actor with no wares cannot trade.
	if outcome == Parts.OUTCOME_TRADE and (actor.get("wares", []) as Array).is_empty():
		return false
	var keys := ["actor:" + actor_id, "want:" + want_id, "place:" + place_id, "act:" + act_id, "escalation:" + escalation_id]
	for pair in Parts.EXCLUDE:
		if keys.has(pair[0]) and keys.has(pair[1]):
			return false
	return true


static func _tags_allow(tags: Array, part: Dictionary) -> bool:
	var need: Array = part.get("require_any", [])
	if not need.is_empty():
		var any := false
		for tag in need:
			if tags.has(tag):
				any = true
				break
		if not any:
			return false
	for tag in part.get("forbid", []):
		if tags.has(tag):
			return false
	return true


static func _id_of(actor_id: String, want_id: String, place_id: String, act_id: String, escalation_id: String) -> String:
	return "%s.%s.%s.%s.%s" % [actor_id, want_id, place_id, act_id, escalation_id]


static func _build() -> void:
	_all.clear()
	_by_id.clear()
	var ids := Parts.part_ids()
	for actor_id in ids.actors:
		for want_id in ids.wants:
			for place_id in ids.places:
				for act_id in ids.acts:
					for escalation_id in ids.escalations:
						if is_coherent(actor_id, want_id, place_id, act_id, escalation_id):
							var event := compose(actor_id, want_id, place_id, act_id, escalation_id)
							_all.append(event)
							_by_id[event.id] = event


## Builds the playable event: title, the mini cutscene's beats, the staging
## the director uses and the outcome it hands off to.
static func compose(actor_id: String, want_id: String, place_id: String, act_id: String, escalation_id: String) -> Dictionary:
	var actor: Dictionary = Parts.ACTORS[actor_id]
	var want: Dictionary = Parts.WANTS[want_id]
	var place: Dictionary = Parts.PLACES[place_id]
	var act: Dictionary = Parts.ACTS[act_id]
	var escalation: Dictionary = Parts.ESCALATIONS[escalation_id]
	var event_id := _id_of(actor_id, want_id, place_id, act_id, escalation_id)
	var sig: Dictionary = actor.get("signature", {})
	var is_signature := not sig.is_empty() and str(sig.want) == want_id and str(sig.place) == place_id and str(sig.act) == act_id and str(sig.escalation) == escalation_id
	var fill := {"who": str(actor.who), "place": str(place.name), "want": str(want.noun)}
	var beats: Array = []
	var title := ""
	if is_signature:
		title = str(sig.title)
		beats = (sig.beats as Array).duplicate(true)
	else:
		title = "%s AT %s" % [str(actor.name), str(place.name).to_upper()]
		var speaker := str(actor.get("boss_name", actor.name)).to_upper()
		beats = [
			{"speaker": "", "line": _cap(_fill(str(act.line), fill)), "shot": "wide", "seconds": 2.4},
			{"speaker": speaker, "line": _fill(str(want.line), fill), "shot": "actor", "seconds": 2.6},
		]
		if bool(act.get("vision", false)):
			beats.append({"speaker": "", "line": "[PLACEHOLDER] A spirit stands up out of the air between them.", "shot": "vision", "seconds": 2.8})
		beats.append({"speaker": "", "line": _cap(_fill(str(escalation.line), fill)), "shot": "actor", "seconds": 2.4})
	var outcome := _outcome(actor_id, actor, want_id, want, escalation, fill, event_id)
	return {
		"id": event_id,
		"actor": actor_id, "want": want_id, "place": place_id, "act": act_id, "escalation": escalation_id,
		"title": title,
		"who": str(actor.who),
		"staging": str(actor.get("staging", "generic")),
		"group": (actor.tags as Array).has("group"),
		"vision": bool(act.get("vision", false)),
		"signature": is_signature,
		"placeholder": Parts.PLACEHOLDER and not is_signature,
		"beats": beats,
		"outcome": outcome,
	}


static func _outcome(actor_id: String, actor: Dictionary, want_id: String, want: Dictionary, escalation: Dictionary, fill: Dictionary, event_id: String) -> Dictionary:
	var kind := str(escalation.outcome)
	var outcome := {"kind": kind}
	match kind:
		Parts.OUTCOME_QUEST:
			outcome["task"] = {
				"title": _cap(_fill(str(want.get("task", "Follow up on {who}.")), fill)),
				"from_actor": actor_id,
				"want": want_id,
				# Freeing the splinter (or anyone who wants freeing) is part of
				# the main task, per Greg; other wants spawn free-standing tasks.
				"parent": str(want.get("main_task", "")),
				"placeholder": true,
			}
		Parts.OUTCOME_TRADE:
			var wares: Array = actor.get("wares", [])
			var asks: Array = actor.get("asks", ["[PLACEHOLDER] something of yours"])
			var h := absi(hash(event_id))
			outcome["offer"] = {
				"gives": str(wares[h % wares.size()]),
				"asks": str(asks[(h / 7) % asks.size()]),
				"placeholder": true,
			}
		Parts.OUTCOME_FIGHT:
			var tier := str(escalation.get("tier", actor.get("fight_tier", Parts.TIER_MINI_BOSS)))
			outcome["tier"] = tier
			outcome["boss"] = {
				"name": str(actor.get("boss_name", actor.name)),
				"elo": int(actor.get("elo", 1200)) + (220 if tier == Parts.TIER_BOSS else 0),
				"kind": "boss" if tier == Parts.TIER_BOSS else "hostile",
			}
	return outcome


static func _fill(text: String, values: Dictionary) -> String:
	return text.format(values)


static func _cap(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)
