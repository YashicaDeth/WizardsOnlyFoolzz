extends Control

## The World Index, rebuilt as a made object.
##
## Greg's verdict on the old one was "the world index needs a UI badly it looks
## shit", and he was being generous: it was a `PanelContainer` with one
## default-font `Label` in it and newline-joined prose. It was the single
## clearest piece of evidence in the game that this was an engine project rather
## than a game, and it was showing the most interesting data in the build.
##
## Three pages, because Greg asked for three things that turned out to be one
## thing — a dossier, a faction rank pyramid, and the Wire. They share a body of
## data (`WorldHistory` subjects) and a reading order, so they share a frame:
##
##   FILE      the dossier. Who this is, what is wrong with them, what happened.
##   PYRAMID   the faction as a recruitment scheme. Rank, downline, vacancies.
##   WIRE      the surviving internet. Reach, the feed, and who will not answer.
##
## `ART-DIRECTION.md` asks for interfaces that are physical — framed, screwed
## down, worn. So this is drawn as a salvaged plate: notched corners, fixings,
## a taped-on label, dead pixels in a fixed pattern and scanlines over the top.
## Headers and numerals are set in `CellOutzType`; body copy stays in a real
## font because a stencil alphabet is for stamps, not paragraphs.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const WireNetScript := preload("res://systems/wire_net.gd")
const Grunge := preload("res://systems/celloutz_grunge.gd")
const XrayCursor := preload("res://systems/xray_cursor.gd")
const SUBJECT_ICON := preload("res://systems/subject_icon.gd")
const BODY_INSPECTOR := preload("res://systems/body_inspector.gd")

## Six live 3D heads is cheap; sixty would not be, and each icon owns a World3D.
## So they are a pool the pages draw into by slot rather than one per row.
const ICON_POOL := 6

const INK := Color("e6d4ac")
const COPPER := Color("b0552a")
const HOT := Color("a8281a")
const MOSS := Color("8a9a4a")
const SPORE := Color("7f9440")
const BRUISE := Color("6b3f6e")
const SMOKE := Color(0.042, 0.032, 0.024, 0.96)
const GROUND := Color(0.035, 0.026, 0.019, 0.90)

const PAGES := ["FILE", "PYRAMID", "WIRE", "BODY"]

var page := 0
var rail_index := 0
var feed_scroll := 0.0
var elapsed := 0.0
var wire = null
var posts: Array = []
var last_action := ""
var action_life := 0.0

var xray := false
var cursor_at := Vector2(640, 360)
## Capture harnesses park the cursor deliberately; a headless run has no real
## pointer, so following one puts the drawn cursor at the canvas origin.
var cursor_follows_mouse := true
var page_blend := 1.0
var page_direction := 1.0
var _icons: Array = []
var _inspector: Node
var _rail_cache: Array = []
var _dead_pixels: Array = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Offsets as well as anchors. A Control parented straight to a CanvasLayer
	# has no parent rect to inherit from, so anchors alone leave it at zero size
	# and `_draw` bails on its own minimum-size guard without drawing anything.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	# A fixed pattern, generated once. Dead pixels that move every frame read as
	# an effect; dead pixels that stay read as a broken screen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	for index in 26:
		_dead_pixels.append(Vector2(rng.randf(), rng.randf()))
	_inspector = BODY_INSPECTOR.new()
	_inspector.name = "BodyInspector"
	add_child(_inspector)
	for slot in ICON_POOL:
		var icon: SubViewport = SUBJECT_ICON.new()
		icon.name = "SubjectIcon%d" % slot
		add_child(icon)
		_icons.append(icon)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	refresh()
	queue_redraw()


func close() -> void:
	visible = false


## Rebuilt on open rather than per frame: the Wire derives accounts from every
## subject and every event, which is not work to repeat sixty times a second for
## a panel whose data only changes when the world does.
func refresh() -> void:
	wire = WireNetScript.new(WireNetScript.SIGNAL_SURFACE)
	posts = wire.feed(20)
	_rebuild_rail()
	rail_index = clampi(rail_index, 0, maxi(0, _rail_cache.size() - 1))


