class_name PlaneVoices
extends RefCounted

## AV3.2-AV3.7. "They remember you."
##
## AV3.1 (`sephiroth.gd`) already made every reachable plane a real
## `WorldHistory` subject with `kind: "plane"` and an empty `relations` table.
## This file is what those subjects then *do* with a memory: accumulate a
## standing across trips, speak through it, withhold through it, lend against
## it, collect on it, and disagree with each other about a kill.
##
## Two rules hold the whole file together, and every function below is written
## to obey them rather than to decorate them:
##
##   1. **No meter (AV3.3).** Standing is never printed. It is expressed as how
##      much of what the entity actually said arrives intact. A low-standing
##      line comes through with holes in it; the same line at high standing
##      arrives byte-for-byte whole. The transform is deterministic per
##      (plane, subject, word), so the same entity mangles the same word the
##      same way every time — that consistency *is* the memory being legible.
##      And it is monotone: a word that survives at low clarity survives at
##      every higher clarity, so the readout only ever *clears*, it never
##      reshuffles into a different sentence.
##
##   2. **Withholding, never vagueness (AV3.4).** `ask()` never returns mush.
##      Either the plane genuinely does not know the thing (`ok: false`, said
##      plainly), or it knows a specific, true, derived-from-history answer and
##      either hands it over or refuses it by name. A refusal carries `known:
##      true`, what *kind* of thing is being kept, and the standing that would
##      buy it. The withheld string exists in full the whole time and is
##      recoverable verbatim once standing clears — that is what makes it
##      withholding rather than an empty branch.
##
## Ownership: this file reads planes as subjects (name/role/order, all of
## which `Sephiroth.register_planes()` already stored) and never imports
## `sephiroth.gd`, so the dependency runs one way only — `sephiroth.gd` calls
## in here to let creditors collect, and nothing here calls back.

const Ledger := preload("res://systems/boons.gd")

# --- AV3.2. What a trip is worth ---------------------------------------------
## A relationship accumulates out of acts already recorded by other systems —
## the same discipline `Sephiroth.altitude()` and `AscentEntities.regard()`
## both use. There is no `set_standing()` anywhere in this file: the only way
## a plane thinks better of you is to actually go there, actually pay, and
## actually not fall off it mid-sentence.
const TRIP_WEIGHT := {
	"plane_petitioned": 0.14,       # you came, you named it, you paid to be seen
	"plane_departed": 0.06,         # and you closed the door on the way out
	"plane_altitude_failed": -0.22, # AV2.3 — you came down mid-sentence
	"plane_debt_paid": 0.18,        # AV3.5 — it collected and you had it
	"plane_debt_defaulted": -0.50,  # AV3.5 — it collected and you did not
}
## AV3.6 feeding AV3.2: a plane that approved of one of your kills thinks
## better of you for it, and the plane on the opposite pillar thinks worse —
## which is the whole point of them disagreeing.
const VERDICT_WEIGHT := 0.20
const STANDING_FLOOR := -1.0
const STANDING_CEILING := 1.0

# --- AV3.3. Clarity, which is the only readout standing ever gets ------------
## At standing 0 (a stranger) about a seventh of a line survives. It clears
## fully at `CLEARS_AT`, which is five clean petitions' worth — a relationship,
## not a purchase. Below 0 even the floor erodes, so a plane you have defaulted
## on is genuinely close to unreadable.
const CLARITY_FLOOR := 0.15
const CLEARS_AT := 0.70
## Of the words that do not arrive whole, this fraction arrive as a consonant
## skeleton rather than vanishing — a bad signal, not a redaction bar.
const SKELETON_SHARE := 0.45

