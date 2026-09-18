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
const PlayerActionLedger := preload("res://systems/player_action_ledger.gd")
const SATELLITE := preload("res://systems/satellite_view.gd")
const FACILITY := preload("res://systems/facility_territory.gd")
const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")

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

const DISTRICTS := HOLDINGS.DEFINITIONS
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

## A10. The region seen from above, rendered from the world the player is
## actually standing in. Null until a scene hands one over — the map still works
## without it and simply draws its chart on a dark plate, which is what every
## test and every scene with no 3D world gets.
var satellite: SubViewport = null
## Underground dead zones keep the remembered chart but deny every live orbital
## affordance: image, minimap, player fix and corporate acquisition ping.
var satellite_available := true
var satellite_block_reason := ""
## 0 = high above, looking down. 1 = standing in the street. Driven by the same
## zoom the chart already had, so there is one control rather than two.
var descent := 0.0
## Counts down to the next satellite render. See `_draw`.
var _satellite_due := 0.0
var _minimap_due := 0.0
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
## Reserved in chart coordinates during one draw pass so district, objective
## and moving-contact labels negotiate the same scarce ink instead of printing
## through one another.
var _map_label_rects: Array[Rect2] = []
var hovered_place := -1
var selected_place := -1
## The Black Mirror opens on the facility sheet while that route has ever been
## seen. L flips between it and the Ashbloom satellite: one MAP application,
## two physical survey sheets, rather than a second territory menu.
var facility_sheet := false
var facility_hover := -1
var facility_selected := -1
var _facility_rects: Array = []
## Local arrival animation only. Persistent truth lives in AshbloomHoldings;
## this is how strongly that truth has physically developed on this sheet.
var _holding_reveal: Dictionary = {}
var _holding_polygons: Dictionary = {}
var travel_hold := 0.0
signal travel_requested(place: Dictionary)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_hatch = _build_hatch()
	_holding_polygons = HOLDINGS.polygons()
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
	HOLDINGS.observe(player_at)
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


## A10. Handed the world to look at. Called by whichever scene owns the region;
## the map never goes looking for one, so a scene without a world simply does not
## call this and nothing breaks.
func attach_world(world: World3D) -> void:
	if satellite != null and is_instance_valid(satellite):
		return
	if world == null:
		return
	satellite = SATELLITE.make(world)
	add_child(satellite)


func set_satellite_available(available: bool, reason := "") -> void:
	satellite_available = available
	satellite_block_reason = reason if not available else ""
	if not available:
		_sleep_satellite()
	queue_redraw()


func open_map() -> void:
	visible = true
	follow = true
	pan = Vector2.ZERO
	if satellite_available:
		FACILITY.publish_target_ping(player_at)
	var territory := WorldHistory.subject(FACILITY.SUBJECT)
	facility_sheet = not territory.is_empty()
	if facility_sheet and facility_selected < 0:
		facility_selected = _first_revealed_facility_sector()
	queue_redraw()


## A10.8. Nothing renders while the map is shut.
func _sleep_satellite() -> void:
	if satellite != null and is_instance_valid(satellite):
		satellite.call("sleep")


func close_map() -> void:
	_sleep_satellite()
	visible = false


## The pocket feed reuses the exact satellite camera the full map owns. It is
## deliberately slow (eight frames a second) and close around the player: a
## navigational instrument, not a second always-on render of the whole region.
func update_minimap(delta: float) -> Texture2D:
	if not satellite_available or visible or satellite == null or not is_instance_valid(satellite):
		return null
	satellite.call("observe", Vector3(player_at.x, 0.0, player_at.y), player_yaw, 0.0, delta, Vector2(120, 120))
	_minimap_due -= delta
	if _minimap_due <= 0.0:
		_minimap_due = 1.0 / 8.0
		satellite.call("request_frame")
	return satellite.get_texture()


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
			_commit_travel(district)
			travel_hold = 0.0
	else:
		travel_hold = maxf(0.0, travel_hold - delta * 2.2)


