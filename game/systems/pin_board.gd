class_name PinBoard
extends Control

## L1. The storyline, as a wall.
##
## Greg, 2026-09-12: *"the main game storyline career option thing is a
## conspiracy theory pin board of all the ideas etc, in the Charlie Always Sunny
## style conspiracy board"* — *"and that links everything in."*
##
## What it replaces is the reason it exists. A quest log is a list of text in a
## box, and it is the single worst offender against I0 that this project had not
## yet built: every other screen has been dragged out of that shape and the
## storyline was about to walk straight back into it. So there is no quest state
## anywhere. What the player is "on" is which cards are pinned and which strings
## run between them, read out of `WorldHistory` at the moment the board opens.
##
## This is step 1 of the five in `DESIGN/THE_BOARD.md`: **the surface**.
## Read-only, populated from what actually happened, pannable and zoomable.
## Pinning, strings-as-claims, publishing and career routes come after, and all
## four of them need this to exist first.
##
## The register is `DESIGN/IN_GAME_INTERNET.md`'s paranoid collage: cork, too
## much paper, block capitals, red thread, and more connections than the
## evidence supports. It should look **made** rather than rendered — from across
## the room you read the shape, up close you read the cards.

const Grunge := preload("res://systems/celloutz_grunge.gd")

const CORK := Color("6b4f31")
const CORK_DARK := Color("4a3721")
const PAPER := Color("d9cdb2")
const PAPER_COOL := Color("c9c6bb")
const NEWSPRINT := Color("bfb79d")
const INK := Color("241c14")
const MARKER := Color("8d1f16")
const THREAD := Color("a8281a")
const PIN := Color("c8b23a")
const PHOTO_BACK := Color("2a2a26")

## The authored mainline theories. They ship pinned — the board is never blank —
## and nothing on the board marks which of them is true. Each is a different
## reading of the same world, and following one far enough is how the game ends,
## which makes these the set that `E7`'s two routes are the first two of.
const THEORIES := [
	{
		"id": "theory_ownership",
		"title": "IT IS A DEBT",
		"claim": "NOBODY DIED HERE. THEY WERE REPOSSESSED.\nCHECK WHO HOLDS THE LIEN.",
		"at": Vector2(-520, -300),
		"pulls": ["faction", "part", "lien"],
	},
	{
		"id": "theory_frequency",
		"title": "THE SIGNAL IS THE PRAYER",
		"claim": "THE MASTS ARE NOT FOR TALKING.\nSOMETHING IS BEING CARRIED UP.",
		"at": Vector2(120, -380),
		"pulls": ["place", "signal"],
	},
	{
		"id": "theory_absent_god",
		"title": "HE IS NOT LISTENING",
		"claim": "YOU CANNOT GET HIS ATTENTION BY ASKING.\nSO MAKE SOMETHING HE HAS TO ANSWER FOR.",
		"at": Vector2(-180, 120),
		"pulls": ["event", "person"],
	},
	{
		"id": "theory_rotation",
		"title": "FOUR CHAIRS, ONE TABLE",
		"claim": "THE LEADERSHIP CHANGES AND THE ORDERS DO NOT.\nTHEREFORE THE ORDERS ARE NOT THEIRS.",
		"at": Vector2(520, -60),
		"pulls": ["faction", "person"],
	},
	{
		"id": "theory_inside",
		"title": "THE HUNT IS THE PRODUCT",
		"claim": "THEY SELL YOU THE WIRE.\nTHEY SELL THEM YOUR NAME.",
		"at": Vector2(200, 340),
		"pulls": ["event", "faction"],
	},
]

## A card is a piece of paper on the wall. `kind` decides how it is drawn, not
## what it says — a photograph, a torn cutting, an index card and a filed record
## are different objects and should never share a template.
class Card extends RefCounted:
	var id := ""
	var kind := "person"
	var title := ""
	var body := ""
	var at := Vector2.ZERO
	var size := Vector2(150, 96)
	var angle := 0.0
	var seed_value := 0
	var tint: Color = PAPER
	var struck := false


var cards: Array[Card] = []
var threads: Array = []
var pan := Vector2.ZERO
var zoom := 1.0
var clock := 0.0
var open_blend := 0.0

