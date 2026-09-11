class_name Carry
extends RefCounted

## What you are carrying, as things rather than as a list of nouns.
##
## C4. The inventory subject has existed in `WorldHistory` since the Hunt
## Grounds were built and has never been on screen — `register_subject
## ("inventory", {"items": []})` and nothing else. Surfacing it as strings would
## have been a morning's work and would have violated I0 on the way past, so
## this is the model underneath it instead.
##
## Three things make it worth being a system rather than an array:
##
## - **B4 already produces identified objects.** A chunk knows its layer, its
##   zone, the person it came off and which organ or implant it is. Carrying it
##   has to preserve that, because B5 (robbing), the ritual camera and the organ
##   economy all read it back.
## - **Mass is a real constraint** (C4.3). A body will hold so much, and a
##   player dragging a leg and three organs should feel it.
## - **Meat spoils.** An organ is worth something for a while and then it is
##   worth nothing and then it is a problem. That is a clock on looting, and it
##   is what stops the Choir's economy being a vending machine.

const SPOIL_SECONDS := 420.0
## Kilograms a body will carry before it starts costing movement. Deliberately
## low: this is a person with pockets, not a rucksack simulator.
const CAPACITY := 28.0

## Per-layer mass and whether it rots. Bone and hardware keep; the wet layers
## do not.
const LAYER_MASS := {
	"skin": 0.3, "fat": 0.6, "muscle": 1.4, "bone": 1.1, "organ": 0.9, "cybernetic": 2.2, "limb": 5.5,
}
const LAYER_PERISHES := {
	"skin": true, "fat": true, "muscle": true, "bone": false, "organ": true, "cybernetic": false, "limb": true,
}

var items: Array = []
var _since_save := 0.0


func _init() -> void:
	load_from_history()


## Anything the world already recorded as carried, restored. Plain strings from
## before this system existed are kept as untyped goods rather than dropped.
func load_from_history() -> void:
	items.clear()
	var record: Dictionary = WorldHistory.subject("inventory")
	for entry in record.get("items", []):
		if entry is Dictionary:
			items.append((entry as Dictionary).duplicate())
		else:
			items.append({"label": str(entry), "kind": "goods", "mass": 0.5, "perishes": false, "age": 0.0})


func save_to_history() -> void:
	WorldHistory.update_subject("inventory", {"items": items.duplicate(true)}, "carry_changed")


## C4.2. A chunk becomes a carried object without losing what it is. The
## identity dictionary from `GoreChunks.take()` goes in whole.
func take_chunk(info: Dictionary) -> Dictionary:
	if info.is_empty():
		return {}
	var layer := str(info.get("layer_name", "muscle"))
	var label := layer.to_upper()
	if bool(info.get("whole_limb", false)):
		label = "SEVERED %s" % str(info.get("zone", "limb")).replace("_", " ").to_upper()
	elif str(info.get("implant", "")) != "":
		label = str(info.get("implant", "")).to_upper()
	elif str(info.get("organ_id", "")) != "":
		label = str(info.get("organ_id", "")).replace("_", " ").to_upper()
	else:
		label = "%s (%s)" % [layer.to_upper(), str(info.get("zone", "")).replace("_", " ").to_upper()]
	var item := {
		"label": label,
		"kind": layer,
		"mass": float(LAYER_MASS.get(layer, 0.8)),
		"perishes": bool(LAYER_PERISHES.get(layer, true)),
		"age": 0.0,
		"from": str(info.get("subject_id", "")),
		"zone": str(info.get("zone", "")),
		"organ_id": str(info.get("organ_id", "")),
		"implant": str(info.get("implant", "")),
		"whole_limb": bool(info.get("whole_limb", false)),
		"condition": clampf(float(info.get("condition", 1.0)), 0.0, 1.0),
	}
	items.append(item)
	save_to_history()
	WorldHistory.record_event("carried_part", {"subject": str(info.get("subject_id", "")), "part": label})
	return item


func first_index(kind: String) -> int:
	for index in items.size():
		if str((items[index] as Dictionary).get("kind", "")) == kind:
			return index
	return -1


func damage_item(index: int, amount: float) -> float:
	if index < 0 or index >= items.size():
		return 0.0
	var item: Dictionary = items[index]
	item["condition"] = clampf(float(item.get("condition", 1.0)) - maxf(0.0, amount), 0.0, 1.0)
	items[index] = item
	save_to_history()
	return float(item.condition)


## The first economy seam. The Choir/Soft Rot price identity, remaining
## condition and freshness; the wallet lives beside CARRY, not inside the item.
func sale_value(item: Dictionary) -> int:
	var base := int({"limb": 7, "organ": 12, "cybernetic": 24}.get(str(item.get("kind", "")), 0))
	if base <= 0:
		return 0
	var condition := clampf(float(item.get("condition", 1.0)), 0.0, 1.0)
	return maxi(1, roundi(float(base) * maxf(0.2, condition) * maxf(0.15, freshness(item))))


func sell(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var item: Dictionary = items[index]
	var price := sale_value(item)
	if price <= 0:
		return {}
	items.remove_at(index)
	var inventory := WorldHistory.subject("inventory")
	var wallet := int(inventory.get("rust_scrip", 0)) + price
	WorldHistory.update_subject("inventory", {"items": items.duplicate(true), "rust_scrip": wallet}, "carried_part_sold")
	WorldHistory.record_event("carried_part_sold", {"part": item.duplicate(true), "price": price, "currency": "rust_scrip"})
	return {"item": item, "price": price, "wallet": wallet}


func drop(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var gone: Dictionary = items[index]
	items.remove_at(index)
	save_to_history()
	return gone


func total_mass() -> float:
	var total := 0.0
	for item in items:
		total += float((item as Dictionary).get("mass", 0.5))
	return total


## Over capacity you do not stop moving, you move worse. A hard cap would make
## the player stand over loot deciding; a penalty makes them carry it and regret
## it, which is the more interesting failure.
func burden() -> float:
	return clampf(total_mass() / CAPACITY, 0.0, 2.0)


## Fresh meat is worth something. This is the clock that makes looting a
## decision about *when* to sell rather than only whether to pick it up.
func freshness(item: Dictionary) -> float:
	if not bool(item.get("perishes", false)):
		return 1.0
	return clampf(1.0 - float(item.get("age", 0.0)) / SPOIL_SECONDS, 0.0, 1.0)


func condition_label(item: Dictionary) -> String:
	if not bool(item.get("perishes", false)):
		return "KEEPS"
	var fresh := freshness(item)
	if fresh > 0.66:
		return "FRESH"
	if fresh > 0.33:
		return "TURNING"
	if fresh > 0.0:
		return "SPOILED"
	return "ROTTEN"


## Advanced by whoever owns the carry — the hunt loop, not this class, because
## time should not pass inside a menu.
func age(delta: float) -> void:
	var changed := false
	for item in items:
		if not bool((item as Dictionary).get("perishes", false)):
			continue
		item["age"] = float(item.get("age", 0.0)) + delta
		changed = true
	if not changed:
		return
	# Persisted on an interval rather than every frame. The first attempt keyed
	# the interval off `items[0]`, which crashes the moment nothing perishable
	# is carried and is a silly way to count seconds regardless.
	_since_save += delta
	if _since_save >= 30.0:
		_since_save = 0.0
		save_to_history()
