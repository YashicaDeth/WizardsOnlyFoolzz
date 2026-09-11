class_name LivingMap
extends Control

## The Living Map. It used to be five lines of hardcoded prose behind `M`,
## which is why it never told anyone anything. This draws the region that was
## actually generated: the real road spines, the real building footprints from
## `AshbloomWorldGenerator.lots`, the real Reality Misfire seeds, live contacts
## and the player's own heading.
##
## It is a *living* map because it is surveyed rather than given. Ground within
## sight of where the player has walked is charted and stays charted across
## sessions; everything else is hatched over and unlabelled. Walking is what
## makes the map.

const SURVEY_ID := "ashbloom_survey"
const CELL := 22.0
const SURVEY_RADIUS := 3

const VOID := Color("060b09")
const PLATE := Color("0a120e")
const INK := Color("dce6ba")
const ACID := Color("b4da48")
const SPORE := Color("9bf01a")
const ARTERIAL := Color("c81f16")
const BILE := Color("b8a12a")
const SCAN := Color("35b7a7")
const BONE := Color("ead4ad")

const DISTRICTS := [
	{"at": Vector2(-150, -122), "name": "BLACK MILE YARDS", "note": "raider highway, tolls"},
	{"at": Vector2(130, -122), "name": "SOFT ROT COMMUNION", "note": "fungal forest, shifting"},
	{"at": Vector2(-155, 0), "name": "THE BONE YARD", "note": "quarry, Ashline ground"},
	{"at": Vector2(135, 0), "name": "OSSUARY WORKS", "note": "sealed anatomy industry"},
	{"at": Vector2(65, 115), "name": "TUNNEL MOUTH", "note": "floodlit trade route"},
]
## The three road slabs `ashbloom_world_generator.gd` lays down, in plan view.
const ROADS := [
	Rect2(-9, -185, 18, 370),
	Rect2(-235, -79.5, 470, 15),
	Rect2(-118, -11, 12, 170),
]

var world_generator: Node = null
var misfire_director: Node = null
var contacts_provider: Callable = Callable()

var player_at := Vector2.ZERO
var player_yaw := 0.0
var zoom := 1.25
var pan := Vector2.ZERO
var follow := true
var dragging := false
var last_pointer := Vector2.ZERO
var clock := 0.0
var surveyed: Dictionary = {}

var _hatch: ImageTexture
var _chart := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_hatch = _build_hatch()
	visible = false
	set_process(true)
	_load_survey()


func _build_hatch() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var diagonal := absf(fposmod(float(x + y), 8.0) - 4.0) / 4.0
			var speck := sin(float(x * 57 + y * 131)) * 43758.5453
			speck -= floorf(speck)
			var value := clampf((1.0 - diagonal) * 0.55 + speck * 0.25, 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value, 0.25 + value * 0.4))
	return ImageTexture.create_from_image(image)


func bind(generator: Node, director: Node, contacts: Callable) -> void:
	world_generator = generator
	misfire_director = director
	contacts_provider = contacts


func _load_survey() -> void:
	var record: Dictionary = WorldHistory.subject(SURVEY_ID)
	surveyed.clear()
	for key in record.get("cells", []):
		surveyed[str(key)] = true


## Called every frame from the hunt loop whether the map is open or not, so the
## chart fills in while you walk rather than only while you read it.
func observe(world_position: Vector3, yaw: float) -> void:
	player_at = Vector2(world_position.x, world_position.z)
	player_yaw = yaw
	var base := Vector2i(roundi(player_at.x / CELL), roundi(player_at.y / CELL))
	var added := false
	for dx in range(-SURVEY_RADIUS, SURVEY_RADIUS + 1):
		for dy in range(-SURVEY_RADIUS, SURVEY_RADIUS + 1):
			if Vector2(dx, dy).length() > float(SURVEY_RADIUS) + 0.2:
				continue
			var key := "%d,%d" % [base.x + dx, base.y + dy]
			if not surveyed.has(key):
				surveyed[key] = true
				added = true
	if added:
		WorldHistory.update_subject(SURVEY_ID, {"cells": surveyed.keys()}, "region_surveyed")


