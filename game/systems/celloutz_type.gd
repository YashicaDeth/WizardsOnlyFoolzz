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
	# Closed squares rather than hairlines: a 0.6-wide segment disappears at
	# small caps, which turned every "0.5 KG" into "0 5 KG".
	".": [[[2.4, 8.9], [3.6, 8.9], [3.6, 10.0], [2.4, 10.0], [2.4, 8.9]]],
	",": [[[3.2, 9.2], [2.3, 11]]],
	"-": [[[0.8, 5], [5.2, 5]]],
	"+": [[[3, 2], [3, 8]], [[0.8, 5], [5.2, 5]]],
	"/": [[[0, 10], [6, 0]]],
	":": [[[2.4, 2.6], [3.6, 2.6], [3.6, 3.7], [2.4, 3.7], [2.4, 2.6]], [[2.4, 7.9], [3.6, 7.9], [3.6, 9.0], [2.4, 9.0], [2.4, 7.9]]],
	";": [[[2.4, 2.6], [3.6, 2.6], [3.6, 3.7], [2.4, 3.7], [2.4, 2.6]], [[3.2, 8.2], [2.3, 10.4]]],
	"!": [[[3, 0], [3, 6.6]], [[2.7, 9.6], [3.3, 9.6]]],
	"?": [[[0, 1.8], [1.6, 0], [4.4, 0], [6, 1.8], [6, 3.4], [3, 5.6], [3, 7]], [[2.7, 9.6], [3.3, 9.6]]],
	"'": [[[3, 0], [3, 2.4]]],
	"(": [[[4.2, 0], [2, 3], [2, 7], [4.2, 10]]],
	")": [[[1.8, 0], [4, 3], [4, 7], [1.8, 10]]],
	"[": [[[4.2, 0], [2, 0], [2, 10], [4.2, 10]]],
	"]": [[[1.8, 0], [4, 0], [4, 10], [1.8, 10]]],
	"%": [[[0, 10], [6, 0]], [[0.4, 0.4], [2, 0.4], [2, 2], [0.4, 2], [0.4, 0.4]], [[4, 8], [5.6, 8], [5.6, 9.6], [4, 9.6], [4, 8]]],
	"*": [[[3, 1.4], [3, 8.6]], [[0.4, 2.8], [5.6, 7.2]], [[5.6, 2.8], [0.4, 7.2]]],
	# The ten characters the screens actually use that the plate did not have.
	#
	# An unset glyph is not a missing-character box in this face - `draw_text`
	# skips it and still advances the cursor, so it comes out as a hole of exactly
	# one letter's width. That is why converting a screen off the fallback font
	# has been a quiet layout hazard rather than an obvious one, and it is the
	# reason these were counted off the real `draw_string` call sites rather than
	# guessed at: interpunct 12 uses, em dash 7, underscore 7, then the arrows.
	"·": [[[2.4, 4.45], [3.6, 4.45], [3.6, 5.55], [2.4, 5.55], [2.4, 4.45]]],
	# Eleventh, and not from the count: `gothic_field_hud.gd`'s weapon well had
	# been drawing its reserve count through a multiplication sign since it was
	# written, silently blank the whole time, and the fix at the time was to
	# change the copy to "x". The copy stays as it is — it ships and it is
	# verified — but the glyph exists now, so the next plate that reaches for it
	# gets a multiplication sign instead of a hole.
	"×": [[[1.2, 3.2], [4.8, 6.8]], [[4.8, 3.2], [1.2, 6.8]]],
	"—": [[[0, 5], [6, 5]]],
	"_": [[[0, 10.4], [6, 10.4]]],
	"\\": [[[0, 0], [6, 10]]],
	# Shaft plus an open chevron, not a filled head: a solid triangle at 10px cap
	# turns into a blob, and the rest of the face is cut lines.
	#
	# The two horizontal arrows carry a head wider and shallower than the two
	# vertical ones, which is not a symmetry mistake. `CONDENSED` squeezes x to
	# 0.68 and leaves y alone, so a head 2.2 units wide and 4.8 tall — the
	# obvious mirror of the vertical pair — comes out 1.5 wide and 4.8 tall in
	# the condensed cut and reads as a plus sign. 3.0 by 3.6 survives the
	# squeeze. Caught by rendering the specimen sheet, not by reading the data.
	"↑": [[[3, 10], [3, 0.6]], [[0.9, 3.1], [3, 0.6], [5.1, 3.1]]],
	"↓": [[[3, 0], [3, 9.4]], [[0.9, 6.9], [3, 9.4], [5.1, 6.9]]],
	"←": [[[6, 5], [0.4, 5]], [[3.4, 3.2], [0.4, 5], [3.4, 6.8]]],
	"→": [[[0, 5], [5.6, 5]], [[2.6, 3.2], [5.6, 5], [2.6, 6.8]]],
	# Directional quotes as slanted pairs of the apostrophe stroke. The lean is
	# the only thing distinguishing open from closed at this weight, so they lean
	# opposite ways rather than both sitting vertical.
	"“": [[[2.2, 0], [1.6, 2.6]], [[4.4, 0], [3.8, 2.6]]],
	"”": [[[1.6, 0], [2.2, 2.6]], [[3.8, 0], [4.4, 2.6]]],
}


