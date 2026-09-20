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
## D3.5 v2. `line_for()` indexes each pool with `handler_line % pool.size()`,
## and `handler_line` used to start at zero every single decanting — so the
## first idle line was always the same line, then the same second one, in
## the same order, forever. Rolled once per scene rather than per moment, so
## which line starts each pool varies decanting to decanting while a single
## intake still plays the same way twice if replayed (the property the file's
## own doc actually asks for — determinism within a sitting, not across new
## characters).
var line_offset := 0
## D3.4. What he is actually saying, and how long he sits with it. The line used
## to be an index into a rota on a flat timer; it is now whatever the moment
## called for, held for as long as that particular line is worth holding.
var handler_says := ""
## AX1.2. The doctor is a second presence, not a second mood of the handler.
## He speaks rarely and never about paperwork.
var doctor_says := ""
var doctor_life := 0.0
var doctor_moment := 0
## AX2.2. Carried out of the examination and into the breakout.
var refusals := 0
## AX1.5. Which saved build a repeat player came back with, if any.
var preset_loaded := ""
## AX2.1. His closing beats, played before the form is actually filed.
var verdict: Array = []
## D8.3. A procedure in progress: the beats left to play, and the shot each one
## wants. Input is suspended while it runs, because it is being done to you.
var procedure: Array = []
var shot := "tank"
## What he has just written down, which is not always what you chose.
var transcript := ""
var transcript_life := 0.0
var mirror_settle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet = SHEET.new()
	var offset_rng := RandomNumberGenerator.new()
	offset_rng.randomize()
	line_offset = offset_rng.randi()
	set_process(true)
	_speak()


## D3.4. He answers the moment rather than reading down a list. The hold comes
## with the line, so the pause after a mistranscription is not the pause after
## ticking a box.
func _speak(context: String = "idle") -> void:
	handler_line += 1
	var beat := IntakeDirection.line_for(context, handler_line + line_offset)
	handler_says = str(beat.line)
	handler_life = float(beat.hold)


## D8.3. Signing for something is a thing he does to you, on camera, saying what
## it costs while he does it. Refusing gets its own beat, because declining is
## the harder road and it should feel chosen rather than skipped.
func _play_procedure(modifier_id: String, accepted: bool) -> void:
	procedure = IntakeDirection.procedure(modifier_id, accepted)
	if procedure.is_empty():
		return
	_advance_procedure()


func _advance_procedure() -> void:
	if procedure.is_empty():
		shot = "tank"
		_speak("chose")
		return
	var beat: Dictionary = procedure.pop_front()
	handler_says = str(beat.get("line", ""))
	handler_life = float(beat.get("hold", 2.6))
	shot = str(beat.get("shot", "tank"))


## D3. He writes down what he *thinks* you said. Usually right, occasionally
## not, and with CLERICAL ERROR taken it is a coin toss — the trait does not add
## the behaviour, it makes the behaviour worse.
## D4.6 v2. `success_context` is what he says when it goes down clean — the
## generic "chose" pool by default, or something that actually answers what
## was just picked (a race, currently) when one is given. A slip still gets
## "slipped" regardless: getting your paperwork wrong is not the moment for
## him to have an opinion about who you are.
func _transcribe(intent: String, success_context: String = "chose") -> void:
	var slip := 0.12
	if sheet.traits.has("clerical_error"):
		slip = 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(intent) + int(elapsed * 1000.0)) & 0x7fffffff
	if rng.randf() < slip:
		var wrong := ["YES", "NO", "DECLINED", "UNREADABLE", "SEE OVERLEAF", "N/A"]
		transcript = "WROTE: %s" % wrong[rng.randi_range(0, wrong.size() - 1)]
		# He knows. He is not going to fix it.
		if procedure.is_empty():
			_speak("slipped")
	else:
		transcript = "WROTE: %s" % intent.to_upper()
		if procedure.is_empty():
			_speak(success_context)
	transcript_life = 3.2


