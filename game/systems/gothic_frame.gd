class_name GothicFrame
extends RefCounted

## Drawn furniture for full panels: a wooden reliquary cabinet with iron corner
## brackets and a gear train, and a bevelled chrome plate with filigree
## corners. Static and procedural, like `CellOutzType` — nothing imported, so
## any Control can dress itself in one call from its own `_draw`.

const WOOD := Color("2b1a12")
const WOOD_LIGHT := Color("4a2d1c")
const IRON := Color("3a3634")
const CHROME := Color("c9c6c0")
const BRASS := Color("9c7a3c")


## The cabinet carcass around `rect`: planked wood, a routed inner edge, iron
## brackets at the corners and a gear train running down the left side.
static func draw_cabinet(canvas: CanvasItem, rect: Rect2, time: float) -> void:
	var outer := rect.grow(18.0)
	canvas.draw_rect(outer, WOOD)
	# Planks: vertical boards with grain lines that drift per board.
	var board := 64.0
	var x := outer.position.x
	var index := 0
	while x < outer.end.x:
		var w := minf(board, outer.end.x - x)
		var shade := 0.9 + 0.1 * sin(float(index) * 2.3)
		canvas.draw_rect(Rect2(x, outer.position.y, w, outer.size.y), WOOD_LIGHT * Color(shade, shade, shade, 0.35))
		for grain in 5:
			var gx := x + 6.0 + fmod(float(grain * 13 + index * 7), maxf(w - 12.0, 1.0))
			canvas.draw_line(Vector2(gx, outer.position.y), Vector2(gx + sin(float(grain + index)) * 5.0, outer.end.y), Color(0.07, 0.035, 0.02, 0.35), 1.0)
		canvas.draw_line(Vector2(x, outer.position.y), Vector2(x, outer.end.y), Color(0.05, 0.02, 0.01, 0.8), 2.0)
		x += board
		index += 1
	canvas.draw_rect(rect, Color(0.03, 0.02, 0.015, 0.94))
	canvas.draw_rect(rect.grow(3.0), Color(0.08, 0.04, 0.02), false, 4.0)
	canvas.draw_rect(rect.grow(6.0), WOOD_LIGHT * Color(1, 1, 1, 0.6), false, 1.0)
	for corner in [outer.position, Vector2(outer.end.x, outer.position.y), Vector2(outer.position.x, outer.end.y), outer.end]:
		_bracket(canvas, corner, outer.get_center())
	var gear_x := outer.position.x - 6.0
	var spacing := 74.0
	var count := int(outer.size.y / spacing)
	for g in count:
		var radius := 26.0 if g % 2 == 0 else 17.0
		var centre := Vector2(gear_x + (0.0 if g % 2 == 0 else 14.0), outer.position.y + 40.0 + g * spacing)
		var turn := time * (0.35 if g % 2 == 0 else -0.54) + float(g)
		draw_gear(canvas, centre, radius, 10 if g % 2 == 0 else 7, turn)


## An L-shaped iron bracket screwed over a corner, pointing inward.
static func _bracket(canvas: CanvasItem, corner: Vector2, towards: Vector2) -> void:
	var sx := signf(towards.x - corner.x)
	var sy := signf(towards.y - corner.y)
	var arm := 46.0
	var t := 12.0
	var shape := PackedVector2Array([
		corner, corner + Vector2(arm * sx, 0), corner + Vector2(arm * sx, t * sy),
		corner + Vector2(t * sx, t * sy), corner + Vector2(t * sx, arm * sy), corner + Vector2(0, arm * sy),
	])
	canvas.draw_colored_polygon(shape, IRON)
	var closed := shape.duplicate()
	closed.append(shape[0])
	canvas.draw_polyline(closed, CHROME * Color(1, 1, 1, 0.35), 1.0)
	for bolt in [corner + Vector2(6, 6) * Vector2(sx, sy), corner + Vector2(arm - 8, 6) * Vector2(sx, sy), corner + Vector2(6, arm - 8) * Vector2(sx, sy)]:
		canvas.draw_circle(bolt, 2.6, CHROME * Color(1, 1, 1, 0.7))
		canvas.draw_circle(bolt + Vector2(0.6, 0.6), 1.2, Color(0.1, 0.1, 0.1))


static func draw_gear(canvas: CanvasItem, centre: Vector2, radius: float, teeth: int, turn: float) -> void:
	var outline := PackedVector2Array()
	var steps := teeth * 4
	for i in steps + 1:
		var a := turn + TAU * float(i) / float(steps)
		var r := radius if (i % 4) < 2 else radius * 0.8
		outline.append(centre + Vector2(cos(a), sin(a)) * r)
	canvas.draw_colored_polygon(outline, BRASS.darkened(0.35))
	canvas.draw_polyline(outline, BRASS, 1.2)
	canvas.draw_arc(centre, radius * 0.55, 0.0, TAU, 20, BRASS.darkened(0.1), 2.0)
	for spoke in 4:
		var a := turn + TAU * float(spoke) / 4.0
		canvas.draw_line(centre, centre + Vector2(cos(a), sin(a)) * radius * 0.55, BRASS.darkened(0.1), 2.0)
	canvas.draw_circle(centre, radius * 0.16, IRON)


## A bevelled chrome plate: light top-left edge, dark bottom-right, filigree
## scrolls at each corner. For dialogs and headers inside a cabinet.
static func draw_chrome_plate(canvas: CanvasItem, rect: Rect2, fill: Color) -> void:
	canvas.draw_rect(rect, fill)
	var tl := rect.position
	var br := rect.end
	canvas.draw_line(tl, Vector2(br.x, tl.y), CHROME, 2.0)
	canvas.draw_line(tl, Vector2(tl.x, br.y), CHROME, 2.0)
	canvas.draw_line(Vector2(tl.x, br.y), br, Color(0.2, 0.2, 0.2), 2.0)
	canvas.draw_line(Vector2(br.x, tl.y), br, Color(0.2, 0.2, 0.2), 2.0)
	for corner in [tl, Vector2(br.x, tl.y), Vector2(tl.x, br.y), br]:
		var sx := 1.0 if corner.x == tl.x else -1.0
		var sy := 1.0 if corner.y == tl.y else -1.0
		var c: Vector2 = corner + Vector2(9 * sx, 9 * sy)
		canvas.draw_arc(c, 6.0, 0.0, TAU, 14, CHROME * Color(1, 1, 1, 0.8), 1.2)
		canvas.draw_arc(c + Vector2(8 * sx, 0), 3.5, PI * 0.5, PI * 1.8, 8, CHROME * Color(1, 1, 1, 0.6), 1.0)
		canvas.draw_arc(c + Vector2(0, 8 * sy), 3.5, PI * -0.3, PI * 1.0, 8, CHROME * Color(1, 1, 1, 0.6), 1.0)
