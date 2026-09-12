class_name Substances
extends RefCounted

## E6. "Substances are the access verb for the entity layer... every
## substance has a body cost the anatomy component already tracks... a
## fictional wasteland economy in the same satirical register as the rest of
## the game. It is not instruction, and real substances should be renamed
## into the world's own vocabulary." — DESIGN/RITUAL_AND_KARMA.md
##
## Nothing in `CATALOG` is a real drug under another name with the serial
## numbers filed off — each is built from what Ashbloom actually has lying
## around (fungal, cybernetic, industrial), per non-negotiable 1.
##
## E6.2 (preparation/consumption minigames) is UI and is not attempted here.
## E6.4 (production/sale economy) is `carry.gd`'s "substance" kind below —
## the same wallet and pricing every other carried thing already uses, not a
## second economy.

const AnatomyComponent := preload("res://systems/anatomy_component.gd")

## AU1.2. "A drug is an object — a baggie, a blister, a tab, a weight." Each
## entry now names which of those it actually is, read by `carry.gd`'s
## `take_substance()` so the item that lands in the bag looks like the thing
## it is rather than a generic "substance" kind — the same way a chunk in
## CARRY already knows it is a limb and not just meat.
const CATALOG := {
	"marrow_dust": {
		"label": "Marrow Dust", "role": "Ground cortical bone, cut and smoked",
		"form": "baggie", "cost_kind": "blood", "cost_amount": 220.0,
		"pain_relief": 30.0, "consciousness_cost": 6.0, "door": false,
	},
	"choir_bloom": {
		"label": "Choir Bloom", "role": "A fungal graft the Choir cultivates for exactly this",
		"form": "weight", "cost_kind": "organ", "cost_target": "liver", "cost_amount": 4.5,
		"pain_relief": 0.0, "consciousness_cost": 18.0, "door": true,
	},
	"static_hymn": {
		"label": "Static Hymn", "role": "A dead mast's feedback, inhaled off a cracked speaker cone",
		"form": "tab", "cost_kind": "limb", "cost_target": "head", "cost_amount": 6.0,
		"pain_relief": 0.0, "consciousness_cost": 26.0, "door": true,
	},
}


## AU1.3. "Two mushrooms are not one item with a number." Flavour names per
## substance, seeded per pickup rather than authored once — a real strain
## identity (`roll_strain()`) rather than a generic label with a condition
## percentage next to it, which is all `carry.gd`'s other perishables get.
const STRAIN_NAMES := {
	"marrow_dust": ["FEMUR CUT", "RIB CUT", "SKULL CUT", "SPINE CUT"],
	"choir_bloom": ["FIRST BLOOM", "SECOND BLOOM", "GRAVE BLOOM", "WET BLOOM"],
	"static_hymn": ["CARRIER TONE", "DEAD AIR", "NUMBERS CUT", "FEEDBACK LOOP"],
}
const POTENCY_RANGE := Vector2(0.7, 1.3)


