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

const FieldCamera := preload("res://systems/field_camera.gd")

const BOARD_ID := "pin_board"

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
		"supported_by": ["lien", "part", "carried_part", "robbery"],
	},
	{
		"id": "theory_frequency",
		"title": "THE SIGNAL IS THE PRAYER",
		"claim": "THE MASTS ARE NOT FOR TALKING.\nSOMETHING IS BEING CARRIED UP.",
		"at": Vector2(120, -380),
		"pulls": ["place", "signal"],
		"supported_by": ["signal", "mast", "place"],
	},
	{
		"id": "theory_absent_god",
		"title": "HE IS NOT LISTENING",
		"claim": "YOU CANNOT GET HIS ATTENTION BY ASKING.\nSO MAKE SOMETHING HE HAS TO ANSWER FOR.",
		"at": Vector2(-180, 120),
		"pulls": ["event", "person"],
		"supported_by": ["execution", "spare", "downed"],
	},
	{
		"id": "theory_rotation",
		"title": "FOUR CHAIRS, ONE TABLE",
		"claim": "THE LEADERSHIP CHANGES AND THE ORDERS DO NOT.\nTHEREFORE THE ORDERS ARE NOT THEIRS.",
		"at": Vector2(520, -60),
		"pulls": ["faction", "person"],
		"supported_by": ["faction", "rank", "command"],
	},
	{
		"id": "theory_inside",
		"title": "THE HUNT IS THE PRODUCT",
		"claim": "THEY SELL YOU THE WIRE.\nTHEY SELL THEM YOUR NAME.",
		"at": Vector2(200, 340),
		"pulls": ["event", "faction"],
		"supported_by": ["wire", "bounty", "hunt", "sold"],
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


## L2. What the player has actually put on the wall: an array of
## `{ref, kind, at, angle, seed}`. This is the save, and it is the only thing on
## the board that is authored by the player rather than read out of the world.
var pinned: Array = []
## L2. What is in the player's hand, on its way to the wall. Pinning is a two
## step act — take it off a screen, then choose where it goes — because putting
## a photograph of somebody on your conspiracy wall should cost a decision.
var holding: Dictionary = {}

## L3. The strings the player has drawn. Each one is a claim: this connects to
## that. The board keeps them exactly as drawn and says nothing about whether
## they are true, because that is the mechanic.
var strings: Array = []

var cards: Array[Card] = []
var threads: Array = []
var pan := Vector2.ZERO
var zoom := 1.0
var clock := 0.0
var open_blend := 0.0

var _dragging := false
var _moving := ""
var _stringing := ""
var _board_rect := Rect2()

signal pinned_changed()
signal strings_changed()
## L3.2. Something the world bears out, which means there is work in it.
signal lead_opened(from: String, to: String)


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
	load_board()
	rebuild()
	visible = true
	open_blend = 0.0


## The wall persists, because it is a thing in a room rather than a view. Kept
## in `WorldHistory` alongside everything else so a save carries the player's
## reading of the world and not only the world.
func load_board() -> void:
	var record: Dictionary = WorldHistory.subject(BOARD_ID)
	if record.is_empty():
		# L2.3. A new board is not blank and it is not full. The authored
		# theories are up because they were on the wall when the player found
		# it, and exactly one card is theirs: their own. Everything else is
		# pinned by hand or it is not up at all.
		pinned = [{"ref": "player", "kind": "photo", "at": Vector2(-60, 470), "angle": 0.02, "seed": 4711}]
		strings = []
		save_board()
		return
	strings.clear()
	for row: Dictionary in record.get("strings", []):
		strings.append({"from": str(row.get("from", "")), "to": str(row.get("to", "")), "seed": int(row.get("seed", 0))})
	pinned.clear()
	for entry: Dictionary in record.get("pinned", []):
		var at: Variant = entry.get("at", Vector2.ZERO)
		pinned.append({
			"ref": str(entry.get("ref", "")),
			"kind": str(entry.get("kind", "photo")),
			# Saves come back through JSON, where a Vector2 arrives as an array.
			"at": at if at is Vector2 else Vector2(float(at[0]), float(at[1])),
			"angle": float(entry.get("angle", 0.0)),
			"seed": int(entry.get("seed", 0)),
		})


func save_board() -> void:
	var rows: Array = []
	for entry: Dictionary in pinned:
		var at: Vector2 = entry["at"]
		rows.append({"ref": entry["ref"], "kind": entry["kind"], "at": [at.x, at.y], "angle": entry["angle"], "seed": entry["seed"]})
	WorldHistory.update_subject(BOARD_ID, {"pinned": rows, "strings": strings.duplicate(true)}, "board_changed")


## L2.1. Offered from the index, the camera and CARRY. Returns false when it is
## already up, because a wall does not take the same photograph twice.
func pin(ref: String, kind := "photo", at := Vector2.INF) -> bool:
	if ref == "" or is_pinned(ref):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ref)
	pinned.append({
		"ref": ref,
		"kind": kind,
		"at": at if at != Vector2.INF else _free_space(rng, ref),
		"angle": rng.randf_range(-0.11, 0.11),
		"seed": rng.randi(),
	})
	save_board()
	rebuild()
	pinned_changed.emit()
	WorldHistory.record_event("board_pinned", {"subject": ref, "kind": kind})
	return true


