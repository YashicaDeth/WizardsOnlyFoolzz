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
## for the same hand inverted (death).
##
## Rebuilt, because the first version was not a hand. It drew two arms leaving a
## stem at forty-five degrees with little split tips on the ends, which reads as
## a tree — fingers do not splay like that and there was no palm at all. What the
## photographs actually show is four fingers held close to vertical with a wide
## gap opened between the middle and the ring, a thumb thrown well out to one
## side, and the wrist running down out of frame.
##
## Drawn that way, nobody has to be told it is algiz. The two finger pairs *are*
## the rune's arms and the wrist *is* its stem, and the glyph falls out of an
## honest hand rather than being a rune with hand-shaped decoration on it.
static func draw_hand_rune(canvas: CanvasItem, root: Vector2, reach: float, facing: float, colour: Color, width: float, rng: RandomNumberGenerator) -> void:
	var wobble := reach * 0.016
	var up := Vector2(0, -1) * facing

	# The wrist, running back out of the glyph. This is the stem of the rune and
	# it is drawn first so the palm overlaps it rather than butting onto it.
	_rough(canvas, root, root - up * reach * 0.34, colour, width * 1.05, rng, wobble)

	# The palm. Short, and the only part of a hand that is not a line — without
	# it the fingers read as sticks radiating from a point.
	var palm_top := root + up * (reach * 0.26)
	_rough(canvas, root, palm_top, colour, width * 1.5, rng, wobble * 0.5)

	# Four fingers in two pairs. The gap between the middle and the ring is the
	# sign — it is what makes this hand *this* hand — so it is the widest angle
	# in the drawing and everything else is closer to vertical than instinct
	# suggests. Angles are radians off the palm; lengths are fractions of reach.
	# Evenly spaced, these read as a bunch of sticks. The sign is not four
	# fingers, it is *two pairs* — index and middle held together, ring and
	# little held together, and a gap between them wider than either pair is
	# internally. Tight pairs and a wide centre is the whole read.
	var fingers := [
		[-0.74, 0.86],
		[-0.52, 1.00],
		[0.52, 0.97],
		[0.74, 0.82],
	]
	for finger: Array in fingers:
		var lean := float(finger[0]) * facing
		var length := float(finger[1]) * reach * 0.74
		# Rotate `up` by the lean, so a finger leaves the palm rather than the
		# origin and the whole hand turns together when `facing` flips.
		var direction := Vector2(
			up.x * cos(lean) - up.y * sin(lean),
			up.x * sin(lean) + up.y * cos(lean)
		)
		var tip := palm_top + direction * length
		_rough(canvas, palm_top, tip, colour, width, rng, wobble)

	# The thumb. Thrown out and down, far wider than any finger, and on one side
	# only — the asymmetry is what stops this reading as a symmetrical rune
	# somebody drew with a ruler.
	var thumb_root := root + up * (reach * 0.12)
	var thumb_lean := -1.48 * facing
	var thumb_direction := Vector2(
		up.x * cos(thumb_lean) - up.y * sin(thumb_lean),
		up.x * sin(thumb_lean) + up.y * cos(thumb_lean)
	)
	_rough(canvas, thumb_root, thumb_root + thumb_direction * reach * 0.38, colour, width * 0.92, rng, wobble)


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
