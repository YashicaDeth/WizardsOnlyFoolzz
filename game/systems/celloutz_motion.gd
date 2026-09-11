class_name CellOutzMotion
extends RefCounted

## Nothing in this game snaps.
##
## `DESIGN/INTERFACE_DIRECTION.md` makes seamlessness a hard requirement rather
## than a polish pass — *"everything seamless... every hard cut in this game is a
## bug"* — and the failure mode that produces is a hundred separate ad-hoc lerps,
## each with its own rate, none of them agreeing. So this is the one place rates
## and curves live (A8.4), and new interface code picks a named rate instead of
## inventing a number.
##
## The rates are named after what they are for rather than by value, because the
## value is meaningless on its own and the intent is not.

## A panel arriving or leaving. Fast enough not to be in the way, slow enough to
## read as an object moving rather than a frame being swapped.
const PANEL := 4.6
## A selection moving inside a panel already on screen. Quicker: the panel is
## established, only the highlight is travelling.
const SELECTION := 14.0
## A value counting toward a new reading — a hull figure, a score.
const READOUT := 8.0
## A list scrolling under a fixed frame.
const SCROLL := 11.0


## Ease-out. The standard curve for something arriving: fast at the start, so it
## feels responsive, settling at the end, so it feels physical.
static func ease_out(t: float, power := 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), power)


## Ease-in-out, for something travelling between two places it belongs.
static func ease_both(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


## A slight overshoot, for something snapping into a slot. Used sparingly - on a
## grimy salvaged interface, a bouncy panel reads as a phone app.
static func ease_back(t: float, strength := 1.18) -> float:
	var x := clampf(t, 0.0, 1.0)
	var c := strength * 1.525
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


## Frame-rate independent approach toward a target. The naive
## `lerp(current, target, delta * rate)` everybody writes is frame-rate
## dependent and quietly behaves differently at 30fps and 144fps; this does not.
static func approach(current: float, target: float, delta: float, rate: float) -> float:
	return lerpf(current, target, 1.0 - exp(-delta * rate))


## The same, for a position.
static func approach_vector(current: Vector2, target: Vector2, delta: float, rate: float) -> Vector2:
	return current.lerp(target, 1.0 - exp(-delta * rate))


## Advances a 0..1 blend in one direction and reports it. Saves every caller
## writing the same clamp twice, once for opening and once for closing.
static func blend(current: float, delta: float, rate: float, forward: bool) -> float:
	var step := delta * rate
	return minf(1.0, current + step) if forward else maxf(0.0, current - step)
