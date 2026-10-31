class_name OverworldEventParts
extends RefCounted

## The written parts the overworld random events are generated from.
## (DESIGN/OVERWORLD_EVENTS.md, Greg 24 September 2026: "a generator from
## written parts: who, what they want, where, what they do, how it escalates.
## Greg approves the parts.")
##
## ============================================================================
## PLACEHOLDER WRITING FOR GREG. Every line of prose below was drafted by an
## agent so the generator has something to combine. None of it is approved.
## Greg approves, rewrites or deletes each part; the generator does not care
## what the words say, only which tags a part carries.
##
## Still open (DESIGN/OVERWORLD_EVENTS.md "Still open"), so every piece of
## text touching them is marked [PLACEHOLDER] where it appears in play:
##   - what the splinter monks trade, and what they want in return;
##   - what the spirits are (the dead? the planes? real?);
##   - why the splinter left the wizardsonlyfoolz guild.
## Decided and used as given: the monks are a splinter of wizardsonlyfoolz,
## the guild wants them gone, they believe they have reached the final stage
## of enlightenment and are waiting to be freed, and freeing them is part of
## the main task END ALL SUFFERING.
## ============================================================================
##
## How the parts fit together (the generator's only rules):
## - An ACTOR carries `tags`, the `outcomes` it can end in, and a `staging`
##   (how the director puts it on screen: "generic", "vehicle_ram",
##   "monk_rite").
## - A WANT, ACT or ESCALATION may `require_any` actor tags (at least one) and
##   `forbid` actor tags (none of them).
## - A PLACE carries tags. An actor's `needs_place` lists place tags it cannot
##   play without (a car needs somewhere drivable).
## - An ESCALATION has one `outcome` (quest, trade or fight). It is kept only
##   when that outcome is in both the actor's `outcomes` and the want's
##   `leads_to` - that is what makes a combination read as one story.
## - `EXCLUDE` lists pairs that pass the tag rules but still read wrong.
##
## Text templates: {who} the actor, {place} the place, {want} the want's noun.

const PLACEHOLDER := true
const PLACEHOLDER_MARK := "[PLACEHOLDER]"

const OUTCOME_QUEST := "quest"
const OUTCOME_TRADE := "trade"
const OUTCOME_FIGHT := "fight"
const OUTCOMES := [OUTCOME_QUEST, OUTCOME_TRADE, OUTCOME_FIGHT]

const TIER_MINI_BOSS := "mini_boss"
const TIER_BOSS := "boss"

