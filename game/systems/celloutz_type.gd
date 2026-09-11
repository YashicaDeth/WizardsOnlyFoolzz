class_name CellOutzType
extends RefCounted

## The project's display face, drawn rather than loaded.
##
## Every interface in this game was set in `ThemeDB.fallback_font` — Godot's
## default UI face. Greg's read was that the whole thing looks "tutorial level,
## same as the font", and he is right: nothing announces an unfinished engine
## project louder than its default typeface, and every reference he sent has a
## display face of its own.
##
## This is a stencil alphabet built from stroke paths on a 6x10 cap grid, in the
## register of something cut through a plate with a torch: straight, industrial,
## broken where a stencil bridge would be. Drawing it has three advantages over
## shipping a font file — there is nothing to licence, it scales to any size
## without an atlas, and the letterforms are part of the CellOutz identity
## rather than someone else's work sitting inside it.
##
## Body copy stays in a real font. This is for headers, numerals and stamps,
## where character matters more than reading a paragraph.

const GRID := Vector2(6.0, 10.0)

## Strokes are polylines on the cap grid: x rightward 0-6, y downward 0-10 with
## 0 at the cap line and 10 on the baseline. Gaps in a path are expressed as
## separate strokes, which is where the stencil bridges live.
const GLYPHS := {
	"A": [[[0, 10], [3, 0], [6, 10]], [[1.1, 6.6], [2.3, 6.6]], [[3.7, 6.6], [4.9, 6.6]]],
	"B": [[[0, 0], [0, 10]], [[0, 0], [4.2, 0], [5.6, 1.4], [5.6, 3.6], [4.2, 5], [0, 5]], [[0, 5], [4.6, 5], [6, 6.4], [6, 8.6], [4.6, 10], [0, 10]]],
	"C": [[[6, 1.8], [4.4, 0], [1.6, 0], [0, 1.8], [0, 8.2], [1.6, 10], [4.4, 10], [6, 8.2]]],
	"D": [[[0, 0], [0, 10]], [[0, 0], [4, 0], [6, 2], [6, 8], [4, 10], [0, 10]]],
	"E": [[[6, 0], [0, 0]], [[0, 0], [0, 10]], [[0, 10], [6, 10]], [[1, 5], [4.6, 5]]],
	"F": [[[6, 0], [0, 0]], [[0, 0], [0, 10]], [[1, 5], [4.4, 5]]],
	"G": [[[6, 1.8], [4.4, 0], [1.6, 0], [0, 1.8], [0, 8.2], [1.6, 10], [4.4, 10], [6, 8.2], [6, 5.6]], [[3.4, 5.6], [6, 5.6]]],
	"H": [[[0, 0], [0, 10]], [[6, 0], [6, 10]], [[0, 5], [2.3, 5]], [[3.7, 5], [6, 5]]],
	"I": [[[3, 0], [3, 10]], [[1, 0], [5, 0]], [[1, 10], [5, 10]]],
	"J": [[[5.2, 0], [5.2, 8], [3.6, 10], [1.4, 10], [0, 8.4]]],
	"K": [[[0, 0], [0, 10]], [[5.8, 0], [0.6, 5.2]], [[1.8, 4.2], [6, 10]]],
	"L": [[[0, 0], [0, 10], [5.8, 10]]],
	"M": [[[0, 10], [0, 0], [3, 4.4], [6, 0], [6, 10]]],
	"N": [[[0, 10], [0, 0], [6, 10], [6, 0]]],
	"O": [[[1.6, 0], [4.4, 0], [6, 1.8], [6, 8.2], [4.4, 10], [1.6, 10], [0, 8.2], [0, 1.8], [1.6, 0]]],
	"P": [[[0, 10], [0, 0], [4.4, 0], [6, 1.6], [6, 4], [4.4, 5.6], [0, 5.6]]],
	"Q": [[[1.6, 0], [4.4, 0], [6, 1.8], [6, 8.2], [4.4, 10], [1.6, 10], [0, 8.2], [0, 1.8], [1.6, 0]], [[3.6, 7.2], [6.2, 10.4]]],
	"R": [[[0, 10], [0, 0], [4.4, 0], [6, 1.6], [6, 4], [4.4, 5.6], [0, 5.6]], [[3.2, 5.6], [6, 10]]],
	"S": [[[6, 1.6], [4.4, 0], [1.6, 0], [0, 1.6], [0, 3.6], [1.6, 5], [4.4, 5], [6, 6.4], [6, 8.4], [4.4, 10], [1.6, 10], [0, 8.4]]],
	"T": [[[0, 0], [6, 0]], [[3, 0], [3, 10]]],
	"U": [[[0, 0], [0, 8.2], [1.6, 10], [4.4, 10], [6, 8.2], [6, 0]]],
	"V": [[[0, 0], [3, 10], [6, 0]]],
	"W": [[[0, 0], [1.4, 10], [3, 3.6], [4.6, 10], [6, 0]]],
	"X": [[[0, 0], [6, 10]], [[6, 0], [0, 10]]],
	"Y": [[[0, 0], [3, 5], [6, 0]], [[3, 5], [3, 10]]],
	"Z": [[[0, 0], [6, 0], [0, 10], [6, 10]]],
	"0": [[[1.6, 0], [4.4, 0], [6, 1.8], [6, 8.2], [4.4, 10], [1.6, 10], [0, 8.2], [0, 1.8], [1.6, 0]], [[1.2, 8.4], [4.8, 1.6]]],
	"1": [[[1.2, 1.8], [3, 0], [3, 10]], [[1, 10], [5, 10]]],
	"2": [[[0, 1.8], [1.6, 0], [4.4, 0], [6, 1.8], [6, 3.4], [0, 10], [6, 10]]],
	"3": [[[0, 1.6], [1.6, 0], [4.4, 0], [6, 1.6], [6, 3.6], [4.4, 5], [6, 6.4], [6, 8.4], [4.4, 10], [1.6, 10], [0, 8.4]]],
	"4": [[[4.6, 10], [4.6, 0], [0, 6.8], [6, 6.8]]],
	"5": [[[6, 0], [0, 0], [0, 4.4], [4.4, 4.4], [6, 6], [6, 8.4], [4.4, 10], [1.4, 10], [0, 8.6]]],
	"6": [[[5.4, 0.6], [3.6, 0], [1.4, 0], [0, 1.8], [0, 8.2], [1.6, 10], [4.4, 10], [6, 8.4], [6, 6.6], [4.4, 5], [1.6, 5], [0, 6.4]]],
	"7": [[[0, 0], [6, 0], [2.4, 10]]],
	"8": [[[1.6, 5], [0, 3.6], [0, 1.6], [1.6, 0], [4.4, 0], [6, 1.6], [6, 3.6], [4.4, 5], [1.6, 5], [0, 6.6], [0, 8.4], [1.6, 10], [4.4, 10], [6, 8.4], [6, 6.6], [4.4, 5]]],
	"9": [[[0.6, 9.4], [2.4, 10], [4.6, 10], [6, 8.2], [6, 1.8], [4.4, 0], [1.6, 0], [0, 1.6], [0, 3.4], [1.6, 5], [4.4, 5], [6, 3.6]]],
	".": [[[2.7, 9.6], [3.3, 9.6]]],
	",": [[[3.2, 9.2], [2.3, 11]]],
	"-": [[[0.8, 5], [5.2, 5]]],
	"+": [[[3, 2], [3, 8]], [[0.8, 5], [5.2, 5]]],
	"/": [[[0, 10], [6, 0]]],
	":": [[[2.7, 3], [3.3, 3]], [[2.7, 8.4], [3.3, 8.4]]],
	"!": [[[3, 0], [3, 6.6]], [[2.7, 9.6], [3.3, 9.6]]],
	"?": [[[0, 1.8], [1.6, 0], [4.4, 0], [6, 1.8], [6, 3.4], [3, 5.6], [3, 7]], [[2.7, 9.6], [3.3, 9.6]]],
	"'": [[[3, 0], [3, 2.4]]],
	"(": [[[4.2, 0], [2, 3], [2, 7], [4.2, 10]]],
	")": [[[1.8, 0], [4, 3], [4, 7], [1.8, 10]]],
	"[": [[[4.2, 0], [2, 0], [2, 10], [4.2, 10]]],
	"]": [[[1.8, 0], [4, 0], [4, 10], [1.8, 10]]],
	"%": [[[0, 10], [6, 0]], [[0.4, 0.4], [2, 0.4], [2, 2], [0.4, 2], [0.4, 0.4]], [[4, 8], [5.6, 8], [5.6, 9.6], [4, 9.6], [4, 8]]],
	"*": [[[3, 1.4], [3, 8.6]], [[0.4, 2.8], [5.6, 7.2]], [[5.6, 2.8], [0.4, 7.2]]],
}


