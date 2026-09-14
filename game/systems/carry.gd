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

const ImplantCatalog := preload("res://systems/implant_catalog.gd")

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
		# B5.4: a robbed part keeps whose it was for as long as it exists. The
		# Choir reads it to price the risk; the owner reads it to recognise it.
		"lien": str(info.get("lien", "")),
		"stolen": bool(info.get("stolen", false)),
	}
	items.append(item)
	save_to_history()
	WorldHistory.record_event("carried_part", {"subject": str(info.get("subject_id", "")), "part": label})
	return item


## E6.4. A produced or bought substance, carried the same way a robbed part
## is — same wallet, same `sale_value()`, same spoil clock — rather than a
## second inventory only drugs live in.
const SubstancesCatalog := preload("res://systems/substances.gd")


## AU1.2. `stolen` marks it the same way a robbed organ already is — B5.6's
## "a part somebody watched you cut out is worth less" applies here through
## the exact same `sale_value()` heat discount, not a second rule invented
## for drugs specifically.
func take_substance(substance_id: String, stolen := false) -> Dictionary:
	if not SubstancesCatalog.CATALOG.has(substance_id):
		return {}
	var data: Dictionary = SubstancesCatalog.CATALOG[substance_id]
	var form := str(data.get("form", "weight"))
	# AU1.3. Seeded per pickup off the world's own event counter, so this
	# exact baggie rolls the same strain if asked twice and the next one off
	# a different body does not — two mushrooms are not one item with a
	# number, they are two different numbers.
	var strain := SubstancesCatalog.roll_strain(substance_id, WorldHistory.next_sequence)
	var item := {
		"label": "%s — %s (%s)" % [str(data.label).to_upper(), str(strain.strain), form.to_upper()], "kind": "substance",
		"substance_id": substance_id, "form": form, "strain": str(strain.strain), "potency": float(strain.potency),
		"mass": 0.2, "perishes": true, "age": 0.0, "condition": 1.0, "stolen": stolen,
	}
	items.append(item)
	save_to_history()
	return item


## AU1.2. "It can be stolen off a body." A subject can carry one substance as
## real data (`carried_substance`, the same shape `wounds`/`anatomy` already
## live in) rather than a drug only ever existing once the player already has
## it — taking it clears the subject's own copy, so it cannot be lifted twice,
## and always sets `stolen`, the same as anything else taken off somebody who
## did not hand it over.
func take_from_subject(subject_id: String) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	var substance_id := str(subject.get("carried_substance", ""))
	if substance_id.is_empty():
		return {}
	var item := take_substance(substance_id, true)
	if item.is_empty():
		return item
	WorldHistory.update_subject(subject_id, {"carried_substance": ""}, "robbed")
	return item


func first_index(kind: String) -> int:
	for index in items.size():
		if str((items[index] as Dictionary).get("kind", "")) == kind:
			return index
	return -1


## C8.2 / AS3.2. "Pockets are real, and what is in them is in them." Not a
## second inventory — the same real `items` this file has always carried,
## with `pocketed` marking which ones are on the body rather than in the bag
## CAPACITY already budgets against (this file's own comment already named
## the difference: "a person with pockets, not a rucksack simulator"). Small
## and few on purpose: a pocket holds what a hand can find without looking,
## not the whole kit.
const POCKET_CAPACITY := 3
const POCKET_MASS_LIMIT := 0.6


func pocketed_items() -> Array:
	var found: Array = []
	for item in items:
		if bool((item as Dictionary).get("pocketed", false)):
			found.append(item)
	return found


