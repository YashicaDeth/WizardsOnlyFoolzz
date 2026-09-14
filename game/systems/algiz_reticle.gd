class_name AlgizReticle
extends Control

## Greg: *"the cursor should be the algiz that is used in the logo and it should
## switch from flipped up and down depending on if you are in combat or not"*.
##
## The mark on the front of the game is ᛉ inside a struck ring. `tools/wof_wordmark.py`
## already states what it means, and this control is only the other half of that
## sentence: *"Upright is life and protection, which is the one that goes on the
## logo. Reversed is ᛦ, death."* So the cursor is upright while nothing is trying
## to kill you and inverted the moment something is. One mark in two states, not
## two icons — the whole point is that it is the *same* three strokes.
##
## Drawn, not loaded. The geometry here is the logo's `algiz()` transcribed
## literally: stem a full height, arms leaving the stem at 0.56 down and climbing
## 0.44 back to exactly the stem's own crown, span 0.46. Those numbers are
## load-bearing and the python carries the reason — *"Overshooting reads as a Y in
## a circle; stopping short reads as an arrow. Level with the crown is what makes
## it algiz."* Do not round them off.
##
## What it supersedes: `gore_demo.gd`'s HUD drew a hand-rolled sight commented
## "An Algiz-like sight" — a stem, two arms and a `draw_arc`, in rust. It was
## Algiz-shaped and never inverted, so it carried none of the meaning. Delete
## those lines when this goes in; two sights at the same screen centre is worse
## than either.

## The logo's device size. Every other measurement is derived from it exactly as
## `wof_wordmark.build()` derives them, so the cursor cannot drift away from the
## mark on the box.
@export var mark_size := 36.0:
	set(value):
		mark_size = maxf(6.0, value)
		queue_redraw()

## Upright: bone, the colour the rest of this project's readouts are set in.
## Inverted: the blood red already used across the gore systems. The colour is
## the second reading, not the first — a player who never notices the flip still
## learns "pale means nothing is happening".
const LIFE := Color("ead4ad")
const DEATH := Color("c81f16")
## The ring is rust in both states on purpose: it is the containment, not the
## mark, and a ring that changes with the rune makes the flip harder to see.
const RING := Color("b0552a")

## How long the mark takes to turn over. Rule 3 — every hard cut is a bug — so
## this is a card turning about its own horizontal axis rather than one sprite
## being swapped for another: `cos()` across the flip carries the ease for free,
## slow at both ends and quickest through edge-on.
const FLIP_SECONDS := 0.34
## A state change settles rather than arrives. Decays to nothing.
const SETTLE_SECONDS := 0.45

## Ring geometry, straight off the logo: five struck segments with a gap, because
## a continuous circle reads as drawn and this one is meant to read as stamped.
const RING_SEGMENTS := 5
const RING_GAP := 0.10

var in_combat := false
## 0 upright, 1 inverted. Eased; `facing` is taken from it, never set directly.
var _flip := 0.0
var _settle := 0.0
var _drift := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The one call a caller needs. Idempotent — safe to hand it the same value every
## frame, which is what a combat check usually is.
func set_in_combat(value: bool) -> void:
	if value == in_combat:
		return
	in_combat = value
	_settle = 1.0


## Place the mark in a state with no animation at all. For spawning into a scene
## that is already in combat, where easing in from upright would be a lie.
func snap_state(value: bool) -> void:
	in_combat = value
	_flip = 1.0 if value else 0.0
	_settle = 0.0
	queue_redraw()


## 1 upright, -1 inverted, and every value between is the mark mid-turn. Exposed
## because a caller animating something alongside the cursor should read the same
## number rather than run a second timer that drifts out of step.
func facing() -> float:
	return cos(_flip * PI)


func _process(delta: float) -> void:
	var target := 1.0 if in_combat else 0.0
	_flip = move_toward(_flip, target, delta / FLIP_SECONDS)
	_settle = maxf(0.0, _settle - delta / SETTLE_SECONDS)
	_drift = fposmod(_drift + delta * 0.22, TAU)
	queue_redraw()


