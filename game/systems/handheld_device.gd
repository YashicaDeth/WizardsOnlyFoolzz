class_name HandheldDevice
extends Control

## The one object the interface lives inside.
##
## C1. `DESIGN/IN_GAME_INTERNET.md` opens by naming the problem this solves:
## *"The World Index (Tab), Living Map (M), Character Tree (T) and Allusions
## artwork (J) are four unrelated fullscreen panels bound to four keys. Nothing
## connects them."* Four keys, four looks, four ways of navigating, and no
## reason for any of them to know about the others.
##
## The earlier version of this file was the shell without the substance: it drew
## a convincing piece of junk hardware and then filled its screen with
## `_mode_lines()` — arrays of strings, one per mode, summarising panels that
## already existed and were far better. That is the "boxes of text" failure
## `DESIGN/INTERFACE_DIRECTION.md` now forbids outright, and it meant the device
## was a *fifth* interface rather than the replacement for the other four.
##
## So the device now **hosts the real panels**. The World Index and the Living
## Map are child controls sized into the screen aperture; the chassis draws
## under them and the damage draws over them. Nothing is summarised and nothing
## is duplicated.
##
## What the hardware adds, and why it is not just a frame:
##
## - **Raising it is a physical action and the world does not stop.** Nothing
##   here pauses the tree. You are holding a lit screen in a dark place.
## - **Condition is legible.** Dead pixels, cracks and scanlines sit *over* the
##   hosted panel, so a damaged device genuinely costs you information rather
##   than being decoration around a clean readout.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const Grunge := preload("res://systems/celloutz_grunge.gd")
const Motion := preload("res://systems/celloutz_motion.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")
const LIVING_MAP := preload("res://systems/living_map.gd")
const WIRE_RADIO := preload("res://systems/wire_radio.gd")
const CARRY := preload("res://systems/carry.gd")
const SIGNAL_FIELD := preload("res://systems/signal_field.gd")
const RADIAL := preload("res://systems/radial_menu.gd")

signal mode_changed(mode: String)
signal lead_found(station: String)

## TREE and ALLUSIONS are not gone, they are *inside* INDEX — the Tree axis is
## drawn on every dossier and the archive is a page rather than a mode. Listing
## them again here would recreate the six-panel problem inside the fix for it.
const MODES := ["INDEX", "MAP", "WIRE", "RADIO", "CARRY"]

const CASE := Color("1b1713")
const CASE_EDGE := Color("6d5a44")
const SCREEN_BG := Color("07120f")
const INK := Color("e6d4ac")
const AMBER := Color("b0552a")
const MOSS := Color("8a9a4a")
const ALERT := Color("a8281a")

var mode_index := 0
var raised := 0.0
var is_open := false
var elapsed := 0.0
var condition := 0.78
var radio: WireRadio
var carry: Carry
var signal_field: SignalField
var radial: Control

var dead_pixels: Array[Vector2] = []
var crack_lines: Array[PackedVector2Array] = []

var _clip: Control
var _overlay: Control
var _index: Control
var _map: Control
var _device_rect := Rect2()
var _screen_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	radio = WIRE_RADIO.new()
	carry = CARRY.new()
	signal_field = SIGNAL_FIELD.new()

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

	# The aperture. Children are clipped to it, which is what lets a full panel
	# be hosted inside a hole in a piece of hardware without spilling out of it.
	_clip = Control.new()
	_clip.name = "Aperture"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)

	_index = WORLD_INDEX.new()
	_index.name = "IndexPanel"
	_clip.add_child(_index)
	_map = LIVING_MAP.new()
	_map.name = "MapPanel"
	_clip.add_child(_map)

	# Added last so it draws over the hosted panels. A Control's own `_draw`
	# runs before its children, so damage could not be painted from here.
	_overlay = Control.new()
	_overlay.name = "Damage"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_damage)
	add_child(_overlay)
	# C2. The wheel lives outside the aperture: it is held in front of you, not
	# displayed on the device, so it must not be clipped by the screen.
	radial = RADIAL.new()
	radial.name = "Radial"
	add_child(radial)
	set_process(true)


