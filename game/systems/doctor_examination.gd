class_name DoctorExamination
extends RefCounted

## AX1.1 / AX1.2 / AX2.1. The examination is the character creation.
##
## `DESIGN/PLAYER_DIRECTION_INTERVIEW_2026-09-18.md` is the authority here, and
## it is specific: the player is conscious in the vat while a senior visiting
## doctor studies them, a tube prevents speech, and the implanted brain
## interface exposes their answers to the examiner. So the questions are not a
## menu wrapped in fiction — the answers are taken out of the player's head
## whether or not they would have given them.
##
## The handler in `intake_direction.gd` is not this man. He is the clerk: he
## runs the form, he is bored, he has done four hundred of these. The doctor
## outranks him, is not from here, and is doing something else entirely —
## learning what the player is, in order to know how to take them apart.
##
## **What can be wrong is never the player's choice.** The direction doc draws
## that line hard: "the player's mechanical choices remain accurate. What can
## be wrong is the government's insulting or politically distorted diagnosis of
## those choices." So nothing here edits the sheet. The classification is a
## second, contradictory record kept alongside it, and the game never resolves
## which one the world believes.


## The institution's own word for what you said you were. Never the word you
## chose, and never quite an insult you could point at — that is the register.
const CLASSIFICATION := {
	"decanted": {"label": "ASSET, GROWN", "note": "no prior custody, no next of kin, no claim"},
	"born": {"label": "ASSET, RECOVERED", "note": "prior custody lapsed; claim not pursued"},
	"revived": {"label": "ASSET, RETURNED", "note": "third instance; earlier records sealed"},
	"grafted": {"label": "COMPOSITE", "note": "component origin mixed; treat as grown"},
	"unknown": {"label": "ASSET, UNFILED", "note": "origin declined; filed as grown"},
}

const DEFAULT_CLASSIFICATION := {"label": "ASSET, UNFILED", "note": "origin unreadable; filed as grown"}

## He is cruel and he is sympathetic, and the doc is clear those are the same
## man rather than two moods. The cruelty is in what he is doing; the sympathy
## is real and does not stop him. A line that is only sneering is the wrong
## line for him — it makes him a cartoon and the scene stops hurting.
const OBSERVATIONS := {
	"race": [
		{"line": "You chose that. Nobody chooses that. Interesting.", "hold": 3.0},
		{"line": "I'll write what you meant. The file will write something else.", "hold": 3.2},
	],
	"traits": [
		{"line": "That one costs you later. You don't know that yet.", "hold": 3.0},
		{"line": "I'd have picked it too, at your age, in your tank.", "hold": 3.2},
	],
	"body": [
		{"line": "You're building something you'd like to be. Noted, and kept.", "hold": 3.2},
		{"line": "Hold still. This part is for me, not for you.", "hold": 2.8},
	],
	"schedule": [
		{"line": "A real birth time. You'd be amazed how few of you have one.", "hold": 3.2},
		{"line": "The chart is not superstition here. That is the unkind part.", "hold": 3.4},
	],
	"declined": [
		{"line": "Declining is an answer. I have written it down as one.", "hold": 3.2},
		{"line": "Good. Refusal reads clearly on the instrument. Do it again.", "hold": 3.4},
	],
}

## AX2.1. What he says before he leaves, and the whole reason the examination
## is not a menu: he tells the player what it was for. He does not gloat. He
## explains, because explaining is worse.
## Held tight on purpose. The verdict is the longest stretch in the opening
## where the player cannot act, and it now has the examiner's walk to the door
## after it rather than the vat failing under him. At the old holds the two
## together ran the route to 26 seconds from one keypress, which
## `opening_handoff_test` is right to refuse. Same four sentences, less waiting
## between them.
## Greg, 25 September, in his own words: the first thing the examiner says,
## once his terminal is up. The last line turns the room's cameras on you.
const OPENING := [
	{"line": "Hello. Hey. You're going to do a psychology test for me.", "hold": 3.0},
	{"line": "You're going to tell me your birthday, and I'm going to find out everything I need to know. Everything we need to know.", "hold": 4.4},
	{"line": "Hurry up now. I'm being watched too.", "hold": 3.0, "cue": "watched"},
]
## The first time you think out loud (V). Greg: "because they have a brain chip".
const READS_THOUGHTS := {"line": "Hey. I can read your thoughts. Don't forget. We own you. Brain chip.", "hold": 3.8}

