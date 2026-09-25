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
const VAT_BODY_PREVIEW := preload("res://systems/vat_body_preview.gd")
const Branding := preload("res://systems/celloutz_branding.gd")
const IntakePageMotion := preload("res://systems/intake_page_motion.gd")

signal filed(state: Dictionary)
## A beat in his lines the room answers ("watched": the cameras close in).
signal doctor_cue(kind: String)

const INK := Color("e6d4ac")
const COPPER := Color("b0552a")
## Height of the SUBJECT / TANK header band over the vat panel.
const NAME_BAND := 50.0
const HOT := Color("a8281a")
const MOSS := Color("8a9a4a")
const BRUISE := Color("6b3f6e")
# The form is literally seen through the same bloody culture medium as the
# 3D tank.  Keeping its UI wash green made the first frame look like a different
# scene from the vat beneath it.
const GOO := Color("70150e")
const PAPER := Color(0.12, 0.075, 0.06)

const ROUTES := ["PRESET", "RANDOM", "CHART", "INSTRUMENT"]
## Greg, 25 September: "then he asks what style of fighting you want to do".
const PAGES := ["ROUTE", "RACE", "TRAITS", "FACE", "BODY", "BIRTH", "SCHEDULE", "STYLE"]
const BIRTH_PAGE := 5
const STYLE_PAGE := 7
const FORM_REVEAL_AT := 5.5
const FORM_REVEAL_DURATION := 0.55

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
## Enforced silence after a line, so he is not speaking every second he is not
## already speaking.
var handler_quiet := 0.0
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
## Greg's opening lines, still to say, and whether he is still saying them.
var opening_lines: Array = []
var opening_active := false
var read_thoughts_said := false
var doctor_life := 0.0
var doctor_moment := 0
## AX2.2. Carried out of the examination and into the breakout.
var refusals := 0
## AX1.5. Which saved build a repeat player came back with, if any.
var preset_loaded := ""
## AX2.1. His closing beats, played before the form is actually filed.
var verdict: Array = []
## The closing sequence needs a state of its own: an empty queue means both
## "not started" and "finished" otherwise, which used to make a single F press
## replay the first beat forever instead of letting the doctor leave.
var verdict_started := false
## How many of his closing lines the player hurried past (speedrunners).
var lines_skipped := 0
## D8.3. A procedure in progress: the beats left to play, and the shot each one
## wants. Input is suspended while it runs, because it is being done to you.
var procedure: Array = []
var shot := "tank"
## What he has just written down, which is not always what you chose.
var transcript := ""
var transcript_life := 0.0
var mirror_settle := 0.0
var body_preview: Control
var intake_armed := false
var touched_pages: Dictionary = {}

# --- first-launch rework (Greg, 2026-09-24) ---------------------------------
# The vat fills the right side; the examiner is a live 3D feed top-left; the old
# text strip is a reply panel you answer from. His words type out and are held
# long enough to read, in a real font at a readable size, and the form takes
# the mouse as well as the keys.
const EXAMINER_FEED := preload("res://systems/examiner_feed.gd")
## Greg, 24 September: his line bigger, typed at reading pace with a cursor.
const PROSE_SIZE := 20
## Characters per second his line types out at, and reading speed for the hold
## after it: a 90-character line used to be gone in about four seconds.
const REVEAL_RATE := 22.0
const READ_RATE := 18.0
var examiner_feed: Control
var revealed := 0.0
var _shown_text := ""
## His earlier lines, newest last, kept above the current one and fading.
var said_history: Array[String] = []
const HISTORY_LINES := 2
## Tabs print in (Greg, 24 September): 0 as the page starts feeding out of the
## terminal's printer, 1 once it has all printed.
var page_print := 1.0
var _printed_page := -1
const PRINT_SECONDS := 0.85
## Where the page hangs from, in clipboard space: the drive gear on its left.
const PAGE_HINGE := Vector2(6, 118)
## The blood each page change runs down the paper, and how many changes.
var blood_runs: Array = []
var page_turns := 0
## The stats strip's gauges ease toward the sheet's real values, and a change
## flashes its size beside the number.
var _gauge_shown: Dictionary = {}
var _gauge_delta: Dictionary = {}
var _gauge_flash: Dictionary = {}
const GAUGE_MAX := 12.0
## Answers to the question he is asking right now, if he is asking one.
var answers: Array = []
## V: what you thought out loud, typed or heard by the tank's pickup.
var thought := ""
var thought_life := 0.0
var thought_edit: LineEdit
var voice: Node
var _board_xform := Transform2D()
var _board_width := 0.0
var _tab_hits: Array[Rect2] = []
var _row_hits: Array[Rect2] = []
var _answer_hits: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet = SHEET.new()
	var offset_rng := RandomNumberGenerator.new()
	offset_rng.randomize()
	line_offset = offset_rng.randi()
	body_preview = VAT_BODY_PREVIEW.new()
	body_preview.name = "LiveVatBodyPreview"
	add_child(body_preview)
	examiner_feed = EXAMINER_FEED.new()
	examiner_feed.name = "ExaminerFeed"
	add_child(examiner_feed)
	thought_edit = LineEdit.new()
	thought_edit.name = "ThinkOutLoud"
	thought_edit.placeholder_text = "think out loud, then Enter"
	thought_edit.visible = false
	thought_edit.text_submitted.connect(_think)
	add_child(thought_edit)
	resized.connect(_layout_body_preview)
	call_deferred("_layout_body_preview")
	call_deferred("_refresh_body_preview")
	# The player first sees the actual laboratory, examiner and terminal.  The
	# paperwork arrives a beat later instead of replacing the room on frame one.
	modulate.a = 0.0
	set_process(true)
	_speak()


## D3.4. He answers the moment rather than reading down a list. The hold comes
## with the line, so the pause after a mistranscription is not the pause after
## ticking a box.
## How long he stays quiet after finishing a line. Idle muttering gets the long
## gap; a reaction to something the player just did gets the short one, because
## a man answering you is not the same as a man filling silence.
const IDLE_GAP := Vector2(5.0, 9.0)
const REACTION_GAP := Vector2(1.6, 2.8)


