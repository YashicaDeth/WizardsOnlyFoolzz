class_name WitnessLedger
extends RefCounted

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## Who saw it, whether they lived to say so, and what the world ended up
## believing as a result.
##
## F1, and `DESIGN/HUNT_SYSTEM.md` puts it first for a reason: *"Events already
## record participants; they must also record witnesses. An act with no
## surviving witness does not enter faction knowledge."* Everything else in the
## Hunt System is downstream — grudges travelling along relation edges (F2),
## promotion into vacancies (F3), rivals generated from real events (F4) — and
## none of it can be built on an event log that every faction can already read.
##
## The distinction this draws is the whole thing. There are now **two** records:
##
## - **What happened.** `WorldHistory.events`. Complete, ordered, true. It is
##   the game's memory, not anybody's.
## - **What is known.** Per faction, and always a subset, always later, and
##   often wrong. This is what NPCs act on.
##
## Which produces the mechanic Mordor has no equivalent for and which Greg's
## nemesis notes kept circling: **you can cut the transmission.** A witness who
## dies before they report takes the event with them. The world still remembers
## — bodies remember, that is a pillar — but no faction ever learns.

## Seconds a witness takes to get word home. Not instant: the gap between the
## act and the report is the window F1.3 exists inside.
const REPORT_DELAY := 24.0
## F2. How far a story travels along the relation graph before nobody repeats
## it. Three hops is enough for "a friend of a friend heard" and short enough
## that the whole cast does not learn everything.
const MAX_HOPS := 3
## What crossing one edge costs, before the edge's own strength is applied. A
## close ally passes it on nearly intact; an acquaintance barely bothers.
const HOP_DECAY := 0.62
## Below this the story stops being worth telling and simply stops.
const FAINTEST := 0.12
## The Wire arrives first and arrives worst: no delay, wider than any friendship
## graph, and distorted past the end of the hop ladder.
const WIRE_FORCE := 0.45
## How far a witness can be and still see it. Generous, because the failure mode
## that matters is a killing nobody reports, not one somebody implausibly saw.
const SIGHT_RANGE := 34.0
## AE10.10. Buying testimony uses the one currency the world already has. The
## price is per account, not per witness, so somebody carrying three separate
## wrongs is materially harder to buy than somebody carrying one.
const REPORT_PRICE := 12
## Below this the body's own perception is already visibly breaking down (the
## Hunt drives its full-screen altered-perception treatment from the same
## consciousness value). Testimony can invert the one binary resolution this
## witness actually had to distinguish; there is no hidden random falsehood.
const CLEAR_TESTIMONY_AT := 45.0

## Pending reports in flight. Runtime only: a report that has not landed is not
## knowledge, so persisting it would be persisting the wrong thing.
var pending: Array = []
var delivered := 0
var cut := 0
var bought := 0


## Who was close enough to see it. `candidates` is [{id, at, alive}] so the
## caller decides what counts as present — the hunt has actors, the derby has
## drivers, and neither should have to look like the other.
static func witnesses_of(at: Vector3, candidates: Array, exclude: String = "") -> Array:
	var seen: Array = []
	for candidate in candidates:
		var subject_id := str((candidate as Dictionary).get("id", ""))
		if subject_id == "" or subject_id == exclude:
			continue
		if not bool((candidate as Dictionary).get("alive", true)):
			continue
		var position: Vector3 = (candidate as Dictionary).get("at", Vector3.ZERO)
		if position.distance_to(at) <= SIGHT_RANGE:
			seen.append(subject_id)
	return seen


