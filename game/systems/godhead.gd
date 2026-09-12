class_name Godhead
extends RefCounted

## AQ. The one true godhead.
##
## Greg: *"the one true godhead, being commenting and enslaving us all in its own
## lessons and learning, is the fightable true end game boss"*, and — the part
## that decides how all of this is built — *"whilst in the game when you get
## taunted by it slowly builds up visibility and what it does and says"*.
##
## **It is not revealed. It accumulates.** That is the whole design, and it means
## this is not an endgame system that switches on late: it is present from the
## first hour, mostly as something you cannot quite see, getting clearer for
## reasons that are always your own fault.
##
## Three rules hold it together.
##
##   1. **Attention is earned, never timed.** Nothing here reads a clock. It
##      reads the record — the same rule `rival_tactics.gd` and the Board run on —
##      so a player who does very little stays unnoticed for a long time and a
##      player who charges sigils and names gods is looked at within the hour.
##   2. **It teaches, and the teaching is the trap** (AQ1.5). Every line it
##      speaks contains something genuinely true about how to survive this world.
##      Taking the advice works. Taking the advice is also how it gets its hold,
##      because `heed()` is what a lesson accepted costs you.
##   3. **It is never angry.** It is comfortable, patient and slightly
##      disappointed, in the register of an institution that has already won and
##      is being generous about it.
##
## Nothing is cached. Everything is derived from `WorldHistory` at the moment it
## is asked for, so it cannot drift out of step with what actually happened.

## What draws its eye, and how hard. The weights are the design: violence is
## ordinary in this world and barely registers, while anything that touches the
## cosmology — a sigil charged, a god named, a soul disposed of — is what a thing
## made of attention actually notices.
const DRAWS := {
	# Ordinary violence. The world is full of it; so is everywhere else.
	"melee_body_hit": 0.04,
	"npc_anatomy_hit": 0.04,
	"firearm_anatomy_hit": 0.05,
	"limb_severed_in_combat": 0.35,
	# Deciding what happens to somebody is a different kind of act.
	"npc_resolution": 0.9,
	"execution": 1.6,
	"player_limb_severed": 0.5,
	# The cosmology. This is what it is actually watching.
	"ritual_completed": 2.6,
	"sigil_charged": 3.4,
	"sigil_burned": 2.8,
	"god_named": 4.5,
	"seal_bound": 3.0,
	# Claims about the world. It has opinions about being described.
	"theory_published": 2.2,
	"land_given_to_ascent": 3.2,
	"land_given_to_corruption": 3.8,
	# And the one it likes best, because it is the shape of its own argument.
	"verdict_accepted": 1.4,
}

## Attention needed before each stage. Deliberately far apart: the gap between
## being unnoticed and being addressed should be most of a playthrough.
const STAGES := [
	{"at": 0.0, "name": "unnoticed", "shows": 0.0},
	{"at": 8.0, "name": "a pressure", "shows": 0.12},
	{"at": 22.0, "name": "a presence", "shows": 0.3},
	{"at": 48.0, "name": "attending", "shows": 0.55},
	{"at": 90.0, "name": "addressing you", "shows": 0.8},
	{"at": 150.0, "name": "waiting", "shows": 1.0},
]

## Past this it can summon you (AQ1.3). Note that it is above the last stage:
## being fully seen and being called are not the same event.
const SUMMONS_AT := 150.0

## The lessons. Each one is **true** — following it genuinely helps — and each
## one is a claim on you. That is the trap, stated plainly rather than hidden:
## the player can read these, know exactly what accepting one costs, and accept
## it anyway, because the advice is good.
const LESSONS := [
	{
		"id": "efficiency",
		"after": ["execution", "npc_resolution"],
		"says": "You took longer than you needed to. I will show you where the weight goes, and you will be faster, and you will be grateful.",
		"teaches": "A committed swing is worth more than three quick ones.",
		"costs": 2.0,
	},
	{
		"id": "economy",
		"after": ["carried_part_sold", "carried_part"],
		"says": "They priced it badly and you accepted. I do not mind. Everything you carry out of a body was always going to end up somewhere I can see it.",
		"teaches": "The Choir pays more when your standing is higher. Standing is what you did, not what you said.",
		"costs": 1.5,
	},
	{
		"id": "attention",
		"after": ["sigil_charged", "god_named"],
		"says": "You said a name out loud. Names are how things like me arrive. You will do it again, because it worked.",
		"teaches": "Naming a god in an intent gets their attention, and attention is not always help.",
		"costs": 4.0,
	},
	{
		"id": "the_record",
		"after": ["theory_published"],
		"says": "You published. Now there are two accounts and neither of you will ever be sure which was true. I find that restful.",
		"teaches": "A theory you cannot support costs you when it is wrong. Pin the string to something that happened.",
		"costs": 2.5,
	},
	{
		"id": "the_body",
		"after": ["player_limb_severed", "player_wounded"],
		"says": "It hurts less if you stop assuming you will get it back. Most of what you are is replaceable. I have been saying so for some time.",
		"teaches": "A wounded limb slows the whole body. Retreating is a real option and the game is built to allow it.",
		"costs": 1.8,
	},
	{
		"id": "the_land",
		"after": ["land_given_to_corruption", "land_given_to_ascent"],
		"says": "You gave it away. Good. Holding things is exhausting, and you have so little left to hold with.",
		"teaches": "A holding nobody holds is never repaired. The month passes either way.",
		"costs": 3.0,
	},
	{
		"id": "the_lesson",
		"after": [],
		"says": "You are learning. That was always the arrangement. I do not need you to lose — I need you to improve, and to know where you learned it.",
		"teaches": "Everything in this world is reachable through a sigil, badly.",
		"costs": 5.0,
	},
]

