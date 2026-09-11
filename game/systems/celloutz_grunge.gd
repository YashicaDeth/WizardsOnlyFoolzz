class_name CellOutzGrunge
extends RefCounted

## Surface damage for interfaces, drawn rather than textured.
##
## Greg's read on the first World Index pass: *"it's a bit too cyberpunk
## internet heavy, should be more fallout and biopunk post nuclear cynical
## insane online communities and corrupt evil world."* He is right, and the tell
## was the palette — thin bright teal vector lines on near-black is a sci-fi
## terminal. This world's interfaces are **printed institutional paperwork that
## has been in a wet building for four years**, and the difference is almost
## entirely surface: stains, blood, stamps, grain, scratches and things somebody
## wrote on by hand.
##
## Everything here is deterministic from a seed, so a panel's grime does not
## crawl between frames — which is the single fastest way to make drawn damage
## read as an effect instead of as dirt that is actually on the thing.
##
## Kept as static helpers on a `RefCounted` so any `CanvasItem` in the project
## can use it, the same way `CellOutzType` is shared.

## The register. Deliberately no cyan: contamination, rust, dried blood, bone
## and bile, which is what `ART-DIRECTION.md` already asks for and what the
## first pass quietly ignored.
const PAPER := Color("d9c49a")
const RUST := Color("b0552a")
const DRIED := Color("6e1d13")
const WET := Color("a8281a")
const SPORE := Color("7f9440")
const BILE := Color("9a8c3f")
const BRUISE := Color("6b3f6e")
const SOOT := Color("15110d")


## An irregular blot - damp, rust bloom, old coffee, something worse.
##
## Built from overlapping translucent discs rather than from one wobbled
## polygon. The polygon version was the first attempt and it was wrong in a way
## worth recording: twenty jittered vertices produce visible straight edges and
## spikes, so it read as an abstract shape laid over the panel instead of as a
## mark soaked into it. Accumulated alpha gives a soft irregular edge for free.
static func stain(canvas: CanvasItem, at: Vector2, radius: float, seed_value: int, tint: Color, alpha := 0.14) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var blobs := 11
	var per_blob := alpha / 2.6
	for index in blobs:
		var drift := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.7, 0.7)) * radius * 0.46
		var size := radius * rng.randf_range(0.30, 0.62)
		canvas.draw_circle(at + drift, size, tint * Color(1, 1, 1, per_blob))
	# A few darker specks where it pooled, so it is not a uniform wash.
	for index in 5:
		var drift := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.8, 0.8)) * radius * 0.5
		canvas.draw_circle(at + drift, radius * rng.randf_range(0.05, 0.13), tint * Color(1, 1, 1, alpha * 0.85))


## Cast-off blood: a few large marks and a spray of fine ones with a direction.
## Used over the interface itself, not only in the world — the premise is that
## this is a physical object in a place where people are opened up.
static func spatter(canvas: CanvasItem, at: Vector2, seed_value: int, count: int, heading: Vector2, tint := DRIED) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var direction := heading.normalized() if heading.length() > 0.01 else Vector2.RIGHT
	for index in count:
		var distance := rng.randf() * rng.randf() * 130.0
		var spread := direction.rotated(rng.randf_range(-0.55, 0.55))
		var point := at + spread * distance + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		var size := 1.0 + rng.randf() * rng.randf() * 7.0
		var alpha := 0.30 + rng.randf() * 0.45
		if size > 4.0:
			# The big ones are not round. A drop that lands with momentum tears.
			var tail := spread * size * rng.randf_range(1.2, 2.6)
			canvas.draw_colored_polygon(PackedVector2Array([
				point + spread.orthogonal() * size * 0.5,
				point + tail,
				point - spread.orthogonal() * size * 0.5,
				point - spread * size * 0.6,
			]), tint * Color(1, 1, 1, alpha))
		else:
			canvas.draw_circle(point, size, tint * Color(1, 1, 1, alpha))


## A rubber stamp: struck at an angle, ink missing where the pad was dry. The
## cheapest way to make an interface read as a document somebody processed.
static func stamp(canvas: CanvasItem, at: Vector2, text: String, cap: float, angle: float, tint: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var width := CellOutzType.width(text, cap, cap * 0.22)
	canvas.draw_set_transform(at, angle, Vector2.ONE)
	var box := Rect2(Vector2(-10, -cap * 0.55), Vector2(width + 20, cap * 2.1))
	# The border is drawn in broken segments rather than as a rect, so the frame
	# itself has dry patches like the letters do.
	var corners := [box.position, box.position + Vector2(box.size.x, 0), box.position + box.size, box.position + Vector2(0, box.size.y)]
	for index in 4:
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % 4]
		var segments := 7
		for step in segments:
			if rng.randf() < 0.22:
				continue
			var a := from.lerp(to, float(step) / float(segments))
			var b := from.lerp(to, float(step + 1) / float(segments))
			canvas.draw_line(a, b, tint * Color(1, 1, 1, 0.55 + rng.randf() * 0.35), 2.0)
	CellOutzType.draw_text(canvas, Vector2(0, 0), text, cap, tint * Color(1, 1, 1, 0.82), cap * 0.22)
	# Dry patches: knock holes in the ink by stamping the ground back over it.
	for index in rng.randi_range(3, 7):
		var hole := Vector2(rng.randf() * width, rng.randf_range(-cap * 0.3, cap * 1.2))
		canvas.draw_circle(hole, rng.randf_range(1.5, 4.0), SOOT * Color(1, 1, 1, 0.55))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Dust, grit and dead emulsion. Fixed per seed so it sits still.