var _dragging := false
var _board_rect := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(true)
	# A Control parented to a CanvasLayer gets no size from its anchors, because
	# the layer is not a Control and never lays anything out. Taken from the
	# viewport directly and kept in step with it.
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	size = get_viewport_rect().size


func open() -> void:
	_fit()
	rebuild()
	visible = true
	open_blend = 0.0


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	open_blend = minf(open_blend + delta * 2.6, 1.0)
	queue_redraw()


## Reads the wall out of what happened. Nothing here is quest state: subjects,
## events and carried parts are the evidence, and the theories are speculation
## laid over it. Called on every open, so the board is always the current
## reading rather than a saved arrangement.
func rebuild() -> void:
	cards.clear()
	threads.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210

	var theory_cards: Dictionary = {}
	for theory: Dictionary in THEORIES:
		var card := Card.new()
		card.id = str(theory["id"])
		card.kind = "theory"
		card.title = str(theory["title"])
		card.body = str(theory["claim"])
		card.at = theory["at"]
		card.size = Vector2(240, 146)
		card.seed_value = rng.randi()
		card.angle = rng.randf_range(-0.035, 0.035)
		cards.append(card)
		theory_cards[str(theory["id"])] = card

	# People and factions, from the ledger. Only what the player has actually
	# met ends up on the wall, because this is their reading rather than an
	# encyclopaedia.
	var placed := 0
	for subject_id: String in WorldHistory.all_subjects().keys():
		var state: Dictionary = WorldHistory.subject(subject_id)
		var kind := str(state.get("kind", ""))
		if kind != "person" and kind != "faction":
			continue
		if subject_id == "player":
			continue
		var card := Card.new()
		card.id = subject_id
		card.kind = "photo" if kind == "person" else "record"
		card.title = str(state.get("name", subject_id)).to_upper()
		card.body = str(state.get("role", state.get("doctrine", ""))).to_upper()
		card.struck = str(state.get("status", "")) in ["dead", "executed"]
		card.seed_value = rng.randi()
		card.size = Vector2(132, 148) if kind == "person" else Vector2(164, 92)
		# Clustered around whichever theory wants this kind of evidence, so the
		# wall has districts rather than a even scatter.
		var anchor := _anchor_for(kind, rng)
		card.at = anchor + Vector2(rng.randf_range(-230.0, 230.0), rng.randf_range(-190.0, 190.0))
		card.angle = rng.randf_range(-0.10, 0.10)
		card.tint = PAPER_COOL if kind == "faction" else PAPER
		cards.append(card)
		placed += 1
		# One string from the evidence to the theory it is filed under. Step 3
		# makes these the player's own claims; for now they are where the
		# evidence sits, which is already an argument.
		var theory_id := _theory_for(kind)
		if theory_cards.has(theory_id):
			threads.append({"from": card.id, "to": theory_id, "seed": rng.randi()})
		if placed > 14:
			break

	# What happened, as cuttings. The event log is the one true record in the
	# game and on this wall it is reduced to headlines, which is exactly the
	# distortion the two-records rule is about.
	var cut := 0
	for event: Dictionary in WorldHistory.recent_events(8):
		var card := Card.new()
		card.id = "event:%d" % cut
		card.kind = "cutting"
		card.title = str(event.get("type", "")).replace("_", " ").to_upper()
		var details: Dictionary = event.get("details", {})
		card.body = str(details.get("subject", details.get("rival", ""))).replace("_", " ").to_upper()
		card.seed_value = rng.randi()
		card.size = Vector2(rng.randf_range(120.0, 170.0), rng.randf_range(58.0, 84.0))
		card.at = Vector2(rng.randf_range(-660.0, 660.0), rng.randf_range(-420.0, 440.0))
		card.angle = rng.randf_range(-0.14, 0.14)
		card.tint = NEWSPRINT
		cards.append(card)
		if cut % 2 == 0:
			threads.append({"from": card.id, "to": str(THEORIES[cut % THEORIES.size()]["id"]), "seed": rng.randi()})
		cut += 1

	# The player is the one card that is always up, bottom centre, because every
	# theory on the wall is ultimately a theory about them.
	var self_card := Card.new()
	self_card.id = "player"
	self_card.kind = "photo"
	self_card.title = str(WorldHistory.subject("player").get("name", "THE HUNTER")).to_upper()
	self_card.body = "ME"
	self_card.at = Vector2(-60, 470)
	self_card.size = Vector2(140, 158)
	self_card.angle = 0.02
	self_card.seed_value = 4711
	cards.append(self_card)
	for theory: Dictionary in THEORIES:
		threads.append({"from": "player", "to": str(theory["id"]), "seed": rng.randi()})


