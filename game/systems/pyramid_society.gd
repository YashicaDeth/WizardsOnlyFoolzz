class_name PyramidSociety
extends RefCounted

## Canonical, presentation-independent model for social standing, dossiers,
## recurring enemies and the graveyard. It deliberately does not manufacture a
## single ELO-like number: every dimension remains available to game rules and
## the UI, while pyramid placement uses named eligibility gates and scarce
## places. Combat can make somebody dangerous without making them socially
## powerful.

const SCHEMA_VERSION := 1
const DIMENSIONS := [
	"class", "influence", "wealth", "access", "reputation", "fear",
	"respect", "faction", "combat", "leverage", "knowledge", "relationships",
]
const REFERENCE_KINDS := ["evidence", "social_posts", "websites", "locations", "associates", "notes"]
const DEAD_STATUSES := ["dead", "executed", "killed"]

## Original vocabulary rather than another game's named hierarchy. Capacities
## make the silhouette of the pyramid real: one apex, then 3, 9, 27, and the
## uncapped population beneath it.
const BANDS := [
	{"id": "singularity", "label": "SINGULARITY", "capacity": 1},
	{"id": "privy", "label": "PRIVY RING", "capacity": 3},
	{"id": "office", "label": "OFFICE", "capacity": 9},
	{"id": "network", "label": "NETWORK", "capacity": 27},
	{"id": "outside", "label": "OUTSIDE", "capacity": -1},
]

var records: Dictionary = {}
var graveyard: Dictionary = {}
var next_event_sequence := 1
var _resurrection_hooks: Dictionary = {}


func register_subject(subject_id: String, initial: Dictionary = {}) -> Dictionary:
	if subject_id.is_empty():
		return {}
	if records.has(subject_id):
		var current: Dictionary = records[subject_id]
		var incoming := _migrate_record(subject_id, initial)
		# Registration is migration-safe. New authored keys fill gaps but never
		# erase state earned in an older save.
		for key in incoming:
			if not current.has(key):
				current[key] = incoming[key]
		current["schema_version"] = SCHEMA_VERSION
		current["social_power"] = _normalise_power(current.get("social_power", {}), current)
		current["dossier"] = _normalise_dossier(current.get("dossier", {}))
		current["nemesis_events"] = _dictionary_array(current.get("nemesis_events", []))
		records[subject_id] = current
	else:
		records[subject_id] = _migrate_record(subject_id, initial)
	return subject(subject_id)


func subject(subject_id: String) -> Dictionary:
	return (records.get(subject_id, {}) as Dictionary).duplicate(true)


func all_subjects() -> Dictionary:
	return records.duplicate(true)


func update_power(subject_id: String, changes: Dictionary) -> Dictionary:
	var entry := register_subject(subject_id)
	var power: Dictionary = entry.social_power
	for dimension in changes:
		if DIMENSIONS.has(str(dimension)):
			power[str(dimension)] = clampf(float(changes[dimension]), 0.0, 100.0)
	entry["social_power"] = power
	records[subject_id] = entry
	return subject(subject_id)


func set_alignment(subject_id: String, alignment: float) -> Dictionary:
	var entry := register_subject(subject_id)
	entry["alignment"] = clampf(alignment, -1.0, 1.0)
	records[subject_id] = entry
	return subject(subject_id)


## Returns a player-facing band, its population location and the full vector.
## No total/score is returned or stored.
func standing(subject_id: String, faction_id: String = "") -> Dictionary:
	var layout := pyramid(faction_id)
	for band in layout.bands:
		for member in (band as Dictionary).members:
			if str((member as Dictionary).id) == subject_id:
				return (member as Dictionary).duplicate(true)
	return {}