func _process(delta: float) -> void:
	elapsed += delta
	handler_life = maxf(0.0, handler_life - delta)
	doctor_life = maxf(0.0, doctor_life - delta)
	if doctor_life <= 0.0 and not verdict.is_empty():
		_advance_verdict()
	transcript_life = maxf(0.0, transcript_life - delta)
	if handler_life <= 0.0:
		# A procedure runs itself to the end before he goes back to muttering.
		if not procedure.is_empty():
			_advance_procedure()
		else:
			_speak()
	mirror_settle = Motion.approach(mirror_settle, 1.0 if page == 3 else 0.0, delta, Motion.PANEL)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# D8.3. While he is putting something into you, you are not filling in a
	# form. The scene runs to the end of its beats before it hands you back.
	if not procedure.is_empty():
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_LEFT:
			page = wrapi(page - 1, 0, PAGES.size())
			_doctor_observe()
			row = 0
		KEY_RIGHT:
			page = wrapi(page + 1, 0, PAGES.size())
			_doctor_observe()
			row = 0
			_speak("page")
		KEY_UP:
			row = maxi(0, row - 1)
		KEY_DOWN:
			row = mini(_rows() - 1, row + 1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_commit()
		KEY_F:
			# AX2.1. He does not let you leave without telling you what it was for.
			# The verdict plays first; filing happens when he has finished.
			if verdict.is_empty():
				_begin_verdict()
			else:
				_finish_filing()
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
			# AX1.3. Eight rows now: anatomy sits at the top of the body page,
			# because it is the first thing the facility decided about you.
			return 8
		_:
			return CharacterSheet.MODIFIERS.size()


func _commit() -> void:
	match page:
		0:
			sheet.route = ROUTES[row].to_lower()
			if sheet.route == "random":
				sheet.randomise()
			elif sheet.route == "preset":
				# AX1.5. The fast route for a repeat player. PRESET has been the
				# first option on the first page since this screen was written and
				# did nothing at all, which is a poor first promise to break.
				var saved: Array = CharacterPresets.names()
				if saved.is_empty():
					_speak("slipped")
					transcript = "WROTE: NO PRESET ON FILE"
					transcript_life = 3.2
				else:
					CharacterPresets.apply(str(saved[0]), sheet)
					preset_loaded = str(saved[0])
					transcript = "WROTE: ON FILE ALREADY // %s" % preset_loaded
					transcript_life = 3.6
					_doctor_observe()
			_transcribe(ROUTES[row])
		1:
			sheet.race = str(CharacterSheet.RACES.keys()[row])
			# D4.6 v2. He reacts to what you actually picked rather than
			# saying the same "noted" he says for anything else on the form.
			_transcribe(str((CharacterSheet.RACES[sheet.race] as Dictionary).name), "race_" + sheet.race)
		2:
			var trait_id := str(CharacterSheet.TRAITS.keys()[row])
			if sheet.toggle_trait(trait_id):
				_transcribe(str((CharacterSheet.TRAITS[trait_id] as Dictionary).name))
			else:
				transcript = "WROTE: NO BUDGET"
				transcript_life = 2.4
		3:
			# D7. Under the skin, because the kill cam will show it later. The
			# last three entries make the human/evolved line a choice that grows
			# onto the same player body rather than a lore label.
			match row:
				0:
					sheet.anatomy_sex = _cycle(CharacterSheet.ANATOMY_SEX.keys(), sheet.anatomy_sex)
				1:
					sheet.under_skin["blood"] = _cycle(["O-RUST", "A-ASH", "B-9", "AB-", "SAP", "NULL"], str(sheet.under_skin.get("blood", "O-RUST")))
				2:
					sheet.under_skin["skeleton"] = _cycle(["standard", "dense", "hollow", "plated"], str(sheet.under_skin.get("skeleton", "standard")))
				3:
					sheet.under_skin["organs"] = _cycle(["standard", "doubled", "salvaged", "communion"], str(sheet.under_skin.get("organs", "standard")))
				4:
					sheet.appearance["face"] = fmod(float(sheet.appearance.get("face", 0.5)) + 0.17, 1.0)
				5:
					sheet.appearance["wear"] = fmod(float(sheet.appearance.get("wear", 0.4)) + 0.2, 1.01)
				6:
					sheet.appearance["mutation"] = fmod(float(sheet.appearance.get("mutation", 0.0)) + 0.2, 1.01)
				7:
					sheet.appearance["ink"] = fmod(float(sheet.appearance.get("ink", 0.0)) + 0.25, 1.01)
				_:
					sheet.appearance["piercings"] = fmod(float(sheet.appearance.get("piercings", 0.0)) + 0.25, 1.01)
			_transcribe("BODY")
		_:
			var key := str(CharacterSheet.MODIFIERS.keys()[row])
			var accepted := not sheet.modifiers.has(key)
			if accepted:
				sheet.modifiers.append(key)
			else:
				sheet.modifiers.erase(key)
			_transcribe(str((CharacterSheet.MODIFIERS[key] as Dictionary).name))
			# D8.3. The flag is set either way; the difference is that you watch
			# it happen to you.
			_play_procedure(key, accepted)
			# AX2.2. Refusal during the examination is not flavour -- it is the half
			# of the breakthrough the player chooses, and SoulBreakthrough will not
			# awaken without it no matter how much the facility does to them.
			if not accepted:
				refusals += 1
				_doctor_note_refusal()


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
	_draw_doctor(viewport)


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


func _draw_routes(_rect: Rect2, ink: Color, y: float) -> void:
	for index in ROUTES.size():
		var label: String = ROUTES[index]
		_row_mark(ink, Vector2(30, y - 9), index == row, sheet.route == label.to_lower())
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), label, 13.0, ink, 0.9)
		var note: String = ["authored, canonical", "the decanting lottery", "birth date, time, place", "the questionnaire"][index]
		CellOutzType.draw_condensed(self, Vector2(180, y - 8), note.to_upper(), 8.0, ink * Color(1, 1, 1, 0.45), 0.7)
		y += 26.0