## Handed the live world so the hosted panels and the radio read real state.
func bind(generator: Node, director: Node, contacts: Callable) -> void:
	if _map.has_method("bind"):
		_map.bind(generator, director, contacts)


func open_device() -> void:
	is_open = true
	visible = true
	set_mode(current_mode())


func close_device() -> void:
	is_open = false


func toggle_device() -> void:
	if is_open:
		close_device()
	else:
		open_device()


## C2. The wheel the player actually holds. The X-ray is a permanent segment
## because `xray_cursor.gd` was deliberately built as one seat of a ring that
## would grow, and this is that ring.
func open_radial() -> void:
	var wheel: Array = [
		{"id": "xray", "label": "X-RAY", "kind": "xray", "note": "see through what you are looking at"},
		{"id": "blade", "label": "BLADE", "kind": "blade", "note": "close, slow, opens people"},
		{"id": "sidearm", "label": "SIDEARM", "kind": "gun", "note": "loud, and everyone hears it"},
		{"id": "implant", "label": "IMPLANT", "kind": "implant", "note": "what is bolted into you"},
		{"id": "seal", "label": "SEAL", "kind": "seal", "note": "nothing is free"},
		{"id": "device", "label": "DEVICE", "kind": "mode", "note": "raise the handheld"},
	]
	radial.xray_on = bool(_index.get("xray")) if "xray" in _index else false
	radial.open_wheel(wheel)


func close_radial() -> void:
	radial.close_wheel()


func current_mode() -> String:
	return MODES[mode_index]


func cycle_mode(step: int) -> void:
	if not is_open:
		return
	set_mode(MODES[wrapi(mode_index + step, 0, MODES.size())])


func set_mode(mode: String) -> void:
	var found := MODES.find(mode.to_upper())
	if found < 0:
		return
	mode_index = found
	# WIRE is not a separate surface — it is the index already open on its own
	# page. Duplicating it would be the six-panel problem again in miniature.
	if current_mode() == "WIRE" and "page" in _index:
		_index.set("page", 2)
	elif current_mode() == "INDEX" and "page" in _index and int(_index.get("page")) == 2:
		_index.set("page", 0)
	# Both hosted panels gate their own drawing on an open flag, so entering a
	# mode has to open the panel as well as show it.
	if current_mode() == "MAP" and _map.has_method("open_map"):
		_map.open_map()
	if current_mode() in ["INDEX", "WIRE"] and _index.has_method("open"):
		_index.open()
	mode_changed.emit(current_mode())


## Where the character is standing. Reception, coverage and which parts of the
## Wire exist are all read off this, per C5: connectivity is a property of place.
func stand_at(world_position: Vector2) -> void:
	radio.stand_at(world_position)
	signal_field.stand_at(world_position)
	if "signal_grade" in _index:
		_index.set("signal_grade", signal_field.grade())


func _process(delta: float) -> void:
	elapsed += delta
	raised = Motion.blend(raised, delta, Motion.PANEL, is_open)
	if raised <= 0.001 and not is_open:
		visible = false
		_clip.visible = false
		return

	# The aperture is laid out here rather than in `_draw`, because the hosted
	# panels are real children and have to know their size before they render.
	var device_size := Vector2(minf(size.x * 0.88, 1140.0), minf(size.y * 0.86, 640.0))
	var resting := Vector2((size.x - device_size.x) * 0.5, size.y + 60.0)
	var lifted := Vector2((size.x - device_size.x) * 0.5, (size.y - device_size.y) * 0.5)
	_device_rect = Rect2(resting.lerp(lifted, Motion.ease_out(raised)), device_size)
	_screen_rect = Rect2(_device_rect.position + Vector2(26, 62), _device_rect.size - Vector2(52, 104))
	_clip.position = _screen_rect.position
	_clip.size = _screen_rect.size
	_clip.visible = true
	_overlay.position = Vector2.ZERO
	_overlay.size = size

	var mode := current_mode()
	var showing_index := mode == "INDEX" or mode == "WIRE"
	_index.visible = showing_index
	_map.visible = mode == "MAP"
	if showing_index:
		_index.size = _clip.size
		_index.position = Vector2.ZERO
		# The index normally owns the screen and draws its own cursor; inside the
		# device the chassis is the frame, so it is told not to chase the mouse.
		if "cursor_follows_mouse" in _index:
			_index.set("cursor_follows_mouse", false)
		if "show_cursor" in _index:
			_index.set("show_cursor", false)
	if _map.visible:
		_map.size = _clip.size
		_map.position = Vector2.ZERO

	carry.age(delta)
	if mode == "RADIO":
		var found := radio.hold(delta)
		if found != "":
			lead_found.emit(found)
	_overlay.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if raised <= 0.001:
		return
	var alpha := clampf(raised, 0.0, 1.0)
	_draw_chassis(_device_rect, alpha)
	draw_rect(_screen_rect, SCREEN_BG * Color(1, 1, 1, alpha))
	# The modes with no hosted panel draw straight onto the screen.
	var mode := current_mode()
	if mode == "RADIO":
		_draw_radio(_screen_rect, alpha)
	elif mode == "CARRY":
		_draw_carry(_screen_rect, alpha)


