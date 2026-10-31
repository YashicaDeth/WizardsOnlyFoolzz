class_name SkinMarket
extends RefCounted

## The Wire's skin market (Greg, 24 September: "make it sellable on economy
## for heaps"). In-game rust scrip only.
##
## A price is the tier's base, times how worn it is, times how scarce that
## skin is in this world (every mint is counted in `WorldHistory`), times the
## kills it has on it, times a pattern bonus for the seeds collectors chase: a
## near-all-blue case-hardened or a full fade. Gold is a fortune on its own.

const SKINS := preload("res://systems/weapon_skins.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

const BASE := {
	"issue": 8,
	"contraband": 45,
	"restricted": 260,
	"covert": 1800,
	"relic": 7500,
	"gold": 250000,
}
const REGISTRY := "skin_registry"


static func minted(skin_id: String) -> int:
	var counts: Dictionary = WorldHistory.subject(REGISTRY).get("minted", {})
	return int(counts.get(skin_id, 0))


## Count a new skin into the world. Every case opened goes through here.
static func register_mint(item: Dictionary) -> void:
	var record := WorldHistory.subject(REGISTRY)
	var counts: Dictionary = (record.get("minted", {}) as Dictionary).duplicate()
	var skin_id := str(item.get("skin", ""))
	counts[skin_id] = int(counts.get(skin_id, 0)) + 1
	WorldHistory.update_subject(REGISTRY, {"minted": counts}, "skin_minted")


static func pattern_bonus(item: Dictionary) -> float:
	var skin: Dictionary = SKINS.SKINS.get(str(item.get("skin", "")), {})
	var seed := int(item.get("seed", 500))
	match str(skin.get("finish", "")):
		"case_hardened":
			# Low seeds come out nearly all blue.
			return 4.0 if seed < 10 else (1.6 if seed < 60 else 1.0)
		"fade":
			return 2.0 if seed > 990 else (1.3 if seed > 900 else 1.0)
	return 1.0


static func price(item: Dictionary) -> int:
	var tier_id := str(item.get("tier", "issue"))
	var base := float(BASE.get(tier_id, 8))
	var wear_value := float(SKINS.wear_band(float(item.get("wear", 0.5))).value)
	var scarcity := 1.0 + 1.5 / (1.0 + float(minted(str(item.get("skin", "")))))
	var kills := 1.0 + minf(float(item.get("kills", 0)) * 0.02, 0.5)
	return maxi(1, roundi(base * wear_value * scarcity * kills * pattern_bonus(item)))


## Sell the skin at `index` in `carry` on the Wire. Refuses anything that is
## not a skin, and never half-applies.
static func sell(carry: Carry, index: int) -> Dictionary:
	if carry == null or index < 0 or index >= carry.items.size():
		return {"ok": false, "reason": "NOTHING THERE"}
	var item: Dictionary = carry.items[index]
	if str(item.get("kind", "")) != "skin":
		return {"ok": false, "reason": "NOT A SKIN"}
	var paid := price(item)
	var inventory := WorldHistory.subject("inventory")
	var wallet := int(inventory.get("rust_scrip", 0)) + paid
	WorldHistory.begin_ledger_batch()
	carry.items.remove_at(index)
	WorldHistory.update_subject("inventory", {"rust_scrip": wallet}, "carry_changed")
	carry.save_to_history()
	PLAYER_ACTION_LEDGER.record("skin_sold", {"skin": str(item.get("skin", "")), "tier": str(item.get("tier", "")), "wear": float(item.get("wear", 0.0)), "paid": paid})
	WorldHistory.commit_ledger_batch()
	return {"ok": true, "paid": paid, "wallet": wallet, "label": str(item.get("label", ""))}
