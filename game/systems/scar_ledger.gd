class_name ScarLedger
extends RefCounted

## Brief 2 of `DESIGN/PROMPT_ROADMAP.md`: `scar-ledger`.
##
## A wound is a hole that heals. A scar is a sentence about a person: *this
## happened here, this made it, on this day, in this round*. The body already
## records every wound — `BaselineHuman._record_wound()` has kept the impact
## point, the travel, the depth, whether the round went through and which bone
## it had to cross to get there since AN6.5 — but a body keeps `MAX_PER_ZONE`
## marks per limb and drops the oldest, so the shape of what happened to it
## fogs over after a dozen blows.
##
## This is the part that does not fog: one small record per landed blow, kept on
## the body beside the marks and saved with it. Nothing here is a new damage
## number. Every field is read off what the hit already decided:
##
##   zone      what the body said it was hit in
##   cause     the wound type, said in the words a person would use
##   at        the impact point, in the limb's own space, so it stays put
##   bone      the bone the wound had to cross to be that deep, or nothing
##   round     which round into this body it was, counted off the rounds already
##             recorded — only rounds get one, a blade has no count
##   minute    the world hour it happened, for the date on the line
##
## It is deliberately not a second wound table: the marks are what you look at,
## the ledger is what you read back.

## Past this a body is not a record any more, it is a spreadsheet, and the save
## grows with every run. Oldest goes first, and a body that has taken twenty-four
## wounds is beyond having its history read.
const MAX_SCARS := 24

## The wound types the body already uses, said plainly. A cause is a word, never
## a number and never a new category.
const CAUSES := {
	"cut": "BLADE",
	"shear": "BLADE",
	"ballistic": "ROUND",
	"puncture": "ROUND",
	"blunt": "BLUNT",
	"burn": "BURN",
	"shock": "SHOCK",
	"chemical": "CHEM",
	"sever": "SEVER",
	"graft": "GRAFT",
}
## Only these are counted. A round is one of a number of rounds; a cut is one cut.
const COUNTED := ["ballistic", "puncture"]

## What a bone is called, per limb. Not a rig table — the rig has joints, not
## names — but the same vocabulary `WoundCatalog` already uses for authored
## injuries ("fractured left clavicle"), so a scar and an authored wound can be
## read in the same sentence.
const BONES := {
	"head": "SKULL",
	"torso": "RIB",
	"left_arm": "HUMERUS",
	"right_arm": "HUMERUS",
	"left_leg": "FEMUR",
	"right_leg": "FEMUR",
}
const ZONE_LABELS := {
	"head": "HEAD",
	"torso": "TORSO",
	"left_arm": "LEFT ARM",
	"right_arm": "RIGHT ARM",
	"left_leg": "LEFT LEG",
	"right_leg": "RIGHT LEG",
}
## How deep a wound has to be, as a fraction of the limb, before it has reached
## the bone. The same threshold `RoundTrails` reads, and for the same reason:
## the torso's bone is deeper than a forearm's only because the torso is thicker.
const BONE_AT := 0.62


## The scar one landed blow leaves. `wound` is the record `_record_wound()` just
## wrote (`at`, `type`, `depth`, `through`, `seed`), and `minute` is the world
## hour. Returns empty for anything that is not a wound on a body.
static func from_wound(zone: String, wound: Dictionary, minute: float, existing: Array = []) -> Dictionary:
	if wound.is_empty():
		return {}
	var kind := str(wound.get("type", "blunt"))
	var cause := str(CAUSES.get(kind, "BLUNT"))
	var depth := clampf(float(wound.get("depth", 0.0)), 0.0, 1.0)
	var through := bool(wound.get("through", false))
	var reached := through or depth >= BONE_AT
	var scar := {
		"zone": zone,
		"zone_label": str(ZONE_LABELS.get(zone, str(zone).to_upper())),
		"cause": cause,
		"type": kind,
		"at": wound.get("at", Vector3.ZERO),
		"depth": depth,
		"through": through,
		"bone": str(BONES.get(zone, "")) if reached else "",
		"minute": minute,
		"stamp": stamp_for(minute),
		"round": rounds_in(existing) + 1 if COUNTED.has(kind) else 0,
		"exit": bool(wound.get("exit", false)),
	}
	scar["label"] = line(scar)
	return scar