## Taking something down is as much a claim as putting it up.
func unpin(ref: String) -> bool:
	for index in pinned.size():
		if str((pinned[index] as Dictionary)["ref"]) == ref:
			pinned.remove_at(index)
			for thread in range(strings.size() - 1, -1, -1):
				var row: Dictionary = strings[thread]
				if str(row["from"]) == ref or str(row["to"]) == ref:
					strings.remove_at(thread)
			save_board()
			rebuild()
			pinned_changed.emit()
			return true
	return false


## L3.1. Lays a string between two things on the wall. The board takes it without
## comment. L3.3 is the whole design: a false string is drawn exactly like a
## true one, nothing marks it, and the player finds out by acting on it.
func lay_string(from: String, to: String) -> bool:
	if from == "" or to == "" or from == to:
		return false
	if not _on_wall(from) or not _on_wall(to):
		return false
	for existing: Dictionary in strings:
		var a := str(existing["from"])
		var b := str(existing["to"])
		if (a == from and b == to) or (a == to and b == from):
			return false
	strings.append({"from": from, "to": to, "seed": hash(from + to)})
	save_board()
	# L3.2. A string the world supports opens work. One that it does not is
	# recorded exactly the same way, because the ledger holds what the player
	# did, not whether they were right.
	var supported := supports(from, to)
	WorldHistory.record_event("board_string_drawn", {"subject": from, "target": to, "supported": supported})
	if supported:
		_open_lead(from, to)
	rebuild()
	strings_changed.emit()
	return true


func cut_string(from: String, to: String) -> bool:
	for index in strings.size():
		var row: Dictionary = strings[index]
		var a := str(row["from"])
		var b := str(row["to"])
		if (a == from and b == to) or (a == to and b == from):
			strings.remove_at(index)
			save_board()
			rebuild()
			strings_changed.emit()
			return true
	return false


## L3.2 / L3.3. Whether the world actually bears the connection out. This is
## never shown on the board — it is only consulted when a lead would open, and
## when the player goes and acts on the claim.
func supports(from: String, to: String) -> bool:
	var theory := _theory(from)
	var other := to
	if theory.is_empty():
		theory = _theory(to)
		other = from
	if not theory.is_empty():
		# Evidence supports a theory when the evidence is of the kind the theory
		# says would bear it out. A carried heart supports "it is a debt"; a
		# faction doctrine does not.
		var tokens: Array = theory.get("supported_by", [])
		var haystack := (other + " " + _describe(other)).to_lower()
		for token: String in tokens:
			if haystack.contains(token):
				return true
		return false
	# Between two pieces of evidence: the world has to actually connect them.
	if WorldHistory.relationship_strength(from, to) != 0 or WorldHistory.relationship_strength(to, from) != 0:
		return true
	var from_state: Dictionary = WorldHistory.subject(from)
	var to_state: Dictionary = WorldHistory.subject(to)
	if str(from_state.get("faction_id", "@")) == to or str(to_state.get("faction_id", "@")) == from:
		return true
	# A cutting or a part naming the other is a connection you can point at.
	if _describe(from).to_lower().contains(to.to_lower()) or _describe(to).to_lower().contains(from.to_lower()):
		return true
	for event: Dictionary in WorldHistory.events:
		var details: Dictionary = event.get("details", {})
		var mentioned := false
		var both := 0
		for value: Variant in details.values():
			var text := str(value)
			if text == from or text == to:
				both += 1
				mentioned = true
		if mentioned and both >= 2:
			return true
	return false


