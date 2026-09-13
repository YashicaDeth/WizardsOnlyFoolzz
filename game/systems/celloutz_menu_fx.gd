extends Control

const COPPER := Color("ef652e")
## Greg: *"make the sigil have effects through designer and be on a red cpu with
## the lines glowing with effects"*. The die, the traces and the pins.
const DIE := Color("2a0908")
const TRACE := Color("c4241c")
const PIN := Color("e0784a")
const TEAL := Color("25aa9c")
const CREAM := Color("efd0a0")
var elapsed := 0.0
var nodes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in 24:
		nodes.append({"phase": index * 0.48, "depth": float(index % 6) / 6.0, "side": -1.0 if index % 2 == 0 else 1.0})


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 400:
		return
	_draw_red_cpu()
	_draw_blood_sigil()
	_draw_hud_frame()
	_draw_footer()


## A cheap bloom: the same stroke laid down two or three times, each wider and
## fainter than the last, with the true line on top. There is no post-process
## glow reaching a Control that draws itself, and Greg asked for the lines to
## glow rather than for the whole screen to.
func _glow_line(from: Vector2, to: Vector2, color: Color, width: float, spread := 3.0) -> void:
	for step in 3:
		var out := float(3 - step)
		draw_line(from, to, color * Color(1, 1, 1, color.a * 0.16 / out),
			width + out * spread, true)
	draw_line(from, to, color, width, true)


func _glow_arc(centre: Vector2, radius: float, from: float, to: float, points: int,
		color: Color, width: float, spread := 3.0) -> void:
	for step in 3:
		var out := float(3 - step)
		draw_arc(centre, radius, from, to, points,
			color * Color(1, 1, 1, color.a * 0.16 / out), width + out * spread, true)
	draw_arc(centre, radius, from, to, points, color, width, true)


