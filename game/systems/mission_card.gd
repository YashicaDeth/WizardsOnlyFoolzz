class_name MissionCard
extends Control

## The mission indicator Greg asked for: a task title "in massive celloutz
## style font, bloody and bony, xray, blobtrack, dither ... intense font
## animations that make it move around 4d, inverting, going crazy, and after
## that flashes", with "hakker celloutz.xyz code and sigils breaking apart".
##
## Placeholder art by design: Greg said he will replace it with his own. Put
## an image at `res://art/mission_cards/<card_id>.png` and it is drawn in
## place of the generated letters, with the same motion, glitch and flash
## around it, so swapping the art never touches the scenes that show cards.

const CellOutzType := preload("res://systems/celloutz_type.gd")

signal finished(card_id: String)

const BONE := Color("e8dcc0")
const BLOOD := Color("a8281a")
const DRIED := Color("4a0f0a")
const XRAY := Color("cfe9ff")
const CODE := Color("7fbf95")

const CODE_LINES := [
	"GET celloutz.xyz/asset/0C-7/firmware  403 FORBIDDEN",
	"wetwire.chip >> owner=celloutz  owner=??????",
	"sudo rm -rf /consent/*",
	"SIGIL_TABLE[07] checksum FAIL  FAIL  FAIL",
	"debt.meat.balance = NaN",
	"while(suffering) { suffering++; }",
	"celloutz.xyz :: route /reprocess :: DENIED BY ASSET",
	"0xDEAD 0xB0NE 0xB100D 0x0C07",
	"implant.handshake(OWNER) -> OWNER UNKNOWN",
	"ritual.bind(asset) ... asset.bind(ritual)",
]

var card_id := "card"
var text := "END ALL SUFFERING"
var duration := 5.2
var clock := 0.0
var playing := false
var custom_art: Texture2D
var _seed := 0


## Starts the card. `seconds` is the whole piece, flash included.
func play(id: String, words: String, seconds := 5.2) -> void:
	card_id = id
	text = words.to_upper()
	duration = seconds
	clock = 0.0
	playing = true
	_seed = hash(id)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art_path := "res://art/mission_cards/%s.png" % id
	custom_art = load(art_path) as Texture2D if ResourceLoader.exists(art_path) else null
	WorldHistory.record_event("mission_card_shown", {"card_id": id, "text": text})
	set_process(true)
	queue_redraw()


func skip() -> void:
	if playing:
		clock = duration


func _process(delta: float) -> void:
	if not playing:
		return
	clock += delta
	queue_redraw()
	if clock >= duration:
		playing = false
		visible = false
		set_process(false)
		finished.emit(card_id)


func _draw() -> void:
	if not playing:
		return
	var view := size
	var t := clampf(clock / duration, 0.0, 1.0)
	var flash_at := duration - 0.55
	var inverted := _inverted()
	var ground := DRIED.darkened(0.6) if not inverted else BONE
	draw_rect(Rect2(Vector2.ZERO, view), Color(ground, clampf(clock * 3.0, 0.0, 0.92)))
	_draw_code(view, inverted)
	_draw_sigils(view, t, inverted)
	_draw_title(view, inverted)
	_draw_tracking(view)
	_draw_dither(view)
	# The flash: white, then gone.
	if clock >= flash_at:
		var f := clampf((clock - flash_at) / 0.55, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, 1.0 - absf(f * 2.0 - 0.6)))


## Hard inversions that come faster as the card goes on.
func _inverted() -> bool:
	var rate := lerpf(1.6, 9.0, clampf(clock / duration, 0.0, 1.0))
	return fmod(clock * rate + float(_seed % 7) * 0.13, 1.0) < 0.12


func _draw_title(view: Vector2, inverted: bool) -> void:
	var words := text.split(" ")
	var cap := minf(view.y * 0.2, view.x / maxf(6.0, float(_longest(words)) * 0.9))
	# Letter count undersizes wide words (OVERTAKEN ran off the left edge):
	# fit the widest word's real drawn width, tracking included, to 88%.
	for word in words:
		var drawn := CellOutzType.width(word, cap, cap * 0.08) + cap * 0.3
		if drawn > view.x * 0.88:
			cap *= view.x * 0.88 / drawn
	var line_gap := cap * 1.25
	var total := line_gap * float(words.size())
	var top := view.y * 0.5 - total * 0.5 + cap * 0.1
	var slam := CelloutzEase.slam(clampf(clock / 0.45, 0.0, 1.0))
	for line in words.size():
		var word := words[line]
		var tracking := cap * 0.08
		var width := CellOutzType.width(word, cap, tracking)
		var x := view.x * 0.5 - width * 0.5
		var y := top + line_gap * float(line)
		for index in word.length():
			var glyph := word.substr(index, 1)
			var gw := CellOutzType.width(glyph, cap, 0.0)
			var phase := float(index) * 0.7 + float(line) * 1.9
			# "4D": each letter turns through a fake depth axis (its width
			# swings through zero and flips), wobbles on a second one, and
			# the whole line shears.
			var turn := cos(clock * (2.4 + float(line)) + phase)
			var stretch := maxf(0.08, absf(turn)) * slam
			var lift := sin(clock * 5.3 + phase) * cap * 0.06
			var jitter := Vector2(_noise(index, line, 0) * cap * 0.05, _noise(index, line, 1) * cap * 0.05) * clampf(clock, 0.0, 1.0)
			var shear := sin(clock * 1.7 + float(line)) * cap * 0.12
			var at := Vector2(x + gw * (1.0 - stretch) * 0.5 + shear, y + lift) + jitter
			var bone := XRAY if turn < 0.0 else BONE
			if inverted:
				bone = DRIED
			# Blood under, bone over, an X-ray ghost offset like a bad scan.
			CellOutzType.draw_text(self, at + Vector2(cap * 0.05, cap * 0.07), glyph, cap, Color(BLOOD, 0.9), 0.0, cap * 0.04, stretch)
			CellOutzType.draw_text(self, at + Vector2(-cap * 0.03 * sin(clock * 9.0), 0), glyph, cap, Color(XRAY, 0.25), 0.0, 0.0, stretch)
			CellOutzType.draw_text(self, at, glyph, cap, bone, 0.0, cap * 0.02, stretch)
			# Drips off the bottom of the letter.
			var drip := fmod(clock * 0.7 + phase, 1.0)
			draw_line(at + Vector2(gw * 0.5, cap), at + Vector2(gw * 0.5, cap + drip * cap * 0.6), Color(BLOOD, 1.0 - drip), maxf(2.0, cap * 0.03))
			x += gw + tracking
	if custom_art != null:
		var art_size := custom_art.get_size() * minf(view.x * 0.8 / custom_art.get_size().x, view.y * 0.6 / custom_art.get_size().y)
		var wobble := Vector2(sin(clock * 3.0), cos(clock * 2.3)) * 8.0
		draw_texture_rect(custom_art, Rect2(view * 0.5 - art_size * 0.5 + wobble, art_size), false, Color(1, 1, 1, slam))