func _rebuild_rail() -> void:
	_rail_cache.clear()
	match page:
		0, 3:
			for subject_id in WorldHistory.all_subjects():
				var subject: Dictionary = WorldHistory.subject(subject_id)
				if str(subject.get("kind", "person")) != "person":
					continue
				_rail_cache.append({"id": subject_id, "label": str(subject.get("name", subject_id)), "note": str(subject.get("role", ""))})
		1:
			for faction_id in wire.factions():
				var faction: Dictionary = WorldHistory.subject(faction_id)
				_rail_cache.append({"id": faction_id, "label": str(faction.get("name", faction_id)), "note": str(faction.get("threat", "UNKNOWN"))})
		2:
			for account in wire.accounts_by_reach():
				var note := str(account.tier)
				if str(account.id) == "player":
					note += "  \u00b7  YOU"
				_rail_cache.append({"id": str(account.id), "label": str(account.name), "note": note})


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	action_life = maxf(0.0, action_life - delta)
	page_blend = minf(1.0, page_blend + delta * 4.4)
	if cursor_follows_mouse:
		cursor_at = get_global_mouse_position()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Arrow keys only, deliberately. WASD would drive the car underneath the
	# panel: the chassis reads `Input.is_action_pressed` in `_physics_process`,
	# which does not care that the event was marked handled here.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				_go_to_page((page + PAGES.size() - 1) % PAGES.size(), -1.0)
			KEY_RIGHT:
				_go_to_page((page + 1) % PAGES.size(), 1.0)
			KEY_UP:
				rail_index = maxi(0, rail_index - 1)
			KEY_DOWN:
				rail_index = mini(_rail_cache.size() - 1, rail_index + 1)
			KEY_TAB:
				if page != 3 or not _inspector.handle_key(KEY_TAB):
					return
			KEY_X:
				_set_xray(not xray)
			KEY_1, KEY_2, KEY_3, KEY_4:
				var target: int = event.keycode - KEY_1
				_go_to_page(target, 1.0 if target > page else -1.0)
			_:
				return
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and XrayCursor.on_button(cursor_at, event.position):
			_set_xray(not xray)
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and page == 3:
			if not _inspector.handle_click(event.position):
				return
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			feed_scroll = minf(feed_scroll + 42.0, maxf(0.0, float(posts.size()) * 80.0 - 320.0))
			if wire:
				wire.scroll(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			feed_scroll = maxf(0.0, feed_scroll - 42.0)
		else:
			return
		get_viewport().set_input_as_handled()
		queue_redraw()


## Binds a pooled icon to a subject and draws it at `rect`. Returns false when
## the pool is exhausted so a caller can lay out around a missing icon rather
## than assuming one is always there.
func _draw_icon(slot: int, subject_id: String, rect: Rect2) -> bool:
	if slot >= _icons.size():
		return false
	var icon: SubViewport = _icons[slot]
	var subject: Dictionary = WorldHistory.subject(subject_id)
	if subject.is_empty():
		return false
	icon.set_subject(subject, _subject_tone(subject))
	icon.set_xray(xray)
	# A frame under the icon, so it reads as a plate set into the panel rather
	# than a floating render with a transparent background.
	draw_rect(rect, Color(0, 0, 0, 0.35))
	draw_texture_rect(icon.get_texture(), rect, false)
	var corner := rect.size.x * 0.22
	var accent := HOT if xray else COPPER
	draw_polyline(PackedVector2Array([
		rect.position + Vector2(0, corner), rect.position, rect.position + Vector2(corner, 0),
	]), accent * Color(1, 1, 1, 0.7), 1.4)
	draw_polyline(PackedVector2Array([
		rect.position + rect.size - Vector2(0, corner), rect.position + rect.size, rect.position + rect.size - Vector2(corner, 0),
	]), accent * Color(1, 1, 1, 0.7), 1.4)
	return true


## Colour a subject by where they sit on the Tree axis, so a row of icons is
## already telling you something before you read a single word.
func _subject_tone(subject: Dictionary) -> Color:
	var alignment: float = WorldHistory.tree_alignment(subject)
	if alignment > 0.15:
		return SPORE
	if alignment < -0.15:
		return HOT
	return COPPER


func _set_xray(on: bool) -> void:
	xray = on
	for icon in _icons:
		icon.set_xray(xray)


func _go_to_page(target: int, direction: float) -> void:
	if target == page:
		return
	page = target
	page_direction = direction
	page_blend = 0.0
	rail_index = 0
	feed_scroll = 0.0
	_rebuild_rail()


func _selected() -> Dictionary:
	if _rail_cache.is_empty():
		return {}
	return _rail_cache[clampi(rail_index, 0, _rail_cache.size() - 1)]


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var viewport := size
	if viewport.x < 640.0 or viewport.y < 400.0:
		viewport = get_viewport_rect().size
	if viewport.x < 640.0 or viewport.y < 400.0:
		return
	draw_rect(Rect2(Vector2.ZERO, viewport), GROUND)
	var plate := Rect2(Vector2(54, 44), viewport - Vector2(108, 88))
	_draw_plate(plate)
	_draw_header(plate)
	var body := Rect2(plate.position + Vector2(22, 122), plate.size - Vector2(44, 176))
	var rail := Rect2(body.position, Vector2(246, body.size.y))
	var panel := Rect2(body.position + Vector2(262, 0), body.size - Vector2(262, 0))
	_draw_rail(rail)
	# Ease-out on the incoming page, offset along the direction of travel. The
	# transform is pushed rather than every draw call being offset by hand, so
	# the page functions stay unaware that they are mid-transition.
	var eased := 1.0 - pow(1.0 - clampf(page_blend, 0.0, 1.0), 3.0)
	var slide := (1.0 - eased) * page_direction * 46.0
	draw_set_transform(Vector2(slide, 0.0), 0.0, Vector2.ONE)
	match page:
		0:
			_draw_file(panel)
		1:
			_draw_pyramid(panel)
		2:
			_draw_wire(panel)
		3:
			_draw_body(panel)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if page_blend < 1.0:
		_draw_page_wipe(panel, eased)
	_draw_stamp(plate)
	_draw_footer(plate)
	_draw_gore(plate)
	_draw_screen_decay(plate)
	Grunge.grain(self, plate, 907, 900)
	XrayCursor.draw(self, cursor_at, xray, elapsed)


## The plate itself. Notched top-left and bottom-right so the outline is never a
## rectangle, fixings at the corners, and a strip of tape somebody labelled by
## hand — the difference between a panel and an object.
func _draw_plate(rect: Rect2) -> void:
	var notch := 26.0
	var body := PackedVector2Array([
		rect.position + Vector2(notch, 0),
		rect.position + Vector2(rect.size.x, 0),
		rect.position + Vector2(rect.size.x, rect.size.y - notch),
		rect.position + Vector2(rect.size.x - notch, rect.size.y),
		rect.position + Vector2(0, rect.size.y),
		rect.position + Vector2(0, notch),
	])
	draw_colored_polygon(body, SMOKE)
	# Grime goes down before anything else is printed on it, so the interface
	# reads as ink on a dirty surface rather than dirt laid over a clean screen.
	Grunge.stain(self, rect.position + rect.size * Vector2(0.16, 0.78), 96.0, 11, Grunge.BILE, 0.05)
	Grunge.stain(self, rect.position + rect.size * Vector2(0.74, 0.20), 118.0, 27, Grunge.RUST, 0.042)
	Grunge.stain(self, rect.position + rect.size * Vector2(0.50, 0.95), 78.0, 43, Grunge.SPORE, 0.038)
	Grunge.scratches(self, rect, 61, 22)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, COPPER * Color(1, 1, 1, 0.62), 2.0)
	# An inner scribe line, offset unevenly, so the edge has depth without a bevel.
	draw_polyline(PackedVector2Array([
		rect.position + Vector2(7, notch + 6),
		rect.position + Vector2(7, rect.size.y - 7),
		rect.position + Vector2(rect.size.x - notch - 6, rect.size.y - 7),
	]), INK * Color(1, 1, 1, 0.12), 1.0)
	# Inset past the notches, or the top-left fixing sits in the cut corner.
	for corner in [rect.position + Vector2(38, 20), rect.position + Vector2(rect.size.x - 18, 20), rect.position + Vector2(18, rect.size.y - 18), rect.position + Vector2(rect.size.x - 38, rect.size.y - 16)]:
		draw_circle(corner, 4.0, Color(0.10, 0.07, 0.06, 1.0))
		draw_arc(corner, 4.0, 0, TAU, 12, INK * Color(1, 1, 1, 0.30), 1.0)
		draw_line(corner + Vector2(-2.4, -2.4), corner + Vector2(2.4, 2.4), INK * Color(1, 1, 1, 0.34), 1.0)
	# Tape torn off crooked and labelled by hand. Drawn as a skewed polygon
	# rather than a rect, because a perfectly axis-aligned strip reads as a
	# rounded card again — the exact thing this panel exists to stop being.
	var tape_at := rect.position + Vector2(rect.size.x - 268, -11)
	var tape := PackedVector2Array([
		tape_at, tape_at + Vector2(162, 3), tape_at + Vector2(159, 25), tape_at + Vector2(-2, 22),
	])
	draw_colored_polygon(tape, Color(0.80, 0.74, 0.55, 0.19))
	var tape_edge := tape.duplicate()
	tape_edge.append(tape[0])
	draw_polyline(tape_edge, Color(0.80, 0.74, 0.55, 0.34), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, tape_at + Vector2(11, 17), "do not lose this one", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.62))