## Deterministic from `seed_value` — the same pickup rolls the same strain
## every time it is asked, the same guarantee `seal_strokes()` (E2.1) makes
## for a seal. `potency` scales the effect at the point of use rather than
## the cost to acquire it: a weak batch still costs what the catalogue says,
## it just does less for you, which is the whole risk of buying unlabelled
## drugs off whoever is selling this week.
static func roll_strain(substance_id: String, seed_value: int) -> Dictionary:
	var names: Array = STRAIN_NAMES.get(substance_id, ["UNMARKED BATCH"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(substance_id + str(seed_value)) & 0x7fffffff
	return {
		"strain": str(names[rng.randi() % names.size()]),
		"potency": rng.randf_range(POTENCY_RANGE.x, POTENCY_RANGE.y),
	}


## E6.1. Pays into the exact same `anatomy_state` shape `boons.gd` already
## pays boosts into — one body ledger, not two. Refused rather than lethal,
## same as `Boons`: `_pay()` already refuses under its own floors.
##
## AU1.3. `potency` scales what it actually does to you, so a weak batch and
## a strong one costing the same body price is the point — the price was
## paid for whatever you thought you were getting.
static func take(subject_id: String, substance_id: String, potency: float = 1.0) -> Dictionary:
	if not CATALOG.has(substance_id):
		return {"ok": false, "reason": "NO SUCH SUBSTANCE"}
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var data: Dictionary = CATALOG[substance_id].duplicate()
	data["pain_relief"] = float(data.pain_relief) * potency
	data["consciousness_cost"] = float(data.consciousness_cost) * potency
	var payment := Boons._pay(subject_id, str(data.cost_kind), float(data.cost_amount), str(data.get("cost_target", "")))
	if not bool(payment.get("ok", false)):
		return payment
	var anatomy: Dictionary = WorldHistory.subject(subject_id).get("anatomy_state", {})
	anatomy["pain"] = clampf(float(anatomy.get("pain", 0.0)) - float(data.pain_relief), 0.0, 100.0)
	anatomy["consciousness"] = clampf(float(anatomy.get("consciousness", 100.0)) - float(data.consciousness_cost), 0.0, 100.0)
	WorldHistory.amend_subject(subject_id, {"anatomy_state": anatomy})
	WorldHistory.record_event("substance_taken", {
		"subject_id": subject_id, "substance_id": substance_id,
		"cost_kind": data.cost_kind, "cost_amount": data.cost_amount,
	})
	var result := {"ok": true, "consciousness_after": float(anatomy.consciousness), "pain_after": float(anatomy.pain)}
	if bool(data.get("door", false)):
		result["glimpsed"] = _glimpse_one(subject_id, substance_id)
	return result


## AU1.10. "You can lace somebody." Not `take()` under another name: the
## target never consents and never pays through `Boons._pay()` — a
## non-consensual dose does not get to refuse itself under a safety floor,
## it just happens — and the actor gets nothing structural back, no boon, no
## glimpse credited to them. What the actor gets instead is a real witness
## record and a real disagreement: `witness_ledger` (when given one, the
## same object `Extraction.notice()` already takes as a parameter rather
## than assuming a global) decides who actually saw it, and the gods each
## give their own verdict on it exactly the way a death already gets one —
## the game records what happened; it does not congratulate whoever did it.
static func lace(actor_id: String, target_id: String, substance_id: String, witness_ledger: Object = null, witness_ids: Array = []) -> Dictionary:
	if not CATALOG.has(substance_id):
		return {"ok": false, "reason": "NO SUCH SUBSTANCE"}
	var target := WorldHistory.subject(target_id)
	if target.is_empty():
		return {"ok": false, "reason": "NO SUCH TARGET"}
	var data: Dictionary = CATALOG[substance_id]
	var anatomy: Dictionary = target.get("anatomy_state", {})
	anatomy["pain"] = clampf(float(anatomy.get("pain", 0.0)) - float(data.pain_relief), 0.0, 100.0)
	anatomy["consciousness"] = clampf(float(anatomy.get("consciousness", 100.0)) - float(data.consciousness_cost), 0.0, 100.0)
	WorldHistory.amend_subject(target_id, {"anatomy_state": anatomy})
	var details := {"actor_id": actor_id, "target_id": target_id, "substance_id": substance_id}
	var event: Dictionary
	if witness_ledger != null and witness_ledger.has_method("record"):
		event = witness_ledger.record("subject_laced", details, witness_ids)
	else:
		event = WorldHistory.record_event("subject_laced", details)
	# AJ5.4/AJ5.7. Two verdicts on one act is the normal outcome here too,
	# never averaged — each god's own opinion, attributed to its own name,
	# the same as `ModernGods.record_death_verdicts()` already does for a
	# kill. Reimplemented rather than called through, since that function is
	# named and shaped for a death specifically and this is not one.
	var verdicts: Array = []
	for god_id in ModernGods.GODS.keys():
		var result: Dictionary = ModernGods.verdict(str(god_id), target_id, {"witnessed": witness_ids.size()})
		if result.is_empty():
			continue
		verdicts.append(result)
		WorldHistory.record_event("lacing_verdict", {
			"actor_id": actor_id, "target_id": target_id, "god_id": str(god_id),
			"label": result.label, "lean": result.lean,
		})
	return {
		"ok": true, "event_sequence": int(event.get("sequence", -1)),
		"witnessed_by": witness_ids.size(), "verdicts": verdicts,
	}


## The one currently-buildable half of E6.3: which entity a door-substance
## opens onto. Deterministic per subject/substance/attempt rather than truly
## random, so a save is reproducible and a test does not have to seed an RNG
## to assert on the outcome.
static func _glimpse_one(subject_id: String, substance_id: String) -> String:
	var entity_ids := AscentEntities.ENTITIES.keys()
	if entity_ids.is_empty():
		return ""
	var index := int(hash(subject_id + substance_id + str(WorldHistory.next_sequence))) % entity_ids.size()
	var entity_id := str(entity_ids[absi(index)])
	AscentEntities.glimpse(entity_id, subject_id)
	return entity_id
