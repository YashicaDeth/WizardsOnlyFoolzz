extends Control

## L2.1. Something on this page is worth putting on the wall.
signal pin_requested(ref: String, kind: String, title: String)

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
const Motion := preload("res://systems/celloutz_motion.gd")
const SUBJECT_ICON := preload("res://systems/subject_icon.gd")
const BODY_INSPECTOR := preload("res://systems/body_inspector.gd")
const ImplantCatalog := preload("res://systems/implant_catalog.gd")
const WoundCatalog := preload("res://systems/wound_catalog.gd")

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
## I1. The material the plate is cut out of, not a backdrop behind it.
var _rain: Array = []
var _rain_size := Vector2.ZERO
var wire = null
var posts: Array = []
var last_action := ""
var action_life := 0.0

var xray := false
var cursor_at := Vector2(640, 360)
## Capture harnesses park the cursor deliberately; a headless run has no real
## pointer, so following one puts the drawn cursor at the canvas origin.
var cursor_follows_mouse := true
## Suppressed when the panel is hosted inside the handheld: the device owns the
## frame there, and a second reticle floating in the aperture is just litter.
var show_cursor := true
## C5. The Wire's reach is decided by where the player is standing, not by a
## constant. Every caller used to pass SIGNAL_SURFACE, which made connectivity
## unconditional and quietly turned the whole design back into a menu.
var signal_grade := 1
var page_blend := 1.0
var page_direction := 1.0
## A8.2. The panel is an object arriving, not a visibility flag.
var open_blend := 0.0
var closing := false
## A8.3. The rail highlight travels to the row rather than teleporting onto it.
var highlight_y := 0.0
var rail_scroll := 0.0
var rail_scroll_target := 0.0
## A2.7. The index is searchable *and* incomplete, per the design.
var search_active := false
var search_query := ""
## A3.5. Where each pyramid member was drawn, so one can be clicked through to.
var _tier_rects: Array = []
## A4.5/A4.6. The last contact attempt and the last action, held rather than
## recomputed - see `_refresh_contact`.
var _contact: Dictionary = {}
var _contact_for := ""
var _last_action: Dictionary = {}
var _action_rects: Array = []
## I5. One list for everything the reader can point at that is not already a
## dedicated control. Collected during the draw that puts it on screen, so a
## thing is clickable exactly where it was printed and nothing has to keep a
## second layout in sync.
var _link_rects: Array = []
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
	closing = false
	open_blend = 0.0
	refresh()
	queue_redraw()


## A8.2. Closing runs the blend backwards and hides at the end of it, so the
## panel leaves rather than vanishing. `_process` finishes the job.
func close() -> void:
	closing = true


## Rebuilt on open rather than per frame: the Wire derives accounts from every
## subject and every event, which is not work to repeat sixty times a second for
## a panel whose data only changes when the world does.
func refresh() -> void:
	wire = WireNetScript.new(signal_grade)
	posts = wire.feed(20)
	_rebuild_rail()
	rail_index = clampi(rail_index, 0, maxi(0, _rail_cache.size() - 1))


## A2.7. Filtering happens here rather than at draw time so that selection,
## scrolling and the count all agree about how many rows exist.
## A person, as opposed to a bookkeeping record. `WorldHistory` holds machine
## subjects too - the inventory, the settings, the survey grid - and `kind`
## defaults to "person" when absent while half the real registrations omit it.
## So neither trusting the default nor requiring the field works: a subject is a
## person if somebody gave it a name.
func _is_person(subject: Dictionary) -> bool:
	if str(subject.get("kind", "")) == "faction":
		return false
	return str(subject.get("name", "")) != ""


func _matches(label: String, note: String) -> bool:
	if search_query == "":
		return true
	var needle := search_query.to_lower()
	return label.to_lower().contains(needle) or note.to_lower().contains(needle)


func _rebuild_rail() -> void:
	_rail_cache.clear()
	match page:
		0, 3:
			for subject_id in WorldHistory.all_subjects():
				var subject: Dictionary = WorldHistory.subject(subject_id)
				if not _is_person(subject):
					continue
				var person_label := str(subject.get("name", subject_id))
				var person_note := str(subject.get("role", ""))
				if _matches(person_label, person_note):
					_rail_cache.append({"id": subject_id, "label": person_label, "note": person_note})
		1:
			for faction_id in wire.factions():
				var faction: Dictionary = WorldHistory.subject(faction_id)
				var faction_label := str(faction.get("name", faction_id))
				var faction_note := str(faction.get("threat", "UNKNOWN"))
				if _matches(faction_label, faction_note):
					_rail_cache.append({"id": faction_id, "label": faction_label, "note": faction_note})
		2:
			for account in wire.accounts_by_reach():
				var note := str(account.tier)
				if str(account.id) == "player":
					note += "  \u00b7  YOU"
				if _matches(str(account.name), note):
					_rail_cache.append({"id": str(account.id), "label": str(account.name), "note": note})


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	action_life = maxf(0.0, action_life - delta)
	page_blend = Motion.blend(page_blend, delta, Motion.PANEL, true)
	open_blend = Motion.blend(open_blend, delta, Motion.PANEL, not closing)
	if closing and open_blend <= 0.0:
		visible = false
		closing = false
		return
	highlight_y = Motion.approach(highlight_y, float(rail_index), delta, Motion.SELECTION)
	rail_scroll = Motion.approach(rail_scroll, rail_scroll_target, delta, Motion.SCROLL)
	if cursor_follows_mouse:
		cursor_at = get_global_mouse_position()
	queue_redraw()


