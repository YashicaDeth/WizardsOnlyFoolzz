class_name BrainIndex
extends RefCounted

## AT. WETWIRE — the brain, the chip and the index. `DESIGN/THE_BRAIN.md`.
##
## "a brain in high detail that has a CRT bent screen showing you the inside of
## the brain, which can be the index for some optional knowledge and the drug
## index". This file is the half of that which is not a render: the **index
## itself**, the **chip that gates it**, and the **cost of using the chip**.
## The organ and the curved CRT (AT1.1/AT1.2/AT1.4) are not attempted here and
## their boxes stay open — there is nothing in this file anybody has looked at.
##
## The mind is a filesystem. Folders, entries, and entries that are *sealed*.
##
## The one rule that makes it a mechanic rather than a skill tree: **a keyword
## cannot be bought, only remembered.** `unlock()` refuses any keyword the
## subject has no lived evidence for, and evidence is counted by reading
## `WorldHistory.events` — the same "draw the conclusion from the log" shape
## `ascent_entities.gd`'s `regard()` uses for attention and `substances.gd`
## uses for a door. Nothing here hands out a keyword from a menu. An NPC can
## say the word "RESTRAINT" at you all day; until the log shows you were
## actually taken, the word opens nothing, because you do not yet know what it
## means. That is remembering rather than purchasing, stated mechanically.
##
## The chip is the other half. It is **hardware somebody else installed**
## (AP1.3 — while you were captured), so it is theirs: it can be revoked, it
## leaves a trail every time you use it, and above a threshold that trail is a
## fix on where you are. And the bridge it opens is the thing killing you —
## reaching 8D/9D doses the head on the *same* `dose` ledger
## `anatomy_component.gd` already burns zones and organs with, so the brain
## this index lives in is the organ the connection eats first.

const ImplantCatalog := preload("res://systems/implant_catalog.gd")
## AT2. "The inventory system with the brain that's a file system of the
## entire game's info index... with drug experiences and other stuff." Both
## preloads below back a *listing*, never a second copy of the data: CARRY
## already owns what you are holding and `substances.gd` already owns what a
## dose costs, so this file reads them back rather than tracking either again.
const CarryModel := preload("res://systems/carry.gd")
const Substances := preload("res://systems/substances.gd")

## The chip as a real piece of hardware in the head, not a boolean. Registered
## into `anatomy_state.cybernetics` through the same catalogue every other
## implant uses, so `body_inspector.gd` and `damage_portrait.gd` find it
## without being told it is special.
const CHIP_IMPLANT_ID := "wetwire chip"
const DEFAULT_OWNER := "celloutz"


# -- the filesystem -----------------------------------------------------------

## AT1.3. Fourteen regions. `open` is whether the folder itself is listed at
## all — UNKNOWN is listed and its contents are not, which is the point of
## having it: you can see that there is something there.
const FOLDERS := {
	"memory": {"label": "MEMORY", "note": "What happened, as you hold it"},
	"passwords": {"label": "PASSWORDS", "note": "Words that open something"},
	"combat": {"label": "COMBAT", "note": "What the body learned being hurt"},
	"people": {"label": "PEOPLE", "note": "Who you are carrying"},
	"places": {"label": "PLACES", "note": "Ground you have stood on"},
	# AT2.1. Not a second CARRY page — `listing()`/`folder_counts()` special-case
	# this one folder to read live off the same `carry.gd` object C4's own page
	# already reads, so the bag and the index cannot disagree.
	"carry": {"label": "CARRY", "note": "What your hands are holding, filed here instead of a second screen"},
	"dreams": {"label": "DREAMS", "note": "Unattributed. Filed anyway"},
	"drugs": {"label": "MATERIA", "note": "The cabinet. What it cost"},
	"entities": {"label": "ENTITIES", "note": "Things that have noticed you"},
	"trauma": {"label": "TRAUMA", "note": "Sealed hardest. Opens worst"},
	"skills": {"label": "SKILLS", "note": "Not points. Things you did twice"},
	"rituals": {"label": "RITUALS", "note": "Names, seals, licences to depart"},
	"languages": {"label": "LANGUAGES", "note": "Structure. Hod's register"},
	"archived": {"label": "ARCHIVED SELVES", "note": "Bodies you are no longer in"},
	"unknown": {"label": "UNKNOWN", "note": "Indexed. Not readable"},
}