## WHO. The first two are the ones written in full (their `signature` is the
## authored version of their event); the rest are placeholders built from
## factions and figures that already exist somewhere in the game (Ashline,
## Soft Rot, CellOutz, wizardsonlyfoolz), so nothing here invents a faction.
const ACTORS := {
	"crazed_driver": {
		"name": "THE CRAZED DRIVER",
		"who": "a driver in a scrap skiff",
		"tags": ["human", "alone", "violent", "vehicle", "unhinged"],
		"outcomes": [OUTCOME_FIGHT, OUTCOME_QUEST, OUTCOME_TRADE],
		"needs_place": ["drivable"],
		"staging": "vehicle_ram",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "The Driver",
		"elo": 1260,
		"wares": ["a working fuel cell", "the skiff's keys"],
		"weight": 3,
		"written_in_full": true,
		# The authored version: a car tries to run you over and goes crazy.
		"signature": {
			"want": "your_life", "place": "road", "act": "ram", "escalation": "goes_crazy",
			"title": "THE CRAZED DRIVER",
			"beats": [
				{"speaker": "", "line": "An engine, far too close, far too fast.", "shot": "wide", "seconds": 2.2},
				{"speaker": "THE DRIVER", "line": "YOU. YOU'RE THE ONE ON THE RADIO.", "shot": "vehicle", "seconds": 2.4},
				{"speaker": "", "line": "The skiff comes straight at you and misses by a hand.", "shot": "vehicle_pass", "seconds": 2.6},
				{"speaker": "THE DRIVER", "line": "HOLD STILL. HOLD STILL AND I'LL MAKE IT QUICK.", "shot": "chase", "seconds": 2.6},
				{"speaker": "", "line": "It spins, and spins, and something in the cab starts laughing.", "shot": "chase", "seconds": 2.6},
				{"speaker": "THE DRIVER", "line": "FINE. ON FOOT THEN.", "shot": "actor", "seconds": 2.0},
			],
		},
	},
	"splinter_monks": {
		"name": "THE SPLINTER MONKS",
		"who": "a tribe of old wizard monks",
		"tags": ["human", "group", "mystic", "elder", "trader", "splinter"],
		"outcomes": [OUTCOME_TRADE, OUTCOME_QUEST, OUTCOME_FIGHT],
		"needs_place": [],
		"staging": "monk_rite",
		"fight_tier": TIER_BOSS,
		"boss_name": "The Eldest of the Splinter",
		"elo": 1640,
		# OPEN: what the monks trade. Every entry is a placeholder.
		"wares": ["[PLACEHOLDER] a vision of the spirits", "[PLACEHOLDER] a strip of sigil cloth", "[PLACEHOLDER] a name the guild erased"],
		"asks": ["[PLACEHOLDER] a measure of your blood", "[PLACEHOLDER] a promise to come back", "[PLACEHOLDER] one true answer"],
		"weight": 3,
		"written_in_full": true,
		# The authored version. Decided: splinter of wizardsonlyfoolz, the
		# guild wants them gone, they believe they have reached the last stage
		# and wait to be freed, which is part of END ALL SUFFERING. Open: why
		# they left, what the spirits are, what they trade.
		"signature": {
			"want": "to_be_freed", "place": "ruined_shrine", "act": "invoke_spirits", "escalation": "names_a_price",
			"title": "THE SPLINTER MONKS",
			"beats": [
				{"speaker": "", "line": "Old men in black and white, the white gone brown with blood.", "shot": "wide", "seconds": 2.6},
				{"speaker": "THE ELDEST", "line": "We finished. We finished climbing. Now we only wait.", "shot": "actor", "seconds": 2.8},
				{"speaker": "", "line": "They raise their hands and something that is not a body stands up between them.", "shot": "vision", "seconds": 3.2},
				{"speaker": "THE ELDEST", "line": "[PLACEHOLDER] The spirits show us what the guild would not.", "shot": "vision", "seconds": 2.8},
				{"speaker": "THE ELDEST", "line": "Free us, when you are able. Until then, trade.", "shot": "actor", "seconds": 2.6},
			],
		},
	},
	"guild_enforcer": {
		"name": "A GUILD ENFORCER",
		"who": "an enforcer of the wizardsonlyfoolz",
		"tags": ["human", "alone", "mystic", "violent", "guild"],
		"outcomes": [OUTCOME_FIGHT, OUTCOME_QUEST],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Guild Enforcer",
		"elo": 1480,
		"weight": 2,
	},
	"ashline_collectors": {
		"name": "ASHLINE COLLECTORS",
		"who": "Ashline toll collectors",
		"tags": ["human", "group", "violent", "trader"],
		"outcomes": [OUTCOME_FIGHT, OUTCOME_TRADE],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Ashline Tollkeeper",
		"elo": 1180,
		"wares": ["passage", "a toll token"],
		"asks": ["teeth", "rust scrip"],
		"weight": 2,
	},
	"soft_rot_broker": {
		"name": "A SOFT ROT BROKER",
		"who": "a Soft Rot broker",
		"tags": ["human", "alone", "trader", "talker"],
		"outcomes": [OUTCOME_TRADE, OUTCOME_QUEST],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Soft Rot Broker",
		"elo": 1050,
		"wares": ["a spore futures slip", "a mushroom that remembers"],
		"asks": ["rust scrip", "a rumour"],
		"weight": 2,
	},
	"repo_crew": {
		"name": "A CELLOUTZ REPOSSESSION CREW",
		"who": "a CellOutz repossession crew",
		"tags": ["human", "group", "violent", "corporate"],
		"outcomes": [OUTCOME_FIGHT, OUTCOME_TRADE, OUTCOME_QUEST],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Repossession Lead",
		"elo": 1320,
		"wares": ["a payment plan", "a receipt with your name on it"],
		"asks": ["an organ you are behind on", "scrip"],
		"weight": 2,
	},
	"failed_subject": {
		"name": "A FAILED SUBJECT",
		"who": "a failed subject out of a CellOutz vat",
		"tags": ["alone", "desperate", "celloutz", "unhinged"],
		"outcomes": [OUTCOME_QUEST, OUTCOME_FIGHT],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Failed Subject",
		"elo": 1150,
		"weight": 2,
	},
	"funeral_procession": {
		"name": "A FUNERAL PROCESSION",
		"who": "a funeral procession",
		"tags": ["human", "group", "mourning"],
		"outcomes": [OUTCOME_QUEST, OUTCOME_TRADE, OUTCOME_FIGHT],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Chief Mourner",
		"elo": 1100,
		"wares": ["grave goods", "the dead man's coat"],
		"asks": ["a pallbearer's hands", "a coin for the eyes"],
		"weight": 1,
	},
	"bone_picker": {
		"name": "A BONE PICKER",
		"who": "a bone picker with a full sack",
		"tags": ["human", "alone", "trader", "scavenger"],
		"outcomes": [OUTCOME_TRADE, OUTCOME_QUEST, OUTCOME_FIGHT],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Bone Picker",
		"elo": 1010,
		"wares": ["a clean femur", "somebody's implant"],
		"asks": ["whatever you killed last", "a lamp"],
		"weight": 1,
	},
	"wounded_courier": {
		"name": "A WOUNDED COURIER",
		"who": "a courier bleeding through their satchel",
		"tags": ["human", "alone", "desperate", "carrier"],
		"outcomes": [OUTCOME_QUEST, OUTCOME_TRADE],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Courier",
		"elo": 980,
		"wares": ["a sealed letter", "a route nobody else knows"],
		"asks": ["a bandage", "your word"],
		"weight": 1,
	},
	"radio_preacher": {
		"name": "A RADIO PREACHER",
		"who": "a preacher reading from a radio",
		"tags": ["human", "alone", "mystic", "talker", "unhinged"],
		"outcomes": [OUTCOME_QUEST, OUTCOME_FIGHT, OUTCOME_TRADE],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "The Preacher",
		"elo": 1120,
		"wares": ["a frequency", "a blessing that might be real"],
		"asks": ["a confession", "batteries"],
		"weight": 1,
	},
	"celloutz_surveyor": {
		"name": "A CELLOUTZ SURVEYOR",
		"who": "a CellOutz surveyor measuring the ground",
		"tags": ["human", "alone", "corporate", "trader", "talker"],
		"outcomes": [OUTCOME_TRADE, OUTCOME_QUEST, OUTCOME_FIGHT],
		"staging": "generic",
		"fight_tier": TIER_MINI_BOSS,
		"boss_name": "Surveyor",
		"elo": 1060,
		"wares": ["a survey map", "a CellOutz voucher"],
		"asks": ["a signature", "a sample"],
		"weight": 1,
	},
}

