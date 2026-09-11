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
