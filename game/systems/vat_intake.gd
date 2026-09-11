extends Control

## The intake form, filled in about you while you float in it.
##
## D3 and D7. `DESIGN/CHARACTER_CREATION.md` puts the creator in the vat because
## it closes two open problems at once — the opening is under-directed, and the
## game has no character creation at all — and because of one joke that turns
## out to be the spine of the whole thing:
##
## **You cannot speak. The tube is in.** So the handler asks, you blink or
## twitch, and *he* writes down what he thinks you said. The character sheet is
## a document produced about you by a bored man on a night shift, which puts
## §13's pillar — information is partial, late, manipulated or false — on the
## player's own record inside the first five minutes.
##
## D7's mirror obeys the same logic. It is on a swing arm over the tank and you
## are looking through growth medium and curved glass, so **the preview is
## wrong**: the face wobbles, and what you are actually editing is only settled
## once you are decanted. Underneath it you edit the skeleton, the organ set and
## the blood, because `baseline_human.gd` and `kill_cam.gd` already draw the
## real ones — every choice here is visible the first time somebody opens you up.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const Grunge := preload("res://systems/celloutz_grunge.gd")
const Motion := preload("res://systems/celloutz_motion.gd")
const SHEET := preload("res://systems/character_sheet.gd")

signal filed(state: Dictionary)

const INK := Color("e6d4ac")
const COPPER := Color("b0552a")
const HOT := Color("a8281a")
const MOSS := Color("8a9a4a")
const BRUISE := Color("6b3f6e")
const GOO := Color("3e4a2a")
const PAPER := Color(0.86, 0.80, 0.63)

const ROUTES := ["PRESET", "RANDOM", "CHART", "INSTRUMENT"]
const PAGES := ["ROUTE", "RACE", "TRAITS", "BODY", "SCHEDULE"]

## What the handler says while he works. He is not talking to you so much as
## near you, which is the register the whole scene runs in.
const HANDLER_LINES := [
	"Don't try to talk. Blink once for yes. I'll know.",
	"Right. Intake. This is the bit where you become a number.",
	"Debt's already in the meat, so the form's a formality.",
	"You'd be amazed how many of these come back wrong.",
	"I've done four hundred of these. Four hundred and one.",
	"Nod if you understand. Not like that. Fine, I'll put yes.",
]

var sheet: CharacterSheet
var page := 0
var row := 0
var elapsed := 0.0
var handler_line := 0
var handler_life := 0.0
## What he has just written down, which is not always what you chose.
var transcript := ""
var transcript_life := 0.0
var mirror_settle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet = SHEET.new()
	set_process(true)
	_speak()


func _speak() -> void:
	handler_line = (handler_line + 1) % HANDLER_LINES.size()
	handler_life = 5.0


## D3. He writes down what he *thinks* you said. Usually right, occasionally
## not, and with CLERICAL ERROR taken it is a coin toss — the trait does not add
## the behaviour, it makes the behaviour worse.
func _transcribe(intent: String) -> void:
	var slip := 0.12
	if sheet.traits.has("clerical_error"):
		slip = 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(intent) + int(elapsed * 1000.0)) & 0x7fffffff
	if rng.randf() < slip:
		var wrong := ["YES", "NO", "DECLINED", "UNREADABLE", "SEE OVERLEAF", "N/A"]
		transcript = "WROTE: %s" % wrong[rng.randi_range(0, wrong.size() - 1)]
	else:
		transcript = "WROTE: %s" % intent.to_upper()
	transcript_life = 3.2


