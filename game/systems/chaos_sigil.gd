class_name ChaosSigil
extends RefCounted

## AJ1. "The magic system using sigils and the new and improved chaos magick
## v2" — Greg's own brief, and the reason chaos magick is the tradition to
## build on rather than an invented one: sigilisation is already a real,
## five-step procedure. State the intent, strip the repeating letters,
## condense what is left into a glyph, charge it, forget it. Five real game
## verbs, and not one of them had to be made up.
##
## `celloutz_type.gd` already carries a complete procedural sigil engine
## (`seal_strokes`/`draw_seal`/`draw_seal_forming`/`draw_seal_corrupted`/
## `draw_seal_burning`) that has, until now, only ever drawn decoration for
## the 72 authored Goetic seals (E2). This file does not touch that engine —
## it only ever needed an integer seed, and a player's own intent is where
## this one comes from instead of a seal's own roster position.
##
## AJ1.1/AJ1.2. State an intent, in the player's own words; watch the letters
## get stripped and condensed into what a real sigil-maker actually keeps.
## The classic method: drop everything but letters, keep only the first
## occurrence of each (repeats are exactly what "condense" means to remove),
## then drop vowels once real consonants remain. A vowel-only intent ("I",
## "AWE") would otherwise condense to nothing, so vowels are only dropped
## when consonants survive to replace them — the glyph is never empty.
const CellOutzType := preload("res://systems/celloutz_type.gd")
const Boons := preload("res://systems/boons.gd")

const VOWELS := ["A", "E", "I", "O", "U"]
## AJ1.4. "Charging costs something real." Blood is the oldest cost in the
## actual tradition — a blood sigil is not an invented mechanic, it is the
## most literal reading of the source material available. Scaled by the
## condensed glyph's own length rather than a flat number, so a longer,
## more demanding intent costs more the same way a heavier ask should —
## never a fiction number unrelated to what was actually stated.
const BLOOD_COST_PER_LETTER := 40.0

## AJ1.5. "Forgetting is mechanical." The real chaos-magick principle, in
## full: a sigil worked *by* being charged and then consciously let go of —
## dwelling on the intent is exactly what keeps it from firing. So this is a
## real clock, not a flavour flag: charging is itself a moment of attention
## (the instant of making it is the most anyone could be looking at it), and
## a sigil only becomes fireable once real WorldClock time has passed since
## the last time anyone attended to it. Attending to it again — the mind
## wandering back to check on it — resets the clock rather than the delay
## accumulating regardless.
const FORGET_HOURS := 6.0

## AJ1.6. "It goes into the world as an object - scratched, burned, carried
## or worn." Four real media, not a flag on the sigil's own dictionary — an
## inscription becomes its own `WorldHistory` subject (`kind: "sigil_object"`)
## so it can be found, stood next to, defaced or stolen later (AJ2.4) the
## same way any other physical thing in this world already can be.
const MEDIA := ["scratched", "burned", "carried", "worn"]
## AJ2.4. Only a portable medium can actually be stolen — a sigil scratched
## into a door or burned into a wall does not move because someone wants it
## to. `worn`/`carried` are the two `MEDIA` that go with a person.
const PORTABLE_MEDIA := ["carried", "worn"]
## AJ2.4. Grudge raised on whoever made a sigil that gets defaced or stolen
## — the same real field the Hunt System's own propagation already reads
## (F2), on the same escalating scale `wire_net.gd`'s channel-contest
## retaliation already uses: a theft is remembered harder than a defacement.
const DEFACE_GRUDGE := 6.0
const STEAL_GRUDGE := 12.0

## AJ2.5. How many charged-but-unfired sigils a subject can actually carry
## before the next one comes out corrupted (`chaos_pending` tracks the real
## count on their own record, advanced in `charge()`/`fire()`, never re-derived
## by counting anything at read time).
const CARRY_CAPACITY := 3
const OVERCHARGE_CORRUPTION := 2.0
## AJ2.2. What a genuine misfire costs — smaller than overcharging, because
## a sigil that simply did not parse into anything is an honest miss, not a
## body pushed past what it can hold.
const MISFIRE_CORRUPTION := 1.0