## Width of `text` at a given cap height, so callers can right-align or centre
## without guessing.
static func width(text: String, cap_height: float, tracking := 0.0) -> float:
	var scale := cap_height / GRID.y
	var advance := GRID.x * scale + cap_height * 0.26 + tracking
	return maxf(0.0, float(text.length()) * advance - (cap_height * 0.26 + tracking))


## Draws `text` with its cap line at `at.y` and its left edge at `at.x`.
## Returns the width drawn, so a caller can continue on the same line.
static func draw_text(canvas: CanvasItem, at: Vector2, text: String, cap_height: float, color: Color, tracking := 0.0, weight := 0.0) -> float:
	var scale := cap_height / GRID.y
	var thickness := weight if weight > 0.0 else maxf(1.0, cap_height * 0.13)
	var advance := GRID.x * scale + cap_height * 0.26 + tracking
	var cursor := at.x
	for index in text.length():
		var glyph := text.substr(index, 1).to_upper()
		if GLYPHS.has(glyph):
			for stroke in GLYPHS[glyph]:
				var points := PackedVector2Array()
				for point in stroke:
					points.append(Vector2(at.x + float(point[0]) * scale, at.y + float(point[1]) * scale) + Vector2(cursor - at.x, 0.0))
				if points.size() == 2:
					canvas.draw_line(points[0], points[1], color, thickness)
				else:
					canvas.draw_polyline(points, color, thickness)
		cursor += advance
	return maxf(0.0, cursor - at.x - (cap_height * 0.26 + tracking))


## The same text struck twice slightly out of register, which is how a worn
## plate actually prints and what gives a stamped header its edge.
static func draw_stamped(canvas: CanvasItem, at: Vector2, text: String, cap_height: float, color: Color, ghost: Color, tracking := 0.0) -> float:
	draw_text(canvas, at + Vector2(cap_height * 0.06, cap_height * 0.05), text, cap_height, ghost, tracking)
	return draw_text(canvas, at, text, cap_height, color, tracking)