func _draw_chassis(rect: Rect2, alpha: float) -> void:
	draw_rect(rect.grow(5), Color("0a0806") * Color(1, 1, 1, 0.6 * alpha))
	draw_rect(rect, CASE * Color(1, 1, 1, alpha))
	draw_rect(rect, CASE_EDGE * Color(1, 1, 1, 0.8 * alpha), false, 2)
	Grunge.stain(self, rect.position + rect.size * Vector2(0.12, 0.9), 120.0, 4409, Grunge.RUST, 0.10 * alpha)
	Grunge.scratches(self, rect, 4411, 20)
	# Cable-tied battery clamped to the side, because nothing here is stock.
	var pack := Rect2(Vector2(rect.position.x + rect.size.x - 22, rect.position.y + 92), Vector2(16, rect.size.y - 180))
	draw_rect(pack, Color("241c16") * Color(1, 1, 1, alpha))
	draw_rect(pack, CASE_EDGE * Color(1, 1, 1, 0.5 * alpha), false, 1)
	for tie in 3:
		var y := pack.position.y + 22 + tie * (pack.size.y * 0.4)
		draw_line(Vector2(rect.position.x + rect.size.x - 30, y), Vector2(pack.end.x + 3, y), Color("100c0a") * Color(1, 1, 1, alpha), 3)
	CellOutzType.draw_stamped(self, rect.position + Vector2(26, 20), "CELLOUTZ", 19.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.3 * alpha), 1.6)
	CellOutzType.draw_condensed(self, rect.position + Vector2(190, 26), "FIELD WIRE MK-II // SALVAGED // NOT SERVICEABLE", 9.0, CASE_EDGE * Color(1, 1, 1, 0.8 * alpha), 0.8)
	_draw_tabs(rect, alpha)
	_draw_status(rect, alpha)


func _draw_tabs(rect: Rect2, alpha: float) -> void:
	var x := rect.position.x + 26.0
	var y := rect.position.y + rect.size.y - 34.0
	for index in MODES.size():
		var label: String = MODES[index]
		var width := CellOutzType.width(label, 11.0, 1.0) + 26.0
		var active := index == mode_index
		var tint: Color = AMBER if active else CASE_EDGE
		var shape := PackedVector2Array([
			Vector2(x, y), Vector2(x + width, y),
			Vector2(x + width - 6, y + 22), Vector2(x + 6, y + 22),
		])
		if active:
			draw_colored_polygon(shape, AMBER * Color(1, 1, 1, 0.22 * alpha))
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, tint * Color(1, 1, 1, alpha), 1.4)
		CellOutzType.draw_text(self, Vector2(x + 13, y + 6), label, 11.0, (INK if active else tint) * Color(1, 1, 1, alpha), 1.0)
		x += width + 8.0