func _speak(context: String = "idle") -> void:
	handler_line += 1
	# Every third idle beat he asks you something you can actually answer.
	if context == "idle" and handler_line % 3 == 0:
		context = "ask"
	var beat := IntakeDirection.line_for(context, handler_line + line_offset)
	handler_says = str(beat.line)
	answers = (beat.get("answers", []) as Array).duplicate()
	handler_life = maxf(float(beat.hold), _read_time(handler_says)) + (6.0 if not answers.is_empty() else 0.0)
	# He used to start the next line the instant the last one expired, which
	# meant he never stopped talking for the whole examination -- the pools just
	# cycled, forever, whether or not the player had done anything. Silence is
	# what makes him a man working near you rather than a man narrating at you,
	# and it is what gives the lines that *are* reactions room to land.
	var gap: Vector2 = IDLE_GAP if context == "idle" else REACTION_GAP
	handler_quiet = randf_range(gap.x, gap.y)


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
	handler_life = maxf(float(beat.get("hold", 2.6)), _read_time(handler_says))
	answers = []
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
	modulate.a = clampf((elapsed - FORM_REVEAL_AT) / FORM_REVEAL_DURATION, 0.0, 1.0)
	if not intake_armed and elapsed >= FORM_REVEAL_AT:
		intake_armed = true
		transcript = "NEURALACE ENGAGED  //  EXAMINER TERMINAL CONNECTED"
		transcript_life = 4.0
		_speak("page")
		var greeting: Array = DoctorExamination.OPENING.duplicate(true)
		greeting[greeting.size() - 1]["event"] = "examiner_greeting"
		_queue_lines(greeting)
	handler_life = maxf(0.0, handler_life - delta)
	handler_quiet = maxf(0.0, handler_quiet - delta)
	doctor_life = maxf(0.0, doctor_life - delta)
	if opening_active and doctor_life <= 0.0:
		if opening_lines.is_empty():
			opening_active = false
		else:
			_advance_opening()
	if doctor_life <= 0.0 and verdict_started:
		_advance_verdict()
	transcript_life = maxf(0.0, transcript_life - delta)
	if handler_life <= 0.0:
		# A procedure runs itself to the end before he goes back to muttering.
		if not procedure.is_empty():
			_advance_procedure()
		elif handler_quiet <= 0.0:
			_speak()
	mirror_settle = Motion.approach(mirror_settle, 1.0 if page == 3 else 0.0, delta, Motion.PANEL)
	var line := _current_line()
	if line != _shown_text:
		if not _shown_text.is_empty():
			said_history.append(_shown_text)
			while said_history.size() > HISTORY_LINES:
				said_history.pop_front()
		_shown_text = line
		revealed = 0.0
	if page != _printed_page:
		_printed_page = page
		page_print = 0.0
		page_turns += 1
		blood_runs.append(IntakePageMotion.new_run(page_turns, size.x * 0.375, 30.0, size.y - 220.0))
	IntakePageMotion.age_runs(blood_runs, delta)
	page_print = minf(1.0, page_print + delta / PRINT_SECONDS)
	_update_gauges(delta)
	revealed = minf(revealed + delta * REVEAL_RATE, float(line.length()))
	thought_life = maxf(0.0, thought_life - delta)
	if examiner_feed != null and is_instance_valid(examiner_feed):
		examiner_feed.call("say", line.left(int(revealed)), revealed < float(line.length()))
	if body_preview != null and is_instance_valid(body_preview):
		body_preview.call("set_face_focus", page == 3)
	queue_redraw()


## Long enough to read, whatever the authored hold was.
func _read_time(text: String) -> float:
	return 1.4 + float(text.length()) / REVEAL_RATE + float(text.length()) / READ_RATE


## What his mouth is saying right now: an observation displaces the patter.
func _current_line() -> String:
	if doctor_life > 0.0 and doctor_says != "":
		return doctor_says
	return handler_says