## Pointer events aimed at this full-screen Control enter through `_gui_input`;
## keyboard events still use `_unhandled_input`. Routing the mouse explicitly
## is what makes BODY hover and direct specimen manipulation work in the game,
## not only when their methods are called by a test.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_unhandled_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Arrow keys only, deliberately. WASD would drive the car underneath the
	# panel: the chassis reads `Input.is_action_pressed` in `_physics_process`,
	# which does not care that the event was marked handled here.
	# A2.7. While the search field has focus it eats printable keys, otherwise
	# typing "i" in a query would close the panel.
	if search_active and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			search_active = false
			search_query = ""
			_rebuild_rail()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			search_active = false
		elif event.keycode == KEY_BACKSPACE:
			search_query = search_query.substr(0, maxi(0, search_query.length() - 1))
			_rebuild_rail()
		else:
			var typed := char(event.unicode)
			if typed.strip_edges() != "" and search_query.length() < 24:
				search_query += typed
				rail_index = 0
				_rebuild_rail()
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
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
			KEY_P:
				# L2.1. Take the selected record off the index and carry it to
				# the wall. The index does not know the board exists — it hands
				# the reference up and whoever owns both decides what happens,
				# which keeps the two screens independent.
				if rail_index >= 0 and rail_index < _rail_cache.size():
					var row: Dictionary = _rail_cache[rail_index]
					var subject: Dictionary = WorldHistory.subject(str(row["id"]))
					var row_kind := "record" if str(subject.get("kind", "")) == "faction" else "photo"
					pin_requested.emit(str(row["id"]), row_kind, str(row["label"]))
			KEY_TAB:
				if page != 3 or not _inspector.handle_key(KEY_TAB):
					return
			KEY_ENTER, KEY_KP_ENTER:
				# A4.5. Sending is an act, so it re-rolls deliberately rather
				# than the panel re-rolling it behind your back every frame.
				if page != 2 or _contact_for == "":
					return
				_refresh_contact(_contact_for, true)
			KEY_SLASH:
				search_active = true
			KEY_X:
				_set_xray(not xray)
			KEY_1, KEY_2, KEY_3, KEY_4:
				var target: int = event.keycode - KEY_1
				_go_to_page(target, 1.0 if target > page else -1.0)
			_:
				return
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventMouseMotion and page == 3:
		if _inspector.handle_pointer_motion(event.position, event.relative):
			get_viewport().set_input_as_handled()
			queue_redraw()
	elif event is InputEventMouseButton and page == 3 and _inspector.handle_mouse_button(event.position, event.button_index, event.pressed):
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and XrayCursor.on_button(cursor_at, event.position):
			_set_xray(not xray)
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			# I5. Everything printed is pointable. One list, checked before the
			# page-specific controls so a link always wins over the surface
			# underneath it.
			for link in _link_rects:
				if (link["rect"] as Rect2).has_point(event.position):
					_follow_link(link)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
		if event.button_index == MOUSE_BUTTON_LEFT and page == 1:
			# A3.5. Click a rank and read the person standing in it.
			for row in _tier_rects:
				if (row["rect"] as Rect2).has_point(event.position):
					_jump_to_subject(str(row["id"]))
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
		if event.button_index == MOUSE_BUTTON_LEFT and page == 2:
			for row in _action_rects:
				if (row["rect"] as Rect2).has_point(event.position):
					_run_action(str(row["id"]))
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			feed_scroll += 42.0
			if wire:
				wire.scroll(1.0)
			# A4.7. It does not end. Reaching the bottom loads more, which is
			# the mechanic the design asks for - the feed is meant to farm you,
			# and a scroll bar that fills up is an exit sign.
			if feed_scroll > maxf(0.0, float(posts.size()) * 80.0 - 360.0):
				posts.append_array(wire.feed(10, posts.size()))
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


## A3.5. Switching page *and* selection together, which the rail alone cannot do.
func _jump_to_subject(subject_id: String) -> void:
	_go_to_page(0, -1.0)
	for index in _rail_cache.size():
		if str((_rail_cache[index] as Dictionary).id) == subject_id:
			rail_index = index
			return


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