## How a keyword is earned. `event` is the recorded type, `count` how many of
## them it takes, `match` fields that must appear in the event's details.
##
## **An empty rule is not an oversight.** A keyword with no rule is a region of
## the index with no known way in — the UNKNOWN folder is built out of them,
## and `unlock()` refuses them forever. A mind that has no locked regions is
## not a mind.
const KEYWORDS := {
	"RESTRAINT": {"event": "player_captured", "count": 1, "match": {}},
	"REDECANT": {"event": "player_redecanted", "count": 1, "match": {}},
	# `extraction.gd` names the body in `subject_id` and never names the cutter,
	# because the only thing that calls it is the player cutting. `whose: "*"`
	# says that out loud rather than pretending the event carries an author.
	"OFFCUT": {"event": "part_extracted", "count": 3, "match": {}, "whose": "*"},
	"MERCY": {"event": "npc_resolution", "count": 3, "match": {"outcome": "spare"}},
	"GROUND": {"event": "map_travel", "count": 4, "match": {}},
	"LIEN": {"event": "device_repossessed", "count": 1, "match": {}},
	"MARROW": {"event": "substance_taken", "count": 1, "match": {"substance_id": "marrow_dust"}},
	"BLOOM": {"event": "substance_taken", "count": 1, "match": {"substance_id": "choir_bloom"}},
	"CARRIER": {"event": "substance_taken", "count": 2, "match": {"substance_id": "static_hymn"}},
	"SILENCE": {"event": "meditation_ended", "count": 2, "match": {}},
	"SEAL": {"event": "ritual_completed", "count": 1, "match": {}},
	"VERDICT": {"event": "death_verdict", "count": 1, "match": {}},
	"WITNESSED": {"event": "subject_laced", "count": 1, "match": {}},
	"NOTICED": {"event": "entity_took_notice", "count": 1, "match": {}},
	# No rule. No route. Indexed and unreadable — see the note above.
	"DA'ATH": {},
	"THE NINTH BODY": {},
}


## An entry is a file. `keyword` empty means it was never sealed. `plane` is
## the floor on the ladder you have to be standing on to read it at all, which
## is what makes most of this index reachable only through the chip (AT1.5):
## plane 0 is "no bridge needed", 4 is free (the wizard eyes), 5 and up are
## the chip's and only the chip's.
##
## AT1.3, "most of what is in it is optional": `optional` is a real field and
## `optional_ratio()` measures it. Three entries are not optional and they are
## the three the game genuinely cannot run without you having — who you are,
## what is in your head, and that you bleed.
##
## AT2.6, "what the chip put there is distinguishable from what you put
## there." `source` defaults to `"self"` — a memory, opened by living the
## keyword's evidence, same as always. `"chip"` marks the other kind: a file
## that arrived the day the hardware did rather than one you remembered.
## `is_open()` reads the two sources completely differently (installed vs.
## unlocked) and `forget()` refuses a `"chip"` entry outright — it is theirs to
## have put there, not yours to take back out.
const ENTRIES := {
	"self_name": {
		"folder": "memory", "title": "WHO YOU ARE", "optional": false, "keyword": "", "plane": 0,
		"body": "The name you answer to. It survived the tank; not much else did.",
	},
	"the_chip": {
		"folder": "memory", "title": "THE THING IN YOUR HEAD", "optional": false, "keyword": "", "plane": 0,
		"body": "A tower bolted through the parietal bone into wet tissue. It is not yours. You did not buy it and you cannot return it.",
	},
	"you_bleed": {
		"folder": "combat", "title": "YOU BLEED", "optional": false, "keyword": "", "plane": 0,
		"body": "Five litres, and every one of them spends.",
	},
	"the_table": {
		"folder": "trauma", "title": "THE TABLE", "optional": true, "keyword": "RESTRAINT", "plane": 0,
		"body": "Four straps and a drain in the floor. You remember the drain best, because it was the only thing you could see.",
	},
	"who_held_you": {
		"folder": "people", "title": "WHO HELD YOU DOWN", "optional": true, "keyword": "RESTRAINT", "plane": 0,
		"body": "Two of them. One apologised. That one is worse.",
	},
	"the_previous_body": {
		"folder": "archived", "title": "THE BODY BEFORE THIS ONE", "optional": true, "keyword": "REDECANT", "plane": 0,
		"body": "Same index, different meat. The index is what CellOutz insures; the meat is what you keep losing.",
	},
	"the_seam": {
		"folder": "archived", "title": "THE SEAM", "optional": true, "keyword": "REDECANT", "plane": 0,
		"body": "Where the last one ended and this one starts, there is about nine seconds nobody has ever accounted for.",
	},
	"where_they_come_apart": {
		"folder": "combat", "title": "WHERE THEY COME APART", "optional": true, "keyword": "OFFCUT", "plane": 0,
		"body": "Three you have opened. The joint before the bone, always, and never the other way around.",
	},
	"the_ones_you_let_go": {
		"folder": "people", "title": "THE ONES YOU LET GO", "optional": true, "keyword": "MERCY", "plane": 0,
		"body": "They are all still out there and they all still know your face.",
	},
	"the_walk": {
		"folder": "places", "title": "THE WALK", "optional": true, "keyword": "GROUND", "plane": 0,
		"body": "Four districts in your legs. You could do the middle two with your eyes shut and once you had to.",
	},
	"whose_it_is": {
		"folder": "passwords", "title": "WHOSE IT IS", "optional": true, "keyword": "LIEN", "plane": 0,
		"body": "Everything you are holding has somebody else's claim stamped inside it. Including this.",
	},
	"the_cut": {
		"folder": "drugs", "title": "THE CUT", "optional": true, "keyword": "MARROW", "plane": 0,
		"body": "Ground cortical bone. It does not stop the pain, it relocates it.",
	},
	"what_grew": {
		"folder": "drugs", "title": "WHAT GREW ON IT", "optional": true, "keyword": "BLOOM", "plane": 0,
		"body": "The Choir cultivates it for exactly this and they do not pretend otherwise.",
	},
	"dead_air": {
		"folder": "languages", "title": "DEAD AIR", "optional": true, "keyword": "CARRIER", "plane": 5,
		"body": "Twice through the static and the second time it was in an order. Hod is structure; this is what structure sounds like from underneath.",
	},
	"the_sitting": {
		"folder": "rituals", "title": "THE SITTING", "optional": true, "keyword": "SILENCE", "plane": 0,
		"body": "Nothing arrives. That is not the failure state, that is the practice.",
	},
	"the_stroke_order": {
		"folder": "rituals", "title": "THE STROKE ORDER", "optional": true, "keyword": "SEAL", "plane": 0,
		"body": "A name, a seal, an offering, and a licence to depart. Skip the fourth and it does not leave.",
	},
	"they_disagree": {
		"folder": "rituals", "title": "THEY DISAGREE", "optional": true, "keyword": "VERDICT", "plane": 7,
		"body": "Two verdicts on one killing, never averaged. Severity and Mercy are different floors of the same building.",
	},
	"what_you_put_in_it": {
		"folder": "trauma", "title": "WHAT YOU PUT IN IT", "optional": true, "keyword": "WITNESSED", "plane": 0,
		"body": "Somebody saw. The index does not editorialise; it just will not let you close this one.",
	},
	"it_answered": {
		"folder": "entities", "title": "IT ANSWERED", "optional": true, "keyword": "NOTICED", "plane": 7,
		"body": "Tiferet is the first floor where they will actually speak with you. Below it you are a noise they are choosing to ignore.",
	},
	"the_recurring_corridor": {
		"folder": "dreams", "title": "THE RECURRING CORRIDOR", "optional": true, "keyword": "SILENCE", "plane": 0,
		"body": "It has the drain in it. You have never told anyone that.",
	},
	"the_abyss": {
		"folder": "unknown", "title": "[UNINDEXED REGION]", "optional": true, "keyword": "DA'ATH", "plane": 0,
		"body": "Not on the map. The deliriants go here and nothing comes back with anything useful.",
	},
	"the_ninth": {
		"folder": "unknown", "title": "[UNINDEXED REGION]", "optional": true, "keyword": "THE NINTH BODY", "plane": 0,
		"body": "Filed under a body number you have not reached.",
	},
	"the_terms": {
		"folder": "passwords", "title": "WHAT YOU AGREED TO (YOU DID NOT)", "optional": true, "keyword": "", "plane": 0,
		"source": "chip",
		"body": "Standard CellOutz wetwire terms, installed the same day as the hardware. Revocation for non-payment is clause four. Nobody has ever shown you clauses one through three.",
	},
}


