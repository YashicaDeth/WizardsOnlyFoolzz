class_name CabScreens
extends Control

## Dash screens bolted into the cab: a hull schematic showing which panels have
## gone, and a radar showing every other car and how wrecked it is. Salvaged
## CRTs on cable looms rather than a clean overlay, per ART-DIRECTION.md — the
## HUD is a product someone installed in a car, and it shows.

const CASE := Color("161310")
const CASE_EDGE := Color("5c4a34")
const SCREEN_BG := Color("0a1410")
const PHOSPHOR := Color("8fd6a0")
const AMBER := Color("e8913a")
const ALERT := Color("c8402e")
const ROT := Color("86a35c")

var hull := 100
var parts_lost: Array = []
var contacts: Array = []
var elapsed := 0.0
var radar_range := 60.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)


func set_telemetry(hull_value: int, lost: Array, contact_list: Array, range_value: float) -> void:
	hull = hull_value
	parts_lost = lost
	contacts = contact_list
	radar_range = maxf(12.0, range_value)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	var schematic := Rect2(Vector2(26.0, size.y - 232.0), Vector2(196.0, 200.0))
	var radar := Rect2(Vector2(size.x - 228.0, size.y - 232.0), Vector2(196.0, 200.0))
	_draw_unit(schematic, "HULL")
	_draw_unit(radar, "CONTACTS")
	_draw_schematic(schematic.grow(-12.0))
	_draw_radar(radar.grow(-12.0))


func _draw_unit(rect: Rect2, label: String) -> void:
	# Cable loom running off the bottom of the casing.
	var loom_from := Vector2(rect.get_center().x, rect.end.y)
	draw_polyline(PackedVector2Array([
		loom_from, loom_from + Vector2(6, 14), loom_from + Vector2(-9, 26), loom_from + Vector2(4, 34),
	]), Color("120f0c"), 4.0)
	draw_rect(rect.grow(3), Color("070605") * Color(1, 1, 1, 0.5))
	draw_rect(rect, CASE)
	draw_rect(rect, CASE_EDGE, false, 2)
	# Fixing bolts.
	for corner in [Vector2(7, 7), Vector2(rect.size.x - 7, 7), Vector2(7, rect.size.y - 7), Vector2(rect.size.x - 7, rect.size.y - 7)]:
		draw_circle(rect.position + corner, 2.0, CASE_EDGE * Color(1, 1, 1, 0.8))
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(10, rect.size.y - 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, CASE_EDGE)
	var inner := rect.grow(-12.0)
	draw_rect(inner, SCREEN_BG)
	for scan in range(0, int(inner.size.y), 3):
		draw_line(Vector2(inner.position.x, inner.position.y + scan), Vector2(inner.end.x, inner.position.y + scan), Color(0, 0, 0, 0.2), 1)
	var sweep := fmod(elapsed * 30.0, inner.size.y)
	draw_rect(Rect2(inner.position.x, inner.position.y + sweep, inner.size.x, 2), PHOSPHOR * Color(1, 1, 1, 0.08))


func _draw_schematic(rect: Rect2) -> void:
	var centre := rect.get_center() + Vector2(0, -6)
	var ratio := clampf(float(hull) / 100.0, 0.0, 1.0)
	var body := PHOSPHOR.lerp(ALERT, 1.0 - ratio)

	# Plan view of the car. Shed panels are drawn as gaps, not as labels.
	var chassis := PackedVector2Array([
		centre + Vector2(-26, -46), centre + Vector2(26, -46),
		centre + Vector2(30, 4), centre + Vector2(24, 48),
		centre + Vector2(-24, 48), centre + Vector2(-30, 4),
	])
	draw_colored_polygon(chassis, body * Color(1, 1, 1, 0.14))
	draw_polyline(chassis + PackedVector2Array([chassis[0]]), body * Color(1, 1, 1, 0.8), 1.5)

	var panels := {
		"Hood": Rect2(centre + Vector2(-20, -44), Vector2(40, 20)),
		"BumperFront": Rect2(centre + Vector2(-26, -52), Vector2(52, 7)),
		"BumperRear": Rect2(centre + Vector2(-26, 47), Vector2(52, 7)),
		"DoorLeft": Rect2(centre + Vector2(-31, -14), Vector2(9, 38)),
		"DoorRight": Rect2(centre + Vector2(22, -14), Vector2(9, 38)),
		"Wheel0": Rect2(centre + Vector2(-36, -34), Vector2(7, 16)),
	}
	for panel in panels:
		var panel_rect: Rect2 = panels[panel]
		if parts_lost.has(panel):
			# Torn away: ragged outline only.
			for spur in 4:
				var from := panel_rect.position + Vector2(panel_rect.size.x * float(spur) / 4.0, 0)
				draw_line(from, from + Vector2(3, panel_rect.size.y * 0.45), ALERT * Color(1, 1, 1, 0.55), 1)
			draw_rect(panel_rect, ALERT * Color(1, 1, 1, 0.22), false, 1)
		else:
			draw_rect(panel_rect, body * Color(1, 1, 1, 0.3))
			draw_rect(panel_rect, body * Color(1, 1, 1, 0.65), false, 1)

	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(4, 12), "%03d%%" % hull, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, body)
	if not parts_lost.is_empty():
		draw_string(font, Vector2(rect.position.x + 4, rect.end.y - 4), "-%d PANELS" % parts_lost.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ALERT)


func _draw_radar(rect: Rect2) -> void:
	var centre := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.46
	for ring in 3:
		draw_arc(centre, radius * float(ring + 1) / 3.0, 0, TAU, 30, PHOSPHOR * Color(1, 1, 1, 0.16), 1)
	draw_line(centre - Vector2(radius, 0), centre + Vector2(radius, 0), PHOSPHOR * Color(1, 1, 1, 0.12), 1)
	draw_line(centre - Vector2(0, radius), centre + Vector2(0, radius), PHOSPHOR * Color(1, 1, 1, 0.12), 1)

	var sweep_angle := fmod(elapsed * 1.7, TAU)
	draw_line(centre, centre + Vector2.from_angle(sweep_angle - PI * 0.5) * radius, PHOSPHOR * Color(1, 1, 1, 0.35), 1.5)

	for contact in contacts:
		var offset: Vector2 = contact.get("offset", Vector2.ZERO)
		var distance := offset.length()
		if distance > radar_range:
			continue
		var blip := centre + (offset / radar_range) * radius
		var health := clampf(float(contact.get("integrity", 100)) / 100.0, 0.0, 1.0)
		var tint := PHOSPHOR.lerp(ALERT, 1.0 - health)
		if bool(contact.get("rival", false)):
			tint = AMBER
			draw_arc(blip, 7.0 + sin(elapsed * 4.0) * 1.5, 0, TAU, 14, tint, 1.5)
		draw_circle(blip, 3.4, tint)
		# Integrity reads as a shrinking bar under each contact.
		draw_line(blip + Vector2(-5, 6), blip + Vector2(-5 + 10.0 * health, 6), tint * Color(1, 1, 1, 0.8), 2)

	draw_circle(centre, 3.0, ROT)
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(4, 12), "%d" % contacts.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, PHOSPHOR)