## F1.1. Records the act, and separately puts a report in flight for each
## witness. The event is true the moment it happens; the knowledge is not.
func record(event_type: String, details: Dictionary, witness_ids: Array, as_player_action: bool = false) -> Dictionary:
	var full := details.duplicate()
	full["witnesses"] = witness_ids.duplicate()
	# Most callers describe world acts. A caller that owns an explicit player
	# verb may opt into the shared receipt route without rebuilding testimony.
	var event := PLAYER_ACTION_LEDGER.record(event_type, full) if as_player_action else WorldHistory.record_event(event_type, full)
	for witness_id in witness_ids:
		var subject: Dictionary = WorldHistory.subject(str(witness_id))
		var faction := str(subject.get("faction_id", ""))
		if faction == "":
			# Someone with no faction still carries it personally, which is what
			# makes an unaffiliated drifter worth killing or worth keeping.
			faction = "unaffiliated"
		pending.append({
			"sequence": int(event.get("sequence", 0)),
			"type": event_type,
			"witness": str(witness_id),
			"faction": faction,
			"remaining": REPORT_DELAY,
			"details": _testimony_details(event_type, details, subject),
		})
	return event


## What the body can honestly carry home. WorldHistory keeps `details`
## unchanged above; only this witness's account is affected. Restrict the
## mistake to the authored opposite outcomes instead of mutating arbitrary
## fields or inventing a random suspect the witness never saw.
static func _testimony_details(event_type: String, details: Dictionary, witness: Dictionary) -> Dictionary:
	var testimony := details.duplicate(true)
	if event_type != "npc_resolution":
		return testimony
	var anatomy: Dictionary = witness.get("anatomy_state", {}) if witness.get("anatomy_state", {}) is Dictionary else {}
	if anatomy.is_empty() and witness.get("anatomy", {}) is Dictionary:
		anatomy = witness.get("anatomy", {}) as Dictionary
	if float(anatomy.get("consciousness", 100.0)) >= CLEAR_TESTIMONY_AT:
		return testimony
	match str(testimony.get("outcome", "")):
		"execute": testimony["outcome"] = "spare"
		"spare": testimony["outcome"] = "execute"
	return testimony


## F1.2. Time passes and reports land. Returns the reports that arrived this
## tick so a caller can react — a faction learning something is an event in
## itself, not a silent table write.
func tick(delta: float) -> Array:
	var landed: Array = []
	var survivors: Array = []
	for report in pending:
		report["remaining"] = float(report["remaining"]) - delta
		if float(report["remaining"]) > 0.0:
			survivors.append(report)
			continue
		_deliver(report)
		landed.append(report)
	pending = survivors
	return landed


func _deliver(report: Dictionary) -> void:
	var faction := str(report["faction"])
	var record_id := "knowledge:%s" % faction
	var known: Dictionary = WorldHistory.subject(record_id)
	var entries: Array = known.get("entries", [])
	# What arrives is the witness's account, not the event. One retelling of
	# distortion at the point of report; `DESIGN/HUNT_SYSTEM.md` adds more per
	# hop when F2 propagates it onward from here.
	var wire := WireNet.new(WireNet.SIGNAL_SURFACE)
	var testimony: Dictionary = (report.get("details", {}) as Dictionary).duplicate(true)
	var account_subject := str(report["type"]).replace("_", " ")
	if not str(testimony.get("outcome", "")).is_empty():
		account_subject += ": %s" % str(testimony.outcome)
	entries.append({
		"sequence": int(report["sequence"]),
		"type": str(report["type"]),
		"told_by": str(report["witness"]),
		"account": wire.distort("%s, as told by the one who walked back" % account_subject, 1),
		"testimony": testimony,
	})
	WorldHistory.update_subject(record_id, {
		"kind": "knowledge",
		"faction": faction,
		"entries": entries,
	}, "faction_learned")
	delivered += 1
	# F2. Getting home is not the end of it. The witness tells the people they
	# actually know, and it travels from there until nobody repeats it.
	propagate(str(report["witness"]), {
		"sequence": int(report["sequence"]),
		"type": str(report["type"]),
		"details": (report.get("details", {}) as Dictionary),
	})