func _anchor_for(kind: String, rng: RandomNumberGenerator) -> Vector2:
	var candidates: Array = []
	for theory: Dictionary in THEORIES:
		var pulls: Array = theory["pulls"]
		if pulls.has(kind):
			candidates.append(theory["at"])
	if candidates.is_empty():
		return Vector2(rng.randf_range(-400.0, 400.0), rng.randf_range(-300.0, 300.0))
	return candidates[rng.randi() % candidates.size()]


func _theory_for(kind: String) -> String:
	for theory: Dictionary in THEORIES:
		var pulls: Array = theory["pulls"]
		if pulls.has(kind):
			return str(theory["id"])
	return str(THEORIES[0]["id"])


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					zoom = clampf(zoom * 1.12, 0.35, 2.4)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					zoom = clampf(zoom / 1.12, 0.35, 2.4)
	elif event is InputEventMouseMotion and _dragging:
		pan += (event as InputEventMouseMotion).relative


func _to_screen(board: Vector2) -> Vector2:
	return _board_rect.get_center() + pan + board * zoom


func _draw() -> void:
	if not visible:
		return
	_board_rect = Rect2(Vector2.ZERO, size)
	_draw_cork()
	# Thread under the paper, because a string is pinned first and the next
	# card goes on top of it. Drawing it over everything is the tell that a
	# board was composited rather than built.
	for thread: Dictionary in threads:
		_draw_thread(thread)
	for card: Card in cards:
		if card.kind != "theory":
			_draw_card(card)
	# Theories last, because the argument sits on top of what it is made of.
	for card: Card in cards:
		if card.kind == "theory":
			_draw_card(card)
	_draw_wall_light()


## Cork, not a brown rectangle. The grain is what stops it reading as a colour
## swatch, and the frame is what makes it an object hanging in a room.
func _draw_cork() -> void:
	draw_rect(_board_rect, CORK_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	# Chipped granules. Dense enough to read as a surface at a glance and cheap
	# because it is one pass of small rects.
	for fleck in 900:
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var shade := CORK.lerp(CORK_DARK, rng.randf())
		draw_rect(Rect2(at, Vector2(rng.randf_range(2.0, 7.0), rng.randf_range(2.0, 5.0))), shade * Color(1, 1, 1, 0.55))
	Grunge.stain(self, size * Vector2(0.2, 0.7), 260.0, 77, Color("2a1c10"), 0.10)
	Grunge.stain(self, size * Vector2(0.8, 0.25), 300.0, 91, Color("3a2a16"), 0.08)
	# Old pin holes, from everything that used to be up here.
	rng.seed = 4402
	for hole in 140:
		draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(0.8, 1.8), Color(0, 0, 0, 0.35))
	# The frame.
	var frame := 14.0
	for edge in 4:
		var bar := Rect2(Vector2.ZERO, Vector2(size.x, frame)) if edge == 0 else \
			Rect2(Vector2(0, size.y - frame), Vector2(size.x, frame)) if edge == 1 else \
			Rect2(Vector2.ZERO, Vector2(frame, size.y)) if edge == 2 else \
			Rect2(Vector2(size.x - frame, 0), Vector2(frame, size.y))
		draw_rect(bar, Color("3b2a18"))
		draw_rect(bar, Color("120c07"), false, 1.0)


## Red thread, with sag in it. A straight line between two points is a diagram;
## a line that hangs is a piece of string somebody pulled tight and it went
## slack anyway.
func _draw_thread(thread: Dictionary) -> void:
	var from := _find(str(thread["from"]))
	var to := _find(str(thread["to"]))
	if from == null or to == null:
		return
	var a := _to_screen(from.at + from.size * 0.5 * zoom * 0.0)
	var b := _to_screen(to.at + to.size * 0.5 * zoom * 0.0)
	var sag := (b - a).length() * 0.06
	var points := PackedVector2Array()
	for step in 15:
		var t := float(step) / 14.0
		var point := a.lerp(b, t)
		point.y += sin(t * PI) * sag
		points.append(point)
	# The shadow the thread throws on the cork, so it sits off the surface.
	var shadow := PackedVector2Array()
	for point: Vector2 in points:
		shadow.append(point + Vector2(2.0, 3.0))
	draw_polyline(shadow, Color(0, 0, 0, 0.28 * open_blend), 2.0)
	draw_polyline(points, THREAD * Color(1, 1, 1, 0.85 * open_blend), 2.0)
	draw_polyline(points, Color(1, 0.6, 0.5, 0.12 * open_blend), 1.0)


