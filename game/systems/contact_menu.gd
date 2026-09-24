class_name ContactMenu
extends Control

## The people you carry, the things that noticed you, and the cabinet where
## you met half of them. Three folders of the wetwire index — PEOPLE,
## ENTITIES, MATERIA — read through `BrainIndex`, which owns every rule here:
## sealed rows list but never open, higher planes refuse without reach, and
## drug experiences arrive as real rows per dose taken rather than lore.
##
## This menu adds no rules and keeps none. It draws the index and reports what
## the index says, including the refusals — a sealed row answering SEALED is
## the index working, not the menu failing.

signal close_requested

const INDEX := preload("res://systems/brain_index.gd")

const INK := Color("d9c79a")
const BLOOD := Color("a92e32")
const MOSS := Color("8ea85d")
const DIM := Color("5a5648")
const GLASS := Color("090b0a")

const FOLDERS := ["people", "entities", "drugs"]

var folder := 0
var selected := 0
var reading: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false


func open_menu() -> void:
	folder = 0
	selected = 0
	reading = {}
	visible = true
	queue_redraw()


func close_menu() -> void:
	visible = false


func rows() -> Array:
	return INDEX.listing(str(FOLDERS[folder]))


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_F8:
				close_requested.emit()
			KEY_LEFT, KEY_A:
				folder = posmod(folder - 1, FOLDERS.size())
				selected = 0
				reading = {}
				queue_redraw()
			KEY_RIGHT, KEY_D:
				folder = posmod(folder + 1, FOLDERS.size())
				selected = 0
				reading = {}
				queue_redraw()
			KEY_UP, KEY_W:
				selected = maxi(0, selected - 1)
				reading = {}
				queue_redraw()
			KEY_DOWN, KEY_S:
				selected = mini(rows().size() - 1, selected + 1)
				reading = {}
				queue_redraw()
			KEY_ENTER, KEY_KP_ENTER:
				_read_selected()
		return true
	return event is InputEventMouseMotion


func _read_selected() -> void:
	var list := rows()
	if selected < 0 or selected >= list.size():
		return
	reading = INDEX.read_entry(str((list[selected] as Dictionary).get("id", "")))
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	var screen := Rect2(Vector2.ZERO, size)
	draw_rect(screen, Color(0.01, 0.012, 0.01, 0.90))
	var plate := Rect2(size * Vector2(0.12, 0.1), size * Vector2(0.76, 0.8))
	draw_rect(plate, GLASS)
	draw_rect(plate, INK * Color(1, 1, 1, 0.4), false, 2.0)
	draw_string(font, plate.position + Vector2(28, 38), "CONTACT // WHO YOU CARRY, WHAT NOTICED YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, INK)
	draw_string(font, plate.position + Vector2(28, 62), "LEFT/RIGHT FOLDER   UP/DOWN SELECT   ENTER REACH   F8 / ESC CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK * Color(1, 1, 1, 0.65))
	var tab_x := plate.position.x + 28.0
	for index in FOLDERS.size():
		var spec: Dictionary = INDEX.FOLDERS.get(str(FOLDERS[index]), {})
		var label := str(spec.get("label", str(FOLDERS[index]).to_upper()))
		var active := index == folder
		if active:
			draw_rect(Rect2(Vector2(tab_x - 6, 74), Vector2(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12, 22)), BLOOD * Color(1, 1, 1, 0.25))
		draw_string(font, Vector2(tab_x, 90), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK if active else DIM)
		tab_x += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0
	var list := rows()
	var y := plate.position.y + 128.0
	var max_rows := maxi(1, floori((plate.size.y - 260.0) / 26.0))
	for index in range(mini(list.size(), max_rows)):
		var row: Dictionary = list[index]
		var at := Vector2(plate.position.x + 28, y)
		if index == selected:
			draw_rect(Rect2(at - Vector2(6, 16), Vector2(plate.size.x - 56, 24)), INK * Color(1, 1, 1, 0.12))
		var ink := INK if bool(row.get("open", false)) else DIM
		if not bool(row.get("reachable", true)):
			ink = BLOOD
		draw_string(font, at, str(row.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 120, 13, ink)
		y += 26.0
	if list.is_empty():
		draw_string(font, Vector2(plate.position.x + 28, y), "NOTHING FILED HERE YET.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	if not reading.is_empty():
		var ry := plate.end.y - 110.0
		if bool(reading.get("ok", false)):
			draw_string(font, Vector2(plate.position.x + 28, ry), str(reading.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MOSS)
			draw_string(font, Vector2(plate.position.x + 28, ry + 24), str(reading.get("body", "")).left(220), HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 56, 12, INK * Color(1, 1, 1, 0.8))
		else:
			draw_string(font, Vector2(plate.position.x + 28, ry), str(reading.get("reason", "REFUSED")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BLOOD)