## AJ2.1. "Effects come from the intent, parsed, not from a spell list." Five
## broad semantic families matched against real words in the stated intent,
## never fifty exact authored phrases — a chaos-magick sigil worked because
## of what the caster actually meant, not because they typed a password from
## a list. An intent that matches none of them is a real, honest miss (AJ2.2),
## not a fallback family invented so nothing ever fails.
const INTENT_FAMILIES := {
	"violence": {"words": ["kill", "hurt", "burn", "break", "hunt", "war", "wound", "destroy"], "stat": "combat_power"},
	"protection": {"words": ["protect", "shield", "guard", "safe", "ward", "armour", "armor"], "stat": "pain_resist"},
	"concealment": {"words": ["hide", "unseen", "quiet", "silent", "vanish", "shadow"], "stat": "stealth"},
	"fortune": {"words": ["luck", "win", "money", "wealth", "gain", "debt"], "stat": "fortune"},
	"sight": {"words": ["see", "know", "reveal", "truth", "find", "remember"], "stat": "perception"},
}
## AJ2.1/AJ2.3. The base swing of a resolved sigil before AJ2.3's own working
## multiplies it, and how long that working actually lasts. Reuses `Boons`
## for the grant itself — an effect from working chaos magick is exactly the
## kind of temporary, body-adjacent boost `boons.gd` already exists for, not
## a second effects system built beside it.
const BASE_MAGNITUDE := 0.15
const POTENCY_STEP := 0.1
const EFFECT_DURATION := 180.0
const EFFECT_COST_KIND := "standing"
const EFFECT_COST := 4.0

## AJ4.1/AJ4.3. "Skill is what you have actually done, read off the record"
## and "a practice you stop practising decays." No second stat this file has
## to keep synchronised with the real one — `skill_level()` counts genuine
## `sigil_resolved` events for a family, the same events `resolve()` already
## writes, inside a real trailing window of `WorldClock` time. Nothing prunes
## old workings on purpose; they simply age out of the window on their own,
## which is what "stop practising and it decays" actually means read
## literally — no decay tick, no cron, just a window that moves. AJ4.2's "no
## skill tree" follows from this directly: there is no second progression
## structure here for the pyramid (AI) to compete with, only a count.
const SKILL_DECAY_HOURS := 168.0


static func condense(intent: String) -> String:
	var upper := intent.to_upper()
	var seen := {}
	var letters := ""
	for index in upper.length():
		var glyph := upper.substr(index, 1)
		if glyph < "A" or glyph > "Z":
			continue
		if seen.has(glyph):
			continue
		seen[glyph] = true
		letters += glyph
	var consonants := ""
	for index in letters.length():
		var glyph := letters.substr(index, 1)
		if not VOWELS.has(glyph):
			consonants += glyph
	return consonants if not consonants.is_empty() else letters


## AJ1.3. "The same words make the same sigil, always." Seeded off the
## condensed letters rather than the raw intent, so whitespace noise and
## case ("I WANT TO WIN" vs "i want   to win") land on the exact same mark —
## the intent is what survives condensation, not how it happened to be typed.
static func seed_for(intent: String) -> int:
	if condense(intent).is_empty():
		return 0
	return hash(condense(intent)) & 0x7fffffff


## The whole first half of the procedure, as one real object: what was
## stated, what it condensed to, and the one number every drawn form of it
## (`CellOutzType.draw_seal` and its `_forming`/`_corrupted`/`_burning`
## variants all key off `seed`) will ever need.
static func seal_for(intent: String) -> Dictionary:
	var trimmed := intent.strip_edges()
	if trimmed.is_empty():
		return {}
	var condensed := condense(trimmed)
	return {
		"intent": trimmed,
		"condensed": condensed,
		"seed": seed_for(trimmed),
	}


