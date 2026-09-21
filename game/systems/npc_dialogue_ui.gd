class_name NPCDialogueUI
extends Control

## The conversation screen, in the register Greg asked for: a Fallout 3 style
## terminal panel — speaker named to one side, a framed list of options along
## the bottom, thin bright rules on a dark plate.
##
## It is not a copy of that interface and could not be: this one has to hold a
## thing Fallout's never did, which is free speech. The spec is explicit that
## "scripted quest choices can coexist with free speech", so the canned lines
## and the open microphone share the same list, and holding V is simply the
## last option on it.
##
## The waveform across the top is the microphone, drawn live. It is here rather
## than in a corner because it answers the question a push-to-talk game always
## raises — *is it hearing me?* — in the place the player is already looking.

signal option_chosen(text: String)
signal speak_pressed(held: bool)
signal closed()

const PLATE := Color(0.03, 0.05, 0.035, 0.88)
const RULE := Color("5fe08a")
const TEXT := Color("7fffaf")
const DIM_TEXT := Color(0.35, 0.62, 0.45)
const SPEAK := Color("ffd166")

## Section 5's tones, as colour. The waveform is green while you are calm and
## climbs toward red as you get loud and hostile, so a player can see their own
## register — which is the half of "emotional notes in your voice" that a game
## can honestly show without pretending to do sentiment analysis on audio.
const TONE_COLOURS := {
	"neutral": Color("5fe08a"),
	"warm": Color("ffd166"),
	"clinical": Color("6fd6d0"),
	"amused": Color("c8e06a"),
	"cold": Color("6fa8d6"),
	"frightened": Color("9d8fe0"),
	"pleading": Color("d69fd6"),
	"hostile": Color("e0553a"),
}

var speaker := "UNKNOWN"
var options: Array[String] = []
var selected := 0
var listening := false
var npc_line := ""
var tone := "neutral"

## A ring of recent microphone amplitudes. Ring rather than an append-and-trim
## array because this is redrawn every frame and reallocating a 256-entry list
## sixty times a second is a cost with nothing to show for it.
var _wave: PackedFloat32Array = PackedFloat32Array()
var _wave_head := 0
var _loudness := 0.0
var _aggression := 0.0
var _clock := 0.0

const WAVE_POINTS := 220


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave.resize(WAVE_POINTS)
	set_process(true)


func open(who: String, choices: Array[String]) -> void:
	speaker = who.to_upper()
	options = choices.duplicate()
	selected = 0
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	listening = false
	closed.emit()


func say(line: String, line_tone: String) -> void:
	npc_line = line
	tone = line_tone
	queue_redraw()


## Fed from the microphone each frame. `level` is 0..1 amplitude.
func push_level(level: float) -> void:
	_wave[_wave_head] = clampf(level, 0.0, 1.0)
	_wave_head = (_wave_head + 1) % _wave.size()
	# Smoothed, because a raw peak meter flickers and reads as noise rather
	# than as a voice. Attack faster than release, so a shout registers
	# immediately and then falls away.
	var target := clampf(level, 0.0, 1.0)
	_loudness = lerpf(_loudness, target, 0.55 if target > _loudness else 0.12)


