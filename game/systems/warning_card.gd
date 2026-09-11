class_name WarningCard
extends Control

## The card that comes up before anything else. Greg asked for the Postal 2
## register — a blunt, funny, slightly unhinged notice that sets the tone before
## the game proper starts — so this is that idea in the Ashbloom's own voice: a
## CellOutz product liability notice, written by a company that is not sorry.
##
## It is also load-bearing rather than decoration. The game already carries
## three violence tiers and buried them in a settings submenu nobody opens; the
## card is where that choice is actually made, which is why it is the first
## thing the player is asked.

signal chosen(gore_mode: String)

const TIERS := [
	{
		"id": "OFF", "name": "CLINICAL",
		"note": "No blood, no viscera. The record still says what happened to them.",
	},
	{
		"id": "REDUCED", "name": "FIELD CONDITIONS",
		"note": "What you would actually see, badly lit, mostly at speed.",
	},
	{
		"id": "FULL", "name": "UNRESTRICTED",
		"note": "Everything the body has, on the floor, for as long as you stand there.",
	},
]

const BODY := """CELLOUTZ CORPORATION accepts no responsibility for what this
product depicts, implies, or causes you to consider.

This is a work of fiction. The organs are fictional. The
company is fictional. The company's opinion of you is not.

Nothing here should be attempted, recreated or reported.
Anyone doing so is acting alone and we will say so loudly."""

const VOID := Color("060b09")
const INK := Color("dce6ba")
const ACID := Color("b4da48")
const ARTERIAL := Color("c81f16")
const RED := Color("e65a4f")
const BILE := Color("b8a12a")

var buttons: Array[Button] = []
var highlighted := 2
var clock := 0.0
var sheet: Control
var _factor := 1.0
var _origin := Vector2.ZERO

const DESIGN := Vector2(880, 620)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	sheet = Control.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	for index in TIERS.size():
		var tier: Dictionary = TIERS[index]
		var button := Button.new()
		button.name = str(tier.id)
		button.text = "    %s" % str(tier.name)
		button.position = Vector2(60, 372 + index * 58)
		button.size = Vector2(760, 50)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 21)
		var accent := ARTERIAL if index == 2 else (ACID if index == 1 else INK)
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


func open_card() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clock = 0.0
	buttons[2].grab_focus()
	_highlight(2)


func _highlight(index: int) -> void:
	highlighted = index
	queue_redraw()


func _choose(index: int) -> void:
	var mode := str(TIERS[index].id)
	WorldHistory.register_subject("settings", {"gore": mode})
	WorldHistory.update_subject("settings", {"gore": mode}, "gore_setting_chosen")
	BaselineHuman.apply_gore_setting()
	hide()
	chosen.emit(mode)


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			_choose(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		KEY_UP, KEY_W:
			buttons[(highlighted + 2) % 3].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_DOWN, KEY_S:
			buttons[(highlighted + 1) % 3].grab_focus()
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


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), VOID * Color(1, 1, 1, 0.93))
	draw_set_transform(_origin, 0.0, Vector2(_factor, _factor))

	draw_rect(Rect2(0, 0, DESIGN.x, DESIGN.y), Color("0a120e"))
	draw_rect(Rect2(0, 0, DESIGN.x, DESIGN.y), ARTERIAL * Color(1, 1, 1, 0.55), false, 2.0)
	# A second misregistered plate, the way a dying press prints.
	draw_rect(Rect2(3, 2, DESIGN.x, DESIGN.y), ARTERIAL * Color(1, 1, 1, 0.12), false, 2.0)
	for row in range(6, int(DESIGN.y), 3):
		draw_line(Vector2(4, row), Vector2(DESIGN.x - 4, row), Color(0, 0, 0, 0.17), 1.0)

	var beat := 0.5 + 0.5 * sin(clock * 2.4)
	draw_string(font, Vector2(60, 78), "WARNING", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, ARTERIAL * Color(1, 1, 1, 0.75 + beat * 0.25))
	draw_string(font, Vector2(60, 104), "CELLOUTZ CORPORATION / PRODUCT LIABILITY NOTICE 11-B", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BILE)
	draw_line(Vector2(60, 118), Vector2(DESIGN.x - 60, 118), ARTERIAL * Color(1, 1, 1, 0.4), 1.0)

	var line_y := 152.0
	for line in BODY.split("\n"):
		draw_string(font, Vector2(60, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, DESIGN.x - 120, 15, INK * Color(1, 1, 1, 0.82))
		line_y += 22.0

	draw_string(font, Vector2(60, 344), "CHOOSE WHAT YOU ARE WILLING TO SEE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ACID)
	draw_string(font, Vector2(DESIGN.x - 60, 344), "1-3   ↑↓   ENTER", HORIZONTAL_ALIGNMENT_RIGHT, 0, 11, INK * Color(1, 1, 1, 0.4))

	for index in buttons.size():
		var row := buttons[index]
		draw_string(font, row.position + Vector2(20, 32), "%02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK * Color(1, 1, 1, 0.38))
		if index == highlighted:
			var accent := ARTERIAL if index == 2 else (ACID if index == 1 else INK)
			var slide := 5.0 + sin(clock * 6.0) * 2.0
			draw_colored_polygon(PackedVector2Array([
				row.position + Vector2(-14 - slide, 16),
				row.position + Vector2(-4 - slide, 25),
				row.position + Vector2(-14 - slide, 34),
			]), accent)

	# The consequence line sits in one fixed place under the rows. Drawing it
	# beneath the highlighted row put it through the row below and off the card
	# entirely on the last tier.
	draw_string(font, Vector2(60, DESIGN.y - 56), str(TIERS[highlighted].note), HORIZONTAL_ALIGNMENT_LEFT, DESIGN.x - 120, 14, INK * Color(1, 1, 1, 0.78))

	draw_string(font, Vector2(60, DESIGN.y - 28), "THIS CHOICE CAN BE CHANGED LATER. THE BODIES CANNOT.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BILE * Color(1, 1, 1, 0.65))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