## Holding T resolves once, here. The signal may start a scene transition, but
## the choice that requested it already has a durable identity in the ledger.
func _commit_travel(district: Dictionary) -> void:
	travel_requested.emit(district)
	PlayerActionLedger.record("map_travel", {
		"subject": "player",
		"place": str(district.get("name", "")),
		"place_id": str(district.get("id", district.get("record", ""))),
	})


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	for row: Dictionary in HOLDINGS.overview().holdings:
		var id := str(row.id)
		var current := float(_holding_reveal.get(id, 0.0))
		var target := 1.0 if bool(row.revealed) else 0.0
		_holding_reveal[id] = move_toward(current, target, delta * 0.72)
	# Looking through the corporate lens lets it look back. The authority
	# de-duplicates within its coarse cell, so this is cheap and only writes when
	# the carried device has crossed into a genuinely new search area.
	if satellite_available:
		FACILITY.publish_target_ping(player_at)
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
	if facility_sheet:
		_handle_facility_input(event)
		return
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
			zoom = clampf(zoom * 1.14, _zoom_floor(), 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = clampf(zoom / 1.14, _zoom_floor(), 5.0)
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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		facility_sheet = true
		facility_selected = _first_revealed_facility_sector()
		queue_redraw()


func _handle_facility_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		facility_hover = _facility_under((event as InputEventMouseMotion).position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var found := _facility_under((event as InputEventMouseButton).position)
		if found >= 0:
			facility_selected = found
			queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_L:
				facility_sheet = false
			KEY_LEFT, KEY_UP:
				_select_facility(-1)
			KEY_RIGHT, KEY_DOWN:
				_select_facility(1)
		queue_redraw()


func _facility_under(point: Vector2) -> int:
	for entry: Dictionary in _facility_rects:
		if (entry.rect as Rect2).has_point(point):
			return int(entry.index)
	return -1


func _first_revealed_facility_sector() -> int:
	var rows: Array = FACILITY.overview().sectors
	for index in rows.size():
		if bool(rows[index].revealed):
			return index
	return -1


func _select_facility(step: int) -> void:
	var rows: Array = FACILITY.overview().sectors
	if rows.is_empty():
		facility_selected = -1
		return
	var start := facility_selected if facility_selected >= 0 else 0
	for offset in range(1, rows.size() + 1):
		var candidate := wrapi(start + step * offset, 0, rows.size())
		if bool(rows[candidate].revealed):
			facility_selected = candidate
			return


## Greg, on the second playtest: *"the map is incredibly laggy right now"*.
##
## Both grid passes — the unwalked veil and the unsurveyed hatch — walked every
## cell in the whole region on every redraw, formatted a `"%d,%d"` string per
## cell to look it up, ran `_to_screen` on it, built a Rect2 and then threw
## almost all of them away because they were off the chart. At CELL = 22 over
## the Ashbloom that is thousands of cells a frame to draw a few hundred.
##
## `_to_screen` is a translate and a scale, so it inverts exactly. Deriving the
## cell range from the chart rectangle means the loops only ever touch cells
## that can actually be seen, which is the same picture for a fraction of the
## work — and the cost now scales with the window instead of with the world.
func _to_world(screen: Vector2) -> Vector2:
	var origin := _chart.get_center() + pan
	var anchor := player_at if follow else Vector2.ZERO
	return (screen - origin) / maxf(zoom, 0.0001) + anchor


## The inclusive cell range covering the chart, with a one-cell margin so a cell
## straddling the edge is still drawn.
func _visible_cells() -> Dictionary:
	var top_left := _to_world(_chart.position)
	var bottom_right := _to_world(_chart.end)
	var half := AshbloomWorldGenerator.REGION_SIZE * 0.5
	# Clamped to the region: there is nothing to say about ground the world does
	# not have, and an unclamped range at low zoom is unbounded.
	var from := Vector2i(
		maxi(floori(minf(top_left.x, bottom_right.x) / CELL) - 1, floori(-half.x / CELL) - 1),
		maxi(floori(minf(top_left.y, bottom_right.y) / CELL) - 1, floori(-half.y / CELL) - 1)
	)
	var to := Vector2i(
		mini(ceili(maxf(top_left.x, bottom_right.x) / CELL) + 1, ceili(half.x / CELL) + 1),
		mini(ceili(maxf(top_left.y, bottom_right.y) / CELL) + 1, ceili(half.y / CELL) + 1)
	)
	return {"from": from, "to": to}


func _to_screen(world: Vector2) -> Vector2:
	var origin := _chart.get_center() + pan
	var anchor := player_at if follow else Vector2.ZERO
	return origin + (world - anchor) * zoom


## The zoom that still holds the whole region, with a margin.
##
## Greg: *"the map in the maingame is completly broken"*. Part of why was this:
## the wheel clamped to 0.35, and the Ashbloom is 470x370m. On a 1280 window a
## chart 1228px wide at 0.35 claims to be showing three and a half kilometres of
## a world that has four hundred metres in it, so the region sat as a small
## island in the middle of an enormous blank floor and the default 1.25 was
## already twice too wide. There is no view worth having that is wider than the
## world, so the floor is derived from the chart and the region rather than
## being a number somebody picked.
func _zoom_floor() -> float:
	if _chart.size.x <= 1.0 or _chart.size.y <= 1.0:
		return 0.35
	# 1.12 so the region has an edge rather than touching the frame.
	var region := AshbloomWorldGenerator.REGION_SIZE * 1.12
	return minf(_chart.size.x / region.x, _chart.size.y / region.y)


func _draw() -> void:
	if not visible:
		return
	var margin := 26.0
	# Controls can receive one draw during a resize with a zero-sized viewport.
	# The former code made a negative chart in that frame, then fed it into every
	# intersection test in the unexplored-ground pass — an error storm that made
	# the map look broken and dragged the whole game down. A map with no surface
	# simply waits one frame for its real dimensions.
	var chart_size := Vector2(size.x - margin * 2.0, size.y - margin * 2.0 - 74.0)
	if chart_size.x <= 1.0 or chart_size.y <= 1.0:
		return
	_chart = Rect2(Vector2(margin, margin + 34.0), chart_size)
	if facility_sheet:
		_draw_facility_sheet()
		if not satellite_available:
			_draw_satellite_block()
		return
	# The floor depends on the chart, which depends on the window, so it is
	# applied here rather than only where the wheel is read — a map opened on a
	# smaller window would otherwise keep a zoom that window cannot justify.
	zoom = clampf(zoom, _zoom_floor(), 5.0)

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.026, 0.019, 0.94))
	draw_rect(_chart, PLATE)

	# A10.1/A10.2. The region itself, under everything else. The chart's marks,
	# roads and contacts still draw on top — what changes is what they draw on
	# top *of*: the world in its own materials rather than a dark plate.
	if satellite_available and satellite != null and is_instance_valid(satellite):
		# Zoom already ran 0.6-3.0 for the chart; reuse it rather than inventing
		# a second control the player has to learn.
		descent = clampf(inverse_lerp(0.8, 2.8, zoom), 0.0, 1.0)
		# The other half of "the map is broken". The chart's marks are drawn at
		# `zoom` pixels per metre about the chart's own centre; the photograph
		# under them was framed by a camera height that knew nothing about that,
		# so at the default zoom the chart claimed 982m across while the camera
		# photographed 252m and that square was then stretched into a wide
		# rectangle. Roads, districts and contacts were sitting over a picture of
		# somewhere else, at a different scale, squashed. The camera is told what
		# ground the chart is claiming, and frames exactly that.
		var span := _chart.size / maxf(zoom, 0.0001)
		var chart_centre := _to_world(_chart.get_center())
		satellite.call("observe", Vector3(chart_centre.x, 0.0, chart_centre.y), player_yaw, descent, get_process_delta_time(), span)
		# A whole second render of the region, at 768 square, is not something to
		# do sixty times a second for a picture nobody is animating. Asked for at
		# about twenty, which is indistinguishable while panning and a third of
		# the cost. The texture persists between frames, so the map still draws
		# a satellite image on every one of them.
		_satellite_due -= get_process_delta_time()
		if _satellite_due <= 0.0:
			_satellite_due = 1.0 / 20.0
			satellite.call("request_frame")
		var image := satellite.get_texture()
		if image != null:
			# Full strength. At 0.92 it was being mixed with the plate below
			# it before the chart had even started drawing over the top.
			draw_texture_rect(image, _chart, false, Color(1, 1, 1, 1.0))
			# A10.5. Unwalked ground is greyed over the image rather than cut out
			# of it, so the shape of what you have not been to is still legible.
			_draw_unwalked_veil()
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
		# Matched to the camera rather than picked. `satellite_view.gd` now holds
		# the oblique at 52 degrees of pitch, so the ground is foreshortened by
		# cos(38) = 0.79. Squashing the marks harder than that made the chart and
		# the photograph disagree about the same ground, on top of each other,
		# which is the other half of what "reads as a smear" was describing.
		var squash := lerpf(1.0, 0.79, tilt)
		draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(0.0, squash), Vector2(0.0, horizon * (1.0 - squash))))

	# A10.4. Over a live image the grid is a reference overlay and belongs at
	# overlay weight; on paper it is the chart itself.
	if not _satellite_live():
		_draw_grid()
	_draw_roads()
	_draw_lots()
	# Over the plan, not under it: unwalked ground is supposed to withhold what
	# is standing on it, which it cannot do from underneath.
	_draw_unsurveyed()
	_draw_holdings()
	_map_label_rects.clear()
	_draw_districts()
	_draw_misfires()
	_draw_contacts()
	_draw_celloutz_target_area()
	if satellite_available:
		_draw_player()
	_draw_places()
	if tilt > 0.0:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# The far edge falls away into haze, which an affine squash cannot do on
		# its own and which is most of what makes a tilt legible.
		var haze := _chart.size.y * 0.22 * tilt
		# 14 bands over a 0.22-height falloff banded visibly. Enough of them that
		# the far edge reads as haze rather than as a stack of rectangles.
		var steps := 38
		for band in steps:
			var travel := float(band) / float(steps)
			draw_rect(Rect2(_chart.position + Vector2(0, haze * travel), Vector2(_chart.size.x, haze / float(steps) + 1.0)), VOID * Color(1, 1, 1, (1.0 - travel) * 0.72 * tilt))
	_draw_frame()
	_draw_bezel()
	_draw_legend()
	if selected_place >= 0:
		_draw_place_panel()
	_draw_cracks()
	if not satellite_available:
		_draw_satellite_block()


