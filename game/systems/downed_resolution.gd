class_name DownedResolution
extends Control

## The downed-enemy resolution window. Not a menu: the world keeps running
## behind it, the panel sits along the bottom of the frame rather than over the
## middle of it, and a tether ties the form to the body actually lying on the
## ground. Deciding is supposed to cost time you may not have.
##
## Presentation only. It is handed a name, a live anatomy snapshot and a
## recruitment verdict, and it emits one of three outcomes. It knows nothing
## about WorldHistory, the rig or the hunt loop.

signal selected(outcome: String)
signal cancelled()
signal voice_capture_requested(active: bool)

const CHOICES := ["execute", "spare", "recruit"]
const TITLES := ["EXECUTE", "SPARE", "RECRUIT"]
const CONSEQUENCES := [
	"Finish them where they lie. The wound that dropped them becomes the wound that killed them, their carried goods fall here, and the record closes.",
	"Pack the wounds and walk away. Nothing heals. They keep the injuries, the possessions and a first-hand account of you that they are free to spread.",
	"Offer a place beside you. Consensual only — they must already owe you or trust you. No chip, no ownership, and they can still refuse later.",
]
const CONTEXT_CONSEQUENCES := [
	"End them here. Their carried goods fall and the death enters the record.",
	"Stabilise them. Their wounds, possessions and memory of you remain.",
	"Offer shelter. They must already trust you or owe a recognised debt.",
]

# Ashbloom clinical palette: near-black ground, acid green instrumentation,
# arterial red for anything that is someone's death.
const VOID := Color("060b09")
const PLATE := Color("0a120e")
const INK := Color("dce6ba")
const ACID := Color("b4da48")
const SPORE := Color("9bf01a")
const ARTERIAL := Color("c81f16")
const RED := Color("e65a4f")
const BILE := Color("b8a12a")
const BRUISE := Color("6a2d6e")
const SCAN := Color("35b7a7")
const BONE := Color("ead4ad")

const DESIGN := Vector2(1180, 330)
const BODY_SCALE := 1.12

## Organ plan positions in the shared body space `character_archive.gd` and
## `kill_cam.gd` both draw in, so the same heart sits in the same place
## wherever the player sees it.
const ORGAN_PLAN := {
	"brain": Vector2(0, -86),
	"heart": Vector2(-3, -26),
	"left_lung": Vector2(-16, -29),
	"right_lung": Vector2(16, -29),
	"liver": Vector2(3, 13),
	"gut": Vector2(0, 35),
	"spine": Vector2(0, -4),
}
const ZONE_PLAN := {
	"head": Vector2(0, -86),
	"torso": Vector2(0, -12),
	"left_arm": Vector2(-38, -6),
	"right_arm": Vector2(38, -6),
	"left_leg": Vector2(-17, 72),
	"right_leg": Vector2(17, 72),
}

var buttons: Array[Button] = []
var cancel_button: Button
var voice_button: Button
var subject_name := ""
var subject_role := ""
var serial := "000-000"
var anatomy: Dictionary = {}
var highlighted := 1
var clock := 0.0
var sheet: Control
var consequence: Label
var recruit_allowed := false
var recruit_reason := ""
var world_anchor := Vector2(-1, -1)
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var voice_state := "MIC READY / HOLD V"
var voice_reply := ""
var voice_level := 0.0
var voice_active := false

