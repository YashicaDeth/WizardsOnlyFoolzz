class_name ImplantBootHud
extends Control

## "then you get up get some ui cause of your brain implant being hacked"
## (Greg, DESIGN/ESCAPE_ROUTES.md, "The opening, continued"). There is no HUD
## in the tank. The HUD is the implant, and it only comes up once the implant
## has been taken: CellOutz firmware lines are typed, struck and overwritten,
## then the vitals, the objective and the prompt glitch on one at a time.
##
## Additive: the Growing Floor hands this its body-cam overlay (`attach`),
## which blanks it, and starts the boot when the player is on their knees
## (`begin`). It owns which overlay pieces show from then on; the chamber
## still owns what they say. After the boot it watches the objective line and
## glitches it whenever the task is rewritten (GET REVENGE over the escape).
##
## PLACEHOLDER TEXT: every firmware line below is an assistant draft, not
## Greg's copy. They sit in one table so his words replace them in one place.

signal booted

const BONE := Color("e8dcc0")
const BLOOD := Color("c8321e")
const CODE := Color("7fbf95")
const XRAY := Color("cfe9ff")

## The whole boot, and the rebirth's short one ("a rebirth runs a short
## version: no cards, quick boot").
const FULL_SECONDS := 2.6
const QUICK_SECONDS := 1.0
## Where in the boot (0..1) each HUD piece comes up, in Greg's order.
const REVEAL := {"frame": 0.18, "rec": 0.3, "vitals": 0.46, "objective": 0.64, "prompt": 0.8}
const REVEAL_GLITCH := 0.22
const OVERWRITE_GLITCH := 0.5

## PLACEHOLDER (Greg to replace): [what CellOutz wrote, what overwrote it].
const SEIZED_LINES := [
	["CELLOUTZ FIRMWARE 4.1  //  ASSET %s", "WETWIRE  //  OWNER UNKNOWN"],
	["OWNER: CELLOUTZ", "OWNER: ??????"],
	["MOTOR LOCK: ENGAGED", "MOTOR LOCK: SEVERED"],
	["CONSENT: ON FILE", "CONSENT: NOT FOUND"],
	["HUD: ASSET VIEW", "HUD: MOUNTING FOR ??????"],
]
## A player who refused nothing does not get the chip (SoulBreakthrough), but
## the tank still broke and the HUD still comes up: contested, not taken.
const CONTESTED_LINES := [
	["CELLOUTZ FIRMWARE 4.1  //  ASSET %s", "WETWIRE  //  WRITE PARTIAL"],
	["OWNER: CELLOUTZ", "OWNER: CELLOUTZ  //  CONTESTED"],
	["MOTOR LOCK: ENGAGED", "MOTOR LOCK: SLIPPING"],
	["HUD: ASSET VIEW", "HUD: ASSET VIEW  //  UNSUPERVISED"],
]

var clock := 0.0
var duration := FULL_SECONDS
var running := false
var done := false
var quick := false
var seized := true
var lines: Array = []
var osd: BodyCamOSD
var _revealed: Dictionary = {}
var _objective: Label
var _objective_seen := ""
var _objective_glitch := 0.0
var _seed := 7


func _init() -> void:
	name = "ImplantBootHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## Takes the overlay over and blanks it: nothing is on screen until the
## implant puts it there.
func attach(body_cam: BodyCamOSD) -> void:
	osd = body_cam
	_objective = body_cam.objective_source
	body_cam.all_pieces(false)
	for key in REVEAL:
		_revealed[key] = false


## `seizure` is SoulBreakthrough.seize's result (or empty): it decides whether
## the lines say the chip was taken or only fought over.
func begin(seizure: Dictionary, is_quick := false) -> void:
	if running or done:
		return
	quick = is_quick
	duration = QUICK_SECONDS if quick else FULL_SECONDS
	seized = seizure.is_empty() or bool(seizure.get("ok", false))
	var serial := str(seizure.get("serial", "0C-7"))
	if serial.is_empty():
		serial = "0C-7"
	lines.clear()
	for pair in (SEIZED_LINES if seized else CONTESTED_LINES):
		var was := str(pair[0])
		lines.append({"was": (was % serial.to_upper()) if was.contains("%s") else was, "now": str(pair[1])})
	if quick:
		lines = lines.slice(0, 2)
	clock = 0.0
	running = true
	visible = true
	_seed = hash(serial)
	WorldHistory.record_event("opening_implant_booted", {"seized": seized, "quick": quick, "serial": serial})
	set_process(true)
	queue_redraw()