func pyramid(faction_id: String = "") -> Dictionary:
	var living: Array[Dictionary] = []
	for subject_id in records:
		var entry: Dictionary = records[subject_id]
		if str(entry.get("kind", "person")) != "person":
			continue
		if DEAD_STATUSES.has(str(entry.get("status", "active")).to_lower()):
			continue
		if not faction_id.is_empty() and str(entry.get("faction_id", "")) != faction_id:
			continue
		var candidate := entry.duplicate(true)
		candidate["id"] = subject_id
		candidate["eligible_band"] = _eligible_band(candidate.social_power)
		living.append(candidate)
	# Structural fields decide scarce office before physical danger. This is a
	# lexicographic comparison, not a hidden scalar rating.
	living.sort_custom(_precedes)
	var bands: Array[Dictionary] = []
	for definition in BANDS:
		bands.append({
			"id": definition.id,
			"label": definition.label,
			"capacity": definition.capacity,
			"members": [],
		})
	for candidate in living:
		var band_index := int(candidate.eligible_band)
		while band_index < bands.size() - 1:
			var capacity := int(bands[band_index].capacity)
			if capacity < 0 or (bands[band_index].members as Array).size() < capacity:
				break
			band_index += 1
		var members: Array = bands[band_index].members
		var slot := members.size()
		members.append(_placement(candidate, band_index, slot))
		bands[band_index].members = members
	return {
		"schema_version": SCHEMA_VERSION,
		"faction_id": faction_id,
		"headcount": living.size(),
		"bands": bands,
		"graveyard_count": graveyard.size(),
		"geometry": "3x3_expanding_horseshoe",
	}


func record_nemesis_event(subject_id: String, event_type: String, details: Dictionary = {}) -> Dictionary:
	var entry := register_subject(subject_id)
	if event_type.is_empty():
		return {}
	var event := {
		"id": "nemesis_%06d" % next_event_sequence,
		"sequence": next_event_sequence,
		"type": event_type,
		"details": _json_safe(details),
	}
	next_event_sequence += 1
	var history: Array = entry.nemesis_events
	history.append(event)
	entry["nemesis_events"] = history
	entry["is_rival"] = true
	entry["last_nemesis_event"] = event.id
	records[subject_id] = entry
	return event.duplicate(true)


func nemesis_history(subject_id: String) -> Array:
	return (subject(subject_id).get("nemesis_events", []) as Array).duplicate(true)


func link_dossier(subject_id: String, kind: String, reference: Dictionary) -> Dictionary:
	var entry := register_subject(subject_id)
	if not REFERENCE_KINDS.has(kind) or reference.is_empty():
		return {}
	var safe: Dictionary = _json_safe(reference)
	if not safe.has("id"):
		safe["id"] = "%s_%08x" % [kind.trim_suffix("s"), hash(JSON.stringify(safe)) & 0xffffffff]
	var dossier: Dictionary = entry.dossier
	var references: Array = dossier[kind]
	for existing in references:
		if str((existing as Dictionary).get("id", "")) == str(safe.id):
			return (existing as Dictionary).duplicate(true)
	references.append(safe)
	dossier[kind] = references
	entry["dossier"] = dossier
	records[subject_id] = entry
	return safe.duplicate(true)


func dossier(subject_id: String) -> Dictionary:
	return (subject(subject_id).get("dossier", {}) as Dictionary).duplicate(true)


## Death archives rather than deletes. Resurrection prices are descriptive
## world-resource metadata only; this service never talks to payment systems or
## real currency.
func mark_dead(subject_id: String, death: Dictionary = {}, resurrection: Dictionary = {}) -> Dictionary:
	var entry := register_subject(subject_id)
	if entry.is_empty():
		return {}
	entry["status"] = "dead"
	entry["death"] = _json_safe(death)
	records[subject_id] = entry
	var grave := {
		"subject_id": subject_id,
		"death": entry.death,
		"nemesis_event_count": (entry.nemesis_events as Array).size(),
		"resurrection": _normalise_resurrection(resurrection),
	}
	graveyard[subject_id] = grave
	record_nemesis_event(subject_id, "subject_died", death)
	grave["nemesis_event_count"] = (records[subject_id].nemesis_events as Array).size()
	graveyard[subject_id] = grave
	return grave.duplicate(true)


func graveyard_entries() -> Array:
	var entries: Array = graveyard.values()
	entries.sort_custom(func(a, b): return str(a.subject_id) < str(b.subject_id))
	return entries.duplicate(true)


func resurrection_offer(subject_id: String) -> Dictionary:
	return (graveyard.get(subject_id, {}) as Dictionary).get("resurrection", {}).duplicate(true)


func register_resurrection_hook(hook_id: String, callback: Callable) -> void:
	if not hook_id.is_empty() and callback.is_valid():
		_resurrection_hooks[hook_id] = callback