## What a reference is, in words, for the support check. Deliberately the same
## text the card shows, so a player reading the wall is reading what the check
## reads.
func _describe(ref: String) -> String:
	if ref.begins_with("part:"):
		return "carried_part part lien " + ref.substr(5).replace("@", " ")
	if ref.begins_with("event:"):
		var index := int(ref.substr(6))
		if index >= 0 and index < WorldHistory.events.size():
			var event: Dictionary = WorldHistory.events[index]
			return str(event.get("type", "")) + " " + str((event.get("details", {}) as Dictionary).values())
		return ""
	if ref.begins_with("photo:"):
		for frame: Dictionary in FieldCamera.album():
			if str(frame.get("id", "")) == ref.substr(6):
				return str(frame.get("caption", "")) + " " + str(frame.get("location", ""))
		return ""
	var state: Dictionary = WorldHistory.subject(ref)
	var kind := str(state.get("kind", ""))
	return "%s %s %s %s" % [kind, state.get("role", ""), state.get("doctrine", ""), state.get("faction_id", "")]


## L3.2. A supported string opens work. Recorded as a lead on the board's own
## subject rather than as quest state, because there is no quest state.
func _open_lead(from: String, to: String) -> void:
	var record: Dictionary = WorldHistory.subject(BOARD_ID)
	var leads: Array = (record.get("leads", []) as Array).duplicate()
	var lead := {"from": from, "to": to, "opened": WorldHistory.events.size()}
	for existing: Dictionary in leads:
		if str(existing.get("from", "")) == from and str(existing.get("to", "")) == to:
			return
	leads.append(lead)
	WorldHistory.update_subject(BOARD_ID, {"leads": leads}, "lead_opened")
	lead_opened.emit(from, to)


func leads() -> Array:
	return (WorldHistory.subject(BOARD_ID).get("leads", []) as Array).duplicate()


func _theory(ref: String) -> Dictionary:
	for theory: Dictionary in THEORIES:
		if str(theory["id"]) == ref:
			return theory
	return {}


func _on_wall(ref: String) -> bool:
	return is_pinned(ref) or not _theory(ref).is_empty()


func is_pinned(ref: String) -> bool:
	for entry: Dictionary in pinned:
		if str(entry["ref"]) == ref:
			return true
	return false


## Held in the hand, from wherever the player took it. The wall does not accept
## it until they say where it goes.
func hold(ref: String, kind: String, title := "") -> void:
	holding = {"ref": ref, "kind": kind, "title": title}


func drop_held(at: Vector2) -> bool:
	if holding.is_empty():
		return false
	var placed := pin(str(holding["ref"]), str(holding["kind"]), at)
	holding = {}
	return placed


## Where a new card lands when the player has not said. Near the theory it bears
## on, crowded rather than spaced: a conspiracy wall is dense, and maximising
## clearance produced an evenly scattered grid that read as a gallery hang. It
## only refuses a position that would bury another card outright.
func _free_space(rng: RandomNumberGenerator, ref := "") -> Vector2:
	var anchor := _pull_anchor(ref, rng)
	var best := anchor
	var best_score := -INF
	for attempt in 32:
		var candidate := anchor + Vector2(rng.randf_range(-250.0, 250.0), rng.randf_range(-180.0, 180.0))
		var nearest := INF
		for entry: Dictionary in pinned:
			nearest = minf(nearest, (candidate - (entry["at"] as Vector2)).length())
		for theory: Dictionary in THEORIES:
			nearest = minf(nearest, (candidate - (theory["at"] as Vector2)).length())
		# Close is good, on top of something is not. The peak sits just outside
		# a card's own footprint, so paper overlaps at the corners the way it
		# does on a real wall.
		var score := -absf(nearest - 155.0)
		if nearest < 92.0:
			score -= 600.0
		if score > best_score:
			best_score = score
			best = candidate
	return best


## The theory a new card gravitates to, so the wall grows in clusters that mean
## something rather than filling left to right.
func _pull_anchor(ref: String, rng: RandomNumberGenerator) -> Vector2:
	var haystack := (ref + " " + _describe(ref)).to_lower()
	for theory: Dictionary in THEORIES:
		for token: String in theory.get("supported_by", []):
			if haystack.contains(token):
				return (theory["at"] as Vector2) + Vector2(0, 150)
	var kind := str(WorldHistory.subject(ref).get("kind", ""))
	for theory: Dictionary in THEORIES:
		if (theory["pulls"] as Array).has(kind):
			return (theory["at"] as Vector2) + Vector2(0, 150)
	return Vector2(rng.randf_range(-400.0, 400.0), rng.randf_range(-280.0, 280.0))


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	open_blend = minf(open_blend + delta * 2.6, 1.0)
	queue_redraw()