# --- AV3.7. Demonic and jesterish is the register ----------------------------
## The jester is already on the handheld (I0.5, `BlackMirror.draw_jester`) —
## this is the other half of that joke, the voice that goes with the face on
## the back of the case. The register is made mechanical rather than decorative
## by one rule, enforced in `speak()`: **the jest never distorts; the truth
## always does.** The fool is louder than the oracle, so at zero standing what
## reaches you is a complete, perfectly legible taunt wrapped around a sentence
## with holes in it. Getting the truth out of them is the work.
const MASK := {
	"malkuth": {"mask": "THE BAILIFF", "jest": "oh, look who walked here. on legs. like an animal."},
	"yesod": {"mask": "THE STATIC IMP", "jest": "i can hear you. that is not the same as listening, little aerial."},
	"hod": {"mask": "THE CLERK OF FLIES", "jest": "your file is thin. i have read thinner. not much thinner."},
	"netzach": {"mask": "THE WANTING THING", "jest": "you want. adorable. everything here wants. get in line, get in line."},
	"tiferet": {"mask": "THE MIRROR THAT SCORES", "jest": "stand there. no — there. yes. now be measured, and try not to cry about it."},
	"gevurah": {"mask": "THE RED ASSESSOR", "jest": "another debtor. ha! bring the small knife, we will be here a while."},
	"chesed": {"mask": "THE GRINNING ALMONER", "jest": "mercy! mercy, he says, with those hands. i love this bit. i love this bit."},
	"binah": {"mask": "THE DARK MIDWIFE", "jest": "something is being born out of you and you will not enjoy meeting it."},
	"chokmah": {"mask": "THE SCREAMING POINT", "jest": "there is no pipe in you narrow enough for this. i will pour anyway. ha."},
	"keter": {"mask": "THE LAST DOORMAN", "jest": "you are at the end of the addresses. past me there is no one to be rude to."},
}
const DEFAULT_MASK := {"mask": "SOMETHING WITH A GRIN ON IT", "jest": "no name here. you will not miss it."}

# --- AV3.6. The two pillars, which is why they cannot agree ------------------
## Not invented: this is the Tree's own left/right/middle pillar split, and the
## roles `Sephiroth.PLANES` already carries agree with it ("Severity — every
## debt this world has ever written down" against "Mercy"). Because it is
## structural, the disagreement in AV3.6 falls out for free the way AJ5.4's
## does in `modern_gods.gd` — nobody authored four opinions, the same real
## number is read through opposite institutional obsessions.
const PILLAR := {
	"binah": "severity", "gevurah": "severity", "hod": "severity",
	"chokmah": "mercy", "chesed": "mercy", "netzach": "mercy",
	"keter": "middle", "tiferet": "middle", "yesod": "middle", "malkuth": "middle",
}
const CALLED_IN := "A DEBT CALLED IN"
const MERCY_WITHHELD := "A MERCY WITHHELD"
const PILLAR_BIAS := 0.6
const PILLAR_BIAS_WEAK := 0.2

# --- AV3.5. Debt ---------------------------------------------------------------
## Defaulting does not clear the debt, it grows it. A plane you could not pay
## is a plane that will take more next time you set foot on it.
const DEFAULT_INTEREST := 1.35

# --- AV3.4. What each plane knows, and what it costs to be told ---------------
## Every one of these is *derived* — a real count, a real name, a real number
## out of `WorldHistory` — never an authored secret. The `withholding` line is
## the discipline made concrete: it names the shape of the thing being kept so
## a refusal is informative about its own contents without leaking them.
const KNOWLEDGE := {
	"your_debt": {
		"threshold": -1.0,
		"withholding": "",
	},
	"your_falls": {
		"threshold": 0.25,
		"withholding": "I HAVE THE COUNT. EVERY TIME YOU SLID OFF ME MID-SENTENCE, AND WHICH WORD YOU WERE ON. IT IS A NUMBER AND I AM SITTING ON IT.",
	},
	"the_dead": {
		"threshold": 0.45,
		"withholding": "THERE IS A LIST OF NAMES IN MY BOOK WITH YOUR HAND ON THEM. THE BOOK IS SHUT. THE BOOK IS NOT EMPTY.",
	},
	"who_watches": {
		"threshold": 0.60,
		"withholding": "SOMETHING LARGE HAS ITS EYE ON YOU AND I KNOW ITS NAME AND HOW MANY TIMES YOU MADE IT LOOK. YOU HAVE NOT PAID FOR THE NAME.",
	},
	"the_disagreement": {
		"threshold": 0.80,
		"withholding": "ONE OF MY NEIGHBOURS CALLED A DEATH THE OPPOSITE OF WHAT I CALLED IT. I KNOW WHICH ONE AND I KNOW WHICH DEATH. THAT IS THE EXPENSIVE SHELF.",
	},
}


# =============================================================================
# AV3.2 — a relationship accumulates across trips
# =============================================================================

