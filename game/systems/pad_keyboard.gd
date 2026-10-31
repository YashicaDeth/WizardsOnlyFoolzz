class_name PadKeyboard
extends Control

## An on-screen keyboard for the pad (Job 4: "Rename by an on-screen pad
## keyboard"). Stick or d-pad moves over big keys, Cross types the lit key,
## Circle deletes (or closes it when empty), Triangle types a space, Options
## (or the DONE key) submits. A real keyboard types straight in too, Enter
## submits, Escape cancels.
##
## intake-29: an optional row of PRESETS sits above the keys. Cross on one
## submits it as written, so a pad player without a mic (or without the
## patience to spell) is never stuck on a typing prompt.

signal submitted(text: String)
signal cancelled

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("e6d4ac")
const BLOOD := Color("a8281a")
const COPPER := Color("b0552a")
const KEYS := ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ-'.0", "123456789:"]
## The bottom row: DEL, SPACE, DONE.
const ACTIONS := ["DEL", "SPACE", "DONE"]
const MAX_LENGTH := 20

var text := ""
var title := "NAME"
var max_length := MAX_LENGTH
## Whole answers offered above the keys; Cross on one submits it.
var presets: Array = []
var cursor := Vector2i.ZERO
var _stick := Vector2i.ZERO


func _ready() -> void:
	name = "PadKeyboard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open(start_text: String, heading: String, preset_list: Array = [], length := MAX_LENGTH) -> void:
	max_length = length
	text = start_text.left(max_length)
	title = heading
	presets = preset_list.duplicate()
	cursor = Vector2i.ZERO
	queue_redraw()


## Every row, top to bottom: the presets (if any), the letters, the actions.
func rows() -> Array:
	var list: Array = []
	if not presets.is_empty():
		list.append(presets)
	for line: String in KEYS:
		var keys: Array = []
		for character in line:
			keys.append(character)
		list.append(keys)
	list.append(ACTIONS)
	return list


func _on_presets() -> bool:
	return not presets.is_empty() and cursor.y == 0


## The lit key's label.
func lit() -> String:
	var row: Array = rows()[clampi(cursor.y, 0, rows().size() - 1)]
	return str(row[clampi(cursor.x, 0, row.size() - 1)])


func press_lit() -> void:
	if _on_presets():
		text = lit()
		submit()
		return
	if cursor.y == rows().size() - 1:
		match lit():
			"DEL":
				delete()
			"SPACE":
				type(" ")
			"DONE":
				submit()
		return
	type(lit())


func type(character: String) -> void:
	if text.length() < max_length:
		text += character.to_upper()
	queue_redraw()


func delete() -> void:
	text = text.left(maxi(0, text.length() - 1))
	queue_redraw()


func submit() -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		cancelled.emit()
	else:
		submitted.emit(clean)
	queue_free()


func cancel() -> void:
	cancelled.emit()
	queue_free()


func move(step: Vector2i) -> void:
	var list := rows()
	cursor.y = wrapi(cursor.y + step.y, 0, list.size())
	var width: int = (list[cursor.y] as Array).size()
	cursor.x = wrapi(cursor.x + step.x, 0, width) if step.x != 0 else clampi(cursor.x, 0, width - 1)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		if pad.pressed:
			match pad.button_index:
				JOY_BUTTON_A:
					press_lit()
				JOY_BUTTON_B:
					if text.is_empty():
						cancel()
					else:
						delete()
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
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_ENTER, KEY_KP_ENTER:
					submit()
				KEY_ESCAPE:
					cancel()
				KEY_BACKSPACE:
					delete()
				_:
					if key.unicode >= 32 and key.unicode < 127:
						type(char(key.unicode))
			queue_redraw()
		get_viewport().set_input_as_handled()