## F1.3. The witness does not make it back. Every report they were carrying dies
## with them — and this is the whole reason the delay exists.
func silence(subject_id: String) -> int:
	var survivors: Array = []
	var lost := 0
	for report in pending:
		if str(report["witness"]) == subject_id:
			lost += 1
			continue
		survivors.append(report)
	pending = survivors
	cut += lost
	if lost > 0:
		WorldHistory.record_event("report_cut", {"subject": subject_id, "reports": lost})
	return lost


func reports_carried_by(subject_id: String) -> int:
	return pending.filter(func(report: Dictionary): return str(report.get("witness", "")) == subject_id).size()


## AE10.10. Pay the person who is physically carrying the account before it
## lands. This is neither murder nor retroactive deletion from faction
## knowledge: only pending reports can be bought. Inventory, witness memory,
## removed testimony and the action receipt settle in one nested ledger batch.
func buy(subject_id: String, buyer_id: String = "player") -> Dictionary:
	var carried: Array = pending.filter(func(report: Dictionary): return str(report.get("witness", "")) == subject_id)
	if carried.is_empty():
		return {"ok": false, "reason": "THEY ARE CARRYING NO REPORT"}
	var inventory := WorldHistory.subject("inventory")
	var price := carried.size() * REPORT_PRICE
	var wallet := int(inventory.get("rust_scrip", 0))
	if wallet < price:
		return {"ok": false, "reason": "NEED %d RUST SCRIP" % price, "price": price, "wallet": wallet}
	var sequences: Array = carried.map(func(report: Dictionary): return int(report.get("sequence", -1)))
	WorldHistory.begin_ledger_batch()
	pending = pending.filter(func(report: Dictionary): return str(report.get("witness", "")) != subject_id)
	bought += carried.size()
	WorldHistory.amend_subject("inventory", {"rust_scrip": wallet - price})
	var witness := WorldHistory.subject(subject_id)
	WorldHistory.amend_subject(subject_id, {
		"bribes_taken": int(witness.get("bribes_taken", 0)) + price,
		"memory": "Took rust scrip to bury %d pending account%s." % [carried.size(), "" if carried.size() == 1 else "s"],
	})
	var details := {
		"actor": buyer_id, "subject_id": subject_id, "reports": carried.size(),
		"source_sequences": sequences, "price": price, "currency": "rust_scrip",
	}
	var event: Dictionary
	if buyer_id == "player":
		event = PLAYER_ACTION_LEDGER.record("report_bought", details)
	else:
		event = WorldHistory.record_event("report_bought", details)
	WorldHistory.commit_ledger_batch()
	return {
		"ok": true, "reports": carried.size(), "price": price,
		"wallet": wallet - price, "source_sequences": sequences,
		"action_id": str((event.get("details", {}) as Dictionary).get("action_id", "")),
	}


# --- F2: grudges travel real edges -----------------------------------------

## What the act is worth as a wrong. Read straight off E1.1's karma table, so
## the thing the world holds against you is the same thing that moved you down
## the Tree — one definition of harm, not two that can drift apart.
static func harm_of(event: Dictionary) -> float:
	return maxf(0.0, -WorldHistory.event_karma(event))


static func account_of(event: Dictionary) -> String:
	return "%s, as told by the one who walked back" % str(event.get("type", "something")).replace("_", " ")