func is_surveyed(at: Vector2) -> bool:
	return surveyed.has("%d,%d" % [roundi(at.x / CELL), roundi(at.y / CELL)])


func open_map() -> void:
	visible = true
	follow = true
	pan = Vector2.ZERO
	queue_redraw()


func close_map() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = clampf(zoom * 1.14, 0.35, 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = clampf(zoom / 1.14, 0.35, 5.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_pointer = event.position
			if event.pressed:
				follow = false
	elif event is InputEventMouseMotion and dragging:
		pan += event.position - last_pointer
		last_pointer = event.position
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		follow = true
		pan = Vector2.ZERO


func _to_screen(world: Vector2) -> Vector2:
	var origin := _chart.get_center() + pan
	var anchor := player_at if follow else Vector2.ZERO
	return origin + (world - anchor) * zoom


func _draw() -> void:
	if not visible:
		return
	var margin := 26.0
	_chart = Rect2(margin, margin + 34.0, size.x - margin * 2.0, size.y - margin * 2.0 - 74.0)

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.02, 0.93))
	draw_rect(_chart, PLATE)

	_draw_grid()
	_draw_roads()
	_draw_lots()
	# Over the plan, not under it: unwalked ground is supposed to withhold what
	# is standing on it, which it cannot do from underneath.
	_draw_unsurveyed()
	_draw_districts()
	_draw_misfires()
	_draw_contacts()
	_draw_player()
	_draw_frame()
	_draw_legend()


func _draw_grid() -> void:
	var step := CELL * zoom
	if step < 6.0:
		step *= 4.0
	var origin := _to_screen(Vector2.ZERO)
	var first_x := _chart.position.x + fposmod(origin.x - _chart.position.x, step)
	var x := first_x
	while x < _chart.end.x:
		draw_line(Vector2(x, _chart.position.y), Vector2(x, _chart.end.y), ACID * Color(1, 1, 1, 0.055), 1.0)
		x += step
	var first_y := _chart.position.y + fposmod(origin.y - _chart.position.y, step)
	var y := first_y
	while y < _chart.end.y:
		draw_line(Vector2(_chart.position.x, y), Vector2(_chart.end.x, y), ACID * Color(1, 1, 1, 0.055), 1.0)
		y += step
	# Region boundary, so the chart has an edge the world also has.
	var half := AshbloomWorldGenerator.REGION_SIZE * 0.5
	var top_left := _to_screen(-half)
	var bottom_right := _to_screen(half)
	draw_rect(Rect2(top_left, bottom_right - top_left), SPORE * Color(1, 1, 1, 0.22), false, 1.5)


## Everything the player has never been near is hatched over. This is the whole
## reason the map is worth opening twice.
func _draw_unsurveyed() -> void:
	var step := CELL * zoom
	if step < 3.0:
		return
	var half := AshbloomWorldGenerator.REGION_SIZE * 0.5
	var from := Vector2i(floori(-half.x / CELL) - 1, floori(-half.y / CELL) - 1)
	var to := Vector2i(ceili(half.x / CELL) + 1, ceili(half.y / CELL) + 1)
	for cx in range(from.x, to.x + 1):
		for cy in range(from.y, to.y + 1):
			if surveyed.has("%d,%d" % [cx, cy]):
				continue
			var at := _to_screen(Vector2(cx * CELL - CELL * 0.5, cy * CELL - CELL * 0.5))
			var cell := Rect2(at, Vector2(step, step))
			if not _chart.intersects(cell):
				continue
			var patch := cell.intersection(_chart)
			draw_rect(patch, Color(0.03, 0.045, 0.038, 0.82))
			draw_texture_rect(_hatch, patch, true, Color(0.35, 0.42, 0.28, 0.22))


func _draw_roads() -> void:
	for road in ROADS:
		var top_left := _to_screen(road.position)
		var bottom_right := _to_screen(road.end)
		var strip := Rect2(top_left, bottom_right - top_left)
		if not _chart.intersects(strip):
			continue
		draw_rect(strip.intersection(_chart), Color(0.16, 0.15, 0.12, 0.9))
		draw_rect(strip.intersection(_chart), BILE * Color(1, 1, 1, 0.18), false, 1.0)


