class_name HuntContracts
extends RefCounted

## F10.8/F10.9 / AR2. A contract is not a menu promise or a second money
## economy. It is a one-use WorldHistory subject posted by an existing patron
## against an existing subject whose obstruction is named as frequency or aura.
## Taking it spends the same body/standing ledger as every other supernatural
## bargain, then consumes the offer before it can be taken again.

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")
const BLOCK_KINDS := ["frequency", "aura"]
const RESOLVED_STATUSES := ["dead", "executed", "escaped", "spared", "recruited"]


## Publishing is deliberately narrow. The ascending side must first have
## noticed the player through AscentEntities' real mercy ledger; the descending
## side must be whoever holds CellOutz's CROWN *now*. Captains and faction
## labels cannot masquerade as either top patron.
static func publish(patron_id: String, target_id: String, block_kind: String, obstruction: String, cost_kind: String, cost_amount: float, cost_target: String = "") -> Dictionary:
	var patron := WorldHistory.subject(patron_id)
	var target := WorldHistory.subject(target_id)
	if patron.is_empty() or not _patron_side(patron_id, patron) in ["ascent", "descent"]:
		return {"ok": false, "reason": "PATRON CANNOT POST TOP-TIER WORK"}
	if target.is_empty() or str(target.get("kind", "")) not in ["person", "entity"]:
		return {"ok": false, "reason": "NO EXACT LIVING TARGET"}
	if not BLOCK_KINDS.has(block_kind) or obstruction.strip_edges().is_empty():
		return {"ok": false, "reason": "NO FREQUENCY OR AURA OBSTRUCTION"}
	if not Boons.COST_KINDS.has(cost_kind) or cost_amount <= 0.0:
		return {"ok": false, "reason": "CONTRACT HAS NO REAL COST"}
	var contract_id := "hunt_contract:%s:%s:%06d" % [patron_id, target_id, WorldHistory.next_sequence]
	var contract := WorldHistory.register_subject(contract_id, {
		"name": "%s // %s" % [str(patron.get("name", patron_id)), str(target.get("name", target_id))],
		"kind": "job", "job_class": "frequency_bounty", "status": "offered",
		"patron_id": patron_id, "patron_side": _patron_side(patron_id, patron),
		"target_id": target_id, "block_kind": block_kind,
		"obstruction": obstruction.strip_edges(),
		"cost_kind": cost_kind, "cost_amount": cost_amount, "cost_target": cost_target,
		"uses_remaining": 1, "issued_at": WorldClock.long_stamp(),
	})
	WorldHistory.record_event("hunt_contract_published", {
		"subject_id": contract_id, "patron_id": patron_id, "target_id": target_id,
		"patron_side": str(contract.patron_side), "block_kind": block_kind,
	})
	contract["id"] = contract_id
	contract["ok"] = true
	return contract


## The debit happens before the offer changes state. A refused payment leaves
## the same offer available; a successful one consumes its only use and writes
## one compact player-action receipt. Re-entering with an active/completed id
## returns the row without charging the body a second time.
static func accept(contract_id: String, hunter_id: String = "player") -> Dictionary:
	var contract := WorldHistory.subject(contract_id)
	if str(contract.get("job_class", "")) != "frequency_bounty":
		return {"ok": false, "reason": "NO SUCH HUNT CONTRACT"}
	if str(contract.get("status", "")) != "offered" or int(contract.get("uses_remaining", 0)) <= 0:
		contract["ok"] = false
		contract["reason"] = "CONTRACT ALREADY CONSUMED"
		return contract
	if WorldHistory.subject(hunter_id).is_empty():
		return {"ok": false, "reason": "NO SUCH HUNTER"}
	WorldHistory.begin_ledger_batch()
	var payment := Boons.pay(
		hunter_id, str(contract.cost_kind), float(contract.cost_amount), str(contract.get("cost_target", ""))
	)
	if not bool(payment.get("ok", false)):
		WorldHistory.commit_ledger_batch()
		return payment
	contract = WorldHistory.amend_subject(contract_id, {
		"status": "active", "uses_remaining": 0, "accepted_by": hunter_id,
		"accepted_at": WorldClock.long_stamp(), "cost_paid": float(contract.cost_amount),
	})
	PLAYER_ACTION_LEDGER.record("hunt_contract_consumed", {
		"subject_id": contract_id, "hunter_id": hunter_id,
		"patron_id": str(contract.patron_id), "target_id": str(contract.target_id),
		"cost_kind": str(contract.cost_kind), "cost_paid": float(contract.cost_amount),
		"cost_target": str(contract.get("cost_target", "")),
	})
	WorldHistory.commit_ledger_batch()
	contract["ok"] = true
	return contract


