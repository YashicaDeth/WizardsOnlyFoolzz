class_name BlackMirror
extends RefCounted

## I0.5. The handheld's shell, re-specified by Greg: *"the internet portal
## through the black mirror phone device with a jester design on the back of the
## black cracked mirror you look into."*
##
## The distinction is the whole design. A screen is a thing you **read** — it
## sits in front of you and prints at you. A mirror is a thing you **look into**,
## which means the surface is dark and reflective *before* it is informational,
## content surfaces up out of the depth rather than being stamped on the front,
## and something is always looking back.
##
## So the glass here is drawn in four layers, back to front:
##
##   1. the black, which is nearly all of it;
##   2. the reflection — the reader's own face, unreliable;
##   3. the cracks, which are damage to a mirror rather than dead LCD pixels;
##   4. the content, which the page draws on top and which the glass tints.
##
## The jester lives on the back of the case: CellOutz sold you a fool's errand,
## and the collective above is literally called wizardsonlyfoolz. The joke is
## supposed to land twice.

const GLASS := Color("05060a")
const SHEEN := Color("2a3340")
const CRACK := Color("8f9cab")
const REFLECT := Color("1a2029")
const JESTER := Color("7d2230")
const BELL := Color("c9a23a")


## The dark ground the whole device sits on. Drawn first; everything else is
## depth added to it.
static func draw_glass(canvas: CanvasItem, rect: Rect2, alpha: float, clock: float) -> void:
	canvas.draw_rect(rect, GLASS * Color(1, 1, 1, alpha))
	# A slow sheen crossing the glass, so it reads as a surface with an angle to
	# it rather than as a black rectangle.
	var sweep := fposmod(clock * 0.11, 1.6) - 0.3
	var band := rect.size.x * 0.42
	var at := rect.position.x + rect.size.x * sweep
	for step in 7:
		var offset := float(step) / 7.0
		canvas.draw_rect(
			Rect2(at + offset * band * 0.4, rect.position.y, band * 0.18, rect.size.y),
			SHEEN * Color(1, 1, 1, (0.05 - offset * 0.006) * alpha)
		)


## The reader, in the glass. Deliberately vague — a silhouette and two lights
## where eyes are, moving slightly out of time with the viewer. `presence` is
## how strongly they show: a bright page hides the reflection, a dark one does
## not, which is true of real glass and also means the mirror asserts itself
## most when there is least to read.
static func draw_reflection(canvas: CanvasItem, rect: Rect2, alpha: float, clock: float, presence: float) -> void:
	if presence <= 0.01:
		return
	var centre := rect.get_center() + Vector2(sin(clock * 0.23) * 6.0, cos(clock * 0.17) * 4.0)
	var scale := minf(rect.size.x, rect.size.y) * 0.5
	var tint := REFLECT * Color(1, 1, 1, presence * alpha)

	# Head and shoulders, low contrast, slightly off-centre.
	canvas.draw_colored_polygon(_ellipse(centre + Vector2(0, -scale * 0.12), scale * 0.19, scale * 0.24, 18), tint)
	canvas.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-scale * 0.46, scale * 0.62),
		centre + Vector2(-scale * 0.24, scale * 0.14),
		centre + Vector2(scale * 0.24, scale * 0.14),
		centre + Vector2(scale * 0.46, scale * 0.62),
	]), tint)

	# Two lights where the eyes are. They blink on their own schedule, which is
	# the part that makes it look back rather than sit there.
	var blink := sin(clock * 0.9) * sin(clock * 2.3)
	if blink > -0.72:
		for side in [-1.0, 1.0]:
			canvas.draw_circle(centre + Vector2(side * scale * 0.075, -scale * 0.14), maxf(1.0, scale * 0.012), CRACK * Color(1, 1, 1, 0.5 * presence * alpha))


## Damage to a mirror: long forks from an impact point, not a grid of dead
## pixels. Deterministic from `seed_value`, so the same device is always broken
## in the same places.
static func draw_cracks(canvas: CanvasItem, rect: Rect2, alpha: float, seed_value: int, severity: float) -> void:
	if severity <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var origin := rect.position + Vector2(rect.size.x * 0.74, rect.size.y * 0.22)
	var forks := 3 + int(severity * 6.0)
	for fork in forks:
		var heading := rng.randf() * TAU
		var length := (0.25 + rng.randf() * 0.7) * minf(rect.size.x, rect.size.y)
		var points := PackedVector2Array([origin])
		var cursor := origin
		var steps := 3 + rng.randi_range(0, 3)
		for step in steps:
			heading += rng.randf_range(-0.42, 0.42)
			cursor += Vector2.from_angle(heading) * (length / float(steps))
			points.append(cursor)
		canvas.draw_polyline(points, CRACK * Color(1, 1, 1, 0.18 * severity * alpha), 1.0)
		# The bright edge that catches light along one side of a real crack.
		canvas.draw_polyline(points, Color(1, 1, 1, 0.05 * severity * alpha), 2.4)
	canvas.draw_circle(origin, 3.0, CRACK * Color(1, 1, 1, 0.3 * severity * alpha))


## The jester on the back of the case. Shown when the device is turned over,
## and as a small pressed mark on the front bezel the rest of the time.
static func draw_jester(canvas: CanvasItem, at: Vector2, size: float, alpha: float, clock: float) -> void:
	var sway := sin(clock * 1.3) * size * 0.05
	# Three-pointed hood, a bell on each point.
	var points := PackedVector2Array([
		at + Vector2(0, size * 0.26),
		at + Vector2(-size * 0.52, -size * 0.06),
		at + Vector2(-size * 0.30, -size * 0.44) + Vector2(sway, 0),
		at + Vector2(0, -size * 0.14),
		at + Vector2(size * 0.30, -size * 0.44) - Vector2(sway, 0),
		at + Vector2(size * 0.52, -size * 0.06),
	])
	canvas.draw_colored_polygon(points, JESTER * Color(1, 1, 1, 0.85 * alpha))
	for bell in [Vector2(-size * 0.30, -size * 0.44) + Vector2(sway, 0), Vector2(size * 0.30, -size * 0.44) - Vector2(sway, 0), Vector2(-size * 0.52, -size * 0.06), Vector2(size * 0.52, -size * 0.06)]:
		canvas.draw_circle(at + bell, size * 0.07, BELL * Color(1, 1, 1, 0.9 * alpha))
	# The face is a hole. Nothing in the hood, which is the joke.
	canvas.draw_colored_polygon(_ellipse(at + Vector2(0, size * 0.06), size * 0.22, size * 0.26, 16), GLASS * Color(1, 1, 1, alpha))
	for side in [-1.0, 1.0]:
		canvas.draw_circle(at + Vector2(side * size * 0.08, size * 0.02), size * 0.03, BELL * Color(1, 1, 1, 0.5 * alpha))
	# A grin drawn as a curve of teeth rather than a line.
	for tooth in 5:
		var t := float(tooth) / 4.0
		var x := lerpf(-size * 0.11, size * 0.11, t)
		var y := size * 0.14 + sin(t * PI) * size * 0.05
		canvas.draw_rect(Rect2(at + Vector2(x - size * 0.015, y), Vector2(size * 0.03, size * 0.045)), BELL * Color(1, 1, 1, 0.6 * alpha))


static func _ellipse(centre: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