func _unhandled_input(event: InputEvent) -> void:
	# V is held, not pressed: the pickup listens while it is down.
	if event is InputEventKey and event.keycode == KEY_V and not event.echo and intake_armed:
		_think_key(event.pressed)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not intake_armed:
		get_viewport().set_input_as_handled()
		return
	# D8.3. While he is putting something into you, you are not filling in a
	# form. The scene runs to the end of its beats before it hands you back.
	if not procedure.is_empty():
		get_viewport().set_input_as_handled()
		return
	# Greg, 25 September: speedrunners. Once you've filed, F, Enter or Space
	# moves him to his next line instead of waiting it out. Every line still
	# plays; you just don't have to sit through it.
	if verdict_started and event.keycode in [KEY_F, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		doctor_life = 0.0
		lines_skipped += 1
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
		KEY_ENTER, KEY_KP_ENTER:
			_commit()
		KEY_1, KEY_2, KEY_3:
			_answer(event.keycode - KEY_1)
		KEY_F:
			# AX2.1. He does not let you leave without telling you what it was for.
			# The verdict plays first; filing happens when he has finished.
			if not verdict_started and _can_file():
				_begin_verdict()
			elif not verdict_started:
				transcript = "STILL TO CONFIRM: " + ", ".join(_unconfirmed())
				transcript_life = 4.5
		_:
			return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _unconfirmed() -> Array[String]:
	var missing: Array[String] = []
	for index in PAGES.size():
		if not touched_pages.has(index):
			missing.append(str(PAGES[index]))
	return missing


## Mouse: hover picks a row, a click confirms it, the tabs and his answers are
## buttons. The form is drawn tilted, so clicks are carried into its frame.
func _gui_input(event: InputEvent) -> void:
	if not intake_armed or not procedure.is_empty():
		return
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var at: Vector2 = event.position
	for index in _answer_hits.size():
		if _answer_hits[index].has_point(at) and click:
			_answer(index)
			accept_event()
			return
	var local := _board_xform.affine_inverse() * at
	for index in _tab_hits.size():
		if _tab_hits[index].has_point(local) and click and index != page:
			page = index
			row = 0
			_doctor_observe()
			_speak("page")
			accept_event()
			return
	for index in _row_hits.size():
		if _row_hits[index].has_point(local):
			row = index
			if click:
				_commit()
			accept_event()
			queue_redraw()
			return


func _answer(index: int) -> void:
	if index < 0 or index >= answers.size():
		return
	var choice := str(answers[index])
	answers = []
	if choice == "STARE":
		transcript = "WROTE: YES (UNRESPONSIVE)"
		transcript_life = 3.2
		_speak("stared")
	else:
		_transcribe(choice)


## V down/up. With the tank's pickup running (Vosk) it listens while held;
## without one it opens a line to type the thought into instead.
func _think_key(pressed: bool) -> void:
	if voice == null:
		voice = VoiceInput.new()
		voice.name = "TankPickup"
		add_child(voice)
		voice.utterance_final.connect(_think)
		voice.call("start")
	if voice != null and voice.call("available"):
		voice.call("set_listening", pressed)
		if pressed:
			thought = "..."
			thought_life = 2.0
		return
	if pressed and thought_edit != null:
		thought_edit.visible = true
		thought_edit.grab_focus()


func _think(text: String) -> void:
	if thought_edit != null:
		thought_edit.clear()
		thought_edit.visible = false
		thought_edit.release_focus()
	text = text.strip_edges()
	if text.is_empty():
		return
	thought = text
	thought_life = 6.0
	if thought_edit != null:
		thought_edit.placeholder_text = "think out loud, then Enter"
	var told := CharacterSheet.parse_birth(text)
	if not told.is_empty():
		_give_birth(told)
		return
	if not read_thoughts_said:
		# The first thought you have, he answers. Not the handler: him.
		read_thoughts_said = true
		doctor_says = str(DoctorExamination.READS_THOUGHTS.line)
		doctor_life = maxf(float(DoctorExamination.READS_THOUGHTS.hold), _read_time(doctor_says))
		WorldHistory.record_event("examiner_read_thought", {"thought": text.left(120)})
		return
	_speak("heard")


func _rows() -> int:
	match page:
		0:
			return ROUTES.size()
		1:
			return CharacterSheet.RACES.size()
		2:
			return CharacterSheet.TRAITS.size()
		3:
			# AX1.3. The face is seven named axes, its own page.
			return FaceModel.ORDER.size()
		4:
			# Anatomy sits at the top of the body page, because it is the first
			# thing the facility decided about you.
			return 9
		BIRTH_PAGE:
			return 1
		STYLE_PAGE:
			return BloodTrees.STYLE_ORDER.size()
		_:
			return CharacterSheet.MODIFIERS.size()


func _commit() -> void:
	touched_pages[page] = true
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
			# FACE used to draw seven explicit choices while this branch silently
			# changed body data.  The form now changes precisely the feature the
			# player selected, then derives the old scalar every legacy body reader
			# still understands.
			var axis: String = FaceModel.ORDER[row]
			sheet.face = FaceModel.cycle(sheet.face, axis)
			sheet.sync_face()
			_transcribe(FaceModel.reading(sheet.face, axis), "face")
		4:
			# Under the skin, because the kill cam will show it later. The
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
					sheet.appearance["build"] = fmod(float(sheet.appearance.get("build", 0.5)) + 0.17, 1.01)
				5:
					sheet.appearance["wear"] = fmod(float(sheet.appearance.get("wear", 0.4)) + 0.2, 1.01)
				6:
					sheet.appearance["mutation"] = fmod(float(sheet.appearance.get("mutation", 0.0)) + 0.2, 1.01)
				7:
					sheet.appearance["ink"] = fmod(float(sheet.appearance.get("ink", 0.0)) + 0.25, 1.01)
				_:
					sheet.appearance["piercings"] = fmod(float(sheet.appearance.get("piercings", 0.0)) + 0.25, 1.01)
			_transcribe("BODY")
		BIRTH_PAGE:
			# He asked for it; you tell him. Typed here, or said with V.
			if thought_edit != null:
				thought_edit.placeholder_text = "your birthday: day month year, and the time if you know it"
				thought_edit.visible = true
				thought_edit.grab_focus()
		STYLE_PAGE:
			sheet.fighting_style = str(BloodTrees.STYLE_ORDER[row])
			_transcribe(str((BloodTrees.STYLES[sheet.fighting_style] as Dictionary).label), "style_" + sheet.fighting_style)
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
	_refresh_body_preview()

func _can_file() -> bool:
	return touched_pages.size() == PAGES.size() and sheet.route != "" and sheet.race != ""


## This is a visual construction only.  The preview never applies the sheet to
## WorldHistory; the actual filing path remains the sole place that commits a
## person to the game.
func _refresh_body_preview() -> void:
	if body_preview != null and is_instance_valid(body_preview):
		body_preview.call("present_sheet", sheet)


func _layout_body_preview() -> void:
	if body_preview == null or not is_instance_valid(body_preview):
		return
	var mirror := _vat_rect()
	# The live tank starts under the SUBJECT header band (Greg, 24 September:
	# a band above the vat panel, not text drawn under the picture).
	body_preview.position = mirror.position + Vector2(8, 8 + NAME_BAND)
	body_preview.size = Vector2(maxf(1.0, mirror.size.x - 16.0), maxf(1.0, mirror.size.y - 56.0 - NAME_BAND))
	body_preview.visible = size.x >= 640.0 and size.y >= 400.0
	if examiner_feed != null and is_instance_valid(examiner_feed):
		var feed := _feed_rect()
		examiner_feed.position = feed.position + Vector2(6, 24)
		examiner_feed.size = Vector2(maxf(1.0, feed.size.x - 12.0), maxf(1.0, feed.size.y - 30.0))
		examiner_feed.visible = body_preview.visible
	if thought_edit != null:
		var reply := _reply_rect()
		thought_edit.position = reply.position + Vector2(10, reply.size.y - 44)
		thought_edit.size = Vector2(reply.size.x - 20, 34)


## The vat is the whole right side of the screen: the body you are choosing,
## full height, in an elongated tank.
func _vat_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.72, 24), Vector2(size.x * 0.28 - 24, size.y - 48))


## Where the recording notice used to hang alone: the examiner, live.
func _feed_rect() -> Rect2:
	return Rect2(Vector2(40, 56), Vector2(size.x * 0.27, size.y * 0.34))