## The red CPU the ward is stamped on. A die with a chamfered corner, pin banks
## down all four edges, and Manhattan-routed traces running out of it — right
## angles, because that is what reads as a board rather than as a spider. A
## charge travels each trace on its own phase, so the thing looks powered.
func _draw_red_cpu() -> void:
	var centre := Vector2(size.x * 0.79, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.205
	var half := radius * 1.02
	var die := Rect2(centre - Vector2(half, half), Vector2(half * 2.0, half * 2.0))

	# Traces first, so the die sits on top of where they leave it.
	var rng := 0.0
	for index in 14:
		rng = float(index)
		var side := index % 4
		var along := (fposmod(rng * 0.37, 0.76) + 0.12) * half * 2.0
		var start := Vector2.ZERO
		var run := Vector2.ZERO
		match side:
			0: start = Vector2(die.position.x + along, die.position.y); run = Vector2(0, -1)
			1: start = Vector2(die.end.x, die.position.y + along); run = Vector2(1, 0)
			2: start = Vector2(die.position.x + along, die.end.y); run = Vector2(0, 1)
			_: start = Vector2(die.position.x, die.position.y + along); run = Vector2(-1, 0)
		var first := start + run * (18.0 + fposmod(rng * 11.0, 34.0))
		var turn := Vector2(-run.y, run.x) * ((22.0 + fposmod(rng * 7.0, 40.0)) * (1.0 if index % 2 == 0 else -1.0))
		var second := first + turn
		var tone := TRACE * Color(1, 1, 1, 0.26)
		draw_line(start, first, tone, 1.6, true)
		draw_line(first, second, tone, 1.6, true)
		# The charge. One bright pip per trace, running out and starting again.
		var travel := fposmod(elapsed * 0.42 + rng * 0.19, 1.0)
		var at := start.lerp(first, minf(travel * 2.0, 1.0)) if travel < 0.5 			else first.lerp(second, (travel - 0.5) * 2.0)
		draw_circle(at, 2.1, PIN * Color(1, 1, 1, 0.75 * (1.0 - travel * 0.55)))
		draw_circle(at, 4.4, PIN * Color(1, 1, 1, 0.16 * (1.0 - travel * 0.55)))

	# The pins.
	for index in 44:
		var side := index % 4
		var step := float(index / 4) / 11.0
		var along := die.position.x + half * 0.22 + step * half * 1.56
		var down := die.position.y + half * 0.22 + step * half * 1.56
		var lit := 0.30 + 0.42 * maxf(0.0, sin(elapsed * 1.7 + float(index) * 0.5))
		var tone := PIN * Color(1, 1, 1, lit * 0.55)
		match side:
			0: draw_line(Vector2(along, die.position.y), Vector2(along, die.position.y - 7.0), tone, 2.0)
			1: draw_line(Vector2(die.end.x, down), Vector2(die.end.x + 7.0, down), tone, 2.0)
			2: draw_line(Vector2(along, die.end.y), Vector2(along, die.end.y + 7.0), tone, 2.0)
			_: draw_line(Vector2(die.position.x, down), Vector2(die.position.x - 7.0, down), tone, 2.0)

	# The substrate, with one corner cut the way a real package marks pin one.
	var notch := half * 0.20
	draw_colored_polygon(PackedVector2Array([
		die.position + Vector2(notch, 0.0),
		Vector2(die.end.x, die.position.y),
		die.end,
		Vector2(die.position.x, die.end.y),
		die.position + Vector2(0.0, notch),
	]), DIE * Color(1, 1, 1, 0.82))
	_glow_line(die.position + Vector2(notch, 0.0), die.position + Vector2(0.0, notch),
		TRACE * Color(1, 1, 1, 0.55), 1.8, 2.0)
	for edge in [
		[Vector2(die.position.x + notch, die.position.y), Vector2(die.end.x, die.position.y)],
		[Vector2(die.end.x, die.position.y), die.end],
		[die.end, Vector2(die.position.x, die.end.y)],
		[Vector2(die.position.x, die.end.y), Vector2(die.position.x, die.position.y + notch)],
	]:
		_glow_line(edge[0], edge[1], TRACE * Color(1, 1, 1, 0.5), 1.8, 2.0)


## The menu needs a mark that belongs to the world, not another stock loading
## screen.  This is drawn under the type so it reads like something stamped in
## wet rust on the camera glass: imperfect rings, a six-point ward and drips.
func _draw_blood_sigil() -> void:
	# Kept clear of the title card: this is the middle-right ritual wound in the
	# image, not another mark competing with the logo.
	var center := Vector2(size.x * 0.79, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.205
	var breathe := 0.78 + sin(elapsed * 1.15) * 0.14
	var blood := Color("a91517") * Color(1, 1, 1, 0.45 * breathe)
	var old_ring := Color("47100e") * Color(1, 1, 1, 0.34)
	draw_arc(center + Vector2(3, -2), radius * 1.03, -0.18, TAU - 0.36, 86, old_ring, 4.0)
	_glow_arc(center, radius, 0.09, TAU - 0.22, 96, blood, 2.25)
	_glow_arc(center, radius * 0.58, -0.34, TAU - 0.7, 72, blood * Color(1, 1, 1, 0.72), 1.5)
	var points := PackedVector2Array()
	for index in 7:
		var angle := -PI * 0.5 + float(index) * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.86)
	for index in 6:
		_glow_line(points[index], points[(index + 2) % 6], blood, 1.5)
		draw_circle(points[index], 3.2 + sin(elapsed * 2.0 + index) * 0.75, blood)
		var drip := 16.0 + float((index * 13) % 29)
		if index % 2 == 0:
			draw_line(points[index] + Vector2(0, 5), points[index] + Vector2(2, drip), blood * Color(1, 1, 1, 0.72), 2.0)
			draw_circle(points[index] + Vector2(2, drip + 3), 2.2, blood)
	# The centre is a fixed ritual cross, not a cursor-shaped decoration.
	_glow_line(center + Vector2(-radius * 0.29, 0), center + Vector2(radius * 0.29, 0), blood, 2.5)
	_glow_line(center + Vector2(0, -radius * 0.29), center + Vector2(0, radius * 0.29), blood, 2.5)
	draw_circle(center, 4.5, Color("270507") * Color(1, 1, 1, 0.85))


func _draw_hud_frame() -> void:
	var edge := Color("c8502a") * Color(1, 1, 1, 0.48)
	var margin := 18.0
	var corner := 54.0
	# Broken corners keep the overlay from becoming a generic rectangle.
	for flip_x in [-1.0, 1.0]:
		for flip_y in [-1.0, 1.0]:
			var pivot := Vector2(margin if flip_x < 0.0 else size.x - margin, margin if flip_y < 0.0 else size.y - margin)
			draw_line(pivot, pivot + Vector2(corner * flip_x, 0), edge, 1.5)
			draw_line(pivot, pivot + Vector2(0, corner * flip_y), edge, 1.5)


func _draw_tree() -> void:
	var root := Vector2(size.x * 0.78, size.y * 0.84)
	var crown := Vector2(size.x * 0.78, size.y * 0.17)
	var pulse := 0.55 + sin(elapsed * 1.3) * 0.16
	draw_line(root, crown, COPPER * Color(1, 1, 1, pulse), 2.0)
	for level in 7:
		var t := float(level + 1) / 8.0
		var point := root.lerp(crown, t)
		var reach := 40.0 + level * 18.0
		for side in [-1.0, 1.0]:
			var end := point + Vector2(side * reach, -34.0 - level * 5.0)
			draw_line(point, end, TEAL * Color(1, 1, 1, 0.22 + t * 0.35), 1.5)
			draw_circle(end, 3.0 + sin(elapsed * 2.0 + level) * 1.0, COPPER * Color(1, 1, 1, 0.55))
			if level > 2:
				draw_line(end, end + Vector2(side * 24, -18), CREAM * Color(1, 1, 1, 0.17), 1.0)


func _draw_title_signal() -> void:
	var origin := Vector2(50, 155)
	var length := 280.0 + sin(elapsed * 1.6) * 36.0
	draw_line(origin, origin + Vector2(length, 0), COPPER * Color(1, 1, 1, 0.65), 2.0)
	draw_line(origin + Vector2(0, 7), origin + Vector2(length * 0.67, 7), TEAL * Color(1, 1, 1, 0.48), 1.0)
	var scan := fmod(elapsed * 85.0, length)
	draw_circle(origin + Vector2(scan, 0), 4.0, CREAM)


func _draw_archive_nodes() -> void:
	var center := Vector2(size.x * 0.76, size.y * 0.48)
	for item in nodes:
		var depth := float(item.depth)
		var phase := float(item.phase) + elapsed * (0.08 + depth * 0.12)
		var radius := 90.0 + depth * 230.0
		var point := center + Vector2(cos(phase) * radius, sin(phase) * radius * 0.48)
		var color := TEAL.lerp(COPPER, depth)
		draw_circle(point, 1.5 + depth * 3.0, color * Color(1, 1, 1, 0.16 + depth * 0.25))
		if depth > 0.65:
			draw_line(point, center.lerp(point, 0.82), color * Color(1, 1, 1, 0.09), 1.0)


func _draw_footer() -> void:
	var y := size.y - 32.0
	# House type. This line sits under a menu now entirely set in CellOutzType,
	# so the engine fallback font was the one thing on the front door still
	# speaking in somebody else's voice.
	CellOutzType.draw_condensed(self, Vector2(48, y - 9.0),
		"WORLD BUILD // EVERY ACTION LEAVES A WITNESS // EVEN SPIRITS SEEK REDEMPTION",
		9.0, CREAM * Color(1, 1, 1, 0.62), 1.2)
	for index in 9:
		var x := size.x - 210 + index * 18
		var height := 4.0 + sin(elapsed * 2.5 + index * 0.7) * 3.0
		draw_line(Vector2(x, y), Vector2(x, y - height), COPPER * Color(1, 1, 1, 0.5), 3.0)