const VERDICT_CLOSE := [
	{"line": "That is the examination. Thank you — I mean that.", "hold": 2.6},
	{"line": "You have told me how you are put together.", "hold": 2.6},
	{"line": "Which means you have told me how to take you apart.", "hold": 3.0},
	{"line": "Someone will be along. It will not be me.", "hold": 2.8},
	# Greg, 25 September: once he has what he needs, he says so and goes.
	{"line": "Okay. Great. We can break you now.", "hold": 2.4},
]

## He records it without asking. The notice is on screen for the player, not
## for him — he has never once looked at it.
const CONSENT_NOTICE := "RECORDING — EXAMINATION — CONSENT NOT REQUIRED"


## The institution's verdict on an origin the player chose freely. Returns the
## contradicting record, never a correction: `chosen` is preserved verbatim so
## the two can be shown side by side, which is the whole point of the beat.
static func classify(sheet) -> Dictionary:
	var chosen := "unknown"
	if sheet != null and "race" in sheet:
		chosen = str(sheet.race).to_lower()
	var filed: Dictionary = CLASSIFICATION.get(chosen, DEFAULT_CLASSIFICATION)
	return {
		"chosen": chosen.to_upper(),
		"label": str(filed.get("label", "ASSET, UNFILED")),
		"note": str(filed.get("note", "")),
		"agrees": false,
	}


## One interjection, chosen by which page of the examination the player is on.
## `moment` indexes the pool the same way `IntakeDirection.line_for` does, so a
## second visit to a page does not replay the first line.
static func observe(context: String, moment: int) -> Dictionary:
	var pool: Array = OBSERVATIONS.get(context, [])
	if pool.is_empty():
		return {}
	return pool[abs(moment) % pool.size()]


## AX2.1's closing beats, with the player's own answers folded in — the threat
## only lands because it is specific. A generic "we know how to break you" is
## a villain line; naming the trait they picked eight minutes ago is not.
static func verdict(sheet) -> Array:
	var beats: Array = []
	var named := ""
	if sheet != null and "traits" in sheet and not sheet.traits.is_empty():
		named = str(sheet.traits[0]).replace("_", " ")
	for beat in VERDICT_CLOSE:
		beats.append({"line": str(beat.line), "hold": float(beat.hold)})
	if named != "":
		beats.insert(2, {
			"line": "The %s, particularly. That was generous of you." % named,
			"hold": 3.4,
		})
	return beats


## AX2.6. If an exceptionally skilled player reaches him and kills him, that
## has to stay killed.
##
## The direction doc is unusually firm here: "An apparent doctor kill remains a
## real victory; later medical reconstruction can return him later with his
## memory and scars intact. The victory remains true and begins a personal
## rivalry; resurrection is not a cutscene retcon."
##
## So reconstruction is not undo. The record of the kill survives it, the scars
## are derived from how it was done, and he remembers. What the player took
## from him is permanent; what comes back is a man with a grudge and a repaired
## body, not a reset.
const FATE_SUBJECT := "the_visiting_doctor"

## What a method leaves on a man who is put back together afterwards.
const SCARS := {
	"blunt": "jaw rebuilt; the left side of his face does not move with the right",
	"ballistic": "entry and exit through the chest, both closed badly on purpose",
	"blade": "throat, reopened and stitched by somebody competent and unkind",
	"burn": "grafted from shoulder to ear; the graft did not take his colour",
	"fall": "spine pinned; he stands straighter than he used to and it costs him",
}
const DEFAULT_SCAR := "repaired without a note on the file, which is its own answer"


## Records a kill as having happened. Nothing here is provisional -- there is
## no "apparent" flag, because the doc says the victory is true.
static func record_kill(method: String, killed_by: String = "player") -> Dictionary:
	var record := {
		"killed": true,
		"killed_by": killed_by,
		"method": method,
		"scar": str(SCARS.get(method, DEFAULT_SCAR)),
		"reconstructed": false,
		"remembers": true,
	}
	WorldHistory.register_subject(FATE_SUBJECT, record)
	return record