func _draw_races(_rect: Rect2, ink: Color, y: float) -> void:
	var keys: Array = CharacterSheet.RACES.keys()
	for index in keys.size():
		var data: Dictionary = CharacterSheet.RACES[keys[index]]
		_row_mark(ink, Vector2(30, y - 9), index == row, sheet.race == str(keys[index]))
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), str(data.name), 12.0, ink, 0.9)
		CellOutzType.draw_condensed(self, Vector2(50, y + 4), str(data.price).to_upper(), 7.0, ink * Color(1, 1, 1, 0.42), 0.6)
		# AX1.4. What you picked, and what the facility wrote down instead. Shown
		# together on purpose: the doc is explicit that the player's choice stays
		# accurate and it is the institution's diagnosis that is distorted.
		if sheet.race == str(keys[index]):
			var filed := DoctorExamination.classify(sheet)
			CellOutzType.draw_condensed(self, Vector2(300, y - 10), "FILED AS " + str(filed.label), 9.0, HOT * Color(1, 1, 1, 0.8), 0.7)
			CellOutzType.draw_condensed(self, Vector2(300, y + 4), str(filed.note).to_upper(), 7.0, HOT * Color(1, 1, 1, 0.45), 0.6)
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


func _draw_body(_rect: Rect2, ink: Color, y: float) -> void:
	var rows := [
		["ANATOMY", str((CharacterSheet.ANATOMY_SEX[sheet.anatomy_sex] as Dictionary).name)],
		["BLOOD", str(sheet.under_skin.get("blood", "O-RUST"))],
		["SKELETON", str(sheet.under_skin.get("skeleton", "standard")).to_upper()],
		["ORGAN SET", str(sheet.under_skin.get("organs", "standard")).to_upper()],
		["FACE", "SETTING %02d" % int(float(sheet.appearance.get("face", 0.5)) * 99.0)],
		["WEAR", "%.0f%%" % (float(sheet.appearance.get("wear", 0.4)) * 100.0)],
		["EVOLUTION", "%.0f%% // GROWTH / EYE / HORN" % (float(sheet.appearance.get("mutation", 0.0)) * 100.0)],
		["INK", "%.0f%%" % (float(sheet.appearance.get("ink", 0.0)) * 100.0)],
		["METAL", "%.0f%%" % (float(sheet.appearance.get("piercings", 0.0)) * 100.0)],
	]
	for index in rows.size():
		_row_mark(ink, Vector2(30, y - 9), index == row, false)
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), str(rows[index][0]), 11.0, ink * Color(1, 1, 1, 0.6), 0.8)
		CellOutzType.draw_condensed(self, Vector2(190, y - 10), str(rows[index][1]), 12.0, ink, 0.9)
		# AX1.3/AX1.4. The facility's word for the body it grew, beside the
		# player's. INTERSEX files as "F / STANDARD" because the form has no
		# second box -- the distortion is the paperwork's, never the body's.
		if index == 0:
			CellOutzType.draw_condensed(self, Vector2(340, y - 10), "FILED " + str(CharacterSheet.ANATOMY_SEX_FILED.get(sheet.anatomy_sex, "")), 8.0, HOT * Color(1, 1, 1, 0.72), 0.65)
		y += 28.0
	CellOutzType.draw_condensed(self, Vector2(30, y + 10), "WHAT IS UNDER THE SKIN IS WHAT THEY WILL FIND.", 8.0, ink * Color(1, 1, 1, 0.42), 0.7)