## Pure read over acts already recorded. Because the events persist, this is
## genuinely cumulative across trips: departing a plane does not reset it, and
## the same five petitions read the same on the tenth visit as on the sixth.
static func standing(plane_id: String, subject_id: String) -> float:
	if str(WorldHistory.subject(plane_id).get("kind", "")) != "plane":
		return 0.0
	var total := 0.0
	for event in WorldHistory.events:
		var details: Dictionary = event.get("details", {})
		if str(details.get("plane_id", "")) != plane_id:
			continue
		var event_type := str(event.get("type", ""))
		if event_type == "plane_verdict":
			if str(details.get("killer_id", "")) != subject_id:
				continue
			total += float(details.get("lean", 0.0)) * VERDICT_WEIGHT
			continue
		if str(details.get("subject_id", "")) != subject_id:
			continue
		total += float(TRIP_WEIGHT.get(event_type, 0.0))
	return clampf(total, STANDING_FLOOR, STANDING_CEILING)


## How many times this subject has actually stood on this plane. Exposed
## because "across trips" should be a countable fact, not an impression.
static func trips(plane_id: String, subject_id: String) -> int:
	var count := 0
	for event in WorldHistory.events:
		if str(event.get("type", "")) != "plane_petitioned":
			continue
		var details: Dictionary = event.get("details", {})
		if str(details.get("plane_id", "")) == plane_id and str(details.get("subject_id", "")) == subject_id:
			count += 1
	return count


## Writes the derived standing into the plane's own `relations` — the real
## per-subject table `register_planes()` already seeds empty, the same place
## `ModernGods._apply_consequence()` keeps a god's opinion of a killer. The
## derivation above stays the source of truth; this is the copy a dossier or
## the Board can read without scanning history itself. Any debt already on the
## edge is preserved, since debt is stored state and standing is not.
static func remember(plane_id: String, subject_id: String) -> Dictionary:
	var plane := WorldHistory.subject(plane_id)
	if str(plane.get("kind", "")) != "plane":
		return {}
	var relations: Dictionary = (plane.get("relations", {}) as Dictionary).duplicate(true)
	var edge: Dictionary = relations.get(subject_id, {})
	edge["kind"] = "standing"
	edge["standing"] = standing(plane_id, subject_id)
	edge["trips"] = trips(plane_id, subject_id)
	relations[subject_id] = edge
	WorldHistory.amend_subject(plane_id, {"relations": relations})
	return edge


# =============================================================================
# AV3.3 — voice is distorted and clears with standing
# =============================================================================

## The one number standing ever becomes, and it never leaves this file as text.
static func clarity(plane_id: String, subject_id: String) -> float:
	var value := standing(plane_id, subject_id)
	if value <= 0.0:
		return maxf(0.0, CLARITY_FLOOR * (1.0 + value))
	return clampf(CLARITY_FLOOR + (1.0 - CLARITY_FLOOR) * (value / CLEARS_AT), CLARITY_FLOOR, 1.0)


## The transform itself. Word count, word order and punctuation are all
## preserved, so what arrives is plainly the same sentence with holes in it
## rather than a different, vaguer sentence — which would be exactly the
## failure AV3.4 forbids, arriving through the AV3.3 door instead.
static func voice(plane_id: String, subject_id: String, line: String) -> String:
	return distort(line, clarity(plane_id, subject_id), plane_id + "|" + subject_id)


## Exposed separately so the transform can be exercised at a chosen clarity
## without staging a relationship first.
static func distort(line: String, clear: float, salt: String) -> String:
	if clear >= 1.0 or line.is_empty():
		return line
	var words := line.split(" ")
	var out: PackedStringArray = []
	var skeleton_edge := clear + (1.0 - clear) * SKELETON_SHARE
	for index in words.size():
		var word := str(words[index])
		var roll := _roll(salt, index, word)
		if roll < clear:
			out.append(word)
		elif roll < skeleton_edge:
			out.append(_skeleton(word))
		else:
			out.append(_lost(word))
	return " ".join(out)


## Deterministic in (salt, position, word) — no RNG, so the same entity garbles
## the same sentence identically every time you hear it, and the thresholds
## above only widen as clarity rises, which is what makes the readout monotone.
static func _roll(salt: String, index: int, word: String) -> float:
	return float(absi(hash("%s|%d|%s" % [salt, index, word])) % 10007) / 10007.0


