class_name Clothing
extends RefCounted

## AS3. Layers as a world system rather than a paperdoll.
##
## Greg: *"pockets and clothes should be integral, or at least a part of the
## world system, layers and strategy to everything."*
##
## AS3.1/AS3.3: one worn layer at a time, drawn from a small catalog the same
## shape as `substances.gd`'s — each entry a real reason to wear it (warmth
## against `storm_weather.gd`'s exposure cost, standing with the factions
## `WorldHistory.tree_alignment()` already prices trades against) rather than
## a cosmetic skin. Nothing here is a real fabric under an invented name —
## each is built from what a wrecker actually has lying around, per
## `DESIGN/RITUAL_AND_KARMA.md`'s non-negotiable 1, the same rule
## `substances.gd` already follows.
##
## AS3.2: pockets are a small, *named* capacity — three particular things
## kept on you — deliberately separate from `carry.gd`'s mass-based bag,
## which is everything looted rather than everything worn close.
##
## AS3.4 (shows on the body the mirror renders): the coat itself is real and
## tinted per layer in `hunter_appearance.gd` — visible on the body in the
## ordinary camera right now. Left unchecked in CHECKLIST.md regardless: the
## literal mirror this item names (AH1.5/B9.1) is not built anywhere in the
## project yet, so there is nothing to prove the second half of the claim
## against.
##
## Radiation is named in AS3.3 alongside weather and faction standing, and
## `radiation_resist` is carried on every entry for it, but there is no
## radiation stat anywhere in the project yet for it to reduce — the same
## honest gap AS1.5 and AS2.3 already carry rather than a fabricated system.

const CATALOG := {
	"bare": {
		"label": "Bare", "role": "Whatever was already on you",
		"tint": "594d3c", "warmth": 0.0, "radiation_resist": 0.0, "faction_bias": 0.0,
	},
	"scavenged_coat": {
		"label": "Scavenged Coat", "role": "Layered off three coats nobody else wanted",
		"tint": "29271f", "warmth": 0.35, "radiation_resist": 0.05, "faction_bias": 0.0,
	},
	"storm_oilskin": {
		"label": "Storm Oilskin", "role": "Waxed canvas, cut for a wrecker crew's worst shift",
		"tint": "1d2b26", "warmth": 0.55, "radiation_resist": 0.05, "faction_bias": -0.04,
	},
	"lead_vest": {
		"label": "Lead-Lined Vest", "role": "Scrapped off a downed satellite's own shielding",
		"tint": "3a3d33", "warmth": 0.15, "radiation_resist": 0.6, "faction_bias": -0.08,
	},
	"gate_lantern_wrap": {
		"label": "Gate Lantern Wrap", "role": "Bought off the Choir at a price that was never money",
		"tint": "6b5a3a", "warmth": 0.2, "radiation_resist": 0.1, "faction_bias": 0.12,
	},
	# AX3.2. The Growing Floor's own issue, not a shop item: stencilled with a
	# subject number that is never the wearer's own until they make it theirs.
	# `HUMILIATION_TAG` marks it so a caller can ask "is this institutional
	# degradation" without string-matching the id.
	"humiliation_smock": {
		"label": "Humiliation Smock", "role": "Stencilled with a subject number that was never yours",
		"tint": "5c4636", "warmth": 0.1, "radiation_resist": 0.0, "faction_bias": -0.06,
		"tag": "humiliation",
	},
}

## AX3.2. "The outfit begins as institutional degradation." Any catalog entry
## carrying this tag is that — checked by tag rather than by id, so a second
## degradation garment does not need its own special-cased string later.
const HUMILIATION_TAG := "humiliation"

## AS3.2. Three, not a number tuned for balance — enough to matter what you
## chose to keep close, not enough that a pocket is just a second bag.
const POCKET_CAPACITY := 3
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")


## Never invents "bare" as a stored fact — a subject nobody has dressed yet
## simply reads as bare, the same way `condition` reads as intact until
## something actually happens to it.
static func worn(subject_id: String) -> String:
	var layer := str(WorldHistory.subject(subject_id).get("worn_layer", "bare"))
	return layer if CATALOG.has(layer) else "bare"


## AX3.2. Scaled by `worn_condition` rather than returning the catalog entry
## raw: a torn garment gives less of what it gave whole, the same way a
## carried part's `condition` already discounts its `sale_value()` in
## `carry.gd`. Whole cloth (never degraded) reads exactly as it always did.
static func stats(subject_id: String) -> Dictionary:
	var entry := (CATALOG.get(worn(subject_id), CATALOG.bare) as Dictionary).duplicate(true)
	var condition := worn_condition(subject_id)
	entry["warmth"] = float(entry.get("warmth", 0.0)) * condition
	entry["radiation_resist"] = float(entry.get("radiation_resist", 0.0)) * condition
	entry["condition"] = condition
	return entry


## AX3.2. Never invents 1.0 as a stored fact for a garment that has actually
## been torn — but a subject nobody has degraded yet reads as whole, the same
## refusal `worn()` already makes for a subject nobody has dressed.
static func worn_condition(subject_id: String) -> float:
	return clampf(float(WorldHistory.subject(subject_id).get("worn_condition", 1.0)), 0.0, 1.0)


