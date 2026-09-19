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
const VERDICT_CLOSE := [
	{"line": "That is the examination. Thank you — I mean that.", "hold": 3.0},
	{"line": "You have told me how you are put together.", "hold": 3.0},
	{"line": "Which means you have told me how to take you apart.", "hold": 3.6},
	{"line": "Someone will be along. It will not be me.", "hold": 3.2},
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
