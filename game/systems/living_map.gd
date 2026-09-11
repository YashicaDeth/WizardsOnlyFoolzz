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

const Grunge := preload("res://systems/celloutz_grunge.gd")
const Motion := preload("res://systems/celloutz_motion.gd")

const SURVEY_ID := "ashbloom_survey"
const CELL := 22.0
const SURVEY_RADIUS := 3

const VOID := Color("0a0806")
const PLATE := Color("100c09")
const INK := Color("e6d4ac")
const ACID := Color("b0552a")
const SPORE := Color("7f9440")
const ARTERIAL := Color("a8281a")
const BILE := Color("9a8c3f")
const SCAN := Color("8a9a4a")
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
## A6.2/A6.3. Discovered places, the one under the cursor, and where travel is
## being committed to.
var _place_rects: Array = []
var hovered_place := -1
var selected_place := -1
var travel_hold := 0.0
signal travel_requested(place: Dictionary)


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


func _handle_travel(delta: float) -> void:
	if selected_place < 0:
		travel_hold = 0.0
		return
	var district: Dictionary = DISTRICTS[selected_place]
	if not is_surveyed(district.get("at", Vector2.ZERO)):
		travel_hold = 0.0
		return
	if Input.is_key_pressed(KEY_T):
		travel_hold = minf(1.0, travel_hold + delta * 0.85)
		if travel_hold >= 1.0:
			travel_requested.emit(district)
			WorldHistory.record_event("map_travel", {"subject": "player", "place": str(district.get("name", ""))})
			travel_hold = 0.0
	else:
		travel_hold = maxf(0.0, travel_hold - delta * 2.2)


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	_handle_travel(delta)
	queue_redraw()


