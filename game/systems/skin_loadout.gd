class_name SkinLoadout
extends RefCounted

## Which skin is on what. Applying a skin takes it out of the bag and puts it
## on its target (a weapon, the ram, a jester part); removing it gives it
## back. The world keeps the record, so a skin stays on across scenes, and
## the wear it picks up in a fight is saved on the item itself.

const SUBJECT := "skin_loadout"
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")


static func applied(target: String) -> Dictionary:
	var worn: Dictionary = WorldHistory.subject(SUBJECT).get("applied", {})
	return (worn.get(target, {}) as Dictionary).duplicate(true)


static func all_applied() -> Dictionary:
	return (WorldHistory.subject(SUBJECT).get("applied", {}) as Dictionary).duplicate(true)


static func _store(target: String, item: Dictionary) -> void:
	var worn: Dictionary = (WorldHistory.subject(SUBJECT).get("applied", {}) as Dictionary).duplicate(true)
	if item.is_empty():
		worn.erase(target)
	else:
		worn[target] = item
	WorldHistory.update_subject(SUBJECT, {"applied": worn}, "skin_loadout_changed")


## Put the skin at `index` in `carry` on its target. A skin already there
## goes back into the bag.
static func apply(carry: Carry, index: int) -> Dictionary:
	if carry == null or index < 0 or index >= carry.items.size():
		return {"ok": false, "reason": "NOTHING THERE"}
	var item: Dictionary = carry.items[index]
	if str(item.get("kind", "")) != "skin":
		return {"ok": false, "reason": "NOT A SKIN"}
	var target := str(item.get("target", ""))
	WorldHistory.begin_ledger_batch()
	carry.items.remove_at(index)
	var previous := applied(target)
	if not previous.is_empty():
		carry.items.append(previous)
	_store(target, item)
	carry.save_to_history()
	PLAYER_ACTION_LEDGER.record("skin_applied", {"skin": str(item.get("skin", "")), "target": target})
	WorldHistory.commit_ledger_batch()
	return {"ok": true, "target": target, "item": item, "returned": previous}


static func remove(carry: Carry, target: String) -> Dictionary:
	var item := applied(target)
	if item.is_empty() or carry == null:
		return {"ok": false, "reason": "NO SKIN ON IT"}
	WorldHistory.begin_ledger_batch()
	_store(target, {})
	carry.items.append(item)
	carry.save_to_history()
	PLAYER_ACTION_LEDGER.record("skin_removed", {"skin": str(item.get("skin", "")), "target": target})
	WorldHistory.commit_ledger_batch()
	return {"ok": true, "item": item}


## Wear the applied skin on `target` from use; returns the item as it is now
## (empty when nothing is applied).
static func scuff(target: String, amount: float, bloodied := 0.0, killed := false) -> Dictionary:
	var item := applied(target)
	if item.is_empty():
		return {}
	WeaponSkins.scuff(item, amount, bloodied, killed)
	_store(target, item)
	return item