var _grain: ImageTexture
var _factor := 1.0
var _origin := Vector2.ZERO
var _trace: PackedFloat32Array = PackedFloat32Array()
var compact_context := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The panel covers a strip, not the screen. Letting the pointer through the
	# rest of the frame is what keeps this from reading as a modal.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain = _build_grain()
	_trace.resize(150)
	sheet = Control.new()
	sheet.name = "Sheet"
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)

	consequence = Label.new()
	consequence.name = "Consequence"
	consequence.position = Vector2(686, 214)
	consequence.size = Vector2(474, 70)
	consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	consequence.add_theme_font_size_override("font_size", 14)
	consequence.add_theme_color_override("font_color", INK * Color(1, 1, 1, 0.86))
	sheet.add_child(consequence)

	for index in CHOICES.size():
		var button := _build_row(index)
		sheet.add_child(button)
		buttons.append(button)
	for index in buttons.size():
		buttons[index].focus_neighbor_top = buttons[(index + 2) % 3].get_path()
		buttons[index].focus_neighbor_bottom = buttons[(index + 1) % 3].get_path()

	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	cancel_button.text = "ESC   LEAVE THEM UNDECIDED"
	voice_button = Button.new()
	voice_button.name = "Talk"
	voice_button.text = "V   HOLD TO SPEAK"
	voice_button.position = Vector2(686, 286)
	voice_button.size = Vector2(290, 32)
	voice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	voice_button.add_theme_font_size_override("font_size", 13)
	voice_button.add_theme_color_override("font_color", SCAN)
	for state in ["normal", "hover", "pressed", "focus"]:
		var voice_style := StyleBoxFlat.new()
		voice_style.bg_color = SCAN * Color(1, 1, 1, 0.14 if state in ["hover", "pressed", "focus"] else 0.05)
		voice_style.border_color = SCAN * Color(1, 1, 1, 0.8 if state in ["hover", "pressed", "focus"] else 0.3)
		voice_style.border_width_left = 4
		voice_style.content_margin_left = 14
		voice_button.add_theme_stylebox_override(state, voice_style)
	voice_button.button_down.connect(_voice_hold.bind(true))
	voice_button.button_up.connect(_voice_hold.bind(false))
	sheet.add_child(voice_button)

	cancel_button.position = Vector2(988, 286)
	cancel_button.size = Vector2(172, 32)
	cancel_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cancel_button.add_theme_font_size_override("font_size", 12)
	cancel_button.add_theme_color_override("font_color", INK * Color(1, 1, 1, 0.55))
	cancel_button.add_theme_color_override("font_hover_color", INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = INK * Color(1, 1, 1, 0.5 if state in ["hover", "focus"] else 0.16)
		style.border_width_top = 1
		style.content_margin_left = 14
		cancel_button.add_theme_stylebox_override(state, style)
	cancel_button.pressed.connect(cancel_menu)
	sheet.add_child(cancel_button)
	hide()


func _build_row(index: int) -> Button:
	var accent := RED if index == 0 else ACID
	var button := Button.new()
	button.name = TITLES[index]
	button.text = "      %s" % TITLES[index]
	button.position = Vector2(686, 56 + index * 52)
	button.size = Vector2(474, 46)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", accent * Color(1, 1, 1, 0.78))
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_focus_color", accent)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", INK * Color(1, 1, 1, 0.22))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var lit: bool = state in ["hover", "focus", "pressed"]
		var style := StyleBoxFlat.new()
		style.bg_color = accent * Color(1, 1, 1, 0.15) if lit else Color(0.055, 0.08, 0.06, 0.72)
		style.border_color = accent * Color(1, 1, 1, 0.9 if lit else 0.3)
		style.border_width_left = 5
		style.border_width_top = 1 if lit else 0
		style.border_width_bottom = 1 if lit else 0
		style.content_margin_left = 20
		if state == "disabled":
			style.bg_color = Color(0.05, 0.055, 0.05, 0.55)
			style.border_color = INK * Color(1, 1, 1, 0.14)
		button.add_theme_stylebox_override(state, style)
	button.mouse_entered.connect(_highlight.bind(index))
	button.focus_entered.connect(_highlight.bind(index))
	button.pressed.connect(_choose.bind(index))
	return button


## Paper grain and toner speckle. Generated so the form carries no external
## texture dependency, the same rule the dossier follows.
func _build_grain() -> ImageTexture:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			var hashed := sin(float(x * 127 + y * 311)) * 43758.5453
			var speckle: float = hashed - floorf(hashed)
			var band := 0.5 + 0.5 * sin(float(y) * 0.7)
			var value := clampf(speckle * 0.7 + band * 0.3, 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value, 0.18 + value * 0.5))
	return ImageTexture.create_from_image(image)


func open_for(display_name: String, snapshot: Dictionary, context: Dictionary = {}) -> void:
	if visible:
		return
	previous_mouse_mode = Input.mouse_mode
	subject_name = display_name
	subject_role = str(context.get("role", "UNFILED")).to_upper()
	serial = _serial_for(str(context.get("subject_id", display_name)))
	anatomy = snapshot.duplicate(true)
	recruit_allowed = bool(context.get("recruit", false))
	recruit_reason = str(context.get("recruit_reason", "No bond, no debt, no reason to follow you."))
	buttons[2].disabled = not recruit_allowed
	buttons[2].tooltip_text = "They agree to join." if recruit_allowed else recruit_reason
	clock = 0.0
	voice_state = "MIC READY / HOLD V"
	voice_reply = ""
	voice_level = 0.0
	voice_active = false
	for index in _trace.size():
		_trace[index] = 0.0
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	buttons[1].grab_focus()
	_highlight(1)


func close_menu() -> void:
	if not visible:
		return
	hide()
	if voice_active:
		_voice_hold(false)
	world_anchor = Vector2(-1, -1)
	Input.mouse_mode = previous_mouse_mode


func cancel_menu() -> void:
	if not visible:
		return
	close_menu()
	cancelled.emit()


## Screen position of the victim, so the form can point at the actual body.
## Off-screen is expressed as a negative anchor and simply drops the tether.
func set_world_anchor(at: Vector2) -> void:
	world_anchor = at


func _choose(index: int) -> void:
	if not visible or buttons[index].disabled:
		return
	close_menu()
	selected.emit(CHOICES[index])


func _highlight(index: int) -> void:
	highlighted = index
	consequence.text = CONTEXT_CONSEQUENCES[index] if compact_context else CONSEQUENCES[index]
	consequence.add_theme_color_override("font_color", (RED if index == 0 else INK) * Color(1, 1, 1, 0.9))
	if index == 2 and not recruit_allowed:
		consequence.text = "REFUSED. %s Mercy does not buy consent." % recruit_reason
		consequence.add_theme_color_override("font_color", BILE)
	queue_redraw()


func set_voice_state(state: String, level_value := 0.0, reply := "") -> void:
	voice_state = state
	voice_level = clampf(level_value, 0.0, 1.0)
	if not reply.is_empty():
		voice_reply = reply
	voice_button.text = ("V   LISTENING ..." if voice_active else "V   HOLD TO SPEAK")
	queue_redraw()