## AX3.2. "Physically tears/degrades." A real, persisted number a struggle, a
## door, a guard's grip — anything this project builds later — can reduce,
## rather than a cosmetic timer. Floors at 0 instead of going negative; it
## does not strip the garment back to bare on its own, because *what it looks
## like at 0* is `worn_label()`'s question, not this one's.
static func degrade(subject_id: String, amount: float) -> float:
	var after := clampf(worn_condition(subject_id) - maxf(0.0, amount), 0.0, 1.0)
	WorldHistory.amend_subject(subject_id, {"worn_condition": after})
	WorldHistory.record_event("layer_degraded", {"subject_id": subject_id, "item_id": worn(subject_id), "condition": after})
	return after


## AX3.2. "Visibly tears" without a second render path: the label itself
## carries the tear, the same way `carry.gd`'s `condition_label()` already
## turns a number into FRESH/TURNING/SPOILED/ROTTEN rather than a bar nobody
## reads. Whole cloth still reads as the catalog's own label, unmodified.
static func worn_label(subject_id: String) -> String:
	var item_id := worn(subject_id)
	if item_id == "bare":
		return "BARE"
	var label := str(CATALOG[item_id].get("label", item_id)).to_upper()
	var condition := worn_condition(subject_id)
	if condition <= 0.0:
		return "BARE // %s TORN AWAY" % label
	if condition < 0.35:
		return "TORN %s" % label
	if condition < 1.0:
		return "TATTERED %s" % label
	return label


## AS3.3/AS3.4. Writes `clothing_bias` onto the subject alongside the layer
## itself — resolved once, here, rather than `world_history.gd` reaching back
## into this file's own catalog every time `tree_alignment()` runs for every
## subject in the world.
##
## AX3.2. Also resets `worn_condition` to whole. Every ordinary donning is
## putting on something clean; a garment that arrives already damaged
## (`take_worn()` below) degrades it explicitly, right after, rather than
## this function guessing at a starting condition for every caller.
static func wear(subject_id: String, item_id: String) -> Dictionary:
	if not CATALOG.has(item_id):
		return {"ok": false, "reason": "NO SUCH LAYER"}
	if WorldHistory.subject(subject_id).is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var bias := float(CATALOG[item_id].get("faction_bias", 0.0))
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(subject_id, {"worn_layer": item_id, "clothing_bias": bias, "worn_condition": 1.0})
	var details := {"subject_id": subject_id, "item_id": item_id}
	if subject_id == "player":
		PLAYER_ACTION_LEDGER.record("layer_worn", details)
	else:
		WorldHistory.record_event("layer_worn", details)
	WorldHistory.commit_ledger_batch()
	return {"ok": true}


## AX3.2. "Take clothing off a dead subject." Refused for anyone not already
## dead — this is specifically the failed-subject garment DESIGN/
## PLAYER_DIRECTION_INTERVIEW_2026-09-18.md names, not a general strip-the-
## living looting verb nothing in this project has asked for yet. The taken
## garment does not arrive pristine: pulling it off wreckage costs it real
## condition in the same act, so "physically tears" is true the moment it is
## acquired rather than only after some later system gets around to it.
static func take_worn(from_subject_id: String, to_subject_id: String) -> Dictionary:
	var source := WorldHistory.subject(from_subject_id)
	if source.is_empty():
		return {"ok": false, "reason": "NO SUCH BODY"}
	if not (str(source.get("status", "")) in ["dead", "failed", "executed", "killed"]):
		return {"ok": false, "reason": "STILL LIVING"}
	var item_id := worn(from_subject_id)
	if item_id == "bare":
		return {"ok": false, "reason": "NOTHING WORN"}
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(from_subject_id, {"worn_layer": "bare", "worn_condition": 1.0})
	var result := wear(to_subject_id, item_id)
	if bool(result.get("ok", false)):
		degrade(to_subject_id, 0.3)
		var details := {"subject_id": to_subject_id, "item_id": item_id, "from": from_subject_id}
		if to_subject_id == "player":
			PLAYER_ACTION_LEDGER.record("garment_taken_from_dead", details)
		else:
			WorldHistory.record_event("garment_taken_from_dead", details)
		result["condition"] = worn_condition(to_subject_id)
	WorldHistory.commit_ledger_batch()
	return result


static func pocketed(subject_id: String) -> Array:
	return (WorldHistory.subject(subject_id).get("pocket_items", []) as Array).duplicate()


static func pocket(subject_id: String, item_id: String) -> Dictionary:
	var items := pocketed(subject_id)
	if items.size() >= POCKET_CAPACITY:
		return {"ok": false, "reason": "POCKETS ARE FULL"}
	items.append(item_id)
	WorldHistory.amend_subject(subject_id, {"pocket_items": items})
	return {"ok": true, "items": items}


static func unpocket(subject_id: String, item_id: String) -> Dictionary:
	var items := pocketed(subject_id)
	var index := items.find(item_id)
	if index < 0:
		return {"ok": false, "reason": "NOT IN POCKET"}
	items.remove_at(index)
	WorldHistory.amend_subject(subject_id, {"pocket_items": items})
	return {"ok": true, "items": items}
