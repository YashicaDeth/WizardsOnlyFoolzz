class_name VatRebirth
extends RefCounted

## Death is rebirth in a vat (Greg, 24 September 2026, DESIGN.md).
##
##   - "Whoever owns your body grows you back; the world does not rewind."
##   - You wake in the vat of whoever claims you: whichever faction holds your
##     body or your debt at the time (CellOutz, a rival, a cult).
##   - Nothing carried survives. Gear, the gun and clothes stay where you
##     died, on the old body, to be looted or recovered.
##   - The character preset, memories and the world's record carry over, so a
##     death never costs a trip back through creation.
##
## `DefeatRouter` already owns being *taken* (captured, shackled, stamped) and
## the deliberate death in captivity (`redecant`). This is the other door: an
## ordinary death anywhere, which leaves a body behind and a regrown one in a
## claimant's tank. It reads DefeatRouter's `captor_faction` as the first
## claim, so the two agree about who has you.

const CARRY := preload("res://systems/carry.gd")
const CLOTHING := preload("res://systems/clothing.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## CellOutz grew you and owns what it grew (DESIGN/COSMOLOGY.md, the opening's
## "Debt's in the meat"), so with no other claim on you, the body is theirs.
const DEFAULT_CLAIMANT := "celloutz"

## Only the Growing Floor exists as a vat scene today. The other claimants'
## tanks are named so the record says whose vat it was, and share its scene
## until their own rooms are built.
const CLAIMANT_VATS := {
	"celloutz": {"scene": "res://vat_chamber.tscn", "place": "growing_floor", "label": "CELLOUTZ GROWING FLOOR"},
	"ashline_wreckers": {"scene": "res://vat_chamber.tscn", "place": "ashline_shackle_pit", "label": "ASHLINE SHACKLE PIT TANK"},
	"choir_of_marrow": {"scene": "res://vat_chamber.tscn", "place": "ossuary_intake", "label": "OSSUARY INTAKE TANK"},
}


## Who has a claim on the body right now. A captor's claim beats the debt;
## an explicit owner written by any later system beats both.
static func claimant() -> String:
	var player := WorldHistory.subject("player")
	for field in ["body_owner", "captor_faction"]:
		var claim := str(player.get(field, ""))
		if not claim.is_empty():
			return claim
	return DEFAULT_CLAIMANT


static func vat_for(claim: String) -> Dictionary:
	return (CLAIMANT_VATS.get(claim, CLAIMANT_VATS[DEFAULT_CLAIMANT]) as Dictionary).duplicate()


static func is_pending() -> bool:
	return bool(WorldHistory.subject("player").get("rebirth_pending", false))


static func deaths() -> int:
	return int(WorldHistory.subject("player").get("deaths", 0))


## The player dies here. Everything carried and worn goes onto a body left at
## `location`/`position`; the player record is marked for regrowth in the
## claimant's vat. Returns where to send them. Travel is the caller's, so a
## scene can play its own last beat before the cut.
static func die(location: String, cause: String, killed_by := "", position := Vector3.ZERO) -> Dictionary:
	var player := WorldHistory.subject("player")
	var count := int(player.get("deaths", 0)) + 1
	var claim := claimant()
	var vat := vat_for(claim)
	var carry := CARRY.new()
	var items: Array = carry.items.duplicate(true)
	var worn := CLOTHING.worn("player")
	# The parts you had on (the jester set) stay on the old body too; the new
	# one comes out of the vat bare.
	# Only parts actually put on: before the Hunt dresses you, the outfit
	# record does not exist yet and there is nothing of it to leave.
	var outfit_record := WorldHistory.subject(Outfit.SUBJECT)
	var outfit: Dictionary = (outfit_record.get("parts", {}) as Dictionary).duplicate() if bool(outfit_record.get("initialized", false)) else {}
	var remains_id := "remains_%d" % count

	WorldHistory.begin_ledger_batch()
	WorldHistory.register_subject(remains_id, {
		"kind": "remains", "name": "YOUR OLD BODY", "status": "dead",
		"location": location, "position": [position.x, position.y, position.z],
		"items": items, "worn_layer": worn, "worn_condition": CLOTHING.worn_condition("player"),
		"outfit": outfit,
		"died_of": cause, "killed_by": killed_by, "body_number": count, "recovered": false,
	})
	carry.items.clear()
	carry.save_to_history()
	if worn != "bare":
		WorldHistory.amend_subject("player", {"worn_layer": "bare", "worn_condition": 1.0})
	if not outfit.is_empty():
		WorldHistory.update_subject(Outfit.SUBJECT, {"initialized": true, "parts": {}, "locked": false}, "outfit_changed")
	WorldHistory.amend_subject("player", {
		"deaths": count,
		"status": "regrowing",
		"rebirth_pending": true,
		"reborn_by": claim,
		"reborn_at": str(vat.place),
		"body_number": count + 1,
		"memory": "Died at %s (%s). %s grew the body back." % [location.replace("_", " "), cause, str(vat.label)],
	})
	WorldHistory.record_event("player_died", {
		"subject_id": "player", "location": location, "cause": cause, "killed_by": killed_by,
		"remains_id": remains_id, "claimant": claim, "items_left": items.size(),
	})
	PLAYER_ACTION_LEDGER.record("player_reborn_pending", {"claimant": claim, "vat": str(vat.place), "body_number": count + 1})
	WorldHistory.commit_ledger_batch()
	return {"claimant": claim, "vat": vat, "remains_id": remains_id, "scene": str(vat.scene), "items_left": items.size()}


## The regrown body has broken out. Called by the vat, once.
static func complete() -> void:
	if not is_pending():
		return
	WorldHistory.amend_subject("player", {"rebirth_pending": false, "status": "regrown"})
	WorldHistory.record_event("player_regrown", {"subject_id": "player", "body_number": int(WorldHistory.subject("player").get("body_number", 2)), "claimant": claimant()})


## Unrecovered bodies the player left in a place, oldest first.
static func remains_at(location: String) -> Array:
	var found: Array = []
	for index in range(1, deaths() + 1):
		var remains := WorldHistory.subject("remains_%d" % index)
		if remains.is_empty() or bool(remains.get("recovered", false)):
			continue
		if str(remains.get("location", "")) == location:
			var entry := remains.duplicate(true)
			entry["id"] = "remains_%d" % index
			found.append(entry)
	return found


static func remains_position(remains: Dictionary) -> Vector3:
	var at: Array = remains.get("position", [0.0, 0.0, 0.0])
	return Vector3(float(at[0]), float(at[1]), float(at[2])) if at.size() >= 3 else Vector3.ZERO


## Take back what the old body still holds. Clothes go back on only if the
## new body is bare; whatever is already worn stays.
static func recover(remains_id: String) -> Dictionary:
	var remains := WorldHistory.subject(remains_id)
	if remains.is_empty() or str(remains.get("kind", "")) != "remains":
		return {"ok": false, "reason": "NO SUCH BODY"}
	if bool(remains.get("recovered", false)):
		return {"ok": false, "reason": "ALREADY STRIPPED"}
	var carry := CARRY.new()
	var items: Array = remains.get("items", [])
	for item in items:
		carry.items.append((item as Dictionary).duplicate(true) if item is Dictionary else item)
	var outfit: Dictionary = remains.get("outfit", {})
	for part_id: String in outfit:
		carry.items.append(Outfit.part_item(part_id, float(outfit[part_id])))
	WorldHistory.begin_ledger_batch()
	carry.save_to_history()
	var worn := str(remains.get("worn_layer", "bare"))
	var dressed := false
	if worn != "bare" and CLOTHING.worn("player") == "bare":
		WorldHistory.amend_subject("player", {"worn_layer": worn, "worn_condition": float(remains.get("worn_condition", 1.0))})
		dressed = true
	WorldHistory.amend_subject(remains_id, {"recovered": true, "items": [], "worn_layer": "bare", "outfit": {}})
	PLAYER_ACTION_LEDGER.record("player_remains_recovered", {"remains_id": remains_id, "items": items.size(), "dressed": dressed})
	WorldHistory.commit_ledger_batch()
	return {"ok": true, "items": items.size() + outfit.size(), "dressed": dressed}


## Whether the player is carrying something by label. The facility's tools
## live in Carry, so dying really does leave them behind.
static func carries(label: String) -> bool:
	for entry in WorldHistory.subject("inventory").get("items", []):
		if entry is Dictionary and str((entry as Dictionary).get("label", "")) == label:
			return true
	return false
