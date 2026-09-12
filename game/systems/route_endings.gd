class_name RouteEndings
extends RefCounted

## E7. "Run it far enough and Greg's endpoint applies: you turn into one, and
## the soul is signed over. That is a real ending state, not a stat... appeal
## far enough up the ladder and the game continues rather than ending, which
## makes Ascent the long route and Descent the fast one."
## — DESIGN/RITUAL_AND_KARMA.md
##
## `tree_alignment()` has existed since the dossier was built and nothing has
## ever asked it "have you actually finished the ladder." `check()` is that
## question, asked read-only against real, already-recorded karma — nothing
## here invents a new currency or a scripted branch.
##
## Deliberately partial, said here rather than left silent: this file can
## detect and permanently record which ending a subject reached (E7.3, done),
## but it stops at the write. The actual *consequence* of having signed away —
## a title card, a locked stat, dialogue that reads differently — is scene
## and UI work nobody has asked for yet, and enforcing "mercy no longer moves
## a demon back" would mean intercepting `_accumulate_karma()` inside
## world_history.gd, which is Codex's file; that needs an API request, not an
## edit made here. E7.1/E7.2 are therefore real but incomplete: the state is
## reached and written truthfully, and nothing downstream reads it yet.

const DEMON_THRESHOLD := -0.85
const ASCENDANT_THRESHOLD := 0.85
const ENDING_DEMON := "demon_signed"
const ENDING_ASCENDANT := "ascended_continue"


## Read-only until the threshold is actually crossed; from then on the write
## happens exactly once and every later call returns the same answer, because
## an ending recorded twice with a different alignment reading would quietly
## contradict its own history.
static func check(subject_id: String = "player") -> String:
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return ""
	if bool(subject.get("route_ending_recorded", false)):
		return str(subject.get("route_ending", ""))
	var alignment := WorldHistory.tree_alignment(subject)
	if alignment <= DEMON_THRESHOLD:
		return _record(subject_id, ENDING_DEMON, alignment)
	if alignment >= ASCENDANT_THRESHOLD:
		return _record(subject_id, ENDING_ASCENDANT, alignment)
	return ""


static func _record(subject_id: String, ending: String, alignment: float) -> String:
	WorldHistory.amend_subject(subject_id, {"route_ending_recorded": true, "route_ending": ending})
	WorldHistory.record_event("route_ending_reached", {"subject_id": subject_id, "ending": ending, "alignment": alignment})
	return ending


static func ending_of(subject_id: String = "player") -> String:
	return str(WorldHistory.subject(subject_id).get("route_ending", ""))
