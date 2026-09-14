class_name DecantingPrologue
extends Control

## Greg: *"the starting cutscne needs to be lore accurate then have the part
## where you can fully character customise"*.
##
## The second half was already wired — `country_town_menu.gd::_start_game()`
## sends a run that has not begun to `vat_chamber.tscn`, the Growing Floor,
## which is the character creation. What was missing is the first half: nothing
## between the title card and the tank ever said what any of it *is*.
##
## Everything below is `DESIGN/COSMOLOGY.md` rather than invention. That
## document settles the frame the game had been playing without stating:
##
##   - CellOutz is not a brand. It is the demon faction, the underground, and
##     the joke the project sat on for months is that *the player has been
##     carrying hell's branded merchandise since the first scene*. The HUD is a
##     CellOutz product; the liability notice is CellOutz refusing
##     responsibility; the handheld is CellOutz hardware.
##   - wizardsonlyfoolz is the other end: the ascending mage collective, the
##     angelic register — and, in the document's own words, "a guild that will
##     not take you seriously". The game's title names the club the player is
##     locked out of.
##   - The player is a CellOut wizard, half demon and half angel. "You are
##     decanted out of a vat on the Growing Floor with a debt that is in the
##     meat, because CellOutz grew you and CellOutz owns the body. Being half of
##     the other thing is what makes you able to leave."
##
## So the register here is the one the document specifies for CellOutz —
## corporate, extractive, bodily, "a company that sells you your own organs
## back". It is a title of ownership, not a narrator. The one thing it must not
## do is explain the game; it states what the company thinks it owns, and the
## last card is the only place the other ladder is even mentioned, because
## being told what you are locked out of is the player's whole problem.

signal finished

const ARTERIAL := Color("c81f16")
const BONE := Color("ead4ad")
const ACID := Color("b4da48")
const BILE := Color("9a8c3f")

## Each card: a heading in the company's voice, and the lines under it. Held
## long enough to read once, never long enough to read twice.
const CARDS := [
	{
		"head": "CELLOUTZ INC.",
		"sub": "GROWING FLOOR / TITLE OF OWNERSHIP 0C-7",
		"lines": [
			"THE BODY DESCRIBED BELOW WAS GROWN TO ORDER",
			"AGAINST AN ACCOUNT IN ARREARS.",
		],
	},
	{
		"head": "TERMS",
		"sub": "SCHEDULE 1 / THE DEBT",
		"lines": [
			"THE DEBT IS NOT ON PAPER.",
			"THE DEBT IS IN THE MEAT.",
		],
	},
	{
		"head": "NOTICE OF DEFECT",
		"sub": "SCHEDULE 2 / THE OTHER HALF",
		"lines": [
			"THIS UNIT IS NOT ENTIRELY OURS.",
			"SOMETHING ABOVE PUT ITS HALF IN FIRST.",
			"WIZARDSONLYFOOLZ ARE NOT TAKING APPLICATIONS.",
		],
	},
	{
		"head": "",
		"sub": "",
		"lines": [
			"A COMPANY GREW YOU.",
			"BEING HALF OF THE OTHER THING IS HOW YOU LEAVE.",
		],
	},
]

const CARD_HOLD := 2.6
const CARD_FADE := 0.55

var clock := 0.0
var card := 0
var running := false
var _card_alpha := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40
	visible = false
	set_process(false)


func play() -> void:
	visible = true
	running = true
	clock = 0.0
	card = 0
	_card_alpha = 0.0
	set_process(true)
	queue_redraw()


## Any key or click gets out. A prologue somebody cannot skip is a prologue they
## resent on the second run, and this one plays on every new world.
func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	# Explicitly typed: `event.pressed` off a base `InputEvent` has no static
	# type, so `:=` cannot infer one and the whole script fails to compile.
	var pressed: bool = event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).is_echo()
	var clicked: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if pressed or clicked:
		accept_event()
		_end()