## Under him: what he is saying, and what you can say back.
func _reply_rect() -> Rect2:
	var feed := _feed_rect()
	var top := feed.end.y + 14.0
	return Rect2(Vector2(40, top), Vector2(feed.size.x, size.y - top - 40.0))


func _cycle(options: Array, current: String) -> String:
	var index := options.find(current)
	return str(options[(index + 1) % options.size()])


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var viewport := size
	if viewport.x < 640 or viewport.y < 400:
		return
	_draw_tank(viewport)
	var board := Rect2(Vector2(viewport.x * 0.325, 54), Vector2(viewport.x * 0.375, viewport.y - 130))
	_draw_clipboard(board)
	_draw_mirror(_vat_rect())
	_draw_handler(viewport)
	_draw_doctor(viewport)


## You are looking out through it, so the whole screen is under water before
## anything else is drawn on top.
func _draw_tank(viewport: Vector2) -> void:
	# This is a red fluid veil, not an opaque painted replacement for the room.
	# The real vat, computer and examiner remain visible through it, so the first
	# impression is a 3D laboratory viewed from inside bloody culture medium.
	#
	# Held deliberately low: `vat_chamber.gd` renders the actual fluid column
	# again, so this is the film on the glass in front of the eye, not the
	# medium itself. At the old 0.34 the two stacked into an opaque brown wash.
	draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.30, 0.012, 0.007, 0.20))
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
		draw_circle(at, 1.5 + rng.randf() * 3.5, Color(0.95, 0.48, 0.36, 0.12))
	# The tube, in the corner of your own eye. It is always there.
	draw_line(Vector2(viewport.x * 0.5, viewport.y), Vector2(viewport.x * 0.46, viewport.y * 0.78), Color(0.5, 0.45, 0.38, 0.5), 9.0)
	draw_line(Vector2(viewport.x * 0.5, viewport.y), Vector2(viewport.x * 0.46, viewport.y * 0.78), Color(0.2, 0.18, 0.15, 0.6), 5.0)
	Grunge.grain(self, Rect2(Vector2.ZERO, viewport), 7717, 700)