func _voice_hold(holding: bool) -> void:
	if not visible or voice_active == holding:
		return
	voice_active = holding
	voice_button.text = "V   LISTENING ..." if holding else "V   HOLD TO SPEAK"
	voice_capture_requested.emit(holding)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	if event.keycode == KEY_V and not event.echo:
		_voice_hold(event.pressed)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			cancel_menu()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3:
			_choose(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		KEY_W, KEY_UP:
			buttons[(highlighted + 2) % 3].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_S, KEY_DOWN:
			buttons[(highlighted + 1) % 3].grab_focus()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_choose(highlighted)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	if compact_context:
		_factor = clampf(minf(size.x / 1280.0, size.y / 720.0), 0.72, 1.15)
		var anchor := world_anchor if world_anchor.x >= 0.0 else size * Vector2(0.48, 0.42)
		_origin = Vector2(
			clampf(anchor.x + 74.0 * _factor, 24.0, size.x - 390.0 * _factor),
			clampf(anchor.y - 102.0 * _factor, 86.0, size.y - 300.0 * _factor),
		)
		sheet.scale = Vector2.ONE * _factor
		sheet.position = _origin
		_layout_context_controls()
		_advance_trace(delta)
		queue_redraw()
		return
	_factor = clampf(minf(size.x / 1232.0, size.y / 760.0), 0.55, 1.3)
	_origin = Vector2((size.x - DESIGN.x * _factor) * 0.5, size.y - (DESIGN.y + 22.0) * _factor)
	sheet.scale = Vector2.ONE * _factor
	sheet.position = _origin
	_advance_trace(delta)
	queue_redraw()


func _layout_context_controls() -> void:
	consequence.position = Vector2(18, 205)
	consequence.size = Vector2(350, 48)
	consequence.add_theme_font_size_override("font_size", 12)
	for index in buttons.size():
		buttons[index].position = Vector2(18, 54 + index * 48)
		buttons[index].size = Vector2(350, 40)
		buttons[index].add_theme_font_size_override("font_size", 18)
	voice_button.position = Vector2(18, 258)
	voice_button.size = Vector2(226, 30)
	cancel_button.position = Vector2(250, 258)
	cancel_button.size = Vector2(118, 30)
	cancel_button.text = "ESC  LEAVE"


## A pulse trace driven by the real body: rate follows how fast they are losing
## blood, amplitude follows how conscious they still are. It flatlines toward
## nothing as the snapshot worsens, without any separate animation state.
func _advance_trace(delta: float) -> void:
	var consciousness := clampf(float(anatomy.get("consciousness", 60)) / 100.0, 0.0, 1.0)
	var rate := 1.6 + clampf(float(anatomy.get("bleed_rate", 0.0)) / 6.0, 0.0, 2.2)
	var phase := fmod(clock * rate, 1.0)
	var beat := 0.0
	if phase < 0.06:
		beat = -0.35
	elif phase < 0.12:
		beat = 1.0
	elif phase < 0.18:
		beat = -0.55
	elif phase < 0.34:
		beat = 0.18
	var sample := beat * (0.25 + consciousness * 0.75)
	var steps := maxi(1, int(delta * 90.0))
	for _step in steps:
		for index in range(_trace.size() - 1):
			_trace[index] = _trace[index + 1]
		_trace[_trace.size() - 1] = sample


func _zone_ratio(zone_id: String) -> float:
	var zones: Dictionary = anatomy.get("zones", {})
	if not zones.has(zone_id):
		return 1.0
	var ceiling := float((AnatomyComponent.DEFAULT_ZONES[zone_id] as Dictionary).health)
	return clampf(float((zones[zone_id] as Dictionary).get("health", ceiling)) / ceiling, 0.0, 1.0)


func worst_zone() -> String:
	var worst := "torso"
	var lowest := 2.0
	for zone_id in AnatomyComponent.DEFAULT_ZONES:
		var ratio := _zone_ratio(zone_id)
		if ratio < lowest:
			lowest = ratio
			worst = zone_id
	return worst


func ruptured_organs() -> Array:
	var out: Array = []
	var organs: Dictionary = anatomy.get("organs", {})
	for organ_id in ORGAN_PLAN:
		if bool((organs.get(organ_id, {}) as Dictionary).get("ruptured", false)):
			out.append(organ_id)
	return out


func _serial_for(id: String) -> String:
	var value := absi(id.hash())
	return "%03d-%03d-%02d" % [value % 997, (value / 997) % 887, (value / 91) % 71]


func _tracked(at: Vector2, value: String, font_size: int, color: Color, tracking := 2.0) -> float:
	var font := ThemeDB.fallback_font
	var cursor := at
	for index in value.length():
		var glyph := value.substr(index, 1)
		draw_string(font, cursor, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		cursor.x += font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking
	return cursor.x - at.x


func _text(at: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if not visible:
		return
	if compact_context:
		_draw_context_overlay()
		return
	var rise := clampf(clock / 0.22, 0.0, 1.0)
	_draw_world_dim(rise)
	_draw_tether(rise)
	draw_set_transform(_origin, 0.0, Vector2(_factor, _factor) * Vector2(1.0, rise * 0.15 + 0.85))
	_draw_substrate()
	_draw_header()
	_draw_scan_cell()
	_draw_condition_cell()
	_draw_disposition_cell()
	_draw_wear()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Choices stay attached to the person in the rendered world. This is the
## encounter itself speaking, rather than a form that takes over the screen.
func _draw_context_overlay() -> void:
	var rise := ease(clampf(clock / 0.18, 0.0, 1.0), -1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.014, 0.012, 0.08 * rise))
	if world_anchor.x >= 0.0:
		var elbow := Vector2(_origin.x - 18.0, _origin.y + 42.0)
		draw_polyline(PackedVector2Array([world_anchor, Vector2(elbow.x - 34.0, world_anchor.y), elbow]), SPORE * Color(1, 1, 1, 0.5 * rise), 1.2)
		draw_arc(world_anchor, (18.0 + sin(clock * 4.0) * 2.0) * _factor, 0, TAU, 24, SPORE * Color(1, 1, 1, 0.62), 1.5)
		draw_line(world_anchor + Vector2(-24, 0), world_anchor + Vector2(-10, 0), SPORE, 1.2)
		draw_line(world_anchor + Vector2(10, 0), world_anchor + Vector2(24, 0), SPORE, 1.2)
	draw_set_transform(_origin, 0.0, Vector2.ONE * _factor)
	# The information sits on separate translucent scraps, leaving the world
	# visible between them like the in-scene confrontation reference.
	draw_colored_polygon(PackedVector2Array([Vector2(8, 4), Vector2(356, 4), Vector2(374, 20), Vector2(374, 294), Vector2(0, 294), Vector2(0, 12)]), PLATE * Color(1, 1, 1, 0.72))
	draw_polyline(PackedVector2Array([Vector2(8, 4), Vector2(356, 4), Vector2(374, 20)]), ACID * Color(1, 1, 1, 0.55), 1.2)
	_tracked(Vector2(18, 21), "CELLOUTZ / LIVE DISPOSITION", 10, ACID, 1.25)
	_text(Vector2(18, 42), subject_name.to_upper(), 18, INK)
	draw_string(ThemeDB.fallback_font, Vector2(222, 42), "DOWNED / ALIVE", HORIZONTAL_ALIGNMENT_RIGHT, 146, 10, RED)
	for index in buttons.size():
		if index != highlighted:
			continue
		var at: Vector2 = buttons[index].position
		var tint := RED if index == 0 else ACID
		var pulse := 3.0 + sin(clock * 6.0) * 1.5
		draw_colored_polygon(PackedVector2Array([at + Vector2(-12 - pulse, 12), at + Vector2(-4 - pulse, 20), at + Vector2(-12 - pulse, 28)]), tint)
		draw_line(at + Vector2(0, 40), at + Vector2(350, 40), tint * Color(1, 1, 1, 0.75), 1.4)
	var blood := int(anatomy.get("blood", 0))
	var pain := int(anatomy.get("pain", 0))
	_text(Vector2(18, 198), "%s TRAUMA   BLOOD %04d mL   PAIN %02d%%" % [worst_zone().to_upper().replace("_", " "), blood, pain], 10, RED)
	_text(Vector2(18, 254), voice_state, 9, SCAN)
	for meter in 14:
		var meter_height := 2.0 + voice_level * float(3 + (meter * 5) % 10)
		draw_rect(Rect2(202 + meter * 3.0, 251 - meter_height, 2, meter_height), SCAN * Color(1, 1, 1, 0.8))
	if not voice_reply.is_empty():
		draw_rect(Rect2(18, 203, 350, 48), Color(0.01, 0.02, 0.016, 0.92))
		draw_string(ThemeDB.fallback_font, Vector2(25, 223), "SUBJECT / %s" % voice_reply, HORIZONTAL_ALIGNMENT_LEFT, 334, 11, INK)
	_text(Vector2(368, 289), "1—3 / ↑↓ / ENTER", 9, INK * Color(1, 1, 1, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The world stays lit and stays running. Only a gradient under the form, so
## the type has something to sit on without the frame going black.
func _draw_world_dim(rise: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.02, 0.016, 0.26 * rise))
	var band := DESIGN.y * _factor + 90.0
	var steps := 18
	for step in steps:
		var t := float(step) / float(steps)
		var top := size.y - band * (1.0 - t)
		draw_rect(Rect2(0, top, size.x, band / float(steps) + 1.0), Color(0.01, 0.018, 0.014, 0.05 * rise))


## A leader from the form up to the body it is about. Without it the panel is a
## menu; with it the panel is a thing being said about someone on the ground.
func _draw_tether(rise: float) -> void:
	if world_anchor.x < 0.0 or world_anchor.y < 0.0:
		return
	if world_anchor.x > size.x or world_anchor.y > size.y:
		return
	var top := _origin + Vector2(DESIGN.x * 0.5 * _factor, 0)
	var elbow := Vector2(world_anchor.x, top.y - 46.0 * _factor)
	var reach := clampf(rise, 0.0, 1.0)
	var tip := world_anchor.lerp(elbow, 1.0 - reach)
	draw_polyline(PackedVector2Array([tip, elbow, top]), SPORE * Color(1, 1, 1, 0.35 * reach), 1.0)
	var tick := 9.0 * _factor
	draw_line(world_anchor + Vector2(-tick, -tick), world_anchor + Vector2(-tick, tick), SPORE * Color(1, 1, 1, 0.6 * reach), 1.0)
	draw_line(world_anchor + Vector2(tick, -tick), world_anchor + Vector2(tick, tick), SPORE * Color(1, 1, 1, 0.6 * reach), 1.0)
	draw_arc(world_anchor, 15.0 * _factor + sin(clock * 3.0) * 2.0, 0.0, TAU, 20, SPORE * Color(1, 1, 1, 0.3 * reach), 1.0)
	draw_string(ThemeDB.fallback_font, world_anchor + Vector2(tick + 6.0, -tick), "SUBJECT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * _factor), SPORE * Color(1, 1, 1, 0.7 * reach))


func _draw_substrate() -> void:
	var notch := 18.0
	var body := PackedVector2Array([
		Vector2(notch, 0), Vector2(DESIGN.x - notch, 0), Vector2(DESIGN.x, notch),
		Vector2(DESIGN.x, DESIGN.y), Vector2(0, DESIGN.y), Vector2(0, notch),
	])
	draw_colored_polygon(body, PLATE * Color(1, 1, 1, 0.97))
	# Toner banding: the copier never lays ink down evenly.
	for band in 9:
		var top := 10.0 + band * 35.0
		var hashed := absf(sin(float(band) * 12.9898) * 43758.5453)
		draw_rect(Rect2(4, top, DESIGN.x - 8, 12.0 + fmod(hashed, 14.0)), Color(0.7, 0.78, 0.55, 0.012 + fmod(hashed, 0.02)))
	draw_texture_rect(_grain, Rect2(0, 0, DESIGN.x, DESIGN.y), true, Color(0.62, 0.72, 0.45, 0.05))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, ACID * Color(1, 1, 1, 0.42), 1.4)
	# Torn top edge, left of the header rule.
	var tear := PackedVector2Array()
	for step in 40:
		var x := 24.0 + step * 7.0
		tear.append(Vector2(x, 2.0 + fmod(absf(sin(float(step) * 4.11) * 91.0), 3.4)))
	draw_polyline(tear, INK * Color(1, 1, 1, 0.16), 1.0)
	# Punch holes down the left margin.
	for hole in 3:
		draw_circle(Vector2(7, 74 + hole * 92), 3.4, VOID)
		draw_arc(Vector2(7, 74 + hole * 92), 3.4, 0.0, TAU, 12, INK * Color(1, 1, 1, 0.2), 1.0)
	_draw_halftone(Rect2(292, 254, 372, 62), 0.05)
	# A slow sweep across the whole sheet, so the paper is never quite still.
	var sweep := fmod(clock * 210.0, DESIGN.x + 300.0) - 150.0
	for line in 4:
		draw_line(Vector2(sweep + line * 3.0, 2), Vector2(sweep + line * 3.0, DESIGN.y - 2), SPORE * Color(1, 1, 1, 0.035 - line * 0.007), 2.0)


func _draw_halftone(rect: Rect2, strength: float) -> void:
	var step := 6.0
	var rows := int(rect.size.y / step)
	var columns := int(rect.size.x / step)
	for row in rows:
		for column in columns:
			var at := rect.position + Vector2(column * step, row * step)
			var wave := 0.5 + 0.5 * sin(float(column) * 0.5 + float(row) * 0.8 + clock * 0.6)
			draw_circle(at, 0.7 + wave * 1.5, INK * Color(1, 1, 1, strength))


func _draw_header() -> void:
	CellOutzType.draw_stamped(self, Vector2(26, 8), "CELLOUTZ", 16.0, ACID, ARTERIAL * Color(1, 1, 1, 0.35), 3.0)
	_tracked(Vector2(112, 22), "FIELD TRIAGE / HUMAN DISPOSITION", 13, INK * Color(1, 1, 1, 0.8), 1.6)
	_text(Vector2(DESIGN.x - 290, 22), "FORM 06-B   REV.C   SER %s" % serial, 11, INK * Color(1, 1, 1, 0.42))
	_draw_barcode(Rect2(DESIGN.x - 92, 10, 66, 15))
	draw_line(Vector2(14, 30), Vector2(DESIGN.x - 14, 30), ACID * Color(1, 1, 1, 0.34), 1.0)
	# Registration crosses in the margins.
	for at in [Vector2(DESIGN.x - 8, 40), Vector2(DESIGN.x - 8, DESIGN.y - 12)]:
		draw_line(at - Vector2(4, 0), at + Vector2(4, 0), INK * Color(1, 1, 1, 0.3), 1.0)
		draw_line(at - Vector2(0, 4), at + Vector2(0, 4), INK * Color(1, 1, 1, 0.3), 1.0)
	# Column rules.
	for x in [282.0, 672.0]:
		draw_line(Vector2(x, 38), Vector2(x, DESIGN.y - 14), INK * Color(1, 1, 1, 0.12), 1.0)


func _draw_barcode(rect: Rect2) -> void:
	var cursor := rect.position.x
	var value := absi(serial.hash())
	var index := 0
	while cursor < rect.end.x:
		var width := 1.0 + float((value >> (index % 24)) & 3)
		if index % 2 == 0:
			draw_rect(Rect2(cursor, rect.position.y, width, rect.size.y), INK * Color(1, 1, 1, 0.55))
		cursor += width + 1.0
		index += 1


func _draw_scan_cell() -> void:
	_tracked(Vector2(22, 52), "ANATOMICAL SCAN", 11, SPORE * Color(1, 1, 1, 0.75), 1.8)
	var center := Vector2(122, 186)
	var scale := BODY_SCALE
	var worst := worst_zone()

	# Zone silhouette, tinted by the real remaining health of each zone.
	for zone_id in ["left_arm", "right_arm", "left_leg", "right_leg", "torso", "head"]:
		_draw_zone(center, scale, zone_id, zone_id == worst)

	# Skeleton over the flesh, the way the dossier plate reads.
	var bone_tint := BONE * Color(1, 1, 1, 0.55)
	draw_line(center + Vector2(0, -55) * scale, center + Vector2(0, 46) * scale, bone_tint, 3.0 * scale)
	for rib in 5:
		var y := -40.0 + rib * 14.0
		draw_arc(center + Vector2(0, y) * scale, (25.0 - rib * 1.6) * scale, 0.22, PI - 0.22, 14, bone_tint, 1.4)
		draw_arc(center + Vector2(0, y) * scale, (25.0 - rib * 1.6) * scale, PI + 0.22, TAU - 0.22, 14, bone_tint * Color(1, 1, 1, 0.55), 1.0)
	draw_arc(center + Vector2(0, -86) * scale, 22.0 * scale, PI, TAU, 18, bone_tint, 1.4)
	draw_line(center + Vector2(-16, 45) * scale, center + Vector2(16, 45) * scale, bone_tint, 3.0 * scale)

	_draw_organs(center, scale)

	# The scan bar. It is the only fast movement on the sheet, which is what
	# makes the still type read as instrumentation rather than decoration.
	var span := 232.0
	var bar := 56.0 + fmod(clock * 74.0, span)
	draw_line(Vector2(24, bar), Vector2(268, bar), SPORE * Color(1, 1, 1, 0.42), 1.0)
	draw_rect(Rect2(24, bar - 11, 244, 11), SPORE * Color(1, 1, 1, 0.045))

	# Brackets around the zone that actually put them down.
	var focus: Vector2 = center + (ZONE_PLAN.get(worst, Vector2.ZERO) as Vector2) * scale
	var half: Vector2 = Vector2(30, 26) * scale
	var arm := 9.0
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = focus + half * corner
		draw_line(at, at - Vector2(arm * corner.x, 0), RED * Color(1, 1, 1, 0.85), 1.6)
		draw_line(at, at - Vector2(0, arm * corner.y), RED * Color(1, 1, 1, 0.85), 1.6)
	draw_string(ThemeDB.fallback_font, Vector2(24, 300), "TRAUMA  %s" % worst.to_upper().replace("_", " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RED)
	draw_string(ThemeDB.fallback_font, Vector2(24, 316), "SCAN PLATE 1:1  DOSE 04  OPERATOR UNLISTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK * Color(1, 1, 1, 0.34))


func _draw_zone(center: Vector2, scale: float, zone_id: String, focused: bool) -> void:
	var ratio := _zone_ratio(zone_id)
	var tint := SCAN.lerp(ARTERIAL, 1.0 - ratio)
	var alpha := 0.3 + (1.0 - ratio) * 0.35
	if focused:
		alpha += 0.08 * (0.5 + 0.5 * sin(clock * 4.0))
	var color := tint * Color(1, 1, 1, alpha)
	match zone_id:
		"head":
			draw_colored_polygon(_disc(center + Vector2(0, -86) * scale, 21.0 * scale, 25.0 * scale), color)
			draw_colored_polygon(_limb(center + Vector2(-7, -66) * scale, center + Vector2(-7, -56) * scale, 14.0 * scale), color)
		"torso":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-20, -62) * scale, center + Vector2(20, -62) * scale,
				center + Vector2(30, -48) * scale, center + Vector2(27, 2) * scale,
				center + Vector2(20, 44) * scale, center + Vector2(-20, 44) * scale,
				center + Vector2(-27, 2) * scale, center + Vector2(-30, -48) * scale,
			]), color)
		"left_arm":
			draw_colored_polygon(_limb(center + Vector2(-25, -48) * scale, center + Vector2(-47, 36) * scale, 15.0 * scale), color)
		"right_arm":
			draw_colored_polygon(_limb(center + Vector2(25, -48) * scale, center + Vector2(47, 36) * scale, 15.0 * scale), color)
		"left_leg":
			draw_colored_polygon(_limb(center + Vector2(-13, 40) * scale, center + Vector2(-20, 104) * scale, 18.0 * scale), color)
		"right_leg":
			draw_colored_polygon(_limb(center + Vector2(13, 40) * scale, center + Vector2(20, 104) * scale, 18.0 * scale), color)
	# A destroyed zone is struck through, so "gone" never depends on hue alone.
	if ratio <= 0.001:
		var at: Vector2 = center + (ZONE_PLAN.get(zone_id, Vector2.ZERO) as Vector2) * scale
		draw_line(at + Vector2(-16, -16) * scale, at + Vector2(16, 16) * scale, ARTERIAL * Color(1, 1, 1, 0.8), 2.0)
		draw_line(at + Vector2(16, -16) * scale, at + Vector2(-16, 16) * scale, ARTERIAL * Color(1, 1, 1, 0.8), 2.0)


func _draw_organs(center: Vector2, scale: float) -> void:
	var organs: Dictionary = anatomy.get("organs", {})
	var row := 0
	for organ_id in ORGAN_PLAN:
		var organ: Dictionary = organs.get(organ_id, {})
		var ruptured := bool(organ.get("ruptured", false))
		var at := center + (ORGAN_PLAN[organ_id] as Vector2) * scale
		var radius := (5.0 if organ_id == "spine" else 8.0) * scale
		var tint := BONE if organ_id == "spine" else (BRUISE if organ_id.ends_with("lung") else (BILE if organ_id in ["gut", "liver"] else ARTERIAL))
		if organ.is_empty():
			continue
		if ruptured:
			var throb := 0.5 + 0.5 * sin(clock * 5.0 + row)
			draw_circle(at, radius * (1.15 + throb * 0.2), ARTERIAL * Color(1, 1, 1, 0.55))
			draw_arc(at, radius * 2.0 + throb * 3.0, 0.0, TAU, 18, ARTERIAL * Color(1, 1, 1, 0.45), 1.2)
			for spur in 6:
				var angle := TAU * spur / 6.0 + row
				draw_line(at, at + Vector2.from_angle(angle) * radius * 2.2, ARTERIAL * Color(1, 1, 1, 0.5), 1.4)
		else:
			draw_arc(at, radius, 0.0, TAU, 16, tint * Color(1, 1, 1, 0.5), 1.2)
			draw_circle(at, radius * 0.35, tint * Color(1, 1, 1, 0.28))
		# Leader out to a labelled column, so every organ is named on the plate.
		var label_at := Vector2(196, 76 + row * 21)
		draw_line(at, label_at - Vector2(6, 4), (ARTERIAL if ruptured else INK) * Color(1, 1, 1, 0.22), 1.0)
		draw_string(ThemeDB.fallback_font, label_at, organ_id.replace("_", " ").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, (ARTERIAL if ruptured else INK) * Color(1, 1, 1, 0.85 if ruptured else 0.45))
		draw_string(ThemeDB.fallback_font, label_at + Vector2(0, 9), "RUPTURED" if ruptured else "INTACT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, (ARTERIAL if ruptured else SCAN) * Color(1, 1, 1, 0.8 if ruptured else 0.35))
		row += 1


func _draw_condition_cell() -> void:
	_tracked(Vector2(296, 52), "SUBJECT CONDITION", 11, SPORE * Color(1, 1, 1, 0.75), 1.8)
	draw_string(ThemeDB.fallback_font, Vector2(294, 88), subject_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 366, 27, INK)
	draw_string(ThemeDB.fallback_font, Vector2(296, 106), "%s   /   FILED %s" % [subject_role, serial], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK * Color(1, 1, 1, 0.4))

	# Status chip. Downed is a state with a clock on it, and it should look like
	# one: the stamp breathes and the word ALIVE is the thing at stake.
	var chip := Rect2(296, 118, 262, 26)
	var beat := 0.5 + 0.5 * sin(clock * 3.2)
	draw_rect(chip, ARTERIAL * Color(1, 1, 1, 0.1 + beat * 0.07))
	draw_rect(chip, ARTERIAL * Color(1, 1, 1, 0.5 + beat * 0.3), false, 1.2)
	_tracked(chip.position + Vector2(10, 18), "DOWNED — ALIVE — UNSTABLE", 12, RED, 1.2)

	var blood := float(anatomy.get("blood", 0))
	var capacity := maxf(1.0, float(anatomy.get("blood_capacity", 5000)))
	_meter(Vector2(296, 160), "BLOOD VOLUME", "%d / %d mL" % [int(blood), int(capacity)], blood / capacity, ARTERIAL)
	_meter(Vector2(296, 194), "CONSCIOUSNESS", "%d%%" % int(anatomy.get("consciousness", 0)), float(anatomy.get("consciousness", 0)) / 100.0, SPORE)
	_meter(Vector2(296, 228), "PAIN LOAD", "%d%%" % int(anatomy.get("pain", 0)), float(anatomy.get("pain", 0)) / 100.0, BILE)

	var ruptured := ruptured_organs()
	var wounds: Array = anatomy.get("wounds", [])
	draw_string(ThemeDB.fallback_font, Vector2(296, 276), "HAEMORRHAGE %.1f mL/s   LOGGED WOUNDS %02d" % [float(anatomy.get("bleed_rate", 0.0)), wounds.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.6))
	var rupture_text := "INTERNALS INTACT" if ruptured.is_empty() else "RUPTURED: " + ", ".join(ruptured).replace("_", " ").to_upper()
	draw_string(ThemeDB.fallback_font, Vector2(296, 290), rupture_text, HORIZONTAL_ALIGNMENT_LEFT, 364, 11, (SCAN if ruptured.is_empty() else ARTERIAL) * Color(1, 1, 1, 0.85))
	_draw_trace(Rect2(296, 298, 364, 24))


func _meter(at: Vector2, label: String, readout: String, ratio: float, tint: Color) -> void:
	var width := 364.0
	draw_string(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK * Color(1, 1, 1, 0.5))
	draw_string(ThemeDB.fallback_font, at + Vector2(width, 0), readout, HORIZONTAL_ALIGNMENT_RIGHT, width, 12, INK)
	var bar := Rect2(at + Vector2(0, 6), Vector2(width, 9))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar.position, Vector2(width * clampf(ratio, 0.0, 1.0), bar.size.y)), tint * Color(1, 1, 1, 0.72))
	draw_rect(bar, INK * Color(1, 1, 1, 0.2), false, 1.0)
	# Graduations, so the bar reads as an instrument and not a progress bar.
	for tick in 9:
		var x := bar.position.x + width * (float(tick + 1) / 10.0)
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.position.y + 3), VOID * Color(1, 1, 1, 0.6), 1.0)


