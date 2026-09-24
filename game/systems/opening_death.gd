class_name OpeningDeath
extends RefCounted

## AX4.5. "Until the player's death fiction is authored, opening death uses an
## honest ordinary reload rather than a counterfeit immortality explanation."
##
## This file exists to hold a gap open.
##
## The player is "an experimental, repeatedly revived entity whose soul remains
## bound to Earth", so there is an obvious temptation: have them wake in the
## vat again, call it canon, and ship it. That would be a counterfeit. The
## direction doc names death and revival in the opening as "a focused design
## problem" and says ordinary reload "is the honest implementation rather than
## pretending the question is solved". Writing the fiction before it is
## decided is how a placeholder becomes permanent -- nobody revisits a question
## the game appears to have answered.
##
## So this reloads, says that it reloaded, and refuses to explain itself. The
## test enforces the refusal, which is the only part of this that is difficult
## to keep true over time.

## Flip this when the death fiction is actually authored, and only then. The
## suite will start requiring a real one, which is the point: the flag cannot
## be flipped quietly to unlock a shortcut.
const FICTION_AUTHORED := false

## Words that would be an answer to the question this file is keeping open.
## Not a blacklist for its own sake -- each one is a specific claim about what
## happens to the player when they die, and none of them has been decided.
const COUNTERFEITS := [
	"revived", "resurrect", "respawn", "clone", "backup", "reprint",
	"immortal", "reborn", "another body", "new vessel",
]


## What happens when the player dies during the facility escape. Returns a
## reload and nothing else. No event is recorded: a death that writes into the
## ledger is a death the world has taken a position on.
static func handle(cause: String = "") -> Dictionary:
	if FICTION_AUTHORED:
		# Deliberately not implemented. When somebody authors the fiction they
		# will land here, and they should -- this is where it goes, and the
		# failing suite next door tells them what it has to satisfy.
		return {"ok": false, "reason": "FICTION MARKED AUTHORED BUT NOT IMPLEMENTED"}
	return {
		"ok": true,
		"kind": "reload",
		"placeholder": true,
		"cause": cause,
		# Said plainly, because a placeholder that reads as finished is the
		# failure mode. This string is for a developer and a playtest note; the
		# player sees a reload, which explains nothing and claims nothing.
		"note": "Opening death is an ordinary reload. The death fiction is not authored yet and this is not it.",
	}


## Whether any text is quietly answering the question. Used by the suite
## against the payload and against the ledger.
static func counterfeits_in(text: String) -> Array:
	var found: Array = []
	var lowered := text.to_lower()
	for word in COUNTERFEITS:
		if lowered.contains(word):
			found.append(word)
	return found