func _draw_satellite_block() -> void:
	var reason := satellite_block_reason.to_upper()
	var title := "SATELLITE OCCLUDED // LOCAL MEMORY ONLY"
	var width := CellOutzType.width_condensed(title, 11.0, 0.82)
	var at := Vector2(_chart.get_center().x - width * 0.5, _chart.position.y + 22.0)
	draw_rect(Rect2(at - Vector2(10, 15), Vector2(width + 20, 25)), VOID * Color(1, 1, 1, 0.88))
	CellOutzType.draw_condensed(self, at, title, 11.0, ARTERIAL, 0.82)
	if not reason.is_empty():
		var reason_width := CellOutzType.width_condensed(reason, 8.0, 0.68)
		CellOutzType.draw_condensed(self, Vector2(_chart.get_center().x - reason_width * 0.5, at.y + 17.0), reason, 8.0, INK * Color(1, 1, 1, 0.7), 0.68)


func _draw_celloutz_target_area() -> void:
	var area := FACILITY.target_area()
	if area.is_empty():
		return
	var centre_world := Vector2(float(area.get("x", 0.0)), float(area.get("z", 0.0)))
	var centre := _to_screen(centre_world)
	var radius := float(area.get("radius", FACILITY.TARGET_PING_RADIUS)) * zoom
	if not _chart.grow(radius).has_point(centre):
		return
	# Broken arcs communicate an estimated search area. A solid circle would
	# falsely promise that CellOutz knows the player's boundary exactly.
	var turn := clock * 0.23
	for segment in 10:
		var start := turn + TAU * float(segment) / 10.0
		draw_arc(centre, radius, start, start + TAU * 0.058, 8, ARTERIAL * Color(1, 1, 1, 0.82), 2.0, true)
	var sweep := Vector2(cos(clock * 0.7), sin(clock * 0.7))
	draw_line(centre - sweep * radius * 0.72, centre + sweep * radius * 0.72, ARTERIAL * Color(1, 1, 1, 0.18), 1.0)
	draw_circle(centre, 4.0 + sin(clock * 2.2) * 1.2, ARTERIAL * Color(1, 1, 1, 0.82))
	var label := "CELLOUTZ TARGET AREA // +/- %d M" % roundi(float(area.get("radius", 0.0)))
	var label_at := centre + Vector2(-radius, -radius - 17.0)
	label_at.x = clampf(label_at.x, _chart.position.x + 8.0, _chart.end.x - CellOutzType.width_condensed(label, 8.0, 0.7) - 8.0)
	label_at.y = clampf(label_at.y, _chart.position.y + 8.0, _chart.end.y - 18.0)
	CellOutzType.draw_condensed(self, label_at, label, 8.0, ARTERIAL, 0.7)


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
## A10.5. The colour arrives as you walk. Everything you have not surveyed is
## covered by a desaturating grey; ground next to somewhere you have been is
## half-covered, because you have seen it from where you stood without having
## stood in it.
func _draw_unwalked_veil() -> void:
	var step := CELL * zoom
	if step < 3.0:
		return
	# Ground beyond the cell grid is unknown too, and was showing through at full
	# colour — which read as the edges of the map being its best-surveyed part.
	# Veiled as four bands around the region rather than as one sheet over
	# everything, because a sheet doubles up on the per-cell veil below and turns
	# the surveyed region into the darkest thing on the chart.
	var half_region := AshbloomWorldGenerator.REGION_SIZE * 0.5
	var top_left := _to_screen(Vector2(-half_region.x, -half_region.y))
	var bottom_right := _to_screen(Vector2(half_region.x, half_region.y))
	var region := Rect2(top_left, bottom_right - top_left).abs()
	var outside := Color(0.46, 0.47, 0.44, 0.86)
	if region.position.y > _chart.position.y:
		draw_rect(Rect2(_chart.position, Vector2(_chart.size.x, region.position.y - _chart.position.y)).intersection(_chart), outside)
	if region.end.y < _chart.end.y:
		draw_rect(Rect2(Vector2(_chart.position.x, region.end.y), Vector2(_chart.size.x, _chart.end.y - region.end.y)).intersection(_chart), outside)
	if region.position.x > _chart.position.x:
		draw_rect(Rect2(Vector2(_chart.position.x, region.position.y), Vector2(region.position.x - _chart.position.x, region.size.y)).intersection(_chart), outside)
	if region.end.x < _chart.end.x:
		draw_rect(Rect2(Vector2(region.end.x, region.position.y), Vector2(_chart.end.x - region.end.x, region.size.y)).intersection(_chart), outside)
	var half := AshbloomWorldGenerator.REGION_SIZE * 0.5
	var from := Vector2i(floori(-half.x / CELL) - 1, floori(-half.y / CELL) - 1)
	var to := Vector2i(ceili(half.x / CELL) + 1, ceili(half.y / CELL) + 1)
	for cx in range(from.x, to.x + 1):
		for cy in range(from.y, to.y + 1):
			var at := _to_screen(Vector2(cx * CELL - CELL * 0.5, cy * CELL - CELL * 0.5))
			var cell := Rect2(at, Vector2(step, step))
			if not _chart.intersects(cell):
				continue
			var patch := cell.intersection(_chart)
			# A10.9. The reveal arrives rather than snaps. A cell's clearness is
			# its whole 3x3 neighbourhood rather than its own bit, so the boundary
			# between walked and unwalked is a gradient instead of the staircase
			# the first pass drew. Diagonals count for less, which is what keeps
			# the falloff round instead of square.
			var clearness := 0.0
			var weight := 0.0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var w: float = 1.0 if dx == 0 and dy == 0 else (0.62 if dx == 0 or dy == 0 else 0.34)
					weight += w
					if surveyed.has("%d,%d" % [cx + dx, cy + dy]):
						clearness += w
			clearness = clampf(clearness / maxf(weight, 0.001), 0.0, 1.0)
			if clearness >= 0.999:
				continue
			# Eased, so ground you have only glimpsed clears slowly and ground you
			# have properly walked clears fast — the satisfying part is the last bit
			# coming off, the way wiping a window is.
			var veil := pow(1.0 - clearness, 1.45)
			# On the satellite view this used to redraw each unseen cell as a
			# fully square grey slab.  The world was correct underneath, but the
			# exploration boundary read as a grid of apartment blocks.  A soft,
			# overlapping survey bloom keeps the information while letting the
			# actual terrain remain the dominant shape.
			if _satellite_live():
				var bloom_radius := minf(step * 0.73, minf(patch.size.x, patch.size.y) * 0.73)
				draw_circle(patch.get_center(), bloom_radius, Color(0.46, 0.47, 0.44, veil * 0.48), true, -1.0, true)
			else:
				draw_rect(patch, Color(0.46, 0.47, 0.44, veil * 0.88))
			# A breath of haze that lingers even on cleared ground, so the map never
			# reads as a clean render of a place nobody has been to.
			if clearness > 0.0 and clearness < 1.0:
				draw_rect(patch, Color(0.70, 0.72, 0.66, 0.05 + clearness * 0.05))