# -- the ladder ---------------------------------------------------------------

## `DESIGN/THE_BRAIN.md` §3. Ten sephiroth plus the one that is not on the map.
## 3D is the world and 4D (the wizard eyes) is the only higher plane that is
## free; **everything from 5D up is reached through the chip and nothing else**,
## which is AT1.5 stated as a number rather than a sentence.
const PLANES := {
	3: {"sephirah": "Malkuth", "label": "THE KINGDOM", "note": "The world. Where the game is played"},
	4: {"sephirah": "Yesod", "label": "THE FOUNDATION", "note": "The wizard eyes. Brief, earned, free"},
	5: {"sephirah": "Hod", "label": "SPLENDOUR", "note": "Structure, language, the Wire seen from above"},
	6: {"sephirah": "Netzach", "label": "VICTORY", "note": "Appetite, endurance, what a body wants"},
	7: {"sephirah": "Tiferet", "label": "BEAUTY", "note": "The centre. Where entities will speak with you"},
	8: {"sephirah": "Gevurah", "label": "SEVERITY", "note": "Judgement. The verdict on a kill lives here"},
	9: {"sephirah": "Chesed", "label": "MERCY", "note": "The other half of that, and it disagrees"},
	10: {"sephirah": "Binah", "label": "UNDERSTANDING", "note": "Form, limit, the shape of a thing"},
	11: {"sephirah": "Chokmah", "label": "WISDOM", "note": "Force without form. Very little survives here"},
	12: {"sephirah": "Keter", "label": "THE CROWN", "note": "The godhead is on the other side of this"},
}
const FREE_PLANE := 4

## AT1.8 / AO1.3. The towers at 8g and 9g are what melts you. Dose per second
## on the head zone, paid into `anatomy_state.dose` — the same dictionary
## `AnatomyComponent._burn_dose()` already spends against zone health and every
## organ in that zone, of which the brain is one. Nothing new melts you; the
## existing melting path is simply pointed at the organ the index lives in.
const RADIATION_DOSE_PER_SECOND := {8: 0.9, 9: 2.4, 10: 3.6, 11: 5.0, 12: 7.5}
const RADIATION_FLOOR_PLANE := 8

## AT1.7. Every crossing of the bridge leaves one. At `TRACE_FIX` the owner has
## enough to put a pin in a map.
const TRACE_FIX := 5


# -- the chip -----------------------------------------------------------------

static func chip(subject_id: String = "player") -> Dictionary:
	return WorldHistory.subject(subject_id).get("wetwire_chip", {})