## The story, and the grudge it carries, moving outward from whoever first knew
## it — along the relation edges the index already draws, and nowhere else.
## Distance is real: every hop costs force, a weak edge costs more, and under
## `FAINTEST` it is not repeated at all. Nobody hears it twice.
func propagate(seed_id: String, event: Dictionary, force: float = 1.0) -> Array:
	var reached: Array = []
	var seen := {seed_id: true}
	var frontier: Array = [{"id": seed_id, "force": force, "hops": 0}]
	var wire := WireNet.new(WireNet.SIGNAL_SURFACE)
	while not frontier.is_empty():
		var node: Dictionary = frontier.pop_front()
		if int(node.hops) >= MAX_HOPS:
			continue
		var relations: Dictionary = WorldHistory.subject(str(node.id)).get("relations", {})
		for other_id in relations:
			if seen.has(str(other_id)):
				continue
			var edge: Dictionary = relations[other_id]
			var closeness := clampf(float(edge.get("strength", 0)) / 100.0, 0.15, 1.0)
			var carried := float(node.force) * HOP_DECAY * closeness
			if carried < FAINTEST:
				continue
			seen[str(other_id)] = true
			var hops := int(node.hops) + 1
			# F2.3. Each retelling is a retelling, so it is distorted again.
			var told := wire.distort(account_of(event), hops)
			_take_it_personally(str(other_id), event, told, carried, hops)
			reached.append({"id": str(other_id), "force": snappedf(carried, 0.01), "hops": hops, "account": told})
			frontier.append({"id": str(other_id), "force": carried, "hops": hops})
	return reached


## F2.4. The Wire gets there first and gets it worst: no walking time, no need
## to know anybody, and distorted past the end of the hop ladder. It reaches
## further than friendship does and is believed less, which is the trade.
func broadcast(event: Dictionary, audience: Array, reach: float = 1.0) -> Array:
	var wire := WireNet.new(WireNet.SIGNAL_SURFACE)
	var told := wire.distort(account_of(event), MAX_HOPS + 1)
	var carried := clampf(reach, 0.0, 1.0) * WIRE_FORCE
	var reached: Array = []
	for listener_id in audience:
		var id := str(listener_id)
		if id == "" or id == str((event.get("details", {}) as Dictionary).get("subject_id", "")):
			continue
		_take_it_personally(id, event, told, carried, MAX_HOPS + 1)
		reached.append({"id": id, "force": snappedf(carried, 0.01), "hops": MAX_HOPS + 1, "account": told})
	return reached


## Hearing about it changes what somebody believes and, if they were close to
## whoever it happened to, how they feel about the person who did it. That
## second part is the whole of F2: a grudge is not assigned, it is inherited
## across an edge that already existed, in proportion to how real the edge is.
func _take_it_personally(subject_id: String, event: Dictionary, told: String, force: float, hops: int) -> void:
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return
	var heard: Array = (subject.get("heard", []) as Array).duplicate()
	heard.append({
		"sequence": int(event.get("sequence", 0)),
		"type": str(event.get("type", "")),
		"account": told,
		"hops": hops,
	})
	while heard.size() > 12:
		heard.pop_front()
	var changes := {"heard": heard}
	var details: Dictionary = event.get("details", {})
	var victim := str(details.get("subject_id", ""))
	var harm := harm_of(event)
	if harm > 0.0 and victim != "" and victim != subject_id:
		var closeness := clampf(float(WorldHistory.relationship_strength(subject_id, victim)) / 100.0, 0.0, 1.0)
		if closeness > 0.0:
			var taken := roundi(harm * force * closeness * 220.0)
			if taken > 0:
				changes["grudge"] = mini(100, int(subject.get("grudge", 0)) + taken)
	WorldHistory.amend_subject(subject_id, changes)


## Does this faction believe anything about that event? The question NPC
## behaviour should ask instead of reading the event log directly.
func faction_knows(faction_id: String, sequence: int) -> bool:
	var known: Dictionary = WorldHistory.subject("knowledge:%s" % faction_id)
	for entry in known.get("entries", []):
		if int((entry as Dictionary).get("sequence", -1)) == sequence:
			return true
	return false


func knowledge(faction_id: String) -> Array:
	return WorldHistory.subject("knowledge:%s" % faction_id).get("entries", [])


## Reports still in the air, for the interface to show. A player who has just
## done something in front of three people should be able to find out that three
## accounts of it are currently walking somewhere.
func in_flight() -> Array:
	return pending.duplicate(true)