## Draws the sigil this intent condenses to. A thin call into the existing
## engine so nothing outside this file ever has to know `seed_for()` exists —
## a caller hands over the words, not a number they derived themselves.
static func draw(canvas: CanvasItem, center: Vector2, radius: float, intent: String, color: Color, complexity: int = 6, weight: float = 0.0) -> void:
	var seal := seal_for(intent)
	if seal.is_empty():
		return
	CellOutzType.draw_seal(canvas, center, radius, int(seal.seed), color, complexity, weight)


## AJ1.4. Spends real blood through the same ledger `boons.gd` already pays
## from — refused outright, the same as a boon would be, if the body does
## not have it to give. A charged sigil is a real, timestamped fact about
## the subject who made it, not a flag on an object nobody else can read.
##
## AJ2.5. "Corruption is what happens when you charge more than you can
## carry." `chaos_pending` on the subject's own record counts real charged
## sigils not yet fired — the ones actually being carried, in the sense the
## checklist means it. Charging past `CARRY_CAPACITY` still succeeds (the
## body still pays; refusing outright would just make overcharging
## impossible rather than costly) but the new sigil comes out corrupted, and
## `resolve()` reads that flag, not a value invented separately from it.
static func charge(intent: String, subject_id: String = "player") -> Dictionary:
	var sigil := seal_for(intent)
	if sigil.is_empty():
		return {"ok": false, "reason": "NOTHING STATED TO CHARGE"}
	var cost := BLOOD_COST_PER_LETTER * maxf(1.0, float(str(sigil.condensed).length()))
	var payment := Boons.pay(subject_id, "blood", cost)
	if not bool(payment.get("ok", false)):
		return payment
	sigil["charged"] = true
	sigil["subject_id"] = subject_id
	sigil["cost_kind"] = "blood"
	sigil["cost_paid"] = cost
	# AJ1.5. Charging is itself a moment of attention — the clock starts from
	# the instant of making it, not from zero, so a sigil cannot be charged
	# and fired in the same breath.
	sigil["last_attended"] = WorldClock.minutes()
	sigil["fired"] = false
	var maker := WorldHistory.subject(subject_id)
	var pending := int(maker.get("chaos_pending", 0))
	var overcharged := pending >= CARRY_CAPACITY
	sigil["corrupted"] = overcharged
	WorldHistory.amend_subject(subject_id, {"chaos_pending": pending + 1})
	WorldHistory.record_event("sigil_charged", {"subject_id": subject_id, "intent": sigil.intent, "seed": sigil.seed, "cost_kind": "blood", "cost_paid": cost, "corrupted": overcharged})
	if overcharged:
		var corruption := float(maker.get("chaos_corruption", 0.0)) + OVERCHARGE_CORRUPTION
		WorldHistory.amend_subject(subject_id, {"chaos_corruption": corruption})
		WorldHistory.record_event("sigil_overcharged", {"subject_id": subject_id, "seed": sigil.seed, "pending": pending + 1, "chaos_corruption": corruption})
	return {"ok": true, "sigil": sigil}


## AJ1.5. Looking at a charged sigil again — checking on it, reading it back,
## anything that puts the intent back in front of the player's attention —
## resets the clock rather than letting the delay accumulate underneath the
## looking. Returns a new dictionary rather than mutating in place, the same
## as `seal_for()`/`charge()` already do, so a caller holding an older copy
## never silently disagrees with a newer one.
static func remember(sigil: Dictionary) -> Dictionary:
	var updated := sigil.duplicate(true)
	updated["last_attended"] = WorldClock.minutes()
	return updated