## Builds the visible wall from two sources that must not be confused: the
## authored theories, which were on the wall when the player found it, and the
## cards the player pinned themselves. Nothing else appears. The board is not a
## view of `WorldHistory` — it is what one person decided was worth keeping,
## which is why it is allowed to be wrong.
func rebuild() -> void:
	cards.clear()
	threads.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210

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

	for entry: Dictionary in pinned:
		var card := _card_for(str(entry["ref"]), str(entry["kind"]), int(entry["seed"]))
		if card == null:
			continue
		card.at = entry["at"]
		card.angle = float(entry["angle"])
		cards.append(card)

	# L3.3. Every string is drawn the same. Nothing here consults `supports()`,
	# and that is deliberate: a wrong connection has to look exactly as
	# convincing as a right one or the mechanic does not exist.
	for row: Dictionary in strings:
		threads.append({"from": str(row["from"]), "to": str(row["to"]), "seed": int(row["seed"])})


## One pinned reference becomes one piece of paper. The reference decides what
## kind of object it is — a person is a photograph, a faction a filed record, an
## event a cutting, a carried part a label off the thing itself — because the
## evidence on a wall is physical and came from somewhere.
func _card_for(ref: String, kind: String, seed_value: int) -> Card:
	var card := Card.new()
	card.id = ref
	card.kind = kind
	card.seed_value = seed_value
	if ref.begins_with("event:"):
		var index := int(ref.substr(6))
		var log: Array = WorldHistory.events
		if index < 0 or index >= log.size():
			return null
		var event: Dictionary = log[index]
		var details: Dictionary = event.get("details", {})
		card.kind = "cutting"
		card.title = str(event.get("type", "")).replace("_", " ").to_upper()
		card.body = str(details.get("subject", details.get("rival", ""))).replace("_", " ").to_upper()
		card.size = Vector2(152, 74)
		card.tint = NEWSPRINT
		return card
	if ref.begins_with("photo:"):
		# L2.2. A photograph carries its verifiable contents onto the wall. The
		# caption is generated from what was in frame by `field_camera.gd`, so a
		# picture on this board can never claim something the body was not
		# doing — which is the one thing on a wall of speculation that is true.
		var photo_id := ref.substr(6)
		for frame: Dictionary in FieldCamera.album():
			if str(frame.get("id", "")) != photo_id:
				continue
			card.kind = "photo"
			card.title = str(frame.get("location", "UNRECORDED")).to_upper()
			card.body = str(frame.get("caption", "")).to_upper()
			card.size = Vector2(168, 164)
			return card
		return null
	if ref.begins_with("part:"):
		# L2.1. Pinned off CARRY. A part on the wall is a label with the weight
		# and whose it was, because the part itself is in your bag.
		var pieces: PackedStringArray = ref.substr(5).split("@")
		card.kind = "cutting"
		card.title = pieces[0].to_upper()
		card.body = ("OFF " + str(WorldHistory.subject(pieces[1]).get("name", pieces[1]))).to_upper() if pieces.size() > 1 else ""
		card.size = Vector2(146, 70)
		card.tint = NEWSPRINT
		return card
	var state: Dictionary = WorldHistory.subject(ref)
	if state.is_empty():
		return null
	var subject_kind := str(state.get("kind", "person"))
	card.kind = "record" if subject_kind == "faction" else "photo"
	card.title = str(state.get("name", ref)).to_upper()
	card.body = str(state.get("role", state.get("doctrine", ""))).to_upper()
	card.struck = str(state.get("status", "")) in ["dead", "executed"]
	card.size = Vector2(164, 92) if subject_kind == "faction" else Vector2(132, 148)
	card.tint = PAPER_COOL if subject_kind == "faction" else PAPER
	if ref == "player":
		card.body = "ME"
		card.size = Vector2(140, 158)
	return card


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
				if button.pressed:
					# Something in the hand goes on the wall where you clicked.
					if not holding.is_empty():
						drop_held(_to_board(button.position))
						return
					# Otherwise you have taken hold of a card, or of the wall.
					_moving = _card_at(button.position)
					_dragging = _moving == ""
				else:
					if _moving != "":
						save_board()
					_moving = ""
					_dragging = false
			MOUSE_BUTTON_MIDDLE:
				# L3.1. Held from one card to another lays a string between
				# them. Middle button so it never fights panning or moving.
				if button.pressed:
					_stringing = _card_at(button.position)
				elif _stringing != "":
					var landed := _card_at(button.position)
					if landed != "" and landed != _stringing:
						lay_string(_stringing, landed)
					_stringing = ""
			MOUSE_BUTTON_RIGHT:
				# L2. Taken down. Theories are not the player's to remove.
				if button.pressed:
					var under := _card_at(button.position)
					# A string under the cursor is cut before the card under it
					# is taken down, because cutting is the smaller act.
					if under != "" and _cut_any(under):
						return
					if under != "" and is_pinned(under):
						unpin(under)
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					zoom = clampf(zoom * 1.12, 0.35, 2.4)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					zoom = clampf(zoom / 1.12, 0.35, 2.4)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _moving != "":
			move_card(_moving, motion.relative / zoom)
		elif _dragging:
			pan += motion.relative