## AP1.3. Somebody else does this to you. `owner_faction` is who it answers to,
## and it is not you — `revoke()` below is theirs to call, not yours.
static func install_chip(subject_id: String = "player", owner_faction: String = DEFAULT_OWNER, installer_id: String = "") -> Dictionary:
	var subject := WorldHistory.subject(subject_id)
	if subject.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	if not chip(subject_id).is_empty():
		return {"ok": false, "reason": "ALREADY WIRED"}
	var serial := "WW-%06d" % (absi(hash(subject_id + owner_faction)) % 1000000)
	var record := {
		"serial": serial, "owner_faction": owner_faction, "installed_by": installer_id,
		"installed_at_sequence": WorldHistory.next_sequence, "revoked": false,
		"revoked_reason": "", "dark": false, "dark_since_sequence": -1,
	}
	# The chip is hardware in the head, carried on the same cybernetics list
	# every other implant is on, so the body panels find it without a special
	# case and pulling it is the same operation as pulling anything else.
	var anatomy: Dictionary = subject.get("anatomy_state", {})
	var installed: Array = anatomy.get("cybernetics", [])
	installed.append(ImplantCatalog.resolve({"id": CHIP_IMPLANT_ID, "name": CHIP_IMPLANT_ID}))
	anatomy["cybernetics"] = installed
	WorldHistory.amend_subject(subject_id, {"wetwire_chip": record, "anatomy_state": anatomy})
	WorldHistory.record_event("wetwire_installed", {
		"subject_id": subject_id, "serial": serial, "owner_faction": owner_faction, "installed_by": installer_id,
	})
	return {"ok": true, "serial": serial, "owner_faction": owner_faction}


## AT1.7, the first third. It is revocable because it was never yours. This
## does **not** touch what you have remembered: `wetwire_opened` is untouched
## on purpose — the memories are yours and the network is theirs, and the
## difference between those two is the entire point of the section.
static func revoke(subject_id: String = "player", reason: String = "TERMS OF SERVICE") -> Dictionary:
	var record := chip(subject_id)
	if record.is_empty():
		return {"ok": false, "reason": "NOT WIRED"}
	if bool(record.get("revoked", false)):
		return {"ok": false, "reason": "ALREADY REVOKED"}
	record["revoked"] = true
	record["revoked_reason"] = reason
	WorldHistory.amend_subject(subject_id, {"wetwire_chip": record})
	WorldHistory.record_event("wetwire_revoked", {
		"subject_id": subject_id, "serial": str(record.get("serial", "")),
		"owner_faction": str(record.get("owner_faction", "")), "reason": reason,
	})
	return {"ok": true, "reason": reason}


static func reinstate(subject_id: String = "player") -> Dictionary:
	var record := chip(subject_id)
	if record.is_empty():
		return {"ok": false, "reason": "NOT WIRED"}
	if not bool(record.get("revoked", false)):
		return {"ok": false, "reason": "NOT REVOKED"}
	record["revoked"] = false
	record["revoked_reason"] = ""
	WorldHistory.amend_subject(subject_id, {"wetwire_chip": record})
	WorldHistory.record_event("wetwire_reinstated", {"subject_id": subject_id, "serial": str(record.get("serial", ""))})
	return {"ok": true}


## Going dark is the only counter to being traceable, and it costs you the
## thing you were being traced for: while dark, nothing above `FREE_PLANE`
## opens. You cannot hide from the network and use the network.
static func go_dark(subject_id: String = "player") -> Dictionary:
	var record := chip(subject_id)
	if record.is_empty():
		return {"ok": false, "reason": "NOT WIRED"}
	if bool(record.get("dark", false)):
		return {"ok": false, "reason": "ALREADY DARK"}
	record["dark"] = true
	record["dark_since_sequence"] = WorldHistory.next_sequence
	WorldHistory.amend_subject(subject_id, {"wetwire_chip": record})
	WorldHistory.record_event("wetwire_went_dark", {"subject_id": subject_id, "serial": str(record.get("serial", ""))})
	return {"ok": true}


static func surface(subject_id: String = "player") -> Dictionary:
	var record := chip(subject_id)
	if record.is_empty():
		return {"ok": false, "reason": "NOT WIRED"}
	if not bool(record.get("dark", false)):
		return {"ok": false, "reason": "NOT DARK"}
	record["dark"] = false
	WorldHistory.amend_subject(subject_id, {"wetwire_chip": record})
	WorldHistory.record_event("wetwire_surfaced", {"subject_id": subject_id, "serial": str(record.get("serial", ""))})
	return {"ok": true}


## AT1.7, the second third. Not a counter kept on the subject — read off the
## log, the same as everything else here, counting only crossings since the
## last time the chip went dark. Going dark is therefore a real reset and not
## a cosmetic one.
static func trace_level(subject_id: String = "player") -> int:
	var record := chip(subject_id)
	if record.is_empty():
		return 0
	var since: int = _last_dark_sequence(subject_id)
	if bool(record.get("dark", false)):
		since = maxi(since, int(record.get("dark_since_sequence", -1)))
	var count := 0
	for event in WorldHistory.events:
		if str(event.get("type", "")) != "wetwire_bridged":
			continue
		if int(event.get("sequence", 0)) <= since:
			continue
		var details: Dictionary = event.get("details", {})
		if str(details.get("subject_id", "")) != subject_id:
			continue
		# Only the chip leaves a trail. 4D is free, which means it is also
		# unlogged by the owner — the wizard eyes are the one thing you do up
		# there that nobody is watching, and that has to be true in the count
		# or "go dark" would be impossible to ever reach.
		if not bool(details.get("via_chip", false)):
			continue
		count += 1
	return count


