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
}

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


static func stats(subject_id: String) -> Dictionary:
	return (CATALOG.get(worn(subject_id), CATALOG.bare) as Dictionary).duplicate(true)


## AS3.3/AS3.4. Writes `clothing_bias` onto the subject alongside the layer
## itself — resolved once, here, rather than `world_history.gd` reaching back
## into this file's own catalog every time `tree_alignment()` runs for every
## subject in the world.
static func wear(subject_id: String, item_id: String) -> Dictionary:
	if not CATALOG.has(item_id):
		return {"ok": false, "reason": "NO SUCH LAYER"}
	if WorldHistory.subject(subject_id).is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var bias := float(CATALOG[item_id].get("faction_bias", 0.0))
	WorldHistory.begin_ledger_batch()
	WorldHistory.amend_subject(subject_id, {"worn_layer": item_id, "clothing_bias": bias})
	var details := {"subject_id": subject_id, "item_id": item_id}
	if subject_id == "player":
		PLAYER_ACTION_LEDGER.record("layer_worn", details)
	else:
		WorldHistory.record_event("layer_worn", details)
	WorldHistory.commit_ledger_batch()
	return {"ok": true}


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
