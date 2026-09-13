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
	WorldHistory.record_event("sigil_charged", {"subject_id": subject_id, "intent": sigil.intent, "seed": sigil.seed, "cost_kind": "blood", "cost_paid": cost})
	return {"ok": true, "sigil": sigil}