## WHAT THEY WANT. `noun` is how the want reads mid-sentence; `leads_to` the
## outcomes it can end in; `task` the quest line if it becomes one.
const WANTS := {
	"your_life": {"noun": "you dead", "line": "I want you dead. I wanted it before I saw you.", "require_any": ["violent", "unhinged"], "leads_to": [OUTCOME_FIGHT, OUTCOME_QUEST], "task": "Find out who wants you dead, and why they sent {who}."},
	"the_road": {"noun": "the road", "line": "This stretch is mine. Everything on it is mine.", "require_any": ["violent", "vehicle", "corporate"], "leads_to": [OUTCOME_FIGHT, OUTCOME_TRADE], "task": "Find who really owns the road at {place}."},
	"to_be_freed": {"noun": "to be freed", "line": "We are finished here. Free us.", "require_any": ["splinter", "desperate"], "leads_to": [OUTCOME_QUEST, OUTCOME_TRADE, OUTCOME_FIGHT], "task": "Free {who}.", "main_task": "end_all_suffering"},
	"a_witness": {"noun": "a witness", "line": "Somebody has to see this. It may as well be you.", "require_any": ["mourning", "mystic", "desperate", "talker"], "leads_to": [OUTCOME_QUEST, OUTCOME_TRADE], "task": "Tell someone two settlements away what you saw at {place}."},
	"a_trade": {"noun": "a trade", "line": "Everything has a price. Even you. Especially you.", "require_any": ["trader"], "leads_to": [OUTCOME_TRADE, OUTCOME_QUEST], "task": "Bring {who} what they asked for."},
	"your_blood": {"noun": "your blood", "line": "Not much. Enough to write with.", "require_any": ["mystic", "celloutz", "corporate", "scavenger"], "leads_to": [OUTCOME_TRADE, OUTCOME_FIGHT], "task": "Find out what {who} wrote in your blood."},
	"a_debt_paid": {"noun": "a debt paid", "line": "You owe. Somebody who looks exactly like you owes.", "require_any": ["corporate", "violent", "trader"], "leads_to": [OUTCOME_FIGHT, OUTCOME_TRADE, OUTCOME_QUEST], "task": "Find the one who ran up the debt in your name."},
	"safe_passage": {"noun": "safe passage", "line": "Walk with us as far as the next lights.", "require_any": ["group", "desperate", "carrier", "elder"], "leads_to": [OUTCOME_QUEST, OUTCOME_TRADE], "task": "See {who} safely past {place}."},
	"your_name": {"noun": "your name", "line": "Say your name. Out loud. So it can be written down.", "require_any": ["mystic", "corporate", "splinter"], "leads_to": [OUTCOME_TRADE, OUTCOME_QUEST, OUTCOME_FIGHT], "task": "Find where {who} wrote your name down."},
	"revenge": {"noun": "revenge", "line": "Someone did this to us. You are going to help.", "require_any": ["mourning", "desperate", "unhinged", "guild"], "leads_to": [OUTCOME_QUEST, OUTCOME_FIGHT], "task": "Find the one {who} want revenge on."},
	"to_test_you": {"noun": "to test you", "line": "Show us what you are. Then we will know what to do with you.", "require_any": ["mystic", "elder", "guild", "violent"], "leads_to": [OUTCOME_FIGHT, OUTCOME_QUEST], "task": "Come back to {who} when you are more than you are."},
	"their_body_back": {"noun": "their body back", "line": "They kept the rest of me. I want it back.", "require_any": ["celloutz"], "leads_to": [OUTCOME_QUEST, OUTCOME_FIGHT], "task": "Find the vat that kept the rest of {who}."},
	"the_splinter_gone": {"noun": "the splinter gone", "line": "There are old men out here wearing our marks. Help me take them back.", "require_any": ["guild"], "leads_to": [OUTCOME_QUEST, OUTCOME_FIGHT], "task": "Find the splinter monks for the guild. Or warn them."},
}

