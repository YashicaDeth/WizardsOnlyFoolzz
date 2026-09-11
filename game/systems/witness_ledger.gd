class_name WitnessLedger
extends RefCounted

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
## How far a witness can be and still see it. Generous, because the failure mode
## that matters is a killing nobody reports, not one somebody implausibly saw.
const SIGHT_RANGE := 34.0

## Pending reports in flight. Runtime only: a report that has not landed is not
## knowledge, so persisting it would be persisting the wrong thing.
var pending: Array = []
var delivered := 0
var cut := 0


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
func record(event_type: String, details: Dictionary, witness_ids: Array) -> Dictionary:
	var full := details.duplicate()
	full["witnesses"] = witness_ids.duplicate()
	var event := WorldHistory.record_event(event_type, full)
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
			"details": details.duplicate(),
		})
	return event


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
	entries.append({
		"sequence": int(report["sequence"]),
		"type": str(report["type"]),
		"told_by": str(report["witness"]),
		"account": wire.distort("%s, as told by the one who walked back" % str(report["type"]).replace("_", " "), 1),
	})
	WorldHistory.register_subject(record_id, {"kind": "knowledge", "faction": faction, "entries": []})
	WorldHistory.update_subject(record_id, {"entries": entries}, "faction_learned")
	delivered += 1


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