func _draw_header(plate: Rect2) -> void:
	# Vertical spacing here is not decoration. `CellOutzType.draw_text` places a
	# glyph's *cap line* at `at.y` and draws downward; `draw_string` places the
	# *baseline* at its y and draws upward. Mixing the two conventions without
	# accounting for it is what had the title, the subtitle and the page tabs all
	# printing through each other in the first capture of this panel.
	var origin := plate.position + Vector2(24, 28)
	CellOutzType.draw_stamped(self, origin, "WORLD INDEX", 24.0, COPPER, HOT * Color(1, 1, 1, 0.34), 1.6)
	var font := ThemeDB.fallback_font
	draw_string(font, plate.position + Vector2(26, 70), "CELLOUTZ SUBJECT REGISTRY — ASHBLOOM EXPANSE — ACCESS: PROVISIONAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.46))
	var code := "CZ-01/WI  REV %02d" % (WorldHistory.next_sequence % 100)
	var code_width := CellOutzType.width(code, 12.0, 0.8)
	CellOutzType.draw_text(self, Vector2(plate.position.x + plate.size.x - 24 - code_width, plate.position.y + 32), code, 12.0, INK * Color(1, 1, 1, 0.42), 0.8)
	# Page tabs, drawn as physical selector keys rather than underlined text.
	var tab_x := plate.position.x + 24.0
	var tab_y := plate.position.y + 82.0
	for index in PAGES.size():
		var label: String = PAGES[index]
		var width := CellOutzType.width(label, 13.0, 1.2) + 30.0
		var active := index == page
		var accent: Color = COPPER if active else INK * Color(1, 1, 1, 0.32)
		var shape := PackedVector2Array([
			Vector2(tab_x, tab_y), Vector2(tab_x + width, tab_y),
			Vector2(tab_x + width - 7, tab_y + 26), Vector2(tab_x + 7, tab_y + 26),
		])
		if active:
			draw_colored_polygon(shape, COPPER * Color(1, 1, 1, 0.20))
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, accent, 1.4)
		CellOutzType.draw_text(self, Vector2(tab_x + 15, tab_y + 7), label, 13.0, INK if active else accent, 1.2)
		if active:
			draw_line(Vector2(tab_x + 7, tab_y + 27), Vector2(tab_x + width - 7, tab_y + 27), HOT, 2.0)
		tab_x += width + 10.0


## The rail is the same in all three pages because the reading order is the
## same: pick a thing on the left, read it on the right. Three different
## navigation models across three pages of one object was the old problem.
func _draw_rail(rect: Rect2) -> void:
	draw_line(rect.position + Vector2(rect.size.x + 8, 0), rect.position + Vector2(rect.size.x + 8, rect.size.y), INK * Color(1, 1, 1, 0.14), 1.0)
	var heading: String = ["SUBJECTS", "FACTIONS", "ACCOUNTS", "BODIES"][page]
	CellOutzType.draw_text(self, rect.position + Vector2(0, 0), heading, 12.0, MOSS, 1.4)
	draw_line(rect.position + Vector2(0, 18), rect.position + Vector2(rect.size.x - 14, 18), MOSS * Color(1, 1, 1, 0.35), 1.0)
	var font := ThemeDB.fallback_font
	var y := rect.position.y + 36.0
	for index in _rail_cache.size():
		if y > rect.position.y + rect.size.y - 18.0:
			break
		var entry: Dictionary = _rail_cache[index]
		var active := index == rail_index
		if active:
			draw_colored_polygon(PackedVector2Array([
				Vector2(rect.position.x - 6, y - 13), Vector2(rect.position.x + rect.size.x - 14, y - 13),
				Vector2(rect.position.x + rect.size.x - 20, y + 15), Vector2(rect.position.x - 6, y + 15),
			]), COPPER * Color(1, 1, 1, 0.17))
			draw_line(Vector2(rect.position.x - 6, y - 13), Vector2(rect.position.x - 6, y + 15), HOT, 2.5)
		draw_string(font, Vector2(rect.position.x + 4, y), str(entry.label), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 26, 14, INK if active else INK * Color(1, 1, 1, 0.72))
		draw_string(font, Vector2(rect.position.x + 4, y + 13), str(entry.note).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 26, 9, COPPER * Color(1, 1, 1, 0.8) if active else INK * Color(1, 1, 1, 0.34))
		y += 34.0


# --- page one: the dossier -------------------------------------------------