func _draw_clipboard(rect: Rect2) -> void:
	# An invasive terminal, not a clean clipboard.
	_board_xform = Transform2D(-0.022, rect.position + Vector2(0, 12))
	_board_width = rect.size.x
	_tab_hits.clear()
	_row_hits.clear()
	draw_set_transform(rect.position + Vector2(0, 12), -0.022, Vector2.ONE)
	var board := Rect2(Vector2.ZERO, rect.size)
	draw_rect(board, Color(0.045, 0.022, 0.02, 0.96))
	draw_rect(board, Color(0.48, 0.13, 0.07, 0.8), false, 2.0)
	var sheet_rect := Rect2(Vector2(12, 34), rect.size - Vector2(24, 52))
	draw_rect(sheet_rect, PAPER)
	for rail in 5:
		var x := 18.0 + float(rail) * (rect.size.x - 36.0) / 4.0
		draw_line(Vector2(x, 38), Vector2(x + sin(elapsed + rail) * 5.0, rect.size.y - 20), Color(0.34, 0.07, 0.04, 0.38), 1.0)
	Grunge.stain(self, sheet_rect.position + sheet_rect.size * Vector2(0.8, 0.12), 60.0, 881, Grunge.BILE, 0.20)
	Grunge.stain(self, sheet_rect.position + sheet_rect.size * Vector2(0.15, 0.9), 44.0, 883, Grunge.RUST, 0.19)
	draw_rect(Rect2(Vector2(rect.size.x * 0.5 - 44, 6), Vector2(88, 22)), Color(0.32, 0.06, 0.03))
	draw_rect(Rect2(Vector2(rect.size.x * 0.5 - 44, 6), Vector2(88, 22)), HOT, false, 1.5)

	var ink := INK
	var y := 124.0
	# The page swings in on its arm while it prints, then hangs still.
	var clip_xform := Transform2D(-0.022, rect.position + Vector2(0, 12))
	if page_print < 1.0:
		draw_set_transform_matrix(clip_xform * IntakePageMotion.swing_transform(page_print, PAGE_HINGE))
	match page:
		0:
			_draw_routes(rect, ink, y)
		1:
			_draw_races(rect, ink, y)
		2:
			_draw_traits(rect, ink, y)
		3:
			_draw_face(rect, ink, y)
		4:
			_draw_body(rect, ink, y)
		BIRTH_PAGE:
			_draw_birth(rect, ink, y)
		STYLE_PAGE:
			_draw_styles(rect, ink, y)
		_:
			_draw_schedule(rect, ink, y)
	draw_set_transform_matrix(clip_xform)
	# The header goes on after the page, over a strip of paper, so a page
	# swinging in comes out from under it rather than across it.
	draw_rect(Rect2(Vector2(12, 34), Vector2(rect.size.x - 24, 74)), PAPER)
	_draw_form_header(rect, ink)
	IntakePageMotion.draw_runs(self, blood_runs)

	# The running total, at the foot of the form where a clerk would put it.
	var footer := rect.size.y - 74.0
	_draw_print_feed(rect, 110.0, footer - 16.0)
	IntakePageMotion.draw_arm(self, PAGE_HINGE, 64.0, IntakePageMotion.swing_angle(page_print))
	IntakePageMotion.draw_train(self, PAGE_HINGE, page_print, elapsed)
	draw_line(Vector2(26, footer - 12), Vector2(rect.size.x - 26, footer - 12), ink * Color(1, 1, 1, 0.3), 1.0)
	_draw_gauges(rect, ink, footer)
	CellOutzType.draw_condensed(self, Vector2(26, footer + 36), "%s // %s RISING // %s" % [sheet.sun_sign(), sheet.ascendant(), sheet.modality().to_upper()], 9.0, ink * Color(1, 1, 1, 0.55), 0.7)
	var done := touched_pages.size()
	var hint := ("CONFIRMED %d/%d  //  CLICK OR ENTER CONFIRMS THIS TAB" % [done, PAGES.size()]) if done < PAGES.size() else "ALL %d CONFIRMED  //  F FILES YOU" % PAGES.size()
	CellOutzType.draw_condensed(self, Vector2(rect.size.x - 26 - CellOutzType.width_condensed(hint, 9.0, 0.8), footer + 52), hint, 9.0, HOT if done < PAGES.size() else MOSS, 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_form_header(rect: Rect2, ink: Color) -> void:
	CellOutzType.draw_stamped(self, Vector2(26, 46), "NEURAL INTAKE", 20.0, ink, HOT * Color(1, 1, 1, 0.32), 1.6)
	CellOutzType.draw_condensed(self, Vector2(26, 72), Branding.copy_for("intake", "header"), 9.0, ink * Color(1, 1, 1, 0.6), 0.7)

	# Page tabs along the top of the paper.
	var tab_x := 26.0
	for index in PAGES.size():
		var label: String = PAGES[index]
		var width := CellOutzType.width_condensed(label, 10.0, 0.8) + 16.0
		var confirmed := touched_pages.has(index)
		width += 12.0 if confirmed else 0.0
		_tab_hits.append(Rect2(Vector2(tab_x - 5, 82), Vector2(width, 24)))
		if index == page:
			draw_rect(Rect2(Vector2(tab_x - 5, 86), Vector2(width, 18)), HOT * Color(1, 1, 1, 0.16))
			draw_line(Vector2(tab_x - 5, 104), Vector2(tab_x - 5 + width, 104), HOT, 1.6)
		CellOutzType.draw_condensed(self, Vector2(tab_x, 90), label, 10.0, ink * Color(1, 1, 1, 1.0 if index == page else 0.45), 0.8)
		if confirmed:
			var tick := Vector2(tab_x + width - 18, 91)
			draw_line(tick + Vector2(0, 4), tick + Vector2(3, 8), MOSS, 2.0)
			draw_line(tick + Vector2(3, 8), tick + Vector2(9, 0), MOSS, 2.0)
		tab_x += width + 6.0


func _update_gauges(delta: float) -> void:
	if sheet == null:
		return
	var values := sheet.attributes()
	for key in CharacterSheet.ATTRIBUTES:
		var actual := float(values[key])
		if not _gauge_shown.has(key):
			_gauge_shown[key] = actual
			continue
		var target_before: float = float(_gauge_delta.get(key + "_target", actual))
		if not is_equal_approx(target_before, actual):
			_gauge_delta[key] = actual - float(_gauge_shown[key])
			_gauge_flash[key] = 1.6
		_gauge_delta[key + "_target"] = actual
		_gauge_shown[key] = move_toward(float(_gauge_shown[key]), actual, delta * 4.0)
		_gauge_flash[key] = maxf(0.0, float(_gauge_flash.get(key, 0.0)) - delta)


## The page feeding out of the printer: everything below the print head is
## still blank paper, the head itself is a hot line, and the last lines it laid
## down are still wet.
func _draw_print_feed(rect: Rect2, top: float, bottom: float) -> void:
	if page_print >= 1.0:
		return
	var head := lerpf(top, bottom, ease(page_print, 0.7))
	draw_rect(Rect2(Vector2(14, head), Vector2(rect.size.x - 28, bottom - head)), PAPER)
	draw_rect(Rect2(Vector2(14, head - 22), Vector2(rect.size.x - 28, 22)), HOT * Color(1, 1, 1, 0.07 * (1.0 - page_print)))
	IntakePageMotion.draw_ink_bleed(self, rect.size.x, head, page_print, 5150 + page_turns)
	draw_line(Vector2(14, head), Vector2(rect.size.x - 14, head), HOT, 2.0)
	draw_line(Vector2(14, head + 3), Vector2(rect.size.x - 14, head + 3), Color(0.02, 0.01, 0.01, 0.8), 3.0)


func _draw_gauges(rect: Rect2, ink: Color, footer: float) -> void:
	var column := 26.0
	var span := rect.size.x * 0.19
	for key in CharacterSheet.ATTRIBUTES:
		var shown := float(_gauge_shown.get(key, sheet.attributes()[key]))
		CellOutzType.draw_condensed(self, Vector2(column, footer - 4), str(key).substr(0, 4).to_upper(), 9.0, ink * Color(1, 1, 1, 0.6), 0.7)
		CellOutzType.draw_condensed(self, Vector2(column + 40, footer - 8), "%04.1f" % shown, 16.0, ink, 0.9)
		var bar := Rect2(Vector2(column, footer + 16), Vector2(span, 7))
		draw_rect(bar, ink * Color(1, 1, 1, 0.12))
		draw_rect(Rect2(bar.position, Vector2(span * clampf(shown / GAUGE_MAX, 0.0, 1.0), bar.size.y)), COPPER.lerp(HOT, 0.3))
		for notch in 4:
			var x := bar.position.x + span * float(notch + 1) / 4.0
			draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), PAPER, 1.0)
		var flash := float(_gauge_flash.get(key, 0.0))
		var change := float(_gauge_delta.get(key, 0.0))
		if flash > 0.0 and absf(change) >= 0.05:
			var tag := "%+.1f" % change
			# Above the number, not beside it: beside it the tag ran into the
			# value it was describing (first capture read "04.5.0").
			CellOutzType.draw_condensed(self, Vector2(column + span - CellOutzType.width_condensed(tag, 11.0, 0.8), footer - 22), tag, 11.0, (MOSS if change > 0.0 else HOT) * Color(1, 1, 1, clampf(flash, 0.0, 1.0)), 0.8)
		column += rect.size.x * 0.22


func _row_mark(ink: Color, at: Vector2, active: bool, ticked: bool) -> void:
	# Every row passes through here, so it is where the row becomes clickable.
	_row_hits.append(Rect2(Vector2(20, at.y - 6), Vector2(_board_width - 40, 23)))
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


