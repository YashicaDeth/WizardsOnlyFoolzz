extends RefCounted


## The intake's pages, animated (Greg, 24 September: "animated, skeuomorphic
## intake pages", "ink, blood, metal, and parts swinging out on gears").
##
## A new page swings in on a riveted steel arm from a gear at the form's left
## edge, and settles with a little overshoot; the gears keep turning while it
## prints. Ink bleeds behind the print head, and each page change runs a line
## of blood down the paper from the clip, which stays there, drying.
##
## Pure drawing: `vat_intake.gd` owns the clock and calls these inside its
## own transform, so everything here is in clipboard space.

const STEEL := Color(0.52, 0.5, 0.47)
const STEEL_DARK := Color(0.16, 0.14, 0.13)
const STEEL_LIGHT := Color(0.86, 0.82, 0.74)
const BRASS := Color(0.62, 0.42, 0.2)
const INK_WET := Color(0.05, 0.02, 0.02)
const BLOOD_WET := Color(0.55, 0.05, 0.03)
const BLOOD_DRY := Color(0.28, 0.03, 0.02)

## How far out the page starts, in radians, and how it settles.
const SWING_FROM := -0.3
const SWING_DAMP := 5.0
const SWING_RING := 9.0
## How long a run of blood takes to reach its length, and to dry.
const RUN_SECONDS := 1.6
const DRY_SECONDS := 14.0
const MAX_RUNS := 4


## The page's angle about its hinge, t running 0..1 across the print.
## Swings in, overshoots a little, and is exactly still at 1.
static func swing_angle(t: float) -> float:
	if t >= 1.0:
		return 0.0
	var t_clamped := clampf(t, 0.0, 1.0)
	return SWING_FROM * exp(-SWING_DAMP * t_clamped) * cos(SWING_RING * t_clamped) * (1.0 - t_clamped)


## The page's transform about `hinge`, to compose onto the clipboard's own.
static func swing_transform(t: float, hinge: Vector2) -> Transform2D:
	return Transform2D(swing_angle(t), hinge) * Transform2D(0.0, -hinge)


## A cut steel gear: teeth, a bored hub, spokes, one highlight edge.
static func draw_gear(canvas: CanvasItem, center: Vector2, radius: float, teeth: int, angle: float) -> void:
	var outline := PackedVector2Array()
	var steps := teeth * 4
	for index in steps + 1:
		var a := angle + TAU * float(index) / float(steps)
		var phase := index % 4
		var r := radius if phase == 1 or phase == 2 else radius * 0.8
		outline.append(center + Vector2(cos(a), sin(a)) * r)
	canvas.draw_colored_polygon(outline, STEEL)
	canvas.draw_polyline(outline, STEEL_DARK, 1.5)
	canvas.draw_arc(center, radius * 0.72, angle - 2.4, angle - 0.9, 10, STEEL_LIGHT * Color(1, 1, 1, 0.7), 1.5)
	for spoke in 4:
		var a := angle + TAU * float(spoke) / 4.0 + PI / 4.0
		canvas.draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.26, center + Vector2(cos(a), sin(a)) * radius * 0.6, STEEL_DARK, 2.0)
	canvas.draw_circle(center, radius * 0.28, BRASS)
	canvas.draw_circle(center, radius * 0.12, STEEL_DARK)


## The riveted arm from the drive gear to the page, swinging with it.
static func draw_arm(canvas: CanvasItem, hinge: Vector2, reach: float, angle: float) -> void:
	var along := Vector2(cos(angle), sin(angle))
	var end := hinge + along * reach
	canvas.draw_line(hinge, end, STEEL_DARK, 7.0)
	canvas.draw_line(hinge, end, STEEL, 4.0)
	canvas.draw_line(hinge + Vector2(0, -1.5), end + Vector2(0, -1.5), STEEL_LIGHT * Color(1, 1, 1, 0.45), 1.0)
	for rivet in 4:
		var at := hinge.lerp(end, (float(rivet) + 0.5) / 4.0)
		canvas.draw_circle(at, 2.2, STEEL_DARK)
		canvas.draw_circle(at + Vector2(-0.6, -0.6), 1.0, STEEL_LIGHT)


## The gear train on the form's left edge. The drive turns with the page and
## keeps turning while it prints; the idler meshes and turns the other way.
static func draw_train(canvas: CanvasItem, hinge: Vector2, t: float, clock: float) -> void:
	var drive := clock * (2.4 if t < 1.0 else 0.15) + swing_angle(t) * 3.0
	var idler_at := hinge + Vector2(-6.0, 38.0)
	draw_gear(canvas, idler_at, 15.0, 9, -drive * 1.45 + 0.2)
	draw_gear(canvas, hinge, 22.0, 13, drive)


## Ink still wet behind the print head: blots that feather out and fade the
## further they are from the head.
static func draw_ink_bleed(canvas: CanvasItem, width: float, head: float, t: float, seed_value: int) -> void:
	if t >= 1.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for blot in 14:
		var x := 22.0 + rng.randf() * (width - 44.0)
		var back := rng.randf() * 60.0
		var fresh := 1.0 - back / 60.0
		var r := (1.5 + rng.randf() * 4.5) * (0.6 + fresh * 0.6)
		canvas.draw_circle(Vector2(x, head - back - 4.0), r, INK_WET * Color(1, 1, 1, 0.5 * fresh * (1.0 - t)))
		canvas.draw_circle(Vector2(x, head - back - 4.0), r * 1.8, INK_WET * Color(1, 1, 1, 0.12 * fresh * (1.0 - t)))


## A new run of blood from the clip, for a page change `serial`.
static func new_run(serial: int, width: float, top: float, bottom: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331 + serial * 97
	return {
		"x": width * 0.5 + rng.randf_range(-30.0, 30.0),
		"top": top,
		"length": rng.randf_range(0.35, 0.8) * (bottom - top),
		"wobble": rng.randf() * TAU,
		"age": 0.0,
	}


static func age_runs(runs: Array, delta: float) -> void:
	for run in runs:
		run["age"] = float(run.age) + delta
	while runs.size() > MAX_RUNS:
		runs.pop_front()


## Blood running down from the clip: a trail that thins as it goes, a bead
## at the front while it is still moving, darkening as it dries.
static func draw_runs(canvas: CanvasItem, runs: Array) -> void:
	for run in runs:
		var grown := clampf(float(run.age) / RUN_SECONDS, 0.0, 1.0)
		var reach := float(run.length) * ease(grown, 0.6)
		var dry := clampf(float(run.age) / DRY_SECONDS, 0.0, 1.0)
		var tone := BLOOD_WET.lerp(BLOOD_DRY, dry)
		var points := PackedVector2Array()
		var segments := 14
		for index in segments + 1:
			var along := float(index) / float(segments) * reach
			points.append(Vector2(float(run.x) + sin(along * 0.05 + float(run.wobble)) * 2.5, float(run.top) + along))
		if points.size() >= 2 and reach > 1.0:
			canvas.draw_polyline(points, tone * Color(1, 1, 1, 0.8), 2.4 - dry)
		var front := points[points.size() - 1]
		canvas.draw_circle(front, 3.2 if grown < 1.0 else 2.4, tone)
		canvas.draw_circle(Vector2(float(run.x), float(run.top)), 4.0, tone * Color(1, 1, 1, 0.9))
