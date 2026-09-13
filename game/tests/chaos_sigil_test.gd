extends Node

## AJ1.1-AJ1.3. "State the intent, strip the repeating letters, condense
## what is left into a glyph" — the first half of the chaos-magick procedure
## Greg named directly. Deterministic from the intent alone: the same words
## always make the same sigil, and nothing here duplicates or replaces
## celloutz_type.gd's existing seal-drawing engine, only feeds it a seed.

const ChaosSigil := preload("res://systems/chaos_sigil.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	print("AJ1 - stating an intent and watching it condense")
	check(ChaosSigil.condense("I WANT TO WIN") == "WNT", "repeats drop (first occurrence kept), vowels drop once consonants survive (%s)" % ChaosSigil.condense("I WANT TO WIN"))
	check(ChaosSigil.condense("i want   to win") == "WNT", "case and whitespace noise do not change the result")
	check(ChaosSigil.condense("AEIOU") == "AEIOU", "a vowel-only intent keeps its vowels rather than condensing to nothing")
	check(ChaosSigil.condense("!!! ??? 123") == "", "an intent with no real letters condenses to nothing rather than crashing")

	print("AJ1.3 - the same words always make the same sigil")
	var first := ChaosSigil.seed_for("I want to be seen")
	var second := ChaosSigil.seed_for("I WANT TO BE SEEN")
	check(first == second, "case alone never changes the seed (%d vs %d)" % [first, second])
	check(first != ChaosSigil.seed_for("I want to be hidden"), "a genuinely different intent gets a genuinely different seed")
	check(ChaosSigil.seed_for("") == 0, "an empty intent is the honest zero, not a fabricated seed")

	print("AJ1 - the whole procedure as one object")
	var sigil := ChaosSigil.seal_for("  Burn the debt collector's ledger  ")
	check(sigil.get("intent", "") == "Burn the debt collector's ledger", "surrounding whitespace is trimmed from what is actually stated")
	check(str(sigil.get("condensed", "")).length() > 0, "a real intent always condenses to something drawable")
	check(int(sigil.get("seed", -1)) == ChaosSigil.seed_for("Burn the debt collector's ledger"), "the packaged seed matches what seed_for() alone would give")
	check(ChaosSigil.seal_for("   ").is_empty(), "a blank intent is refused rather than producing an empty sigil")

	print("CHAOS_SIGIL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