## One hard-edged bar of constant weight with square ends — the logo's `blade()`
## with no nib rake, which is how the rune is cut there. The width does *not*
## squash with the flip: a card seen edge-on still has its thickness, and keeping
## it is what stops the turn from blinking out at the halfway point.
static func _blade(from: Vector2, to: Vector2, width: float) -> PackedVector2Array:
	var span := to - from
	if span.length() < 0.0001:
		return PackedVector2Array()
	var normal: Vector2 = span.normalized().orthogonal() * (width * 0.5)
	return PackedVector2Array([from + normal, to + normal, to - normal, from - normal])


## The three strokes, as centrelines in a unit-height space centred on the origin
## with y running down, scaled by `face` (1 upright, -1 inverted, 0 edge-on).
##
## Three, not four: the stem is one unbroken bar crown to root. A first pass
## broke it with a stencil bridge at dead centre so the aim point would be clear
## glass, and the capture settled it — the mark stopped being the one on the box
## and became a Y with a loose bar under it. `art/brand/wof_seal.png` has a
## continuous stem and the cursor has to be that mark, so precision at the exact
## centre is bought back with the ring instead.
static func rune_strokes(face: float) -> Array:
	var root := 0.5 * face
	var crown := -0.5 * face
	var joint := root - 0.56 * face
	var rise := 0.44 * face
	var span := 0.46
	return [
		[Vector2(0.0, crown), Vector2(0.0, root)],
		[Vector2(0.0, joint), Vector2(-span, joint - rise)],
		[Vector2(0.0, joint), Vector2(span, joint - rise)],
	]


func _draw() -> void:
	var centre := size * 0.5
	# Eased 0..1 for anything that should read as "how far into combat are we",
	# as opposed to `facing()` which is the geometry.
	var heat: float = smoothstep(0.0, 1.0, _flip)
	var tone: Color = LIFE.lerp(DEATH, heat)
	# The settle is a small overshoot on the way out of a state change, so the
	# mark lands rather than stops.
	var settle: float = sin(_settle * PI) * 0.10
	var device: float = mark_size * (1.0 + settle)

	var radius: float = device * 0.50
	var ring_width: float = device * 0.095
	var bar: float = device * 0.150
	var height: float = device * 0.84
	var face: float = facing()

	# Struck, not drawn: five arcs with a gap between them, turning slowly so the
	# cursor is alive on a still screen without anything flashing.
	var ring_tone: Color = RING.lerp(tone, heat * 0.45)
	for index in RING_SEGMENTS:
		var start: float = TAU * (float(index) / float(RING_SEGMENTS)) + RING_GAP + _drift
		var end: float = TAU * (float(index + 1) / float(RING_SEGMENTS)) - RING_GAP + _drift
		draw_arc(centre, radius, start, end, 14, ring_tone * Color(1, 1, 1, 0.72), ring_width, true)

	for stroke: Array in rune_strokes(face):
		var from: Vector2 = centre + Vector2(stroke[0].x, stroke[0].y) * height
		var to: Vector2 = centre + Vector2(stroke[1].x, stroke[1].y) * height
		var polygon: PackedVector2Array = _blade(from, to, bar)
		if polygon.is_empty():
			continue
		draw_colored_polygon(polygon, tone)

	# Edge-on, the stem and the upper arm run have collapsed into the arm bar and
	# the mark is a single horizontal blade. That is correct for a card turning,
	# but it is also the one instant the rune is unreadable, so it is the instant
	# the ring tightens — the eye keeps its anchor through the turn.
	var edge: float = 1.0 - absf(face)
	if edge > 0.01:
		draw_arc(centre, radius * (1.0 - 0.10 * edge), 0.0, TAU, 32,
			tone * Color(1, 1, 1, 0.16 * edge), ring_width * 0.5, true)