## Resolution reads the exact target fresh. It never completes from a generic
## kill count or proximity trigger, and it does not decide which outcome a
## patron approves — the contract only asked that this subject stop blocking.
static func resolve(contract_id: String) -> Dictionary:
	var contract := WorldHistory.subject(contract_id)
	if str(contract.get("job_class", "")) != "frequency_bounty" or str(contract.get("status", "")) != "active":
		return {"ok": false, "reason": "CONTRACT IS NOT ACTIVE"}
	var target := WorldHistory.subject(str(contract.target_id))
	var outcome := str(target.get("status", "")).to_lower()
	if not RESOLVED_STATUSES.has(outcome):
		return {"ok": false, "reason": "EXACT TARGET STILL BLOCKS THE %s" % str(contract.block_kind).to_upper()}
	contract = WorldHistory.update_subject(contract_id, {
		"status": "completed", "completed_at": WorldClock.long_stamp(),
		"target_outcome": outcome,
	}, "hunt_contract_completed")
	contract["ok"] = true
	return contract


static func offers() -> Array[Dictionary]:
	return _contracts_with_status("offered")


static func active() -> Array[Dictionary]:
	return _contracts_with_status("active")


## The first organic market edge. Once an ascent entity has really noticed the
## player, it and the current CROWN holder see one another as reciprocal signal
## obstructions. The names and office are read fresh from the world; succession
## changes who posts and who is targeted without a second authored quest. One
## open pair per relationship keeps repeated mercy checks from printing offers.
static func publish_opposition(ascent_id: String) -> Array[Dictionary]:
	var ascent := WorldHistory.subject(ascent_id)
	if str(ascent.get("kind", "")) != "entity" or not bool(ascent.get("has_noticed", false)):
		return []
	var crown_id := TheFourHorsemen.current_reign()
	var crown := WorldHistory.subject(crown_id)
	if crown_id.is_empty() or crown.is_empty():
		return []
	var published: Array[Dictionary] = []
	if not _has_open_contract(ascent_id, crown_id, "frequency"):
		published.append(publish(
			ascent_id, crown_id, "frequency",
			"%s holds CellOutz's descending carrier across %s's frequency." % [str(crown.get("name", crown_id)), str(ascent.get("name", ascent_id))],
			"blood", 250.0,
		))
	if not _has_open_contract(crown_id, ascent_id, "aura"):
		published.append(publish(
			crown_id, ascent_id, "aura",
			"%s's noticed aura lifts subjects beyond %s's signal control." % [str(ascent.get("name", ascent_id)), str(crown.get("name", crown_id))],
			"standing", 5.0,
		))
	return published.filter(func(row: Dictionary): return bool(row.get("ok", false)))


static func _contracts_with_status(status: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for subject_id in WorldHistory.all_subjects():
		var subject := WorldHistory.subject(str(subject_id))
		if str(subject.get("job_class", "")) != "frequency_bounty" or str(subject.get("status", "")) != status:
			continue
		subject["id"] = str(subject_id)
		rows.append(subject)
	return rows


static func _has_open_contract(patron_id: String, target_id: String, block_kind: String) -> bool:
	for subject_id in WorldHistory.all_subjects():
		var subject := WorldHistory.subject(str(subject_id))
		if str(subject.get("job_class", "")) != "frequency_bounty":
			continue
		if str(subject.get("status", "")) not in ["offered", "active"]:
			continue
		if str(subject.get("patron_id", "")) == patron_id and str(subject.get("target_id", "")) == target_id and str(subject.get("block_kind", "")) == block_kind:
			return true
	return false


static func _patron_side(patron_id: String, patron: Dictionary) -> String:
	if str(patron.get("kind", "")) == "entity" and str(patron.get("faction_id", "")) == "wizardsonlyfoolz" and bool(patron.get("has_noticed", false)):
		return "ascent"
	if DemonHierarchy.tier(patron_id) == DemonHierarchy.TIER_LEADERSHIP:
		return "descent"
	return ""