static func _last_dark_sequence(subject_id: String) -> int:
	var last := -1
	for event in WorldHistory.events:
		if str(event.get("type", "")) != "wetwire_went_dark":
			continue
		var details: Dictionary = event.get("details", {})
		if str(details.get("subject_id", "")) != subject_id:
			continue
		last = maxi(last, int(event.get("sequence", 0)))
	return last


## AT1.7, the last third: **it can find you.** A fix is a real place, taken
## from the last crossing that actually recorded one, and it is only available
## once the trail is long enough. Records the fix, so whoever the owner sends
## is reacting to something that happened rather than to a flag.
static func locate(subject_id: String = "player") -> Dictionary:
	var record := chip(subject_id)
	if record.is_empty():
		return {"found": false, "reason": "NOT WIRED"}
	var level := trace_level(subject_id)
	if level < TRACE_FIX:
		return {"found": false, "reason": "TRAIL TOO SHORT", "trace": level, "needed": TRACE_FIX}
	var place := ""
	var at_sequence := -1
	for event in WorldHistory.events:
		if str(event.get("type", "")) != "wetwire_bridged":
			continue
		var details: Dictionary = event.get("details", {})
		if str(details.get("subject_id", "")) != subject_id:
			continue
		if not bool(details.get("via_chip", false)):
			continue
		if str(details.get("place", "")) == "":
			continue
		place = str(details.place)
		at_sequence = int(event.get("sequence", 0))
	var confidence := clampf(float(level) / float(TRACE_FIX * 2), 0.0, 1.0)
	WorldHistory.record_event("wetwire_traced", {
		"subject_id": subject_id, "serial": str(record.get("serial", "")),
		"owner_faction": str(record.get("owner_faction", "")),
		"place": place, "trace": level, "confidence": confidence,
	})
	return {"found": true, "place": place, "at_sequence": at_sequence, "trace": level, "confidence": confidence}


# -- the bridge ---------------------------------------------------------------

## AT1.5. "The tower is the bridge." Everything about the higher planes goes
## through it, so this is the only door to a plane above `FREE_PLANE`, and it
## refuses for the three reasons the chip can refuse: not installed, revoked
## by its owner, or deliberately dark.
##
## AT1.8. Standing on 8D or above doses the head for as long as you stand
## there. There is no version of reaching Gevurah that does not cost the organ
## you are reaching from — that is the bargain, and `bridge()` charges it in
## the same call that grants the plane rather than in a separate one somebody
## could forget to make.
static func bridge(subject_id: String, plane: int, seconds: float = 1.0, place: String = "") -> Dictionary:
	if not PLANES.has(plane):
		return {"ok": false, "reason": "NO SUCH PLANE"}
	var record := chip(subject_id)
	var via_chip := plane > FREE_PLANE
	if via_chip:
		if record.is_empty():
			return {"ok": false, "reason": "NOTHING IN YOUR HEAD TO REACH WITH"}
		if bool(record.get("revoked", false)):
			return {"ok": false, "reason": "REVOKED: " + str(record.get("revoked_reason", ""))}
		if bool(record.get("dark", false)):
			return {"ok": false, "reason": "DARK — YOU CANNOT HIDE FROM IT AND USE IT"}
	var plane_data: Dictionary = PLANES[plane]
	WorldHistory.record_event("wetwire_bridged", {
		"subject_id": subject_id, "plane": plane, "sephirah": str(plane_data.sephirah),
		"via_chip": via_chip, "place": place, "seconds": seconds,
	})
	var result := {
		"ok": true, "plane": plane, "sephirah": str(plane_data.sephirah),
		"label": str(plane_data.label), "via_chip": via_chip, "dose": 0.0,
	}
	if plane >= RADIATION_FLOOR_PLANE:
		result["dose"] = _radiate(subject_id, plane, seconds)
	if via_chip:
		result["trace"] = trace_level(subject_id)
	return result


## The dose goes on the head and nowhere else, because the tower is in the
## head. `AnatomyComponent._burn_dose()` then spends it against head zone
## health and every organ in that zone — the brain among them — which is why
## this is written as dose rather than as flat damage: it keeps hurting after
## you come down.
static func _radiate(subject_id: String, plane: int, seconds: float) -> float:
	var rate := float(RADIATION_DOSE_PER_SECOND.get(plane, 0.0))
	if rate <= 0.0 or seconds <= 0.0:
		return 0.0
	var taken := rate * seconds
	var subject := WorldHistory.subject(subject_id)
	var anatomy: Dictionary = subject.get("anatomy_state", {})
	var dose: Dictionary = anatomy.get("dose", {})
	dose["head"] = float(dose.get("head", 0.0)) + taken
	anatomy["dose"] = dose
	WorldHistory.amend_subject(subject_id, {"anatomy_state": anatomy})
	WorldHistory.record_event("wetwire_radiation", {
		"subject_id": subject_id, "plane": plane, "zone": "head", "dose": taken,
	})
	return taken