func _draw_unsurveyed() -> void:
	var step := CELL * zoom
	if step < 3.0:
		return
	var span: Dictionary = _visible_cells()
	var from: Vector2i = span["from"]
	var to: Vector2i = span["to"]
	for cx in range(from.x, to.x + 1):
		for cy in range(from.y, to.y + 1):
			if surveyed.has("%d,%d" % [cx, cy]):
				continue
			var at := _to_screen(Vector2(cx * CELL - CELL * 0.5, cy * CELL - CELL * 0.5))
			var cell := Rect2(at, Vector2(step, step))
			if not _chart.intersects(cell):
				continue
			var patch := cell.intersection(_chart)
			if _satellite_live():
				# Survey uncertainty is atmospheric over a live world image, not a
				# square cover laid over it. Keep a faint ring/hatch for the map's
				# printed language without turning buildings into blocky fog tiles.
				var radius := minf(step * 0.48, minf(patch.size.x, patch.size.y) * 0.48)
				draw_circle(patch.get_center(), radius, Color(0.025, 0.040, 0.033, 0.38), true, -1.0, true)
				draw_arc(patch.get_center(), radius, 0.0, TAU, 18, Color(0.35, 0.42, 0.28, 0.22), 0.8, true)
			else:
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


## A10.4. Second playtest, TaKeS on the map: *"sort of? I can tell theres
## somthing behind it"*. Exactly right, and the diagnosis is in the sentence —
## the satellite renders, and then the chart draws its whole symbol set on top
## in solid fills, so the region is behind an opaque plan of itself.
##
## A chart over a photograph is an annotation layer. Every fill below thins to
## an outline while there is a real image underneath, and goes back to being a
## drawn plan the moment there is not — the paper chart is still the fallback
## when no scene has handed the map a world, and it has to stay legible on its
## own.
func _satellite_live() -> bool:
	return satellite_available and satellite != null and is_instance_valid(satellite) and satellite.get_texture() != null


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
		if _satellite_live():
			# The building is already there to look at. All the chart adds is
			# that somebody surveyed it, which is a line, not a block.
			draw_rect(plan, tint * Color(1, 1, 1, 0.62 if charted else 0.16), false, 1.0)
			continue
		draw_rect(plan, tint * Color(1, 1, 1, 0.16 if charted else 0.05))
		draw_rect(plan, tint * Color(1, 1, 1, 0.6 if charted else 0.14), false, 1.0)


func _draw_districts() -> void:
	for district in DISTRICTS:
		var at: Vector2 = district.at
		var screen := _to_screen(at)
		var state := HOLDINGS.holding(str(district.id))
		var charted := bool(state.get("revealed", false))
		var tint := _holding_tone(str(state.get("held_by", district.held_by))) if charted else INK
		if not _chart.has_point(screen):
			continue
		var label := str(district.name) if charted else "UNSURVEYED SECTOR"
		# Held inside the sheet. A name that escapes the chart prints over the
		# title and reads as a caption on the device instead of a place.
		var label_width := CellOutzType.width_condensed(label.to_upper(), 11.0, 1.0)
		var name_at := _reserve_map_label(screen, Vector2(label_width, 36.0), [
			Vector2(-label_width * 0.5, -29.0), Vector2(10.0, -29.0),
			Vector2(-label_width - 10.0, -29.0), Vector2(-label_width * 0.5, 12.0),
		])
		CellOutzType.draw_condensed(self, name_at, label.to_upper(), 11.0, tint * Color(1, 1, 1, 0.9 if charted else 0.3), 1.0)
		if charted:
			var holder := str(state.get("held_by", district.held_by)).replace("_", " ").to_upper()
			CellOutzType.draw_condensed(self, name_at + Vector2(0, 14.0), "HELD / %s" % holder, 7.0, tint * Color(1, 1, 1, 0.55), 0.7)
			var required := int(state.get("local_work_required", 0))
			if required > 0:
				var work_state := str(state.get("local_work_state", "held"))
				var work_label := "DECISION OPEN" if work_state == "ready_for_decision" else "LOCAL CLAIM %d/%d" % [int(state.get("local_work_completed", 0)), required]
				CellOutzType.draw_condensed(self, name_at + Vector2(0, 25.0), work_label, 7.0, SPORE if work_state == "ready_for_decision" else tint * Color(1, 1, 1, 0.66), 0.7)


