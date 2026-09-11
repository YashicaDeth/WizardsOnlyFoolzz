class_name HandheldDevice
extends Control

## The Wire: a salvaged handheld that houses the Index, Map, Tree, internet and
## inventory as modes on one object, replacing four unrelated fullscreen panels
## bound to four keys.
##
## It does not pause the world. Raising it is a physical act with a cost: the
## player is holding a lit screen in a dark wasteland, and being attacked while
## reading it is supposed to be a real risk.
##
## Specified in DESIGN/IN_GAME_INTERNET.md.

signal mode_changed(mode: String)

const MODES := ["INDEX", "MAP", "TREE", "WIRE", "CARRY"]

const CASE := Color("1b1713")
const CASE_EDGE := Color("6d5a44")
const SCREEN_BG := Color("07120f")
const SCREEN_TEXT := Color("9ad8b4")
const AMBER := Color("e8913a")
const SIGNAL_TEAL := Color("35b7a7")
const ALERT := Color("c8402e")

var mode_index := 0
var raised := 0.0
var is_open := false
var elapsed := 0.0
var scroll := 0.0
var dead_pixels: Array[Vector2] = []
var crack_lines: Array[PackedVector2Array] = []
var condition := 0.78


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Damage is fixed per device, not per frame: the same dead pixels and the
	# same cracks every time you raise it, the way a real broken screen behaves.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for index in 14:
		dead_pixels.append(Vector2(rng.randf(), rng.randf()))
	for index in 3:
		var start := Vector2(rng.randf(), rng.randf())
		var line := PackedVector2Array([start])
		var cursor := start
		for segment in 4:
			cursor += Vector2(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.2, 0.2))
			line.append(cursor)
		crack_lines.append(line)
	set_process(true)


func open_device() -> void:
	is_open = true
	visible = true
	emit_signal("mode_changed", current_mode())


func close_device() -> void:
	is_open = false


func toggle_device() -> void:
	if is_open:
		close_device()
	else:
		open_device()


func current_mode() -> String:
	return MODES[mode_index]


func cycle_mode(step: int) -> void:
	if not is_open:
		return
	mode_index = wrapi(mode_index + step, 0, MODES.size())
	scroll = 0.0
	emit_signal("mode_changed", current_mode())


func set_mode(mode: String) -> void:
	var found := MODES.find(mode.to_upper())
	if found >= 0:
		mode_index = found
		scroll = 0.0
		emit_signal("mode_changed", current_mode())


func _process(delta: float) -> void:
	elapsed += delta
	var target := 1.0 if is_open else 0.0
	raised = move_toward(raised, target, delta * 4.2)
	if raised <= 0.001 and not is_open:
		visible = false
		return
	queue_redraw()


func _draw() -> void:
	if raised <= 0.001:
		return
	# Slides up from the lower edge as the character brings it to eye level.
	var device_size := Vector2(minf(size.x * 0.46, 560.0), minf(size.y * 0.66, 520.0))
	var resting := Vector2(size.x - device_size.x - 46.0, size.y + 40.0)
	var lifted := Vector2(size.x - device_size.x - 46.0, size.y - device_size.y - 40.0)
	var origin := resting.lerp(lifted, ease(raised, 0.38))
	var device_rect := Rect2(origin, device_size)
	var alpha := clampf(raised, 0.0, 1.0)

	_draw_chassis(device_rect, alpha)
	var screen_rect := Rect2(device_rect.position + Vector2(18, 46), device_rect.size - Vector2(36, 92))
	_draw_screen(screen_rect, alpha)
	_draw_tabs(device_rect, screen_rect, alpha)
	_draw_status_strip(device_rect, screen_rect, alpha)