## A word that half-arrives: first letter and consonants, vowels gone. Reads as
## a signal problem rather than as a censor's bar.
static func _skeleton(word: String) -> String:
	var out := ""
	var seen_letter := false
	for index in word.length():
		var character := word[index]
		var lower := character.to_lower()
		if lower < "a" or lower > "z":
			out += character
			continue
		if not seen_letter:
			seen_letter = true
			out += character
			continue
		if "aeiou".contains(lower):
			continue
		out += character
	return out


## A word that does not arrive at all. Keeps its own length and its
## punctuation, so the shape of the sentence still tells you something is
## missing there.
static func _lost(word: String) -> String:
	var out := ""
	for index in word.length():
		var character := word[index]
		var lower := character.to_lower()
		if (lower >= "a" and lower <= "z") or (character >= "0" and character <= "9"):
			out += "."
		else:
			out += character
	return out


# =============================================================================
# AV3.7 — the register
# =============================================================================

## The whole readout, in one call: who is grinning at you, the jest (intact,
## always — the fool is louder than the oracle), and the sentence that actually
## matters, arriving in whatever state your standing has earned.
static func speak(plane_id: String, subject_id: String, line: String) -> Dictionary:
	var mask: Dictionary = MASK.get(plane_id, DEFAULT_MASK)
	return {
		"plane_id": plane_id,
		"mask": str(mask.mask),
		"jest": str(mask.jest),
		"line": voice(plane_id, subject_id, line),
		"whole": voice(plane_id, subject_id, line) == line,
	}


## What the black mirror actually prints. The jester is on the back of the case
## (I0.5); this is the voice that goes with it. Deliberately carries no number,
## no bar and no percentage — the state of the sentence is the state of the
## relationship, and that is the entire AV3.3 brief.
static func handheld_readout(plane_id: String, subject_id: String, line: String) -> String:
	var spoken := speak(plane_id, subject_id, line)
	return "%s\n  \"%s\"\n  %s" % [str(spoken.mask), str(spoken.jest), str(spoken.line)]


# =============================================================================
# AV3.4 — mysterious means withholding, never vague
# =============================================================================

## Three outcomes and no fourth. It does not know (said plainly); it knows and
## refuses (naming what it is refusing and what would buy it); it knows and
## tells you, in full.
static func ask(plane_id: String, subject_id: String, topic: String) -> Dictionary:
	if str(WorldHistory.subject(plane_id).get("kind", "")) != "plane":
		return {"ok": false, "reason": "NOTHING THERE TO ASK"}
	if not KNOWLEDGE.has(topic):
		return {"ok": false, "reason": "THAT IS NOT A THING ANYONE HERE KEEPS"}
	var answer := _known(topic, plane_id, subject_id)
	if answer.is_empty():
		# Honest absence. Not a hint, not a maybe — there is genuinely no such
		# fact in the history yet, and saying so costs the plane nothing.
		return {"ok": false, "topic": topic, "known": false, "reason": "I HAVE NOTHING ON THAT. NOT A SECRET. NOTHING."}
	var entry: Dictionary = KNOWLEDGE[topic]
	var threshold := float(entry.threshold)
	if standing(plane_id, subject_id) < threshold:
		return {
			"ok": true, "topic": topic, "known": true, "withheld": true,
			"answer": "", "withholding": str(entry.withholding), "clears_at": threshold,
		}
	return {"ok": true, "topic": topic, "known": true, "withheld": false, "answer": answer, "clears_at": threshold}


## The withheld readout, for the handheld. Note what it does *not* contain: the
## threshold. You are told a specific thing is being kept from you; you are not
## given a progress bar toward it.
static func ask_readout(plane_id: String, subject_id: String, topic: String) -> String:
	var result := ask(plane_id, subject_id, topic)
	if not bool(result.get("ok", false)):
		return handheld_readout(plane_id, subject_id, str(result.get("reason", "")))
	if bool(result.get("withheld", false)):
		return handheld_readout(plane_id, subject_id, str(result.get("withholding", "")))
	return handheld_readout(plane_id, subject_id, str(result.get("answer", "")))


