class_name PadKeyboard
extends Control

## An on-screen keyboard for the pad (Job 4: "Rename by an on-screen pad
## keyboard"). Stick or d-pad moves over big keys, Cross types the lit key,
## Circle deletes, Triangle types a space, Options (or the DONE key) submits.
## A real keyboard types straight in too, Enter submits, Escape cancels.

signal submitted(text: String)
signal cancelled

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("e6d4ac")
const BLOOD := Color("a8281a")
const COPPER := Color("b0552a")
const KEYS := ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ-'.0", "123456789 "]
## The bottom row: DEL, SPACE, DONE.
const ACTIONS := ["DEL", "SPACE", "DONE"]
const MAX_LENGTH := 20

var text := ""
var title := "NAME"
var cursor := Vector2i.ZERO
var _stick := Vector2i.ZERO


func _ready() -> void:
	name = "PadKeyboard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open(start_text: String, heading: String) -> void:
	text = start_text.left(MAX_LENGTH)
	title = heading
	cursor = Vector2i.ZERO
	queue_redraw()


## The lit key's label.
func lit() -> String:
	if cursor.y >= KEYS.size():
		return ACTIONS[clampi(cursor.x, 0, ACTIONS.size() - 1)]
	return str(KEYS[cursor.y])[cursor.x]


func press_lit() -> void:
	match lit():
		"DEL":
			text = text.left(maxi(0, text.length() - 1))
		"SPACE":
			type(" ")
		"DONE":
			submit()
		_:
			type(lit())
	queue_redraw()


func type(character: String) -> void:
	if text.length() < MAX_LENGTH:
		text += character.to_upper()
	queue_redraw()


func submit() -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		cancelled.emit()
	else:
		submitted.emit(clean)
	queue_free()


func move(step: Vector2i) -> void:
	var rows := KEYS.size() + 1
	cursor.y = wrapi(cursor.y + step.y, 0, rows)
	var width := ACTIONS.size() if cursor.y >= KEYS.size() else str(KEYS[cursor.y]).length()
	cursor.x = wrapi(cursor.x + step.x, 0, width) if step.x != 0 else clampi(cursor.x, 0, width - 1)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				press_lit()
			JOY_BUTTON_B:
				text = text.left(maxi(0, text.length() - 1))
			JOY_BUTTON_Y:
				type(" ")
			JOY_BUTTON_START:
				submit()
			JOY_BUTTON_DPAD_UP:
				move(Vector2i(0, -1))
			JOY_BUTTON_DPAD_DOWN:
				move(Vector2i(0, 1))
			JOY_BUTTON_DPAD_LEFT:
				move(Vector2i(-1, 0))
			JOY_BUTTON_DPAD_RIGHT:
				move(Vector2i(1, 0))
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var held := Vector2i(_stick)
		if motion.axis == JOY_AXIS_LEFT_X:
			held.x = 0 if absf(motion.axis_value) < 0.4 else (1 if motion.axis_value > 0.0 else -1)
			if held.x != 0 and _stick.x == 0:
				move(Vector2i(held.x, 0))
		elif motion.axis == JOY_AXIS_LEFT_Y:
			held.y = 0 if absf(motion.axis_value) < 0.4 else (1 if motion.axis_value > 0.0 else -1)
			if held.y != 0 and _stick.y == 0:
				move(Vector2i(0, held.y))
		_stick = held
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				submit()
			KEY_ESCAPE:
				cancelled.emit()
				queue_free()
			KEY_BACKSPACE:
				text = text.left(maxi(0, text.length() - 1))
			_:
				if key.unicode >= 32 and key.unicode < 127:
					type(char(key.unicode))
		queue_redraw()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.0, 0.0, 0.86))
	var unit := minf(view.x / 1280.0, view.y / 720.0)
	var head_h := 22.0 * unit
	CellOutzType.draw_text(self, Vector2(view.x * 0.5 - CellOutzType.width(title, head_h, 1.5) * 0.5, 120.0 * unit), title, head_h, COPPER, 1.5)
	var shown := text + ("_" if int(Time.get_ticks_msec() / 400) % 2 == 0 else " ")
	var text_h := 36.0 * unit
	CellOutzType.draw_text(self, Vector2(view.x * 0.5 - CellOutzType.width(shown, text_h, 2.0) * 0.5, 190.0 * unit), shown, text_h, BONE, 2.0)
	var key_size := Vector2(78.0, 66.0) * unit
	var gap := 8.0 * unit
	var top := 240.0 * unit
	for row in KEYS.size():
		var line := str(KEYS[row])
		var left := view.x * 0.5 - (key_size.x + gap) * line.length() * 0.5
		for column in line.length():
			var rect := Rect2(Vector2(left + column * (key_size.x + gap), top + row * (key_size.y + gap)), key_size)
			_key(rect, " " if line[column] == " " else line[column], cursor == Vector2i(column, row), unit)
	var action_size := Vector2(200.0, 66.0) * unit
	var action_left := view.x * 0.5 - (action_size.x + gap) * ACTIONS.size() * 0.5
	for index in ACTIONS.size():
		var rect := Rect2(Vector2(action_left + index * (action_size.x + gap), top + KEYS.size() * (key_size.y + gap) + 10.0 * unit), action_size)
		_key(rect, str(ACTIONS[index]), cursor == Vector2i(index, KEYS.size()), unit)


func _key(rect: Rect2, label: String, lit_now: bool, unit: float) -> void:
	draw_rect(rect, Color(BLOOD, 0.5 if lit_now else 0.12))
	draw_rect(rect, Color(BONE if lit_now else COPPER, 0.9 if lit_now else 0.45), false, 4.0 * unit if lit_now else 1.5)
	var h := 22.0 * unit
	CellOutzType.draw_text(self, rect.position + Vector2((rect.size.x - CellOutzType.width(label, h, 1.0)) * 0.5, (rect.size.y - h) * 0.5), label, h, BONE, 1.0)
