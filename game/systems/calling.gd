class_name Calling
extends RefCounted

## Calling and summoning people (Greg, 24 September, DESIGN/ESCAPE_ROUTES.md):
## the doctor's hologram gives the player "a cybernetic to call people which
## then opens up in the brain index calling and summoning or trying to summon
## different npcs like inviting npcs in the sims on the phone".
##
## This is the half that is not a screen. The Brain Index reads `contacts()`
## and calls `invite()`; nothing here draws. The emitter that projected the
## doctor is the implant (an assistant proposal in ESCAPE_ROUTES.md, not a
## decision), and without it installed nothing can be called.
##
## Who picks up is decided from the record, never at random: the dead do not
## answer, people who hate you refuse, people who owe or like you come. Every
## call, answered or not, is written down.
##
## OPEN (Greg): who can be called first and what a refusal says. Every line in
## LINES is placeholder and says so in the result (`placeholder: true`).

const ImplantCatalog := preload("res://systems/implant_catalog.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

const SUBJECT := "calling"
const IMPLANT_ID := "hologram call emitter"
## Full hardware record, supplied rather than added to `implant_catalog.gd`'s
## table (another lane's file): `ImplantCatalog.resolve()` merges whatever is
## supplied over its salvage default, so this resolves the same everywhere.
const IMPLANT := {
	"id": IMPLANT_ID, "name": IMPLANT_ID, "zone": "head", "profile": "call_emitter",
	"armor": 0.02, "max_condition": 50.0, "tint": "5fd6e8",
}

const ACCEPTED := "accepted"
const REFUSED := "refused"
const NO_ANSWER := "no_answer"

const INVITE := "invite"
const SUMMON := "summon"

## A refusal is remembered: the same person does not pick up again for this
## many world minutes.
const SCREENED_MINUTES := 120.0
const CALL_LOG_LIMIT := 24

## PLACEHOLDER lines, one per reason. Greg decides the real ones.
const LINES := {
	"dead": "The line opens onto nothing. Nobody is there to pick up.",
	"doctor": "\"Not now. If you want to talk, come up to the roof.\"",
	"hostile": "\"You have the nerve to call me?\" The line goes dead.",
	"screened": "It rings out. They saw it was you.",
	"summon_refused": "\"I don't come because you whistle.\"",
	"summoned": "\"Fine. Tell me where.\"",
	"invited": "\"Yeah. I'll come by.\"",
	"unknown": "It rings out. They do not know this number.",
}


## Whether the emitter is in the player's head.
static func unlocked(subject_id: String = "player") -> bool:
	for implant in ImplantCatalog.list(_cybernetics(subject_id)):
		if str(implant.get("id", "")) == IMPLANT_ID:
			return true
	return false


## The emitter goes in the same way the wetwire chip does
## (`BrainIndex.install_chip`): onto the cybernetics list the body panels
## already read, anatomy_state for a live body, the intake anatomy before one.
static func install_emitter(source: String = "doctor_vehicle_bay", subject_id: String = "player") -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	if unlocked(subject_id):
		return {"ok": false, "reason": "ALREADY INSTALLED"}
	var has_live_anatomy := subject.get("anatomy_state") is Dictionary
	var anatomy: Dictionary = (subject.get("anatomy_state", {}) if has_live_anatomy else subject.get("anatomy", {})).duplicate(true)
	var installed: Array = (anatomy.get("cybernetics", []) as Array).duplicate(true)
	installed.append(ImplantCatalog.resolve(IMPLANT.duplicate(true)))
	anatomy["cybernetics"] = installed
	WorldHistory.begin_ledger_batch()
	var changes := {"call_emitter": {"source": source, "installed_at_minute": WorldClock.minutes()}}
	changes["anatomy_state" if has_live_anatomy else "anatomy"] = anatomy
	WorldHistory.amend_subject(subject_id, changes)
	ensure()
	PLAYER_ACTION_LEDGER.record("call_implant_installed", {"subject_id": subject_id, "implant": IMPLANT_ID, "source": source})
	WorldHistory.commit_ledger_batch()
	return {"ok": true, "implant": IMPLANT_ID}


static func ensure() -> Dictionary:
	var record := WorldHistory.subject(SUBJECT)
	if record.is_empty():
		record = WorldHistory.register_subject(SUBJECT, {"kind": "call_log", "name": "CALLS", "calls": []})
	return record


## People the world knows the player has met, as rows for a list. A person is
## a contact when any record ties them to the player: a relationship either way,
## the `met` flag NPCRelationship sets, `met_player`, or an event that names
## them. Hearsay (a subject registered with no link to the player) is not.
static func contacts(subject_id: String = "player") -> Array[Dictionary]:
	var named := _named_in_events()
	var player_relations: Dictionary = WorldHistory.subject(subject_id).get("relations", {})
	var rows: Array[Dictionary] = []
	var all := WorldHistory.all_subjects()
	var ids: Array = all.keys()
	ids.sort()
	for id in ids:
		var person: Dictionary = all[id]
		if str(id) == subject_id or str(person.get("kind", "")) != "person":
			continue
		var met := bool(person.get("met_player", false)) or player_relations.has(id) \
			or (person.get("relations", {}) as Dictionary).has(subject_id) \
			or bool(NPCRelationship.state(str(id), subject_id).get("met", false)) or named.has(str(id))
		if not met:
			continue
		rows.append({
			"id": str(id),
			"name": str(person.get("name", str(id).replace("_", " "))).to_upper(),
			"role": str(person.get("role", "")),
			"faction": str(person.get("faction", "")),
			"status": str(person.get("status", "")),
			"disposition": NPCRelationship.disposition(str(id), subject_id),
		})
	return rows


static func is_contact(contact_id: String) -> bool:
	for row in contacts():
		if str(row.id) == contact_id:
			return true
	return false


## Ring someone. `mode` is INVITE (come over) or SUMMON (come now, on my word),
## which only companions, the frightened and the deeply bonded obey. Returns
## {ok, outcome, reason, line, placeholder}; `ok` is false only when no call
## was placed at all (no implant, not a contact).
static func invite(contact_id: String, mode: String = INVITE) -> Dictionary:
	if not unlocked():
		return {"ok": false, "reason": "NO CALL IMPLANT"}
	if not is_contact(contact_id):
		return {"ok": false, "reason": "NOT A CONTACT"}
	var verdict := _answer(contact_id, mode)
	var call := {
		"contact_id": contact_id, "mode": mode,
		"outcome": str(verdict.outcome), "reason": str(verdict.reason),
		"minute": WorldClock.minutes(),
	}
	WorldHistory.begin_ledger_batch()
	var calls: Array = (ensure().get("calls", []) as Array).duplicate(true)
	calls.append(call)
	while calls.size() > CALL_LOG_LIMIT:
		calls.pop_front()
	WorldHistory.amend_subject(SUBJECT, {"calls": calls})
	if str(verdict.outcome) == ACCEPTED:
		WorldHistory.amend_subject(contact_id, {"called_by_player": mode, "called_at_minute": WorldClock.minutes()})
	PLAYER_ACTION_LEDGER.record("npc_called", {
		"subject_id": "player", "contact_id": contact_id, "mode": mode,
		"outcome": str(verdict.outcome), "reason": str(verdict.reason),
	})
	WorldHistory.commit_ledger_batch()
	return {
		"ok": true, "outcome": str(verdict.outcome), "reason": str(verdict.reason),
		"line": str(LINES.get(verdict.reason, "")), "placeholder": true,
	}


static func summon(contact_id: String) -> Dictionary:
	return invite(contact_id, SUMMON)


static func calls() -> Array:
	return (ensure().get("calls", []) as Array).duplicate(true)


static func _answer(contact_id: String, mode: String) -> Dictionary:
	var person := WorldHistory.subject(contact_id)
	var status := str(person.get("status", "")).to_lower()
	if status.contains("dead") or status.contains("killed") or (bool(person.get("killed", false)) and not bool(person.get("reconstructed", false))):
		return {"outcome": NO_ANSWER, "reason": "dead"}
	if contact_id == DoctorExamination.FATE_SUBJECT:
		return {"outcome": REFUSED, "reason": "doctor"}
	if _screened(contact_id):
		return {"outcome": NO_ANSWER, "reason": "screened"}
	var disposition := NPCRelationship.disposition(contact_id)
	# Either side's grudge is enough to refuse; either side's bond to come.
	var theirs := WorldHistory.relationship_strength(contact_id, "player")
	var yours := WorldHistory.relationship_strength("player", contact_id)
	var strength := maxi(theirs, yours)
	if disposition == "hostile" or mini(theirs, yours) <= -20 or int(person.get("grudge", 0)) >= 30:
		return {"outcome": REFUSED, "reason": "hostile"}
	if mode == SUMMON:
		if disposition in ["companion", "cowed"] or strength >= 30:
			return {"outcome": ACCEPTED, "reason": "summoned"}
		return {"outcome": REFUSED, "reason": "summon_refused"}
	if disposition in ["companion", "friendly", "cowed"] or strength >= 10:
		return {"outcome": ACCEPTED, "reason": "invited"}
	return {"outcome": NO_ANSWER, "reason": "unknown"}


static func _screened(contact_id: String) -> bool:
	var now := WorldClock.minutes()
	for call in ensure().get("calls", []):
		if str(call.get("contact_id", "")) == contact_id and str(call.get("outcome", "")) == REFUSED \
				and now - float(call.get("minute", -9999.0)) < SCREENED_MINUTES:
			return true
	return false


static func _cybernetics(subject_id: String) -> Array:
	var subject := WorldHistory.subject(subject_id)
	var anatomy: Dictionary = subject.get("anatomy_state", {}) if subject.get("anatomy_state") is Dictionary else subject.get("anatomy", {})
	return anatomy.get("cybernetics", [])


## Everyone one of the player's own acts has named: the guard you coerced is
## someone you have met, whether or not a relationship record was ever opened
## on him. Only PlayerActionLedger receipts count (they carry an action id);
## the world updating somebody's record is not the player meeting them.
static func _named_in_events() -> Dictionary:
	var named := {}
	for event in WorldHistory.events:
		var details: Dictionary = event.get("details", {})
		if not details.has("action_id"):
			continue
		for key in ["subject_id", "npc", "from", "target", "killed_by", "contact_id", "about"]:
			if details.has(key):
				named[str(details[key])] = true
	return named