func _process(delta: float) -> void:
	elapsed += delta
	handler_life = maxf(0.0, handler_life - delta)
	transcript_life = maxf(0.0, transcript_life - delta)
	if handler_life <= 0.0:
		_speak()
	mirror_settle = Motion.approach(mirror_settle, 1.0 if page == 3 else 0.0, delta, Motion.PANEL)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT:
			page = wrapi(page - 1, 0, PAGES.size())
			row = 0
		KEY_RIGHT:
			page = wrapi(page + 1, 0, PAGES.size())
			row = 0
		KEY_UP:
			row = maxi(0, row - 1)
		KEY_DOWN:
			row = mini(_rows() - 1, row + 1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_commit()
		KEY_F:
			filed.emit(sheet.apply_to_world())
		_:
			return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _rows() -> int:
	match page:
		0:
			return ROUTES.size()
		1:
			return CharacterSheet.RACES.size()
		2:
			return CharacterSheet.TRAITS.size()
		3:
			return 4
		_:
			return CharacterSheet.MODIFIERS.size()


func _commit() -> void:
	match page:
		0:
			sheet.route = ROUTES[row].to_lower()
			if sheet.route == "random":
				sheet.randomise()
			_transcribe(ROUTES[row])
		1:
			sheet.race = str(CharacterSheet.RACES.keys()[row])
			_transcribe(str((CharacterSheet.RACES[sheet.race] as Dictionary).name))
		2:
			var trait_id := str(CharacterSheet.TRAITS.keys()[row])
			if sheet.toggle_trait(trait_id):
				_transcribe(str((CharacterSheet.TRAITS[trait_id] as Dictionary).name))
			else:
				transcript = "WROTE: NO BUDGET"
				transcript_life = 2.4
		3:
			# D7. Under the skin, because the kill cam will show it later.
			match row:
				0:
					sheet.under_skin["blood"] = _cycle(["O-RUST", "A-ASH", "B-9", "AB-", "SAP", "NULL"], str(sheet.under_skin.get("blood", "O-RUST")))
				1:
					sheet.under_skin["skeleton"] = _cycle(["standard", "dense", "hollow", "plated"], str(sheet.under_skin.get("skeleton", "standard")))
				2:
					sheet.under_skin["organs"] = _cycle(["standard", "doubled", "salvaged", "communion"], str(sheet.under_skin.get("organs", "standard")))
				_:
					sheet.appearance["face"] = fmod(float(sheet.appearance.get("face", 0.5)) + 0.17, 1.0)
			_transcribe("BODY")
		_:
			var key := str(CharacterSheet.MODIFIERS.keys()[row])
			if sheet.modifiers.has(key):
				sheet.modifiers.erase(key)
			else:
				sheet.modifiers.append(key)
			_transcribe(str((CharacterSheet.MODIFIERS[key] as Dictionary).name))


func _cycle(options: Array, current: String) -> String:
	var index := options.find(current)
	return str(options[(index + 1) % options.size()])


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var viewport := size
	if viewport.x < 640 or viewport.y < 400:
		return
	_draw_tank(viewport)
	var board := Rect2(Vector2(viewport.x * 0.36, 54), Vector2(viewport.x * 0.40, viewport.y - 150))
	_draw_clipboard(board)
	_draw_mirror(Rect2(Vector2(viewport.x * 0.79, 96), Vector2(viewport.x * 0.18, viewport.y * 0.52)))
	_draw_handler(viewport)


## You are looking out through it, so the whole screen is under water before
## anything else is drawn on top.
func _draw_tank(viewport: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.06, 0.075, 0.05, 1.0))
	for band in 26:
		var travel := float(band) / 26.0
		draw_rect(Rect2(Vector2(0, viewport.y * travel), Vector2(viewport.x, viewport.y / 26.0 + 1.0)), GOO * Color(1, 1, 1, 0.05 + sin(elapsed * 0.6 + travel * 7.0) * 0.02))
	# Bubbles, rising. Fixed columns so it reads as a tank rather than noise.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3311
	for index in 40:
		var column := rng.randf()
		var speed := 0.12 + rng.randf() * 0.3
		var height := fposmod(1.0 - (elapsed * speed + rng.randf()), 1.0)
		var at := Vector2(column * viewport.x, height * viewport.y)
		draw_circle(at, 1.5 + rng.randf() * 3.5, Color(0.75, 0.85, 0.7, 0.10))
	# The tube, in the corner of your own eye. It is always there.
	draw_line(Vector2(viewport.x * 0.5, viewport.y), Vector2(viewport.x * 0.46, viewport.y * 0.78), Color(0.5, 0.45, 0.38, 0.5), 9.0)
	draw_line(Vector2(viewport.x * 0.5, viewport.y), Vector2(viewport.x * 0.46, viewport.y * 0.78), Color(0.2, 0.18, 0.15, 0.6), 5.0)
	Grunge.grain(self, Rect2(Vector2.ZERO, viewport), 7717, 700)


