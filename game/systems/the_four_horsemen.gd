class_name TheFourHorsemen
extends RefCounted

## K2. "Recurring bosses across the whole game, who take turns leading the
## CellOutz faction... None of them should be a health bar in a room. They
## lead a faction that is already simulated, so they should be met the way
## any ranked subject is met... Famine running CellOutz is a different world
## from War running it." — DESIGN/COSMOLOGY.md
##
## Names given by Greg 2026-09-12: the traditional four (War, Famine,
## Pestilence, Death), used directly rather than an Ashbloom coinage. What is
## this world's own is what each of them actually runs:
##
## - **War** currently holds CROWN — the reigning Horseman when the derby
##   itself is CellOutz's product.
## - **Famine** controls the ration boards and water allocation the opening
##   already references.
## - **Pestilence** runs the spore blooms that answer to him before they
##   answer to weather — Ashbloom's own fungal ecology, not a plague added on
##   top of it.
## - **Death** owns the Growing Floor's discard manifest: the paperwork on
##   who didn't make it out of the vat. The player's own opening is on that
##   ledger.
##
## K2.2 (rotating succession) is deliberately *not* a scripted order. Per
## non-negotiable 2, "systems create stories" — each Horseman gets real
## influence/loyalty/wealth so `WireNet.promote_successor()`'s existing,
## generic scoring decides who actually takes the post when War falls,
## the same machinery F3 already runs for any faction. Nothing here names
## the next Horseman in advance.
##
## K2.3/K2.4: `CellOutzDoctrine.current()` (below) reads whichever Horseman
## currently holds CROWN and returns that Horseman's own doctrine/threat/
## territory instead of one static text — the concrete answer to "who holds
## the post changes what CellOutz does" and, because a run's succession is
## emergent rather than scripted, to "the Horseman in power is what makes a
## run different" (the roguelike question K2.4 asks).

## Each Horseman's own grip on a real Sin (not a raw "influence" number —
## `WireNet._build_account()` computes influence from a subject's own
## outgoing `command`/`ally`/`bond` relations, so that is what has to carry
## it) doubles as flavour: War over the Wrath faction that already runs the
## derby, Famine over the toll cartel that controls what moves, Pestilence
## over the fungal faith, Death over the anatomical one. `loyalty` and
## `wealth` are real fields `_best_successor()` reads directly.
const HORSEMEN := {
	"war": {
		"name": "War", "role": "Reigning Horseman — every derby heat is technically his product",
		"memory": "Has not lost a rotation yet. Says the quiet part out loud: a heat that never ends is the whole business model.",
		"grip": "ashline_wreckers", "loyalty": 30, "wealth": 4000,
	},
	"famine": {
		"name": "Famine", "role": "Controls the ration boards and the water allocation",
		"memory": "Has never once raised his voice. Has never once needed to.",
		"grip": "black_mile", "loyalty": 55, "wealth": 2200,
	},
	"pestilence": {
		"name": "Pestilence", "role": "The spore blooms answer to him before they answer to weather",
		"memory": "Was in the quarry the week the fungus first turned. Nobody has asked him why he wasn't surprised.",
		"grip": "soft_rot", "loyalty": 20, "wealth": 1500,
	},
	"death": {
		"name": "Death", "role": "Owns the Growing Floor's discard manifest",
		"memory": "Keeps the paperwork on everyone who didn't make it out of a vat. Yours is in there.",
		"grip": "choir_of_marrow", "loyalty": 40, "wealth": 8000,
	},
}
const REIGNING := "war"


static func seed_horsemen() -> void:
	WorldHistory.begin_ledger_batch()
	for horseman_id in HORSEMEN:
		var data: Dictionary = HORSEMEN[horseman_id]
		WorldHistory.register_subject(horseman_id, {
			"name": str(data.name), "kind": "person", "role": str(data.role),
			"faction": "CellOutz", "faction_id": "celloutz",
			"faction_rank": "CROWN" if horseman_id == REIGNING else "",
			"loyalty": int(data.loyalty), "wealth": int(data.wealth),
			"elo": 1500, "grudge": 0, "status": "active", "memory": str(data.memory),
			"wounds": [], "anatomy": {"blood_type": "UNKNOWN", "cybernetics": []},
			"relations": {str(data.grip): {"kind": "command", "strength": 60}},
		})
	WorldHistory.commit_ledger_batch()


## K2.3/K2.4. Each variation keeps CellOutz's own "ownership, downward" line
## — the Horseman changes how it is enforced, not the fact of it, since it is
## still the one company underneath all four.
const DOCTRINE := {
	"war": {"doctrine": "Ownership, downward, enforced at speed. The heat is the argument.", "threat": "SEVERE"},
	"famine": {"doctrine": "Ownership, downward, enforced by scarcity. You will take what is allotted.", "threat": "HIGH"},
	"pestilence": {"doctrine": "Ownership, downward, enforced by exposure. The spores decide who is compliant.", "threat": "UNKNOWN"},
	"death": {"doctrine": "Ownership, downward, enforced by the manifest. Everyone is already accounted for.", "threat": "SEVERE"},
}


## Whoever actually holds CROWN right now, read fresh rather than cached —
## after a real succession (`WireNet.promote_successor()`) this changes
## without anything here needing to be told. `promote_successor()` does not
## clear a fallen holder's own `faction_rank` (dead members are excluded by
## status everywhere else that reads the pyramid, not by the field itself),
## so a dead Horseman still carrying "CROWN" on paper is skipped here too
## rather than read as still reigning.
static func current_reign() -> String:
	for horseman_id in HORSEMEN:
		var subject := WorldHistory.subject(horseman_id)
		if WireNet.DEAD_STATUSES.has(str(subject.get("status", "")).to_lower()):
			continue
		if str(subject.get("faction_rank", "")) == "CROWN":
			return horseman_id
	return ""


## K2.3, concretely: CellOutz's own doctrine and threat rating, but read
## through whoever is actually reigning. Falls back to the faction's own
## static text if the post is genuinely vacant (`DemonHierarchy`'s structural
## vacancy, not an error).
static func current_doctrine() -> Dictionary:
	var base := WorldHistory.subject("celloutz")
	var reigning := current_reign()
	if reigning.is_empty():
		return base
	var flavor: Dictionary = DOCTRINE.get(reigning, {})
	base["threat"] = str(flavor.get("threat", base.get("threat", "")))
	base["doctrine"] = str(flavor.get("doctrine", base.get("doctrine", "")))
	base["reigning_horseman"] = reigning
	return base