func _find(card_id: String) -> Card:
	for card: Card in cards:
		if card.id == card_id:
			return card
	return null


func _draw_card(card: Card) -> void:
	var at := _to_screen(card.at)
	var card_size := card.size * zoom
	if not _board_rect.grow(240.0).has_point(at):
		return
	# Rotated about its own pin, because paper on a wall hangs off one point.
	draw_set_transform(at, card.angle, Vector2.ONE)
	var body := Rect2(-card_size * Vector2(0.5, 0.0), card_size)
	# Paper throws a shadow. This is most of what makes a flat rect read as a
	# thing lying on top of another thing.
	draw_rect(Rect2(body.position + Vector2(4, 5), body.size), Color(0, 0, 0, 0.34 * open_blend))
	match card.kind:
		"theory":
			_draw_theory(body, card)
		"photo":
			_draw_photo(body, card)
		"cutting":
			_draw_cutting(body, card)
		_:
			_draw_record(body, card)
	if card.struck:
		# Crossed out in marker. Somebody on this wall is finished.
		draw_line(body.position, body.end, MARKER * Color(1, 1, 1, 0.8 * open_blend), 4.0)
		draw_line(body.position + Vector2(body.size.x, 0), body.position + Vector2(0, body.size.y), MARKER * Color(1, 1, 1, 0.8 * open_blend), 4.0)
	# The pin, at the top, which is the point everything else rotated about.
	draw_circle(Vector2(1.5 * zoom, 8.0 * zoom), 6.0 * zoom, Color(0, 0, 0, 0.35 * open_blend))
	draw_circle(Vector2(0, 6.0 * zoom), 5.0 * zoom, PIN * Color(1, 1, 1, open_blend))
	draw_circle(Vector2(-1.4 * zoom, 4.6 * zoom), 1.8 * zoom, Color(1, 1, 1, 0.5 * open_blend))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The authored speculation. Index card, block capitals, underlined twice, and a
## question mark somebody added later.
func _draw_theory(body: Rect2, card: Card) -> void:
	draw_rect(body, PAPER * Color(1, 1, 1, open_blend))
	draw_rect(body, INK * Color(1, 1, 1, 0.25 * open_blend), false, 1.0)
	# Ruled lines, because it is an index card.
	for rule in range(2, int(body.size.y / (15.0 * zoom))):
		var y := body.position.y + float(rule) * 15.0 * zoom
		draw_line(Vector2(body.position.x + 6, y), Vector2(body.end.x - 6, y), Color("6f86a8") * Color(1, 1, 1, 0.22 * open_blend), 1.0)
	Grunge.grain(self, body, card.seed_value, 90, Color("8a7a5c"))
	# Written to fit the card. Somebody writing on an index card makes the
	# letters smaller when they run out of room; they do not write off the edge.
	var measure := body.size.x - 20.0 * zoom
	var cap := 13.0 * zoom
	while cap > 7.0 * zoom and CellOutzType.width_condensed(card.title, cap, 1.1 * zoom) > measure:
		cap -= 0.5 * zoom
	CellOutzType.draw_condensed(self, body.position + Vector2(10, 9) * zoom, card.title, cap, MARKER * Color(1, 1, 1, open_blend), 1.1 * zoom)
	var title_width := CellOutzType.width_condensed(card.title, cap, 1.1 * zoom)
	var underline := body.position + Vector2(10 * zoom, 11.0 * zoom + cap * 1.35)
	draw_line(underline, underline + Vector2(title_width, 0), MARKER * Color(1, 1, 1, 0.85 * open_blend), 2.0)
	draw_line(underline + Vector2(2, 4), underline + Vector2(title_width - 6, 4), MARKER * Color(1, 1, 1, 0.5 * open_blend), 1.4)
	var line_y := 42.0 * zoom
	for paragraph: String in card.body.split("\n"):
		for line: String in _wrap(paragraph, measure, 8.5 * zoom, 0.8 * zoom):
			CellOutzType.draw_condensed(self, body.position + Vector2(10 * zoom, line_y), line, 8.5 * zoom, INK * Color(1, 1, 1, 0.85 * open_blend), 0.8 * zoom)
			line_y += 13.0 * zoom
	# Somebody was not convinced.
	CellOutzType.draw_condensed(self, body.end - Vector2(22, 26) * zoom, "?", 20.0 * zoom, MARKER * Color(1, 1, 1, 0.6 * open_blend), 0.0)