func _draw_clipboard(rect: Rect2) -> void:
	# A board with paper on it, held at an angle by somebody standing over you.
	draw_set_transform(rect.position + Vector2(0, 12), -0.022, Vector2.ONE)
	var board := Rect2(Vector2.ZERO, rect.size)
	draw_rect(board, Color(0.16, 0.13, 0.10))
	draw_rect(board, Color(0.30, 0.24, 0.17), false, 2.0)
	var sheet_rect := Rect2(Vector2(12, 34), rect.size - Vector2(24, 52))
	draw_rect(sheet_rect, PAPER * Color(1, 1, 1, 0.92))
	Grunge.stain(self, sheet_rect.position + sheet_rect.size * Vector2(0.8, 0.12), 60.0, 881, Grunge.BILE, 0.16)
	Grunge.stain(self, sheet_rect.position + sheet_rect.size * Vector2(0.15, 0.9), 44.0, 883, Grunge.RUST, 0.13)
	# The clip.
	draw_rect(Rect2(Vector2(rect.size.x * 0.5 - 34, 6), Vector2(68, 22)), Color(0.42, 0.38, 0.30))
	draw_rect(Rect2(Vector2(rect.size.x * 0.5 - 34, 6), Vector2(68, 22)), Color(0.18, 0.15, 0.12), false, 1.5)

	var ink := Color(0.16, 0.12, 0.10)
	CellOutzType.draw_stamped(self, Vector2(26, 46), "INTAKE", 20.0, ink, HOT * Color(1, 1, 1, 0.22), 1.6)
	CellOutzType.draw_condensed(self, Vector2(26, 72), "CELLOUTZ GROWING FLOOR // FORM CZ-00/I // ONE PER BODY", 9.0, ink * Color(1, 1, 1, 0.6), 0.7)

	# Page tabs along the top of the paper.
	var tab_x := 26.0
	for index in PAGES.size():
		var label: String = PAGES[index]
		var width := CellOutzType.width_condensed(label, 10.0, 0.8) + 16.0
		if index == page:
			draw_rect(Rect2(Vector2(tab_x - 5, 86), Vector2(width, 18)), HOT * Color(1, 1, 1, 0.16))
			draw_line(Vector2(tab_x - 5, 104), Vector2(tab_x - 5 + width, 104), HOT, 1.6)
		CellOutzType.draw_condensed(self, Vector2(tab_x, 90), label, 10.0, ink * Color(1, 1, 1, 1.0 if index == page else 0.45), 0.8)
		tab_x += width + 6.0

	var y := 124.0
	match page:
		0:
			_draw_routes(rect, ink, y)
		1:
			_draw_races(rect, ink, y)
		2:
			_draw_traits(rect, ink, y)
		3:
			_draw_body(rect, ink, y)
		_:
			_draw_schedule(rect, ink, y)

	# The running total, at the foot of the form where a clerk would put it.
	var values := sheet.attributes()
	var footer := rect.size.y - 74.0
	draw_line(Vector2(26, footer - 12), Vector2(rect.size.x - 26, footer - 12), ink * Color(1, 1, 1, 0.3), 1.0)
	var column := 26.0
	for key in CharacterSheet.ATTRIBUTES:
		CellOutzType.draw_condensed(self, Vector2(column, footer), str(key).substr(0, 4).to_upper(), 8.0, ink * Color(1, 1, 1, 0.5), 0.7)
		CellOutzType.draw_condensed(self, Vector2(column, footer + 12), "%04.1f" % float(values[key]), 14.0, ink, 0.9)
		column += rect.size.x * 0.22
	CellOutzType.draw_condensed(self, Vector2(26, footer + 36), "%s // %s RISING // %s" % [sheet.sun_sign(), sheet.ascendant(), sheet.modality().to_upper()], 9.0, ink * Color(1, 1, 1, 0.55), 0.7)
	CellOutzType.draw_condensed(self, Vector2(rect.size.x - 150, footer + 36), "F TO FILE", 10.0, HOT, 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _row_mark(ink: Color, at: Vector2, active: bool, ticked: bool) -> void:
	draw_rect(Rect2(at, Vector2(11, 11)), ink * Color(1, 1, 1, 0.55), false, 1.2)
	if ticked:
		draw_line(at + Vector2(2, 6), at + Vector2(4.5, 9), ink, 1.8)
		draw_line(at + Vector2(4.5, 9), at + Vector2(9, 1.5), ink, 1.8)
	if active:
		draw_line(at + Vector2(-12, 5.5), at + Vector2(-4, 5.5), HOT, 2.0)


func _draw_routes(rect: Rect2, ink: Color, y: float) -> void:
	for index in ROUTES.size():
		var label: String = ROUTES[index]
		_row_mark(ink, Vector2(30, y - 9), index == row, sheet.route == label.to_lower())
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), label, 13.0, ink, 0.9)
		var note: String = ["authored, canonical", "the decanting lottery", "birth date, time, place", "the questionnaire"][index]
		CellOutzType.draw_condensed(self, Vector2(180, y - 8), note.to_upper(), 8.0, ink * Color(1, 1, 1, 0.45), 0.7)
		y += 26.0


