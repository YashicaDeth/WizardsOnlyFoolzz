class_name SkinCase
extends RefCounted

## Skin cases: a CS-style case with the game's own rarity ladder (Greg, 24
## September). Cases drop from bodies, contracts and caches, and the Wire's
## exchange sells them for scrip (`CaseMenu`). One case holds one skin.
##
## The roll is pure. `open()` takes the caller's draws, so the odds are exactly
## testable: 10,000 evenly spaced tier draws give 7992 / 1598 / 320 / 63 / 26
## and exactly one gold. Every case's gold row is the shared gold pool, the way
## a CS case's rare special item is.

const SKINS := preload("res://systems/weapon_skins.gd")

const CASES := {
	"wetwork_case": {"label": "WETWORK CASE", "price": 250, "classes": ["gun"], "ink": "4b8bd8"},
	"abattoir_case": {"label": "ABATTOIR CASE", "price": 300, "classes": ["blade", "ram"], "ink": "e0321e"},
	"fools_case": {"label": "FOOL'S WARDROBE CASE", "price": 120, "classes": ["cloth"], "ink": "d9c7a0"},
}


## Which tier a 0..1 draw buys, from the ladder's weights.
static func tier_for(draw: float) -> String:
	var total := 0.0
	for entry: Dictionary in SKINS.TIERS:
		total += float(entry.weight)
	var cursor := clampf(draw, 0.0, 0.9999999) * total
	var running := 0.0
	for entry: Dictionary in SKINS.TIERS:
		running += float(entry.weight)
		if cursor < running:
			return str(entry.id)
	return "issue"


## The skins a case can give at a tier. Gold is shared across every case;
## any other tier this case has nothing in steps down to the next one that has.
static func pool(case_id: String, tier_id: String) -> Array:
	var spec: Dictionary = CASES.get(case_id, {})
	if spec.is_empty():
		return []
	var rank := SKINS.tier_rank(tier_id)
	while rank >= 0:
		var wanted := str(SKINS.TIERS[rank].id)
		var found: Array = []
		for skin_id: String in SKINS.SKINS:
			var skin: Dictionary = SKINS.SKINS[skin_id]
			if str(skin.tier) != wanted:
				continue
			if wanted == "gold" or str(SKINS.TARGETS[skin.target]["class"]) in spec.classes:
				found.append(skin_id)
		if not found.is_empty():
			return found
		rank -= 1
	return []


## Open a case: a tier draw, a pick draw, a wear draw and a pattern seed.
## Returns the receipt with the minted skin item under "item".
static func open(case_id: String, tier_draw: float, pick_draw: float, wear_draw: float, seed: int) -> Dictionary:
	if not CASES.has(case_id):
		return {"ok": false, "reason": "NO SUCH CASE"}
	var tier_id := tier_for(tier_draw)
	var choices := pool(case_id, tier_id)
	if choices.is_empty():
		return {"ok": false, "reason": "EMPTY CASE"}
	var skin_id := str(choices[mini(floori(clampf(pick_draw, 0.0, 0.9999999) * choices.size()), choices.size() - 1)])
	var item := SKINS.mint(skin_id, wear_draw, seed)
	return {
		"ok": true,
		"case": case_id,
		"tier": str(item.tier),
		"skin": skin_id,
		"item": item,
		"label": str(item.label),
	}


## A case as a Carry item, for loot and the shop.
static func case_item(case_id: String) -> Dictionary:
	var spec: Dictionary = CASES.get(case_id, {})
	return {
		"label": str(spec.get("label", "SKIN CASE")),
		"kind": "case",
		"case": case_id,
		"mass": 0.4,
		"perishes": false,
		"age": 0.0,
	}


## What a body or cache has in it: a case, sometimes. `draw` is 0..1; about
## one body in sixteen carries one, gear cases more often than cloth.
static func drop_for(draw: float) -> String:
	if draw >= 0.0625:
		return ""
	var pick := draw / 0.0625
	if pick < 0.4:
		return "wetwork_case"
	if pick < 0.75:
		return "abattoir_case"
	return "fools_case"


## Open a case into `carry`: roll it, count the mint into the world, put the
## skin in the bag and record it. `from_index` is a case item being opened
## (it is used up); -1 means a case bought at the exchange this moment.
static func open_into(carry: Carry, case_id: String, rng: RandomNumberGenerator, from_index := -1) -> Dictionary:
	if carry == null:
		return {"ok": false, "reason": "NO BAG"}
	if from_index >= 0:
		if from_index >= carry.items.size() or str(carry.items[from_index].get("kind", "")) != "case":
			return {"ok": false, "reason": "NOT A CASE"}
		case_id = str(carry.items[from_index].get("case", case_id))
	var receipt := open(case_id, rng.randf(), rng.randf(), rng.randf(), rng.randi_range(0, 999))
	if not bool(receipt.get("ok", false)):
		return receipt
	WorldHistory.begin_ledger_batch()
	if from_index >= 0:
		carry.items.remove_at(from_index)
	carry.items.append(receipt.item)
	SkinMarket.register_mint(receipt.item)
	carry.save_to_history()
	Carry.PLAYER_ACTION_LEDGER.record("case_opened", {"case": case_id, "tier": str(receipt.tier), "kind": "skin", "skin": str(receipt.skin), "wear": float(receipt.item.wear), "seed": int(receipt.item.seed)})
	WorldHistory.commit_ledger_batch()
	return receipt