## A person, as a photograph. Dark backing, a bad print, a name written on the
## white border underneath because that is where you write it.
func _draw_photo(body: Rect2, card: Card) -> void:
	draw_rect(body, PAPER_COOL * Color(1, 1, 1, open_blend))
	var window := Rect2(body.position + Vector2(7, 7) * zoom, body.size - Vector2(14, 34) * zoom)
	draw_rect(window, PHOTO_BACK * Color(1, 1, 1, open_blend))
	# The subject: a head and shoulders, lit from one side, never a face. Nobody
	# on this wall was photographed with their consent.
	var centre := window.get_center()
	var scale := window.size.y * 0.5
	draw_colored_polygon(_ellipse(centre + Vector2(0, -scale * 0.22), scale * 0.3, scale * 0.36, 18), Color("4e4a42") * Color(1, 1, 1, open_blend))
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-scale * 0.72, window.end.y - centre.y),
		centre + Vector2(-scale * 0.38, scale * 0.18),
		centre + Vector2(scale * 0.38, scale * 0.18),
		centre + Vector2(scale * 0.72, window.end.y - centre.y),
	]), Color("413d36") * Color(1, 1, 1, open_blend))
	Grunge.grain(self, window, card.seed_value, 120, Color("9a9488"))
	# Flash blow-out down one side, which is what a field photograph looks like.
	draw_rect(Rect2(window.position, Vector2(window.size.x * 0.22, window.size.y)), Color(1, 1, 1, 0.05 * open_blend))
	CellOutzType.draw_condensed(self, body.position + Vector2(8, body.size.y - 24 * zoom), card.title, 8.5 * zoom, INK * Color(1, 1, 1, 0.9 * open_blend), 0.7 * zoom)
	if card.body != "":
		CellOutzType.draw_condensed(self, body.position + Vector2(8, body.size.y - 13 * zoom), card.body, 6.5 * zoom, INK * Color(1, 1, 1, 0.5 * open_blend), 0.6 * zoom)


## A headline torn out of something. Newsprint, a ragged edge, and a marker
## circle round the part that matters.
func _draw_cutting(body: Rect2, card: Card) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed_value
	# The torn edge is the whole point: a cutting with four clean sides is a
	# label, not something somebody pulled out of a page.
	draw_rect(body, card.tint * Color(1, 1, 1, open_blend))
	# The torn edge is the whole point: a cutting with four clean sides is a
	# label, not something somebody pulled out of a page. Bitten out of the
	# paper with cork-coloured notches rather than drawn as an outline, because
	# a ring polygon of this shape does not fill reliably.
	var notch := 4.0 * zoom
	var runs := 14
	for step in runs:
		var t := float(step) / float(runs)
		var x := body.position.x + body.size.x * t
		var y := body.position.y + body.size.y * t
		var run := body.size.x / float(runs) + 1.0
		var drop := body.size.y / float(runs) + 1.0
		_bite(Rect2(Vector2(x, body.position.y), Vector2(run, rng.randf_range(0.5, notch))))
		_bite(Rect2(Vector2(x, body.end.y - rng.randf_range(0.5, notch)), Vector2(run, notch)))
		_bite(Rect2(Vector2(body.position.x, y), Vector2(rng.randf_range(0.5, notch), drop)))
		_bite(Rect2(Vector2(body.end.x - rng.randf_range(0.5, notch), y), Vector2(notch, drop)))
	Grunge.grain(self, body, card.seed_value + 7, 70, Color("7d7360"))
	CellOutzType.draw_condensed(self, body.position + Vector2(7, 7) * zoom, card.title, 8.5 * zoom, INK * Color(1, 1, 1, 0.9 * open_blend), 0.7 * zoom)
	if card.body != "":
		CellOutzType.draw_condensed(self, body.position + Vector2(7, 22) * zoom, card.body, 7.0 * zoom, INK * Color(1, 1, 1, 0.6 * open_blend), 0.6 * zoom)
		# Ringed in marker, the way you ring the name you think matters.
		var ring := Rect2(body.position + Vector2(4, 17) * zoom, Vector2(CellOutzType.width_condensed(card.body, 7.0 * zoom, 0.6 * zoom) + 8.0 * zoom, 14.0 * zoom))
		draw_arc(ring.get_center(), maxf(ring.size.x, ring.size.y) * 0.56, 0.0, TAU, 20, MARKER * Color(1, 1, 1, 0.65 * open_blend), 1.6)
	# Three lines of body copy nobody reads, as texture rather than as words.
	Grunge.scrawl(self, body.position + Vector2(7, 38) * zoom, body.size.x - 14.0 * zoom, 3, card.seed_value, INK * Color(1, 1, 1, 0.35 * open_blend))