func _draw_holdings() -> void:
	for row: Dictionary in HOLDINGS.overview().holdings:
		var id := str(row.id)
		var world_polygon: PackedVector2Array = _holding_polygons.get(id, PackedVector2Array())
		if world_polygon.size() < 3:
			continue
		var full := PackedVector2Array()
		for point: Vector2 in world_polygon:
			full.append(_to_screen(point))
		var revealed := bool(row.revealed)
		var tone := _holding_tone(str(row.held_by)) if revealed else INK
		var blend := float(_holding_reveal.get(id, 0.0)) if revealed else 0.0
		var work_state := str(row.get("local_work_state", "held"))
		# Unknown land keeps a complete faint silhouette: enough shape to pull at
		# the player. Known land develops outward from its settlement like an old
		# instant photograph, making the reveal one event rather than many pixels.
		var closed := full.duplicate()
		closed.append(full[0])
		draw_polyline(closed, tone * Color(1, 1, 1, 0.16 if not revealed else 0.24), 1.0)
		if blend <= 0.001:
			continue
		var centre := _to_screen(row.at)
		var reveal := holding_reveal_profile(blend)
		var eased := float(reveal.coverage)
		var arriving := PackedVector2Array()
		for point: Vector2 in full:
			arriving.append(centre.lerp(point, eased))
		draw_colored_polygon(arriving, tone * Color(1, 1, 1, 0.035 + blend * 0.055))
		var arriving_closed := arriving.duplicate()
		arriving_closed.append(arriving[0])
		# The moving edge is the cleaning action: pale and thick at mid-travel,
		# relaxing into the holder-coloured border once the glass is clear.
		var wipe_tone := BONE.lerp(tone, blend)
		draw_polyline(arriving_closed, wipe_tone * Color(1, 1, 1, float(reveal.edge_alpha)), float(reveal.edge_width))
		var work_profile := holding_work_profile(work_state, Time.get_ticks_msec() / 1000.0)
		if bool(work_profile.visible):
			# A broken claim fractures inward from every border vertex. It reads
			# over satellite terrain at any zoom and leaves the holder colour in
			# place until the player performs the separate land decision.
			for vertex in full.size():
				var edge: Vector2 = full[vertex]
				var next: Vector2 = full[(vertex + 1) % full.size()]
				var bite := edge.lerp(next, 0.22)
				draw_line(edge, centre.lerp(bite, 0.28), ARTERIAL * Color(1, 1, 1, float(work_profile.crack_alpha)), float(work_profile.crack_width))
			if bool(work_profile.decision_open):
				draw_polyline(arriving_closed, SPORE * Color(1, 1, 1, float(work_profile.pulse_alpha)), 2.4)
		if float(reveal.streak_alpha) > 0.01:
			for vertex in range(0, full.size(), 2):
				var streak_end: Vector2 = arriving[vertex]
				var streak_start := centre.lerp(full[vertex], maxf(0.0, eased - 0.10))
				draw_line(streak_start, streak_end, BONE * Color(1, 1, 1, float(reveal.streak_alpha)), 1.0)


## Testable timing contract for the holding reveal. Coverage only advances;
## the bright cleaning lip peaks halfway and is gone once the new border rests.
static func holding_reveal_profile(blend: float) -> Dictionary:
	var clamped := clampf(blend, 0.0, 1.0)
	var front := sin(clamped * PI)
	return {
		"coverage": 1.0 - pow(1.0 - clamped, 3.0),
		"edge_alpha": 0.35 + clamped * 0.40 + front * 0.38,
		"edge_width": 1.6 + front * 2.6,
		"streak_alpha": front * 0.32,
	}


## The map treatment is data-testable independently of a framebuffer. A single
## completed job scars the old claim; the full connected set adds a slow living
## border, announcing an available decision without assigning the land.
static func holding_work_profile(state: String, elapsed: float) -> Dictionary:
	if state not in ["disrupted", "ready_for_decision"]:
		return {"visible": false, "decision_open": false, "crack_alpha": 0.0, "crack_width": 0.0, "pulse_alpha": 0.0}
	var open := state == "ready_for_decision"
	return {
		"visible": true,
		"decision_open": open,
		"crack_alpha": 0.52 if open else 0.34,
		"crack_width": 1.6 if open else 1.15,
		"pulse_alpha": (0.42 + sin(elapsed * 1.7) * 0.14) if open else 0.0,
	}


func _holding_tone(holder: String) -> Color:
	var axis := 0.0
	if WorldHistory.FACTION_TREE_AXIS.has(holder):
		axis = float((WorldHistory.FACTION_TREE_AXIS[holder] as Dictionary).get("axis", 0.0))
	if axis < -0.2:
		return ARTERIAL
	if axis > 0.2:
		return SPORE
	return BILE


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
			CellOutzType.draw_condensed(self, screen + Vector2(-3, -4), "?", 8.0, tint * Color(1, 1, 1, 0.6), 0.6)
			continue
		CellOutzType.draw_condensed(self, screen + Vector2(11, -4), str(encounter.get("title", "?")).to_upper(), 8.0, tint * Color(1, 1, 1, 0.85), 0.7)


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
			"work_raid": tint = ACID
			"work_collection": tint = SCAN
		if state == "loot":
			draw_rect(Rect2(screen - Vector2(3, 3), Vector2(6, 6)), tint * Color(1, 1, 1, 0.8))
			continue
		var beat := 0.5 + 0.5 * sin(clock * 4.0)
		# I0.3. There used to be a key along the bottom of the page — seven
		# coloured dots with words beside them — because every mark on the chart
		# was the same dot in a different colour. A mark that needs a key is a
		# mark that has not been drawn. These are told apart by shape, so the
		# key could be deleted rather than restyled.
		match state:
			"work_raid":
				# Four blades around an empty centre: a place to break open, not
				# another person pretending to be a quest marker.
				draw_colored_polygon(PackedVector2Array([
					screen + Vector2(0, -7), screen + Vector2(7, 0),
					screen + Vector2(0, 7), screen + Vector2(-7, 0),
				]), tint * Color(1, 1, 1, 0.28))
				draw_polyline(PackedVector2Array([
					screen + Vector2(0, -7), screen + Vector2(7, 0), screen + Vector2(0, 7),
					screen + Vector2(-7, 0), screen + Vector2(0, -7),
				]), tint, 1.6)
				draw_line(screen - Vector2(3, 0), screen + Vector2(3, 0), tint, 1.2)
			"work_collection":
				# A bracketed cache, kept distinct from the plain filled square
				# used for incidental loot.
				draw_rect(Rect2(screen - Vector2(6, 6), Vector2(12, 12)), tint, false, 1.6)
				draw_circle(screen, 2.0, tint)
			"hostile":
				# Point down: a thing coming at you.
				draw_colored_polygon(PackedVector2Array([
					screen + Vector2(0, 5.5), screen + Vector2(-5.0, -4.0), screen + Vector2(5.0, -4.0),
				]), tint)
			"ally", "recruited":
				# Closed ring with a centre: someone standing with you.
				draw_arc(screen, 5.0, 0.0, TAU, 14, tint, 1.6)
				draw_circle(screen, 2.0, tint)
			"downed":
				# Struck out.
				draw_line(screen - Vector2(5.5, 5.5), screen + Vector2(5.5, 5.5), tint, 1.6)
				draw_line(screen + Vector2(5.5, -5.5), screen + Vector2(-5.5, 5.5), tint, 1.6)
			_:
				# Open: neither yours nor after you yet.
				draw_arc(screen, 4.6, 0.0, TAU, 14, tint, 1.4)
		draw_arc(screen, 9.0 + beat * 4.0, 0.0, TAU, 14, tint * Color(1, 1, 1, 0.4 - beat * 0.2), 1.0)
		var label := str(contact.get("name", ""))
		if not label.is_empty():
			var width := CellOutzType.width_condensed(label.to_upper(), 8.0, 0.7)
			var label_at := _reserve_map_label(screen, Vector2(width, 13.0), [
				Vector2(10, -16), Vector2(10, 9), Vector2(-width - 10, -16),
				Vector2(-width - 10, 9), Vector2(10, -34), Vector2(-width * 0.5, 18),
			])
			CellOutzType.draw_condensed(self, label_at, label.to_upper(), 8.0, tint * Color(1, 1, 1, 0.9), 0.7)