## What he knows once you have told him: the date, the wheel it gives, and the
## element each stat drinks from, as bars.
func _draw_birth(_rect: Rect2, ink: Color, y: float) -> void:
	var told := touched_pages.has(BIRTH_PAGE)
	_row_mark(ink, Vector2(30, y - 9), row == 0, told)
	CellOutzType.draw_condensed(self, Vector2(50, y - 10), "TELL HIM" if not told else "TOLD HIM", 13.0, ink, 0.9)
	CellOutzType.draw_condensed(self, Vector2(50, y + 6), "ENTER TO TYPE IT  //  HOLD V TO SAY IT", 7.0, ink * Color(1, 1, 1, 0.5), 0.6)
	y += 42.0
	var birth: Dictionary = sheet.birth
	var date := "%02d %s %d" % [int(birth.get("day", 1)), str(CharacterSheet.MONTH_NAMES[clampi(int(birth.get("month", 1)), 1, 12) - 1]).left(3), int(birth.get("year", 2000))]
	var time := ("%02d:%02d" % [int(birth.get("hour", 12)), int(birth.get("minute", 0))]) if bool(birth.get("time_known", true)) else "--:--"
	var dim := ink * Color(1, 1, 1, 1.0 if told else 0.35)
	CellOutzType.draw_condensed(self, Vector2(50, y), date if told else "?? ??? ????", 20.0, dim, 0.8)
	CellOutzType.draw_condensed(self, Vector2(260, y + 4), time if told else "--:--", 14.0, dim, 0.8)
	y += 34.0
	CellOutzType.draw_condensed(self, Vector2(50, y), "SUN %s  //  %s RISING  //  %s" % [sheet.sun_sign(), sheet.ascendant(), sheet.modality().to_upper()], 10.0, (HOT if told else dim), 0.7)
	y += 26.0
	var balance := sheet.element_balance()
	var total := 0.0
	for element in balance:
		total += float(balance[element])
	for element in ["fire", "earth", "air", "water"]:
		var share := float(balance[element]) / maxf(total, 0.001)
		CellOutzType.draw_condensed(self, Vector2(50, y), "%s  >  %s" % [element.to_upper(), str(CharacterSheet.ELEMENT_ATTRIBUTE[element]).to_upper()], 9.0, dim, 0.7)
		draw_rect(Rect2(Vector2(220, y + 1), Vector2(180, 9)), ink * Color(1, 1, 1, 0.12))
		draw_rect(Rect2(Vector2(220, y + 1), Vector2(180 * share, 9)), (HOT if told else ink) * Color(1, 1, 1, 0.8 if told else 0.25))
		y += 18.0


## The four blood trees, with the first node each one opens and what you
## would walk into the Hunt holding.
func _draw_styles(_rect: Rect2, ink: Color, y: float) -> void:
	for index in BloodTrees.STYLE_ORDER.size():
		var style_id: String = BloodTrees.STYLE_ORDER[index]
		var style: Dictionary = BloodTrees.STYLES[style_id]
		var tone: Color = style.tone
		_row_mark(ink, Vector2(30, y - 9), index == row, sheet.fighting_style == style_id)
		draw_rect(Rect2(Vector2(50, y - 12), Vector2(6, 26)), tone)
		CellOutzType.draw_condensed(self, Vector2(64, y - 10), str(style.label), 13.0, ink, 0.9)
		var first := BloodTrees.first_node(style_id)
		var node: Dictionary = BloodTrees.NODES.get(first, {})
		CellOutzType.draw_condensed(self, Vector2(64, y + 6), ("OPENS %s  //  %s" % [str(node.get("label", "")), str(node.get("effect", ""))]).left(58), 7.0, ink * Color(1, 1, 1, 0.5), 0.6)
		CellOutzType.draw_condensed(self, Vector2(330, y - 8), "HOLDING  %s" % BloodTrees.weapon_label(BloodTrees.starting_weapon(style_id)), 8.0, tone * Color(1, 1, 1, 0.9), 0.7)
		y += 36.0


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


## AX1.3. Seven axes, each read back in the facility's own words rather than
## as a number -- a number would imply somebody measured carefully.
func _draw_face(_rect: Rect2, ink: Color, y: float) -> void:
	for index in FaceModel.ORDER.size():
		var axis: String = FaceModel.ORDER[index]
		var spec: Dictionary = FaceModel.AXES[axis]
		_row_mark(ink, Vector2(30, y - 9), index == row, false)
		CellOutzType.draw_condensed(self, Vector2(50, y - 10), str(spec.label), 11.0, ink * Color(1, 1, 1, 0.6), 0.8)
		CellOutzType.draw_condensed(self, Vector2(190, y - 10), FaceModel.reading(sheet.face, axis), 12.0, ink, 0.9)
		# The axis drawn as a mark on a strip, because the form has no numbers
		# on it anywhere else either.
		var strip := Rect2(Vector2(340, y - 14), Vector2(120, 4))
		draw_rect(strip, ink * Color(1, 1, 1, 0.18))
		draw_rect(Rect2(strip.position + Vector2(clampf(float(sheet.face.get(axis, 0.5)), 0.0, 1.0) * (strip.size.x - 6), -2), Vector2(6, 8)), HOT)
		y += 28.0
	CellOutzType.draw_condensed(self, Vector2(30, y + 10), "THEY WILL WRITE DOWN WHAT THEY THINK THEY SAW.", 8.0, ink * Color(1, 1, 1, 0.42), 0.7)