func _draw_chassis(rect: Rect2, alpha: float) -> void:
	draw_rect(rect.grow(4), Color("0a0806") * Color(1, 1, 1, 0.55 * alpha))
	draw_rect(rect, CASE * Color(1, 1, 1, alpha))
	draw_rect(rect, CASE_EDGE * Color(1, 1, 1, 0.8 * alpha), false, 2)
	# Cable-tied battery pack clamped to the side, because nothing here is stock.
	var pack := Rect2(rect.position + Vector2(rect.size.x - 26, 62), Vector2(18, 74))
	draw_rect(pack, Color("241c16") * Color(1, 1, 1, alpha))
	draw_rect(pack, CASE_EDGE * Color(1, 1, 1, 0.5 * alpha), false, 1)
	for tie in 2:
		var y := pack.position.y + 16 + tie * 40
		draw_line(Vector2(rect.position.x + rect.size.x - 32, y), Vector2(pack.end.x + 3, y), Color("100c0a") * Color(1, 1, 1, alpha), 3)
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(18, 28), "CELLOUTZ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AMBER * Color(1, 1, 1, alpha))
	draw_string(font, rect.position + Vector2(108, 28), "FIELD WIRE  MK-II  //  SALVAGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CASE_EDGE * Color(1, 1, 1, 0.75 * alpha))


func _draw_screen(rect: Rect2, alpha: float) -> void:
	draw_rect(rect, SCREEN_BG * Color(1, 1, 1, alpha))
	draw_rect(rect, SIGNAL_TEAL * Color(1, 1, 1, 0.35 * alpha), false, 1)
	var font := ThemeDB.fallback_font

	var lines := _mode_lines()
	var line_height := 15.0
	var top := rect.position.y + 20.0
	for index in lines.size():
		var y := top + index * line_height
		if y > rect.end.y - 8.0:
			break
		var entry: Dictionary = lines[index]
		var tint: Color = entry.get("color", SCREEN_TEXT)
		draw_string(font, Vector2(rect.position.x + 12, y), str(entry.text), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24, int(entry.get("size", 10)), tint * Color(1, 1, 1, alpha))

	# Scanlines, then a slow refresh sweep, then the permanent damage.
	for scan in range(0, int(rect.size.y), 3):
		draw_line(Vector2(rect.position.x, rect.position.y + scan), Vector2(rect.end.x, rect.position.y + scan), Color(0, 0, 0, 0.16 * alpha), 1)
	var sweep := fmod(elapsed * 42.0, rect.size.y)
	draw_rect(Rect2(rect.position.x, rect.position.y + sweep, rect.size.x, 2), SIGNAL_TEAL * Color(1, 1, 1, 0.1 * alpha))
	for pixel in dead_pixels:
		draw_rect(Rect2(rect.position + pixel * rect.size, Vector2(2, 2)), Color(0, 0, 0, 0.85 * alpha))
	for line in crack_lines:
		var points := PackedVector2Array()
		for point in line:
			points.append(rect.position + point * rect.size)
		draw_polyline(points, Color(0.85, 0.92, 0.9, 0.1 * alpha), 1.0)


func _draw_tabs(device_rect: Rect2, screen_rect: Rect2, alpha: float) -> void:
	var font := ThemeDB.fallback_font
	var tab_width := screen_rect.size.x / float(MODES.size())
	var y := screen_rect.end.y + 6.0
	for index in MODES.size():
		var tab := Rect2(screen_rect.position.x + index * tab_width, y, tab_width - 3.0, 22.0)
		var active := index == mode_index
		draw_rect(tab, (AMBER if active else Color("2a2118")) * Color(1, 1, 1, (0.85 if active else 0.7) * alpha))
		draw_string(font, tab.position + Vector2(6, 15), MODES[index], HORIZONTAL_ALIGNMENT_LEFT, tab.size.x - 8, 8, (Color.BLACK if active else CASE_EDGE) * Color(1, 1, 1, alpha))


func _draw_status_strip(device_rect: Rect2, screen_rect: Rect2, alpha: float) -> void:
	var font := ThemeDB.fallback_font
	var y := device_rect.end.y - 12.0
	# Condition drives the readout, so a damaged device advertises its own decay.
	var battery := 0.35 + 0.45 * condition
	for cell in 5:
		var filled := float(cell) / 5.0 < battery
		var cell_rect := Rect2(device_rect.position.x + 18 + cell * 11, y - 9, 8, 9)
		draw_rect(cell_rect, (AMBER if filled else Color("2a2118")) * Color(1, 1, 1, alpha))
	var bars := int(round(condition * 4.0))
	for bar in 4:
		var height := 3.0 + bar * 3.0
		var bar_color := SIGNAL_TEAL if bar < bars else Color("2a2118")
		draw_rect(Rect2(device_rect.position.x + 88 + bar * 7, y - height, 5, height), bar_color * Color(1, 1, 1, alpha))
	draw_string(font, Vector2(device_rect.position.x + 128, y), "SIGNAL // ASHBLOOM RELAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CASE_EDGE * Color(1, 1, 1, 0.8 * alpha))
	draw_string(font, Vector2(device_rect.end.x - 96, y), "[TAB] MODE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CASE_EDGE * Color(1, 1, 1, 0.6 * alpha))


func _mode_lines() -> Array:
	match current_mode():
		"MAP":
			return _map_lines()
		"TREE":
			return _tree_lines()
		"WIRE":
			return _wire_lines()
		"CARRY":
			return _carry_lines()
		_:
			return _index_lines()


func _index_lines() -> Array:
	var lines: Array = [{"text": "WORLD INDEX", "color": AMBER, "size": 12}, {"text": "", "size": 6}]
	var subjects := WorldHistory.all_subjects()
	var shown := 0
	for subject_id in subjects:
		var subject: Dictionary = subjects[subject_id]
		if str(subject.get("kind", "")) != "person":
			continue
		lines.append({"text": "%s  //  %s" % [str(subject.get("name", subject_id)).to_upper(), str(subject.get("status", "unknown"))], "size": 10})
		var wounds: Array = subject.get("wounds", [])
		if not wounds.is_empty():
			lines.append({"text": "   %s" % ", ".join(PackedStringArray(wounds)), "color": ALERT, "size": 8})
		shown += 1
		if shown >= 8:
			break
	if shown == 0:
		lines.append({"text": "No indexed subjects.", "size": 10})
	return lines


func _map_lines() -> Array:
	return [
		{"text": "LIVING MAP", "color": AMBER, "size": 12}, {"text": "", "size": 6},
		{"text": "LIMBO // THE ASHBLOOM EXPANSE", "color": SIGNAL_TEAL, "size": 10}, {"text": "", "size": 4},
		{"text": "[BONE YARD]  rusted quarry / Ashline ground", "size": 9},
		{"text": "[BLACK MILE]  raider highway past the pylons", "size": 9},
		{"text": "[SOFT ROT]  fungal forest, shifting paths", "size": 9},
		{"text": "[OSSUARY]  sealed anatomy works below the ridge", "size": 9},
		{"text": "[TUNNEL]  floodlit trade route under the quarry", "size": 9},
		{"text": "", "size": 6},
		{"text": "Coverage follows relays. No signal underground.", "color": CASE_EDGE, "size": 8},
	]


func _tree_lines() -> Array:
	var lines: Array = [{"text": "CHARACTER TREE // AS ABOVE, SO BELOW", "color": AMBER, "size": 11}, {"text": "", "size": 6}]
	var subjects := WorldHistory.all_subjects()
	for subject_id in subjects:
		var subject: Dictionary = subjects[subject_id]
		if str(subject.get("kind", "")) != "person":
			continue
		var axis := WorldHistory.tree_alignment(subject)
		var label := WorldHistory.tree_axis_label(axis)
		var principle := WorldHistory.tree_descriptor(subject)
		var tint := SIGNAL_TEAL if label == "ASCENT" else (ALERT if label == "DESCENT" else SCREEN_TEXT)
		var suffix := " (%s)" % principle if not principle.is_empty() else ""
		lines.append({"text": "%-16s %s%s" % [str(subject.get("name", subject_id)).to_upper(), label, suffix], "color": tint, "size": 9})
		if lines.size() > 14:
			break
	return lines


## Clout is the world's unreliable estimate of influence, derived from what the
## Wire has actually reported about a subject rather than stored as a stat.
func _wire_lines() -> Array:
	var lines: Array = [{"text": "THE WIRE", "color": AMBER, "size": 12}, {"text": "", "size": 6}]
	var subjects := WorldHistory.all_subjects()
	for subject_id in subjects:
		var subject: Dictionary = subjects[subject_id]
		if str(subject.get("kind", "")) != "person":
			continue
		var elo := int(subject.get("elo", 1000))
		var grudge := int(subject.get("grudge", 0))
		var clout := maxi(0, (elo - 900) * 7 + grudge * 23)
		var reachable := clout < 2600
		lines.append({
			"text": "@%s  %s likes" % [str(subject.get("name", subject_id)).to_lower().replace(" ", "_"), _compact(clout)],
			"color": SCREEN_TEXT if reachable else CASE_EDGE, "size": 9,
		})
		lines.append({
			"text": "   %s" % ("open to contact" if reachable else "does not answer mentions or DMs"),
			"color": SIGNAL_TEAL if reachable else ALERT, "size": 8,
		})
		if lines.size() > 14:
			break
	lines.append({"text": "", "size": 6})
	var recent := WorldHistory.recent_events(3)
	for event in recent:
		lines.append({"text": "// %s" % str(event.get("type", "")).replace("_", " "), "color": CASE_EDGE, "size": 8})
	return lines


func _carry_lines() -> Array:
	var lines: Array = [{"text": "CARRY", "color": AMBER, "size": 12}, {"text": "", "size": 6}]
	var items: Array = WorldHistory.subject("inventory").get("items", [])
	if items.is_empty():
		lines.append({"text": "Nothing but the clothes and the debt.", "color": CASE_EDGE, "size": 9})
		return lines
	var counts := {}
	for item in items:
		counts[item] = int(counts.get(item, 0)) + 1
	for item in counts:
		lines.append({"text": "%-28s x%d" % [str(item).to_upper(), int(counts[item])], "size": 9})
	return lines


func _compact(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fk" % (float(value) / 1000.0)
	return str(value)