## How hot the waveform reads. Volume is most of it, but a hostile line keeps
## the colour up after the shouting stops, which is what makes the visual feel
## like it is tracking the conversation rather than the decibels.
func set_aggression(value: float) -> void:
	_aggression = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var view := size
	var font := ThemeDB.fallback_font

	# The speaker's name, up the right, the way the reference does it.
	var name_at := Vector2(view.x - 34.0, view.y * 0.22)
	_text(font, name_at - Vector2(font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, 0), speaker, 22, TEXT)

	if not npc_line.is_empty():
		var line_box := Rect2(Vector2(view.x * 0.16, view.y * 0.30), Vector2(view.x * 0.68, 78.0))
		draw_rect(line_box, PLATE)
		_frame(line_box, TONE_COLOURS.get(tone, RULE))
		_wrapped(font, line_box.grow(-14.0), npc_line, 17, TONE_COLOURS.get(tone, TEXT))

	# Height derived from the option count, not fixed. At a fixed 168px a sixth
	# option fell out of the bottom of the plate and the hint line was drawn on
	# top of it -- and the list is meant to grow as the conversation does.
	var row_height := 28.0
	var box_height := 26.0 + row_height * float(maxi(options.size(), 1)) + 14.0
	var box := Rect2(Vector2(view.x * 0.16, view.y - (box_height + 58.0)), Vector2(view.x * 0.68, box_height))
	draw_rect(box, PLATE)
	_frame(box, RULE)
	_wave_strip(Rect2(box.position + Vector2(10, -46), Vector2(box.size.x - 20, 38)))

	var y := box.position.y + 26.0
	for index in options.size():
		var option := str(options[index])
		var is_speak := option.begins_with("[V]")
		var tint := SPEAK if is_speak else (TEXT if index == selected else DIM_TEXT)
		if index == selected:
			# The reference boxes the highlighted line rather than colouring it.
			var highlight := Rect2(Vector2(box.position.x + 12, y - 17), Vector2(box.size.x - 24, 26))
			draw_rect(highlight, Color(RULE.r, RULE.g, RULE.b, 0.10))
			_frame(highlight, RULE)
		_text(font, Vector2(box.position.x + 24, y), option, 16, tint)
		y += row_height

	# Below the plate rather than inside it, so it can never collide with the
	# last option however many there are.
	_text(font, Vector2(box.position.x + 4, box.end.y + 20.0),
		"UP/DOWN SELECT   //   ENTER CHOOSE   //   HOLD V SPEAK   //   ESC LEAVE", 11, DIM_TEXT)


## The microphone, drawn. Silence is a flat line rather than an empty strip:
## a player who cannot tell "not listening" from "listening and hearing
## nothing" will assume the feature is broken, and be right to.
func _wave_strip(rect: Rect2) -> void:
	draw_rect(rect, Color(0.02, 0.04, 0.03, 0.8))
	var heat := clampf(maxf(_aggression, _loudness * 0.9), 0.0, 1.0)
	var calm := Color("5fe08a")
	var hot := Color("e0553a")
	var tint := calm.lerp(hot, heat)
	if not listening:
		tint = Color(0.22, 0.34, 0.27)
	var mid := rect.position.y + rect.size.y * 0.5
	var step := rect.size.x / float(_wave.size() - 1)
	var previous := Vector2(rect.position.x, mid)
	for index in _wave.size():
		# Read out of the ring oldest-first, so the trace scrolls rather than
		# jumping where the write head happens to be.
		var sample := _wave[(_wave_head + index) % _wave.size()]
		var amplitude := sample * rect.size.y * 0.45 if listening else 0.0
		# Signed so it reads as a wave around a centre line, not a bar chart.
		var wobble := sin(float(index) * 0.55 + _clock * 9.0) * amplitude
		var point := Vector2(rect.position.x + step * float(index), mid + wobble)
		draw_line(previous, point, tint, 1.6)
		previous = point
	if not listening:
		draw_line(Vector2(rect.position.x, mid), Vector2(rect.end.x, mid), tint, 1.0)
	_frame(rect, tint * Color(1, 1, 1, 0.55))


func move_selection(delta: int) -> void:
	if options.is_empty():
		return
	selected = wrapi(selected + delta, 0, options.size())
	queue_redraw()


func choose() -> void:
	if options.is_empty():
		return
	option_chosen.emit(str(options[selected]))


func _frame(rect: Rect2, tint: Color) -> void:
	draw_rect(rect, tint, false, 1.5)


func _text(font: Font, at: Vector2, body: String, font_size: int, tint: Color) -> void:
	draw_string(font, at + Vector2(1, 1), body, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
	draw_string(font, at, body, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _wrapped(font: Font, rect: Rect2, body: String, font_size: int, tint: Color) -> void:
	var words := body.split(" ", false)
	var line := ""
	var y := rect.position.y + float(font_size)
	for word in words:
		var candidate := line + (" " if not line.is_empty() else "") + str(word)
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
			_text(font, Vector2(rect.position.x, y), line, font_size, tint)
			y += float(font_size) + 5.0
			line = str(word)
		else:
			line = candidate
	if not line.is_empty():
		_text(font, Vector2(rect.position.x, y), line, font_size, tint)