## Produces a request for an economy/quest system to fulfil. It does not deduct
## resources. Unknown hook ids remain valid serialized dependencies so future
## builds can restore the save before their provider is loaded.
func request_resurrection(subject_id: String) -> Dictionary:
	if not graveyard.has(subject_id):
		return {"ok": false, "reason": "NOT_IN_GRAVEYARD"}
	var offer: Dictionary = resurrection_offer(subject_id)
	if not bool(offer.get("available", false)):
		return {"ok": false, "reason": "UNAVAILABLE"}
	return {
		"ok": true,
		"subject_id": subject_id,
		"costs": (offer.get("costs", []) as Array).duplicate(true),
		"hook_ids": (offer.get("hook_ids", []) as Array).duplicate(),
	}


## Called only after another game system has decided the fictional cost/story
## requirements were met. Receipts are metadata, never a transaction.
func complete_resurrection(subject_id: String, receipt: Dictionary = {}) -> Dictionary:
	var request := request_resurrection(subject_id)
	if not bool(request.get("ok", false)):
		return request
	var entry := subject(subject_id)
	entry["status"] = "active"
	entry["resurrection_receipt"] = _json_safe(receipt)
	records[subject_id] = entry
	graveyard.erase(subject_id)
	var event := record_nemesis_event(subject_id, "subject_resurrected", receipt)
	for hook_id in request.hook_ids:
		var callback: Callable = _resurrection_hooks.get(str(hook_id), Callable())
		if callback.is_valid():
			callback.call(subject_id, event.duplicate(true))
	return subject(subject_id)


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"next_event_sequence": next_event_sequence,
		"records": _json_safe(records),
		"graveyard": _json_safe(graveyard),
	}


func restore(payload: Dictionary) -> void:
	records.clear()
	graveyard.clear()
	next_event_sequence = maxi(1, int(payload.get("next_event_sequence", 1)))
	var stored_records: Dictionary = payload.get("records", payload.get("subjects", {}))
	for subject_id in stored_records:
		if stored_records[subject_id] is Dictionary:
			records[str(subject_id)] = _migrate_record(str(subject_id), stored_records[subject_id])
	var stored_graves: Dictionary = payload.get("graveyard", {})
	for subject_id in stored_graves:
		if stored_graves[subject_id] is Dictionary and records.has(str(subject_id)):
			var grave: Dictionary = (stored_graves[subject_id] as Dictionary).duplicate(true)
			grave["subject_id"] = str(subject_id)
			grave["death"] = _json_safe(grave.get("death", {}))
			grave["resurrection"] = _normalise_resurrection(grave.get("resurrection", {}))
			graveyard[str(subject_id)] = grave
	# Old saves sometimes only carried status=dead. They still belong in the
	# graveyard after migration and keep every unknown authored field.
	for subject_id in records:
		var entry: Dictionary = records[subject_id]
		for event in entry.nemesis_events:
			next_event_sequence = maxi(next_event_sequence, int((event as Dictionary).get("sequence", 0)) + 1)
		if DEAD_STATUSES.has(str(entry.status).to_lower()) and not graveyard.has(subject_id):
			graveyard[subject_id] = {
				"subject_id": subject_id,
				"death": _json_safe(entry.get("death", {})),
				"nemesis_event_count": (entry.nemesis_events as Array).size(),
				"resurrection": _normalise_resurrection({}),
			}


func _migrate_record(subject_id: String, source: Dictionary) -> Dictionary:
	var out := source.duplicate(true)
	out["schema_version"] = SCHEMA_VERSION
	out["id"] = subject_id
	out["name"] = str(out.get("name", subject_id))
	out["kind"] = str(out.get("kind", "person"))
	out["status"] = str(out.get("status", "active"))
	out["faction_id"] = str(out.get("faction_id", ""))
	out["alignment"] = clampf(float(out.get("alignment", out.get("tree_alignment", 0.0))), -1.0, 1.0)
	out["social_power"] = _normalise_power(out.get("social_power", out.get("power_dimensions", {})), out)
	out["dossier"] = _normalise_dossier(out.get("dossier", {}))
	out["nemesis_events"] = _dictionary_array(out.get("nemesis_events", []))
	out["is_rival"] = bool(out.get("is_rival", not (out.nemesis_events as Array).is_empty()))
	return out


