class_name PlayerFaction
extends RefCounted

## U. "How you can persuade them to join your ranks - your own faction that
## you start through progressing and exploring around the map... E is the two
## ladders that already exist. This is the third one, which is yours."
##
## Deliberately not a `FACTION_TREE_AXIS` entry (that const lives in
## world_history.gd, Codex's file, and is an authored table for the seven
## Sins plus the two poles — the player's own faction is emergent, not
## authored). `standing()` computes the real average `tree_alignment()` of
## whoever has actually joined instead, which is the more honest answer for
## a faction that did not exist until the player built it: it starts wherever
## its first members already stood, and moves as the roster changes, on the
## same axis (E) rather than a fourth invented one.
const FACTION_ID := "player_faction"


## U1.1. "Found something — a name, a mark, a first member." The player is
## the first member, holding CROWN the same way any faction's founder would,
## on the exact same rank machinery `wire_net.gd`'s pyramid already runs for
## the seven Sins and wizardsonlyfoolz — never a second rank system for the
## player's own faction either.
static func found(faction_name: String, mark: String = "", player_id: String = "player") -> Dictionary:
	if not WorldHistory.subject(FACTION_ID).is_empty():
		return {"ok": false, "reason": "A FACTION HAS ALREADY BEEN FOUNDED"}
	var player := WorldHistory.subject(player_id)
	if player.is_empty():
		return {"ok": false, "reason": "NO SUCH FOUNDER"}
	WorldHistory.register_subject(FACTION_ID, {
		"name": faction_name, "kind": "faction", "role": "Founded, not born",
		"mark": mark, "threat": "UNKNOWN", "territory": "Wherever the founder has actually been",
		"doctrine": "Not written yet. It is whatever its members actually do.",
		"relations": {player_id: {"kind": "command", "strength": 50}},
	})
	WorldHistory.update_subject(player_id, {
		"faction_id": FACTION_ID, "faction": faction_name, "faction_rank": "CROWN",
	}, "faction_founded")
	return {"ok": true, "faction_id": FACTION_ID}


## U1.2. "Recruits from the clinch and the downed window belong to it." One
## call, meant to be made from wherever a recruit resolution actually
## happens (Codex's F5/F6 territory) — an API offered rather than wired in,
## same relationship this file has to combat as `ritual_app.gd` has to the
## camera that would take its photographs.
static func recruit(subject_id: String) -> Dictionary:
	var faction := WorldHistory.subject(FACTION_ID)
	if faction.is_empty():
		return {"ok": false, "reason": "NOTHING HAS BEEN FOUNDED YET"}
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	if str(subject.get("faction_id", "")) == FACTION_ID:
		return {"ok": false, "reason": "ALREADY ONE OF YOURS"}
	WorldHistory.update_subject(subject_id, {
		"faction_id": FACTION_ID, "faction": str(faction.get("name", FACTION_ID)),
	}, "recruited_to_own_faction")
	return {"ok": true, "subject_id": subject_id}


## U1.4. "It can be attacked, and it can lose people." Losing someone is a
## real, permanent departure from the roster — recorded distinctly from a
## generic status change so the Board and the pyramid both read it as what
## it was (killed vs. walked away), not as an unexplained disappearance.
static func lose_member(subject_id: String, reason: String) -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty() or str(subject.get("faction_id", "")) != FACTION_ID:
		return {"ok": false, "reason": "NOT ONE OF YOURS"}
	WorldHistory.update_subject(subject_id, {"faction_id": "", "faction": "Unbound"}, "left_own_faction")
	WorldHistory.record_event("own_faction_lost_member", {"subject_id": subject_id, "reason": reason})
	return {"ok": true, "subject_id": subject_id, "reason": reason}


static func members() -> Array[String]:
	var out: Array[String] = []
	for subject_id in WorldHistory.all_subjects():
		if str(WorldHistory.subject(subject_id).get("faction_id", "")) == FACTION_ID:
			out.append(subject_id)
	return out


## U1.3. "It has standing on the same axis every other faction does" —
## computed from whoever is actually in it rather than an authored constant,
## since nothing sat here before the player built it.
static func standing() -> float:
	var roster := members()
	if roster.is_empty():
		return 0.0
	var total := 0.0
	for subject_id in roster:
		total += WorldHistory.tree_alignment(WorldHistory.subject(subject_id))
	return clampf(total / float(roster.size()), -1.0, 1.0)