func _draw_file(rect: Rect2) -> void:
	var entry := _selected()
	var font := ThemeDB.fallback_font
	if entry.is_empty():
		draw_string(font, rect.position + Vector2(0, 20), "NO SUBJECT ON FILE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK * Color(1, 1, 1, 0.5))
		return
	var subject: Dictionary = WorldHistory.subject(str(entry.id))
	CellOutzType.draw_stamped(self, rect.position, str(subject.get("name", entry.id)).to_upper(), 21.0, INK, COPPER * Color(1, 1, 1, 0.3), 1.4)
	draw_string(font, rect.position + Vector2(2, 44), "%s   ·   %s" % [str(subject.get("role", "unindexed")).to_upper(), str(subject.get("faction", "Unbound")).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COPPER)

	# Four readings across the top. Numerals in the display face because they are
	# what the eye goes to first.
	var stats := [
		{"label": "ELO", "value": "%04d" % int(subject.get("elo", 1000)), "tone": MOSS},
		{"label": "GRUDGE", "value": "%03d" % int(subject.get("grudge", 0)), "tone": HOT},
		{"label": "BOND", "value": "%03d" % int(subject.get("bond", 0)), "tone": SPORE},
		{"label": "REACH", "value": "%05d" % int((wire.account(str(entry.id)) as Dictionary).get("reach", 0)), "tone": BRUISE},
	]
	var x := rect.position.x
	for stat in stats:
		CellOutzType.draw_text(self, Vector2(x, rect.position.y + 62), str(stat.label), 9.0, INK * Color(1, 1, 1, 0.45), 1.0)
		CellOutzType.draw_text(self, Vector2(x, rect.position.y + 78), str(stat.value), 19.0, stat.tone, 1.0)
		x += 108.0
	_draw_icon(0, str(entry.id), Rect2(rect.position + Vector2(rect.size.x - 118, -10), Vector2(110, 110)))
	draw_line(rect.position + Vector2(0, 112), rect.position + Vector2(rect.size.x, 112), INK * Color(1, 1, 1, 0.16), 1.0)

	var column := rect.size.x * 0.56
	var right_x := rect.position.x + rect.size.x * 0.60
	var right_width := rect.size.x * 0.40

	# The Tree axis. It exists, it is already computed, and nothing showed it.
	var alignment: float = WorldHistory.tree_alignment(subject)
	_draw_axis(Rect2(rect.position + Vector2(0, 130), Vector2(column, 52)), alignment, str(WorldHistory.tree_descriptor(subject)))

	# Memory, set as a quotation rather than a field, because it is the one piece
	# of a dossier that is somebody's account rather than a measurement.
	var memory := str(subject.get("memory", ""))
	var left_y := rect.position.y + 208.0
	if memory != "":
		draw_line(Vector2(rect.position.x, left_y - 13), Vector2(rect.position.x + 3, left_y + 24), COPPER, 2.0)
		for line in _wrap(memory, 54):
			draw_string(font, Vector2(rect.position.x + 14, left_y), str(line), HORIZONTAL_ALIGNMENT_LEFT, column - 14, 13, INK * Color(1, 1, 1, 0.86))
			left_y += 17.0
		left_y += 16.0

	# Relations. Real data on every subject that nothing in the game displayed,
	# and the edges the Hunt System propagates grudges along - so this is the
	# closest thing the build currently has to a view of that machinery.
	var relations: Dictionary = subject.get("relations", {})
	if not relations.is_empty():
		CellOutzType.draw_text(self, Vector2(rect.position.x, left_y), "KNOWN EDGES", 11.0, MOSS, 1.2)
		draw_line(Vector2(rect.position.x, left_y + 17), Vector2(rect.position.x + column, left_y + 17), MOSS * Color(1, 1, 1, 0.3), 1.0)
		left_y += 36.0
		for other in relations:
			if left_y > rect.position.y + rect.size.y - 92.0:
				break
			var edge: Dictionary = relations[other]
			var kind := str(edge.get("kind", "known"))
			var strength := int(edge.get("strength", 0))
			var other_subject: Dictionary = WorldHistory.subject(str(other))
			var other_name := str(other_subject.get("name", other)).to_upper()
			var tone: Color = HOT if kind in ["grudge", "hunts", "enemy"] else (SPORE if kind in ["bond", "saved", "ally"] else INK)
			draw_string(font, Vector2(rect.position.x + 2, left_y), other_name, HORIZONTAL_ALIGNMENT_LEFT, column * 0.50, 12, INK * Color(1, 1, 1, 0.82))
			draw_string(font, Vector2(rect.position.x + column * 0.52, left_y), kind.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, column * 0.26, 11, tone)
			# A short bar, because a strength of 72 and a strength of 8 should not
			# look the same at a glance.
			var bar_x := rect.position.x + column * 0.80
			draw_line(Vector2(bar_x, left_y - 4), Vector2(bar_x + column * 0.18, left_y - 4), INK * Color(1, 1, 1, 0.12), 4.0)
			draw_line(Vector2(bar_x, left_y - 4), Vector2(bar_x + column * 0.18 * clampf(float(strength) / 100.0, 0.0, 1.0), left_y - 4), tone, 4.0)
			left_y += 19.0

	# Right column: what is wrong with them, and what is bolted into them.
	var wy := rect.position.y + 130.0
	CellOutzType.draw_text(self, Vector2(right_x, wy), "CONDITION", 11.0, MOSS, 1.2)
	draw_line(Vector2(right_x, wy + 17), Vector2(right_x + right_width, wy + 17), MOSS * Color(1, 1, 1, 0.3), 1.0)
	wy += 36.0
	var condition := str(subject.get("injury", ""))
	var lines: Array = []
	if condition != "" and condition != "none":
		lines.append(condition)
	for wound in subject.get("wounds", []):
		if not lines.has(str(wound)):
			lines.append(str(wound))
	if lines.is_empty():
		lines.append("no recorded damage")
	for line in lines:
		draw_string(font, Vector2(right_x, wy), "— %s" % str(line), HORIZONTAL_ALIGNMENT_LEFT, right_width, 12, HOT * Color(1, 1, 1, 0.9))
		wy += 17.0
	var anatomy: Dictionary = subject.get("anatomy", {})
	var cybernetics: Array = anatomy.get("cybernetics", [])
	if not cybernetics.is_empty():
		wy += 18.0
		CellOutzType.draw_text(self, Vector2(right_x, wy), "INSTALLED", 11.0, BRUISE.lerp(INK, 0.3), 1.2)
		draw_line(Vector2(right_x, wy + 17), Vector2(right_x + right_width, wy + 17), BRUISE * Color(1, 1, 1, 0.4), 1.0)
		wy += 36.0
		for part in cybernetics:
			draw_string(font, Vector2(right_x, wy), "+ %s" % str(part), HORIZONTAL_ALIGNMENT_LEFT, right_width, 12, BRUISE.lerp(INK, 0.55))
			wy += 17.0
	var blood := str(anatomy.get("blood_type", ""))
	if blood != "":
		wy += 14.0
		draw_string(font, Vector2(right_x, wy), "BLOOD %s" % blood.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, right_width, 11, INK * Color(1, 1, 1, 0.45))

	# History, across the full width at the foot, wrapping into columns.
	var hy := rect.position.y + rect.size.y - 76.0
	CellOutzType.draw_text(self, Vector2(rect.position.x, hy), "WHAT THE WORLD RECORDED", 11.0, MOSS, 1.2)
	draw_line(Vector2(rect.position.x, hy + 17), Vector2(rect.position.x + rect.size.x, hy + 17), MOSS * Color(1, 1, 1, 0.3), 1.0)
	var base_y := hy + 36.0
	var shown := 0
	for event in WorldHistory.recent_events(30):
		if shown >= 6:
			break
		var details: Dictionary = event.get("details", {})
		var names := false
		for key in details:
			if str(details[key]) == str(entry.id):
				names = true
		if not names:
			continue
		var col := shown / 3
		var row := shown % 3
		var ex := rect.position.x + float(col) * rect.size.x * 0.34
		var ey := base_y + float(row) * 19.0
		CellOutzType.draw_text(self, Vector2(ex, ey - 10), "%04d" % int(event.get("sequence", 0)), 11.0, COPPER * Color(1, 1, 1, 0.7), 0.6)
		draw_string(font, Vector2(ex + 44, ey), str(event.get("type", "unknown")).replace("_", " ").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.30, 12, INK * Color(1, 1, 1, 0.78))
		shown += 1
	if shown == 0:
		draw_string(font, Vector2(rect.position.x, base_y), "NOTHING ABOUT THEM HAS BEEN WRITTEN DOWN YET.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK * Color(1, 1, 1, 0.4))


## Naive word wrap. The memory line is the only free prose on the panel and it
## is authored, so a width in characters is honest enough and avoids measuring
## every substring against the font.
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


## Ascent above, Descent below, the subject's mark between them. Drawn vertically
## because the whole motif is AS ABOVE, SO BELOW and a horizontal slider would
## quietly throw that away.
func _draw_axis(rect: Rect2, alignment: float, descriptor: String) -> void:
	var font := ThemeDB.fallback_font
	CellOutzType.draw_text(self, rect.position, "TREE AXIS", 10.0, MOSS, 1.2)
	var track_y := rect.position.y + 30.0
	var left := rect.position.x
	var right := rect.position.x + rect.size.x - 12.0
	draw_line(Vector2(left, track_y), Vector2(right, track_y), INK * Color(1, 1, 1, 0.18), 3.0)
	for index in 11:
		var tx := lerpf(left, right, float(index) / 10.0)
		draw_line(Vector2(tx, track_y - 4), Vector2(tx, track_y + 4), INK * Color(1, 1, 1, 0.16), 1.0)
	var mark := lerpf(left, right, clampf((alignment + 1.0) * 0.5, 0.0, 1.0))
	var tone := SPORE if alignment > 0.15 else (HOT if alignment < -0.15 else INK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(mark, track_y - 10), Vector2(mark + 7, track_y), Vector2(mark, track_y + 10), Vector2(mark - 7, track_y),
	]), tone)
	draw_string(font, Vector2(left, track_y + 22), "DESCENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, HOT * Color(1, 1, 1, 0.7))
	draw_string(font, Vector2(right - 46, track_y + 22), "ASCENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, SPORE * Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(left, rect.position.y + 10), descriptor.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 12, 10, tone)


# --- page two: the rank pyramid --------------------------------------------

## Greg asked for "ranks and pyramid scheme conspiracy" as one object, and the
## data for it already existed — command relation strength is a real ladder and
## a dead officer leaves a real hole. So the satire is in the presentation
## (buy-in, downline, an OPPORTUNITY where a person used to be) while every
## number under it is read from `WorldHistory`.
func _draw_pyramid(rect: Rect2) -> void:
	var entry := _selected()
	var font := ThemeDB.fallback_font
	if entry.is_empty():
		draw_string(font, rect.position + Vector2(0, 20), "NO FACTION SELECTED.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK * Color(1, 1, 1, 0.5))
		return
	var data: Dictionary = wire.pyramid(str(entry.id))
	CellOutzType.draw_stamped(self, rect.position + Vector2(0, 4), str(data.name).to_upper(), 21.0, INK, HOT * Color(1, 1, 1, 0.3), 1.4)
	draw_string(font, rect.position + Vector2(2, 38), "THREAT %s   ·   %s   ·   %d ON THE BOOKS" % [str(data.threat), str(data.territory).to_upper(), int(data.headcount)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COPPER)
	draw_string(font, rect.position + Vector2(2, 58), "\"%s\"" % str(data.doctrine), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 12, INK * Color(1, 1, 1, 0.6))

	var tiers: Array = data.tiers
	var top := rect.position.y + 84.0
	var row_height := minf(64.0, (rect.size.y - 110.0) / float(maxi(1, tiers.size())))
	for index in tiers.size():
		var tier: Dictionary = tiers[index]
		var members: Array = tier["members"]
		# The width is the pyramid: narrow at the crown, wide at intake.
		var span := lerpf(rect.size.x * 0.46, rect.size.x * 0.96, float(index) / float(maxi(1, tiers.size() - 1)))
		var cx := rect.position.x + rect.size.x * 0.5
		var y := top + float(index) * row_height
		var vacant := members.is_empty()
		var accent: Color = HOT if vacant else [COPPER, COPPER, MOSS, MOSS, INK][mini(index, 4)]
		var shape := PackedVector2Array([
			Vector2(cx - span * 0.5 + 10, y), Vector2(cx + span * 0.5 - 10, y),
			Vector2(cx + span * 0.5, y + row_height - 8), Vector2(cx - span * 0.5, y + row_height - 8),
		])
		draw_colored_polygon(shape, accent * Color(1, 1, 1, 0.10 if not vacant else 0.16))
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, accent * Color(1, 1, 1, 0.75), 1.4)
		var rank_x := cx - span * 0.5 + (82.0 if not members.is_empty() else 18.0)
		CellOutzType.draw_text(self, Vector2(rank_x, y + 8), str(tier["rank"]), 11.0, accent, 1.2)
		var buy_in := "BUY-IN %d" % int(tier["buy_in"])
		var buy_width := CellOutzType.width(buy_in, 9.0, 0.8)
		CellOutzType.draw_text(self, Vector2(cx + span * 0.5 - 18 - buy_width, y + 9), buy_in, 9.0, INK * Color(1, 1, 1, 0.42), 0.8)
		if vacant:
			var claimant := ""
			for vacancy in data.vacancies:
				if str((vacancy as Dictionary).rank) == str(tier["rank"]):
					claimant = str((vacancy as Dictionary).claimant)
			var pitch := "OPPORTUNITY — POST UNFILLED"
			if claimant != "":
				pitch = "OPPORTUNITY — %s IS POSITIONED FOR IT" % claimant.to_upper()
			draw_string(font, Vector2(cx - span * 0.5 + 18, y + 34), pitch, HORIZONTAL_ALIGNMENT_LEFT, span - 36, 12, HOT)
		else:
			var names: Array = []
			for member in members:
				names.append(str((member as Dictionary).name))
			var downline := "DOWNLINE %02d" % int(tier["downline"])
			var down_width := CellOutzType.width(downline, 10.0, 0.9)
			# The crown tier is the narrowest row and usually holds the longest
			# names, so the room left after the downline figure has to be measured
			# rather than assumed - a fixed 130px reservation printed "Dray Kell,
			# Mara Voss" straight through "DOWNLINE 02".
			var room := span - 36.0 - down_width - 16.0
			var label := ", ".join(names)
			while names.size() > 1 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > room:
				names.resize(names.size() - 1)
				label = ", ".join(names) + "  +%d" % (members.size() - names.size())
			# The tier's lead member gets a turning head at the left edge of the
			# row. Greg's ask: the people in the hierarchy should be present as
			# objects, not as text in a table.
			var lead: Dictionary = members[0]
			var icon_size := minf(row_height - 12.0, 48.0)
			var has_icon := _draw_icon(index, str(lead.id), Rect2(Vector2(cx - span * 0.5 + 16, y + 4), Vector2(icon_size, icon_size)))
			var text_x := cx - span * 0.5 + (18.0 + icon_size + 10.0 if has_icon else 18.0)
			draw_string(font, Vector2(text_x, y + 40), label, HORIZONTAL_ALIGNMENT_LEFT, room - icon_size - 10.0, 13, INK * Color(1, 1, 1, 0.88))
			CellOutzType.draw_text(self, Vector2(cx + span * 0.5 - 18 - down_width, y + 30), downline, 10.0, SPORE * Color(1, 1, 1, 0.8), 0.9)

	var fy := top + float(tiers.size()) * row_height + 12.0
	if fy < rect.position.y + rect.size.y - 16.0:
		draw_string(font, Vector2(rect.position.x, fy + 12), "ADVANCEMENT IS BY REMEMBERED IMPACT. RECRUIT TWO AND YOUR POSITION IS SECURE.", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 11, COPPER * Color(1, 1, 1, 0.62))
		draw_string(font, Vector2(rect.position.x, fy + 28), "CELLOUTZ IS NOT RESPONSIBLE FOR POSITIONS HELD BY THE DECEASED.", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 10, INK * Color(1, 1, 1, 0.32))


# --- page three: the Wire ---------------------------------------------------

func _draw_wire(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var entry := _selected()
	var split := rect.size.x * 0.46
	# Left of the split: the account you have selected, and whether it will
	# answer you. Right: the feed, which is not sorted for your benefit.
	if not entry.is_empty():
		var account: Dictionary = wire.account(str(entry.id))
		CellOutzType.draw_stamped(self, rect.position + Vector2(0, 4), str(account.get("name", "")).to_upper(), 18.0, INK, COPPER * Color(1, 1, 1, 0.28), 1.2)
		draw_string(font, rect.position + Vector2(2, 34), str(account.get("handle", "")), HORIZONTAL_ALIGNMENT_LEFT, split, 12, MOSS)
		if bool(account.get("verified", false)):
			var badge := rect.position + Vector2(split - 30, 16)
			draw_colored_polygon(PackedVector2Array([
				badge + Vector2(0, -9), badge + Vector2(9, 0), badge + Vector2(0, 9), badge + Vector2(-9, 0),
			]), MOSS * Color(1, 1, 1, 0.85))
			draw_string(font, badge + Vector2(-3, 4), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.05, 0.05))
		_draw_icon(0, str(entry.id), Rect2(Vector2(rect.position.x + split - 116, rect.position.y + 36), Vector2(92, 92)))
		CellOutzType.draw_text(self, rect.position + Vector2(0, 52), "REACH", 9.0, INK * Color(1, 1, 1, 0.45), 1.0)
		CellOutzType.draw_text(self, rect.position + Vector2(0, 66), "%06d" % int(account.get("reach", 0)), 20.0, COPPER, 1.0)
		CellOutzType.draw_text(self, rect.position + Vector2(146, 52), "TIER", 9.0, INK * Color(1, 1, 1, 0.45), 1.0)
		CellOutzType.draw_text(self, rect.position + Vector2(146, 66), str(account.get("tier", "")), 16.0, BRUISE.lerp(INK, 0.4), 1.0)
		draw_string(font, rect.position + Vector2(2, 104), "LAST SEEN %s" % str(account.get("last_seen", "")), HORIZONTAL_ALIGNMENT_LEFT, split, 11, INK * Color(1, 1, 1, 0.55))
		var bought := int(account.get("manufactured", 0))
		if bought > 0:
			draw_string(font, rect.position + Vector2(2, 120), "ESTIMATED %d OF THAT WAS PURCHASED" % bought, HORIZONTAL_ALIGNMENT_LEFT, split, 10, HOT * Color(1, 1, 1, 0.7))

		# The contact readout. This is the page's argument: the number is not a
		# score, it is a door, and most doors are shut.
		var attempt: Dictionary = wire.contact(str(entry.id))
		var chance := float(attempt.get("chance", 0.0))
		var cy := rect.position.y + 146.0
		draw_line(Vector2(rect.position.x, cy - 8), Vector2(rect.position.x + split - 20, cy - 8), INK * Color(1, 1, 1, 0.16), 1.0)
		CellOutzType.draw_text(self, Vector2(rect.position.x, cy + 4), "WILL THEY READ YOU", 11.0, MOSS, 1.2)
		# `cy` is already absolute - adding `rect.position` to it again put this
		# meter 170px below the label it belongs to, at the bottom of the panel.
		var bar := Rect2(Vector2(rect.position.x, cy + 26), Vector2(split - 40, 12))
		draw_rect(bar, INK * Color(1, 1, 1, 0.10))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(chance, 0.0, 1.0), bar.size.y)), HOT.lerp(SPORE, clampf(chance, 0.0, 1.0)))
		draw_rect(bar, INK * Color(1, 1, 1, 0.22), false, 1.0)
		CellOutzType.draw_text(self, Vector2(bar.position.x + bar.size.x + 8, bar.position.y), "%02d" % roundi(chance * 100.0), 12.0, INK, 0.8)
		var ry := cy + 52.0
		for route in attempt.get("routes", []):
			draw_string(font, Vector2(rect.position.x + 2, ry + 12), "· %s" % str(route), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 11, SPORE)
			ry += 15.0
		if str(attempt.get("reason", "")) != "":
			draw_string(font, Vector2(rect.position.x + 2, ry + 14), str(attempt.get("reason", "")), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 11, HOT * Color(1, 1, 1, 0.85))
			ry += 18.0
		elif str(attempt.get("reply", "")) != "":
			draw_string(font, Vector2(rect.position.x + 2, ry + 14), "\"%s\"" % str(attempt.get("reply", "")), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 12, INK)
			ry += 20.0
		var lever: String = wire.leverage(str(entry.id))
		if lever != "":
			draw_string(font, Vector2(rect.position.x + 2, ry + 16), "HELD AGAINST THEM: %s" % lever.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 10, BRUISE.lerp(INK, 0.5))

		# Your own exposure, because everything on this page works both ways.
		var ey := rect.position.y + rect.size.y - 44.0
		draw_line(Vector2(rect.position.x, ey - 10), Vector2(rect.position.x + split - 20, ey - 10), INK * Color(1, 1, 1, 0.16), 1.0)
		CellOutzType.draw_text(self, Vector2(rect.position.x, ey + 2), "YOUR EXPOSURE", 10.0, HOT if wire.exposure >= 8 else INK * Color(1, 1, 1, 0.5), 1.1)
		CellOutzType.draw_text(self, Vector2(rect.position.x + 150, ey - 2), "%02d" % wire.exposure, 16.0, HOT if wire.exposure >= 8 else INK, 0.8)
		var trace: String = wire.pending_trace()
		if trace != "":
			draw_string(font, Vector2(rect.position.x + 2, ey + 26), "%s HAS YOUR PATTERN." % trace.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 11, HOT)

	# The feed.
	var feed := Rect2(rect.position + Vector2(split + 16, 0), Vector2(rect.size.x - split - 16, rect.size.y))
	draw_line(feed.position + Vector2(-10, 0), feed.position + Vector2(-10, feed.size.y), INK * Color(1, 1, 1, 0.14), 1.0)
	CellOutzType.draw_text(self, feed.position, "THE WIRE", 12.0, COPPER, 1.4)
	var strain_label := "STRAIN %02d" % roundi(wire.strain)
	var strain_width := CellOutzType.width(strain_label, 10.0, 0.8)
	CellOutzType.draw_text(self, Vector2(feed.position.x + feed.size.x - strain_width, feed.position.y + 2), strain_label, 10.0, BRUISE.lerp(HOT, clampf(wire.strain / 40.0, 0, 1)), 0.8)
	draw_line(feed.position + Vector2(0, 18), feed.position + Vector2(feed.size.x, 18), COPPER * Color(1, 1, 1, 0.3), 1.0)
	var y := feed.position.y + 34.0 - feed_scroll
	for post in posts:
		# A post is 60px tall. Breaking on its *start* let the last one print
		# through the footer and out of the plate entirely.
		if y + 62.0 > feed.position.y + feed.size.y:
			break
		if y > feed.position.y + 20.0:
			_draw_post(feed, post, y)
		y += 80.0


func _draw_post(feed: Rect2, post: Dictionary, y: float) -> void:
	var font := ThemeDB.fallback_font
	var kind := str(post.get("kind", "doom"))
	var tone: Color = {
		"report": COPPER, "doom": INK, "wellness": MOSS, "collage": BRUISE,
		"bait": INK, "bot": INK, "dead": INK, "lunch": SPORE, "underbelly": HOT,
	}.get(kind, INK)
	draw_line(Vector2(feed.position.x, y - 12), Vector2(feed.position.x + 2, y + 46), tone * Color(1, 1, 1, 0.55), 2.0)
	var author := str(post.get("author", "")).to_upper()
	draw_string(font, Vector2(feed.position.x + 12, y), author, HORIZONTAL_ALIGNMENT_LEFT, feed.size.x - 110, 11, tone)
	# Author, then the mark, then the handle - each measured off the last rather
	# than guessed at. Backing the mark off the handle by a fixed 14px printed it
	# through the final letters of every verified name.
	var cursor := feed.position.x + 12.0 + font.get_string_size(author, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6.0
	if bool(post.get("verified", false)):
		draw_circle(Vector2(cursor + 4, y - 4), 3.5, MOSS * Color(1, 1, 1, 0.9))
		cursor += 15.0
	draw_string(font, Vector2(cursor, y), str(post.get("handle", "")), HORIZONTAL_ALIGNMENT_LEFT, feed.size.x - 40, 10, INK * Color(1, 1, 1, 0.35))
	if kind == "underbelly":
		CellOutzType.draw_text(self, Vector2(feed.position.x + feed.size.x - 62, y - 9), "DEEP", 9.0, HOT, 1.0)
	# Two lines, wrapped. `draw_string` clips at its width rather than wrapping,
	# so every post longer than the column was being cut mid-word.
	var body_y := y + 18.0
	var wrapped := _wrap(str(post.get("body", "")), 62)
	for index in mini(2, wrapped.size()):
		var line := str(wrapped[index])
		if index == 1 and wrapped.size() > 2:
			line += "\u2026"
		draw_string(font, Vector2(feed.position.x + 12, body_y), line, HORIZONTAL_ALIGNMENT_LEFT, feed.size.x - 24, 12, INK * Color(1, 1, 1, 0.84))
		body_y += 15.0
	var meta := "%d REPLIES" % int(post.get("replies", 0))
	if int(post.get("hops", 0)) > 0:
		meta += "   \u00b7   %d RETELLINGS DEEP" % int(post.get("hops", 0))
	draw_string(font, Vector2(feed.position.x + 12, y + 52), meta, HORIZONTAL_ALIGNMENT_LEFT, feed.size.x - 24, 9, INK * Color(1, 1, 1, 0.3))
	draw_line(Vector2(feed.position.x + 12, y + 60), Vector2(feed.position.x + feed.size.x - 8, y + 60), INK * Color(1, 1, 1, 0.08), 1.0)


# --- page four: the body ---------------------------------------------------

## B1 and B2. The inspector owns its own state and its own 3D viewport and draws
## into this canvas, so the plate chrome and the scanlines stay on top of it
## rather than being covered by a child Control.
func _draw_body(rect: Rect2) -> void:
	var entry := _selected()
	if entry.is_empty():
		return
	_inspector.set_subject(WorldHistory.subject(str(entry.id)))
	_inspector.xray = xray
	_inspector.draw_into(self, rect)


# --- chrome ----------------------------------------------------------------

func _draw_footer(plate: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var y := plate.position.y + plate.size.y - 26.0
	draw_line(Vector2(plate.position.x + 22, y - 14), Vector2(plate.position.x + plate.size.x - 22, y - 14), INK * Color(1, 1, 1, 0.14), 1.0)
	draw_string(font, Vector2(plate.position.x + 24, y), "←/→ PAGE    ↑/↓ SELECT    WHEEL SCROLL    X X-RAY    I CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.55))
	var note := "THIS REGISTRY IS INCOMPLETE AND PARTS OF IT ARE WRONG."
	draw_string(font, Vector2(plate.position.x + 24, y), note, HORIZONTAL_ALIGNMENT_RIGHT, plate.size.x - 48, 10, COPPER * Color(1, 1, 1, 0.5))


## The sweep that covers a page change. A salvaged screen redrawing itself does
## not cut cleanly, it rolls - so the incoming page arrives behind a bar of
## brightness travelling in the direction you asked it to go.
func _draw_page_wipe(panel: Rect2, eased: float) -> void:
	var x := panel.position.x + panel.size.x * eased if page_direction > 0.0 else panel.position.x + panel.size.x * (1.0 - eased)
	var fade := (1.0 - eased) * 0.5
	draw_line(Vector2(x, panel.position.y - 14), Vector2(x, panel.position.y + panel.size.y), COPPER * Color(1, 1, 1, 0.55 + fade), 2.0)
	var band := 26.0 * page_direction
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, panel.position.y - 14), Vector2(x - band, panel.position.y - 14),
		Vector2(x - band, panel.position.y + panel.size.y), Vector2(x, panel.position.y + panel.size.y),
	]), INK * Color(1, 1, 1, fade * 0.28))