## Width of `text` at a given cap height, so callers can right-align or centre
## without guessing.
## A1.4. The condensed cut. Not a separate alphabet - the same stencil squeezed
## horizontally, which is what a real condensed cut of a grotesque is, and which
## means the two faces cannot drift apart as glyphs are added.
##
## It exists because the display face at its natural width eats a column: three
## data readouts across a plate is about all it fits, and the derby HUD and the
## dossier both wanted five. Anything in a tight column gets this; headers keep
## the full width, because that is where the character is.
const CONDENSED := 0.68


## A1.6 v2. Kerning.
##
## Every letter sat on the 6-unit grid and took the same advance, which is what a
## stencil plate does and what a typeface must not: `AV` and `TA` open a hole you
## can see from across the room, because two diagonals leaning away from each
## other leave a triangle of white that the flat advance does nothing about.
##
## The usual fix is a hand-built table of pairs. That is the wrong tool here —
## the glyphs are stroke data in this file and they get edited, so a table would
## be a second description of the letterforms that silently goes out of date the
## first time somebody moves a vertex.
##
## So this measures instead. For a pair, the face is cut into horizontal bands;
## in each band it finds how far right the left glyph actually reaches and how
## far left the right glyph actually starts, and the pair closes by the smallest
## clearance any band has — down to a floor, so letters touch but never collide.
## Optical kerning, derived from the letterforms themselves, correct by
## construction whenever a glyph changes.

## Bands down the cap height. Eight is enough to catch a diagonal without paying
## for resolution nobody can see.
const KERN_BANDS := 8
## The white that must survive between two letters, in grid units. Below this the
## face stops reading as cut metal and starts reading as a ligature.
const KERN_CLEARANCE := 1.15
## No pair closes by more than this, whatever the measurement says. `L` followed
## by a full stop would otherwise close almost the entire advance.
const KERN_LIMIT := 2.1

static var _kern_cache: Dictionary = {}
static var _edge_cache: Dictionary = {}


## Per band: how far right this glyph reaches, and how far left it starts.
## -1 in a band means the glyph has nothing at that height at all, which is the
## case that produces the big holes and the case a flat advance cannot see.
static func _edges(glyph: String) -> Array:
	if _edge_cache.has(glyph):
		return _edge_cache[glyph]
	var rightmost := []
	var leftmost := []
	for _band in KERN_BANDS:
		rightmost.append(-1.0)
		leftmost.append(-1.0)
	if GLYPHS.has(glyph):
		for stroke in GLYPHS[glyph]:
			# Sample along each segment rather than only at its vertices: a
			# diagonal's midpoint is exactly what needs measuring and there is
			# no vertex there.
			for index in range(stroke.size() - 1):
				var from := Vector2(float(stroke[index][0]), float(stroke[index][1]))
				var to := Vector2(float(stroke[index + 1][0]), float(stroke[index + 1][1]))
				var steps := maxi(2, ceili(from.distance_to(to) * 2.0))
				for step in steps + 1:
					var point := from.lerp(to, float(step) / float(steps))
					var band := clampi(floori(point.y / GRID.y * float(KERN_BANDS)), 0, KERN_BANDS - 1)
					if rightmost[band] < 0.0 or point.x > rightmost[band]:
						rightmost[band] = point.x
					if leftmost[band] < 0.0 or point.x < leftmost[band]:
						leftmost[band] = point.x
	var edges := [rightmost, leftmost]
	_edge_cache[glyph] = edges
	return edges