## A2.8. The registry is wrong about some of what it holds. `DESIGN/IN_GAME_
## INTERNET.md` and Codex §13 both make partial, late, manipulated or false
## information a pillar, and an index that is quietly always correct undercuts
## it. One field in roughly a third of files is disputed, deterministically, and
## the panel shows the claim struck through with what is reported instead.
const DISPUTED_ROLES := [
	"claims the rank, holds no post",
	"three people answer to this name",
	"reported dead twice",
	"this entry predates the flash",
	"filed by someone with a grudge",
]


func _disputed_note(subject_id: String) -> String:
	var mark := hash(subject_id + "dispute") % 100
	if mark >= 34:
		return ""
	return str(DISPUTED_ROLES[mark % DISPUTED_ROLES.size()])


## I5.2-I5.4. Following a link never opens a window: it moves this panel to the
## page that already shows the thing, which is rule 3 — parts leave diagrams
## rather than spawning modals.
func _follow_link(link: Dictionary) -> void:
	match str(link.get("kind", "")):
		"wound", "implant":
			# Both live on the body, so both go to BODY with the right zone up.
			page = 3
			page_blend = 0.0
			page_direction = 1.0
			var zone := str(link.get("zone", ""))
			if zone.is_empty():
				zone = _zone_from_text(str(link.get("id", "")))
			if _inspector != null and _inspector.has_method("focus_zone"):
				_inspector.focus_zone(zone)
		"account":
			# _jump_to_subject lands on FILE by design, so select first and then
			# put the reader on the Wire, which is where an account lives.
			_jump_to_subject(str(link.get("id", "")))
			_go_to_page(2, 1.0)
		"faction":
			page = 1
			page_blend = 0.0
			page_direction = 1.0