static func head_dose(subject_id: String = "player") -> float:
	var anatomy: Dictionary = WorldHistory.subject(subject_id).get("anatomy_state", {})
	var dose: Dictionary = anatomy.get("dose", {})
	return float(dose.get("head", 0.0))


## The highest plane this subject could reach right now, given what is in their
## head and what state it is in. `FREE_PLANE` for everybody, because the wizard
## eyes are free; the rest is the chip's.
static func reach(subject_id: String = "player") -> int:
	var record := chip(subject_id)
	if record.is_empty() or bool(record.get("revoked", false)) or bool(record.get("dark", false)):
		return FREE_PLANE
	return 12


# -- remembering --------------------------------------------------------------

## Does this event concern this subject? Harder than it looks, and getting it
## wrong is how this file first counted zero acts of mercy for a player who had
## spared three people: `npc_resolution` names the *NPC* in `subject_id` and the
## player in `actor`, so a naive "first identity field wins" attributes every
## sparing to the person who was spared.
##
## So: an author, when the event names one, beats a subject. Events naming
## nobody at all (`player_captured` — it could only ever be about you) count for
## the player. A rule may override with `whose`, either naming the detail key
## that identifies its person or "*" for "attribution is not checked here".
static func _concerns(event: Dictionary, subject_id: String, whose: String = "") -> bool:
	var details: Dictionary = event.get("details", {})
	if whose == "*":
		return true
	if whose != "":
		return str(details.get(whose, "")) == subject_id
	for key in ["actor", "actor_id"]:
		if details.has(key):
			return str(details[key]) == subject_id
	for key in ["subject_id", "subject"]:
		if details.has(key):
			return str(details[key]) == subject_id
	return subject_id == "player"


## How much lived evidence there is for a keyword. Zero for a keyword with no
## rule, always — that is what makes UNKNOWN unknown.
static func evidence_count(keyword: String, subject_id: String = "player") -> int:
	var rule: Dictionary = KEYWORDS.get(keyword, {})
	if rule.is_empty():
		return 0
	var wanted := str(rule.get("event", ""))
	var match_fields: Dictionary = rule.get("match", {})
	var count := 0
	for event in WorldHistory.events:
		if str(event.get("type", "")) != wanted:
			continue
		if not _concerns(event, subject_id, str(rule.get("whose", ""))):
			continue
		var details: Dictionary = event.get("details", {})
		var ok := true
		for field in match_fields:
			if str(details.get(field, "")) != str(match_fields[field]):
				ok = false
				break
		if ok:
			count += 1
	return count


static func has_evidence(keyword: String, subject_id: String = "player") -> bool:
	var rule: Dictionary = KEYWORDS.get(keyword, {})
	if rule.is_empty():
		return false
	return evidence_count(keyword, subject_id) >= int(rule.get("count", 1))


## Every keyword this subject could speak truthfully right now. This is the
## honest readout of "what you are about to remember" — and it is derived, so
## it changes when the player's history does and never because a menu said so.
static func discovered_keywords(subject_id: String = "player") -> Array:
	var found: Array = []
	for keyword in KEYWORDS:
		if has_evidence(str(keyword), subject_id):
			found.append(str(keyword))
	return found


static func opened(subject_id: String = "player") -> Array:
	return (WorldHistory.subject(subject_id).get("wetwire_opened", []) as Array).duplicate()


static func is_open(entry_id: String, subject_id: String = "player") -> bool:
	var entry: Dictionary = ENTRIES.get(entry_id, {})
	if entry.is_empty():
		return false
	# AT2.6. A chip file is never sealed behind a keyword and never remembered
	# into `wetwire_opened` — it is simply present once the hardware is,
	# whether or not the subject would ever have gone looking for it. `chip()`
	# stays populated after `revoke()` (that call only flips fields on the same
	# record), so a revoked chip's own paperwork does not vanish with it —
	# consistent with "you cannot delete the chip's files" below in `forget()`.
	if str(entry.get("source", "self")) == "chip":
		return not chip(subject_id).is_empty()
	if str(entry.get("keyword", "")) == "":
		return true
	return opened(subject_id).has(entry_id)


## **The one that matters.** A keyword is refused unless the log says you lived
## it — so a word overheard, read off a wall, or handed over by an NPC opens
## nothing until the thing it names has actually happened to you. When it does
## open, every entry sealed under that word opens at once, because that is what
## remembering is: not one file, the whole afternoon.
static func unlock(keyword: String, subject_id: String = "player") -> Dictionary:
	var word := keyword.strip_edges().to_upper()
	if not KEYWORDS.has(word):
		return {"ok": false, "reason": "THAT WORD MEANS NOTHING HERE", "opened": []}
	if not has_evidence(word, subject_id):
		var rule: Dictionary = KEYWORDS[word]
		if rule.is_empty():
			return {"ok": false, "reason": "INDEXED. NOT READABLE.", "opened": []}
		return {
			"ok": false, "reason": "YOU KNOW THE WORD. YOU DO NOT KNOW WHAT IT MEANS YET.",
			"opened": [], "evidence": evidence_count(word, subject_id), "needed": int(rule.get("count", 1)),
		}
	var already := opened(subject_id)
	var newly: Array = []
	for entry_id in ENTRIES:
		var entry: Dictionary = ENTRIES[entry_id]
		if str(entry.get("keyword", "")) != word:
			continue
		if already.has(entry_id):
			continue
		already.append(entry_id)
		newly.append(entry_id)
	if newly.is_empty():
		return {"ok": false, "reason": "ALREADY REMEMBERED", "opened": []}
	WorldHistory.amend_subject(subject_id, {"wetwire_opened": already})
	WorldHistory.record_event("memory_recovered", {
		"subject_id": subject_id, "keyword": word, "entries": newly.duplicate(),
	})
	return {"ok": true, "keyword": word, "opened": newly}