## Chooses the first clear authored register, then the least-overlapping one if
## the chart is genuinely dense. Clamped to the chart so avoiding one label can
## never push another through the bezel.
func _reserve_map_label(anchor: Vector2, label_size: Vector2, offsets: Array) -> Vector2:
	var best := anchor
	var best_rect := Rect2(anchor, label_size)
	var best_overlap := INF
	for offset_variant in offsets:
		var offset: Vector2 = offset_variant
		var candidate := anchor + offset
		candidate.x = clampf(candidate.x, _chart.position.x + 7.0, _chart.end.x - label_size.x - 7.0)
		candidate.y = clampf(candidate.y, _chart.position.y + 7.0, _chart.end.y - label_size.y - 7.0)
		var rect := Rect2(candidate - Vector2(2, 2), label_size + Vector2(4, 4))
		var overlap := 0.0
		for occupied: Rect2 in _map_label_rects:
			var intersection := rect.intersection(occupied)
			if intersection.has_area():
				overlap += intersection.get_area()
		if is_zero_approx(overlap):
			_map_label_rects.append(rect)
			return candidate
		if overlap < best_overlap:
			best_overlap = overlap
			best = candidate
			best_rect = rect
	_map_label_rects.append(best_rect)
	return best


func _draw_player() -> void:
	var screen := _to_screen(player_at)
	if not _chart.has_point(screen):
		return
	# A facing cone, because a mark on a map cannot tell you which way you are
	# pointed and that is the one thing you open a map to find out.
	var heading := Vector2(sin(player_yaw), cos(player_yaw))
	var side := Vector2(-heading.y, heading.x)
	draw_colored_polygon(PackedVector2Array([
		screen + heading * 46.0 + side * 20.0,
		screen,
		screen + heading * 46.0 - side * 20.0,
	]), SPORE * Color(1, 1, 1, 0.12))

	# Greg: "make in the map it have the head icon instead of an arrow." An arrow
	# is a cursor; a head is a person, and this map is a survey of a place full of
	# people rather than a navigation aid. Drawn from above — the crown, with the
	# jaw toward where you are looking, so it still reports facing.
	var crown := 6.0
	draw_circle(screen, crown, SPORE)
	draw_circle(screen, crown * 0.62, VOID * Color(1, 1, 1, 0.55))
	# The jaw, toward the heading.
	draw_colored_polygon(PackedVector2Array([
		screen + heading * crown * 1.55,
		screen + side * crown * 0.52,
		screen - side * crown * 0.52,
	]), SPORE)
	# Shoulders, so it reads as a body seen from above rather than a dot.
	draw_line(screen - side * crown * 1.25, screen + side * crown * 1.25, SPORE * Color(1, 1, 1, 0.8), 2.2)
	draw_arc(screen, 13.0 + sin(clock * 3.0) * 2.0, 0.0, TAU, 20, SPORE * Color(1, 1, 1, 0.5), 1.0)


func _draw_frame() -> void:
	draw_rect(_chart, ACID * Color(1, 1, 1, 0.4), false, 1.4)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := _chart.position + _chart.size * corner
		var dx := -18.0 if corner.x > 0.5 else 18.0
		var dy := -14.0 if corner.y > 0.5 else 14.0
		draw_line(at, at + Vector2(dx, 0), ACID, 2.0)
		draw_line(at, at + Vector2(0, dy), ACID, 2.0)
	CellOutzType.draw_stamped(self, Vector2(26, 10), "LIVING MAP", 20.0, ACID, ARTERIAL * Color(1, 1, 1, 0.25), 3.4)
	_draw_title_block()