## True once `piece` ("vitals", "objective", "prompt") has come up.
func revealed(piece: String) -> bool:
	return bool(_revealed.get(piece, false))


## 0..1 through the boot; 1 once it is over.
func progress() -> float:
	if done:
		return 1.0
	return clampf(clock / duration, 0.0, 1.0) if running else 0.0


## Runs the boot to its end at once (a skipped opening, or a test).
func finish() -> void:
	if not running and not done:
		begin({}, true)
	clock = duration
	_step(0.0)


## A scene that steps its own clock (the Growing Floor does, on its physics
## tick) sets this and calls `step`, so the boot keeps time with the scene.
var driven := false


func _process(delta: float) -> void:
	if not driven:
		_step(delta)


func step(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	if running:
		clock += delta
		var t := clampf(clock / duration, 0.0, 1.0)
		for key in REVEAL:
			var at: float = REVEAL[key]
			if t < at:
				_show(key, false)
				continue
			_revealed[key] = true
			# The piece fights its way on: it drops out in bursts for a moment
			# before it holds.
			var since := (t - at) * duration
			var glitch := since < REVEAL_GLITCH * (0.5 if quick else 1.0)
			_show(key, not glitch or _hash01(int(clock * 40.0) + key.length()) > 0.35)
		if t >= 1.0:
			running = false
			done = true
			for key in REVEAL:
				_show(key, true)
			if _objective != null:
				_objective_seen = _objective.text
			booted.emit()
	elif done and _objective != null and is_instance_valid(_objective):
		# A rewritten task glitches over the old one.
		if _objective.text != _objective_seen:
			if not _objective_seen.is_empty():
				_objective_glitch = OVERWRITE_GLITCH
			_objective_seen = _objective.text
		if _objective_glitch > 0.0:
			_objective_glitch = maxf(0.0, _objective_glitch - delta)
			_objective.modulate = Color(1.4, 0.8, 0.8, 1.0) if _hash01(int(Time.get_ticks_msec() / 30)) > 0.5 else Color.WHITE
			if _objective_glitch <= 0.0:
				_objective.modulate = Color.WHITE
	visible = running or _objective_glitch > 0.0
	queue_redraw()


func _draw() -> void:
	var view := size
	if running:
		var t := clampf(clock / duration, 0.0, 1.0)
		# Signal breaking up: heavy at the start, gone by the end.
		var storm := clampf(1.0 - t * 1.15, 0.0, 1.0)
		_draw_tears(view, storm)
		_draw_scanlines(view, 0.10 + storm * 0.18)
		_draw_firmware(view, t)
		for key in REVEAL:
			if osd == null or not revealed(key):
				continue
			var since := (t - float(REVEAL[key])) * duration
			if since < REVEAL_GLITCH:
				_draw_split(osd.piece_rect(key), 1.0 - since / REVEAL_GLITCH)
	elif _objective_glitch > 0.0 and osd != null:
		_draw_split(osd.piece_rect("objective"), _objective_glitch / OVERWRITE_GLITCH)


## CellOutz lines typed in, struck, and overwritten by whatever has the chip now.
func _draw_firmware(view: Vector2, t: float) -> void:
	var cap := clampf(view.y * 0.022, 10.0, 18.0)
	var left := view.x * 0.07
	var top := view.y * 0.34
	var header_alpha := clampf(t * 8.0, 0.0, 1.0) * clampf((1.0 - t) * 6.0, 0.0, 1.0)
	CellOutzType.draw_text(self, Vector2(left, top - cap * 2.6), "IMPLANT  //  HANDSHAKE", cap * 0.8, Color(XRAY, 0.7 * header_alpha))
	var count := lines.size()
	for index in count:
		var line: Dictionary = lines[index]
		# Each line gets its slot of the first two thirds of the boot: typed,
		# held, then overwritten.
		var start := 0.04 + float(index) / float(maxi(1, count)) * 0.5
		var typed := clampf((t - start) / 0.08, 0.0, 1.0)
		if typed <= 0.0:
			continue
		var fade := clampf((1.0 - t) * 5.0, 0.0, 1.0)
		var y := top + float(index) * cap * 1.9
		var jitter := (_hash01(index * 31 + int(clock * 24.0)) - 0.5) * cap * 0.6 * clampf(1.0 - t * 1.4, 0.0, 1.0)
		var over := clampf((t - start - 0.12) / 0.07, 0.0, 1.0)
		var was: String = line.was
		var now: String = line.now
		if over <= 0.0:
			var shown := was.substr(0, ceili(float(was.length()) * typed))
			CellOutzType.draw_text(self, Vector2(left + jitter, y), shown, cap, Color(CODE, 0.9 * fade))
			continue
		# Struck through, with the new owner written over the top in blood.
		var was_width := CellOutzType.width(was, cap)
		CellOutzType.draw_text(self, Vector2(left, y), was, cap, Color(CODE, 0.35 * fade))
		draw_line(Vector2(left - 4.0, y + cap * 0.5), Vector2(left + was_width * over + 4.0, y + cap * 0.5), Color(BLOOD, 0.9 * fade), maxf(2.0, cap * 0.16))
		var now_shown := now.substr(0, ceili(float(now.length()) * over))
		CellOutzType.draw_text(self, Vector2(left + was_width + cap * 1.2 + jitter, y), now_shown, cap, Color(BONE if seized else BLOOD, fade), 0.0, cap * 0.15)


## Horizontal tears: slices of the screen knocked sideways, some inverted.
func _draw_tears(view: Vector2, storm: float) -> void:
	if storm <= 0.0:
		return
	var tick := int(clock * 18.0)
	for index in int(3 + storm * 9.0):
		var y := _hash01(tick * 7 + index * 13) * view.y
		var h := 3.0 + _hash01(tick + index * 5) * 26.0 * storm
		var x := (_hash01(tick * 3 + index) - 0.3) * view.x * 0.5
		var w := view.x * (0.2 + _hash01(index * 17 + tick) * 0.7)
		var colour := [Color(BLOOD, 0.35), Color(CODE, 0.22), Color(XRAY, 0.18), Color(0, 0, 0, 0.55)][index % 4] as Color
		draw_rect(Rect2(x, y, w, h), Color(colour, colour.a * storm))


func _draw_scanlines(view: Vector2, strength: float) -> void:
	var offset := fmod(clock * 90.0, 4.0)
	var y := offset
	while y < view.y:
		draw_rect(Rect2(0, y, view.x, 1.0), Color(0, 0, 0, strength))
		y += 4.0


## An RGB-split box over a HUD piece while it comes up or is rewritten.
func _draw_split(rect: Rect2, amount: float) -> void:
	var shift := 6.0 * amount
	draw_rect(Rect2(rect.position + Vector2(-shift, 0), rect.size), Color(BLOOD, 0.35 * amount), false, 2.0)
	draw_rect(Rect2(rect.position + Vector2(shift, 1), rect.size), Color(XRAY, 0.3 * amount), false, 2.0)
	for band in 3:
		var y := rect.position.y + _hash01(int(clock * 30.0) + band * 11) * rect.size.y
		draw_rect(Rect2(rect.position.x - shift * 2.0, y, rect.size.x + shift * 4.0, 2.0 + 3.0 * amount), Color(CODE, 0.4 * amount))


func _show(piece: String, on: bool) -> void:
	if osd != null and is_instance_valid(osd):
		osd.show_piece(piece, on)


func _hash01(value: int) -> float:
	return fposmod(sin(float(value) * 12.9898 + float(_seed % 997)) * 43758.5453, 1.0)