## AT2.6, the other half of the distinction `is_open()` draws: a memory can be
## let go of, its own file. A `"chip"` entry refuses outright, permanently and
## for the one reason that matters — it was never yours to begin with, so
## there is nothing here for you to hand back. A `"self"` entry that was never
## opened refuses too, but for the ordinary reason: there is nothing there yet
## to forget.
static func forget(entry_id: String, subject_id: String = "player") -> Dictionary:
	var entry: Dictionary = ENTRIES.get(entry_id, {})
	if entry.is_empty():
		return {"ok": false, "reason": "NO SUCH ENTRY"}
	if str(entry.get("source", "self")) == "chip":
		return {"ok": false, "reason": "NOT YOURS TO DELETE"}
	var already := opened(subject_id)
	if not already.has(entry_id):
		return {"ok": false, "reason": "NOTHING TO FORGET"}
	already.erase(entry_id)
	WorldHistory.amend_subject(subject_id, {"wetwire_opened": already})
	WorldHistory.record_event("memory_forgotten", {"subject_id": subject_id, "entry_id": entry_id})
	return {"ok": true, "entry_id": entry_id}


## Reading one. Three separate refusals, and they say different things because
## they *are* different things: sealed is "you have not remembered this",
## revoked is "somebody took the floor you were standing on", and too-low is
## "you are not high enough to be here".
static func read_entry(entry_id: String, subject_id: String = "player") -> Dictionary:
	var entry: Dictionary = ENTRIES.get(entry_id, {})
	if entry.is_empty():
		return {"ok": false, "reason": "NO SUCH ENTRY"}
	if not is_open(entry_id, subject_id):
		return {"ok": false, "reason": "SEALED", "keyword_hint": str(entry.get("keyword", ""))}
	var required := int(entry.get("plane", 0))
	if required > 0:
		var available := reach(subject_id)
		if available < required:
			var record := chip(subject_id)
			var why := "NOT HIGH ENOUGH"
			if bool(record.get("revoked", false)):
				why = "REVOKED: " + str(record.get("revoked_reason", ""))
			elif bool(record.get("dark", false)):
				why = "DARK"
			elif record.is_empty():
				why = "NOTHING IN YOUR HEAD TO REACH WITH"
			return {"ok": false, "reason": why, "required_plane": required, "reach": available}
	return {
		"ok": true, "id": entry_id, "title": str(entry.title), "folder": str(entry.folder),
		"body": str(entry.body), "optional": bool(entry.optional), "plane": required,
		"source": str(entry.get("source", "self")),
	}


## What the index draws. Sealed entries are **listed and not readable** — you
## can see the shape of what you have not remembered, which is the difference
## between an index and an inventory.
##
## AT2.1/AT2.4. Two folders draw from somewhere other than `ENTRIES`: CARRY is
## entirely live (`carry_listing()` — there is no static entry to list at
## all), and MATERIA's static lore rows are followed by one real row per dose
## actually taken (`drug_experiences()`). Neither is a second dataset; both
## read the same objects their own systems already keep.
static func listing(folder_id: String, subject_id: String = "player") -> Array:
	if folder_id == "carry":
		return carry_listing(subject_id)
	var rows: Array = []
	for entry_id in ENTRIES:
		var entry: Dictionary = ENTRIES[entry_id]
		if str(entry.get("folder", "")) != folder_id:
			continue
		var open_now := is_open(entry_id, subject_id)
		var required := int(entry.get("plane", 0))
		rows.append({
			"id": entry_id,
			"title": str(entry.title) if open_now else "[SEALED]",
			"optional": bool(entry.optional),
			"open": open_now,
			"plane": required,
			"reachable": required <= reach(subject_id),
			"source": str(entry.get("source", "self")),
		})
	if folder_id == "drugs":
		rows.append_array(drug_experiences(subject_id))
	return rows


static func folder_counts(subject_id: String = "player") -> Dictionary:
	var counts := {}
	for folder_id in FOLDERS:
		var rows := listing(folder_id, subject_id)
		var open_count := 0
		for row in rows:
			if bool((row as Dictionary).get("open", false)):
				open_count += 1
		counts[folder_id] = {"total": rows.size(), "open": open_count}
	return counts