## Whether a charged sigil has actually been let go of long enough to fire.
## Never true for one that was never charged, or one already spent.
static func can_fire(sigil: Dictionary) -> bool:
	if not bool(sigil.get("charged", false)) or bool(sigil.get("fired", false)):
		return false
	var attended := float(sigil.get("last_attended", 0.0))
	return WorldClock.minutes() - attended >= FORGET_HOURS * WorldClock.MINUTES_PER_HOUR


## AJ1.5. The gate AJ2's actual effects will sit behind: refused outright,
## same register as `charge()`'s own refusals, while the intent is still
## being consciously held. What the effect of a fired sigil actually does
## is AJ2's — this only ever decides whether firing is allowed to happen at
## all, and records that it genuinely did.
static func fire(sigil: Dictionary) -> Dictionary:
	if not bool(sigil.get("charged", false)):
		return {"ok": false, "reason": "NEVER CHARGED"}
	if bool(sigil.get("fired", false)):
		return {"ok": false, "reason": "ALREADY SPENT"}
	if not can_fire(sigil):
		return {"ok": false, "reason": "STILL BEING HELD IN MIND"}
	var fired := sigil.duplicate(true)
	fired["fired"] = true
	var subject_id := str(sigil.get("subject_id", ""))
	# AJ2.5. Fired is no longer carried — whatever `charge()` added to
	# `chaos_pending`, this is the one place it comes back off.
	var maker := WorldHistory.subject(subject_id)
	if not maker.is_empty():
		WorldHistory.amend_subject(subject_id, {"chaos_pending": maxi(0, int(maker.get("chaos_pending", 0)) - 1)})
	WorldHistory.record_event("sigil_fired", {"subject_id": subject_id, "intent": str(sigil.get("intent", "")), "seed": int(sigil.get("seed", 0))})
	return {"ok": true, "sigil": fired}


## AJ2.1/AJ2.2/AJ2.3/AJ2.5. What a fired sigil actually does — the second
## half of `fire()`'s own docstring. A corrupted sigil (AJ2.5) always
## misfires regardless of what it asked for, on the theory that a working
## charged past what the caster could carry does not do what they wanted,
## it does what the overcharge made of it. Otherwise the stated intent is
## matched against `INTENT_FAMILIES`; no match is a real, honest miss
## (AJ2.2) rather than a family invented so resolution never fails, and
## either way something is left behind — `chaos_corruption` rises on a
## miss, the exact ledger AJ2.5's own overcharge already writes into, so a
## caster who keeps missing accumulates the same real cost as one who keeps
## overcharging.
static func resolve(sigil: Dictionary, subject_id: String = "player") -> Dictionary:
	if not bool(sigil.get("fired", false)):
		return {"ok": false, "reason": "NOT FIRED YET"}
	if bool(sigil.get("resolved", false)):
		return {"ok": false, "reason": "ALREADY RESOLVED"}
	var seed := int(sigil.get("seed", 0))
	var resolved := sigil.duplicate(true)
	resolved["resolved"] = true
	var corrupted := bool(sigil.get("corrupted", false))
	var family := "" if corrupted else _match_family(str(sigil.get("intent", "")))
	if family.is_empty():
		var maker := WorldHistory.subject(subject_id)
		var corruption := float(maker.get("chaos_corruption", 0.0)) + (OVERCHARGE_CORRUPTION if corrupted else MISFIRE_CORRUPTION)
		WorldHistory.amend_subject(subject_id, {"chaos_corruption": corruption})
		WorldHistory.record_event("sigil_misfired", {"subject_id": subject_id, "intent": str(sigil.get("intent", "")), "seed": seed, "corrupted": corrupted, "chaos_corruption": corruption})
		resolved["result"] = "misfired"
		return {"ok": true, "sigil": resolved, "result": "misfired", "family": ""}
	var potency := _potency(subject_id, seed)
	var stat := str(INTENT_FAMILIES[family].stat)
	var magnitude := BASE_MAGNITUDE * (1.0 + float(potency) * POTENCY_STEP)
	var granted := Boons.grant(subject_id, "sigil:%s" % family, stat, magnitude, EFFECT_DURATION, EFFECT_COST_KIND, EFFECT_COST)
	if not bool(granted.get("ok", false)):
		# AJ2.2. Even a real, matched intent can still fail if the caster has
		# nothing left to pay the effect with — a failure of the body, not of
		# the parsing, but a sigil that does not fire is still a miss.
		WorldHistory.record_event("sigil_misfired", {"subject_id": subject_id, "intent": str(sigil.get("intent", "")), "seed": seed, "reason": str(granted.get("reason", ""))})
		resolved["result"] = "misfired"
		return {"ok": true, "sigil": resolved, "result": "misfired", "family": family}
	_bump_potency(subject_id, seed)
	WorldHistory.record_event("sigil_resolved", {"subject_id": subject_id, "seed": seed, "family": family, "stat": stat, "magnitude": magnitude, "potency": potency + 1, "world_minute": WorldClock.minutes()})
	resolved["result"] = "resolved"
	resolved["family"] = family
	return {"ok": true, "sigil": resolved, "result": "resolved", "family": family, "magnitude": magnitude}


