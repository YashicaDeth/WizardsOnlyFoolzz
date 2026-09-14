extends Node2D

## A1.7. A specimen sheet for the ten glyphs added this pass, plus the wrapper,
## the alignment and the clip — rendered and written out, because stroke data
## that parses is not the same as stroke data that reads. Every one of these
## glyphs was authored as numbers on a 6x10 grid; the only way to know an arrow
## looks like an arrow at 10px is to look at it.

const TYPE := preload("res://systems/celloutz_type.gd")

const INK := Color(0.91, 0.89, 0.84)
const DIM := Color(0.55, 0.53, 0.49)
const RULE := Color(0.24, 0.23, 0.22)
const GROUND := Color(0.07, 0.07, 0.08)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(880, 560)
	await RenderingServer.frame_post_draw
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var out := "res://captures/a1_7_type_specimen.png"
	shot.save_png(ProjectSettings.globalize_path(out))
	print("TYPE_SPECIMEN_CAPTURE_RESULT saved=", out)
	get_tree().quit(0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(880, 560)), GROUND)

	TYPE.draw_text(self, Vector2(32, 28), "CELLOUTZ TYPE", 22.0, INK, 1.5)
	TYPE.draw_condensed(self, Vector2(32, 62), "TEN GLYPHS THE SCREENS WERE ALREADY ASKING FOR", 9.0, DIM, 0.7)
	draw_line(Vector2(32, 84), Vector2(848, 84), RULE, 1.0)

	# The new glyphs large enough to judge the shapes, then small enough to
	# judge whether they survive the size the screens actually set them at.
	TYPE.draw_text(self, Vector2(32, 108), "·—_\\↑↓←→“”", 44.0, INK, 6.0)
	TYPE.draw_condensed(self, Vector2(32, 176), "·—_\\↑↓←→“”", 10.0, INK, 0.8)
	TYPE.draw_condensed(self, Vector2(150, 176), "AT 10PX, THE SIZE A READOUT USES", 10.0, DIM, 0.8)

	# In the copy they were counted from, rather than in isolation — a glyph can
	# look fine alone and collide with a letter beside it.
	TYPE.draw_condensed(self, Vector2(32, 206), "ASHLINE · LEFT ARM · 0.62 CONDITION", 12.0, INK, 0.7)
	TYPE.draw_condensed(self, Vector2(32, 228), "STANDING ↑ 3 — DEBT ↓ 1 — REACH → TIER TWO", 12.0, INK, 0.7)
	TYPE.draw_condensed(self, Vector2(32, 250), "“HE WENT DOWN IN THE YARD” ← WITNESSED", 12.0, INK, 0.7)
	TYPE.draw_condensed(self, Vector2(32, 272), "FILE_NAME_WITH_UNDERSCORES AND A\\PATH", 12.0, INK, 0.7)

	draw_line(Vector2(32, 300), Vector2(848, 300), RULE, 1.0)

	# The wrapper, drawn inside a real box so an overflow would be visible as an
	# overflow rather than argued about.
	var box := Rect2(Vector2(32, 320), Vector2(300, 180))
	draw_rect(box, RULE, false, 1.0)
	TYPE.draw_condensed(self, Vector2(40, 328), "WRAP_CONDENSED", 8.0, DIM, 0.6)
	TYPE.draw_block(self, Vector2(40, 348), box.size.x - 16.0,
		"THE BONE YARD KEEPS ITS OWN LEDGER AND SETTLES IT LATE — NOBODY LEAVES OWING WHAT THEY CANNOT CARRY",
		11.0, INK, 0.7, 17.0)

	# Alignment, against a rule so the right edge is checkable by eye.
	var rail := Rect2(Vector2(356, 320), Vector2(230, 180))
	draw_rect(rail, RULE, false, 1.0)
	TYPE.draw_condensed(self, Vector2(364, 328), "ALIGNED", 8.0, DIM, 0.6)
	draw_line(Vector2(rail.end.x - 8, 348), Vector2(rail.end.x - 8, 440), RULE, 1.0)
	var rows := {"ROUNDS": "12", "CONDITION": "0.62", "OWED": "1400", "WITNESSES": "3"}
	var y := 352.0
	for label: String in rows:
		TYPE.draw_condensed(self, Vector2(364, y), label, 11.0, DIM, 0.7)
		TYPE.draw_condensed_aligned(self, Vector2(364, y), rail.size.x - 24.0, rows[label], 11.0, INK, 2, 0.7)
		y += 22.0

	# The clip, shown as the same name in three narrowing columns.
	var clip := Rect2(Vector2(610, 320), Vector2(238, 180))
	draw_rect(clip, RULE, false, 1.0)
	TYPE.draw_condensed(self, Vector2(618, 328), "FIT_CONDENSED", 8.0, DIM, 0.6)
	var name := "MARGUERITE OF THE SEVENTH CUT"
	var widths := [214.0, 150.0, 96.0, 54.0, 18.0]
	y = 352.0
	for room: float in widths:
		draw_line(Vector2(618 + room, y - 3), Vector2(618 + room, y + 13), RULE, 1.0)
		TYPE.draw_condensed(self, Vector2(618, y), TYPE.fit_condensed(name, room, 11.0, 0.7), 11.0, INK, 0.7)
		y += 22.0

	TYPE.draw_condensed(self, Vector2(32, 520), "NOTHING BELOW IS THE FALLBACK FONT", 9.0, DIM, 0.7)
