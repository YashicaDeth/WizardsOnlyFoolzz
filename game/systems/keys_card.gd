class_name KeysCard
extends Control

## What can be pressed, on demand, in the game's own face.
##
## AG2.1-AG2.4 and AG3.5, which are all the same fault reported four times. From
## the 12 September playtest: the tester could not find the Board *and Greg could
## not remember the key either*; nothing teaches the weapon wheel, so Greg had to
## guess (*"i think its holding b?"* — correct, and only because he wrote it);
## and the derby says nothing about any key at all. The record's own summary of
## how a player currently learns this game is *"press buttons probably"*.
##
## `gothic_field_hud.gd` already draws a contextual strip and that strip is
## right: it names the two or three verbs that apply to what you are looking at
## *now*, and it fades as you stop needing it. What it deliberately does not do
## is list the panels — the index, the map, the tree, the Board — because a
## permanent list of every key in the game drawn over the world is exactly the
## tutorial look I3 removed.
##
## So this is the other half, and it is a card rather than a strip: nothing until
## it is asked for, everything when it is. The scene hands it its own rows, so
## the card can never drift from what that scene actually binds — the derby's
## card lists the derby's keys because the derby wrote them, not because this
## file holds a table of what it assumes the game does.

const CellOutzType := preload("res://systems/celloutz_type.gd")

const BONE := Color("ead4ad")
const BLOOD := Color("a81716")
const COPPER := Color("dc5827")
const VOID := Color(0.02, 0.01, 0.012, 0.93)

## How fast the card comes up and goes away. Fast enough not to be a wait,
## slow enough that it reads as something being held up rather than a popup.
const FADE_PER_SECOND := 6.5

## Groups of rows: `{"group": "MOVING", "rows": [["WASD", "MOVE"], ...]}`.
var groups: Array = []
## The key that opens this, printed on the closed-state hint so the hint can
## never name a key the scene did not actually bind to it.
var open_key := "F1"
var is_open := false
## Drawn rather than toggled, so the card fades instead of appearing.
var shown := 0.0
## AG2.3. The hint fades once, after the player has opened the card a couple of
## times and therefore knows it is there. It does not come back, because a
## permanent prompt for a help screen is the tutorial look arriving by the back
## door. Counted rather than timed: somebody who never opens it keeps being told.
var opened_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)


## Called by the scene, with that scene's own bindings.
func configure(key_label: String, card_groups: Array) -> void:
	open_key = key_label
	groups = card_groups
	queue_redraw()


func toggle() -> void:
	is_open = not is_open
	if is_open:
		opened_count += 1
	queue_redraw()


func close() -> void:
	is_open = false


func _process(delta: float) -> void:
	var target := 1.0 if is_open else 0.0
	if is_equal_approx(shown, target):
		return
	shown = move_toward(shown, target, delta * FADE_PER_SECOND)
	queue_redraw()


func _draw() -> void:
	if shown <= 0.001:
		_draw_hint()
		return
	_draw_card()


## The closed state. One line, in the corner, naming the key — because a help
## screen nobody knows about is worth exactly as much as no help screen.
func _draw_hint() -> void:
	if opened_count >= 2:
		return
	var at := Vector2(size.x - 128.0, size.y - 26.0)
	var cursor := CellOutzType.draw_condensed(self, at, open_key, 11.0, Color(COPPER, 0.8), 2.0)
	CellOutzType.draw_condensed(self, at + Vector2(cursor + 8.0, 0.0), "KEYS", 10.0, Color(BONE, 0.5), 1.6)


func _draw_card() -> void:
	var alpha := shown
	# Sized from the content rather than fixed, so a scene with fewer bindings
	# gets a smaller card instead of a mostly empty one.
	var rows_in_longest := 0
	for group: Dictionary in groups:
		rows_in_longest = maxi(rows_in_longest, (group.get("rows", []) as Array).size())
	var columns := groups.size()
	if columns <= 0:
		return
	var column_width := 232.0
	var row_height := 21.0
	var plate := Vector2(
		column_width * float(columns) + 56.0,
		rows_in_longest * row_height + 122.0)
	var origin := (size - plate) * 0.5

	# The plate. Dimmed world behind it rather than a hard cut, because the card
	# is held up in front of the world, not a screen the world went away for.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55 * alpha))
	draw_rect(Rect2(origin, plate), Color(VOID, VOID.a * alpha))
	draw_rect(Rect2(origin, plate), Color(COPPER, 0.35 * alpha), false, 1.4)
	# Corner ticks, the same furniture the index and the map already use.
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var at := origin + Vector2(corner.x * plate.x, corner.y * plate.y)
		var step := Vector2(14.0 * (1.0 if corner.x < 0.5 else -1.0), 0.0)
		var drop := Vector2(0.0, 14.0 * (1.0 if corner.y < 0.5 else -1.0))
		draw_line(at, at + step, Color(COPPER, 0.8 * alpha), 2.0)
		draw_line(at, at + drop, Color(COPPER, 0.8 * alpha), 2.0)

	CellOutzType.draw_stamped(self, origin + Vector2(28.0, 34.0), "KEYS", 22.0,
		Color(COPPER, alpha), Color(BLOOD, 0.35 * alpha), 3.2)
	CellOutzType.draw_condensed(self, origin + Vector2(28.0, 60.0),
		"CELLOUTZ FIELD ISSUE / WHAT THIS BODY CAN BE MADE TO DO", 9.0,
		Color(BONE, 0.45 * alpha), 0.9)
	draw_line(origin + Vector2(28.0, 74.0), origin + Vector2(plate.x - 28.0, 74.0),
		Color(COPPER, 0.3 * alpha), 1.0)

	for index: int in groups.size():
		var group: Dictionary = groups[index]
		var column := origin + Vector2(28.0 + column_width * float(index), 98.0)
		CellOutzType.draw_condensed(self, column, str(group.get("group", "")), 10.0,
			Color(BLOOD, 0.95 * alpha), 2.2)
		var y := 20.0
		for row: Array in (group.get("rows", []) as Array):
			# The key in the readable copper, the verb quieter beside it — the
			# same weighting the field strip uses, so the two teach the same
			# hierarchy rather than each inventing one.
			CellOutzType.draw_condensed(self, column + Vector2(0.0, y), str(row[0]), 10.5,
				Color(COPPER, 0.92 * alpha), 1.8)
			CellOutzType.draw_condensed(self, column + Vector2(84.0, y), str(row[1]), 9.5,
				Color(BONE, 0.62 * alpha), 1.2)
			y += row_height

	CellOutzType.draw_condensed(self, origin + Vector2(28.0, plate.y - 22.0),
		"%s  CLOSE" % open_key, 9.5, Color(BONE, 0.42 * alpha), 1.6)