func _draw_code(view: Vector2, inverted: bool) -> void:
	var font := ThemeDB.fallback_font
	var line_height := 18.0
	var rows := int(view.y / line_height)
	for row in rows:
		var scroll := int(clock * 14.0) + row
		var line: String = CODE_LINES[(scroll + _seed) % CODE_LINES.size()]
		var cut := int(fmod(clock * 40.0 + float(row) * 7.0, float(line.length() + 20)))
		var shown := line.substr(0, mini(cut, line.length()))
		var x := fmod(float(row * 97 + _seed), maxf(1.0, view.x * 0.6))
		var colour := CODE if not inverted else DRIED
		draw_string(font, Vector2(x, float(row) * line_height + 14.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(colour, 0.22 + 0.2 * _noise(row, 3, 2)))


## Sigils breaking apart: the existing corrupted and burning seal drawings,
## driven hard.
func _draw_sigils(view: Vector2, t: float, inverted: bool) -> void:
	for index in 5:
		var angle := float(index) / 5.0 * TAU + clock * 0.3
		var center := view * 0.5 + Vector2(cos(angle) * view.x * 0.36, sin(angle) * view.y * 0.34)
		var radius := view.y * (0.09 + 0.03 * sin(clock * 2.0 + float(index)))
		var colour := Color(BLOOD if not inverted else DRIED, 0.55)
		if index % 2 == 0:
			CellOutzType.draw_seal_corrupted(self, center, radius, _seed + index, colour, clampf(t * 1.4, 0.0, 1.0), 6)
		else:
			CellOutzType.draw_seal_burning(self, center, radius, _seed + index, colour, clampf(t * 1.2, 0.0, 1.0), clock, 6)


## Blob tracking: boxes that lock onto parts of the title and label them, the
## way a tracker would, lagging and snapping.
func _draw_tracking(view: Vector2) -> void:
	var font := ThemeDB.fallback_font
	for index in 6:
		var snap := floorf(clock * 6.0 + float(index))
		var at := Vector2(0.2 + 0.6 * _hash01(int(snap) * 13 + index), 0.3 + 0.4 * _hash01(int(snap) * 7 + index * 3)) * view
		var box := Vector2(60.0 + 80.0 * _hash01(index * 5 + int(snap)), 40.0 + 50.0 * _hash01(index * 11))
		var rect := Rect2(at - box * 0.5, box)
		draw_rect(rect, Color(XRAY, 0.7), false, 1.5)
		draw_string(font, rect.position + Vector2(2, -4), "%s %0.2f" % [["BONE", "MEAT", "ASSET", "0C-7", "SIGIL", "VOID"][index], _hash01(int(snap) + index)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(XRAY, 0.8))


## Ordered dither over everything, heavier as it goes, so it reads as a
## signal breaking rather than a clean overlay.
func _draw_dither(view: Vector2) -> void:
	var cell := 6.0
	var strength := 0.10 + 0.12 * clampf(clock / duration, 0.0, 1.0)
	var cols := int(view.x / cell) + 1
	var rows := int(view.y / cell) + 1
	var offset := int(clock * 20.0) % 4
	for row in range(0, rows, 2):
		for col in range((row / 2 + offset) % 2, cols, 3):
			draw_rect(Rect2(float(col) * cell, float(row) * cell, cell * 0.5, cell * 0.5), Color(0, 0, 0, strength))


func _longest(words: PackedStringArray) -> int:
	var longest := 1
	for word in words:
		longest = maxi(longest, word.length())
	return longest


func _noise(a: int, b: int, c: int) -> float:
	return sin(clock * (7.0 + float(c) * 3.1) + float(a) * 12.9898 + float(b) * 78.233)


func _hash01(value: int) -> float:
	return fposmod(sin(float(value) * 12.9898 + float(_seed % 997)) * 43758.5453, 1.0)


class CelloutzEase:
	## Overshoots, then lands: the letters arrive like something thrown.
	static func slam(t: float) -> float:
		if t >= 1.0:
			return 1.0
		return (1.0 - pow(1.0 - t, 3.0)) + 0.3 * sin(t * PI)