func _draw_status(rect: Rect2, alpha: float) -> void:
	# C5. Signal first, because it is the thing that decides whether half the
	# device works, and "no signal" is useless without saying what would fix it.
	var reading: Dictionary = signal_field.reading()
	var grade := int(reading.get("grade", 0))
	var bars := clampf(float(reading.get("strength", 0.0)), 0.0, 1.0)
	var signal_tint: Color = ALERT if grade == SignalField.NONE else (MOSS if grade == SignalField.SURFACE else AMBER)
	# On the header row, not the footer: the footer is the mode rail and the
	# first placement printed the carrier name straight through the tabs.
	var strip_x := rect.position.x + rect.size.x - 330.0
	var strip_y := rect.position.y + 38.0
	for bar in 4:
		var lit := float(bar) / 4.0 < bars
		var height := 4.0 + float(bar) * 3.0
		draw_rect(Rect2(Vector2(strip_x + bar * 7.0, strip_y - height), Vector2(5, height)), (signal_tint if lit else CASE_EDGE * Color(1, 1, 1, 0.3)) * Color(1, 1, 1, alpha))
	var label := str(reading.get("source", ""))
	if grade == SignalField.UNDERBELLY:
		label += "  //  DEEP"
	elif grade == SignalField.NONE:
		var carrier: Dictionary = signal_field.nearest_carrier()
		if not carrier.is_empty():
			label = "NO CARRIER \u2014 NEAREST %s, %dM" % [str(carrier.get("name", "")), int(carrier.get("distance", 0.0))]
	CellOutzType.draw_condensed(self, Vector2(strip_x + 36.0, strip_y - 9.0), label, 9.0, signal_tint * Color(1, 1, 1, 0.85 * alpha), 0.7)

	# Named apart from the signal label above: both live in this function now and
	# GDScript will not take the same `var` twice in one scope.
	var health := clampf(condition, 0.0, 1.0)
	var tint: Color = ALERT if health < 0.35 else MOSS
	var cell_label := "CELL %02d%%" % roundi(health * 100.0)
	var cell_width := CellOutzType.width_condensed(cell_label, 10.0, 0.9)
	CellOutzType.draw_condensed(self, Vector2(rect.position.x + rect.size.x - 30 - cell_width, rect.position.y + rect.size.y - 30), cell_label, 10.0, tint * Color(1, 1, 1, alpha), 0.9)
	for cell in 8:
		var lit := float(cell) / 8.0 < health
		var bar := Rect2(Vector2(rect.position.x + rect.size.x - 150 + cell * 9.0, rect.position.y + rect.size.y - 30), Vector2(6, 11))
		draw_rect(bar, (tint if lit else CASE_EDGE * Color(1, 1, 1, 0.3)) * Color(1, 1, 1, alpha))


## C1.5. Drawn by the overlay child so it lands on top of whatever panel is
## hosted. A damaged device has to actually cost you information; damage painted
## underneath the readout is a frame, not a fault.
func _draw_damage() -> void:
	if raised <= 0.001:
		return
	var alpha := clampf(raised, 0.0, 1.0)
	var rect := _screen_rect
	var wear := 1.0 - clampf(condition, 0.0, 1.0)
	for scan in range(0, int(rect.size.y), 3):
		_overlay.draw_line(Vector2(rect.position.x, rect.position.y + scan), Vector2(rect.end.x, rect.position.y + scan), Color(0, 0, 0, 0.12 * alpha), 1.0)
	# Dead scanlines: whole rows that never light, not a shimmer.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for band in int(wear * 9.0):
		var y := rect.position.y + rng.randf() * rect.size.y
		_overlay.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0, 0, 0, 0.75 * alpha), rng.randf_range(1.0, 3.0))
	for point in dead_pixels:
		_overlay.draw_rect(Rect2(rect.position + Vector2(point.x * rect.size.x, point.y * rect.size.y), Vector2(2, 2)), Color(0, 0, 0, 0.8 * alpha))
	for line in crack_lines:
		var run := PackedVector2Array()
		for point in line:
			run.append(rect.position + Vector2(point.x * rect.size.x, point.y * rect.size.y))
		_overlay.draw_polyline(run, Color(0, 0, 0, 0.66 * alpha), 2.4)
		_overlay.draw_polyline(run, INK * Color(1, 1, 1, 0.10 * alpha), 1.0)
	# The glass itself, over everything.
	_overlay.draw_rect(rect, Color(0.55, 0.72, 0.62, 0.035 * alpha))


# --- the two modes that have no hosted panel ------------------------------

