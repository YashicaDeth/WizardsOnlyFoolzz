class_name VatsOverlay
extends Control

## What aimed X-ray shows on the glass: every part of one body that can be
## chosen, the chosen one bracketed and named, its plate, what breaking it
## does, and how much held time is left. The body itself is lit by the same
## `reveal_organs()`/`see_through()` the X-ray sweep uses, so this only labels
## what is already visible through the flesh.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("e6d4ac")
const HOT := Color("a8281a")
const BRASS := Color("b0552a")
const SCAN := Color("35b7a7")
const SOOT := Color(0.05, 0.036, 0.028, 0.82)

const EFFECT_WORDS := {"slow": "SLOWS", "blind": "BLINDS", "disarm": "DISARMS"}

## [{"at": Vector2, "part": Dictionary}] for this frame, in the overlay's space.
var marks: Array = []
var selected := -1
var focus_ratio := 0.0
var subject := ""
var _fade := 0.0
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# It has to keep drawing while the world is slowed nearly to a stop.
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_parts(new_marks: Array, chosen: int, focus: float, display_name: String) -> void:
	marks = new_marks
	selected = chosen
	focus_ratio = clampf(focus, 0.0, 1.0)
	subject = display_name


func clear() -> void:
	marks = []
	selected = -1


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	_clock += real
	var was := _fade
	_fade = move_toward(_fade, 1.0 if not marks.is_empty() else 0.0, real * 7.0)
	if _fade > 0.001 or was > 0.001:
		queue_redraw()


func _draw() -> void:
	if _fade <= 0.001:
		return
	var a := _fade
	# The edges close in: the held breath, without hiding the body.
	var band := 46.0
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, band)), SOOT * Color(1, 1, 1, 0.75 * a))
	draw_rect(Rect2(Vector2(0, size.y - band), Vector2(size.x, band)), SOOT * Color(1, 1, 1, 0.75 * a))
	CellOutzType.draw_text(self, Vector2(24, 14), "XRAY // AIMED", 14.0, HOT * Color(1, 1, 1, a), 2.0)
	if not subject.is_empty():
		CellOutzType.draw_text(self, Vector2(220, 14), subject.to_upper(), 14.0, BONE * Color(1, 1, 1, a), 1.5)
	# Held time, draining.
	var bar := Rect2(Vector2(size.x * 0.5 - 160.0, size.y - band * 0.5 - 3.0), Vector2(320.0, 6.0))
	draw_rect(bar, Color(0, 0, 0, 0.6 * a))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * focus_ratio, bar.size.y)), BRASS * Color(1, 1, 1, a))
	for position in marks.size():
		var mark: Dictionary = marks[position]
		if position != selected:
			_draw_mark(mark.at, mark.part, a * 0.75)
	if selected >= 0 and selected < marks.size():
		var chosen: Dictionary = marks[selected]
		_draw_chosen(chosen.at, chosen.part, a)


func _draw_mark(at: Vector2, part: Dictionary, a: float) -> void:
	var plated := VatsTargeting.is_plated(part)
	if plated:
		# Plate reads as plate: a filled square, not a ring.
		draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), BRASS * Color(1, 1, 1, a))
		draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), BONE * Color(1, 1, 1, a * 0.6), false, 1.0)
	elif str(part.get("kind", "")) == "implant":
		draw_arc(at, 5.0, 0.0, TAU, 12, BRASS * Color(1, 1, 1, a), 1.6)
	else:
		draw_arc(at, 4.0, 0.0, TAU, 10, SCAN * Color(1, 1, 1, a), 1.4)


func _draw_chosen(at: Vector2, part: Dictionary, a: float) -> void:
	var pulse := 1.0 + sin(_clock * 6.0) * 0.08
	var r := 16.0 * pulse
	var tone := HOT * Color(1, 1, 1, a)
	# Corner brackets, so the part itself stays visible inside them.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c: Vector2 = at + corner * r
		draw_line(c, c - Vector2(corner.x * 7.0, 0), tone, 2.0)
		draw_line(c, c - Vector2(0, corner.y * 7.0), tone, 2.0)
	draw_circle(at, 2.2, tone)
	# The card beside it, kept on screen.
	var card := Vector2(at.x + 34.0, at.y - 34.0)
	card.x = clampf(card.x, 12.0, size.x - 250.0)
	card.y = clampf(card.y, 60.0, size.y - 140.0)
	draw_line(at + Vector2(r, -r * 0.5), card + Vector2(0, 14), tone * Color(1, 1, 1, 0.6), 1.0)
	draw_rect(Rect2(card, Vector2(236, 74)), SOOT * Color(1, 1, 1, a))
	draw_rect(Rect2(card, Vector2(236, 74)), BRASS * Color(1, 1, 1, a * 0.7), false, 1.0)
	CellOutzType.draw_text(self, card + Vector2(10, 8), str(part.get("label", "")), 12.0, BONE * Color(1, 1, 1, a), 1.0)
	var armour := float(part.get("armour", 0.0))
	var plate_line := "PLATED %d%%" % roundi(armour * 100.0) if VatsTargeting.is_plated(part) else ("PLATE %d%%" % roundi(armour * 100.0) if armour > 0.005 else "BARE")
	CellOutzType.draw_text(self, card + Vector2(10, 30), plate_line, 10.0, (BRASS if armour > 0.005 else SCAN) * Color(1, 1, 1, a), 1.0)
	# Plate pips: one per tenth, so a glance says how much is in the way.
	for pip in mini(8, roundi(armour * 10.0)):
		draw_rect(Rect2(card + Vector2(130 + pip * 11, 30), Vector2(8, 10)), BRASS * Color(1, 1, 1, a))
	var effect := str(part.get("effect", ""))
	var effect_line := "BREAK // %s" % EFFECT_WORDS.get(effect, "") if not effect.is_empty() else "BREAK // RUPTURE"
	CellOutzType.draw_text(self, card + Vector2(10, 50), effect_line, 10.0, HOT * Color(1, 1, 1, a), 1.0)