## Cards are moved by hand, and where the player puts a thing on a wall is
## itself a claim about what it sits near.
func move_card(ref: String, by: Vector2) -> void:
	for entry: Dictionary in pinned:
		if str(entry["ref"]) == ref:
			entry["at"] = (entry["at"] as Vector2) + by
			rebuild()
			return


## Cuts every string running into a card. Used by the right button, so taking
## a card down never leaves threads hanging off nothing.
func _cut_any(ref: String) -> bool:
	var cut := false
	for index in range(strings.size() - 1, -1, -1):
		var row: Dictionary = strings[index]
		if str(row["from"]) == ref or str(row["to"]) == ref:
			strings.remove_at(index)
			cut = true
	if cut:
		save_board()
		rebuild()
		strings_changed.emit()
	return cut


func _card_at(screen: Vector2) -> String:
	# Backwards, so the card on top of the pile is the one you grab.
	for index in range(cards.size() - 1, -1, -1):
		var card: Card = cards[index]
		var at := _to_screen(card.at)
		if Rect2(at - Vector2(card.size.x * 0.5, 0.0) * zoom, card.size * zoom).has_point(screen):
			return card.id
	return ""


func _to_board(screen: Vector2) -> Vector2:
	return (screen - _board_rect.get_center() - pan) / zoom


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
	_draw_held()
	if _stringing != "":
		var anchor := _find(_stringing)
		if anchor != null:
			draw_line(_to_screen(anchor.at), get_local_mouse_position(), THREAD * Color(1, 1, 1, 0.6), 2.0)


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
	CellOutzType.draw_condensed(self, body.position + Vector2(8 * zoom, body.size.y - 26 * zoom), card.title, 8.5 * zoom, INK * Color(1, 1, 1, 0.9 * open_blend), 0.7 * zoom)
	if card.body != "":
		# Written on the border in pencil, wrapped, because a caption that runs
		# off the photograph is a caption nobody wrote by hand.
		var caption_y := body.size.y - 15.0 * zoom
		for line: String in _wrap(card.body, body.size.x - 16.0 * zoom, 6.5 * zoom, 0.6 * zoom):
			if caption_y > body.size.y - 2.0 * zoom:
				break
			CellOutzType.draw_condensed(self, body.position + Vector2(8 * zoom, caption_y), line, 6.5 * zoom, INK * Color(1, 1, 1, 0.55 * open_blend), 0.6 * zoom)
			caption_y += 9.0 * zoom


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


## What is in the player's hand, waiting for somewhere to go. Drawn under the
## cursor, tilted, with a shadow well clear of the wall, because it is not on
## the wall yet.
func _draw_held() -> void:
	if holding.is_empty():
		return
	var at := get_local_mouse_position()
	var card_size := Vector2(132, 92)
	draw_set_transform(at, 0.09, Vector2.ONE)
	var body := Rect2(-card_size * 0.5, card_size)
	draw_rect(Rect2(body.position + Vector2(9, 12), body.size), Color(0, 0, 0, 0.4))
	draw_rect(body, PAPER)
	draw_rect(body, INK * Color(1, 1, 1, 0.3), false, 1.0)
	CellOutzType.draw_condensed(self, body.position + Vector2(8, 8), str(holding.get("title", holding["ref"])).to_upper(), 9.0, INK * Color(1, 1, 1, 0.9), 0.7)
	CellOutzType.draw_condensed(self, body.position + Vector2(8, body.size.y - 18.0), "CLICK THE WALL", 7.0, MARKER * Color(1, 1, 1, 0.8), 0.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