## A9.1. The dial: a real sweep with the band drawn under it, stations as ticks
## whose height is how well they are actually coming in from where you stand.
func _draw_radio(rect: Rect2, alpha: float) -> void:
	var signal_state: Dictionary = radio.transmission()
	CellOutzType.draw_stamped(self, rect.position + Vector2(24, 22), "FIELD RECEIVER", 18.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.3 * alpha), 1.4)
	var dial := Rect2(rect.position + Vector2(24, 76), Vector2(rect.size.x - 48, 76))
	draw_rect(dial, Color(0, 0, 0, 0.34 * alpha))
	draw_rect(dial, CASE_EDGE * Color(1, 1, 1, 0.5 * alpha), false, 1.0)
	# Band ticks every megahertz, taller every five.
	var span := WireRadio.BAND_HIGH - WireRadio.BAND_LOW
	var mark := WireRadio.BAND_LOW
	while mark <= WireRadio.BAND_HIGH:
		var x := dial.position.x + (mark - WireRadio.BAND_LOW) / span * dial.size.x
		var tall := fmod(mark, 5.0) < 0.01
		draw_line(Vector2(x, dial.end.y), Vector2(x, dial.end.y - (12.0 if tall else 6.0)), INK * Color(1, 1, 1, 0.25 * alpha), 1.0)
		if tall:
			CellOutzType.draw_condensed(self, Vector2(x - 9, dial.end.y + 4), "%d" % int(mark), 8.0, INK * Color(1, 1, 1, 0.35 * alpha), 0.6)
		mark += 1.0
	for station in radio.band():
		var x := dial.position.x + (float(station.khz) - WireRadio.BAND_LOW) / span * dial.size.x
		var reach := bool(station.in_reach)
		var power := float(station.strength)
		var tint: Color = MOSS if reach else CASE_EDGE
		draw_line(Vector2(x, dial.end.y - 14), Vector2(x, dial.end.y - 14 - 40.0 * maxf(power, 0.12)), tint * Color(1, 1, 1, (0.35 + power * 0.65) * alpha), 3.0)
		if power > 0.25:
			CellOutzType.draw_condensed(self, Vector2(x - 40, dial.position.y + 6), str(station.name), 8.0, tint * Color(1, 1, 1, alpha), 0.6)
	# The needle.
	var needle_x := dial.position.x + (radio.khz - WireRadio.BAND_LOW) / span * dial.size.x
	draw_line(Vector2(needle_x, dial.position.y - 6), Vector2(needle_x, dial.end.y + 2), ALERT * Color(1, 1, 1, alpha), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(needle_x, dial.position.y - 6), Vector2(needle_x + 6, dial.position.y - 14), Vector2(needle_x - 6, dial.position.y - 14),
	]), ALERT * Color(1, 1, 1, alpha))
	CellOutzType.draw_text(self, rect.position + Vector2(24, 168), "%06.2f" % radio.khz, 26.0, INK * Color(1, 1, 1, alpha), 1.4)
	# Measured off the readout rather than guessed: "088.60" at cap 26 runs to
	# about 166px and the name was starting at 150.
	var dial_width := CellOutzType.width("%06.2f" % radio.khz, 26.0, 1.4)
	CellOutzType.draw_condensed(self, rect.position + Vector2(24 + dial_width + 22, 178), str(signal_state.get("name", "CARRIER")), 11.0, MOSS * Color(1, 1, 1, alpha), 0.9)

	# What is coming out of it. Worn type, scaled by how badly it is coming in -
	# a weak signal is heard *wrongly*, not quietly.
	var clarity := float(signal_state.get("strength", 0.0))
	var body := str(signal_state.get("text", ""))
	var wrapped := _wrap(body, 62)
	var y := rect.position.y + 216.0
	for line in wrapped:
		CellOutzType.draw_worn(self, Vector2(rect.position.x + 24, y), str(line), 12.0, INK * Color(1, 1, 1, alpha), (1.0 - clarity) * 0.8, 0.9)
		y += 22.0
		if y > rect.end.y - 60.0:
			break
	# A9.3. The lock, when a hook station is being held.
	var progress: float = radio.lock_progress()
	if progress > 0.01:
		var bar := Rect2(Vector2(rect.position.x + 24, rect.end.y - 44), Vector2(rect.size.x - 48, 12))
		draw_rect(bar, INK * Color(1, 1, 1, 0.10 * alpha))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), MOSS * Color(1, 1, 1, alpha))
		CellOutzType.draw_condensed(self, Vector2(rect.position.x + 24, rect.end.y - 62), "HOLDING A LOCK", 9.0, MOSS * Color(1, 1, 1, alpha), 0.8)