static func _match_family(intent: String) -> String:
	var lower := intent.to_lower()
	for family in INTENT_FAMILIES:
		for word in (INTENT_FAMILIES[family] as Dictionary).words:
			if lower.contains(str(word)):
				return str(family)
	return ""


## AJ2.3. "The same glyph gets stronger the more it has worked." Keyed by
## seed, not by subject alone — two different intents charged by the same
## caster stay at their own separate strength, because it is the glyph that
## is said to gain power from working, not the caster's magic in general.
static func _potency(subject_id: String, seed: int) -> int:
	var table: Dictionary = WorldHistory.subject(subject_id).get("sigil_potency", {})
	return int(table.get(str(seed), 0))


static func _bump_potency(subject_id: String, seed: int) -> void:
	var subject := WorldHistory.subject(subject_id)
	var table: Dictionary = subject.get("sigil_potency", {}).duplicate(true)
	table[str(seed)] = int(table.get(str(seed), 0)) + 1
	WorldHistory.amend_subject(subject_id, {"sigil_potency": table})


## AJ4.1/AJ4.3. A subject's real skill in one family: how many times they
## have actually resolved a sigil into it, inside the last `SKILL_DECAY_HOURS`
## of world time. Never authored, never a value anything grants directly —
## the only way this number moves is `resolve()` genuinely succeeding.
static func skill_level(subject_id: String, family: String) -> int:
	var now := WorldClock.minutes()
	var count := 0
	for event in WorldHistory.events:
		if str(event.get("type", "")) != "sigil_resolved":
			continue
		var details: Dictionary = event.get("details", {})
		if str(details.get("subject_id", "")) != subject_id:
			continue
		if str(details.get("family", "")) != family:
			continue
		var at := float(details.get("world_minute", -INF))
		if now - at <= SKILL_DECAY_HOURS * WorldClock.MINUTES_PER_HOUR:
			count += 1
	return count