## AT2.1. Reads the exact object C4's own CARRY page already reads
## (`carry.gd`), so the brain and the bag can never disagree about what you
## are holding. There is nothing to seal here — what is in your hands is
## never a secret from yourself — so every row comes back open.
static func carry_listing(subject_id: String = "player") -> Array:
	var carry := CarryModel.new()
	var rows: Array = []
	for index in carry.items.size():
		var item: Dictionary = carry.items[index]
		rows.append({
			"id": "carry_%d" % index,
			"index": index,
			"title": str(item.get("label", "UNNAMED")),
			"kind": str(item.get("kind", "goods")),
			"mass": float(item.get("mass", 0.5)),
			"condition": float(item.get("condition", 1.0)),
			"pocketed": bool(item.get("pocketed", false)),
			"optional": true,
			"open": true,
			"plane": 0,
			"reachable": true,
			"source": "self",
		})
	return rows


## AT2.4. Every dose already writes `substance_taken` (`substances.gd`); this
## reads that log back as a reopenable record instead of a drug experience
## needing to be saved into a second place to be reopenable at all. Strain and
## potency are re-derived through the same deterministic `roll_strain()` the
## carried baggie itself was rolled with, keyed off the event's own sequence
## number, so the record and the item agree without either storing the
## other's data.
static func drug_experiences(subject_id: String = "player") -> Array:
	var rows: Array = []
	for event in WorldHistory.events:
		if str(event.get("type", "")) != "substance_taken":
			continue
		var details: Dictionary = event.get("details", {})
		if str(details.get("subject_id", "")) != subject_id:
			continue
		var sequence := int(event.get("sequence", 0))
		var substance_id := str(details.get("substance_id", ""))
		var data: Dictionary = Substances.CATALOG.get(substance_id, {})
		var strain := Substances.roll_strain(substance_id, sequence)
		rows.append({
			"id": "experience_%d" % sequence,
			"sequence": sequence,
			"title": "%s — %s" % [str(data.get("label", substance_id)).to_upper(), str(strain.strain)],
			"substance_id": substance_id,
			"optional": true,
			"open": true,
			"plane": 0,
			"reachable": true,
			"source": "self",
		})
	return rows


## The reopened record itself, kept separate from `read_entry()` because these
## are not files in `ENTRIES` — there is one per dose actually taken, not one
## per substance, and the second Bloom does not read the same as the first.
static func read_experience(sequence: int, subject_id: String = "player") -> Dictionary:
	for event in WorldHistory.events:
		if int(event.get("sequence", -1)) != sequence:
			continue
		if str(event.get("type", "")) != "substance_taken":
			return {"ok": false, "reason": "NOT A DRUG EXPERIENCE"}
		var details: Dictionary = event.get("details", {})
		if str(details.get("subject_id", "")) != subject_id:
			return {"ok": false, "reason": "NOT YOURS"}
		var substance_id := str(details.get("substance_id", ""))
		var data: Dictionary = Substances.CATALOG.get(substance_id, {})
		var strain := Substances.roll_strain(substance_id, sequence)
		return {
			"ok": true, "sequence": sequence, "substance_id": substance_id,
			"title": "%s — %s" % [str(data.get("label", substance_id)).to_upper(), str(strain.strain)],
			"role": str(data.get("role", "")), "potency": float(strain.potency),
			"cost_kind": str(details.get("cost_kind", "")),
			"cost_amount": float(details.get("cost_amount", 0.0)),
		}
	return {"ok": false, "reason": "NO SUCH RECORD"}


## AT1.3, measured rather than asserted. "Most of what is in it is optional"
## is a claim with a number behind it, and the test holds this above 0.8.
static func optional_ratio() -> float:
	if ENTRIES.is_empty():
		return 0.0
	var optional := 0
	for entry_id in ENTRIES:
		if bool((ENTRIES[entry_id] as Dictionary).get("optional", true)):
			optional += 1
	return float(optional) / float(ENTRIES.size())


static func required_entries() -> Array:
	var out: Array = []
	for entry_id in ENTRIES:
		if not bool((ENTRIES[entry_id] as Dictionary).get("optional", true)):
			out.append(entry_id)
	return out


# -- the Wire from above ------------------------------------------------------

## AT1.6, the half of it that is data. "The Wire seen from 5D is what that
## network is" — so this deliberately builds **no second dataset**: it reaches
## for the same `WireNet` accounts the ground-level Wire already has and
## re-ranks them by Tree alignment instead of reach. The same people, ordered
## by what they are rather than by how loud they are, which is the only
## difference Hod actually makes.
##
## Its box stays open: the *content* half of AT1.6 — "the posts are being made
## by something else" — is writing and a shader, neither of which is here.
static func wire_from_above(subject_id: String = "player") -> Dictionary:
	var gate := bridge(subject_id, 5, 0.0)
	if not bool(gate.get("ok", false)):
		return {"ok": false, "reason": str(gate.get("reason", ""))}
	var net := WireNet.new(WireNet.SIGNAL_SURFACE)
	net.rebuild()
	var accounts: Array = net.accounts_by_reach()
	var rows: Array = []
	for account in accounts:
		var entry: Dictionary = account
		var account_id := str(entry.get("id", entry.get("subject_id", "")))
		rows.append({
			"id": account_id,
			"handle": str(entry.get("handle", entry.get("name", account_id))),
			"reach": int(entry.get("reach", 0)),
			"alignment": WorldHistory.tree_alignment(WorldHistory.subject(account_id)),
		})
	rows.sort_custom(func(a, b): return float(a.alignment) > float(b.alignment))
	return {"ok": true, "plane": 5, "sephirah": "Hod", "accounts": rows}