## Every answer below is computed out of recorded history. None of them is a
## stored string waiting to be unlocked, which is what stops AV3.4 collapsing
## into a lore vending machine.
static func _known(topic: String, plane_id: String, subject_id: String) -> String:
	match topic:
		"your_debt":
			var owing := debt(plane_id, subject_id)
			if owing.is_empty():
				return ""
			return "YOU OWE ME %.0f, IN %s, FOR %s. I DO NOT FORGET THE FIGURE." % [
				float(owing.get("amount", 0.0)), str(owing.get("kind", "")).to_upper(),
				str(owing.get("for_what", "NOTHING NAMED")).to_upper(),
			]
		"your_falls":
			var count := 0
			var last_floor := ""
			for event in WorldHistory.events:
				if str(event.get("type", "")) != "plane_altitude_failed":
					continue
				var details: Dictionary = event.get("details", {})
				if str(details.get("plane_id", "")) != plane_id or str(details.get("subject_id", "")) != subject_id:
					continue
				count += 1
				last_floor = str(details.get("floor", ""))
			if count == 0:
				return ""
			return "YOU CAME DOWN OFF ME %d TIMES. THE LAST ONE GAVE OUT AT %s." % [count, last_floor.to_upper()]
		"the_dead":
			var names: Array = []
			for event in WorldHistory.events:
				var event_type := str(event.get("type", ""))
				if event_type != "plane_verdict" and event_type != "death_verdict":
					continue
				var details: Dictionary = event.get("details", {})
				if str(details.get("killer_id", "")) != subject_id:
					continue
				var victim_id := str(details.get("victim_id", ""))
				var victim_name := str(WorldHistory.subject(victim_id).get("name", victim_id))
				if not victim_name.is_empty() and not names.has(victim_name):
					names.append(victim_name)
			if names.is_empty():
				return ""
			return "%d NAMES WENT THROUGH MY BOOK WITH YOUR HAND ON THEM: %s." % [names.size(), ", ".join(PackedStringArray(names)).to_upper()]
		"who_watches":
			var loudest := ""
			var loudest_attention := 0
			for other_id in WorldHistory.all_subjects():
				var other: Dictionary = WorldHistory.subject(str(other_id))
				if str(other.get("kind", "")) != "god":
					continue
				if int(other.get("attention", 0)) > loudest_attention:
					loudest_attention = int(other.get("attention", 0))
					loudest = str(other.get("name", other_id))
			if loudest.is_empty():
				return ""
			return "%s HAS ITS EYE ON YOU. YOU MADE IT LOOK %d TIMES. IT DOES NOT LOOK AWAY." % [loudest.to_upper(), loudest_attention]
		"the_disagreement":
			var mine := {}
			for event in WorldHistory.events:
				if str(event.get("type", "")) != "plane_verdict":
					continue
				var details: Dictionary = event.get("details", {})
				if str(details.get("killer_id", "")) != subject_id:
					continue
				if str(details.get("plane_id", "")) == plane_id:
					mine[str(details.get("victim_id", ""))] = str(details.get("label", ""))
			for event in WorldHistory.events:
				if str(event.get("type", "")) != "plane_verdict":
					continue
				var details: Dictionary = event.get("details", {})
				if str(details.get("killer_id", "")) != subject_id:
					continue
				var other_plane := str(details.get("plane_id", ""))
				if other_plane == plane_id:
					continue
				var victim_id := str(details.get("victim_id", ""))
				if not mine.has(victim_id):
					continue
				var theirs := str(details.get("label", ""))
				if theirs == str(mine[victim_id]) or theirs.is_empty():
					continue
				var other_name := str(WorldHistory.subject(other_plane).get("name", other_plane))
				return "%s CALLED THAT DEATH '%s'. I CALLED IT '%s'. ONE OF US IS LYING TO YOU AND I WILL NOT SAY WHICH." % [
					other_name.to_upper(), theirs, str(mine[victim_id]),
				]
			return ""
	return ""


# =============================================================================
# AV3.5 — they can be owed, and they collect
# =============================================================================

## Real stored state on the plane's own `relations` edge, alongside the standing
## copy — one edge per subject, so "what it thinks of you" and "what it is owed"
## are the same record rather than two that could disagree.
static func debt(plane_id: String, subject_id: String) -> Dictionary:
	var relations: Dictionary = WorldHistory.subject(plane_id).get("relations", {})
	var edge: Dictionary = relations.get(subject_id, {})
	var owing: Dictionary = edge.get("debt", {})
	if float(owing.get("amount", 0.0)) <= 0.0:
		return {}
	return owing