## Button names as the player's device shows them (InputProfile), without
## the "PS4 " family prefix: CROSS, L1, OPTIONS.
static func pad_name(host: Node, button: JoyButton) -> String:
	var profile := host.get_node_or_null("/root/InputProfile")
	if profile == null:
		return ""
	var named := str(profile.call("_joy_button_name", button, str(profile.call("device_family"))))
	for prefix in ["PS5 ", "PS4 ", "PAD "]:
		named = named.trim_prefix(prefix)
	return named


static func on_pad(host: Node) -> bool:
	var profile := host.get_node_or_null("/root/InputProfile")
	return profile != null and bool(profile.get("using_pad"))


func _button(button: JoyButton, keyboard: String) -> String:
	return pad_name(self, button) if on_pad(self) else keyboard


func _draw() -> void:
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.01, 0.0, 0.0, 0.86))
	var unit := minf(view.x / 1280.0, view.y / 720.0)
	var head_h := 22.0 * unit
	var top := 70.0 * unit
	CellOutzType.draw_text(self, Vector2(view.x * 0.5 - CellOutzType.width(title, head_h, 1.5) * 0.5, top), title, head_h, COPPER, 1.5)
	var shown := text + ("_" if int(Time.get_ticks_msec() / 400) % 2 == 0 else " ")
	var text_h := 36.0 * unit
	CellOutzType.draw_text(self, Vector2(view.x * 0.5 - CellOutzType.width(shown, text_h, 2.0) * 0.5, top + 50.0 * unit), shown, text_h, BONE, 2.0)
	var gap := 8.0 * unit
	var y := top + 110.0 * unit
	var list := rows()
	for row_index in list.size():
		var row: Array = list[row_index]
		var is_letters := row != ACTIONS and not (row_index == 0 and not presets.is_empty())
		var key_size := Vector2(78.0, 60.0) * unit
		if not is_letters:
			var longest := 0.0
			for label in row:
				longest = maxf(longest, CellOutzType.width(str(label), 20.0 * unit, 1.0))
			key_size = Vector2(maxf(200.0 * unit, longest + 36.0 * unit), 60.0 * unit)
			# Presets wrap the screen width rather than spill off it.
			key_size.x = minf(key_size.x, (view.x - 80.0 * unit) / float(row.size()) - gap)
		var left := view.x * 0.5 - (key_size.x + gap) * row.size() * 0.5
		for column in row.size():
			var rect := Rect2(Vector2(left + column * (key_size.x + gap), y), key_size)
			_key(rect, str(row[column]), cursor == Vector2i(column, row_index), unit)
		y += key_size.y + gap + (12.0 * unit if row_index == 0 and not presets.is_empty() else 0.0)
	var strip := "%s TYPE  //  %s DELETE  //  %s SPACE  //  %s DONE" % [_button(JOY_BUTTON_A, "TYPE"), _button(JOY_BUTTON_B, "BACKSPACE"), _button(JOY_BUTTON_Y, "SPACE"), _button(JOY_BUTTON_START, "ENTER")]
	if not on_pad(self):
		strip = "TYPE  //  BACKSPACE DELETE  //  ENTER DONE  //  ESC CLOSE"
	var strip_h := 18.0 * unit
	CellOutzType.draw_text(self, Vector2(view.x * 0.5 - CellOutzType.width(strip, strip_h, 1.0) * 0.5, y + 24.0 * unit), strip, strip_h, COPPER, 1.0)


func _key(rect: Rect2, label: String, lit_now: bool, unit: float) -> void:
	draw_rect(rect, Color(BLOOD, 0.5 if lit_now else 0.12))
	draw_rect(rect, Color(BONE if lit_now else COPPER, 0.9 if lit_now else 0.45), false, 4.0 * unit if lit_now else 1.5)
	var h := 22.0 * unit
	while h > 10.0 * unit and CellOutzType.width(label, h, 1.0) > rect.size.x - 12.0 * unit:
		h -= 1.0
	CellOutzType.draw_text(self, rect.position + Vector2((rect.size.x - CellOutzType.width(label, h, 1.0)) * 0.5, (rect.size.y - h) * 0.5), label, h, BONE, 1.0)