func _draw_schedule(_rect: Rect2, ink: Color, y: float) -> void:
	var keys: Array = CharacterSheet.MODIFIERS.keys()
	for index in keys.size():
		var data: Dictionary = CharacterSheet.MODIFIERS[keys[index]]
		_row_mark(ink, Vector2(30, y - 9), index == row, sheet.modifiers.has(str(keys[index])))
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), str(data.name), 12.0, ink, 0.9)
		CellOutzType.draw_condensed(self, Vector2(50, y + 4), str(data.gives).to_upper(), 7.0, MOSS.darkened(0.4), 0.6)
		CellOutzType.draw_condensed(self, Vector2(50, y + 14), str(data.costs).to_upper(), 7.0, HOT.darkened(0.3), 0.6)
		y += 42.0


## D7.4 v2. The wobble used to be four universal constants — every character's
## mirror lied with the exact same waveform regardless of what was actually on
## the sheet. This reads real data instead: `build` (how heavy the race runs)
## damps the wobble, and the skeleton choice sets how rigid the silhouette
## reads — a plated or dense skeleton barely moves, a hollow one swims. Race
## also shifts the wobble's phase, so two characters of different races are
## not only sized differently but actually distort differently.
func _mirror_distortion() -> Dictionary:
	var race_data: Dictionary = CharacterSheet.RACES.get(sheet.race, CharacterSheet.RACES.decanted)
	var build := float(race_data.get("build", 1.0))
	var rigidity: float = {"standard": 1.0, "dense": 0.55, "hollow": 1.7, "plated": 0.4}.get(str(sheet.under_skin.get("skeleton", "standard")), 1.0)
	var scale := rigidity / maxf(0.4, build)
	return {
		"amplitude": 0.06 * scale,
		"amplitude2": 0.04 * scale,
		"phase": float(hash(sheet.race) % 1000) * 0.001 * TAU,
	}


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
	var distortion := _mirror_distortion()
	var phase: float = distortion.phase
	var points := PackedVector2Array()
	for index in 30:
		var angle := TAU * float(index) / 30.0
		var wobble := 1.0 + sin(angle * 3.0 + elapsed * 1.3 + phase) * float(distortion.amplitude) + sin(angle * 5.0 - elapsed * 0.9 + phase) * float(distortion.amplitude2)
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


## AX1.2. He watches the page you are on, not the box you ticked. Arriving at
## a page is the beat; choosing within it belongs to the handler and his form.
func _doctor_observe() -> void:
	doctor_moment += 1
	var beat := DoctorExamination.observe(str(PAGES[page]).to_lower(), doctor_moment)
	if beat.is_empty():
		return
	doctor_says = str(beat.get("line", ""))
	doctor_life = float(beat.get("hold", 3.0))


## He stands on the other side of the glass from the handler, and unlike the
## handler he is lit — the doc has him studying you, which means you can see
## him doing it. The consent notice never leaves the screen because he never
## asked and never will.
## AX2.2. He notices refusal specifically. The handler writes it down as an
## answer; the doctor finds it interesting, which is worse.
func _doctor_note_refusal() -> void:
	var beat := DoctorExamination.observe("declined", refusals)
	if beat.is_empty():
		return
	doctor_says = str(beat.get("line", ""))
	doctor_life = float(beat.get("hold", 3.2))


## AX2.1. The closing sequence. He explains what the examination was for,
## which is worse than gloating, and then he starts to leave.
func _begin_verdict() -> void:
	verdict = DoctorExamination.verdict(sheet)
	_advance_verdict()


