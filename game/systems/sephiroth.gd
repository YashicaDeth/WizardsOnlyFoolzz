class_name Sephiroth
extends RefCounted

## AR1 / AV1. "The tree of life you are drawing IS the plane ladder — same
## ten sephiroth." Two different systems read the same shape: AR's tree
## charts which way you went, AV's ladder is where altitude gates what you
## can do. Rather than each inventing its own layout and drifting apart,
## both draw from this one file — ten sephiroth, the tradition's own
## twenty-two paths between them, and Da'ath: present, positioned, and
## deliberately not one of the ten or the twenty-two (AV1.3, AU1's "Da'ath
## is the good one — real, unmapped, unreachable deliberately").

## Normalized (0..1) positions. x is left-to-right, y is top-to-bottom:
## Keter is the crown at the top, Malkuth — 3D, the Hunt Grounds, where the
## player already stands — is the kingdom at the bottom.
const POSITIONS := {
	"keter": Vector2(0.5, 0.04),
	"chokmah": Vector2(0.82, 0.16),
	"binah": Vector2(0.18, 0.16),
	"daath": Vector2(0.5, 0.30),
	"chesed": Vector2(0.82, 0.42),
	"gevurah": Vector2(0.18, 0.42),
	"tiferet": Vector2(0.5, 0.54),
	"netzach": Vector2(0.82, 0.68),
	"hod": Vector2(0.18, 0.68),
	"yesod": Vector2(0.5, 0.80),
	"malkuth": Vector2(0.5, 0.95),
}

## Ordered the way the tradition counts them, Da'ath excluded — used
## anywhere a caller wants "the ten" rather than "the eleven nodes drawn".
const ORDER := [
	"keter", "chokmah", "binah", "chesed", "gevurah", "tiferet",
	"netzach", "hod", "yesod", "malkuth",
]

const NAMES := {
	"keter": "KETER",
	"chokmah": "CHOKMAH",
	"binah": "BINAH",
	"daath": "DA'ATH",
	"chesed": "CHESED",
	"gevurah": "GEVURAH",
	"tiferet": "TIFERET",
	"netzach": "NETZACH",
	"hod": "HOD",
	"yesod": "YESOD",
	"malkuth": "MALKUTH",
}

## One line each, what it means for THIS game rather than the tradition in
## the abstract — so any panel drawing from this file can show a real gloss
## instead of a bare label.
const MEANINGS := {
	"keter": "The godhead, past reach. You cannot fight it sober (AV2.4).",
	"chokmah": "Raw will before it has taken a shape.",
	"binah": "The form a will takes once it has consequences.",
	"daath": "Real, unmapped, unreachable on purpose — where the deliriants go.",
	"chesed": "Mercy the institution extends only to itself.",
	"gevurah": "Severity — the low-frequency demons AR1.4 asks you to live with.",
	"tiferet": "Balance: Malkuth's Hunter and Keter's godhead sit equally far.",
	"netzach": "Victory as a market — AR2's bounty economy.",
	"hod": "Splendor as paperwork. The Choir prices this one.",
	"yesod": "The foundation everything else's weight rests on.",
	"malkuth": "3D. The Hunt Grounds. Where you are standing right now.",
}

## The tradition's own twenty-two paths, as (from, to) sephirah id pairs.
## Da'ath connects to none of them on purpose: the abyss it sits in is the
## gap between paths, not a twenty-third path of its own.
const PATHS := [
	["keter", "chokmah"], ["keter", "binah"], ["keter", "tiferet"],
	["chokmah", "binah"], ["chokmah", "tiferet"], ["chokmah", "chesed"],
	["binah", "tiferet"], ["binah", "gevurah"],
	["chesed", "gevurah"], ["chesed", "tiferet"], ["chesed", "netzach"],
	["gevurah", "tiferet"], ["gevurah", "hod"],
	["tiferet", "netzach"], ["tiferet", "yesod"], ["tiferet", "hod"],
	["netzach", "hod"], ["netzach", "yesod"], ["netzach", "malkuth"],
	["hod", "yesod"], ["hod", "malkuth"],
	["yesod", "malkuth"],
]