## Blood on the interface, not only in the world. The premise of the whole
## object is that it is a physical thing carried around a place where people get
## opened up, so it has been stood next to that happening. Fixed seeds: grime
## that reshuffles every frame reads as an effect rather than as dirt.
func _draw_gore(plate: Rect2) -> void:
	Grunge.spatter(self, plate.position + Vector2(plate.size.x * 0.70, plate.size.y * 0.30), 5, 22, Vector2(0.9, 0.42))
	Grunge.run_down(self, plate.position + Vector2(plate.size.x * 0.955, plate.size.y * 0.32), 88.0, 12)
	Grunge.run_down(self, plate.position + Vector2(plate.size.x * 0.975, plate.size.y * 0.28), 46.0, 19)
	Grunge.spatter(self, plate.position + Vector2(38, plate.size.y - 58), 31, 14, Vector2(-0.6, 0.7))
	# A dry thumbprint smear where somebody with wet hands held it.
	Grunge.stain(self, plate.position + Vector2(plate.size.x - 54, plate.size.y * 0.52), 26.0, 77, Grunge.DRIED, 0.20)


## The stamp a clerk hit the page with, per page, because this is a processed
## document in a system that does not care about the person it describes.
func _draw_stamp(plate: Rect2) -> void:
	var text: String = ["NO FIXED ABODE", "NO REFUNDS", "UNVERIFIED", "SPECIMEN"][page]
	var tint: Color = [Grunge.DRIED, Grunge.RUST, Grunge.BILE, Grunge.DRIED][page]
	Grunge.stamp(self, plate.position + Vector2(plate.size.x - 258, 92), text, 15.0, -0.16, tint, 300 + page)


## Scanlines, a fixed dead-pixel pattern and a slow horizontal tear. Cheap, and
## it does most of the work of making a drawn panel read as a screen somebody
## salvaged rather than a vector layout.
func _draw_screen_decay(plate: Rect2) -> void:
	var line_y := plate.position.y
	while line_y < plate.position.y + plate.size.y:
		draw_line(Vector2(plate.position.x, line_y), Vector2(plate.position.x + plate.size.x, line_y), Color(0, 0, 0, 0.10), 1.0)
		line_y += 3.0
	for point in _dead_pixels:
		var at := plate.position + Vector2(float(point.x) * plate.size.x, float(point.y) * plate.size.y)
		draw_rect(Rect2(at, Vector2(2, 2)), Color(0, 0, 0, 0.55))
	var tear := fmod(elapsed * 46.0, plate.size.y + 140.0) - 70.0
	if tear > 0.0 and tear < plate.size.y:
		draw_line(Vector2(plate.position.x, plate.position.y + tear), Vector2(plate.position.x + plate.size.x, plate.position.y + tear), INK * Color(1, 1, 1, 0.045), 3.0)