## WHERE. Tags let an actor refuse a place (a car needs `drivable`).
const PLACES := {
	"road": {"name": "the old road", "tags": ["drivable", "open"]},
	"crossroads": {"name": "the crossroads", "tags": ["drivable", "open", "meeting"]},
	"open_waste": {"name": "the open waste", "tags": ["drivable", "open", "empty"]},
	"ruined_shrine": {"name": "a ruined shrine", "tags": ["sacred", "ruin"]},
	"settlement_edge": {"name": "the edge of a settlement", "tags": ["meeting", "people"]},
	"graveyard": {"name": "a graveyard", "tags": ["sacred", "dead"]},
	"drain_mouth": {"name": "a drain mouth", "tags": ["under", "ruin"]},
	"ridge": {"name": "a ridge with a view", "tags": ["open", "high", "sacred"]},
}

## WHAT THEY DO. The first thing the player sees; `vision` acts put a spirit
## vision on screen (OPEN: what the spirits are).
const ACTS := {
	"ram": {"line": "{who} guns it straight at you.", "require_any": ["vehicle"]},
	"block_the_way": {"line": "{who} stand across the way and do not move.", "forbid": ["vehicle"]},
	"perform_rite": {"line": "{who} are halfway through a rite when you arrive.", "require_any": ["mystic"]},
	"invoke_spirits": {"line": "{who} call something up out of the air.", "require_any": ["mystic"], "vision": true},
	"plead": {"line": "{who} see you and start begging before you are close.", "require_any": ["desperate", "mourning", "elder"]},
	"follow_you": {"line": "{who} have been following you for a while.", "forbid": ["group"]},
	"set_out_wares": {"line": "{who} lay their things out on a cloth in your path.", "require_any": ["trader"]},
	"collapse": {"line": "{who} fall down in front of you.", "require_any": ["desperate", "unhinged"], "forbid": ["vehicle"]},
	"mourn": {"line": "{who} are burying something.", "require_any": ["mourning", "group"], "forbid": ["vehicle"]},
	"accuse": {"line": "{who} point at you and say your name wrong.", "require_any": ["talker", "corporate", "guild", "unhinged"]},
}