func _normalise_power(value: Variant, legacy: Dictionary = {}) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var power := {}
	for dimension in DIMENSIONS:
		var fallback: Variant = legacy.get(dimension, 0.0)
		# Old `faction_rank` and `elo` fields are intentionally not collapsed into
		# this model. They survive as legacy data, but do not secretly determine it.
		power[dimension] = clampf(float(source.get(dimension, fallback)), 0.0, 100.0)
	return power


func _normalise_dossier(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var out := source.duplicate(true)
	for kind in REFERENCE_KINDS:
		out[kind] = _dictionary_array(source.get(kind, []))
	return out


func _normalise_resurrection(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var costs: Array[Dictionary] = []
	for raw in source.get("costs", []):
		if not raw is Dictionary:
			continue
		var cost: Dictionary = raw
		var category := str(cost.get("category", "world_resource"))
		# Explicitly reject real-money/payment metadata. Resurrection may consume
		# scrip, organs, favours or story state in-game, never cash or crypto.
		if category in ["real_money", "fiat", "crypto", "payment"]:
			continue
		costs.append({
			"resource": str(cost.get("resource", "unknown")),
			"amount": maxf(0.0, float(cost.get("amount", 0.0))),
			"category": category,
		})
	var hooks: Array[String] = []
	for hook in source.get("hook_ids", []):
		if not str(hook).is_empty() and not hooks.has(str(hook)):
			hooks.append(str(hook))
	return {
		"available": bool(source.get("available", false)),
		"costs": costs,
		"hook_ids": hooks,
		"story_gate": str(source.get("story_gate", "")),
	}


func _eligible_band(power: Dictionary) -> int:
	if float(power.class) >= 90.0 and float(power.influence) >= 75.0 and float(power.access) >= 70.0 and float(power.leverage) >= 65.0:
		return 0
	if float(power.class) >= 70.0 and float(power.influence) >= 55.0 and float(power.access) >= 50.0:
		return 1
	if float(power.influence) >= 40.0 and (float(power.faction) >= 40.0 or float(power.wealth) >= 55.0) and float(power.access) >= 30.0:
		return 2
	if float(power.influence) >= 18.0 or float(power.relationships) >= 30.0 or float(power.reputation) >= 35.0:
		return 3
	return 4


func _precedes(a: Dictionary, b: Dictionary) -> bool:
	if int(a.eligible_band) != int(b.eligible_band):
		return int(a.eligible_band) < int(b.eligible_band)
	for dimension in ["class", "influence", "access", "leverage", "relationships", "faction", "wealth", "knowledge", "reputation", "respect", "fear", "combat"]:
		var left := float((a.social_power as Dictionary)[dimension])
		var right := float((b.social_power as Dictionary)[dimension])
		if not is_equal_approx(left, right):
			return left > right
	return str(a.id) < str(b.id)


func _placement(candidate: Dictionary, band_index: int, slot: int) -> Dictionary:
	var alignment := float(candidate.get("alignment", 0.0))
	var side := "ABOVE" if alignment > 0.15 else ("BELOW" if alignment < -0.15 else "HINGE")
	var width := 1 if band_index == 0 else int(pow(3.0, float(mini(band_index, 3))))
	var column := slot % maxi(1, width)
	var depth := slot / maxi(1, width)
	# Both poles curve back toward the apex. A renderer can use these stable
	# normalized coordinates for a flat view or supply `depth` as the third axis.
	var arc := alignment * PI * 0.82
	return {
		"id": str(candidate.id),
		"name": str(candidate.name),
		"band_id": str(BANDS[band_index].id),
		"band_label": str(BANDS[band_index].label),
		"social_power": (candidate.social_power as Dictionary).duplicate(true),
		"alignment": alignment,
		"side": side,
		"position": {
			"row": band_index,
			"column": column,
			"depth": depth,
			"horseshoe_x": snappedf(sin(arc), 0.001),
			"horseshoe_y": snappedf(-cos(arc), 0.001),
		},
	}


func _dictionary_array(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				out.append((item as Dictionary).duplicate(true))
	return out


func _json_safe(value: Variant) -> Variant:
	# JSON round-tripping also strips object/callable references from data that
	# is promised to survive a save.
	var encoded := JSON.stringify(value)
	var decoded: Variant = JSON.parse_string(encoded)
	return decoded if decoded != null else {}