## A filed record: a faction, a place, a thing with a reference number. Typed,
## stamped, and taped up rather than pinned, because it came out of a cabinet.
func _draw_record(body: Rect2, card: Card) -> void:
	draw_rect(body, card.tint * Color(1, 1, 1, open_blend))
	draw_rect(body, INK * Color(1, 1, 1, 0.3 * open_blend), false, 1.0)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 16.0 * zoom)), INK * Color(1, 1, 1, 0.12 * open_blend))
	Grunge.grain(self, body, card.seed_value, 80, Color("8a8578"))
	CellOutzType.draw_condensed(self, body.position + Vector2(7, 4) * zoom, card.title, 8.5 * zoom, INK * Color(1, 1, 1, 0.9 * open_blend), 0.8 * zoom)
	if card.body != "":
		var line_y := 22.0 * zoom
		for line: String in _wrap(card.body, body.size.x - 14.0 * zoom, 7.0 * zoom, 0.6 * zoom):
			if line_y > body.size.y - 14.0 * zoom:
				break
			CellOutzType.draw_condensed(self, body.position + Vector2(7 * zoom, line_y), line, 7.0 * zoom, INK * Color(1, 1, 1, 0.6 * open_blend), 0.6 * zoom)
			line_y += 11.0 * zoom
	Grunge.stamp(self, body.position + body.size * Vector2(0.62, 0.72), "FILED", 9.0 * zoom, -0.22, MARKER * Color(1, 1, 1, 0.45 * open_blend), card.seed_value)
	# Tape across two corners.
	for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(1.0, 1.0)]:
		var tape_at: Vector2 = body.position + body.size * corner
		draw_colored_polygon(PackedVector2Array([
			tape_at + Vector2(-20, -7) * zoom, tape_at + Vector2(20, -7) * zoom,
			tape_at + Vector2(18, 7) * zoom, tape_at + Vector2(-22, 7) * zoom,
		]), Color("d8cfa8") * Color(1, 1, 1, 0.34 * open_blend))


## A single bulb somewhere off to the left, because this is a room nobody has
## rewired. It also stops the wall reading as an evenly lit texture.
func _draw_wall_light() -> void:
	var centre := size * Vector2(0.34, 0.28)
	for ring in 9:
		var t := float(ring) / 8.0
		draw_circle(centre, size.x * (0.25 + t * 0.62), Color(0, 0, 0, 0.055))
	draw_rect(_board_rect, Color("120b06") * Color(1, 1, 1, 0.10))


## Wrapped to the stencil's own measure, so a claim stays on its card.
func _wrap(text: String, width: float, cap_height: float, tracking: float) -> Array:
	var lines: Array = []
	var line := ""
	for word: String in text.split(" ", false):
		var candidate: String = word if line.is_empty() else line + " " + word
		if CellOutzType.width_condensed(candidate, cap_height, tracking) > width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	return lines


## A notch taken out of the paper, in the colour of what is behind it.
func _bite(rect: Rect2) -> void:
	draw_rect(rect, CORK_DARK * Color(1, 1, 1, 0.9 * open_blend))


func _ellipse(centre: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
