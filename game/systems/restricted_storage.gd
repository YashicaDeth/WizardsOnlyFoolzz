class_name RestrictedStorage
extends RefCounted

## AX3.5. "The Black Mirror is stolen from restricted technology storage as a
## rare prototype, not issued as an ordinary menu." The device itself already
## exists — `black_mirror.gd` draws it, `handheld_device.gd` runs it, and
## `handheld_device.gd` already has a full `possessed` flag with `drop()` /
## `confiscate()` / `repossess()` built for losing and regaining it. What was
## missing was a reason the player does not simply start holding it.
##
## This is that reason, plus what it costs. A fresh "handheld" record is
## registered unpossessed here, before any `HandheldDevice` ever loads one —
## `WorldHistory.register_subject()` only ever fills in fields a record does
## not already have, so whichever of "the room" or "the phone UI" runs first
## does not matter, and `handheld_device.gd` itself needed no edit. Taking the
## prototype flips that same field, the same way `repossess()` would, but
## under its own ledger name: "found it again" and "stolen for the first
## time" are different facts even though the state change is identical.

const HANDHELD := preload("res://systems/handheld_device.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")

const SUBJECT := "restricted_storage"
const DEVICE_ID := HANDHELD.DEVICE_ID


static func ensure() -> Dictionary:
	WorldHistory.begin_ledger_batch()
	var record := WorldHistory.subject(SUBJECT)
	if record.is_empty():
		record = WorldHistory.register_subject(SUBJECT, {
			"kind": "storage_room",
			"name": "RESTRICTED TECHNOLOGY STORAGE",
			"breached": false,
		})
	if WorldHistory.subject(DEVICE_ID).is_empty():
		WorldHistory.register_subject(DEVICE_ID, {"kind": "object", "possessed": false})
	WorldHistory.commit_ledger_batch()
	return record


static func is_breached() -> bool:
	return bool(ensure().get("breached", false))


## The one action the room offers. Idempotent: a second attempt after the
## prototype is already gone changes nothing and posts no second bounty.
static func take_prototype(details: Dictionary = {}) -> Dictionary:
	WorldHistory.begin_ledger_batch()
	ensure()
	if is_breached():
		WorldHistory.commit_ledger_batch()
		return {"ok": false, "reason": "ALREADY TAKEN"}
	WorldHistory.update_subject(SUBJECT, {"breached": true}, "restricted_storage_breached")
	WorldHistory.update_subject(DEVICE_ID, {"possessed": true}, "device_changed")
	var payload := details.duplicate(true)
	PLAYER_ACTION_LEDGER.record("black_mirror_stolen", payload)
	_raise_theft_reaction()
	WorldHistory.commit_ledger_batch()
	return {"ok": true}


## Mirrors `FacilityTerritory._raise_reaction()` on purpose: stealing the
## prototype is the same "CellOutz notices and wants its property back"
## consequence a later derby win raises, just earned earlier and for a
## different reason. Reading `FACILITY_TERRITORY`'s public subject ids rather
## than calling its private `_raise_reaction()` keeps this file the only
## writer of its own beat; whichever reaction lands first wins and the other
## is a no-op, so the order is never posted twice.
##
## TODO(AX4 owner): once both the theft and the derby-win path exist, consider
## folding this into one shared `raise_repossession_order()` in
## `facility_territory.gd` instead of two call sites building the same shape.
static func _raise_theft_reaction() -> void:
	if not WorldHistory.subject(FACILITY_TERRITORY.REACTION_SUBJECT).is_empty():
		return
	WorldHistory.register_subject(FACILITY_TERRITORY.REACTION_SUBJECT, {
		"kind": "job",
		"name": "REPOSSESSION ORDER 0C-7",
		"role": "OPEN CORPORATE BOUNTY",
		"faction": "CellOutz",
		"faction_id": "celloutz",
		"status": "circulating",
		"target_id": "player",
		"threat": "RECOVER THE STOLEN PROTOTYPE; ASSET MAY BE DISASSEMBLED",
		"memory": "CellOutz lists the missing handset as inventory and pays any account that returns it.",
	})
	WorldHistory.record_event("celloutz_repossession_order_posted", {
		"subject_id": FACILITY_TERRITORY.REACTION_SUBJECT,
		"target_id": "player",
		"territory": FACILITY_TERRITORY.SUBJECT,
	})