## How much to pull `right` toward `left`, in grid units.
static func kern(left: String, right: String) -> float:
	if left.is_empty() or right.is_empty():
		return 0.0
	var key := left + right
	if _kern_cache.has(key):
		return _kern_cache[key]
	var closable := KERN_LIMIT
	var touching := false
	var left_edges: Array = _edges(left)
	var right_edges: Array = _edges(right)
	for band in KERN_BANDS:
		var reach: float = left_edges[0][band]
		var start: float = right_edges[1][band]
		# A band where either glyph has no ink cannot constrain the pair — which
		# is precisely why AV closes: at the top A has nothing on its right and
		# at the bottom V has nothing on its left, and no band has both.
		if reach < 0.0 or start < 0.0:
			continue
		touching = true
		var gap := (GRID.x - reach) + start
		closable = minf(closable, maxf(gap - KERN_CLEARANCE, 0.0))
	if not touching:
		# Two glyphs that never share a band at all — a space, mostly. Leave the
		# advance alone rather than collapsing the word.
		closable = 0.0
	_kern_cache[key] = closable
	return closable


static func width(text: String, cap_height: float, tracking := 0.0, stretch := 1.0) -> float:
	var scale := cap_height / GRID.y
	var advance := GRID.x * scale * stretch + cap_height * 0.26 + tracking
	var total := float(text.length()) * advance - (cap_height * 0.26 + tracking)
	# A1.6 v2. Measurement has to agree with drawing or every right-aligned
	# readout in the game drifts by however much the kerning closed.
	for index in range(1, text.length()):
		total -= kern(text.substr(index - 1, 1).to_upper(), text.substr(index, 1).to_upper()) * scale * stretch
	return maxf(0.0, total)


## Draws `text` with its cap line at `at.y` and its left edge at `at.x`.
## Returns the width drawn, so a caller can continue on the same line.
static func draw_text(canvas: CanvasItem, at: Vector2, text: String, cap_height: float, color: Color, tracking := 0.0, weight := 0.0, stretch := 1.0) -> float:
	var scale := cap_height / GRID.y
	var thickness := weight if weight > 0.0 else maxf(1.0, cap_height * 0.13)
	var advance := GRID.x * scale * stretch + cap_height * 0.26 + tracking
	var cursor := at.x
	var previous := ""
	for index in text.length():
		var glyph := text.substr(index, 1).to_upper()
		# A1.6 v2. Close the pair before setting the letter, not after.
		if not previous.is_empty():
			cursor -= kern(previous, glyph) * scale * stretch
		previous = glyph
		if GLYPHS.has(glyph):
			for stroke in GLYPHS[glyph]:
				var points := PackedVector2Array()
				for point in stroke:
					points.append(Vector2(cursor + float(point[0]) * scale * stretch, at.y + float(point[1]) * scale))
				if points.size() == 2:
					canvas.draw_line(points[0], points[1], color, thickness)
				else:
					canvas.draw_polyline(points, color, thickness)
		cursor += advance
	return maxf(0.0, cursor - at.x - (cap_height * 0.26 + tracking))


## The condensed cut, as a named call so tight columns do not each pick their own
## squeeze factor and end up inconsistent.
static func draw_condensed(canvas: CanvasItem, at: Vector2, text: String, cap_height: float, color: Color, tracking := 0.0) -> float:
	return draw_text(canvas, at, text, cap_height, color, tracking, 0.0, CONDENSED)


static func width_condensed(text: String, cap_height: float, tracking := 0.0) -> float:
	return width(text, cap_height, tracking, CONDENSED)


## Wrapping and alignment, which this face has never had and which is the only
## reason thirteen screens are still set in the engine's fallback font.
##
## `draw_string` gives you `HORIZONTAL_ALIGNMENT_RIGHT`, a wrap width and clipping
## for free. `CellOutzType` gives you none of those: it is procedural stroke
## glyphs drawn one at a time from a top-left. So every conversion away from the
## fallback font has had to hand-roll a wrapper, or has quietly overflowed its
## panel — `living_map.gd` grew a private `_wrap_condensed` and everything else
## went without. Promoted here so a conversion is mechanical rather than an
## invitation to break a layout.
##
## Caps only: the stencil has no lower case, and mixed case reads as missing
## glyphs rather than as sentence case. Callers should upper-case their copy.
static func wrap_condensed(text: String, width: float, cap_height: float, tracking := 0.0) -> Array:
	var lines: Array = []
	if width <= 0.0:
		return [text]
	var line := ""
	for word: String in text.split(" ", false):
		var candidate: String = word if line.is_empty() else line + " " + word
		if width_condensed(candidate, cap_height, tracking) > width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	return lines