## Wounds are recorded as prose, not as a zone id, so the link reads the zone
## back out of the text. Names are identities and are never parsed for meaning
## elsewhere; this is a lookup for where to point a camera, nothing more.
func _zone_from_text(text: String) -> String:
	var lowered := text.to_lower()
	for zone in ["head", "torso", "left arm", "right arm", "left leg", "right leg"]:
		if lowered.contains(zone):
			return zone.replace(" ", "_")
	return "torso"


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
	# A8.2. Everything except the cursor is drawn inside this transform, so the
	# whole plate arrives as one object instead of each element animating itself.
	var opened := Motion.ease_out(open_blend)
	var plate_scale := lerpf(0.955, 1.0, opened)
	draw_rect(Rect2(Vector2.ZERO, viewport), GROUND * Color(1, 1, 1, opened))
	draw_set_transform(viewport * 0.5 * (1.0 - plate_scale), 0.0, Vector2(plate_scale, plate_scale))
	var plate := Rect2(Vector2(54, 44), viewport - Vector2(108, 88))
	# I4. How well this reads is how well the person holding it is doing.
	var failing: float = VitalitySignal.severity()
	# I1.3. The rain is drawn first and the plate is punched out of it, so the
	# readout is a hole in the material rather than a panel sitting on a
	# wallpaper. I1.1 gives it the game's own words; I1.2 fails it with the body.
	if _rain.is_empty() or not _rain_size.is_equal_approx(viewport):
		_rain = CodeRain.build(viewport.x, viewport.y, 26.0, 4409)
		_rain_size = viewport
	CodeRain.advance(_rain, get_process_delta_time(), viewport.y)
	# Contained to the margin around the plate rather than the whole viewport.
	# Drawn full-bleed it escaped the World Index entirely when the index is
	# hosted inside the handheld, and printed the game's vocabulary down the
	# sides of the device case.
	CodeRain.draw_field(self, plate.grow(46.0), _rain, MOSS, failing, elapsed, [plate])
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
	_link_rects.clear()
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
	# Drawn last so it sits over the readout rather than under it, and bounded
	# by the plate so it is the object failing, not the frame.
	Grunge.vital_interference(self, plate, failing, elapsed, 5)
	_draw_stamp(plate)
	_draw_footer(plate)
	_draw_gore(plate)
	_draw_screen_decay(plate)
	Grunge.grain(self, plate, 907, 900)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The cursor is a physical thing in front of the screen, so it does not
	# travel with the panel that is arriving behind it.
	if show_cursor:
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
	# G1.4. The plate Greg's artwork is printed on, under the grime and under
	# everything else. Nothing changes when the art pipeline has not been run.
	Grunge.art_substrate(self, rect, 7, 0.10)
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
	CellOutzType.draw_text(self, rect.position, heading, 12.0, MOSS, 1.4)
	var total := "%02d" % _rail_cache.size()
	var total_width := CellOutzType.width(total, 10.0, 0.8)
	CellOutzType.draw_text(self, Vector2(rect.position.x + rect.size.x - 14 - total_width, rect.position.y + 2), total, 10.0, INK * Color(1, 1, 1, 0.4), 0.8)
	draw_line(rect.position + Vector2(0, 18), rect.position + Vector2(rect.size.x - 14, 18), MOSS * Color(1, 1, 1, 0.35), 1.0)

	# A2.7. A search field that looks like something scratched into the plate
	# rather than a form input.
	var font := ThemeDB.fallback_font
	var field := Rect2(rect.position + Vector2(0, 26), Vector2(rect.size.x - 14, 20))
	if search_active or search_query != "":
		draw_colored_polygon(PackedVector2Array([
			field.position + Vector2(4, 0), field.position + Vector2(field.size.x, 0),
			field.position + field.size - Vector2(4, 0), field.position + Vector2(0, field.size.y),
		]), COPPER * Color(1, 1, 1, 0.14))
		var caret := "_" if search_active and fmod(elapsed, 0.9) < 0.45 else ""
		draw_string(font, field.position + Vector2(8, 14), "/ %s%s" % [search_query, caret], HORIZONTAL_ALIGNMENT_LEFT, field.size.x - 14, 12, INK)
	else:
		draw_string(font, field.position + Vector2(2, 14), "/ TO SEARCH", HORIZONTAL_ALIGNMENT_LEFT, field.size.x, 10, INK * Color(1, 1, 1, 0.26))

	# A2.6. The rail was drawing every subject from a fixed origin, so a
	# population past about twelve simply ran off the bottom of the plate and
	# became unreachable. It scrolls now, and the scroll follows the selection.
	var row_height := 34.0
	var top := rect.position.y + 56.0
	var visible_rows := int((rect.position.y + rect.size.y - top) / row_height)
	rail_scroll_target = clampf(float(rail_index) - float(visible_rows) * 0.5, 0.0, maxf(0.0, float(_rail_cache.size() - visible_rows)))
	var offset := rail_scroll * row_height

	# A8.3. The highlight is drawn at its travelling position, not at the row.
	if not _rail_cache.is_empty():
		var marker_y := top + highlight_y * row_height - offset
		if marker_y > top - row_height and marker_y < rect.position.y + rect.size.y:
			draw_colored_polygon(PackedVector2Array([
				Vector2(rect.position.x - 6, marker_y - 13), Vector2(rect.position.x + rect.size.x - 14, marker_y - 13),
				Vector2(rect.position.x + rect.size.x - 20, marker_y + 15), Vector2(rect.position.x - 6, marker_y + 15),
			]), COPPER * Color(1, 1, 1, 0.17))
			draw_line(Vector2(rect.position.x - 6, marker_y - 13), Vector2(rect.position.x - 6, marker_y + 15), HOT, 2.5)

	for index in _rail_cache.size():
		var y := top + float(index) * row_height - offset
		if y < top - row_height or y > rect.position.y + rect.size.y - 8.0:
			continue
		var entry: Dictionary = _rail_cache[index]
		var active := index == rail_index
		var icon_slot := _file_rail_icon_slot(index)
		var text_inset := 4.0
		if icon_slot >= 0 and _draw_icon(icon_slot, str(entry.id), Rect2(Vector2(rect.position.x + 2, y - 12), Vector2(27, 27))):
			text_inset = 35.0
		draw_string(font, Vector2(rect.position.x + text_inset, y), str(entry.label), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - text_inset - 22, 14, INK if active else INK * Color(1, 1, 1, 0.72))
		draw_string(font, Vector2(rect.position.x + text_inset, y + 13), str(entry.note).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - text_inset - 22, 9, COPPER * Color(1, 1, 1, 0.8) if active else INK * Color(1, 1, 1, 0.34))

	# A scroll indicator, so it is obvious there is more than what is on screen.
	if _rail_cache.size() > visible_rows:
		var track_x := rect.position.x + rect.size.x - 10.0
		draw_line(Vector2(track_x, top - 6), Vector2(track_x, rect.position.y + rect.size.y - 8), INK * Color(1, 1, 1, 0.10), 2.0)
		var span := rect.size.y - 62.0
		var thumb := span * clampf(float(visible_rows) / float(_rail_cache.size()), 0.08, 1.0)
		var travel := (span - thumb) * clampf(rail_scroll / maxf(1.0, float(_rail_cache.size() - visible_rows)), 0.0, 1.0)
		draw_line(Vector2(track_x, top - 6 + travel), Vector2(track_x, top - 6 + travel + thumb), COPPER * Color(1, 1, 1, 0.55), 2.0)