## Append and cap. A new body starts with an empty ledger and a ledger that has
## been written to is never re-ordered: the scar keeps the minute it happened.
static func record(existing: Array, zone: String, wound: Dictionary, minute: float) -> Array:
	var scars: Array = existing.duplicate(true)
	var scar := from_wound(zone, wound, minute, scars)
	if scar.is_empty():
		return scars
	scars.append(scar)
	while scars.size() > MAX_SCARS:
		scars.remove_at(0)
	return scars


## How many rounds this body has already taken. Read off the ledger rather than
## stored separately, so the count and the record cannot disagree.
static func rounds_in(scars: Array) -> int:
	var count := 0
	for raw in scars:
		if raw is Dictionary and str((raw as Dictionary).get("cause", "")) == "ROUND":
			count += 1
	return count


## `#3 · ROUND · LEFT ARM · 6 ASHWAKE`. The number is which round into this body
## it was, not which scar it was; a blade's line has no number at all.
static func line(scar: Dictionary) -> String:
	var number := int(scar.get("round", 0))
	var head := "#%d · %s · %s · %s" % [number, str(scar.get("cause", "")), str(scar.get("zone_label", "")), str(scar.get("stamp", ""))]
	if number <= 0:
		head = "%s · %s · %s" % [str(scar.get("cause", "")), str(scar.get("zone_label", "")), str(scar.get("stamp", ""))]
	return head


## The one line a board card quotes: the most recent wound that reached bone,
## because that is the one that says what this person has survived, and the most
## recent wound at all when none of them did.
static func quote(scars: Array) -> String:
	for index in range(scars.size() - 1, -1, -1):
		var scar: Dictionary = scars[index]
		if not is_empty_bone(scar):
			return str(scar.get("label", line(scar)))
	if scars.is_empty():
		return ""
	return str((scars[scars.size() - 1] as Dictionary).get("label", ""))


## Every scar that reached a bone, oldest first. What the X-ray marks.
static func at_bone(scars: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for raw in scars:
		if raw is Dictionary and not is_empty_bone(raw):
			found.append(raw as Dictionary)
	return found


static func is_empty_bone(scar: Dictionary) -> bool:
	return str(scar.get("bone", "")).is_empty()


## `6 ASHWAKE`. The world's own calendar rather than a real month: this runs on
## the Ashbloom Expanse's year and `WorldClock` is the only thing that keeps it.
static func stamp_for(minute: float) -> String:
	var day := int(minute / WorldClock.MINUTES_PER_DAY) + 1
	var absolute := day - 1
	var day_of_year := absolute % WorldClock.DAYS_PER_YEAR
	if day_of_year >= WorldClock.REGULAR_DAYS_PER_YEAR:
		return str(WorldClock.UNCOUNTED_DAYS[day_of_year - WorldClock.REGULAR_DAYS_PER_YEAR])
	var month_index := day_of_year / int(WorldClock.DAYS_PER_MONTH)
	return "%d %s" % [day_of_year % int(WorldClock.DAYS_PER_MONTH) + 1, str(WorldClock.MONTH_NAMES[month_index])]


## A body's ledger as it goes into a save: plain JSON, no Vector3 left in it,
## because a scar has to come back after a reload exactly where it landed.
static func to_records(scars: Array) -> Array:
	var out: Array = []
	for raw in scars:
		if not raw is Dictionary:
			continue
		var scar: Dictionary = (raw as Dictionary).duplicate(true)
		var at: Variant = scar.get("at", Vector3.ZERO)
		scar["at"] = {"x": float(at.x), "y": float(at.y), "z": float(at.z)} if at is Vector3 else at
		out.append(scar)
	return out


static func from_records(records: Variant) -> Array:
	var out: Array = []
	if not records is Array:
		return out
	for raw in records:
		if not raw is Dictionary:
			continue
		var scar: Dictionary = (raw as Dictionary).duplicate(true)
		var at: Variant = scar.get("at", Vector3.ZERO)
		if at is Dictionary:
			scar["at"] = Vector3(float(at.get("x", 0.0)), float(at.get("y", 0.0)), float(at.get("z", 0.0)))
		out.append(scar)
	return out