## Taking something on credit. The cost kind is named up front (it is paid
## through `Boons.pay()` like every other real cost in this project), so what
## will eventually be taken out of you is a fact on the record at the moment
## you borrow, not a surprise invented at collection time.
static func owe(plane_id: String, subject_id: String, kind: String, amount: float, for_what: String, target: String = "") -> Dictionary:
	var plane := WorldHistory.subject(plane_id)
	if str(plane.get("kind", "")) != "plane":
		return {"ok": false, "reason": "NOTHING THERE TO OWE"}
	if amount <= 0.0:
		return {"ok": false, "reason": "A DEBT OF NOTHING IS NOT A DEBT"}
	if not Ledger.COST_KINDS.has(kind):
		return {"ok": false, "reason": "IT DOES NOT TAKE PAYMENT IN THAT"}
	var relations: Dictionary = (plane.get("relations", {}) as Dictionary).duplicate(true)
	var edge: Dictionary = relations.get(subject_id, {})
	var owing: Dictionary = edge.get("debt", {})
	var carried := float(owing.get("amount", 0.0))
	edge["kind"] = "standing"
	edge["debt"] = {
		"amount": carried + amount, "kind": kind, "target": target,
		"for_what": for_what, "incurred_sequence": WorldHistory.next_sequence,
	}
	relations[subject_id] = edge
	WorldHistory.amend_subject(plane_id, {"relations": relations})
	WorldHistory.record_event("plane_debt_incurred", {
		"plane_id": plane_id, "subject_id": subject_id, "amount": amount,
		"kind": kind, "for_what": for_what,
	})
	remember(plane_id, subject_id)
	return {"ok": true, "owed": carried + amount}


## The collection. Not a request — it calls `Boons.pay()` straight out of the
## body or the standing, exactly as if the plane had reached in and taken it,
## because that is what being collected on means.
##
## If the body cannot cover it, this is a default: the debt is not forgiven,
## it grows by `DEFAULT_INTEREST`, and the plane's opinion of you falls further
## in one act than three clean trips raised it. Which is also, through
## `clarity()`, the moment it stops being able to be heard properly at all.
static func collect(plane_id: String, subject_id: String) -> Dictionary:
	var owing := debt(plane_id, subject_id)
	if owing.is_empty():
		return {"ok": true, "collected": 0.0}
	var amount := float(owing.get("amount", 0.0))
	var kind := str(owing.get("kind", ""))
	var payment := Ledger.pay(subject_id, kind, amount, str(owing.get("target", "")))
	if bool(payment.get("ok", false)):
		_write_debt(plane_id, subject_id, {})
		WorldHistory.record_event("plane_debt_paid", {
			"plane_id": plane_id, "subject_id": subject_id, "amount": amount, "kind": kind,
		})
		remember(plane_id, subject_id)
		return {"ok": true, "collected": amount, "kind": kind}
	var grown := amount * DEFAULT_INTEREST
	var next: Dictionary = owing.duplicate(true)
	next["amount"] = grown
	_write_debt(plane_id, subject_id, next)
	WorldHistory.record_event("plane_debt_defaulted", {
		"plane_id": plane_id, "subject_id": subject_id, "amount": amount,
		"kind": kind, "now_owed": grown, "reason": str(payment.get("reason", "")),
	})
	remember(plane_id, subject_id)
	return {"ok": false, "reason": str(payment.get("reason", "")), "now_owed": grown, "defaulted": true}


## Every creditor takes its cut. Called by `Sephiroth.petition()` before the
## offering is even weighed, so setting foot anywhere is when the whole tree
## settles up with you — you do not get to visit a plane you can afford while
## dodging the one you cannot.
static func collect_due(subject_id: String) -> Array:
	var results: Array = []
	for plane_id in WorldHistory.all_subjects():
		var id := str(plane_id)
		if str(WorldHistory.subject(id).get("kind", "")) != "plane":
			continue
		if debt(id, subject_id).is_empty():
			continue
		var result := collect(id, subject_id)
		result["plane_id"] = id
		results.append(result)
	return results


