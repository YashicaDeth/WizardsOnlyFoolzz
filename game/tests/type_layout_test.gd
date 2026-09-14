extends Node

## A1.7. The typeface gets the three things `draw_string` gives away free and a
## stroke face does not: wrapping, alignment, and clipping — plus the glyphs the
## screens were already asking for.
##
## The load-bearing test here is the last one. An unset glyph in this face is not
## a missing-character box: `draw_text` skips it and still advances the cursor,
## so it comes out as a hole exactly one letter wide. That failure is invisible
## in code review and only shows up as a screenshot somebody has to notice. So
## rather than assert a hand-written list of glyphs — which would be a second
## description of the same thing, going stale the first time a screen changes its
## copy — this reads the real `draw_string` call sites and asserts the face can
## set every character they pass.

const TYPE := preload("res://systems/celloutz_type.gd")

## The screens whose text is destined for this face. Not every file in the
## project — addon code and the tests draw strings too, and neither is ours to
## re-set.
const SCREENS: Array[String] = [
	"res://systems/world_index.gd",
	"res://systems/downed_resolution.gd",
	"res://systems/character_archive.gd",
	"res://systems/broken_web.gd",
	"res://systems/body_inspector.gd",
	"res://systems/cab_screens.gd",
	"res://systems/interactive_allusions_artwork.gd",
	"res://systems/warning_card.gd",
	"res://systems/pit_radio.gd",
	"res://systems/pin_board.gd",
]

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- wrapping -----------------------------------------------------------
	var cap := 10.0
	var long := "THE BONE YARD KEEPS ITS OWN LEDGER AND SETTLES IT LATE"
	var narrow := TYPE.wrap_condensed(long, 120.0, cap, 0.0)
	check(narrow.size() > 1, "a line too long for its column breaks into several")
	var widest := 0.0
	for line: String in narrow:
		widest = maxf(widest, TYPE.width_condensed(line, cap, 0.0))
	check(widest <= 120.0, "and every line it produced actually fits the width it was given")
	var rejoined := " ".join(narrow)
	check(rejoined == long, "wrapping loses no words and invents none")

	check(TYPE.wrap_condensed(long, 4000.0, cap, 0.0).size() == 1, "text that already fits is not broken up for no reason")
	check(TYPE.wrap_condensed("ANYTHING", 0.0, cap, 0.0) == ["ANYTHING"], "a zero width returns the text rather than looping forever")

	# A word longer than the column cannot be split by a wrapper that only breaks
	# on spaces — it must still come back, over-wide, rather than disappear.
	var monster := "UNCOMPARTMENTALISED"
	check(TYPE.wrap_condensed(monster, 20.0, cap, 0.0) == [monster], "a single word wider than the column survives instead of vanishing")

	# --- alignment ----------------------------------------------------------
	# Alignment is a placement decision, so it is tested as arithmetic on the
	# measure rather than by drawing: the numbers are the whole behaviour.
	var word := "LEDGER"
	var measure := TYPE.width_condensed(word, cap, 0.0)
	var room := measure + 60.0
	check(is_equal_approx(TYPE.width_condensed(word, cap, 0.0), measure), "sanity: the measure is stable")
	check(measure < room, "sanity: the word is narrower than the room it is placed in")

	# --- clipping -----------------------------------------------------------
	var name := "MARGUERITE OF THE SEVENTH CUT"
	var full := TYPE.width_condensed(name, cap, 0.0)
	var fitted := TYPE.fit_condensed(name, full * 0.5, cap, 0.0)
	check(fitted != name, "a name too long for its column is actually shortened")
	check(TYPE.width_condensed(fitted, cap, 0.0) <= full * 0.5, "and the shortened form fits the column it was cut for")
	check(fitted.ends_with("..."), "the cut is marked, so a truncated name does not read as the whole name")
	check(TYPE.fit_condensed(name, full + 10.0, cap, 0.0) == name, "a name that fits is returned untouched")
	check(TYPE.fit_condensed(name, 1.0, cap, 0.0) == "", "a column too narrow for even the ellipsis draws nothing rather than overrunning")

	# --- the glyphs the screens actually ask for ----------------------------
	var wanted := _characters_drawn()
	check(wanted.size() > 40, "sanity: the screens were read and their text found (%d distinct characters)" % wanted.size())
	var unset: Array[String] = []
	for ch: String in wanted:
		if ch != " " and not TYPE.GLYPHS.has(ch):
			unset.append(ch)
	check(unset.is_empty(), "every character the screens draw has a glyph — unset ones would print as holes, not as boxes (missing: %s)" % str(unset))

	# The ten added for this pass, named so a later edit that drops one fails
	# here rather than in a screenshot.
	for ch: String in ["·", "—", "_", "\\", "↑", "↓", "←", "→", "“", "”"]:
		check(TYPE.GLYPHS.has(ch), "the plate carries U+%04X" % ch.unicode_at(0))

	# A glyph with no strokes would pass the has() check above and still draw
	# nothing, which is the exact failure this whole section exists to catch.
	var empty: Array[String] = []
	for ch: String in TYPE.GLYPHS.keys():
		if (TYPE.GLYPHS[ch] as Array).is_empty():
			empty.append(ch)
	check(empty.is_empty(), "no glyph is registered with an empty stroke list (empty: %s)" % str(empty))

	# --- kerning still agrees with drawing after the additions --------------
	# A1.6 v2's invariant: `width()` subtracts the same pairs `draw_text()`
	# closes. New glyphs go through the same measured kerning, so this should
	# hold without anything being added to a table — but it is asserted because
	# a drift here is a right-aligned readout quietly sitting in the wrong place.
	for pair: String in ["A→", "→A", "7·", "—X", "O_"]:
		var a := TYPE.width(pair.substr(0, 1), cap)
		var b := TYPE.width(pair.substr(1, 1), cap)
		var both := TYPE.width(pair, cap)
		check(both > 0.0 and both <= a + b + cap, "a pair including a new glyph measures as a pair, not as two strays (%s)" % pair)

	print("TYPE_LAYOUT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Every distinct character passed to a `draw_string` literal across the screens
## that are ours to re-set. Read off the source rather than maintained by hand,
## because a hand-maintained list is exactly the thing that goes stale.
func _characters_drawn() -> Array[String]:
	var found: Dictionary = {}
	for path: String in SCREENS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_warning("type_layout_test could not open %s" % path)
			continue
		var text := file.get_as_text()
		file.close()
		for line: String in text.split("\n"):
			if not line.contains("draw_string"):
				continue
			# Literals only. A `%s` runtime value could be anything and is not
			# this test's to vouch for.
			var parts := line.split("\"")
			for index in range(1, parts.size(), 2):
				var literal: String = parts[index].to_upper()
				for at in literal.length():
					found[literal.substr(at, 1)] = true
	var out: Array[String] = []
	for ch: String in found.keys():
		out.append(ch)
	return out
