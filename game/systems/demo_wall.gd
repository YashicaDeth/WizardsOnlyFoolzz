class_name DemoWall
extends Control

## P3. The demo's authored stop, presented as the institution closing an
## account it has already charged. This appears only after the real Hunt win;
## it does not decide whether the player earned that win.

signal front_door_requested

const VOID := Color("050706")
const PAPER := Color("d8d0ae")
const INK := Color("17150f")
const RED := Color("a82920")
const ACID := Color("8da839")
const DESIGN := Vector2(880, 620)

var clock := 0.0
var _factor := 1.0
var _origin := Vector2.ZERO
var _button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_button = Button.new()
	_button.name = "FrontDoor"
	_button.text = ""
	_button.position = Vector2(70, 532)
	_button.size = Vector2(740, 54)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = RED * Color(1, 1, 1, 0.20 if state != "normal" else 0.08)
		style.border_color = RED * Color(1, 1, 1, 0.95 if state != "normal" else 0.55)
		style.border_width_left = 5
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		_button.add_theme_stylebox_override(state, style)
	_button.pressed.connect(_request_front_door)
	add_child(_button)
	hide()


func open_wall() -> void:
	show()
	clock = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_button.grab_focus()
	queue_redraw()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false


func _request_front_door() -> void:
	get_tree().paused = false
	front_door_requested.emit()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		_request_front_door()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	_factor = clampf(minf(size.x / (DESIGN.x + 100.0), size.y / (DESIGN.y + 60.0)), 0.5, 1.4)
	_origin = (size - DESIGN * _factor) * 0.5
	_button.scale = Vector2.ONE * _factor
	_button.position = _origin + Vector2(70, 532) * _factor
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), VOID)
	draw_set_transform(_origin, 0.0, Vector2.ONE * _factor)
	draw_rect(Rect2(Vector2.ZERO, DESIGN), PAPER)
	draw_rect(Rect2(Vector2.ZERO, DESIGN), INK, false, 3.0)
	draw_rect(Rect2(7, 7, DESIGN.x - 14, DESIGN.y - 14), RED * Color(1, 1, 1, 0.72), false, 2.0)
	for row in range(12, int(DESIGN.y), 7):
		draw_line(Vector2(12, row), Vector2(DESIGN.x - 12, row), INK * Color(1, 1, 1, 0.035), 1.0)

	var pulse := 0.82 + sin(clock * 3.0) * 0.12
	CellOutzType.draw_stamped(self, Vector2(56, 38), "ACCOUNT CLOSED", 42.0, RED * Color(1, 1, 1, pulse), INK * Color(1, 1, 1, 0.18), 4.0)
	CellOutzType.draw_text(self, Vector2(58, 93), "CELLOUTZ DEMONSTRATION REGISTER / FINAL INVOICE", 11.0, INK, 1.3)
	draw_line(Vector2(58, 118), Vector2(822, 118), RED, 2.0)

	CellOutzType.draw_text(self, Vector2(58, 143), "SERVICE RENDERED", 13.0, RED, 1.8)
	CellOutzType.draw_condensed(self, Vector2(58, 172), "ASHLINE CAPTAIN FORCED FROM THE FIELD", 15.0, INK, 1.3)
	CellOutzType.draw_condensed(self, Vector2(58, 199), "YOUR BODY AND THEIR GRUDGE REMAIN ON FILE", 11.0, INK * Color(1, 1, 1, 0.78), 1.1)

	CellOutzType.draw_text(self, Vector2(58, 244), "WITHHELD AFTER PAYMENT FAILURE", 13.0, RED, 1.8)
	_draw_line_item(278, "01", "OUTER ASHBLOOM ROAD / LIVE REGION ACCESS")
	_draw_line_item(316, "02", "ASHLINE CAPTAIN / SECOND HUNT / REBUILT BODY")
	_draw_line_item(354, "03", "BOARD CONTRACTS / FACTION ROADS / THE WIRE")

	CellOutzType.draw_text(self, Vector2(58, 416), "BALANCE DUE", 12.0, INK * Color(1, 1, 1, 0.7), 1.5)
	CellOutzType.draw_stamped(self, Vector2(58, 444), "THE REST OF THE GAME", 27.0, RED, INK * Color(1, 1, 1, 0.12), 3.0)
	CellOutzType.draw_condensed(self, Vector2(58, 486), "THIS ENDING HAS BEEN WRITTEN INTO YOUR RECORD", 10.0, ACID, 1.0)
	CellOutzType.draw_text(self, Vector2(92, 548), "RETURN TO THE FRONT DOOR", 18.0, INK, 2.4)
	CellOutzType.draw_condensed(self, Vector2(668, 553), "ENTER / ESC", 9.0, RED, 1.0)


func _draw_line_item(y: float, number: String, label: String) -> void:
	CellOutzType.draw_text(self, Vector2(58, y), number, 12.0, RED, 1.4)
	draw_line(Vector2(96, y + 8), Vector2(815, y + 8), INK * Color(1, 1, 1, 0.16), 1.0)
	CellOutzType.draw_condensed(self, Vector2(112, y), label, 11.0, INK, 1.0)