static func grain(canvas: CanvasItem, rect: Rect2, seed_value: int, density: int, tint := PAPER) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in density:
		var point := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var bright := rng.randf()
		if bright > 0.72:
			canvas.draw_rect(Rect2(point, Vector2(1, 1)), tint * Color(1, 1, 1, 0.10 + rng.randf() * 0.14))
		else:
			canvas.draw_rect(Rect2(point, Vector2(1, 1)), Color(0, 0, 0, 0.14 + rng.randf() * 0.22))


## Scratches in the surface, mostly along one axis like something was dragged
## across it repeatedly in the same direction.
static func scratches(canvas: CanvasItem, rect: Rect2, seed_value: int, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in count:
		var start := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var length := rng.randf_range(14.0, 130.0)
		var lean := rng.randf_range(-0.22, 0.22)
		var finish := start + Vector2(cos(lean), sin(lean)) * length
		canvas.draw_line(start, finish, PAPER * Color(1, 1, 1, 0.05 + rng.randf() * 0.07), 1.0)


## Cross-hatching inside a polygon. Used to mark damage on a printed chart the
## way a medical form actually would — by someone shading it in with a pen.
static func hatch(canvas: CanvasItem, bounds: Rect2, spacing: float, tint: Color, alpha: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var span := bounds.size.x + bounds.size.y
	var offset := -bounds.size.y
	while offset < bounds.size.x:
		var jitter := rng.randf_range(-1.5, 1.5)
		var from := bounds.position + Vector2(offset + jitter, 0)
		var to := bounds.position + Vector2(offset + bounds.size.y + jitter, bounds.size.y)
		canvas.draw_line(from, to, tint * Color(1, 1, 1, alpha * rng.randf_range(0.6, 1.0)), 1.0)
		offset += spacing
	span = span


## A run of fluid down the surface from a point. Blood on a vertical screen does
## not stay where it landed.
static func run_down(canvas: CanvasItem, at: Vector2, length: float, seed_value: int, tint := DRIED) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var width := rng.randf_range(1.6, 4.0)
	var points_left := PackedVector2Array()
	var points_right := PackedVector2Array()
	var steps := 12
	var drift := 0.0
	for index in steps:
		var travel := float(index) / float(steps - 1)
		drift += rng.randf_range(-1.1, 1.1)
		var y := at.y + travel * length
		var taper := width * (1.0 - travel * 0.7)
		points_left.append(Vector2(at.x + drift - taper, y))
		points_right.insert(0, Vector2(at.x + drift + taper, y))
	var shape := points_left
	for point in points_right:
		shape.append(point)
	canvas.draw_colored_polygon(shape, tint * Color(1, 1, 1, 0.42))
	# The bead at the bottom, where it stopped.
	canvas.draw_circle(Vector2(at.x + drift, at.y + length), width * 0.9, tint * Color(1, 1, 1, 0.5))


## Handwriting, as a scrawl rather than as letters. Reads as annotation at a
## glance and is honest about not being legible — which suits a world where the
## person who wrote it is dead.
static func scrawl(canvas: CanvasItem, at: Vector2, width: float, lines: int, seed_value: int, tint := Color("2b2019")) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for line in lines:
		var y := at.y + float(line) * 11.0
		var x := at.x
		var stroke := PackedVector2Array()
		while x < at.x + width * rng.randf_range(0.55, 1.0):
			stroke.append(Vector2(x, y + rng.randf_range(-2.6, 2.6)))
			x += rng.randf_range(3.0, 7.0)
		if stroke.size() >= 2:
			canvas.draw_polyline(stroke, tint * Color(1, 1, 1, 0.55), 1.4)


## G1.4. Greg's artwork as the substrate a panel is printed on.
##
## The interface already had a generated grain layer; this puts a real plate
## under it at low alpha, so the paper a readout sits on is something he made
## rather than noise. Drawn first, under everything, and skipped entirely when
## the pipeline has not been run.
static func art_substrate(canvas: CanvasItem, rect: Rect2, seed_value: int, alpha := 0.12) -> bool:
	var plate: Texture2D = ArtSet.pick("plate", seed_value)
	if plate == null:
		return false
	canvas.draw_texture_rect(plate, rect, false, Color(1, 1, 1, alpha))
	return true


## G1.5. The Wire's collage sheets. The surviving internet is described in
## DESIGN/IN_GAME_INTERNET.md as paranoid hand-assembled collage, which is what
## the pipeline builds out of the art — so the feed is printed over it.
static func art_collage(canvas: CanvasItem, rect: Rect2, seed_value: int, alpha := 0.16) -> bool:
	var sheet: Texture2D = ArtSet.pick("wire", seed_value)
	if sheet == null:
		return false
	canvas.draw_texture_rect(sheet, rect, false, Color(1, 1, 1, alpha))
	return true