func _draw_trace(rect: Rect2) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.35))
	var points := PackedVector2Array()
	for index in _trace.size():
		var x := rect.position.x + rect.size.x * float(index) / float(_trace.size() - 1)
		points.append(Vector2(x, rect.get_center().y - _trace[index] * rect.size.y * 0.42))
	draw_polyline(points, SPORE * Color(1, 1, 1, 0.8), 1.2)
	draw_rect(rect, INK * Color(1, 1, 1, 0.12), false, 1.0)


func _draw_disposition_cell() -> void:
	_tracked(Vector2(686, 52), "SELECT DISPOSITION", 11, SPORE * Color(1, 1, 1, 0.75), 1.8)
	draw_string(ThemeDB.fallback_font, Vector2(686 + 474, 52), "1-3  ↑↓  ENTER  ESC", HORIZONTAL_ALIGNMENT_RIGHT, 474, 10, INK * Color(1, 1, 1, 0.4))
	for index in buttons.size():
		var row := buttons[index]
		var at := row.position
		draw_string(ThemeDB.fallback_font, at + Vector2(18, 30), "%02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK * Color(1, 1, 1, 0.4))
		if index != highlighted:
			continue
		# Focus is a marked-up row, not a hover tint: a caret, a bracket pair and
		# a scan line, all of which survive on a low-contrast display.
		var accent := RED if index == 0 else ACID
		var slide := 4.0 + sin(clock * 6.0) * 2.0
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-14 - slide, 15), at + Vector2(-4 - slide, 23), at + Vector2(-14 - slide, 31),
		]), accent)
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var point := at + Vector2(row.size.x * corner.x, row.size.y * corner.y)
			var dx := -12.0 if corner.x > 0.5 else 12.0
			var dy := -10.0 if corner.y > 0.5 else 10.0
			draw_line(point, point + Vector2(dx, 0), accent, 1.6)
			draw_line(point, point + Vector2(0, dy), accent, 1.6)
		var line := at.y + fmod(clock * 40.0, row.size.y)
		draw_line(Vector2(at.x + 6, line), Vector2(at.x + row.size.x - 6, line), accent * Color(1, 1, 1, 0.16), 2.0)
	if not recruit_allowed:
		var at := buttons[2].position
		draw_line(at + Vector2(8, 8), at + Vector2(buttons[2].size.x - 8, buttons[2].size.y - 8), BILE * Color(1, 1, 1, 0.35), 1.4)
		draw_string(ThemeDB.fallback_font, at + Vector2(buttons[2].size.x - 12, 18), "REFUSED", HORIZONTAL_ALIGNMENT_RIGHT, 0, 11, BILE)
	# A voice link is an action in the scene, not a fourth disposition. The
	# subject keeps bleeding and other enemies keep moving while it is held.
	draw_string(ThemeDB.fallback_font, Vector2(686, 280), voice_state, HORIZONTAL_ALIGNMENT_LEFT, 474, 10, SCAN * Color(1, 1, 1, 0.8))
	for meter in 12:
		var height := 3.0 + voice_level * (4.0 + float((meter * 7) % 11))
		draw_rect(Rect2(946 + meter * 3.0, 306 - height, 2, height), SCAN * Color(1, 1, 1, 0.8))
	if not voice_reply.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(686, 274), "SUBJECT: “%s”" % voice_reply, HORIZONTAL_ALIGNMENT_LEFT, 474, 11, INK)


## Somebody else has been at this form before you.
func _draw_wear() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(686, 210), "— consequence —", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK * Color(1, 1, 1, 0.25))
	var jitter := Vector2(sin(clock * 1.7) * 0.6, cos(clock * 1.3) * 0.6)
	draw_arc(Vector2(250, 60) + jitter, 26.0, 0.4, 5.6, 22, BILE * Color(1, 1, 1, 0.3), 1.6)
	draw_string(ThemeDB.fallback_font, Vector2(214, 44) + jitter, "NOT MY CALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BILE * Color(1, 1, 1, 0.45))
	draw_line(Vector2(292, 300) + jitter, Vector2(470, 300) + jitter, BILE * Color(1, 1, 1, 0.25), 2.0)


func _limb(from: Vector2, to: Vector2, width: float) -> PackedVector2Array:
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	return PackedVector2Array([from + side, to + side * 0.72, to - side * 0.72, from - side])


func _disc(center: Vector2, radius_x: float, radius_y: float, segments := 18) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