## Moves a carried item into a pocket. Refused, not silently truncated, when
## there is genuinely nowhere left or the thing does not fit a pocket at
## all — a severed limb does not go in a pocket regardless of how few are
## already full.
func pocket(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {"ok": false, "reason": "NOTHING THERE"}
	var item: Dictionary = items[index]
	if bool(item.get("pocketed", false)):
		return {"ok": false, "reason": "ALREADY POCKETED"}
	if float(item.get("mass", 0.5)) > POCKET_MASS_LIMIT:
		return {"ok": false, "reason": "TOO BIG FOR A POCKET"}
	if pocketed_items().size() >= POCKET_CAPACITY:
		return {"ok": false, "reason": "POCKETS ARE FULL"}
	item["pocketed"] = true
	items[index] = item
	save_to_history()
	return {"ok": true, "item": item}


## The other direction — into the bag, off the body. Nothing here refuses a
## bag that is already over `CAPACITY`; `burden()` already answers for that
## the same way it does for everything else carried.
func unpocket(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {"ok": false, "reason": "NOTHING THERE"}
	var item: Dictionary = items[index]
	if not bool(item.get("pocketed", false)):
		return {"ok": false, "reason": "NOT POCKETED"}
	item["pocketed"] = false
	items[index] = item
	save_to_history()
	return {"ok": true, "item": item}


## What a search actually finds. A frisk or a robbery that only pats down
## pockets should never turn up the severed limb wrapped in the bag on your
## back — this is the honest, narrower half of `items`, real objects same as
## the rest, not a second, separately-tracked fiction of "small stuff".
func search_pockets() -> Array:
	return pocketed_items()


func damage_item(index: int, amount: float) -> float:
	if index < 0 or index >= items.size():
		return 0.0
	var item: Dictionary = items[index]
	item["condition"] = clampf(float(item.get("condition", 1.0)) - maxf(0.0, amount), 0.0, 1.0)
	items[index] = item
	save_to_history()
	return float(item.condition)


## R1.1. The currency named and given a reason: CellOutz, the same company
## that grew the player, issues it — "ownership, downward" reaching all the
## way to the coin, not just the body.
const CURRENCY := "rust_scrip"
const CURRENCY_ISSUER := "celloutz"


func currency_reason() -> String:
	var issuer := WorldHistory.subject(CURRENCY_ISSUER)
	if issuer.is_empty():
		return "Rust scrip. Issued by nobody in particular, which is its own kind of answer."
	return "Rust scrip, issued by %s: %s" % [str(issuer.get("name", CURRENCY_ISSUER)), str(issuer.get("doctrine", ""))]


## R1.3. "A market is a set of people, not a price." Each buyer wants
## something more than the base rate says, drawn from what the faction
## already is (Choir of Marrow deals in anatomy, Vanity Row deals in
## augments) rather than an invented preference table.
## AU1.2. "The Choir prices it." Choir of Marrow already deals in anatomy at
## a premium; substance is added here rather than assumed, since a body-cult
## pricing what its own members put in their bodies is exactly its lane —
## priced above the anonymous-broker baseline but not as hungrily as the
## anatomy it actually specialises in.
const FACTION_APPETITES := {
	"choir_of_marrow": {"organ": 1.5, "limb": 0.85, "substance": 1.2},
	"vanity_row": {"cybernetic": 1.6, "organ": 0.8},
	"honeyvein": {"substance": 1.4},
	"black_mile": {"cybernetic": 1.15, "substance": 0.9},
}


func _appetite(buyer_faction: String, kind: String) -> float:
	if buyer_faction.is_empty():
		return 1.0
	return float((FACTION_APPETITES.get(buyer_faction, {}) as Dictionary).get(kind, 1.0))


## R1.5. "Prices move with what the world has been through." Read from real
## market history rather than a clock: the more of a kind that has actually
## sold recently, the less the next one is worth — a real glut, not a random
## fluctuation. Floors at half rather than collapsing to nothing.
const GLUT_WINDOW := 40
const GLUT_STEP := 0.04


func _market_glut(kind: String) -> float:
	var recent := 0
	var checked := 0
	for index in range(WorldHistory.events.size() - 1, -1, -1):
		if checked >= GLUT_WINDOW:
			break
		var event: Dictionary = WorldHistory.events[index]
		if str(event.get("type", "")) != "carried_part_sold":
			continue
		checked += 1
		var part: Dictionary = (event.get("details", {}) as Dictionary).get("part", {})
		if str(part.get("kind", "")) == kind:
			recent += 1
	return clampf(1.0 - float(recent) * GLUT_STEP, 0.5, 1.0)


## The first economy seam. The Choir/Soft Rot price identity, remaining
## condition and freshness; the wallet lives beside CARRY, not inside the item.
## `buyer_faction` is who is standing in front of you. E1.2: the same part is
## worth different money to different people, because where they sit on the
## Tree relative to you is the whole of their opinion of you. An empty buyer is
## an anonymous broker who prices nothing but the meat.
func sale_value(item: Dictionary, buyer_faction: String = "") -> int:
	var kind := str(item.get("kind", ""))
	var base := int({"limb": 7, "organ": 12, "cybernetic": 24, "substance": 3}.get(kind, 0))
	if base <= 0:
		return 0
	var condition := clampf(float(item.get("condition", 1.0)), 0.0, 1.0)
	# B5.6. A part somebody watched you cut out is worth less, because the
	# broker is pricing the chance of being asked where it came from. It is the
	# cost of being seen rather than a morality tax.
	var heat := 0.62 if bool(item.get("stolen", false)) else 1.0
	var standing := 1.0
	if not buyer_faction.is_empty():
		standing = WorldHistory.faction_price_factor(buyer_faction, WorldHistory.subject("player"))
		if standing <= 0.0:
			# They will not deal with you at all. Zero is a refusal, not a price.
			return 0
	var appetite := _appetite(buyer_faction, kind)
	var glut := _market_glut(kind)
	return maxi(1, roundi(float(base) * maxf(0.2, condition) * maxf(0.15, freshness(item)) * heat * standing * appetite * glut))


## B5.5. A robbed implant goes into your own body through the same verb that
## installed the one you were decanted with. Condition travels with it: a part
## you tore out with your hands works as badly for you as it would have for
## anyone else.
func install_into(index: int, rig: BaselineHuman) -> Dictionary:
	if index < 0 or index >= items.size() or rig == null or not is_instance_valid(rig):
		return {}
	var item: Dictionary = items[index]
	if str(item.get("kind", "")) != "cybernetic":
		return {}
	var implant_id := str(item.get("implant", item.get("label", ""))).to_lower()
	var catalogue := ImplantCatalog.resolve(implant_id, str(item.get("zone", "torso")))
	var maximum := maxf(1.0, float(catalogue.max_condition))
	rig.install_prosthetic(str(catalogue.zone), {
		"name": implant_id,
		"condition": clampf(float(item.get("condition", 1.0)), 0.0, 1.0) * maximum,
	})
	items.remove_at(index)
	save_to_history()
	WorldHistory.record_event("implant_installed", {
		"implant": implant_id,
		"zone": str(catalogue.zone),
		"condition": snappedf(float(item.get("condition", 1.0)), 0.01),
		"lien": str(item.get("lien", "")),
	})
	return {"implant": implant_id, "zone": str(catalogue.zone), "condition": float(item.get("condition", 1.0))}


func sell(index: int, buyer_faction: String = "") -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var item: Dictionary = items[index]
	var price := sale_value(item, buyer_faction)
	if price <= 0:
		# Either the part is worthless or this buyer will not take it from you.
		# The caller needs to be able to tell those apart to say anything useful.
		if not buyer_faction.is_empty() and WorldHistory.faction_price_factor(buyer_faction, WorldHistory.subject("player")) <= 0.0:
			return {"refused": true, "faction": buyer_faction, "disposition": WorldHistory.faction_disposition(buyer_faction, WorldHistory.subject("player"))}
		return {}
	items.remove_at(index)
	var inventory := WorldHistory.subject("inventory")
	var wallet := int(inventory.get("rust_scrip", 0)) + price
	WorldHistory.update_subject("inventory", {"items": items.duplicate(true), "rust_scrip": wallet}, "carried_part_sold")
	WorldHistory.record_event("carried_part_sold", {"part": item.duplicate(true), "price": price, "currency": "rust_scrip", "buyer_faction": buyer_faction})
	return {"item": item, "price": price, "wallet": wallet, "faction": buyer_faction, "disposition": WorldHistory.faction_disposition(buyer_faction, WorldHistory.subject("player")) if not buyer_faction.is_empty() else ""}


## R1.4. "Debt you can be in, since `debt_to_player` already runs the other
## way." A faction's own opinion of you already reads through
## `faction_price_factor`; this is the ledger a real consequence would read,
## rather than a second morality system — carrying a real, growing number
## rather than a flag.
func debt_to(lender_faction: String) -> int:
	var debts: Dictionary = WorldHistory.subject("inventory").get("player_debt", {})
	return int(debts.get(lender_faction, 0))


## Borrowing is real scrip added to the wallet now, in exchange for a real
## debt recorded against a real faction — never conjured value with no
## ledger behind it.
func borrow(amount: int, lender_faction: String) -> Dictionary:
	if amount <= 0 or lender_faction.is_empty():
		return {"ok": false, "reason": "NOTHING TO BORROW"}
	if WorldHistory.subject(lender_faction).is_empty():
		return {"ok": false, "reason": "NO SUCH LENDER"}
	var inventory := WorldHistory.subject("inventory")
	var debts: Dictionary = (inventory.get("player_debt", {}) as Dictionary).duplicate(true)
	debts[lender_faction] = int(debts.get(lender_faction, 0)) + amount
	var wallet := int(inventory.get("rust_scrip", 0)) + amount
	WorldHistory.update_subject("inventory", {"rust_scrip": wallet, "player_debt": debts}, "player_borrowed")
	WorldHistory.record_event("player_borrowed", {"lender_faction": lender_faction, "amount": amount, "owed_after": debts[lender_faction]})
	return {"ok": true, "wallet": wallet, "owed": int(debts[lender_faction])}


## Paying down is capped at what is actually owed and what is actually in the
## wallet — never a negative debt, never a wallet that goes below zero.
func repay(amount: int, lender_faction: String) -> Dictionary:
	var owed := debt_to(lender_faction)
	if amount <= 0 or owed <= 0:
		return {"ok": false, "reason": "NOTHING OWED"}
	var inventory := WorldHistory.subject("inventory")
	var wallet := int(inventory.get("rust_scrip", 0))
	var paid := mini(amount, mini(owed, wallet))
	if paid <= 0:
		return {"ok": false, "reason": "NOTHING IN THE WALLET TO PAY IT WITH"}
	var debts: Dictionary = (inventory.get("player_debt", {}) as Dictionary).duplicate(true)
	debts[lender_faction] = owed - paid
	WorldHistory.update_subject("inventory", {"rust_scrip": wallet - paid, "player_debt": debts}, "player_repaid")
	WorldHistory.record_event("player_repaid", {"lender_faction": lender_faction, "amount": paid, "owed_after": debts[lender_faction]})
	return {"ok": true, "paid": paid, "owed": int(debts[lender_faction]), "wallet": wallet - paid}


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