## Brings him back, and cannot erase anything. `killed` stays true forever:
## reconstruction adds to the record, it never rewrites it. If this function
## ever clears that flag, an arbitrary cutscene has taken a win off the player,
## which is the exact thing the doc forbids.
static func reconstruct() -> Dictionary:
	var record: Dictionary = WorldHistory.subject(FATE_SUBJECT)
	if record.is_empty() or not bool(record.get("killed", false)):
		return {"ok": false, "reason": "HE WAS NEVER KILLED"}
	if bool(record.get("reconstructed", false)):
		return {"ok": false, "reason": "ALREADY BACK"}
	var returned := record.duplicate(true)
	returned["reconstructed"] = true
	returned["killed"] = true
	returned["remembers"] = true
	returned["rivalry"] = true
	WorldHistory.update_subject(FATE_SUBJECT, returned, "doctor_reconstructed")
	return {"ok": true, "scar": str(returned.get("scar", "")), "remembers": true, "killed": true}


## Whether the player has ever killed him, which stays true after he is back.
static func was_killed() -> bool:
	return bool(WorldHistory.subject(FATE_SUBJECT).get("killed", false))


## AX2.5. "Reaching the departing doctor is an urgent optional pursuit, not a
## forced objective."
##
## Both halves of that are load-bearing and they pull against each other.
## Urgent means a window that closes and a player who feels it closing.
## Optional means the game does not notice when it shuts -- no failed
## objective, no consolation line, no marker greying out. A game that tells
## you that you missed something has made it mandatory and then punished you
## for it, which is worse than not offering it.
##
## So the contract is: the window is real, missing it is silent, and catching
## him is the exception rather than the intended path. The test asserts the
## silence as hard as it asserts the window.

## He starts leaving at the end of the verdict, while the player is still in
## the vat. The window is the walk between the examination room and wherever
## his vehicle is, and it is short because the next torture cycle is not.
const DEPARTURE_WINDOW_MINUTES := 6.0
const DEPARTURE_SUBJECT := "doctor_departure"


## Called when the verdict finishes. He does not wait to see what happens next
## -- the doc is explicit that he begins to leave before the next cycle.
static func begin_departure() -> Dictionary:
	var at := WorldClock.minutes()
	var record := {"left_at_minute": at, "closes_at_minute": at + DEPARTURE_WINDOW_MINUTES, "caught": false}
	WorldHistory.register_subject(DEPARTURE_SUBJECT, record)
	return record


## Whether he can still be reached. Returns false once for every reason --
## never departed, window shut, already caught -- because the caller must not
## be able to tell the difference and neither must the player.
static func reachable() -> bool:
	var record: Dictionary = WorldHistory.subject(DEPARTURE_SUBJECT)
	if record.is_empty() or bool(record.get("caught", false)):
		return false
	return WorldClock.minutes() <= float(record.get("closes_at_minute", -1.0))


## How much of the window is left, 1.0 to 0.0. For a diegetic pressure cue --
## a door closing, an engine starting -- and never for a countdown UI, because
## a timer on screen is the game admitting this is an objective.
static func urgency() -> float:
	var record: Dictionary = WorldHistory.subject(DEPARTURE_SUBJECT)
	if record.is_empty() or not reachable():
		return 0.0
	var left := float(record.get("closes_at_minute", 0.0)) - WorldClock.minutes()
	return clampf(left / DEPARTURE_WINDOW_MINUTES, 0.0, 1.0)


## The player got to him. Not a scripted scene -- it records that the meeting
## happened and hands back the fact, so the encounter itself belongs to
## whatever room they caught him in.
static func catch_up() -> Dictionary:
	if not reachable():
		return {"ok": false, "reason": "HE IS GONE"}
	var record: Dictionary = WorldHistory.subject(DEPARTURE_SUBJECT).duplicate(true)
	record["caught"] = true
	record["caught_at_minute"] = WorldClock.minutes()
	WorldHistory.update_subject(DEPARTURE_SUBJECT, record, "doctor_caught")
	return {"ok": true, "caught": true}


## Deliberately not a function: there is no `missed()`, no failure event and
## nothing that fires when the window shuts. If a later pass adds one, it has
## made an optional pursuit into a mandatory one the player has already lost.
static func was_caught() -> bool:
	return bool(WorldHistory.subject(DEPARTURE_SUBJECT).get("caught", false))
