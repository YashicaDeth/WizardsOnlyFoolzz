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

## This is a description of what the game already is at every tier — the
## world's own aggression, its language, what it implies about sex and
## drugs — not a promise that a lower tier launders any of it. Only the
## gore axis is actually mechanically gated today
## (`BaselineHuman.apply_gore_setting()`, splat detail and whether they
## render at all); CLINICAL is the honest floor of what that one dial can
## turn down, stated plainly rather than implied.
const TIERS := [
	{
		"id": "OFF", "name": "CLINICAL",
		"note": "No blood, no viscera. The record still says what happened to them. Nothing else here is softened — the temper, the mouths, what people want stay exactly as they are.",
	},
	{
		"id": "REDUCED", "name": "FIELD CONDITIONS",
		"note": "What you would actually see, badly lit, mostly at speed. Full aggression, full language, adult content and drug use throughout — this tier softens the wound, not the world.",
	},
	{
		"id": "FULL", "name": "UNRESTRICTED",
		"note": "Everything the body has, on the floor, for as long as you stand there. No limits anywhere — violence, aggression, language, sex, drugs. This is the game as written.",
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
		# The label is drawn in the display face; the Button keeps the hit area,
		# the focus handling and the keyboard support.
		button.text = ""
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


## The words say what each tier is; this is the same claim shown rather than
## told. One small silhouette per row, unmarked at CLINICAL, opening up
## further at each tier down to UNRESTRICTED's missing limb — procedural
## rather than three authored images for the reason every mark in this
## project is: nothing to keep in sync if a tier's own balance is retuned
## later. Seeded per tier rather than per frame, so the preview holds still
## instead of crawling every redraw.
## Word-wraps at the stencil face's own measured width rather than a character
## count, so a run of narrow letters and a run of wide ones both actually fit
## the line they were measured against.
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


func _draw_gore_preview(at: Vector2, tier_index: int) -> void:
	var ghost := INK * Color(1, 1, 1, 0.45)
	draw_line(at + Vector2(0, -20), at + Vector2(0, 14), ghost, 2.0)
	draw_circle(at + Vector2(0, -27), 7.0, ghost)
	draw_line(at + Vector2(0, -10), at + Vector2(-11, 3), ghost, 2.0)
	draw_line(at + Vector2(0, -10), at + Vector2(11, 3), ghost, 2.0)
	draw_line(at + Vector2(0, 14), at + Vector2(-9, 32), ghost, 2.0)
	var right_leg_gone := tier_index == 2
	if not right_leg_gone:
		draw_line(at + Vector2(0, 14), at + Vector2(9, 32), ghost, 2.0)
	if tier_index == 0:
		return
	# CLINICAL is the honest floor of the one dial this actually is — see the
	# note on `TIERS` above.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 + tier_index
	var marks := 4 if tier_index == 1 else 14
	for _mark in marks:
		var offset := Vector2(rng.randf_range(-13.0, 13.0), rng.randf_range(-24.0, 30.0))
		draw_circle(at + offset, rng.randf_range(1.1, 2.6), ARTERIAL * Color(1, 1, 1, 0.85))
	if right_leg_gone:
		# The stump, not the intact silhouette everything else on this card
		# points at — the one row where the preview stops implying and shows.
		draw_line(at + Vector2(0, 14), at + Vector2(3, 22), ARTERIAL, 3.0)
		draw_circle(at + Vector2(3, 22), 2.6, ARTERIAL)


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), VOID * Color(1, 1, 1, 0.93))
	draw_set_transform(_origin, 0.0, Vector2(_factor, _factor))

	draw_rect(Rect2(0, 0, DESIGN.x, DESIGN.y), Color("0a120e"))
	draw_rect(Rect2(0, 0, DESIGN.x, DESIGN.y), ARTERIAL * Color(1, 1, 1, 0.55), false, 2.0)
	# A second misregistered plate, the way a dying press prints.
	draw_rect(Rect2(3, 2, DESIGN.x, DESIGN.y), ARTERIAL * Color(1, 1, 1, 0.12), false, 2.0)
	for row in range(6, int(DESIGN.y), 3):
		draw_line(Vector2(4, row), Vector2(DESIGN.x - 4, row), Color(0, 0, 0, 0.17), 1.0)

	var beat := 0.5 + 0.5 * sin(clock * 2.4)
	CellOutzType.draw_stamped(self, Vector2(60, 40), "WARNING", 44.0, ARTERIAL * Color(1, 1, 1, 0.8 + beat * 0.2), ARTERIAL * Color(1, 1, 1, 0.2), 5.0)
	CellOutzType.draw_text(self, Vector2(60, 96), "CELLOUTZ CORPORATION / LIABILITY NOTICE 11-B", 11.0, BILE, 1.4)
	draw_line(Vector2(60, 118), Vector2(DESIGN.x - 60, 118), ARTERIAL * Color(1, 1, 1, 0.4), 1.0)

	# This is the first prose anybody reads in the game, and it was set in the
	# engine's fallback UI font — next to a stencilled WARNING, on a card that is
	# otherwise entirely house type. `draw_string` takes a baseline and
	# `CellOutzType` takes a top-left, so the y is lifted by the cap to land each
	# line exactly where it already sat.
	var body_cap := 11.0
	var line_y := 152.0
	for line in BODY.split("\n"):
		CellOutzType.draw_condensed(self, Vector2(60, line_y - body_cap), line, body_cap,
			INK * Color(1, 1, 1, 0.82), 1.0)
		line_y += 22.0

	CellOutzType.draw_text(self, Vector2(60, 334), "CHOOSE WHAT YOU ARE WILLING TO SEE", 13.0, ACID, 2.2)
	# Arrow glyphs are not in the stencil alphabet — `CellOutzType.draw_text`
	# skips anything it has no glyph for, so the pair would have come out as two
	# gaps. Named instead, which is also what the keys card does.
	var keys_hint := "1-3   UP/DOWN   ENTER"
	var keys_width := CellOutzType.width_condensed(keys_hint, 9.0, 1.2)
	CellOutzType.draw_condensed(self, Vector2(DESIGN.x - 60 - keys_width, 335), keys_hint, 9.0,
		INK * Color(1, 1, 1, 0.4), 1.2)

	for index in buttons.size():
		var row := buttons[index]
		var accent_row := ARTERIAL if index == 2 else (ACID if index == 1 else INK)
		CellOutzType.draw_text(self, row.position + Vector2(20, 18), "%02d" % (index + 1), 15.0, INK * Color(1, 1, 1, 0.4), 1.6)
		CellOutzType.draw_text(self, row.position + Vector2(62, 15), str(TIERS[index].name), 21.0, accent_row * Color(1, 1, 1, 1.0 if index == highlighted else 0.78), 3.0)
		_draw_gore_preview(row.position + Vector2(725, 25), index)
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
	# entirely on the last tier. Wrapped rather than one line now that the note
	# actually says what every tier covers, not only what it looks like — the
	# unwrapped text ran clean off the right edge of the card, uncut, on the
	# capture that first proved it.
	var note_lines := _wrap_condensed(str(TIERS[highlighted].note), 10.0, 1.0, DESIGN.x - 120.0)
	var note_y := DESIGN.y - 58.0 - float(note_lines.size() - 1) * 14.0
	for line in note_lines:
		CellOutzType.draw_condensed(self, Vector2(60, note_y), line, 10.0, INK * Color(1, 1, 1, 0.78), 1.0)
		note_y += 14.0

	CellOutzType.draw_condensed(self, Vector2(60, DESIGN.y - 28), "THIS CHOICE CAN BE CHANGED LATER. THE BODIES CANNOT.", 9.0,
		BILE * Color(1, 1, 1, 0.65), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