## One line, placed inside `room` by alignment. 0 = left, 1 = centre, 2 = right,
## matching `HORIZONTAL_ALIGNMENT_*` so a converted call keeps its old argument.
static func draw_condensed_aligned(canvas: CanvasItem, at: Vector2, room: float, text: String,
		cap_height: float, color: Color, align := 0, tracking := 0.0) -> float:
	var measure := width_condensed(text, cap_height, tracking)
	var x := at.x
	if align == 1:
		x = at.x + maxf(0.0, (room - measure) * 0.5)
	elif align == 2:
		x = at.x + maxf(0.0, room - measure)
	return draw_condensed(canvas, Vector2(x, at.y), text, cap_height, color, tracking)


## A wrapped block. Returns the y the caller should continue from, so stacked
## paragraphs do not each have to re-measure what the one above them consumed.
static func draw_block(canvas: CanvasItem, at: Vector2, room: float, text: String,
		cap_height: float, color: Color, tracking := 0.0, leading := 0.0, align := 0,
		max_lines := 0) -> float:
	var step := leading if leading > 0.0 else cap_height * 1.55
	var lines := wrap_condensed(text, room, cap_height, tracking)
	if max_lines > 0 and lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
	var y := at.y
	for line: String in lines:
		draw_condensed_aligned(canvas, Vector2(at.x, y), room, line, cap_height, color, align, tracking)
		y += step
	return y


## The third thing `draw_string` gives away free and this face does not: clipping.
##
## A stroke face cannot be clipped by a rect the way a font atlas can without
## also clipping whatever is drawn behind it, so a name too long for its column
## has to be *shortened*, not masked. Returns `text` trimmed until it fits inside
## `room` with an ellipsis, or unchanged if it already fits.
##
## Three full stops rather than U+2026: the ellipsis is one glyph the plate does
## not have, and this is the function whose entire job is not overflowing.
static func fit_condensed(text: String, room: float, cap_height: float, tracking := 0.0) -> String:
	if room <= 0.0 or width_condensed(text, cap_height, tracking) <= room:
		return text
	var cut := text.length()
	while cut > 0:
		cut -= 1
		var candidate := text.substr(0, cut).strip_edges() + "..."
		if width_condensed(candidate, cap_height, tracking) <= room:
			return candidate
	# Not even "..." fits. Better a clipped mark than a line running out of its
	# panel and over whatever is beside it.
	return ""


## A1.5. The worn cut: the same letterforms printed by something that is failing.
##
## `wear` runs 0 (clean) to 1 (barely legible). Strokes break into segments with
## gaps, the segments jitter off the path, and the ink thins. Deterministic from
## the text itself, so a given label wears the *same way* every frame - wear that
## reshuffles is a flicker effect, not damage.
##
## This is the half of I4 that belongs to the typeface: a bleeding player's
## readouts should be harder to read, and the honest way to do that is to damage
## the printing rather than to fade the colour, which just looks like a filter.
static func draw_worn(canvas: CanvasItem, at: Vector2, text: String, cap_height: float, color: Color, wear: float, tracking := 0.0, stretch := 1.0) -> float:
	var damage := clampf(wear, 0.0, 1.0)
	if damage <= 0.01:
		return draw_text(canvas, at, text, cap_height, color, tracking, 0.0, stretch)
	var scale := cap_height / GRID.y
	var thickness := maxf(0.8, cap_height * 0.13 * lerpf(1.0, 0.55, damage))
	var advance := GRID.x * scale * stretch + cap_height * 0.26 + tracking
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text) & 0x7fffffff
	var wander := cap_height * 0.09 * damage
	var cursor := at.x
	var previous := ""
	for index in text.length():
		var glyph := text.substr(index, 1).to_upper()
		# A1.6 v2. Close the pair before setting the letter, not after.
		if not previous.is_empty():
			cursor -= kern(previous, glyph) * scale * stretch
		previous = glyph
		if GLYPHS.has(glyph):
			for stroke in GLYPHS[glyph]:
				# Walk the stroke as segments rather than drawing it whole, so a
				# gap can be opened anywhere along it.
				for step in range(stroke.size() - 1):
					var from := Vector2(cursor + float(stroke[step][0]) * scale * stretch, at.y + float(stroke[step][1]) * scale)
					var to := Vector2(cursor + float(stroke[step + 1][0]) * scale * stretch, at.y + float(stroke[step + 1][1]) * scale)
					var pieces := 3
					for piece in pieces:
						if rng.randf() < damage * 0.45:
							continue
						var a := from.lerp(to, float(piece) / float(pieces))
						var b := from.lerp(to, float(piece + 1) / float(pieces))
						var drift := Vector2(rng.randf_range(-wander, wander), rng.randf_range(-wander, wander))
						canvas.draw_line(a + drift, b + drift, color * Color(1, 1, 1, lerpf(1.0, 0.62, damage)), thickness)
		cursor += advance
	return maxf(0.0, cursor - at.x - (cap_height * 0.26 + tracking))