## HOW IT ESCALATES, and what it resolves into.
const ESCALATIONS := {
	"goes_crazy": {"line": "Then {who} goes completely out of their mind.", "outcome": OUTCOME_FIGHT, "tier": TIER_MINI_BOSS, "require_any": ["unhinged", "violent"]},
	"turns_on_you": {"line": "Then {who} turn on you all at once.", "outcome": OUTCOME_FIGHT, "tier": TIER_MINI_BOSS, "require_any": ["violent", "group", "guild"]},
	"calls_something_bigger": {"line": "Then {who} call up something far bigger than they are.", "outcome": OUTCOME_FIGHT, "tier": TIER_BOSS, "require_any": ["mystic", "elder"]},
	"names_a_price": {"line": "{who} name a price.", "outcome": OUTCOME_TRADE, "require_any": ["trader"]},
	"offers_what_they_carry": {"line": "{who} hold out the one thing they carry.", "outcome": OUTCOME_TRADE, "require_any": ["trader", "carrier", "mourning", "vehicle"]},
	"asks_for_help": {"line": "{who} ask for your help.", "outcome": OUTCOME_QUEST, "forbid": ["vehicle"]},
	"points_elsewhere": {"line": "{who} point somewhere past {place}, and say the answer is there.", "outcome": OUTCOME_QUEST},
	"flees_with_it": {"line": "{who} bolt with it before you can answer.", "outcome": OUTCOME_QUEST, "require_any": ["alone", "vehicle", "scavenger"]},
	"breaks_down": {"line": "{who} break down, and tell you everything.", "outcome": OUTCOME_QUEST, "require_any": ["desperate", "mourning", "unhinged", "elder"]},
}

## Pairs that pass the tag rules but read wrong together. Assistant proposal;
## Greg can empty this list.
const EXCLUDE := [
	["want:a_trade", "escalation:goes_crazy"],
	["want:safe_passage", "act:accuse"],
	["want:to_be_freed", "act:ram"],
	["want:a_witness", "escalation:flees_with_it"],
	["act:mourn", "want:the_road"],
]


## Every part id, grouped, for the generator and for a Greg review sheet.
static func part_ids() -> Dictionary:
	return {
		"actors": _sorted(ACTORS.keys()),
		"wants": _sorted(WANTS.keys()),
		"places": _sorted(PLACES.keys()),
		"acts": _sorted(ACTS.keys()),
		"escalations": _sorted(ESCALATIONS.keys()),
	}


static func _sorted(keys: Array) -> Array:
	var copy := keys.duplicate()
	copy.sort()
	return copy
