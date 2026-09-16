class_name RingmasterCard
extends Control

## AP1.6. The exchange after the colosseum. Same house register
## `warning_card.gd` already established — house type on real `Button` hit
## targets, not the engine's default UI font — because this is the second
## real choice card the project has, not a new one invented from scratch.

signal chosen(choice: String)

const CHOICES := [
	{"id": "join", "label": "WORK FOR HIM", "note": "The colosseum keeps running, and you keep it running with him. Whatever he wants next, he gets."},
	{"id": "escape", "label": "ATTEMPT TO LEAVE", "note": "Walk away from the floor while he is still talking. He may let you. He may not."},
	{"id": "fight", "label": "ATTEMPT TO KILL HIM", "note": "He is not a wrecker. He is not disabled by a car. This is not the fight the pit outside was."},
]

const VOID := Color("060b09")
const INK := Color("dce6ba")
const ACID := Color("b4da48")
const ARTERIAL := Color("c81f16")
const BILE := Color("b8a12a")

## Tall enough for the body text, three full-height rows starting at y=250
## with 64px spacing (last row bottom = 250 + 2*64 + 54 = 432), and the note
## line below with real clearance — the first version at 460 let a two-line
## note overlap the third row's own label, confirmed on a real capture.
const DESIGN := Vector2(820, 540)

var buttons: Array[Button] = []
var highlighted := 0
var clock := 0.0
var sheet: Control
var display_name := "THE RINGMASTER"
var _factor := 1.0
var _origin := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	sheet = Control.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	for index in CHOICES.size():
		var choice: Dictionary = CHOICES[index]
		var button := Button.new()
		button.name = str(choice.id)
		button.text = ""
		button.position = Vector2(50, 250 + index * 64)
		button.size = Vector2(720, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var accent := ARTERIAL if index == 2 else INK
		button.add_theme_color_override("font_color", accent * Color(1, 1, 1, 0.8))
		button.add_theme_color_override("font_hover_color", accent)
		button.add_theme_color_override("font_focus_color", accent)
		for state in ["normal", "hover", "pressed", "focus"]:
			var lit: bool = state in ["hover", "focus", "pressed"]
			var style := StyleBoxFlat.new()
			style.bg_color = accent * Color(1, 1, 1, 0.16) if lit else Color(0.05, 0.075, 0.06, 0.8)
			style.border_color = accent * Color(1, 1, 1, 0.9 if lit else 0.32)
			style.border_width_left = 5
			style.border_width_top = 1 if lit else 0
			style.border_width_bottom = 1 if lit else 0
			style.content_margin_left = 22
			button.add_theme_stylebox_override(state, style)
		button.mouse_entered.connect(_highlight.bind(index))
		button.focus_entered.connect(_highlight.bind(index))
		button.pressed.connect(_choose.bind(index))
		sheet.add_child(button)
		buttons.append(button)
	set_process(true)


func open_card(ringmaster_name: String) -> void:
	display_name = ringmaster_name.to_upper()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clock = 0.0
	buttons[0].grab_focus()
	_highlight(0)


func _highlight(index: int) -> void:
	highlighted = index
	queue_redraw()


func _choose(index: int) -> void:
	var choice := str(CHOICES[index].id)
	hide()
	chosen.emit(choice)


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			_choose(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		KEY_UP, KEY_W:
			buttons[(highlighted + CHOICES.size() - 1) % CHOICES.size()].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_DOWN, KEY_S:
			buttons[(highlighted + 1) % CHOICES.size()].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_choose(highlighted)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	_factor = clampf(minf(size.x / (DESIGN.x + 120.0), size.y / (DESIGN.y + 80.0)), 0.5, 1.4)
	_origin = (size - DESIGN * _factor) * 0.5
	sheet.scale = Vector2.ONE * _factor
	sheet.position = _origin
	queue_redraw()


func _wrap_condensed(text: String, cap: float, tracking: float, max_width: float) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in text.split(" "):
		var candidate := word if current.is_empty() else "%s %s" % [current, word]
		if CellOutzType.width_condensed(candidate, cap, tracking) > max_width and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	return lines


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), VOID * Color(1, 1, 1, 0.93))
	draw_set_transform(_origin, 0.0, Vector2(_factor, _factor))

	draw_rect(Rect2(0, 0, DESIGN.x, DESIGN.y), Color("0a120e"))
	draw_rect(Rect2(0, 0, DESIGN.x, DESIGN.y), ARTERIAL * Color(1, 1, 1, 0.55), false, 2.0)
	draw_rect(Rect2(3, 2, DESIGN.x, DESIGN.y), ARTERIAL * Color(1, 1, 1, 0.12), false, 2.0)
	for row in range(6, int(DESIGN.y), 3):
		draw_line(Vector2(4, row), Vector2(DESIGN.x - 4, row), Color(0, 0, 0, 0.17), 1.0)

	var beat := 0.5 + 0.5 * sin(clock * 1.4)
	CellOutzType.draw_stamped(self, Vector2(50, 40), display_name, 34.0, ACID * Color(1, 1, 1, 0.85 + beat * 0.15), ACID * Color(1, 1, 1, 0.2), 4.0)
	CellOutzType.draw_text(self, Vector2(50, 88), "RUNS THE COLOSSEUM FLOOR", 11.0, BILE, 1.4)
	draw_line(Vector2(50, 108), Vector2(DESIGN.x - 50, 108), ARTERIAL * Color(1, 1, 1, 0.4), 1.0)

	var body_lines := _wrap_condensed(
		"The pit is quiet now. Everyone who was going to be a car when this started is a car now, and everyone who was going to be a body is a body. He is neither. He is watching you, and he is not in a hurry.",
		11.0, 1.0, DESIGN.x - 100.0)
	var body_y := 140.0
	for line in body_lines:
		CellOutzType.draw_condensed(self, Vector2(50, body_y), line, 11.0, INK * Color(1, 1, 1, 0.82), 1.0)
		body_y += 20.0

	for index in buttons.size():
		var row := buttons[index]
		var choice: Dictionary = CHOICES[index]
		var accent := ARTERIAL if index == 2 else INK
		CellOutzType.draw_text(self, row.position + Vector2(20, 17), "%02d" % (index + 1), 14.0, INK * Color(1, 1, 1, 0.4), 1.6)
		CellOutzType.draw_text(self, row.position + Vector2(58, 14), str(choice.label), 18.0, accent * Color(1, 1, 1, 1.0 if index == highlighted else 0.78), 2.6)
		if index == highlighted:
			var slide := 5.0 + sin(clock * 6.0) * 2.0
			draw_colored_polygon(PackedVector2Array([
				row.position + Vector2(-14 - slide, 16),
				row.position + Vector2(-4 - slide, 27),
				row.position + Vector2(-14 - slide, 38),
			]), accent)

	var note_lines := _wrap_condensed(str(CHOICES[highlighted].note), 10.0, 1.0, DESIGN.x - 100.0)
	var note_y := DESIGN.y - 40.0 - float(note_lines.size() - 1) * 14.0
	for line in note_lines:
		CellOutzType.draw_condensed(self, Vector2(50, note_y), line, 10.0, BILE * Color(1, 1, 1, 0.78), 1.0)
		note_y += 14.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