## I0.3. The sheet metadata used to be a single line of fallback-font text run
## across the top of the page, which printed through the map's own district
## labels and read as a status bar. A survey sheet does not have a status bar.
## It has a title block in the corner of the paper: who surveyed it, which sheet
## this is, how much of it was ever walked, and where the surveyor was standing
## when they last put the pencil down.
func _draw_title_block() -> void:
	var charted := float(surveyed.size()) * CELL * CELL
	var total := AshbloomWorldGenerator.REGION_SIZE.x * AshbloomWorldGenerator.REGION_SIZE.y
	var fraction := clampf(charted / total, 0.0, 1.0)
	var block := Rect2(Vector2(_chart.end.x - 222.0, _chart.end.y - 92.0), Vector2(210.0, 80.0))
	# Backed in paper, because it is printed on the sheet rather than floating
	# above it, and the chart is allowed to run underneath.
	draw_rect(block, PLATE * Color(1, 1, 1, 0.92))
	draw_rect(block, INK * Color(1, 1, 1, 0.28), false, 1.0)
	draw_line(block.position + Vector2(0, 20), block.position + Vector2(block.size.x, 20), INK * Color(1, 1, 1, 0.2), 1.0)
	CellOutzType.draw_condensed(self, block.position + Vector2(9, 6), "CELLOUTZ SURVEY", 10.0, ACID * Color(1, 1, 1, 0.85), 0.9)
	CellOutzType.draw_condensed(self, block.position + Vector2(9, 27), "LIMBO / THE ASHBLOOM EXPANSE", 8.0, INK * Color(1, 1, 1, 0.6), 0.7)
	CellOutzType.draw_condensed(self, block.position + Vector2(9, 41), "SHEET 01 OF 01", 8.0, INK * Color(1, 1, 1, 0.45), 0.7)
	# Walked ground as a filled bar. A percentage is a number you read; a bar
	# that is mostly empty is a fact you feel, and this one is meant to shame.
	var bar := Rect2(block.position + Vector2(9, 56), Vector2(block.size.x - 18.0, 7.0))
	draw_rect(bar, INK * Color(1, 1, 1, 0.10))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), SPORE * Color(1, 1, 1, 0.8))
	draw_rect(bar, INK * Color(1, 1, 1, 0.2), false, 1.0)
	CellOutzType.draw_condensed(self, block.position + Vector2(9, 67), "WALKED %0.1f%%" % (fraction * 100.0), 7.0, SPORE * Color(1, 1, 1, 0.75), 0.6)
	var fix := "E %+0.0f  N %+0.0f" % [player_at.x, -player_at.y]
	var fix_width := CellOutzType.width_condensed(fix, 7.0, 0.6)
	CellOutzType.draw_condensed(self, block.position + Vector2(block.size.x - 9.0 - fix_width, 67), fix, 7.0, INK * Color(1, 1, 1, 0.5), 0.6)


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
		var charted := bool(HOLDINGS.holding(str(district.id)).get("revealed", false))
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
	CellOutzType.draw_stamped(self, panel.position + Vector2(14, 14), str(district.get("name", "UNNAMED")).to_upper(), 16.0, INK, ARTERIAL * Color(1, 1, 1, 0.3), 1.2)
	var note_y := 54.0
	for line: String in CellOutzType.wrap_condensed(str(district.get("note", "")).to_upper(), panel.size.x - 32.0, 9.0, 0.7):
		CellOutzType.draw_condensed(self, panel.position + Vector2(16, note_y), line, 9.0, INK * Color(1, 1, 1, 0.7), 0.7)
		note_y += 13.0
	var holding_state := HOLDINGS.holding(str(district.id))
	var charted := bool(holding_state.get("revealed", false))
	var route_ready := is_surveyed(district.get("at", Vector2.ZERO))
	var status := ("HELD / %s" % str(holding_state.get("held_by", district.held_by)).replace("_", " ").to_upper()) if charted else "UNWALKED // NO ROUTE"
	CellOutzType.draw_text(self, panel.position + Vector2(14, 82), status, 10.0, _holding_tone(str(holding_state.get("held_by", ""))) if charted else ARTERIAL, 1.0)
	if route_ready:
		var bar := Rect2(panel.position + Vector2(14, 106), Vector2(panel.size.x - 28, 14))
		draw_rect(bar, INK * Color(1, 1, 1, 0.10))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(travel_hold, 0.0, 1.0), bar.size.y)), ACID)
		draw_rect(bar, INK * Color(1, 1, 1, 0.22), false, 1.0)
		CellOutzType.draw_text(self, panel.position + Vector2(14, 126), "HOLD T TO TRAVEL", 9.0, INK * Color(1, 1, 1, 0.6), 1.0)


## I0.3. What is left of the legend after the key was deleted: a scale bar,
## which is an instrument rather than a list, and the controls written into the
## margin at an angle, the way you write on the edge of a sheet you are holding.
func _draw_legend() -> void:
	var base := Vector2(26, size.y - 34)
	draw_line(base + Vector2(0, -14), base + Vector2(size.x - 52, -14), INK * Color(1, 1, 1, 0.15), 1.0)
	# Scale bar measured off the real zoom, so distances on the chart mean metres.
	var bar := 50.0 * zoom
	draw_line(base, base + Vector2(bar, 0), INK, 2.0)
	draw_line(base, base + Vector2(0, -5), INK, 2.0)
	draw_line(base + Vector2(bar, 0), base + Vector2(bar, -5), INK, 2.0)
	# Ticks at ten metres, because a bar with no divisions is a decoration.
	for tick in range(1, 5):
		var at := base + Vector2(bar * float(tick) / 5.0, 0)
		draw_line(at, at + Vector2(0, -3), INK * Color(1, 1, 1, 0.6), 1.0)
	CellOutzType.draw_condensed(self, base + Vector2(bar + 8, -8), "50 M", 8.0, INK * Color(1, 1, 1, 0.7), 0.7)
	# Marginalia. Scrawled along the bottom edge at a slight angle, low enough
	# in contrast to ignore once it is known, which is what a control hint is
	# for. It is no longer a row of labels in a strip.
	var scrawl := "DRAG TO PAN / WHEEL ZOOMS / F RECENTRES / M PUTS IT AWAY"
	# Ends clear of the keys card, which draws its own closed-state hint at
	# `size.x - 128` on this exact same baseline (`keys_card.gd:96`). Ending at
	# `size.x - 40` put this straight through it, so the one corner of the screen
	# that is nothing but control hints had two of them stacked on each other.
	draw_set_transform(Vector2(size.x - 152.0 - CellOutzType.width_condensed(scrawl, 8.0, 0.8), size.y - 26.0), -0.028, Vector2.ONE)
	CellOutzType.draw_condensed(self, Vector2.ZERO, scrawl, 8.0, ACID * Color(1, 1, 1, 0.45), 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_facility_sheet() -> void:
	var overview := FACILITY.overview()
	var rows: Array = overview.sectors
	_facility_rects.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.026, 0.019, 0.96))
	draw_rect(_chart, PLATE)
	Grunge.stain(self, _chart.position + _chart.size * Vector2(0.24, 0.70), 180.0, 991, Grunge.RUST, 0.06)
	Grunge.stain(self, _chart.position + _chart.size * Vector2(0.76, 0.26), 150.0, 997, Grunge.BILE, 0.05)

	# The routes are real scene adjacency, shown before the rooms so every line
	# terminates underneath its destination rather than through its label.
	for route: Array in overview.routes:
		var a := _facility_row(rows, str(route[0]))
		var b := _facility_row(rows, str(route[1]))
		if a.is_empty() or b.is_empty():
			continue
		var from := _facility_at(a)
		var to := _facility_at(b)
		var known := bool(a.revealed) and bool(b.revealed)
		draw_dashed_line(from, to, SPORE * Color(1, 1, 1, 0.72) if known else INK * Color(1, 1, 1, 0.13), 2.0, 8.0)

	for index in rows.size():
		var row: Dictionary = rows[index]
		var at := _facility_at(row)
		var revealed := bool(row.revealed)
		var state := str(row.state)
		var room := Rect2(at - Vector2(72, 38), Vector2(144, 76))
		_facility_rects.append({"index": index, "rect": room.grow(8.0)})
		var tone := ARTERIAL
		if state == FACILITY.LIBERATED:
			tone = SPORE
		elif state == FACILITY.SURVEYED:
			tone = BILE
		var hot := index == facility_hover or index == facility_selected
		draw_rect(room, tone * Color(1, 1, 1, 0.13 if revealed else 0.035))
		draw_rect(room, tone * Color(1, 1, 1, 0.92 if hot else (0.48 if revealed else 0.14)), false, 2.2 if hot else 1.2)
		# Corporate surveillance is a cone, not a generic eye icon: its footprint
		# is an intentionally imprecise area the player can reason about.
		if revealed and state != FACILITY.LIBERATED:
			var sweep := 0.22 + 0.06 * sin(clock * 1.7 + float(index))
			draw_arc(at, 51.0, -PI * sweep, PI * sweep, 18, ARTERIAL * Color(1, 1, 1, 0.34), 1.2)
		var name := str(row.name).to_upper() if revealed else "REDACTED HOLDING"
		var lines := CellOutzType.wrap_condensed(name, room.size.x - 12.0, 7.5, 0.66)
		var name_y := -12.0 if lines.size() > 1 else -5.0
		for line: String in lines:
			var width := CellOutzType.width_condensed(line, 7.5, 0.66)
			CellOutzType.draw_condensed(self, at + Vector2(-width * 0.5, name_y), line, 7.5, tone * Color(1, 1, 1, 0.95 if revealed else 0.25), 0.66)
			name_y += 10.0
		if revealed:
			var state_label := state.to_upper()
			var sw := CellOutzType.width_condensed(state_label, 7.0, 0.65)
			CellOutzType.draw_condensed(self, at + Vector2(-sw * 0.5, 20), state_label, 7.0, tone, 0.65)

	_draw_facility_header(overview)
	if facility_selected >= 0 and facility_selected < rows.size():
		_draw_facility_panel(rows[facility_selected])
	_draw_frame()
	_draw_bezel()
	_draw_cracks()
	var hint := "POINTER / ARROWS SELECT HOLDING   L ASHBLOOM SATELLITE"
	CellOutzType.draw_condensed(self, Vector2(28, size.y - 27), hint, 8.0, INK * Color(1, 1, 1, 0.5), 0.7)


