class_name WofMark
extends RefCounted

## The Wizards Only Fools seal.
##
## Greg's crew already has a hand sign and it is in every photograph: the palm
## open, the fingers split into two pairs with a gap between middle and ring.
## The thing worth noticing is that **the hand is already the rune**. Two finger
## pairs are the two arms of ᛉ (algiz), the wrist is its stem, and the thumb is
## the outrigger. Nobody had to design a glyph; the sign people were already
## throwing is one.
##
## Which gives the mark its whole argument. Algiz upright is life and
## protection. Algiz reversed — ᛦ — is death. And ᛦ inside a circle is, stroke
## for stroke, the peace badge: Holtom drew semaphore, but the reading this game
## wants is the older bastardisation, the broken cross, the rune turned upside
## down. So the mark is **one hand in two states**, sharing a stem: palm up is
## life, the same hand inverted is death, and the lower half is the peace sign
## that has been sitting there the whole time with its rune the wrong way up.
## Turning it back is not a modification of the symbol. It is a correction.
##
## Drawn rather than drafted: every stroke is jittered off a seeded RNG, so the
## seal is reproducible from a number and never twice identical between seeds.
## That is the same rule the rest of the derived art follows.

## The game's own palette, so the seal is not a second colour system. These are
## `living_map.gd`'s names, and G2.4 is the segment about making that one source
## for the whole HUD rather than a constant per surface.
const VOID := Color("0a0806")
const BONE := Color("ead4ad")
const ARTERIAL := Color("a8281a")
const SPORE := Color("7f9440")

## How far the ring sits outside the glyph.
const RING_RATIO := 1.0
## The gap between the two finger pairs, in radians, measured off the stem. Wide
## enough to read as a deliberate split at favicon size.
const FORK_GAP := 0.30
## Where the arms leave the stem, as a fraction of the half-height.
const ARM_ROOT := 0.10


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A line that was cut by hand. Straight lines read as vector art and this mark
## is supposed to look struck into something.
static func _rough(canvas: CanvasItem, from: Vector2, to: Vector2, colour: Color, width: float, rng: RandomNumberGenerator, wobble: float) -> void:
	var steps := 5
	var points := PackedVector2Array()
	for step in steps + 1:
		var along := float(step) / float(steps)
		var at := from.lerp(to, along)
		# Nothing moves at the ends: a stroke that wanders at its root stops
		# meeting the stem, and the glyph falls apart.
		var edge := sin(along * PI)
		at += Vector2(rng.randf_range(-wobble, wobble), rng.randf_range(-wobble, wobble)) * edge
		points.append(at)
	canvas.draw_polyline(points, colour, width, true)


## One hand, as the rune it already is. `facing` is 1 for palm up (life) and -1
## for the same hand inverted (death). Everything is measured off `reach`, so the
## two halves are the one drawing twice rather than two drawings.
static func draw_hand_rune(canvas: CanvasItem, root: Vector2, reach: float, facing: float, colour: Color, width: float, rng: RandomNumberGenerator) -> void:
	var wobble := reach * 0.018
	var up := Vector2(0, -1) * facing

	# The stem: wrist and forearm. It runs the full half-height, because it is
	# also the axis the other half is mirrored across.
	var stem_end := root + up * reach
	_rough(canvas, root, stem_end, colour, width, rng, wobble)

	# The fork. Two arms leaving the stem low and opening to the gap the sign
	# actually makes — index and middle as one, ring and little as the other.
	var arm_root := root + up * (reach * ARM_ROOT)
	for side: float in [-1.0, 1.0]:
		var angle := (PI * 0.5 - FORK_GAP * 1.45) * side
		# Rotate the arm off vertical by hand rather than by matrix: the sign is
		# not symmetrical in the photographs and it should not be here either.
		var direction := Vector2(sin(angle * 0.62), -cos(angle * 0.62) * facing).normalized()
		var tip := arm_root + direction * (reach * 0.92)
		_rough(canvas, arm_root, tip, colour, width, rng, wobble)

		# Each arm is two fingers, so it splits again at its end — small, but it
		# is what stops the glyph reading as a plain rune with no hand in it.
		var spread := reach * 0.17
		var perpendicular := Vector2(-direction.y, direction.x)
		for finger: float in [-1.0, 1.0]:
			var end := tip + direction * spread * 0.55 + perpendicular * spread * finger * 0.5
			_rough(canvas, tip, end, colour, width * 0.72, rng, wobble * 0.6)

	# The thumb. Short, low, on one side only — the asymmetry is what makes it a
	# hand rather than a rune somebody drew symmetrically.
	var thumb_root := root + up * (reach * 0.22)
	var thumb := thumb_root + Vector2(-0.86, -0.42 * facing).normalized() * (reach * 0.40)
	_rough(canvas, thumb_root, thumb, colour, width * 0.8, rng, wobble)


## The ring. Cut in segments with gaps, so it is a struck circle rather than a
## perfect one, and the gaps sit where a stamp would have lifted.
static func draw_ring(canvas: CanvasItem, centre: Vector2, radius: float, colour: Color, width: float, rng: RandomNumberGenerator) -> void:
	var segments := 5
	for segment in segments:
		var gap := 0.055 + rng.randf() * 0.05
		var from := TAU * (float(segment) / float(segments)) + gap
		var to := TAU * (float(segment + 1) / float(segments)) - gap
		var points := PackedVector2Array()
		var steps := 22
		for step in steps + 1:
			var angle := lerpf(from, to, float(step) / float(steps))
			var r := radius + rng.randf_range(-1.0, 1.0) * radius * 0.012
			points.append(centre + Vector2(cos(angle), sin(angle)) * r)
		canvas.draw_polyline(points, colour, width, true)


## The whole seal. `radius` is the ring, and the glyph is fitted inside it.
static func draw_mark(canvas: CanvasItem, centre: Vector2, radius: float, colour: Color, seed_value := 1312, halo := Color(0, 0, 0, 0)) -> void:
	var rng := _rng(seed_value)
	var width := maxf(1.5, radius * 0.055)
	var reach := radius * 0.74

	# The bleed behind the strokes. Off by default; the menu turns it on so the
	# seal sits in light rather than on top of the page.
	if halo.a > 0.0:
		var glow := _rng(seed_value)
		draw_ring(canvas, centre, radius, halo, width * 2.6, glow)
		draw_hand_rune(canvas, centre, reach, 1.0, halo, width * 2.6, glow)
		draw_hand_rune(canvas, centre, reach, -1.0, halo, width * 2.6, glow)

	draw_ring(canvas, centre, radius, colour, width, rng)
	# Life above the line, death below it, sharing one stem. The lower half on
	# its own is the peace badge.
	draw_hand_rune(canvas, centre, reach, 1.0, colour, width, rng)
	draw_hand_rune(canvas, centre, reach, -1.0, colour, width, rng)