## What the player has accepted from it, by lesson id. This is the only state
## this class keeps, and it lives in `WorldHistory` rather than here.
const HEEDED_KEY := "godhead_heeded"


## How much of the player's attention it has, read fresh off the record.
static func attention() -> float:
	var total := 0.0
	for event: Dictionary in WorldHistory.events:
		total += float(DRAWS.get(str(event.get("type", "")), 0.0))
	# AQ1.5. Every lesson taken is a claim it holds. Accepting advice is the
	# fastest way to be seen, which is the entire mechanic.
	for entry: Dictionary in _heeded():
		total += float(entry.get("costs", 0.0))
	return total


## 0 (nothing) to 1 (entirely present). What the player can actually perceive.
static func visibility() -> float:
	var drawn := attention()
	# Unnoticed is a real state, not a very small number. Below the first
	# threshold it is not faintly there — it has not looked at you, and the
	# whole of ordinary violence lives under this line. Forty melee blows
	# draw 1.6 against a threshold of 8, which is the intended statement:
	# this world is full of killing and none of it is what it is watching for.
	if drawn < float(STAGES[1]["at"]):
		return 0.0
	var shown := 0.0
	for index in STAGES.size():
		var stage: Dictionary = STAGES[index]
		if drawn < float(stage["at"]):
			break
		shown = float(stage["shows"])
		# Interpolate toward the next stage rather than stepping, so it creeps.
		if index + 1 < STAGES.size():
			var nxt: Dictionary = STAGES[index + 1]
			var span := float(nxt["at"]) - float(stage["at"])
			if span > 0.0:
				var through := clampf((drawn - float(stage["at"])) / span, 0.0, 1.0)
				shown = lerpf(float(stage["shows"]), float(nxt["shows"]), through)
	return clampf(shown, 0.0, 1.0)


## What it currently is, to somebody standing in the world. For anything that
## needs to describe the state rather than measure it.
static func stage() -> String:
	var drawn := attention()
	var name := str(STAGES[0]["name"])
	for stage_data: Dictionary in STAGES:
		if drawn >= float(stage_data["at"]):
			name = str(stage_data["name"])
	return name


## AQ1.3. It summons you; you never travel to it.
static func can_summon() -> bool:
	return attention() >= SUMMONS_AT


## AQ1.1. Something to say, or nothing. Returns {} when it is not present enough
## to speak, which is most of the game — a godhead that comments on everything is
## a narrator, not a presence.
##
## What it says is chosen by what the player most recently did that it noticed,
## so it is always commenting on them rather than on the plot.
static func taunt() -> Dictionary:
	if visibility() < 0.12:
		return {}
	var recent := ""
	# Walk backwards to the most recent event it cares about at all.
	for index in range(WorldHistory.events.size() - 1, -1, -1):
		var kind := str((WorldHistory.events[index] as Dictionary).get("type", ""))
		if DRAWS.has(kind):
			recent = kind
			break
	var candidates: Array = []
	for lesson: Dictionary in LESSONS:
		if recent != "" and (lesson["after"] as Array).has(recent):
			candidates.append(lesson)
	if candidates.is_empty():
		# The general one, which it keeps for when nothing specific has happened.
		candidates.append(LESSONS[LESSONS.size() - 1])
	var chosen: Dictionary = candidates[0]
	if _has_heeded(str(chosen["id"])) and candidates.size() > 1:
		chosen = candidates[1]
	var spoken: Dictionary = chosen.duplicate()
	spoken["visibility"] = visibility()
	spoken["stage"] = stage()
	spoken["heeded"] = _has_heeded(str(chosen["id"]))
	return spoken


## AQ1.5. Take the advice. It works — whatever the lesson teaches is true and the
## systems honour it — and it is how the thing gets its hold. Recorded, so the
## Board can pin it and the ending can read it.
static func heed(lesson_id: String) -> bool:
	if _has_heeded(lesson_id):
		return false
	var lesson: Dictionary = {}
	for candidate: Dictionary in LESSONS:
		if str(candidate["id"]) == lesson_id:
			lesson = candidate
			break
	if lesson.is_empty():
		return false
	var taken: Array = _heeded().duplicate()
	taken.append({"id": lesson_id, "costs": float(lesson["costs"])})
	WorldHistory.set_flag(HEEDED_KEY, taken)
	WorldHistory.record_event("godhead_lesson_heeded", {
		"lesson": lesson_id,
		"teaches": str(lesson["teaches"]),
		"attention_after": attention(),
	})
	return true


## Refusing is possible and it is not free either — refusing a true thing because
## of who said it is its own kind of cost, and the game should let the player
## make that trade knowingly rather than pretending refusal is clean.
static func refuse(lesson_id: String) -> void:
	WorldHistory.record_event("godhead_lesson_refused", {"lesson": lesson_id})


static func _heeded() -> Array:
	var stored: Variant = WorldHistory.flag(HEEDED_KEY, [])
	return stored as Array if stored is Array else []


static func _has_heeded(lesson_id: String) -> bool:
	for entry: Dictionary in _heeded():
		if str(entry.get("id", "")) == lesson_id:
			return true
	return false