## The FILE rail gets the five pooled heads surrounding selection; slot zero is
## reserved for the larger dossier portrait. This keeps the six-viewport budget
## while making the list people rather than another column of names.
func _file_rail_icon_slot(index: int) -> int:
	if page != 0 or abs(index - rail_index) > 2:
		return -1
	return 1 + index - (rail_index - 2)


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
	# Hosted in the handheld the aperture is a good deal shorter than a full
	# screen, and the fixed offsets below were written against the latter. In
	# compact mode the relation graph gives up its space to the record, which is
	# the block that cannot be dropped.
	var compact := rect.size.y < 470.0

	# The Tree axis. It exists, it is already computed, and nothing showed it.
	var alignment: float = WorldHistory.tree_alignment(subject)
	_draw_axis(Rect2(rect.position + Vector2(0, 130), Vector2(column, 52)), alignment, str(WorldHistory.tree_descriptor(subject)))

	# Memory, set as a quotation rather than a field, because it is the one piece
	# of a dossier that is somebody's account rather than a measurement.
	var memory := str(subject.get("memory", ""))
	var left_y := rect.position.y + (188.0 if compact else 208.0)
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
	if not relations.is_empty() and not compact:
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
		var wound_label := WoundCatalog.label(wound)
		if not lines.has(wound_label):
			lines.append(wound_label)
	if lines.is_empty():
		lines.append("no recorded damage")
	for line in lines:
		var wound_row := Rect2(right_x - 4, wy - 12, right_width, 17)
		var wound_hot := wound_row.has_point(cursor_at)
		if str(line) != "no recorded damage":
			_link_rects.append({"kind": "wound", "id": str(line), "rect": wound_row})
			if wound_hot:
				draw_rect(wound_row, HOT * Color(1, 1, 1, 0.10))
		draw_string(font, Vector2(right_x, wy), "— %s" % str(line), HORIZONTAL_ALIGNMENT_LEFT, right_width, 12, HOT * Color(1, 1, 1, 1.0 if wound_hot else 0.9))
		wy += 17.0
	var anatomy: Dictionary = subject.get("anatomy_state", subject.get("anatomy", {}))
	var cybernetics := ImplantCatalog.list(anatomy.get("cybernetics", []))
	if not cybernetics.is_empty():
		wy += 18.0
		CellOutzType.draw_text(self, Vector2(right_x, wy), "INSTALLED", 11.0, BRUISE.lerp(INK, 0.3), 1.2)
		draw_line(Vector2(right_x, wy + 17), Vector2(right_x + right_width, wy + 17), BRUISE * Color(1, 1, 1, 0.4), 1.0)
		wy += 36.0
		for part in cybernetics:
			var part_row := Rect2(right_x - 4, wy - 12, right_width, 17)
			var part_hot := part_row.has_point(cursor_at)
			_link_rects.append({"kind": "implant", "id": str(part.name), "zone": str(part.get("zone", "torso")), "rect": part_row})
			if part_hot:
				draw_rect(part_row, BRUISE * Color(1, 1, 1, 0.14))
			draw_string(font, Vector2(right_x, wy), "+ %s  %03d%%" % [str(part.name), roundi(float(part.condition) / maxf(1.0, float(part.max_condition)) * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, right_width, 12, BRUISE.lerp(INK, 0.8 if part_hot else 0.55))
			wy += 17.0
	var blood := str(anatomy.get("blood_type", ""))
	if blood != "":
		wy += 14.0
		draw_string(font, Vector2(right_x, wy), "BLOOD %s" % blood.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, right_width, 11, INK * Color(1, 1, 1, 0.45))

	# History, across the full width at the foot, wrapping into columns.
	var hy := maxf(left_y + 14.0, rect.position.y + rect.size.y - 76.0) if compact else rect.position.y + rect.size.y - 76.0
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
	_tier_rects.clear()

	var tiers: Array = data.tiers
	var top := rect.position.y + 84.0
	var row_height := minf(56.0, (rect.size.y - 150.0) / float(maxi(1, tiers.size())))
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
			# A3.5. Remember where this row is so it can be clicked through to.
			_tier_rects.append({"id": str((members[0] as Dictionary).id), "rect": Rect2(Vector2(cx - span * 0.5, y), Vector2(span, row_height - 8.0))})
			var lead: Dictionary = members[0]
			var icon_size := minf(row_height - 12.0, 48.0)
			var has_icon := _draw_icon(index, str(lead.id), Rect2(Vector2(cx - span * 0.5 + 16, y + 4), Vector2(icon_size, icon_size)))
			var text_x := cx - span * 0.5 + (18.0 + icon_size + 10.0 if has_icon else 18.0)
			draw_string(font, Vector2(text_x, y + 40), label, HORIZONTAL_ALIGNMENT_LEFT, room - icon_size - 10.0, 13, INK * Color(1, 1, 1, 0.88))
			CellOutzType.draw_text(self, Vector2(cx + span * 0.5 - 18 - down_width, y + 30), downline, 10.0, SPORE * Color(1, 1, 1, 0.8), 0.9)

	# A3.7. The ladder is not just tiers - it is who brought whom in. Drawn from
	# real ally and command edges between members of adjacent tiers, because the
	# recruitment chain is the thing a pyramid scheme actually sells.
	for index in range(1, tiers.size()):
		var lower: Array = (tiers[index] as Dictionary)["members"]
		var upper: Array = (tiers[index - 1] as Dictionary)["members"]
		if lower.is_empty() or upper.is_empty():
			continue
		var recruit: Dictionary = lower[0]
		var relations: Dictionary = WorldHistory.subject(str(recruit.id)).get("relations", {})
		for sponsor in upper:
			if not relations.has(str((sponsor as Dictionary).id)):
				continue
			var centre_x := rect.position.x + rect.size.x * 0.5
			var lower_span := lerpf(rect.size.x * 0.46, rect.size.x * 0.96, float(index) / float(maxi(1, tiers.size() - 1)))
			var upper_span := lerpf(rect.size.x * 0.46, rect.size.x * 0.96, float(index - 1) / float(maxi(1, tiers.size() - 1)))
			var from_point := Vector2(centre_x - lower_span * 0.5, top + float(index) * row_height + 10.0)
			var to_point := Vector2(centre_x - upper_span * 0.5, top + float(index - 1) * row_height + row_height - 16.0)
			var elbow := minf(from_point.x, to_point.x) - 14.0
			draw_polyline(PackedVector2Array([
				from_point, Vector2(elbow, from_point.y), Vector2(elbow, to_point.y), to_point,
			]), SPORE * Color(1, 1, 1, 0.75), 1.8)
			draw_circle(to_point, 3.0, SPORE)
			# Named, because "who brought you in" is the thing the pitch sells.
			CellOutzType.draw_text(self, Vector2(elbow - 52.0, (from_point.y + to_point.y) * 0.5 - 5.0), "UPLINE", 8.0, SPORE * Color(1, 1, 1, 0.7), 0.8)
			break

	# A3.6. The register, pushed. This is a recruitment pitch printed on a
	# hierarchy chart, and it should read like one.
	var fy := top + float(tiers.size()) * row_height + 10.0
	if fy < rect.position.y + rect.size.y - 16.0:
		CellOutzType.draw_stamped(self, Vector2(rect.position.x, fy), "ADVANCEMENT OPPORTUNITY", 14.0, COPPER, HOT * Color(1, 1, 1, 0.3), 1.2)
		draw_string(font, Vector2(rect.position.x, fy + 30), "RECRUIT TWO AND YOUR POSITION IS SECURE. RECRUIT FOUR AND YOUR POSITION IS THEIRS.", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 11, INK * Color(1, 1, 1, 0.72))
		var voice: String = "\"I came in on INTAKE owing a car. Eleven weeks later I own the people who sold it to me.\""
		draw_string(font, Vector2(rect.position.x + 8, fy + 48), voice, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 11, SPORE * Color(1, 1, 1, 0.72))
		draw_string(font, Vector2(rect.position.x + 8, fy + 62), "— A SATISFIED EARNER, DECEASED", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 9, INK * Color(1, 1, 1, 0.34))
		draw_string(font, Vector2(rect.position.x, fy + 82), "CELLOUTZ IS NOT RESPONSIBLE FOR POSITIONS HELD BY THE DECEASED. BUY-IN IS NON-REFUNDABLE.", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 9, INK * Color(1, 1, 1, 0.30))


# --- page three: the Wire ---------------------------------------------------

## A4.5. The contact attempt is resolved once and held, not recomputed.
##
## This was a real bug rather than a refactor: `_draw_wire` called
## `wire.contact()` inside `_draw`, so every frame re-rolled the RNG - the reply
## and the routes flickered - and every frame also added 0.6 to `strain`, which
## meant simply *looking* at an account drained the player's attention at 36 a
## second. The Wire is supposed to cost something to read; not that.
const WIRE_ACTIONS := [
	{"id": "observe", "label": "OBSERVE", "cost": "0", "note": "read them"},
	{"id": "trace", "label": "TRACE", "cost": "1", "note": "find where they will be"},
	{"id": "expose", "label": "EXPOSE", "cost": "2", "note": "publish something true"},
	{"id": "fabricate", "label": "FABRICATE", "cost": "3-5", "note": "publish something false"},
	{"id": "swarm", "label": "SWARM", "cost": "7", "note": "turn their own people on them"},
]


func _refresh_contact(subject_id: String, force := false) -> void:
	if subject_id == _contact_for and not force:
		return
	_contact_for = subject_id
	_last_action = {}
	_contact = wire.contact(subject_id) if subject_id != "" else {}


func _run_action(action: String) -> void:
	if _contact_for == "":
		return
	_last_action = wire.act(_contact_for, action)
	# An action changes standing, so whether they will read you changes with it.
	_refresh_contact(_contact_for, true)


func _draw_wire(rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	# G1.5. The Wire is described as paranoid hand-assembled collage, and the
	# pipeline builds exactly that out of Greg's work. The feed prints over it.
	Grunge.art_collage(self, rect, 3, 0.13)
	var entry := _selected()
	var split := rect.size.x * 0.46
	_action_rects.clear()
	if not entry.is_empty():
		_refresh_contact(str(entry.id))
		var account: Dictionary = wire.account(str(entry.id))
		CellOutzType.draw_stamped(self, rect.position + Vector2(0, 4), str(account.get("name", "")).to_upper(), 18.0, INK, COPPER * Color(1, 1, 1, 0.28), 1.2)
		draw_string(font, rect.position + Vector2(2, 34), str(account.get("handle", "")), HORIZONTAL_ALIGNMENT_LEFT, split, 12, MOSS)
		if bool(account.get("verified", false)):
			var badge := rect.position + Vector2(split - 30, 16)
			draw_colored_polygon(PackedVector2Array([
				badge + Vector2(0, -9), badge + Vector2(9, 0), badge + Vector2(0, 9), badge + Vector2(-9, 0),
			]), MOSS * Color(1, 1, 1, 0.85))
			draw_string(font, badge + Vector2(-3, 4), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.05, 0.05))
		CellOutzType.draw_text(self, rect.position + Vector2(0, 52), "REACH", 9.0, INK * Color(1, 1, 1, 0.45), 1.0)
		CellOutzType.draw_text(self, rect.position + Vector2(0, 66), "%06d" % int(account.get("reach", 0)), 20.0, COPPER, 1.0)
		CellOutzType.draw_text(self, rect.position + Vector2(146, 52), "TIER", 9.0, INK * Color(1, 1, 1, 0.45), 1.0)
		CellOutzType.draw_text(self, rect.position + Vector2(146, 66), str(account.get("tier", "")), 16.0, BRUISE.lerp(INK, 0.4), 1.0)
		_draw_icon(0, str(entry.id), Rect2(Vector2(rect.position.x + split - 116, rect.position.y + 36), Vector2(92, 92)))
		draw_string(font, rect.position + Vector2(2, 104), "LAST SEEN %s" % str(account.get("last_seen", "")), HORIZONTAL_ALIGNMENT_LEFT, split, 11, INK * Color(1, 1, 1, 0.55))
		var bought := int(account.get("manufactured", 0))
		if bought > 0:
			draw_string(font, rect.position + Vector2(2, 120), "ESTIMATED %d OF THAT WAS PURCHASED" % bought, HORIZONTAL_ALIGNMENT_LEFT, split, 10, HOT * Color(1, 1, 1, 0.7))

		var chance := float(_contact.get("chance", 0.0))
		var cy := rect.position.y + 140.0
		draw_line(Vector2(rect.position.x, cy - 8), Vector2(rect.position.x + split - 20, cy - 8), INK * Color(1, 1, 1, 0.16), 1.0)
		CellOutzType.draw_text(self, Vector2(rect.position.x, cy), "WILL THEY READ YOU", 11.0, MOSS, 1.2)
		var bar := Rect2(Vector2(rect.position.x, cy + 22), Vector2(split - 66, 12))
		draw_rect(bar, INK * Color(1, 1, 1, 0.10))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(chance, 0.0, 1.0), bar.size.y)), HOT.lerp(SPORE, clampf(chance, 0.0, 1.0)))
		draw_rect(bar, INK * Color(1, 1, 1, 0.22), false, 1.0)
		CellOutzType.draw_text(self, Vector2(bar.position.x + bar.size.x + 8, bar.position.y), "%02d" % roundi(chance * 100.0), 12.0, INK, 0.8)
		var ry := cy + 46.0
		for route in _contact.get("routes", []):
			draw_string(font, Vector2(rect.position.x + 2, ry + 12), "\u00b7 %s" % str(route), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 11, SPORE)
			ry += 15.0
		if str(_contact.get("reason", "")) != "":
			draw_string(font, Vector2(rect.position.x + 2, ry + 14), str(_contact.get("reason", "")), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 11, HOT * Color(1, 1, 1, 0.85))
			ry += 18.0
		elif str(_contact.get("reply", "")) != "":
			draw_string(font, Vector2(rect.position.x + 2, ry + 14), "\"%s\"" % str(_contact.get("reply", "")), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 12, INK)
			ry += 20.0
		draw_string(font, Vector2(rect.position.x + 2, ry + 14), "[ENTER] SEND AGAIN", HORIZONTAL_ALIGNMENT_LEFT, split - 20, 10, COPPER * Color(1, 1, 1, 0.62))

		# A4.6. The active half, with its price on the button. The design is
		# explicit that these must never ship before their costs work, so the
		# cost is the most legible thing on the row.
		var ay := rect.position.y + rect.size.y - 178.0
		CellOutzType.draw_text(self, Vector2(rect.position.x, ay), "ACTIONS", 11.0, MOSS, 1.2)
		draw_line(Vector2(rect.position.x, ay + 17), Vector2(rect.position.x + split - 20, ay + 17), MOSS * Color(1, 1, 1, 0.3), 1.0)
		ay += 28.0
		for action in WIRE_ACTIONS:
			var row := Rect2(Vector2(rect.position.x, ay), Vector2(split - 24, 22))
			_action_rects.append({"id": str(action.id), "rect": row})
			var hot_row := row.has_point(cursor_at)
			if hot_row:
				draw_colored_polygon(PackedVector2Array([
					row.position + Vector2(3, 0), row.position + Vector2(row.size.x, 0),
					row.position + row.size - Vector2(3, 0), row.position + Vector2(0, row.size.y),
				]), COPPER * Color(1, 1, 1, 0.18))
			CellOutzType.draw_text(self, row.position + Vector2(6, 5), str(action.label), 11.0, INK if hot_row else INK * Color(1, 1, 1, 0.74), 1.0)
			draw_string(font, row.position + Vector2(110, 15), str(action.note), HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 168, 10, INK * Color(1, 1, 1, 0.38))
			var cost := "+%s" % str(action.cost)
			var cost_width := CellOutzType.width(cost, 10.0, 0.9)
			CellOutzType.draw_text(self, Vector2(row.position.x + row.size.x - 8 - cost_width, row.position.y + 6), cost, 10.0, HOT * Color(1, 1, 1, 0.8), 0.9)
			ay += 24.0

		if not _last_action.is_empty():
			var tone: Color = SPORE if bool(_last_action.get("ok", false)) else HOT
			CellOutzType.draw_text(self, Vector2(rect.position.x, ay + 4), str(_last_action.get("headline", "")), 11.0, tone, 1.0)
			draw_string(font, Vector2(rect.position.x + 2, ay + 30), str(_last_action.get("detail", "")), HORIZONTAL_ALIGNMENT_LEFT, split - 24, 11, INK * Color(1, 1, 1, 0.66))

		var ey := rect.position.y + rect.size.y - 20.0
		CellOutzType.draw_text(self, Vector2(rect.position.x, ey), "YOUR EXPOSURE", 10.0, HOT if wire.exposure >= 8 else INK * Color(1, 1, 1, 0.5), 1.1)
		CellOutzType.draw_text(self, Vector2(rect.position.x + 150, ey - 4), "%02d" % wire.exposure, 16.0, HOT if wire.exposure >= 8 else INK, 0.8)
		var trace: String = wire.pending_trace()
		if trace != "":
			draw_string(font, Vector2(rect.position.x + 210, ey + 10), "%s HAS YOUR PATTERN." % trace.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, split - 20, 10, HOT)

	var feed := Rect2(rect.position + Vector2(split + 16, 0), Vector2(rect.size.x - split - 16, rect.size.y))
	draw_line(feed.position + Vector2(-10, 0), feed.position + Vector2(-10, feed.size.y), INK * Color(1, 1, 1, 0.14), 1.0)
	CellOutzType.draw_text(self, feed.position, "THE WIRE", 12.0, COPPER, 1.4)
	var strain_label := "STRAIN %02d" % roundi(wire.strain)
	var strain_width := CellOutzType.width(strain_label, 10.0, 0.8)
	CellOutzType.draw_text(self, Vector2(feed.position.x + feed.size.x - strain_width, feed.position.y + 2), strain_label, 10.0, BRUISE.lerp(HOT, clampf(wire.strain / 40.0, 0, 1)), 0.8)
	draw_line(feed.position + Vector2(0, 18), feed.position + Vector2(feed.size.x, 18), COPPER * Color(1, 1, 1, 0.3), 1.0)
	var y := feed.position.y + 34.0 - feed_scroll
	for post in posts:
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
	# I5.4. The name on a post is the account that wrote it.
	var author_width: float = font.get_string_size(author, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var author_row := Rect2(feed.position.x + 10, y - 11, author_width + 8.0, 15)
	var author_hot := author_row.has_point(cursor_at)
	var post_subject := str(post.get("subject_id", post.get("author_id", "")))
	if not post_subject.is_empty():
		_link_rects.append({"kind": "account", "id": post_subject, "rect": author_row})
		if author_hot:
			draw_rect(author_row, tone * Color(1, 1, 1, 0.12))
	draw_string(font, Vector2(feed.position.x + 12, y), author, HORIZONTAL_ALIGNMENT_LEFT, feed.size.x - 110, 11, tone * Color(1, 1, 1, 1.0 if author_hot else 0.88))
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