static func _write_debt(plane_id: String, subject_id: String, owing: Dictionary) -> void:
	var plane := WorldHistory.subject(plane_id)
	var relations: Dictionary = (plane.get("relations", {}) as Dictionary).duplicate(true)
	var edge: Dictionary = relations.get(subject_id, {})
	if owing.is_empty():
		edge.erase("debt")
	else:
		edge["debt"] = owing
	relations[subject_id] = edge
	WorldHistory.amend_subject(plane_id, {"relations": relations})


# =============================================================================
# AV3.6 — they disagree with each other the way the gods do about a kill
# =============================================================================

## Deliberately the same shape as `ModernGods.verdict()`, not a second one: the
## victim's own `tree_alignment()` sets the base lean, then one institutional
## obsession — here the pillar rather than the brand — reads that same real
## number its own way. A verdict is one plane's opinion, attributed, and it is
## never summed with anyone else's.
static func plane_verdict(plane_id: String, victim_id: String, details: Dictionary = {}) -> Dictionary:
	var plane := WorldHistory.subject(plane_id)
	if str(plane.get("kind", "")) != "plane":
		return {}
	var victim := WorldHistory.subject(victim_id)
	if victim.is_empty():
		return {}
	var lean := -WorldHistory.tree_alignment(victim)
	var extracted := bool(details.get("harvested", false)) or bool(details.get("contracted", false))
	var spectacle := bool(details.get("public", false)) or int(details.get("witnessed", 0)) >= 3
	match str(PILLAR.get(plane_id, "middle")):
		"severity":
			# Severity reads a kill as a ledger entry: a price was extracted, so
			# an account closed. One taken for nothing is just waste.
			lean += PILLAR_BIAS if extracted else PILLAR_BIAS_WEAK
		"mercy":
			# Mercy reads the same kill as the failure it was, and reads it
			# worst when it was performed for an audience.
			lean -= PILLAR_BIAS if spectacle else PILLAR_BIAS_WEAK
		"middle":
			# The middle pillar has no obsession to read it through, so the
			# victim's own alignment is the whole verdict — and on a victim who
			# never leaned either way, it genuinely has nothing to say.
			pass
	lean = clampf(lean, -1.0, 1.0)
	var label := CALLED_IN if lean > 0.0 else MERCY_WITHHELD
	if is_zero_approx(lean):
		label = "UNDECIDED — EVEN %s WILL NOT CALL IT" % str(MASK.get(plane_id, DEFAULT_MASK).mask)
	return {
		"plane": str(plane.get("name", plane_id)), "plane_id": plane_id,
		"victim": victim_id, "label": label, "lean": lean,
		"pillar": str(PILLAR.get(plane_id, "middle")),
	}


## Two verdicts on one death is the normal outcome and neither is corrected
## against the other. Each is recorded as its own attributed opinion, and each
## moves that one plane's standing with the killer — which is how a
## disagreement stops being flavour: after a contracted kill, Gevurah can hear
## you better than it could and Chesed can hear you worse.
static func record_plane_verdicts(victim_id: String, killer_id: String, details: Dictionary = {}, plane_ids: Array = []) -> Array:
	var asked: Array = plane_ids
	if asked.is_empty():
		asked = PILLAR.keys()
	var results: Array = []
	for plane_id in asked:
		var id := str(plane_id)
		var result := plane_verdict(id, victim_id, details)
		if result.is_empty():
			continue
		results.append(result)
		WorldHistory.record_event("plane_verdict", {
			"plane_id": id, "victim_id": victim_id, "killer_id": killer_id,
			"label": str(result.label), "lean": float(result.lean),
		})
		remember(id, killer_id)
	return results


## The disagreement itself, as a readable fact rather than something a caller
## has to notice by diffing two lists — which planes called one death one way
## and which called it the other.
static func disagreement(victim_id: String, killer_id: String) -> Dictionary:
	var split := {CALLED_IN: [], MERCY_WITHHELD: []}
	for event in WorldHistory.events:
		if str(event.get("type", "")) != "plane_verdict":
			continue
		var details: Dictionary = event.get("details", {})
		if str(details.get("victim_id", "")) != victim_id or str(details.get("killer_id", "")) != killer_id:
			continue
		var label := str(details.get("label", ""))
		if split.has(label):
			(split[label] as Array).append(str(details.get("plane_id", "")))
	return split