func _process(delta: float) -> void:
	if not running:
		return
	clock += delta
	var span := CARD_HOLD + CARD_FADE * 2.0
	if clock >= span:
		clock -= span
		card += 1
		if card >= CARDS.size():
			_end()
			return
	# In, hold, out.
	if clock < CARD_FADE:
		_card_alpha = clock / CARD_FADE
	elif clock < CARD_FADE + CARD_HOLD:
		_card_alpha = 1.0
	else:
		_card_alpha = maxf(0.0, 1.0 - (clock - CARD_FADE - CARD_HOLD) / CARD_FADE)
	queue_redraw()


func _end() -> void:
	running = false
	set_process(false)
	visible = false
	finished.emit()


func _draw() -> void:
	if not running or card >= CARDS.size():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("050203"))

	var entry: Dictionary = CARDS[card]
	var fade := _card_alpha
	var left := size.x * 0.18

	# Every other surface in this game carries the grain — the HUD, the plates,
	# the index, the device. These cards were a flat fill, which made the cold
	# open the one clean screen in a game whose entire look is authored decay:
	# it read as a different product's title sequence bolted to the front.
	# Seeded off the card so each is dirty in its own way rather than four
	# identical frames, and kept under the fade so it arrives with the card.
	# Scratches only, and deliberately not grain. Grain was tried at 0.05 and
	# again at 0.16 with more than double the density; both were checked in a
	# real capture and neither was perceptible against this card's own 050203
	# ground — the PNG grew by two kilobytes, so the marks were genuinely being
	# drawn, they simply had no black left to clear. Five hundred draw calls a
	# frame for something nobody can see is the trade X exists to refuse, so
	# the grain is not here. The scratches are, because those do read.
	CellOutzGrunge.scratches(self, Rect2(Vector2.ZERO, size), 4400 + card, 4)

	# The block was anchored at 0.36 of the height and grew downward, so every
	# card left the bottom two fifths of the frame as dead black and the text
	# sat neither centred nor cornered — floating high with nothing under it.
	# Measured and centred on its own height instead, at 0.46 rather than a
	# true half because a title card centred optically sits slightly high. A
	# one-line card and a four-line card are now both composed, where before
	# only the tallest one looked deliberate.
	var head := str(entry["head"])
	var sub_text := str(entry["sub"])
	var block := 0.0
	if not head.is_empty():
		block += 44.0
	if not sub_text.is_empty():
		block += 44.0
	block += float((entry["lines"] as Array).size()) * 26.0
	var y := maxf(0.0, (size.y - block) * 0.46)

	if not head.is_empty():
		CellOutzType.draw_stamped(self, Vector2(left, y), head, 30.0,
			ARTERIAL * Color(1, 1, 1, fade), ARTERIAL * Color(1, 1, 1, 0.22 * fade), 3.0)
		y += 44.0
	if not sub_text.is_empty():
		CellOutzType.draw_condensed(self, Vector2(left, y), sub_text, 10.0, BILE * Color(1, 1, 1, 0.8 * fade), 1.6)
		y += 20.0
		draw_line(Vector2(left, y), Vector2(size.x - left, y), ARTERIAL * Color(1, 1, 1, 0.35 * fade), 1.0)
		y += 24.0

	for line in entry["lines"]:
		CellOutzType.draw_condensed(self, Vector2(left, y), str(line), 13.0, BONE * Color(1, 1, 1, 0.9 * fade), 1.4)
		y += 26.0

	# The skip, stated once and quietly, in the corner where this game already
	# keeps its control hints.
	var hint := "ANY KEY / SKIP"
	var width := CellOutzType.width_condensed(hint, 9.0, 1.2)
	CellOutzType.draw_condensed(self, Vector2(size.x - width - 44.0, size.y - 44.0), hint,
		9.0, ACID * Color(1, 1, 1, 0.3 * fade), 1.2)
