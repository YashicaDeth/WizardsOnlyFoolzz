class_name NatalSigil
extends Control

## The Allusions screen as a natal wheel collapsed into a sigil.
##
## `DESIGN.md` §16 already puts chaos magick in the world's rules, and the Tree
## of Life axis in `world_history.gd` already reads subjects on an
## Ascent/Limbo/Descent line. This draws the other half of that idea: a birth
## chart, and then the chart *reduced* — which is the actual chaos magick
## operation. A sigil is made by taking a statement, striking out everything
## repeated, and binding what is left into one mark. Here the statement is a
## chart and the repeated elements are its aspect lines.
##
## **This is symbolic, not astronomical.** It does not compute real planetary
## positions from an ephemeris; it places them deterministically from the birth
## date so the same date always draws the same chart. For a sigil that is the
## correct choice — the mark matters, not the astronomy — but it should not be
## described to anyone as a real natal chart.

const VOID := Color("060b09")
const INK := Color("dce6ba")
const ACID := Color("b4da48")
const SPORE := Color("9bf01a")
const ARTERIAL := Color("c81f16")
const BILE := Color("b8a12a")
const BRUISE := Color("6a2d6e")
const SCAN := Color("35b7a7")

const SIGNS := [
	"ARIES", "TAURUS", "GEMINI", "CANCER", "LEO", "VIRGO",
	"LIBRA", "SCORPIO", "SAGITTARIUS", "CAPRICORN", "AQUARIUS", "PISCES",
]
## Sign glyphs as stroke paths on a 10x10 box, drawn rather than typed so the
## wheel carries no font dependency and no imported symbol set.
const SIGN_MARKS := [
	[[[1, 8], [1, 4], [3, 2], [5, 4], [5, 8]], [[5, 4], [7, 2], [9, 4], [9, 8]]],
	[[[2, 3], [4, 1], [6, 1], [8, 3]], [[5, 4], [3, 6], [5, 9], [7, 6], [5, 4]]],
	[[[2, 1], [8, 1]], [[2, 9], [8, 9]], [[3.5, 1], [3.5, 9]], [[6.5, 1], [6.5, 9]]],
	[[[1, 4], [4, 2], [6, 4], [4, 5], [1, 4]], [[9, 7], [6, 9], [4, 7], [6, 6], [9, 7]]],
	[[[2, 8], [2, 5], [4, 3], [6, 5], [5, 8], [7, 9], [9, 7]]],
	[[[1, 2], [1, 8]], [[1, 3], [3, 2], [4, 4], [4, 8]], [[4, 3], [6, 2], [7, 4], [7, 8]], [[7, 5], [9, 6], [8, 9]]],
	[[[1, 7], [9, 7]], [[1, 9], [9, 9]], [[3, 7], [4.5, 4], [6.5, 4], [8, 7]]],
	[[[1, 2], [1, 8]], [[1, 3], [3, 2], [4, 4], [4, 8]], [[4, 3], [6, 2], [7, 4], [7, 8]], [[7, 8], [9, 8], [8.2, 6]]],
	[[[1, 9], [8, 2]], [[5, 2], [8, 2], [8, 5]], [[3, 6], [6, 9]]],
	[[[1, 3], [3, 7], [5, 3], [5, 7]], [[5, 7], [7, 6], [8, 8], [6, 9], [5, 7]]],
	[[[1, 4], [3, 2], [5, 4], [7, 2], [9, 4]], [[1, 7], [3, 5], [5, 7], [7, 5], [9, 7]]],
	[[[2, 1], [2, 9]], [[8, 1], [8, 9]], [[2, 5], [8, 5]]],
]
const BODIES := ["SOL", "LUNA", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO"]

## Greg's own chart, which is the point: the Allusions screen is his archive,
## so the mark the game binds is his. 11 January 2007, small hours.
var birth_year := 2007
var birth_month := 1
var birth_day := 11
var birth_hour := 2
var subject_name := "GREG"
var clock := 0.0
var placements: Array[Dictionary] = []
var sigil_path := PackedVector2Array()
var reveal := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(true)


## `birth` accepts {"year": int, "month": int, "day": int, "hour": int,
## "name": String}. Anything missing keeps its current value, so the chart can
## be filled in as the details arrive.
func configure(birth: Dictionary) -> void:
	birth_year = int(birth.get("year", birth_year))
	birth_month = int(birth.get("month", birth_month))
	birth_day = int(birth.get("day", birth_day))
	birth_hour = int(birth.get("hour", birth_hour))
	subject_name = str(birth.get("name", subject_name)).to_upper()
	_cast()


func open_chart() -> void:
	visible = true
	reveal = 0.0
	clock = 0.0
	if placements.is_empty():
		_cast()


func close_chart() -> void:
	visible = false


func sun_sign() -> String:
	# Ordinary tropical sign boundaries. This part is real; the placements are
	# the symbolic half. SIGNS starts at Aries, which is the *third* month, so
	# indexing it by month-1 put every date three signs out — August read as
	# Libra instead of Leo.
	const CUSPS := [20, 19, 21, 20, 21, 21, 23, 23, 23, 23, 22, 22]
	var index := (birth_month + 8) % 12
	if birth_day >= CUSPS[birth_month - 1]:
		index = (index + 1) % 12
	return SIGNS[index]


## Deterministic placement from the birth date. Same date, same chart, forever —
## which is what a sigil needs. Not an ephemeris.
func _cast() -> void:
	placements.clear()
	var seed_value := birth_year * 10000 + birth_month * 100 + birth_day
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in BODIES.size():
		var angle := fposmod(float(seed_value * (index + 3) % 360) + rng.randf_range(-14.0, 14.0), 360.0)
		placements.append({
			"body": BODIES[index],
			"angle": deg_to_rad(angle - 90.0),
			"orbit": 0.52 + float(index) * 0.035,
			"weight": rng.randf_range(0.5, 1.0),
		})
	_bind_sigil()


## The reduction. Aspect lines are drawn between bodies that fall close to the
## classical angles; the sigil is the path that visits those meeting points in
## order and closes, with repeats struck out — the chaos magick operation done
## on a chart instead of on a sentence.
func _bind_sigil() -> void:
	var meetings: Array[Vector2] = []
	var seen: Dictionary = {}
	for a in placements.size():
		for b in range(a + 1, placements.size()):
			var separation := absf(rad_to_deg(placements[a].angle - placements[b].angle))
			separation = fposmod(separation, 360.0)
			if separation > 180.0:
				separation = 360.0 - separation
			var aspected := false
			for classical in [0.0, 60.0, 90.0, 120.0, 180.0]:
				if absf(separation - classical) <= 7.0:
					aspected = true
					break
			if not aspected:
				continue
			var midpoint := Vector2.from_angle(float(placements[a].angle)) * float(placements[a].orbit)
			midpoint += Vector2.from_angle(float(placements[b].angle)) * float(placements[b].orbit)
			midpoint *= 0.5
			# Strike out repeats: that is the whole operation.
			var key := "%d,%d" % [roundi(midpoint.x * 14), roundi(midpoint.y * 14)]
			if seen.has(key):
				continue
			seen[key] = true
			meetings.append(midpoint)
	meetings.sort_custom(func(p, q): return p.angle() < q.angle())
	sigil_path = PackedVector2Array(meetings)


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	reveal = minf(1.0, reveal + delta * 0.5)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var centre := size * Vector2(0.5, 0.54)
	var radius := minf(size.x, size.y) * 0.38
	draw_rect(Rect2(Vector2.ZERO, size), VOID)

	_draw_wheel(centre, radius)
	_draw_aspects(centre, radius)
	_draw_sigil(centre, radius)
	_draw_plate()


func _draw_wheel(centre: Vector2, radius: float) -> void:
	for ring in [1.0, 0.86, 0.5]:
		draw_arc(centre, radius * ring, 0.0, TAU, 96, INK * Color(1, 1, 1, 0.22), 1.2)
	for house in 12:
		var angle := TAU * float(house) / 12.0 - PI * 0.5
		var outer := centre + Vector2.from_angle(angle) * radius
		var inner := centre + Vector2.from_angle(angle) * radius * 0.5
		draw_line(inner, outer, INK * Color(1, 1, 1, 0.16), 1.0)
		# Sign mark in the outer band.
		var mark_at := centre + Vector2.from_angle(angle + TAU / 24.0) * radius * 0.93
		_draw_mark(SIGN_MARKS[house], mark_at, radius * 0.052, (ACID if SIGNS[house] == sun_sign() else INK) * Color(1, 1, 1, 0.85 if SIGNS[house] == sun_sign() else 0.34))
	# The Ascent / Limbo / Descent axis the rest of the game already reads on.
	draw_line(centre - Vector2(0, radius * 1.06), centre + Vector2(0, radius * 1.06), SPORE * Color(1, 1, 1, 0.2), 1.0)
	CellOutzType.draw_text(self, centre + Vector2(-radius * 0.16, -radius * 1.16), "ASCENT", radius * 0.045, SPORE * Color(1, 1, 1, 0.5), 2.0)
	CellOutzType.draw_text(self, centre + Vector2(-radius * 0.18, radius * 1.1), "DESCENT", radius * 0.045, ARTERIAL * Color(1, 1, 1, 0.5), 2.0)


## Sign glyphs are stroke paths on a 10x10 box, same approach as the display
## face: drawn, so the wheel carries no imported symbol set.
func _draw_mark(strokes: Array, at: Vector2, scale: float, color: Color) -> void:
	for stroke in strokes:
		var points := PackedVector2Array()
		for point in stroke:
			points.append(at + (Vector2(float(point[0]), float(point[1])) - Vector2(5, 5)) * scale * 0.2)
		if points.size() == 2:
			draw_line(points[0], points[1], color, maxf(1.0, scale * 0.16))
		else:
			draw_polyline(points, color, maxf(1.0, scale * 0.16))


func _draw_aspects(centre: Vector2, radius: float) -> void:
	for a in placements.size():
		var at := centre + Vector2.from_angle(float(placements[a].angle)) * radius * float(placements[a].orbit)
		for b in range(a + 1, placements.size()):
			var to := centre + Vector2.from_angle(float(placements[b].angle)) * radius * float(placements[b].orbit)
			var separation := absf(rad_to_deg(placements[a].angle - placements[b].angle))
			separation = fposmod(separation, 360.0)
			if separation > 180.0:
				separation = 360.0 - separation
			for classical in [0.0, 60.0, 90.0, 120.0, 180.0]:
				if absf(separation - classical) > 7.0:
					continue
				var tint := SCAN if classical in [60.0, 120.0] else ARTERIAL
				draw_line(at, to, tint * Color(1, 1, 1, 0.2 * reveal), 1.0)
				break
	for placement in placements:
		var at := centre + Vector2.from_angle(float(placement.angle)) * radius * float(placement.orbit)
		draw_circle(at, radius * 0.016 * (0.6 + float(placement.weight) * 0.6), BILE * Color(1, 1, 1, 0.85 * reveal))
		CellOutzType.draw_text(self, at + Vector2(radius * 0.028, -radius * 0.02), str(placement.body), radius * 0.033, INK * Color(1, 1, 1, 0.45 * reveal), 1.2)


## The bound mark, drawn over its own chart. It breathes, because a sigil that
## sits still is a logo.
func _draw_sigil(centre: Vector2, radius: float) -> void:
	if sigil_path.size() < 2:
		return
	var breath := 1.0 + sin(clock * 1.4) * 0.012
	var points := PackedVector2Array()
	var shown := maxi(2, int(float(sigil_path.size()) * reveal))
	for index in shown:
		points.append(centre + sigil_path[index] * radius * breath)
	points.append(points[0])
	draw_polyline(points, ARTERIAL * Color(1, 1, 1, 0.28), 9.0)
	draw_polyline(points, ACID, 2.4)
	for point in points:
		draw_circle(point, 3.0, SPORE)


func _draw_plate() -> void:
	CellOutzType.draw_stamped(self, Vector2(44, 36), "NATAL SIGIL", 22.0, ACID, ARTERIAL * Color(1, 1, 1, 0.3), 3.4)
	CellOutzType.draw_text(self, Vector2(44, 76), "%s / SUN IN %s" % [subject_name, sun_sign()], 13.0, INK * Color(1, 1, 1, 0.7), 1.8)
	CellOutzType.draw_text(self, Vector2(44, 98), "%04d-%02d-%02d  BOUND %02d MEETINGS" % [birth_year, birth_month, birth_day, sigil_path.size()], 11.0, BILE * Color(1, 1, 1, 0.6), 1.4)
	draw_string(ThemeDB.fallback_font, Vector2(44, size.y - 40), "Symbolic chart. Placements are derived from the date, not from an ephemeris.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.3))
	CellOutzType.draw_text(self, Vector2(44, size.y - 26), "J  RETURN", 11.0, ACID * Color(1, 1, 1, 0.55), 2.0)