## Which faction ladder (K3.2v2 / world_index.gd's own read) each sephirah
## leans toward, so a panel can light a path from real relationship state
## instead of inventing a second alignment number beside tree_alignment()'s.
## Loose on purpose — a lean, not a lock, and more than one node can share a
## faction. Keter, Chokmah, Binah, Da'ath and Malkuth are left out on
## purpose: the godhead answers to nobody, the top two are
## pre-institutional, and Malkuth is simply where you are standing, not a
## faction you commit to. Tiferet is also left out — a panel should read it
## off the same ascent/descent commitment the double pyramid already
## computes, not a faction lookup of its own.
## AR / AQ. Greg: *"the evil qliphoth this is the flipped tree i meant"* and
## *"tree of life and how the tree should look in game this should be the ui and
## the qilplithoth should flip this"*.
##
## The Qliphoth are the tradition's own shadow of the tree above — the
## *qelippot*, "shells" or "husks": what is left when a sephirah's light is
## withdrawn and only the vessel remains. They are not a second invented tree.
## Each one is the recognised counterpart of the sephirah at the same position,
## so the flip is exactly that — a flip, node for node, on the layout already in
## `POSITIONS`. Nothing here needs new geometry.
##
## Why the game wants them: the tree above is the ascent AR charts and AV gates.
## The husks are the same ladder read downward, and they are where the low
## register of this world actually lives — the CellOutz side, the things that
## feed, the debt that is in the meat. A player descending is not off the tree.
## They are on the other face of it.
##
## Da'ath is deliberately absent from the shells for the same reason it is
## absent from `PATHS`: the abyss is the gap, and the gap does not invert.
const QLIPHOTH := {
	"keter": "THAUMIEL",
	"chokmah": "CHAIGIDEL",
	"binah": "SATHARIEL",
	"chesed": "GAMCHICOTH",
	"gevurah": "GOLACHAB",
	"tiferet": "THAGIRION",
	"netzach": "A'ARAB ZARAQ",
	"hod": "SAMAEL",
	"yesod": "GAMALIEL",
	"malkuth": "NEHEMOTH",
}

## One line each, in this game's register rather than the tradition's — the
## same job `MEANINGS` does for the tree above, so a flipped panel has real
## glosses to draw instead of bare transliterations.
const QLIPHOTH_MEANINGS := {
	"keter": "The twins. Two contending godheads where there should be none.",
	"chokmah": "Will that has been confused on purpose, and sold back to you.",
	"binah": "The form withheld. Everything concealed behind a process.",
	"chesed": "The devourers. Mercy that eats what it was extended to.",
	"gevurah": "The burning bodies. Severity with nothing left to restrain it.",
	"tiferet": "The disputers. Balance argued into permanent litigation.",
	"netzach": "The raven of dispersion. A market that scatters what it prices.",
	"hod": "The poison. Splendor as paperwork, and paperwork as venom.",
	"yesod": "The obscene. A foundation that is only appetite.",
	"malkuth": "The whisperers. The kingdom as it actually is at ground level.",
}


## The flipped tree, as a position lookup. Malkuth becomes the crown and Keter
## the floor: descending the husks is climbing, from the husks' point of view,
## which is the whole reason the CellOutz ladder is a ladder at all.
static func qliphoth_position(sephirah_id: String) -> Vector2:
	var above: Vector2 = POSITIONS.get(sephirah_id, Vector2(0.5, 0.5))
	return Vector2(above.x, 1.0 - above.y)


## Name and gloss for one husk. Returns empty strings for `daath`, which has no
## shell on purpose — callers should treat that as "draw the abyss", not as an
## error or a missing entry.
static func qliphah(sephirah_id: String) -> Dictionary:
	return {
		"name": str(QLIPHOTH.get(sephirah_id, "")),
		"meaning": str(QLIPHOTH_MEANINGS.get(sephirah_id, "")),
		"position": qliphoth_position(sephirah_id),
		"is_abyss": sephirah_id == "daath",
	}


## Everything a panel needs to draw either face of the tree from one call, so
## the flip is a parameter rather than a second renderer that drifts out of
## sync with this one.
static func face(inverted: bool) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for id: String in ORDER:
		nodes.append({
			"id": id,
			"name": str(QLIPHOTH.get(id, "")) if inverted else str(NAMES.get(id, "")),
			"meaning": str(QLIPHOTH_MEANINGS.get(id, "")) if inverted else str(MEANINGS.get(id, "")),
			"position": qliphoth_position(id) if inverted else (POSITIONS.get(id, Vector2(0.5, 0.5)) as Vector2),
			"faction": str(LEANING_FACTION.get(id, "")),
		})
	return nodes


const LEANING_FACTION := {
	"chesed": "black_mile",
	"gevurah": "ashline_wreckers",
	"netzach": "choir_of_marrow",
	"hod": "choir_of_marrow",
	"yesod": "choir_of_marrow",
}


static func node_ids() -> Array:
	return POSITIONS.keys()


## True for the ten real sephiroth; false only for Da'ath, which the
## tradition and AV1.3 both keep off the count.
static func is_countable(node_id: String) -> bool:
	return node_id != "daath"