func _advance_verdict() -> void:
	if verdict.is_empty():
		# AX2.5. He does not wait to see what happens next. The window opens
		# here, while the player is still in the vat and cannot use it yet,
		# which is what makes reaching him afterwards urgent.
		DoctorExamination.begin_departure()
		_finish_filing()
		return
	var beat: Dictionary = verdict.pop_front()
	doctor_says = str(beat.get("line", ""))
	doctor_life = float(beat.get("hold", 3.2))


## What the examination produced, plus the two numbers the breakout needs:
## what was done to the player, and what they refused. AX2.2 reads these.
func _finish_filing() -> void:
	var state: Dictionary = sheet.apply_to_world()
	state["refusals"] = refusals
	state["filed_as"] = DoctorExamination.classify(sheet)
	# AX1.5. The doc asks for "roughly 10-15 minutes" on a deliberate first pass.
	# That is a claim about a human at a keyboard, so it cannot be asserted in a
	# suite -- but it can stop being a guess. Every filing records how long the
	# player actually took, and whether they came in on a preset, so a playtest
	# produces the number instead of an opinion about the number.
	WorldHistory.update_subject("player", {
		"examination_refusals": refusals,
		"institutional_classification": str(DoctorExamination.classify(sheet).label),
		"examination_seconds": int(elapsed),
		"examination_route": "preset:" + preset_loaded if preset_loaded != "" else "deliberate",
	}, "examination_filed")
	print("EXAMINATION FILED // %d:%02d // %s // %d refusals" % [int(elapsed) / 60, int(elapsed) % 60, ("PRESET " + preset_loaded) if preset_loaded != "" else "DELIBERATE", refusals])
	filed.emit(state)


func _draw_doctor(viewport: Vector2) -> void:
	# Top left, not top right: the right third of the screen is the face
	# preview panel, and 8pt dark red on near-black was invisible in the
	# capture. Opening the PNG is the only reason this was caught.
	CellOutzType.draw_condensed(
		self, Vector2(40, 34), DoctorExamination.CONSENT_NOTICE, 11.0,
		HOT.lightened(0.25) * Color(1, 1, 1, 0.72 + 0.28 * sin(elapsed * 2.0)), 0.8,
	)
	# He stands between the handler and the form, lit, close enough to read.
	# The right side belongs to the preview panel and drew over him entirely.
	var head := Vector2(viewport.x * 0.31, viewport.y * 0.26)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-58, 210), head + Vector2(-46, 26), head + Vector2(-20, -8),
		head + Vector2(22, -8), head + Vector2(48, 26), head + Vector2(60, 210),
	]), Color(0.07, 0.07, 0.08, 0.92))
	draw_circle(head, 30.0, Color(0.09, 0.09, 0.10, 0.94))
	if doctor_life <= 0.0 or doctor_says == "":
		return
	var band := Rect2(Vector2(viewport.x * 0.36, viewport.y - 92), Vector2(viewport.x * 0.30, 52))
	draw_colored_polygon(PackedVector2Array([
		band.position + Vector2(10, 0), band.position + Vector2(band.size.x, 0),
		band.position + band.size - Vector2(10, 0), band.position + Vector2(0, band.size.y),
	]), Color(0.05, 0.05, 0.06, 0.86))
	CellOutzType.draw_condensed(self, band.position + Vector2(14, 12), "VISITING PHYSICIAN", 9.0, BRUISE, 0.7)
	CellOutzType.draw_condensed(
		self, band.position + Vector2(14, 30), doctor_says.to_upper(), 11.0,
		PAPER * Color(1, 1, 1, clampf(doctor_life, 0.0, 1.0) * 0.95), 0.8,
	)


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
	var line: String = handler_says if handler_says != "" else HANDLER_LINES[handler_line % HANDLER_LINES.size()]
	CellOutzType.draw_condensed(self, band.position + Vector2(14, 28), line.to_upper(), 11.0, INK * Color(1, 1, 1, clampf(handler_life, 0.0, 1.0) * 0.9), 0.8)
	if transcript_life > 0.0:
		CellOutzType.draw_condensed(self, band.position + Vector2(14, 50), transcript, 10.0, MOSS * Color(1, 1, 1, clampf(transcript_life, 0.0, 1.0)), 0.8)
