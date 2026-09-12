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

const CATALOG := {
	"marrow_dust": {
		"label": "Marrow Dust", "role": "Ground cortical bone, cut and smoked",
		"cost_kind": "blood", "cost_amount": 220.0,
		"pain_relief": 30.0, "consciousness_cost": 6.0, "door": false,
	},
	"choir_bloom": {
		"label": "Choir Bloom", "role": "A fungal graft the Choir cultivates for exactly this",
		"cost_kind": "organ", "cost_target": "liver", "cost_amount": 4.5,
		"pain_relief": 0.0, "consciousness_cost": 18.0, "door": true,
	},
	"static_hymn": {
		"label": "Static Hymn", "role": "A dead mast's feedback, inhaled off a cracked speaker cone",
		"cost_kind": "limb", "cost_target": "head", "cost_amount": 6.0,
		"pain_relief": 0.0, "consciousness_cost": 26.0, "door": true,
	},
}


## E6.1. Pays into the exact same `anatomy_state` shape `boons.gd` already
## pays boosts into — one body ledger, not two. Refused rather than lethal,
## same as `Boons`: `_pay()` already refuses under its own floors.
static func take(subject_id: String, substance_id: String) -> Dictionary:
	if not CATALOG.has(substance_id):
		return {"ok": false, "reason": "NO SUCH SUBSTANCE"}
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var data: Dictionary = CATALOG[substance_id]
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