func _draw_body(_rect: Rect2, ink: Color, y: float) -> void:
	var rows := [
		["ANATOMY", str((CharacterSheet.ANATOMY_SEX[sheet.anatomy_sex] as Dictionary).name)],
		["BLOOD", str(sheet.under_skin.get("blood", "O-RUST"))],
		["SKELETON", str(sheet.under_skin.get("skeleton", "standard")).to_upper()],
		["ORGAN SET", str(sheet.under_skin.get("organs", "standard")).to_upper()],
		["BUILD", "%.0f%% // COMPACT / HEAVY" % (float(sheet.appearance.get("build", 0.5)) * 100.0)],
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
	CellOutzType.draw_condensed(self, Vector2(30, y + 10), Branding.copy_for("intake", "body_notice"), 8.0, ink * Color(1, 1, 1, 0.42), 0.7)


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


## D7. A mirror on a swing arm. Its reflection is a real 3D `BaselineHuman`
## preview drawn by VatBodyPreview, rather than a silhouette pretending to be
## the body the player will later inhabit.
func _draw_mirror(rect: Rect2) -> void:
	var arm_from := Vector2(rect.position.x - 40, rect.position.y - 30)
	draw_line(arm_from, rect.position + Vector2(10, 10), Color(0.30, 0.26, 0.20), 6.0)
	draw_circle(arm_from, 5.0, Color(0.38, 0.33, 0.25))
	draw_rect(rect.grow(6), Color(0.22, 0.19, 0.15))
	draw_rect(rect, Color(0.10, 0.12, 0.09))
	draw_rect(rect.grow(6), Color(0.36, 0.30, 0.22), false, 2.0)

	# "PREVIEW IS THROUGH GLASS" used to be the only glass in this panel: the
	# body stood on flat black and the caption asserted the tank. VatBodyPreview
	# builds the tank now, so the label can say what the picture is instead of
	# standing in for it.
	# Greg on first launch: "the name / tank line readable"; then (24 September)
	# bigger and more prominent: a header over the vat panel, not a caption.
	var subject_name := str(sheet.display_name).to_upper() if sheet != null else "UNNAMED"
	var header := Rect2(rect.position, Vector2(rect.size.x, NAME_BAND))
	draw_rect(header, Color(0.02, 0.018, 0.015, 0.88))
	draw_line(header.position + Vector2(0, header.size.y), header.end, COPPER * Color(1, 1, 1, 0.7), 1.0)
	CellOutzType.draw_condensed(self, header.position + Vector2(12, 7), "SUBJECT  %s" % subject_name, 21.0, INK, 0.7)
	CellOutzType.draw_condensed(self, header.position + Vector2(12, 32), "TANK 0C-7  //  LIVE", 12.0, COPPER, 0.7)
	CellOutzType.draw_condensed(self, rect.position + Vector2(10, rect.size.y - 16), "THE BODY IS NOT A DRAWING", 9.0, INK * Color(1, 1, 1, 0.45), 0.7)


## AX1.2. He watches the page you are on, not the box you ticked. Arriving at
## a page is the beat; choosing within it belongs to the handler and his form.
func _doctor_observe() -> void:
	# He finishes what he came in to say before he comments on your paperwork.
	if opening_active:
		return
	doctor_moment += 1
	var beat := DoctorExamination.observe(str(PAGES[page]).to_lower(), doctor_moment)
	if beat.is_empty():
		return
	doctor_says = str(beat.get("line", ""))
	doctor_life = maxf(float(beat.get("hold", 3.0)), _read_time(doctor_says))


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
	doctor_life = maxf(float(beat.get("hold", 3.2)), _read_time(doctor_says))


## AX2.1. The closing sequence. He explains what the examination was for,
## which is worse than gloating, and then he starts to leave.
func _advance_opening() -> void:
	if opening_lines.is_empty():
		return
	var beat: Dictionary = opening_lines.pop_front()
	doctor_says = str(beat.get("line", ""))
	doctor_life = maxf(float(beat.get("hold", 3.0)), _read_time(doctor_says))
	var cue := str(beat.get("cue", ""))
	if cue != "":
		doctor_cue.emit(cue)
	var event := str(beat.get("event", ""))
	if event != "":
		WorldHistory.record_event(event, {"line": doctor_says})


## Lines he says through, in order, without the patter cutting in.
func _queue_lines(lines: Array) -> void:
	opening_lines.append_array(lines.duplicate(true))
	opening_active = true
	if doctor_life <= 0.0:
		_advance_opening()


## Beat 5. Your birthday goes on the sheet (and so into the stats, which read
## the chart), and he reads it back to you.
func _give_birth(told: Dictionary) -> void:
	sheet.birth = told
	touched_pages[BIRTH_PAGE] = true
	transcript = "WROTE: %02d %s %d  %s" % [int(told.day), str(CharacterSheet.MONTH_NAMES[int(told.month) - 1]).left(3), int(told.year), ("%02d:%02d" % [int(told.hour), int(told.minute)]) if bool(told.time_known) else "TIME UNKNOWN"]
	transcript_life = 4.0
	WorldHistory.record_event("birthday_given", {"birth": told.duplicate(), "sun": sheet.sun_sign(), "rising": sheet.ascendant()})
	var lines: Array = []
	if not read_thoughts_said:
		read_thoughts_said = true
		lines.append(DoctorExamination.READS_THOUGHTS.duplicate())
	lines.append_array(DoctorExamination.read_chart(sheet))
	_queue_lines(lines)
	_refresh_body_preview()


func _begin_verdict() -> void:
	verdict_started = true
	opening_lines.clear()
	opening_active = false
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
	doctor_life = maxf(float(beat.get("hold", 3.2)), _read_time(doctor_says))


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
	# Greg, 24 September: "don't forget the save character preset so you can
	# reload it if you die without wasting time". CharacterPresets.save() had
	# no caller, so PRESET answered NO PRESET ON FILE for everyone. Every filed
	# examination now writes its sheet under the name on it; a regrown body
	# never sees this form, and a new run can take the PRESET route.
	CharacterPresets.save(sheet.display_name, sheet)
	print("EXAMINATION FILED // %d:%02d // %s // %d refusals" % [int(elapsed) / 60, int(elapsed) % 60, ("PRESET " + preset_loaded) if preset_loaded != "" else "DELIBERATE", refusals])
	filed.emit(state)


func _draw_doctor(viewport: Vector2) -> void:
	# Greg, 20 September: "instead of two figures on the left only the 1 doctor
	# / handler whos name is unkown". There were two silhouettes -- a bored
	# clerk and a visiting physician -- and they are now one man. The clerk's
	# form patter and the doctor's observations come out of the same mouth,
	# which is worse for the player and simpler on screen.
	#
	# Only the recording notice is drawn here now, and it is the room's rather
	# than his: he has never once looked at it.
	CellOutzType.draw_condensed(
		self, Vector2(40, 34), DoctorExamination.CONSENT_NOTICE, 11.0,
		HOT.lightened(0.25) * Color(1, 1, 1, 0.72 + 0.28 * sin(elapsed * 2.0)), 0.8,
	)

func _draw_handler(_viewport: Vector2) -> void:
	# The live feed's frame; the man inside it is ExaminerFeed, a real 3D body.
	var feed := _feed_rect()
	draw_rect(feed, Color(0.018, 0.018, 0.015, 0.92))
	draw_rect(feed, COPPER * Color(1, 1, 1, 0.56), false, 1.0)
	CellOutzType.draw_condensed(self, feed.position + Vector2(10, 8), "EXAMINER // LIVE OBSERVATION  //  NAME WITHHELD", 9.0, COPPER, 0.7)
	if fmod(elapsed, 1.6) < 0.8:
		draw_circle(feed.position + Vector2(feed.size.x - 16, 13), 4.0, HOT)

	# The reply panel: what he is saying, then what you can do about it.
	var reply := _reply_rect()
	draw_rect(reply, Color(0.05, 0.028, 0.022, 0.9))
	draw_rect(reply, COPPER * Color(1, 1, 1, 0.4), false, 1.0)
	var font := ThemeDB.fallback_font
	var speaking_as_doctor := doctor_life > 0.0 and doctor_says != ""
	var line := _current_line()
	var shown := line.left(int(revealed))
	var voice_ink: Color = Color("cfd9d2") if speaking_as_doctor else INK
	var fade := clampf((doctor_life if speaking_as_doctor else handler_life) * 1.5, 0.0, 1.0)
	var text_width := reply.size.x - 24.0
	var y := reply.position.y + 14.0
	CellOutzType.draw_condensed(self, Vector2(reply.position.x + 12, y), "HE SAYS", 9.0, COPPER, 0.7)
	y += 16.0
	# What he already said, above, fading the older it is.
	for index in said_history.size():
		var age := said_history.size() - index
		var old := said_history[index]
		draw_string(font, Vector2(reply.position.x + 12, y + 12), old.left(64) + ("..." if old.length() > 64 else ""), HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, voice_ink * Color(1, 1, 1, 0.42 / float(age)))
		y += 17.0
	if not said_history.is_empty():
		y += 4.0
	# A cursor rides the end of the line while he is still typing it.
	var typing := revealed < float(line.length())
	var cursor := "_" if typing and fmod(elapsed, 0.5) < 0.3 else ""
	draw_multiline_string(font, Vector2(reply.position.x + 12, y + PROSE_SIZE), shown + cursor, HORIZONTAL_ALIGNMENT_LEFT, text_width, PROSE_SIZE, 4, voice_ink * Color(1, 1, 1, fade))
	y += PROSE_SIZE * 1.3 * 4.0 + 8.0
	if transcript_life > 0.0:
		draw_string(font, Vector2(reply.position.x + 12, y), transcript, HORIZONTAL_ALIGNMENT_LEFT, text_width, 13, MOSS * Color(1, 1, 1, clampf(transcript_life, 0.0, 1.0)))
		y += 22.0

	# Answers, when he has asked something a body in a tank can answer.
	_answer_hits.clear()
	var mouse := get_local_mouse_position()
	for index in answers.size():
		var button := Rect2(Vector2(reply.position.x + 12, y), Vector2(text_width, 28))
		_answer_hits.append(button)
		var hot := button.has_point(mouse)
		draw_rect(button, HOT * Color(1, 1, 1, 0.28 if hot else 0.12))
		draw_rect(button, HOT * Color(1, 1, 1, 0.7), false, 1.0)
		# Each answer is something an eye does (Greg, 24 September).
		var icon_end := _draw_blink_icon(button.position + Vector2(12, 14), str(answers[index]), hot)
		draw_string(font, Vector2(icon_end + 10, button.position.y + 19), "%d   %s" % [index + 1, str(answers[index])], HORIZONTAL_ALIGNMENT_LEFT, text_width - (icon_end - button.position.x) - 20, 15, INK)
		y += 34.0

	if thought_life > 0.0 and thought != "":
		CellOutzType.draw_condensed(self, Vector2(reply.position.x + 12, y + 6), "YOU THINK", 8.0, BRUISE.lightened(0.4), 0.7)
		draw_multiline_string(font, Vector2(reply.position.x + 12, y + 22 + 15), thought, HORIZONTAL_ALIGNMENT_LEFT, text_width, 15, 3, BRUISE.lightened(0.55) * Color(1, 1, 1, clampf(thought_life, 0.0, 1.0)))

	var keys := "[V] THINK OUT LOUD" + ("   //   [1-%d] ANSWER" % answers.size() if not answers.is_empty() else "") + "   //   TUBE IN: YOU CANNOT SPEAK"
	if thought_edit == null or not thought_edit.visible:
		CellOutzType.draw_condensed(self, Vector2(reply.position.x + 12, reply.end.y - 18), keys, 8.0, INK * Color(1, 1, 1, 0.55), 0.7)


## One eye per blink the answer asks for, drawn shut; an open eye for
## anything else (a stare). Returns the x the label should start at.
func _draw_blink_icon(at: Vector2, answer: String, hot: bool) -> float:
	var upper := answer.to_upper()
	var blinks := 2 if upper.contains("TWICE") else (1 if upper.contains("ONCE") or upper.contains("BLINK") else 0)
	var ink := INK if hot else INK * Color(1, 1, 1, 0.75)
	var x := at.x
	for eye in maxi(1, blinks):
		var centre := Vector2(x + 9, at.y)
		if blinks == 0:
			# Open: lids, and the pupil.
			draw_arc(centre + Vector2(0, 5), 9.0, PI * 1.15, PI * 1.85, 10, ink, 1.4)
			draw_arc(centre + Vector2(0, -5), 9.0, PI * 0.15, PI * 0.85, 10, ink, 1.4)
			draw_circle(centre, 2.6, HOT if hot else ink)
		else:
			# Shut: the lid line and three lashes.
			draw_arc(centre + Vector2(0, -6), 9.0, PI * 0.15, PI * 0.85, 10, ink, 1.6)
			for lash in 3:
				var lx := centre.x - 5.0 + float(lash) * 5.0
				draw_line(Vector2(lx, centre.y + 2.5), Vector2(lx + (float(lash) - 1.0) * 1.5, centre.y + 6.0), ink, 1.2)
		x += 22.0
	return x


func _fit_handler_line(text: String, width: float) -> String:
	var clipped := text
	while clipped.length() > 1 and CellOutzType.width_condensed(clipped + ".", 8.0, 0.58) > width:
		clipped = clipped.left(-1)
	return clipped.strip_edges() + ("." if clipped.length() < text.length() else "")