func _draw_races(rect: Rect2, ink: Color, y: float) -> void:
	var keys: Array = CharacterSheet.RACES.keys()
	for index in keys.size():
		var data: Dictionary = CharacterSheet.RACES[keys[index]]
		_row_mark(ink, Vector2(30, y - 9), index == row, sheet.race == str(keys[index]))
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), str(data.name), 12.0, ink, 0.9)
		CellOutzType.draw_condensed(self, Vector2(50, y + 4), str(data.price).to_upper(), 7.0, ink * Color(1, 1, 1, 0.42), 0.6)
		y += 30.0


func _draw_traits(rect: Rect2, ink: Color, y: float) -> void:
	CellOutzType.draw_condensed(self, Vector2(30, y - 14), "BUDGET %02d" % sheet.points_left(), 11.0, HOT if sheet.points_left() <= 0 else ink, 0.8)
	y += 12.0
	var keys: Array = CharacterSheet.TRAITS.keys()
	for index in keys.size():
		var data: Dictionary = CharacterSheet.TRAITS[keys[index]]
		var cost := int(data.get("cost", 0))
		_row_mark(ink, Vector2(30, y - 9), index == row, sheet.traits.has(str(keys[index])))
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), str(data.name), 11.0, ink, 0.8)
		var cost_text := ("+%d" % -cost) if cost < 0 else "-%d" % cost
		CellOutzType.draw_condensed(self, Vector2(rect.size.x - 62, y - 10), cost_text, 11.0, (MOSS if cost < 0 else HOT).darkened(0.35), 0.8)
		y += 24.0


func _draw_body(rect: Rect2, ink: Color, y: float) -> void:
	var rows := [
		["BLOOD", str(sheet.under_skin.get("blood", "O-RUST"))],
		["SKELETON", str(sheet.under_skin.get("skeleton", "standard")).to_upper()],
		["ORGAN SET", str(sheet.under_skin.get("organs", "standard")).to_upper()],
		["FACE", "SETTING %02d" % int(float(sheet.appearance.get("face", 0.5)) * 99.0)],
	]
	for index in rows.size():
		_row_mark(ink, Vector2(30, y - 9), index == row, false)
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), str(rows[index][0]), 11.0, ink * Color(1, 1, 1, 0.6), 0.8)
		CellOutzType.draw_condensed(self, Vector2(190, y - 10), str(rows[index][1]), 12.0, ink, 0.9)
		y += 28.0
	CellOutzType.draw_condensed(self, Vector2(30, y + 10), "WHAT IS UNDER THE SKIN IS WHAT THEY WILL FIND.", 8.0, ink * Color(1, 1, 1, 0.42), 0.7)


func _draw_schedule(rect: Rect2, ink: Color, y: float) -> void:
	var keys: Array = CharacterSheet.MODIFIERS.keys()
	for index in keys.size():
		var data: Dictionary = CharacterSheet.MODIFIERS[keys[index]]
		_row_mark(ink, Vector2(30, y - 9), index == row, sheet.modifiers.has(str(keys[index])))
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), str(data.name), 12.0, ink, 0.9)
		CellOutzType.draw_condensed(self, Vector2(50, y + 4), str(data.gives).to_upper(), 7.0, MOSS.darkened(0.4), 0.6)
		CellOutzType.draw_condensed(self, Vector2(50, y + 14), str(data.costs).to_upper(), 7.0, HOT.darkened(0.3), 0.6)
		y += 42.0


