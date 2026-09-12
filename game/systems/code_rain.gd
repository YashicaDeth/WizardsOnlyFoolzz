class_name CodeRain
extends RefCounted

## I1. Code as a material rather than a backdrop.
##
## The distinction the checklist draws is the whole of it: falling characters
## behind a panel are wallpaper, and every game has them. Here the rain is a
## *surface*, and panels are cut out of it — the holes are what you read
## through, so the code is the plate and the interface is the hole rather than
## the other way round (I1.3).
##
## The vocabulary is the game's own (I1.1). No katakana, no hex dumps: this
## world's screens are full of zone names, organ names, faction ids, scrip
## amounts and the words CellOutz prints on its own products. A player who
## looks closely at the noise should recognise it.
##
## And it fails where the reader fails (I1.2), through the same
## `VitalitySignal` the panels use, so the substrate and the plate degrade
## together instead of arguing about how hurt you are.

## Drawn from the vocabularies the rest of the game already uses. Anything
## added to a zone list or an implant catalogue belongs here too.
const WORDS := [
	"HEAD", "TORSO", "LEFT ARM", "RIGHT ARM", "LEFT LEG", "RIGHT LEG",
	"BRAIN", "HEART", "LEFT LUNG", "RIGHT LUNG", "LIVER", "GUT", "SPINE",
	"ASHLINE", "BLACK MILE", "SOFT ROT", "CHOIR OF MARROW", "GATE LANTERNS",
	"CELLOUTZ", "WIZARDSONLYFOOLZ", "ASCENT", "LIMBO", "DESCENT",
	"WRATH", "GREED", "GLUTTONY", "ENVY", "PRIDE", "LUST", "SLOTH",
	"RUST SCRIP", "LIEN", "UNVERIFIED", "SPECIMEN", "NO REFUND",
	"CONDITION", "SOUND", "RUPTURED", "SEVERED", "STABILISED",
	"REACH", "STRAIN", "WITNESS", "GRUDGE", "BOND", "KARMA",
]

## A column falls at its own rate and holds one word, so the rain reads as
## legible material rather than as a character soup.
class Column extends RefCounted:
	var x := 0.0
	var head := 0.0
	var speed := 1.0
	var word := ""
	var seed_value := 0


static func build(width: float, height: float, spacing: float, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var columns: Array = []
	var x := spacing * 0.5
	while x < width:
		var column := Column.new()
		column.x = x
		column.head = rng.randf() * height
		column.speed = 14.0 + rng.randf() * 46.0
		column.word = WORDS[rng.randi() % WORDS.size()]
		column.seed_value = rng.randi()
		columns.append(column)
		x += spacing
	return columns


static func advance(columns: Array, delta: float, height: float) -> void:
	for column in columns:
		column.head += column.speed * delta
		if column.head > height + 120.0:
			column.head = -20.0
			column.word = WORDS[absi(column.seed_value + int(column.head)) % WORDS.size()]


## Draws the rain, then punches `holes` out of it. A hole is a Rect2 the rain
## does not fall through — the panel sits in it, so the interface reads as cut
## out of the material rather than laid on top of it.
static func draw_field(canvas: CanvasItem, rect: Rect2, columns: Array, tint: Color, level: float, clock: float, holes: Array = []) -> void:
	var cell := 13.0
	for column in columns:
		var letters: int = column.word.length()
		for index in letters:
			var at := Vector2(rect.position.x + column.x, rect.position.y + column.head - float(index) * cell)
			if at.y < rect.position.y - cell or at.y > rect.end.y:
				continue
			var inside_hole := false
			for hole in holes:
				if (hole as Rect2).grow(4.0).has_point(at):
					inside_hole = true
					break
			if inside_hole:
				continue
			# The head of the column is bright and the tail falls away, which is
			# what makes it read as falling rather than as a static grid.
			var fade := 1.0 - float(index) / float(maxi(letters, 1))
			# Counted back from the end so the word reads top to bottom the way
			# it is written. Indexing forward from the falling head printed
			# every word in the game reversed.
			var glyph: String = column.word.substr(letters - 1 - index, 1)
			var wobble := VitalitySignal.jitter(level, column.seed_value + index, clock)
			CellOutzType.draw_text(canvas, at + wobble, glyph, 11.0, tint * Color(1, 1, 1, (0.10 + fade * 0.5) * VitalitySignal.ink(level)), 0.0)