## AJ1.6. Puts a charged sigil into the world as a real, findable object —
## not a second copy of the dictionary living only in whatever screen made
## it. `object_id` is deterministic per maker (`sigil_objects_made` counts up
## on their own subject) so two calls never collide, and the same intent can
## legitimately go into the world twice over in different media — scratched
## into one door and worn as a mark are not the same act. Requires the sigil
## to have actually been charged first; there is no path here that puts an
## un-charged intent into the world as though it were real.
static func inscribe(sigil: Dictionary, subject_id: String, medium: String, location_id: String = "") -> Dictionary:
	if not bool(sigil.get("charged", false)):
		return {"ok": false, "reason": "NOTHING CHARGED TO PUT INTO THE WORLD"}
	if not MEDIA.has(medium):
		return {"ok": false, "reason": "NO SUCH MEDIUM"}
	var maker := WorldHistory.subject(subject_id)
	if maker.is_empty():
		return {"ok": false, "reason": "NO SUCH SUBJECT"}
	var made := int(maker.get("sigil_objects_made", 0))
	var object_id := "sigil_object:%s:%d" % [subject_id, made]
	WorldHistory.register_subject(object_id, {
		"kind": "sigil_object",
		"maker": subject_id,
		"intent": str(sigil.get("intent", "")),
		"condensed": str(sigil.get("condensed", "")),
		"seed": int(sigil.get("seed", 0)),
		"medium": medium,
		"location_id": location_id,
		"defaced": false,
	})
	WorldHistory.amend_subject(subject_id, {"sigil_objects_made": made + 1})
	WorldHistory.record_event("sigil_inscribed", {"subject_id": subject_id, "object_id": object_id, "medium": medium, "seed": int(sigil.get("seed", 0))})
	return {"ok": true, "object_id": object_id}


## AJ2.4. "Other people's sigils exist in the world and can be read." A
## `sigil_object` (AJ1.6) is already a plain `WorldHistory` subject — this is
## just the honest door into it, refusing anything that is not actually one,
## rather than every caller reaching into `WorldHistory.subject()` directly
## and having to know the `kind` check itself.
static func read_object(object_id: String) -> Dictionary:
	var object := WorldHistory.subject(object_id)
	if object.is_empty() or str(object.get("kind", "")) != "sigil_object":
		return {"ok": false, "reason": "NO SUCH SIGIL OBJECT"}
	return {"ok": true, "object": object}


## AJ2.4. "Defaced." A real, permanent mark on the object's own record — not
## removed, because a defaced sigil having been made is still true — and the
## maker actually feels it: their own `grudge` rises the same real field F2's
## propagation already reads, so an act against a sigil is an act against
## whoever made it, not a private edit to an inventory entry.
static func deface(object_id: String, actor_id: String) -> Dictionary:
	var found := read_object(object_id)
	if not bool(found.get("ok", false)):
		return found
	var object: Dictionary = found.object
	if bool(object.get("defaced", false)):
		return {"ok": false, "reason": "ALREADY DEFACED"}
	WorldHistory.amend_subject(object_id, {"defaced": true, "defaced_by": actor_id})
	var maker_id := str(object.get("maker", ""))
	var maker := WorldHistory.subject(maker_id)
	if not maker.is_empty():
		WorldHistory.amend_subject(maker_id, {"grudge": float(maker.get("grudge", 0.0)) + DEFACE_GRUDGE})
	WorldHistory.record_event("sigil_defaced", {"object_id": object_id, "actor_id": actor_id, "maker": maker_id})
	return {"ok": true}


## AJ2.4. "Stolen." Only a portable object can actually change hands —
## `held_by` is the object's own real current holder, distinct from `maker`
## (who made it stays true forever; who holds it now is what theft changes).
static func steal(object_id: String, actor_id: String) -> Dictionary:
	var found := read_object(object_id)
	if not bool(found.get("ok", false)):
		return found
	var object: Dictionary = found.object
	if not PORTABLE_MEDIA.has(str(object.get("medium", ""))):
		return {"ok": false, "reason": "FIXED IN PLACE"}
	var current_holder := str(object.get("held_by", object.get("maker", "")))
	if current_holder == actor_id:
		return {"ok": false, "reason": "ALREADY IN THEIR OWN HANDS"}
	WorldHistory.amend_subject(object_id, {"held_by": actor_id})
	var maker_id := str(object.get("maker", ""))
	var maker := WorldHistory.subject(maker_id)
	if not maker.is_empty():
		WorldHistory.amend_subject(maker_id, {"grudge": float(maker.get("grudge", 0.0)) + STEAL_GRUDGE})
	WorldHistory.record_event("sigil_stolen", {"object_id": object_id, "actor_id": actor_id, "maker": maker_id, "from": current_holder})
	return {"ok": true}