## The same text struck twice slightly out of register, which is how a worn
## plate actually prints and what gives a stamped header its edge.
static func draw_stamped(canvas: CanvasItem, at: Vector2, text: String, cap_height: float, color: Color, ghost: Color, tracking := 0.0) -> float:
	draw_text(canvas, at + Vector2(cap_height * 0.06, cap_height * 0.05), text, cap_height, ghost, tracking)
	return draw_text(canvas, at, text, cap_height, color, tracking)


## E2.1. The seal-drawing vocabulary. `goetic_seals.gd` is data only by design
## ("Data only. No stroke geometry, no drawing" — its own comment) because per
## this project's non-negotiable on originality, the seal *roster* (72 names,
## ranks and numbers out of Mathers' 1904 edition) is free public-domain
## material, but the drawn glyphs are not: this project does not reproduce the
## historical sigils, it grows its own in the same register the display face
## already established — deterministic stroke paths, nothing raster, nothing
## licensed.
##
## A seal is generated from one integer rather than authored 72 times over: a
## containment ring (every grimoire seal sits inside or against one), a set of
## spokes from the centre toward the ring at seeded angles and lengths, each
## ending in either a hook or a small loop, and occasional chords connecting
## two points on the ring the way a pentagram's construction lines do. Same
## seed, same seal, always — a rite has to point at one mark and mean it.
##
## Coordinates are normalised to a unit circle at the origin; `draw_seal` and
## its variants below scale and place it.
const SEAL_RING_STEPS := 28


static func seal_strokes(seed_value: int, complexity: int = 6) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value) & 0x7fffffff
	var strokes: Array = []

	var ring := PackedVector2Array()
	for step in SEAL_RING_STEPS + 1:
		var angle := TAU * float(step) / float(SEAL_RING_STEPS)
		ring.append(Vector2.from_angle(angle))
	strokes.append(ring)

	var spoke_count := maxi(3, complexity)
	var anchors: Array[Vector2] = []
	for spoke in spoke_count:
		var angle: float = TAU * float(spoke) / float(spoke_count) + rng.randf_range(-0.22, 0.22)
		var outer_radius := rng.randf_range(0.78, 1.0)
		var inner_radius := rng.randf_range(0.0, 0.32)
		var direction := Vector2.from_angle(angle)
		var inner_point := direction * inner_radius
		var outer_point := direction * outer_radius
		anchors.append(direction * 0.95)
		# A kink partway along reads as drawn rather than ruled with a straightedge.
		var kink := inner_point.lerp(outer_point, rng.randf_range(0.35, 0.65)) + direction.orthogonal() * rng.randf_range(-0.09, 0.09)
		strokes.append(PackedVector2Array([inner_point, kink, outer_point]))
		if rng.randf() < 0.5:
			# A hook: the spoke turns before it reaches the ring.
			var hook_dir := direction.rotated(rng.randf_range(0.5, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0))
			strokes.append(PackedVector2Array([outer_point, outer_point + hook_dir * 0.16]))
		else:
			# A loop: a small closed ring at the spoke's end.
			var loop := PackedVector2Array()
			for step in 9:
				loop.append(outer_point + Vector2.from_angle(TAU * float(step) / 8.0) * 0.07)
			strokes.append(loop)

	# Chords between non-adjacent anchors, the way a star's construction lines
	# cross the circle they are inscribed in. Seeded count, never every pair —
	# a seal that connects everything to everything reads as a diagram, not a
	# glyph somebody actually draws.
	var chord_count := mini(anchors.size(), 2 + int(rng.randf() * 3.0))
	for _chord in chord_count:
		if anchors.size() < 3:
			break
		var from_index := rng.randi() % anchors.size()
		var span := 2 + rng.randi() % maxi(1, anchors.size() - 3)
		var to_index := (from_index + span) % anchors.size()
		strokes.append(PackedVector2Array([anchors[from_index], anchors[to_index]]))

	# A small anchoring mark at the centre so the eye has a point of origin,
	# rather than every spoke meeting at a bare gap.
	if rng.randf() < 0.7:
		var core := PackedVector2Array()
		for step in 4:
			core.append(Vector2.from_angle(TAU * float(step) / 3.0 + rng.randf_range(0.0, TAU)) * 0.1)
		core.append(core[0])
		strokes.append(core)

	return strokes