## D7. A mirror on a swing arm, and the face in it is not quite yours yet.
func _draw_mirror(rect: Rect2) -> void:
	var arm_from := Vector2(rect.position.x - 40, rect.position.y - 30)
	draw_line(arm_from, rect.position + Vector2(10, 10), Color(0.30, 0.26, 0.20), 6.0)
	draw_circle(arm_from, 5.0, Color(0.38, 0.33, 0.25))
	draw_rect(rect.grow(6), Color(0.22, 0.19, 0.15))
	draw_rect(rect, Color(0.10, 0.12, 0.09))
	draw_rect(rect.grow(6), Color(0.36, 0.30, 0.22), false, 2.0)

	# The face, drawn as a wobbling silhouette. The wobble is the point: you are
	# looking through growth medium at yourself and it will not hold still.
	var centre := rect.position + rect.size * Vector2(0.5, 0.44)
	var radius := rect.size.x * 0.30
	var setting := float(sheet.appearance.get("face", 0.5))
	var points := PackedVector2Array()
	for index in 30:
		var angle := TAU * float(index) / 30.0
		var wobble := 1.0 + sin(angle * 3.0 + elapsed * 1.3) * 0.06 + sin(angle * 5.0 - elapsed * 0.9) * 0.04
		var jaw := 1.0 + cos(angle) * (setting - 0.5) * 0.28
		points.append(centre + Vector2(sin(angle) * radius * wobble * jaw, -cos(angle) * radius * 1.22 * wobble))
	draw_colored_polygon(points, Color(0.42, 0.33, 0.29, 0.55))
	var edge := points.duplicate()
	edge.append(points[0])
	draw_polyline(edge, INK * Color(1, 1, 1, 0.32), 1.4)
	for eye in [-1.0, 1.0]:
		draw_circle(centre + Vector2(eye * radius * 0.34, -radius * 0.18), radius * 0.09, Color(0.06, 0.05, 0.05, 0.8))
	# The tube, in your mouth, in the mirror.
	draw_line(centre + Vector2(0, radius * 0.5), centre + Vector2(-radius * 0.2, radius * 1.5), Color(0.5, 0.45, 0.38, 0.7), 5.0)

	CellOutzType.draw_condensed(self, rect.position + Vector2(10, rect.size.y - 34), "PREVIEW IS THROUGH GLASS", 8.0, INK * Color(1, 1, 1, 0.4), 0.7)
	CellOutzType.draw_condensed(self, rect.position + Vector2(10, rect.size.y - 22), "AND THROUGH MEDIUM", 8.0, INK * Color(1, 1, 1, 0.28), 0.7)


func _draw_handler(viewport: Vector2) -> void:
	# He is a silhouette above the glass. You never see him properly.
	var head := Vector2(viewport.x * 0.17, viewport.y * 0.30)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-70, 200), head + Vector2(-54, 30), head + Vector2(-22, -6),
		head + Vector2(24, -6), head + Vector2(56, 30), head + Vector2(72, 200),
	]), Color(0.04, 0.05, 0.04, 0.88))
	draw_circle(head, 34.0, Color(0.04, 0.05, 0.04, 0.9))
	var band := Rect2(Vector2(40, viewport.y - 92), Vector2(viewport.x * 0.32, 70))
	draw_colored_polygon(PackedVector2Array([
		band.position + Vector2(10, 0), band.position + Vector2(band.size.x, 0),
		band.position + band.size - Vector2(10, 0), band.position + Vector2(0, band.size.y),
	]), Color(0.03, 0.035, 0.03, 0.82))
	CellOutzType.draw_condensed(self, band.position + Vector2(14, 12), "HANDLER", 9.0, COPPER, 0.7)
	var line: String = HANDLER_LINES[handler_line]
	CellOutzType.draw_condensed(self, band.position + Vector2(14, 28), line.to_upper(), 11.0, INK * Color(1, 1, 1, clampf(handler_life, 0.0, 1.0) * 0.9), 0.8)
	if transcript_life > 0.0:
		CellOutzType.draw_condensed(self, band.position + Vector2(14, 50), transcript, 10.0, MOSS * Color(1, 1, 1, clampf(transcript_life, 0.0, 1.0)), 0.8)