## Hover and selection for the place markers. Runs before the pan handling so
## clicking a marker does not also start dragging the chart.
func _place_under(point: Vector2) -> int:
	for entry in _place_rects:
		if (entry["rect"] as Rect2).has_point(point):
			return int(entry["index"])
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_place = _place_under(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var found := _place_under(event.position)
		if found >= 0:
			selected_place = -1 if found == selected_place else found
			travel_hold = 0.0
			queue_redraw()
			return
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

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.026, 0.019, 0.94))
	draw_rect(_chart, PLATE)
	# A6.1. Grime under the plan, so the chart reads as printed on something.
	Grunge.stain(self, _chart.position + _chart.size * Vector2(0.22, 0.74), 150.0, 611, Grunge.BILE, 0.05)
	Grunge.stain(self, _chart.position + _chart.size * Vector2(0.78, 0.24), 170.0, 617, Grunge.RUST, 0.045)

	# A6.5. Past a zoom threshold the plan lies back, so close inspection reads
	# as leaning over a table rather than as a bigger flat chart. An affine
	# transform cannot do true perspective, so this is a squash about a low
	# horizon plus a fade at the far edge - which is what sells the tilt.
	var tilt := clampf((zoom - 1.6) / 1.4, 0.0, 1.0)
	if tilt > 0.0:
		var horizon := _chart.position.y + _chart.size.y * 0.62
		var squash := lerpf(1.0, 0.60, tilt)
		draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(0.0, squash), Vector2(0.0, horizon * (1.0 - squash))))

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
	_draw_places()
	if tilt > 0.0:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# The far edge falls away into haze, which an affine squash cannot do on
		# its own and which is most of what makes a tilt legible.
		var haze := _chart.size.y * 0.22 * tilt
		var steps := 14
		for band in steps:
			var travel := float(band) / float(steps)
			draw_rect(Rect2(_chart.position + Vector2(0, haze * travel), Vector2(_chart.size.x, haze / float(steps) + 1.0)), VOID * Color(1, 1, 1, (1.0 - travel) * 0.72 * tilt))
	_draw_frame()
	_draw_bezel()
	_draw_legend()
	if selected_place >= 0:
		_draw_place_panel()
	_draw_cracks()


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
	CellOutzType.draw_stamped(self, Vector2(26, 10), "LIVING MAP", 20.0, ACID, ARTERIAL * Color(1, 1, 1, 0.25), 3.4)
	# Measured off the title rather than guessed at 150px, which printed the
	# sheet line straight through the stamp.
	var title_end := 26.0 + CellOutzType.width("LIVING MAP", 20.0, 3.4) + 24.0
	draw_string(font, Vector2(title_end, 28), "LIMBO / THE ASHBLOOM EXPANSE   SHEET 01 OF 01   CELLOUTZ SURVEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK * Color(1, 1, 1, 0.55))
	var charted := float(surveyed.size()) * CELL * CELL
	var total := AshbloomWorldGenerator.REGION_SIZE.x * AshbloomWorldGenerator.REGION_SIZE.y
	draw_string(font, Vector2(size.x - 330, 26), "SURVEYED %05.1f%%   E %+06.1f  N %+06.1f" % [clampf(charted / total, 0.0, 1.0) * 100.0, player_at.x, -player_at.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SPORE)


## A6.1. A salvaged bezel: rolled plate, pipe runs down two edges, and fixings
## at the corners. `ART-DIRECTION.md` asks for the interface to be a made object
## and the map was the clearest remaining case of a chart floating on black.
func _draw_bezel() -> void:
	var outer := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	var inner := _chart.grow(10.0)
	# The bezel face, drawn as the ring between the two rectangles.
	var face := PackedVector2Array([
		outer.position, outer.position + Vector2(outer.size.x, 0), outer.position + outer.size, outer.position + Vector2(0, outer.size.y),
	])
	draw_colored_polygon(face, Color(0.09, 0.07, 0.055, 0.0))
	for band in [outer, inner]:
		draw_rect(band, ACID * Color(1, 1, 1, 0.35), false, 2.0)
	# Pipe runs, because a salvaged housing has things bolted to the outside.
	for pipe_x in [outer.position.x + 4.0, outer.position.x + outer.size.x - 4.0]:
		draw_line(Vector2(pipe_x, outer.position.y + 30), Vector2(pipe_x, outer.position.y + outer.size.y - 30), Color(0.16, 0.12, 0.09), 7.0)
		draw_line(Vector2(pipe_x - 2, outer.position.y + 30), Vector2(pipe_x - 2, outer.position.y + outer.size.y - 30), INK * Color(1, 1, 1, 0.10), 1.0)
		for clamp_y in range(int(outer.position.y) + 60, int(outer.position.y + outer.size.y) - 40, 90):
			draw_rect(Rect2(Vector2(pipe_x - 6, float(clamp_y)), Vector2(12, 7)), Color(0.22, 0.17, 0.12))
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := inner.position + inner.size * corner
		var inset := Vector2(12.0 if corner.x < 0.5 else -12.0, 12.0 if corner.y < 0.5 else -12.0)
		draw_circle(at + inset, 4.0, Color(0.10, 0.08, 0.06))
		draw_arc(at + inset, 4.0, 0, TAU, 12, INK * Color(1, 1, 1, 0.28), 1.0)
		draw_line(at + inset + Vector2(-2.6, -2.6), at + inset + Vector2(2.6, 2.6), INK * Color(1, 1, 1, 0.30), 1.0)


## A6.4. The screen is cracked and the cracks eat the chart. Fixed pattern, so
## it is damage rather than an effect - and it occludes, which is the point:
## the map withholds ground for a second reason beyond not having walked it.
func _draw_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8821
	for strike in 2:
		var origin := _chart.position + Vector2(rng.randf() * _chart.size.x, rng.randf() * _chart.size.y)
		for branch in rng.randi_range(3, 5):
			var heading := rng.randf() * TAU
			var point := origin
			var run := PackedVector2Array([point])
			for step in rng.randi_range(4, 9):
				heading += rng.randf_range(-0.5, 0.5)
				point += Vector2(cos(heading), sin(heading)) * rng.randf_range(16.0, 54.0)
				run.append(point)
			draw_polyline(run, Color(0, 0, 0, 0.55), rng.randf_range(1.4, 2.6))
			draw_polyline(run, INK * Color(1, 1, 1, 0.10), 1.0)


## A6.2. Named places, drawn from the districts the generator already produces,
## as things you point at rather than labels lying on the plan.
func _draw_places() -> void:
	_place_rects.clear()
	for index in DISTRICTS.size():
		var district: Dictionary = DISTRICTS[index]
		var world_at: Vector2 = district.get("at", Vector2.ZERO)
		var screen := _to_screen(world_at)
		if not _chart.has_point(screen):
			continue
		var charted := is_surveyed(world_at)
		var box := Rect2(screen - Vector2(9, 9), Vector2(18, 18))
		_place_rects.append({"index": index, "rect": box, "at": world_at})
		var tint: Color = SPORE if charted else INK * Color(1, 1, 1, 0.3)
		if index == selected_place:
			tint = ACID
		var mark := PackedVector2Array([
			screen + Vector2(0, -7), screen + Vector2(7, 0), screen + Vector2(0, 7), screen + Vector2(-7, 0), screen + Vector2(0, -7),
		])
		draw_polyline(mark, tint, 1.6)
		if index == hovered_place or index == selected_place:
			draw_arc(screen, 13.0 + sin(clock * 3.0) * 1.5, 0, TAU, 24, tint * Color(1, 1, 1, 0.6), 1.2)


## A6.3. Travel, as a commitment rather than a click. Holding is deliberate: a
## map that teleports you the instant you brush a marker is a fast-travel menu,
## and this world is supposed to make you go places.
func _draw_place_panel() -> void:
	var district: Dictionary = DISTRICTS[selected_place]
	var panel := Rect2(Vector2(size.x - 336, _chart.position.y + 16), Vector2(300, 150))
	draw_colored_polygon(PackedVector2Array([
		panel.position + Vector2(14, 0), panel.position + Vector2(panel.size.x, 0),
		panel.position + panel.size - Vector2(0, 14), panel.position + panel.size - Vector2(14, 0),
		panel.position + Vector2(0, panel.size.y), panel.position + Vector2(0, 14),
	]), Color(0.05, 0.04, 0.03, 0.95))
	draw_rect(panel, ACID * Color(1, 1, 1, 0.45), false, 1.4)
	var font := ThemeDB.fallback_font
	CellOutzType.draw_stamped(self, panel.position + Vector2(14, 14), str(district.get("name", "UNNAMED")).to_upper(), 16.0, INK, ARTERIAL * Color(1, 1, 1, 0.3), 1.2)
	draw_string(font, panel.position + Vector2(16, 54), str(district.get("note", "")), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 32, 11, INK * Color(1, 1, 1, 0.7))
	var charted := is_surveyed(district.get("at", Vector2.ZERO))
	var status := "SURVEYED" if charted else "UNWALKED \u2014 NO ROUTE"
	CellOutzType.draw_text(self, panel.position + Vector2(14, 82), status, 10.0, SPORE if charted else ARTERIAL, 1.0)
	if charted:
		var bar := Rect2(panel.position + Vector2(14, 106), Vector2(panel.size.x - 28, 14))
		draw_rect(bar, INK * Color(1, 1, 1, 0.10))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(travel_hold, 0.0, 1.0), bar.size.y)), ACID)
		draw_rect(bar, INK * Color(1, 1, 1, 0.22), false, 1.0)
		CellOutzType.draw_text(self, panel.position + Vector2(14, 126), "HOLD T TO TRAVEL", 9.0, INK * Color(1, 1, 1, 0.6), 1.0)


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