func _draw_lots() -> void:
	if world_generator == null or not is_instance_valid(world_generator):
		return
	var lots: Array = world_generator.get("lots")
	if lots == null:
		return
	for lot in lots:
		var rect := lot as Rect2
		var top_left := _to_screen(rect.position)
		var bottom_right := _to_screen(rect.end)
		var plan := Rect2(top_left, bottom_right - top_left)
		if not _chart.intersects(plan):
			continue
		var charted := is_surveyed(rect.get_center())
		var tint := BONE if charted else INK
		draw_rect(plan, tint * Color(1, 1, 1, 0.16 if charted else 0.05))
		draw_rect(plan, tint * Color(1, 1, 1, 0.6 if charted else 0.14), false, 1.0)


func _draw_districts() -> void:
	for district in DISTRICTS:
		var at: Vector2 = district.at
		var screen := _to_screen(at)
		var charted := is_surveyed(at)
		var radius := 58.0 * zoom
		var tint := SPORE if charted else INK
		draw_arc(screen, radius, 0.0, TAU, 40, tint * Color(1, 1, 1, 0.2 if charted else 0.08), 1.0)
		if not _chart.has_point(screen):
			continue
		if not charted and not _chart.has_point(screen):
			continue
		var label := str(district.name) if charted else "UNSURVEYED SECTOR"
		draw_string(ThemeDB.fallback_font, screen + Vector2(-radius * 0.5, -radius - 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint * Color(1, 1, 1, 0.9 if charted else 0.3))
		if charted:
			draw_string(ThemeDB.fallback_font, screen + Vector2(-radius * 0.5, -radius + 5.0), str(district.note).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK * Color(1, 1, 1, 0.4))


func _draw_misfires() -> void:
	if misfire_director == null or not is_instance_valid(misfire_director):
		return
	var seeds: Array = misfire_director.get("seeded_encounters")
	if seeds == null:
		return
	for encounter in seeds:
		var world: Vector3 = encounter.get("position", Vector3.ZERO)
		var at := Vector2(world.x, world.z)
		var screen := _to_screen(at)
		if not _chart.has_point(screen):
			continue
		var record: Dictionary = WorldHistory.subject("misfire:" + str(encounter.get("instance_id", "")))
		var status := str(record.get("status", ""))
		if status.is_empty() and not is_surveyed(at):
			continue
		var known := not status.is_empty()
		var tint := ARTERIAL if str(encounter.get("kind", "")) in ["hostile", "boss"] else SCAN
		var pulse := 0.5 + 0.5 * sin(clock * 2.6)
		if status == "resolved":
			tint = INK * Color(1, 1, 1, 0.4)
		draw_arc(screen, 7.0 + (pulse * 3.0 if known and status != "resolved" else 0.0), 0.0, TAU, 16, tint, 1.4)
		draw_line(screen - Vector2(3, 0), screen + Vector2(3, 0), tint, 1.0)
		draw_line(screen - Vector2(0, 3), screen + Vector2(0, 3), tint, 1.0)
		if not known:
			draw_string(ThemeDB.fallback_font, screen + Vector2(-3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint * Color(1, 1, 1, 0.6))
			continue
		draw_string(ThemeDB.fallback_font, screen + Vector2(11, 4), str(encounter.get("title", "?")), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tint * Color(1, 1, 1, 0.85))


func _draw_contacts() -> void:
	if not contacts_provider.is_valid():
		return
	for contact in contacts_provider.call():
		var at: Vector2 = contact.get("at", Vector2.ZERO)
		var screen := _to_screen(at)
		if not _chart.has_point(screen):
			continue
		var state := str(contact.get("state", "hostile"))
		var tint := ARTERIAL
		match state:
			"ally", "recruited": tint = SPORE
			"neutral", "spared": tint = BILE
			"downed": tint = BILE
			"loot": tint = BONE
		if state == "loot":
			draw_rect(Rect2(screen - Vector2(3, 3), Vector2(6, 6)), tint * Color(1, 1, 1, 0.8))
			continue
		var beat := 0.5 + 0.5 * sin(clock * 4.0)
		draw_circle(screen, 4.0, tint)
		draw_arc(screen, 8.0 + beat * 4.0, 0.0, TAU, 14, tint * Color(1, 1, 1, 0.4 - beat * 0.2), 1.0)
		if state == "downed":
			draw_line(screen - Vector2(6, 6), screen + Vector2(6, 6), tint, 1.2)
			draw_line(screen + Vector2(6, -6), screen + Vector2(-6, 6), tint, 1.2)
		var label := str(contact.get("name", ""))
		if not label.is_empty():
			draw_string(ThemeDB.fallback_font, screen + Vector2(9, -6), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tint * Color(1, 1, 1, 0.9))


func _draw_player() -> void:
	var screen := _to_screen(player_at)
	if not _chart.has_point(screen):
		return
	# A facing cone, because a dot on a map cannot tell you which way you are
	# pointed and that is the one thing you open a map to find out.
	var heading := Vector2(sin(player_yaw), cos(player_yaw))
	var side := Vector2(-heading.y, heading.x)
	draw_colored_polygon(PackedVector2Array([
		screen + heading * 46.0 + side * 20.0,
		screen,
		screen + heading * 46.0 - side * 20.0,
	]), SPORE * Color(1, 1, 1, 0.12))
	draw_colored_polygon(PackedVector2Array([
		screen + heading * 11.0,
		screen - heading * 6.0 + side * 6.0,
		screen - heading * 6.0 - side * 6.0,
	]), SPORE)
	draw_arc(screen, 13.0 + sin(clock * 3.0) * 2.0, 0.0, TAU, 20, SPORE * Color(1, 1, 1, 0.5), 1.0)


func _draw_frame() -> void:
	draw_rect(_chart, ACID * Color(1, 1, 1, 0.4), false, 1.4)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := _chart.position + _chart.size * corner
		var dx := -18.0 if corner.x > 0.5 else 18.0
		var dy := -14.0 if corner.y > 0.5 else 14.0
		draw_line(at, at + Vector2(dx, 0), ACID, 2.0)
		draw_line(at, at + Vector2(0, dy), ACID, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(26, 26), "LIVING MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACID)
	draw_string(font, Vector2(150, 26), "LIMBO / THE ASHBLOOM EXPANSE   SHEET 01 OF 01   CELLOUTZ SURVEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK * Color(1, 1, 1, 0.55))
	var charted := float(surveyed.size()) * CELL * CELL
	var total := AshbloomWorldGenerator.REGION_SIZE.x * AshbloomWorldGenerator.REGION_SIZE.y
	draw_string(font, Vector2(size.x - 330, 26), "SURVEYED %05.1f%%   E %+06.1f  N %+06.1f" % [clampf(charted / total, 0.0, 1.0) * 100.0, player_at.x, -player_at.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SPORE)


func _draw_legend() -> void:
	var font := ThemeDB.fallback_font
	var base := Vector2(26, size.y - 34)
	draw_line(base + Vector2(0, -14), base + Vector2(size.x - 52, -14), INK * Color(1, 1, 1, 0.15), 1.0)
	# Scale bar measured off the real zoom, so distances on the chart mean metres.
	var bar := 50.0 * zoom
	draw_line(base, base + Vector2(bar, 0), INK, 2.0)
	draw_line(base, base + Vector2(0, -5), INK, 2.0)
	draw_line(base + Vector2(bar, 0), base + Vector2(bar, -5), INK, 2.0)
	draw_string(font, base + Vector2(bar + 8, 4), "50 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.7))
	var entries := [
		["YOU", SPORE], ["HOSTILE", ARTERIAL], ["DOWNED", BILE],
		["ALLY", SPORE], ["CACHE", BONE], ["SIGNAL", SCAN], ["UNSURVEYED", INK * Color(1, 1, 1, 0.35)],
	]
	var cursor := base.x + bar + 70.0
	for entry in entries:
		draw_circle(Vector2(cursor, base.y - 4), 4.0, entry[1])
		draw_string(font, Vector2(cursor + 9, base.y), str(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK * Color(1, 1, 1, 0.6))
		cursor += 30.0 + font.get_string_size(str(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(size.x - 300, size.y - 30), "DRAG PAN   WHEEL ZOOM   F RECENTRE   M CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ACID * Color(1, 1, 1, 0.6))