## Draws a seal generated from `seed_value` at `center`, scaled to `radius`.
static func draw_seal(canvas: CanvasItem, center: Vector2, radius: float, seed_value: int, color: Color, complexity: int = 6, weight: float = 0.0) -> void:
	var thickness := weight if weight > 0.0 else maxf(1.0, radius * 0.035)
	for stroke: PackedVector2Array in seal_strokes(seed_value, complexity):
		var points := PackedVector2Array()
		for point in stroke:
			points.append(center + point * radius)
		if points.size() == 2:
			canvas.draw_line(points[0], points[1], color, thickness)
		else:
			canvas.draw_polyline(points, color, thickness)


## E2.4. A seal being drawn rather than sitting finished — `progress` 0 is a
## bare circle, 1 is the whole mark. Strokes commit in the same order
## `seal_strokes` builds them (ring, then each spoke and its hook or loop,
## then the chords, then the core), and a stroke either exists or does not:
## a rite is a thing you complete, not a bar that fills.
static func draw_seal_forming(canvas: CanvasItem, center: Vector2, radius: float, seed_value: int, color: Color, progress: float, complexity: int = 6, weight: float = 0.0) -> void:
	var strokes := seal_strokes(seed_value, complexity)
	var thickness := weight if weight > 0.0 else maxf(1.0, radius * 0.035)
	var drawn := clampi(roundi(clampf(progress, 0.0, 1.0) * strokes.size()), 0, strokes.size())
	var partial_t := fmod(clampf(progress, 0.0, 1.0) * strokes.size(), 1.0)
	for index in drawn:
		var stroke: PackedVector2Array = strokes[index]
		var points := PackedVector2Array()
		for point in stroke:
			points.append(center + point * radius)
		if points.size() == 2:
			canvas.draw_line(points[0], points[1], color, thickness)
		else:
			canvas.draw_polyline(points, color, thickness)
	# The stroke currently being laid down draws only as far as it has gotten.
	if drawn < strokes.size() and partial_t > 0.01:
		var live: PackedVector2Array = strokes[drawn]
		var live_end := maxi(1, roundi(partial_t * float(live.size() - 1)))
		var points := PackedVector2Array()
		for index in live_end + 1:
			points.append(center + live[index] * radius)
		if points.size() == 2:
			canvas.draw_line(points[0], points[1], color * Color(1, 1, 1, 0.8), thickness)
		elif points.size() > 2:
			canvas.draw_polyline(points, color * Color(1, 1, 1, 0.8), thickness)


## E2.4. The same corruption `draw_worn` applies to letterforms, on a seal
## instead: strokes break into segments and gaps open along them, seeded from
## the seal itself so a given mark corrupts the same way every time rather
## than flickering.
static func draw_seal_corrupted(canvas: CanvasItem, center: Vector2, radius: float, seed_value: int, color: Color, corruption: float, complexity: int = 6, weight: float = 0.0) -> void:
	var damage := clampf(corruption, 0.0, 1.0)
	if damage <= 0.01:
		draw_seal(canvas, center, radius, seed_value, color, complexity, weight)
		return
	var thickness := (weight if weight > 0.0 else maxf(1.0, radius * 0.035)) * lerpf(1.0, 0.6, damage)
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(seed_value) ^ 0x5eed) & 0x7fffffff
	var wander := radius * 0.05 * damage
	for stroke: PackedVector2Array in seal_strokes(seed_value, complexity):
		for step in range(stroke.size() - 1):
			var from := center + stroke[step] * radius
			var to := center + stroke[step + 1] * radius
			var pieces := 3
			for piece in pieces:
				if rng.randf() < damage * 0.5:
					continue
				var a := from.lerp(to, float(piece) / float(pieces))
				var b := from.lerp(to, float(piece + 1) / float(pieces))
				var drift := Vector2(rng.randf_range(-wander, wander), rng.randf_range(-wander, wander))
				canvas.draw_line(a + drift, b + drift, color * Color(1, 1, 1, lerpf(1.0, 0.55, damage)), thickness)