## C4. The inventory that has existed in `WorldHistory` since the Hunt Grounds
## were built and has never once been on screen. Drawn as objects with a mass, a
## condition and a provenance, because B4 already produces parts that know which
## person they came off and throwing that away at the point of carrying it would
## break B5, the ritual camera and the organ trade all at once.
func _draw_carry(rect: Rect2, alpha: float) -> void:
	CellOutzType.draw_stamped(self, rect.position + Vector2(24, 22), "CARRIED", 18.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.3 * alpha), 1.4)
	var burden: float = carry.burden()
	var tone: Color = ALERT if burden > 1.0 else MOSS
	var load_text := "%0.1f / %0.0f KG" % [carry.total_mass(), Carry.CAPACITY]
	var load_width := CellOutzType.width_condensed(load_text, 12.0, 0.9)
	CellOutzType.draw_condensed(self, Vector2(rect.end.x - 26 - load_width, rect.position.y + 26), load_text, 12.0, tone * Color(1, 1, 1, alpha), 0.9)
	# The burden bar runs past its own track when overloaded, which is a clearer
	# read than clamping it and saying nothing.
	var track := Rect2(rect.position + Vector2(24, 52), Vector2(rect.size.x - 48, 8))
	draw_rect(track, INK * Color(1, 1, 1, 0.10 * alpha))
	draw_rect(Rect2(track.position, Vector2(track.size.x * minf(burden, 1.0), track.size.y)), tone * Color(1, 1, 1, alpha))
	if burden > 1.0:
		draw_rect(Rect2(track.position + Vector2(0, -3), Vector2(track.size.x * clampf(burden - 1.0, 0.0, 1.0), 3)), ALERT * Color(1, 1, 1, alpha))

	if carry.items.is_empty():
		CellOutzType.draw_condensed(self, rect.position + Vector2(24, 88), "NOTHING ON YOU WORTH LISTING.", 12.0, INK * Color(1, 1, 1, 0.4 * alpha), 0.9)
		return
	var y := rect.position.y + 86.0
	for index in carry.items.size():
		if y > rect.end.y - 30.0:
			break
		var item: Dictionary = carry.items[index]
		var fresh: float = carry.freshness(item)
		var row_tint: Color = MOSS.lerp(ALERT, 1.0 - fresh)
		# A pip coloured by condition, so the list is scannable without reading.
		draw_circle(Vector2(rect.position.x + 32, y - 4), 4.0, row_tint * Color(1, 1, 1, alpha))
		CellOutzType.draw_condensed(self, Vector2(rect.position.x + 46, y - 9), str(item.get("label", "")), 12.0, INK * Color(1, 1, 1, 0.88 * alpha), 0.9)
		var from := str(item.get("from", ""))
		if from != "":
			var origin := str(WorldHistory.subject(from).get("name", from)).to_upper()
			CellOutzType.draw_condensed(self, Vector2(rect.position.x + 46, y + 6), "OFF %s" % origin, 8.0, INK * Color(1, 1, 1, 0.32 * alpha), 0.7)
		var state: String = carry.condition_label(item)
		CellOutzType.draw_condensed(self, Vector2(rect.end.x - 190, y - 9), state, 10.0, row_tint * Color(1, 1, 1, alpha), 0.8)
		CellOutzType.draw_condensed(self, Vector2(rect.end.x - 90, y - 9), "%0.1f KG" % float(item.get("mass", 0.0)), 10.0, INK * Color(1, 1, 1, 0.55 * alpha), 0.8)
		y += 30.0


func _wrap(text: String, width: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var candidate: String = word if line == "" else line + " " + word
		if candidate.length() > width and line != "":
			out.append(line)
			line = word
		else:
			line = candidate
	if line != "":
		out.append(line)
	return out
