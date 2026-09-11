extends RefCounted

## The cursor is a tool, and one of its buttons sees through people.
##
## Greg: *"once you use the custom mouse it has a circular xray button you can
## click just for a gross factor and visceral elements"*, and separately that
## the radial replaces sliders for weapons, cybernetics, modes and seals. So
## this is deliberately built as **one segment of a ring that will hold more
## segments**, not as a bespoke X-ray widget — C2 extends it rather than
## replacing it.
##
## The important design consequence, and the reason it is a cursor rather than a
## mode: seeing inside a body becomes a *constant available verb* instead of
## something you enter and leave. That is what `DESIGN/INTERFACE_DIRECTION.md`
## means by everything being inspectable, and it is the difference between the
## anatomy system being a feature and being the texture of the game.
##
## Drawn into a caller's canvas like `CellOutzType` and `CellOutzGrunge`, so any
## screen can carry it without owning a node.

const CellOutzType := preload("res://systems/celloutz_type.gd")

const RING := 26.0
const BUTTON_ARC := 0.92
const BUTTON_CENTRE := -PI * 0.5

const BRASS := Color("b0552a")
const BONE := Color("e6d4ac")
const HOT := Color("a8281a")
const SOOT := Color(0.05, 0.036, 0.028, 0.88)


## Is this click on the X-ray segment? Callers ask before their own hit tests,
## because the cursor sits on top of everything.
static func on_button(cursor_at: Vector2, click_at: Vector2) -> bool:
	var offset := click_at - cursor_at
	var distance := offset.length()
	if distance < RING * 0.55 or distance > RING * 1.45:
		return false
	var angle := offset.angle()
	var delta := angle_difference(angle, BUTTON_CENTRE)
	return absf(delta) <= BUTTON_ARC * 0.5


static func draw(canvas: CanvasItem, at: Vector2, active: bool, elapsed: float) -> void:
	# A scratched brass ring, not a neon circle. The ring is drawn in broken
	# segments so it reads as a worn machined part.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	var segments := 46
	for index in segments:
		if rng.randf() < 0.14:
			continue
		var from := TAU * float(index) / float(segments)
		var to := TAU * float(index + 1) / float(segments)
		canvas.draw_arc(at, RING, from, to, 3, BRASS * Color(1, 1, 1, 0.55 + rng.randf() * 0.35), 2.0)

	# The X-ray segment: a thicker arc with its own ground, so it reads as a
	# physical button on the ring rather than a highlight.
	var lit: Color = HOT if active else BONE * Color(1, 1, 1, 0.62)
	canvas.draw_arc(at, RING, BUTTON_CENTRE - BUTTON_ARC * 0.5, BUTTON_CENTRE + BUTTON_ARC * 0.5, 18, SOOT, 11.0)
	canvas.draw_arc(at, RING, BUTTON_CENTRE - BUTTON_ARC * 0.5, BUTTON_CENTRE + BUTTON_ARC * 0.5, 18, lit, 3.0)
	# A skull mark on the button, small enough to read as an icon at cursor size.
	var mark := at + Vector2(0, -RING)
	canvas.draw_circle(mark, 4.2, lit * Color(1, 1, 1, 0.9 if active else 0.55))
	canvas.draw_rect(Rect2(mark + Vector2(-2.6, 2.2), Vector2(5.2, 2.6)), lit * Color(1, 1, 1, 0.9 if active else 0.55))
	canvas.draw_rect(Rect2(mark + Vector2(-1.9, -1.4), Vector2(1.5, 1.8)), SOOT)
	canvas.draw_rect(Rect2(mark + Vector2(0.5, -1.4), Vector2(1.5, 1.8)), SOOT)

	# The remaining arc is left empty on purpose - it is where C2's weapon,
	# cybernetic and seal segments go, and showing the empty seats makes the
	# cursor read as an unfinished tool rather than as a decoration.
	for slot in 3:
		var angle := BUTTON_CENTRE + TAU * float(slot + 1) / 4.0
		var seat := at + Vector2(cos(angle), sin(angle)) * RING
		canvas.draw_circle(seat, 2.6, BRASS * Color(1, 1, 1, 0.30))

	# The pointer itself: a gap-centred cross, so the exact pixel stays visible.
	var pulse := 1.0 + sin(elapsed * 3.1) * 0.06
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		canvas.draw_line(at + axis * 5.0, at + axis * 12.0 * pulse, BONE * Color(1, 1, 1, 0.75), 1.4)
	canvas.draw_circle(at, 1.6, HOT if active else BONE)

	if active:
		# A dashed outer ring while it is on, so the state is unmistakable at a
		# glance without a label sitting next to the pointer.
		var ticks := 20
		for index in ticks:
			var from := TAU * float(index) / float(ticks) + elapsed * 0.6
			canvas.draw_arc(at, RING + 7.0, from, from + 0.1, 3, HOT * Color(1, 1, 1, 0.5), 1.6)
		CellOutzType.draw_text(canvas, at + Vector2(RING + 14.0, -6.0), "XRAY", 9.0, HOT, 1.0)