## E2.4. Burning: unlike corruption (which is a mark going bad while it sits
## there), a burn has a direction — `front_angle` is where it started — and it
## consumes rather than merely damages. Strokes on the near side of the front
## are gone or charred; strokes ahead of it are untouched. `burn` 1.0 leaves
## nothing but the memory of the ring.
static func draw_seal_burning(canvas: CanvasItem, center: Vector2, radius: float, seed_value: int, color: Color, burn: float, front_angle: float = 0.0, complexity: int = 6, weight: float = 0.0) -> void:
	var consumed := clampf(burn, 0.0, 1.0)
	if consumed <= 0.01:
		draw_seal(canvas, center, radius, seed_value, color, complexity, weight)
		return
	var thickness := weight if weight > 0.0 else maxf(1.0, radius * 0.035)
	var ember := Color("dc5827")
	var front := TAU * consumed
	for stroke: PackedVector2Array in seal_strokes(seed_value, complexity):
		var midpoint := Vector2.ZERO
		for point in stroke:
			midpoint += point
		midpoint /= maxf(1.0, float(stroke.size()))
		var stroke_angle := fposmod(midpoint.angle() - front_angle, TAU)
		if stroke_angle < front:
			# Already consumed — gone, not merely dim.
			continue
		var points := PackedVector2Array()
		for point in stroke:
			points.append(center + point * radius)
		# Right at the front it is still catching — ember-bright rather than
		# its normal colour — before it is gone on the next tick.
		var at_front := stroke_angle < front + 0.55
		var tone := ember if at_front else color
		if points.size() == 2:
			canvas.draw_line(points[0], points[1], tone, thickness)
		else:
			canvas.draw_polyline(points, tone, thickness)


## E2.1. The ritual alphabet is made of the same cut strokes as the display
## face. A seal is deliberately only geometry: its name, cost and meaning are
## authored later in E2.2/E2.3, so this vocabulary cannot smuggle a real-world
## occult system into the game.
##
## `strokes` uses points in a centred -1..1 square. Keep intentional gaps as
## separate strokes, exactly as GLYPHS does for stencil bridges.
static func seal_stroke_points(stroke: Array, at: Vector2, radius: float, rotation := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in stroke:
		if not point is Array or point.size() < 2:
			continue
		var local := Vector2(float(point[0]), float(point[1])) * radius
		points.append(at + local.rotated(rotation))
	return points


## Draw one mark from authored stroke paths. The doubled ghost makes it read as
## a stamped, failing instrument rather than pristine diagram linework.


## Drop-in for `CanvasItem.draw_string(font, ...)`: the same arguments after the
## font, the same meaning. `pos.y` is a baseline, `room` a box width (-1 for
## none) that alignment works within, and a line wider than its box is set
## smaller rather than run out of it, because this face does not wrap. Exists
## so the last engine-font screens convert mechanically, call for call.
static func draw_string_compat(canvas: CanvasItem, pos: Vector2, text: String, alignment := HORIZONTAL_ALIGNMENT_LEFT, room := -1.0, font_size := 16, color := Color.WHITE) -> void:
	var cap := float(font_size) * 0.72
	var tracking := float(font_size) * 0.08
	var drawn := width(text, cap, tracking)
	if room > 0.0 and drawn > room and drawn > 0.0:
		cap *= room / drawn
		tracking *= room / drawn
		drawn = room
	var x := pos.x
	if room > 0.0:
		if alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			x = pos.x + room - drawn
		elif alignment == HORIZONTAL_ALIGNMENT_CENTER:
			x = pos.x + (room - drawn) * 0.5
	draw_text(canvas, Vector2(x, pos.y - cap), text, cap, color, tracking)


## Drop-in for `Font.get_string_size(text, alignment, width, font_size)`,
## measuring what `draw_string_compat` will actually draw.
static func string_size_compat(text: String, _alignment := HORIZONTAL_ALIGNMENT_LEFT, room := -1.0, font_size := 16) -> Vector2:
	var measured := width(text, float(font_size) * 0.72, float(font_size) * 0.08)
	if room > 0.0:
		measured = minf(measured, room)
	return Vector2(measured, float(font_size))
