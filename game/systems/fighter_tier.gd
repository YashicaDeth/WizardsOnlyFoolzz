class_name FighterTier
extends RefCounted

## Difficulty is who you fight (Greg, 24 September: "tiers are who you fight",
## tuned so a skilled player can beat each one). Four tiers, each a set of
## measured numbers rather than a hidden multiplier:
##
##   cycle       how long their swing takes, against the hunter's
##   telegraph   how far into the wind-up their side is readable (later is
##               harder: less time to raise the right guard)
##   block       how often they stop a swing from the side they face
##   parry       how often a stopped swing is turned, costing you footing
##   feint       how often a wind-up switches side before it lands
##   reads       how often they swing at the side you are *not* guarding
##
## Every roll is a hash of who they are and how many times they have done it,
## never `randf()`: the same fight goes the same way, so a test can measure a
## tier and a player can learn one.
##
## Anyone mid-swing is committed and cannot defend. Hitting a fighter inside
## their own wind-up is the opening every tier leaves, and the skill.

const TIERS := {
	"scavenger": {"label": "SCAVENGER", "cycle": 1.3, "telegraph": 0.35, "block": 0.08, "parry": 0.0, "feint": 0.0, "reads": 0.0},
	"hunter": {"label": "HUNTER", "cycle": 1.0, "telegraph": 0.5, "block": 0.28, "parry": 0.1, "feint": 0.06, "reads": 0.2},
	"captain": {"label": "ASHLINE CAPTAIN", "cycle": 0.86, "telegraph": 0.62, "block": 0.42, "parry": 0.22, "feint": 0.16, "reads": 0.5},
	"elite": {"label": "ELITE", "cycle": 0.74, "telegraph": 0.72, "block": 0.55, "parry": 0.32, "feint": 0.26, "reads": 0.7},
}
const ORDER := ["scavenger", "hunter", "captain", "elite"]
const SIDES := ["high", "low", "left", "right"]
## When a feint switches side, as a fraction of the wind-up.
const FEINT_AT := 0.82


static func spec(tier: String) -> Dictionary:
	return TIERS.get(tier, TIERS["hunter"])


## Who someone is decides how they fight: returning rivals and captains fight
## as captains, law teams and elites as elites, scavengers as scavengers,
## anyone else hostile as a hunter. An encounter may name its tier outright.
static func tier_for(encounter: Dictionary, returning_rival := false) -> String:
	var named := str(encounter.get("tier", ""))
	if TIERS.has(named):
		return named
	var identity := ("%s %s %s" % [encounter.get("name", ""), encounter.get("role", ""), encounter.get("kind", "")]).to_lower()
	if encounter.has("law_dispatch_sequence") or identity.contains("elite") or identity.contains("law"):
		return "elite"
	if returning_rival or identity.contains("captain") or identity.contains("ringmaster"):
		return "captain"
	if identity.contains("scav") or identity.contains("carrion") or identity.contains("salvage"):
		return "scavenger"
	return "hunter"


## A fixed 0..1 number for this fighter's nth decision of a kind.
static func roll(subject_id: String, sequence: int, salt: String) -> float:
	return float(absi(hash("%s|%d|%s" % [subject_id, sequence, salt])) % 10000) / 10000.0


## Which side the next swing comes from. Lower tiers work round their sides;
## higher ones read your guard and go for the side you are not covering.
static func choose_side(tier: String, subject_id: String, sequence: int, player_guard := "") -> String:
	var t := spec(tier)
	if not player_guard.is_empty() and roll(subject_id, sequence, "reads") < float(t.reads):
		var open: Array = SIDES.duplicate()
		open.erase(player_guard)
		return str(open[int(roll(subject_id, sequence, "open") * open.size()) % open.size()])
	return str(SIDES[posmod(hash(subject_id) + sequence, SIDES.size())])


## Whether this wind-up is a feint, and the side it really lands from.
static func feint_side(tier: String, subject_id: String, sequence: int, shown: String) -> String:
	if roll(subject_id, sequence, "feint") >= float(spec(tier).feint):
		return ""
	var others: Array = SIDES.duplicate()
	others.erase(shown)
	return str(others[int(roll(subject_id, sequence, "feint_to") * others.size()) % others.size()])


## What they do with your swing: "parry", "block" or "open". `committed` is
## true while they are inside their own wind-up, and a committed fighter is
## always open.
static func defend(tier: String, subject_id: String, sequence: int, committed: bool) -> String:
	if committed:
		return "open"
	var t := spec(tier)
	if roll(subject_id, sequence, "block") >= float(t.block):
		return "open"
	return "parry" if roll(subject_id, sequence, "parry") < float(t.parry) / maxf(float(t.block), 0.001) else "block"


## Out of `swings` uncommitted swings, how many would get through: the number
## the tuning is checked against.
static func expected_open(tier: String, swings := 1000) -> float:
	var open := 0
	for index in swings:
		if defend(tier, "measure", index, false) == "open":
			open += 1
	return float(open) / float(swings)