func _facility_row(rows: Array, id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.id) == id:
			return row
	return {}


func _facility_at(row: Dictionary) -> Vector2:
	var normal: Vector2 = row.get("at", Vector2.ZERO)
	return _chart.position + Vector2(_chart.size.x * normal.x, _chart.size.y * normal.y)


func _draw_facility_header(overview: Dictionary) -> void:
	CellOutzType.draw_stamped(self, Vector2(26, 10), "LIVING MAP / HOLDINGS", 20.0, ACID, ARTERIAL * Color(1, 1, 1, 0.25), 3.4)
	var box := Rect2(_chart.position + Vector2(16, 16), Vector2(258, 79))
	draw_rect(box, VOID * Color(1, 1, 1, 0.9))
	draw_rect(box, ACID * Color(1, 1, 1, 0.38), false, 1.0)
	CellOutzType.draw_condensed(self, box.position + Vector2(11, 10), str(overview.name), 11.0, INK, 0.9)
	CellOutzType.draw_condensed(self, box.position + Vector2(11, 30), "REGISTERED OWNER / CELLOUTZ", 8.0, ARTERIAL, 0.7)
	CellOutzType.draw_condensed(self, box.position + Vector2(11, 46), "LIBERATED %d / %d" % [int(overview.liberated_count), (overview.sectors as Array).size()], 8.0, SPORE, 0.7)
	CellOutzType.draw_condensed(self, box.position + Vector2(11, 61), "SURVEILLANCE %03d%%" % roundi(float(overview.surveillance) * 100.0), 8.0, BILE, 0.7)
	var reaction := WorldHistory.subject(FACILITY.REACTION_SUBJECT)
	if not reaction.is_empty():
		var order := Rect2(Vector2(_chart.position.x + 16, _chart.end.y - 43), Vector2(420, 27))
		draw_rect(order, ARTERIAL * Color(1, 1, 1, 0.13))
		draw_rect(order, ARTERIAL * Color(1, 1, 1, 0.66), false, 1.2)
		CellOutzType.draw_condensed(self, order.position + Vector2(10, 7), "%s // %s" % [str(reaction.get("name", "REPOSSESSION ORDER")), str(reaction.get("status", "circulating")).to_upper()], 9.0, ARTERIAL, 0.8)


func _draw_facility_panel(row: Dictionary) -> void:
	var panel := Rect2(Vector2(_chart.end.x - 350, _chart.position.y + 16), Vector2(330, 144))
	draw_rect(panel, VOID * Color(1, 1, 1, 0.94))
	draw_rect(panel, ACID * Color(1, 1, 1, 0.42), false, 1.2)
	CellOutzType.draw_stamped(self, panel.position + Vector2(14, 14), str(row.name), 15.0, INK, ARTERIAL * Color(1, 1, 1, 0.25), 1.0)
	CellOutzType.draw_condensed(self, panel.position + Vector2(14, 48), "STATE / %s" % str(row.state).to_upper(), 9.0, SPORE if str(row.state) == FACILITY.LIBERATED else BILE, 0.8)
	CellOutzType.draw_condensed(self, panel.position + Vector2(14, 66), "OWNER / %s" % ("UNBOUND" if str(row.state) == FACILITY.LIBERATED else str(row.owner).to_upper()), 9.0, ARTERIAL, 0.8)
	var y := 91.0
	for line: String in CellOutzType.wrap_condensed(str(row.objective), panel.size.x - 28.0, 9.0, 0.75):
		CellOutzType.draw_condensed(self, panel.position + Vector2(14, y), line, 9.0, INK * Color(1, 1, 1, 0.72), 0.75)
		y += 14.0
