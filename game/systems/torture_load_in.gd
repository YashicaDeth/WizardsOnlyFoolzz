class_name TortureLoadIn
extends Control

## Greg, 25 September: "when you are loading into the game make it you're
## getting tortured". Beat 1 of `DESIGN/OPENING_TORTURE_INTAKE.md`. Black
## first, and the sound comes first: muffled screaming through fluid, a wet
## rubber gag forced into your mouth, your breathing going to the tube. Flashes
## of X-ray film between the black. A broadcast repeats "hundreds of years of
## the perpetual post-apocalypse" and degrades, glitches out, and you come to
## in the vat. F, Enter, Space or a click cuts to the glitch (speedrunners).
## The sounds are generated placeholders behind `cue()`; Higgsfield or
## recorded takes replace them without touching the timeline.

signal finished(skipped: bool)

const RATE := 22050
const BROADCAST := "HUNDREDS OF YEARS OF THE PERPETUAL POST-APOCALYPSE"
const BONE := Color("e6d4ac")
const BLOOD := Color("a8281a")
const FILM := Color("9fc4c8")
const BLACK := Color("030504")

## When each thing happens, in seconds from black. The broadcast runs three
## passes, each worse than the last, then the glitch hands over to the room.
const SCREAM_AT := [1.1, 3.9, 6.6]
const GAG_AT := 2.5
const TUBE_AT := 3.2
## Greg, 28 September, all four: the surgical lamp overhead with masked
## faces leaning in, your body opened (censored per the setting), your
## vitals flatlining then a jolt, and the warning spirits' faces.
const FLASHES := [
	{"at": 4.6, "kind": "lamp"},
	{"at": 6.1, "kind": "opened"},
	{"at": 7.9, "kind": "vitals"},
	{"at": 9.4, "kind": "spirits"},
]
## Long enough to read what it was (Greg's checklist: clearer), still a cut.
const FLASH_SECONDS := 0.3
## The whispers are spirit voices, and they are warning you (Greg, 28
## September, his words). Placed around the screen, so they come from around
## you rather than from the broadcast's line.
const WHISPERS := [
	{"at": 1.7, "text": "DON'T WAKE UP", "where": Vector2(0.22, 0.3)},
	{"at": 3.5, "text": "THEY'LL TAKE YOU APART", "where": Vector2(0.72, 0.22)},
	{"at": 9.8, "text": "DON'T WAKE UP", "where": Vector2(0.3, 0.6)},
]
const WHISPER_SECONDS := 1.5
## Greg's checklist: scarier. One frame of a masked face in the black, the
## last scream cut off dead, a stab on every flash, your heart under it all.
const FACE_AT := 8.65
const FACE_SECONDS := 0.07
const SCREAM_CUT_AT := 7.15
const BROADCAST_AT := 5.0
const BROADCAST_PASS := 1.9
const GLITCH_AT := 10.8
const GLITCH_SECONDS := 0.9
const REVEAL_SECONDS := 1.3
const TOTAL := GLITCH_AT + GLITCH_SECONDS + REVEAL_SECONDS

## The headless suites predate the load-in and drive the intake from frame
## one; they opt in with `force_in_tests` instead of all being re-timed.
static var force_in_tests := false

var clock := 0.0
var skipped := false
var done := false
var played: Array[String] = []
var _voices: Array[AudioStreamPlayer] = []
var _breath: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


static func wanted() -> bool:
	return force_in_tests or OS.get_environment("ATG_TEST_MODE") != "1"


func _ready() -> void:
	name = "TortureLoadIn"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 1953
	for index in 3:
		var player := AudioStreamPlayer.new()
		player.name = "Cue%d" % index
		if AudioServer.get_bus_index("SFX") != -1:
			player.bus = "SFX"
		add_child(player)
		_voices.append(player)
	_breath = AudioStreamPlayer.new()
	_breath.name = "Breath"
	_breath.stream = _wave("breath_fluid", 3.0, true)
	_breath.volume_db = -14.0
	if AudioServer.get_bus_index("SFX") != -1:
		_breath.bus = "SFX"
	add_child(_breath)
	_breath.play()
	_heart = AudioStreamPlayer.new()
	_heart.name = "Heart"
	_heart.stream = preload("res://systems/sight_audio.gd").stream("heartbeat")
	_heart.volume_db = -10.0
	add_child(_heart)
	_heart.play()
	set_process(true)


func _process(delta: float) -> void:
	step(delta)


## Advances the load-in; tests drive it directly.
func step(delta: float) -> void:
	if done:
		return
	var before := clock
	clock += delta
	for at in SCREAM_AT:
		_cue_between(before, float(at), "scream")
	# Each flash lands with a stab, not in silence.
	for flash in FLASHES:
		if before < float(flash.at) and clock >= float(flash.at):
			cue("glitch")
	# The last scream stops mid-breath.
	if before < SCREAM_CUT_AT and clock >= SCREAM_CUT_AT:
		for voice in _voices:
			voice.stop()
	# Your heart speeds up as it goes on.
	if _heart != null:
		_heart.pitch_scale = lerpf(0.85, 1.7, clampf(clock / GLITCH_AT, 0.0, 1.0))
		if clock >= GLITCH_AT:
			_heart.volume_db = move_toward(_heart.volume_db, -60.0, delta * 60.0)
	for whisper in WHISPERS:
		_cue_between(before, float(whisper.at), "whisper")
	_cue_between(before, GAG_AT, "gag")
	if before < TUBE_AT and clock >= TUBE_AT:
		_breath.stream = _wave("breath_tube", 2.4, true)
		_breath.play()
		played.append("tube")
	for pass_index in 3:
		_cue_between(before, BROADCAST_AT + pass_index * BROADCAST_PASS, "broadcast")
	_cue_between(before, GLITCH_AT, "glitch")
	if clock >= GLITCH_AT + GLITCH_SECONDS:
		_breath.volume_db = lerpf(-14.0, -40.0, clampf((clock - GLITCH_AT - GLITCH_SECONDS) / REVEAL_SECONDS, 0.0, 1.0))
	if clock >= TOTAL:
		_finish()
		return
	queue_redraw()


func _cue_between(before: float, at: float, kind: String) -> void:
	if before < at and clock >= at:
		cue(kind)


func cue(kind: String) -> void:
	played.append(kind)
	var player: AudioStreamPlayer = _voices[played.size() % _voices.size()]
	player.stream = _wave(kind, {"scream": 1.6, "gag": 1.1, "broadcast": 1.8, "glitch": 0.9, "whisper": 1.3}.get(kind, 0.6), false)
	player.volume_db = {"scream": -9.0, "gag": -6.0, "broadcast": -11.0, "glitch": -7.0, "whisper": -8.0}.get(kind, -10.0)
	player.pitch_scale = 1.0 - 0.06 * float(played.count(kind) - 1) if kind == "broadcast" else 1.0
	player.play()


## Speedrun: straight to the glitch, which still plays, so the hand-over
## to the room is never a hard cut.
func skip() -> void:
	if done or clock >= GLITCH_AT:
		return
	skipped = true
	clock = GLITCH_AT - 0.001
	step(0.001)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode in [KEY_F, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			skip()
		# Nothing reaches the tank or the form behind the black.
		if key.keycode != KEY_ESCAPE:
			get_viewport().set_input_as_handled()


func _finish() -> void:
	done = true
	WorldHistory.record_event("torture_load_in", {"skipped": skipped, "seconds": snappedf(clock, 0.1), "sounds": played.size()})
	finished.emit(skipped)
	queue_free()


## 0 while black, 1 at the height of a flash.
func flash_amount() -> float:
	for flash in FLASHES:
		var since := clock - float(flash.at)
		if since >= 0.0 and since < FLASH_SECONDS:
			return 1.0 - since / FLASH_SECONDS * 0.4
	return 0.0


func flash_kind() -> String:
	for flash in FLASHES:
		var since := clock - float(flash.at)
		if since >= 0.0 and since < FLASH_SECONDS:
			return str(flash.kind)
	return ""


## The broadcast line as it is heard on this pass: whole the first time,
## eaten away after that.
func broadcast_text() -> String:
	if clock < BROADCAST_AT or clock >= GLITCH_AT:
		return ""
	var pass_index := mini(2, int((clock - BROADCAST_AT) / BROADCAST_PASS))
	var into := fmod(clock - BROADCAST_AT, BROADCAST_PASS) / (BROADCAST_PASS * 0.8)
	var shown := BROADCAST.left(int(ceil(clampf(into, 0.0, 1.0) * BROADCAST.length())))
	if pass_index == 0:
		return shown + "..."
	var eaten := ""
	var noise := RandomNumberGenerator.new()
	noise.seed = int(clock * 14.0) + pass_index * 97
	for letter in shown:
		if letter != " " and noise.randf() < 0.18 * pass_index:
			eaten += ["#", "/", "_", "-", "."][noise.randi() % 5]
		else:
			eaten += letter
	return eaten + "..."


## The whispers on screen now: [text, where (0-1), alpha].
func whispers_now() -> Array:
	var now: Array = []
	for whisper in WHISPERS:
		var since := clock - float(whisper.at)
		if since >= 0.0 and since < WHISPER_SECONDS:
			var alpha := minf(since / 0.25, 1.0) * clampf((WHISPER_SECONDS - since) / 0.6, 0.0, 1.0)
			now.append([str(whisper.text), whisper.where, alpha])
	return now


func broadcast_pass() -> int:
	return mini(2, int((clock - BROADCAST_AT) / BROADCAST_PASS)) if clock >= BROADCAST_AT else -1


## How much of the room shows through at the end.
func reveal() -> float:
	return clampf((clock - GLITCH_AT - GLITCH_SECONDS) / REVEAL_SECONDS, 0.0, 1.0)


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	var open := reveal()
	draw_rect(area, Color(BLACK, 1.0 - ease(open, 0.6)))
	if open > 0.0:
		# The fluid comes up first: red across what you can see, draining off.
		draw_rect(area, Color(BLOOD, 0.34 * (1.0 - open)))
		return
	var centre := size * 0.5
	var unit := minf(size.x, size.y)
	# Your own pulse behind your eyes, the only light there is.
	var pulse := pow(maxf(0.0, sin(clock * TAU / 1.1)), 8.0)
	for ring in 12:
		var fraction := float(ring) / 12.0
		draw_circle(centre, unit * 0.7 * (1.0 - fraction), Color(BLOOD, (0.006 + pulse * 0.008) * (1.0 + fraction)))
	var gag_since := clock - GAG_AT
	if gag_since >= 0.0 and gag_since < 0.9:
		draw_rect(area, Color(BLOOD, 0.22 * (1.0 - gag_since / 0.9)))
	var amount := flash_amount()
	if amount > 0.0:
		_draw_film(flash_kind(), centre, unit, amount)
	if clock >= FACE_AT and clock < FACE_AT + FACE_SECONDS:
		_draw_face(centre, unit)
	for whisper: Array in whispers_now():
		var w_size := clampf(unit * 0.03, 14.0, 26.0)
		var drift := Vector2(sin(clock * 3.1) * 4.0, (1.0 - float(whisper[2])) * -8.0)
		var w_at: Vector2 = (whisper[1] as Vector2) * size + drift
		CellOutzType.draw_string_compat(self, w_at - Vector2(size.x * 0.5, 0.0), str(whisper[0]), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(w_size), Color(FILM, 0.62 * float(whisper[2])))
	var line := broadcast_text()
	if line != "":
		var pass_index := broadcast_pass()
		var jitter := Vector2(_rng.randf_range(-1.0, 1.0), 0.0) * 3.0 * pass_index
		var font_size := int(clampf(unit * 0.036, 18.0, 36.0))
		var at := Vector2(0.0, size.y * 0.72) + jitter
		# One line only: the red/cyan split copies read as the line doubled
		# (Greg's playtest). Jitter and eaten letters carry the decay.
		CellOutzType.draw_string_compat(self, at, line, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(BONE, 0.82 - 0.14 * pass_index))
	if clock >= GLITCH_AT:
		_draw_glitch(area, clamp((clock - GLITCH_AT) / GLITCH_SECONDS, 0.0, 1.0))


## Him, for one frame: the surgical mask, the eyes above it, too close.
func _draw_face(centre: Vector2, unit: float) -> void:
	# Pale film on black, like the X-rays: no outline, only what the light
	# catches. Hollow sockets with a pinprick in each, the mask's pleats, a
	# brow pressed too close to the glass.
	var r := unit * 0.5
	var film := Color(FILM, 0.32)
	draw_arc(centre + Vector2(0, -r * 0.35), r * 0.95, PI * 1.08, PI * 1.92, 40, film, 5.0)
	for side in [-1.0, 1.0]:
		var socket := centre + Vector2(side * r * 0.33, -r * 0.22)
		var ring := PackedVector2Array()
		for step in 25:
			var a := TAU * float(step) / 24.0
			ring.append(socket + Vector2(cos(a) * r * 0.2, sin(a) * r * 0.13))
		draw_colored_polygon(ring, BLACK)
		draw_polyline(ring, film, 2.0)
		draw_circle(socket + Vector2(side * -r * 0.03, r * 0.01), r * 0.018, Color(BONE, 0.95))
	var mask := PackedVector2Array([centre + Vector2(-r * 0.7, r * 0.02), centre + Vector2(r * 0.7, r * 0.02), centre + Vector2(r * 0.55, r * 0.62), centre + Vector2(-r * 0.55, r * 0.62)])
	draw_colored_polygon(mask, Color(FILM, 0.18))
	for pleat in 3:
		var y := r * (0.16 + pleat * 0.15)
		draw_line(centre + Vector2(-r * 0.64 + pleat * r * 0.04, y), centre + Vector2(r * 0.64 - pleat * r * 0.04, y), Color(FILM, 0.4), 2.0)


## One frame of failing X-ray film: pale on black, scratched.
func _draw_film(kind: String, centre: Vector2, unit: float, amount: float) -> void:
	var film := Color(FILM, 0.8 * amount)
	var dim := Color(FILM, 0.3 * amount)
	draw_rect(Rect2(centre - Vector2(unit * 0.34, unit * 0.44), Vector2(unit * 0.68, unit * 0.88)), Color(FILM, 0.06 * amount))
	# Double exposure: the frame printed twice more, offset and faint, so it
	# reads as failing film and not as a clean drawing.
	for echo in [Vector2(-unit * 0.018, unit * 0.01), Vector2(unit * 0.012, -unit * 0.014)]:
		draw_set_transform(echo)
		_draw_flash(kind, centre, unit, amount * 0.22, Color(FILM, 0.8 * amount * 0.22), Color(FILM, 0.3 * amount * 0.22))
	draw_set_transform(Vector2.ZERO)
	_draw_flash(kind, centre, unit, amount, film, dim)
	# Scratches down the film.
	for scratch in 5:
		var x := centre.x + (float(scratch) / 4.0 - 0.5) * unit * 0.6 + _rng.randf_range(-6.0, 6.0)
		draw_line(Vector2(x, centre.y - unit * 0.44), Vector2(x + _rng.randf_range(-8.0, 8.0), centre.y + unit * 0.44), Color(FILM, 0.12 * amount), 1.0)


func _draw_flash(kind: String, centre: Vector2, unit: float, amount: float, film: Color, dim: Color) -> void:
	match kind:
		"lamp":
			_draw_lamp(centre, unit, amount, film, dim)
		"opened":
			_draw_opened(centre, unit, amount, film, dim)
		"vitals":
			_draw_vitals(centre, unit, amount)
		"spirits":
			_draw_spirits(centre, unit, amount)


## Flat on your back under the surgical lamp; masked heads lean in over it.
func _draw_lamp(centre: Vector2, unit: float, amount: float, film: Color, dim: Color) -> void:
	var lamp := centre + Vector2(0, -unit * 0.05)
	var r := unit * 0.16
	draw_circle(lamp, r * 1.25, Color(FILM, 0.12 * amount))
	draw_arc(lamp, r, 0, TAU, 48, film, 6.0)
	for bulb in 7:
		var a := TAU * float(bulb) / 7.0
		draw_circle(lamp + Vector2(cos(a), sin(a)) * r * 0.58, r * 0.2, Color(BONE, 0.9 * amount))
	draw_circle(lamp, r * 0.24, Color(BONE, amount))
	# Three heads at the rim of the light, too close: the eyes and a mask.
	for side in [-1.0, 0.0, 1.0]:
		var head := lamp + Vector2(side * unit * 0.3, -unit * 0.02 + absf(side) * unit * 0.14)
		if side == 0.0:
			head = lamp + Vector2(0, -unit * 0.3)
		var hr := unit * 0.11
		draw_circle(head, hr, Color(BLACK, 0.92 * amount))
		draw_arc(head, hr, PI * 1.05, PI * 1.95, 20, dim, 3.0)
		for eye in [-1.0, 1.0]:
			draw_circle(head + Vector2(eye * hr * 0.35, -hr * 0.1), hr * 0.07, Color(BONE, 0.85 * amount))
		# A surgical mask: over the nose, square to the jaw, loops to the ears.
		var mask := PackedVector2Array([head + Vector2(-hr * 0.62, hr * 0.02), head + Vector2(0, -hr * 0.06), head + Vector2(hr * 0.62, hr * 0.02),
			head + Vector2(hr * 0.56, hr * 0.62), head + Vector2(-hr * 0.56, hr * 0.62)])
		draw_colored_polygon(mask, Color(FILM, 0.3 * amount))
		for pleat in 3:
			var y := hr * (0.18 + pleat * 0.14)
			draw_line(head + Vector2(-hr * 0.56, y), head + Vector2(hr * 0.56, y), Color(BLACK, 0.35 * amount), 1.5)
		for loop_side in [-1.0, 1.0]:
			draw_line(head + Vector2(loop_side * hr * 0.62, hr * 0.06), head + Vector2(loop_side * hr * 0.96, -hr * 0.05), Color(FILM, 0.35 * amount), 1.5)
			draw_line(head + Vector2(loop_side * hr * 0.56, hr * 0.56), head + Vector2(loop_side * hr * 0.9, hr * 0.3), Color(FILM, 0.35 * amount), 1.5)
	# The drill, coming in from the side.
	var drill := centre + Vector2(unit * 0.36, unit * 0.3)
	draw_line(drill, drill + Vector2(-unit * 0.14, -unit * 0.12), film, 7.0)
	draw_line(drill + Vector2(-unit * 0.14, -unit * 0.12), drill + Vector2(-unit * 0.2, -unit * 0.17), Color(BONE, amount), 2.0)


## Your body opened, seen from the table. Censored (the default), the cavity
## is a mosaic that keeps the silhouette and the blood (AX1.6's rule).
func _draw_opened(centre: Vector2, unit: float, amount: float, film: Color, dim: Color) -> void:
	var torso := PackedVector2Array([
		centre + Vector2(-unit * 0.2, -unit * 0.32), centre + Vector2(unit * 0.2, -unit * 0.32),
		centre + Vector2(unit * 0.16, unit * 0.34), centre + Vector2(-unit * 0.16, unit * 0.34)])
	draw_colored_polygon(torso, Color(FILM, 0.08 * amount))
	var closed := torso.duplicate()
	closed.append(torso[0])
	draw_polyline(closed, film, 4.0)
	var cavity := Rect2(centre + Vector2(-unit * 0.1, -unit * 0.2), Vector2(unit * 0.2, unit * 0.36))
	# Ribs spread back like a cage opened.
	for rib in 6:
		var y := cavity.position.y + rib * cavity.size.y / 6.0
		for side in [-1.0, 1.0]:
			var from := Vector2(centre.x + side * cavity.size.x * 0.5, y)
			draw_line(from, from + Vector2(side * unit * 0.1, -unit * 0.03), film, 3.0)
	# Clamps holding it open.
	for side in [-1.0, 1.0]:
		var at := Vector2(centre.x + side * (cavity.size.x * 0.5 + unit * 0.02), centre.y)
		draw_rect(Rect2(at - Vector2(unit * 0.012, unit * 0.06), Vector2(unit * 0.024, unit * 0.12)), Color(BONE, 0.9 * amount))
	if AnatomyPresentation.is_explicit():
		draw_rect(cavity, Color(BLOOD, 0.75 * amount))
		for organ in 5:
			var at := cavity.position + Vector2(cavity.size.x * (0.3 + 0.4 * float(organ % 2)), cavity.size.y * (0.15 + organ * 0.17))
			draw_circle(at, unit * 0.028, Color(BLOOD.lightened(0.25), amount))
			draw_arc(at, unit * 0.028, 0, TAU, 16, dim, 1.5)
	else:
		var cell := unit * 0.034
		var cells := Vector2i(int(cavity.size.x / cell), int(cavity.size.y / cell))
		var noise := RandomNumberGenerator.new()
		noise.seed = 1717
		for x in cells.x:
			for y in cells.y:
				var shade := noise.randf()
				draw_rect(Rect2(cavity.position + Vector2(x, y) * cell, Vector2(cell, cell)), Color(BLOOD.lerp(BONE, shade * 0.3).darkened(shade * 0.5), amount))
	# Blood running off the table either way.
	for drip in 4:
		var x := centre.x - unit * 0.12 + drip * unit * 0.08
		draw_line(Vector2(x, cavity.end.y), Vector2(x, cavity.end.y + unit * (0.06 + 0.04 * (drip % 2))), Color(BLOOD, amount), 3.0)


## The monitor: a pulse, the line going flat, then the jolt throwing it back.
func _draw_vitals(centre: Vector2, unit: float, amount: float) -> void:
	var trace_ink := Color(0.55, 1.0, 0.8, amount)
	var screen := Rect2(centre - Vector2(unit * 0.46, unit * 0.2), Vector2(unit * 0.92, unit * 0.4))
	draw_rect(screen, Color(FILM, 0.05 * amount))
	draw_rect(screen, Color(FILM, 0.35 * amount), false, 2.0)
	var jolted := flash_since() > FLASH_SECONDS * 0.6
	var trace := PackedVector2Array()
	var base := screen.position.y + screen.size.y * 0.55
	var steps := 240
	for i in steps + 1:
		var u := float(i) / steps
		var y := base
		if u < 0.4:
			var beat := fmod(u, 0.13) / 0.13
			var h := screen.size.y
			y -= h * 0.05 * exp(-pow((beat - 0.22) / 0.04, 2.0))
			y += h * 0.07 * exp(-pow((beat - 0.40) / 0.012, 2.0))
			y -= h * 0.42 * exp(-pow((beat - 0.44) / 0.014, 2.0))
			y += h * 0.12 * exp(-pow((beat - 0.48) / 0.012, 2.0))
			y -= h * 0.09 * exp(-pow((beat - 0.66) / 0.06, 2.0))
		elif jolted and u > 0.86 and u < 0.92:
			# The jolt: the whole line thrown off the top of the screen.
			y -= screen.size.y * 0.62 * sin((u - 0.86) / 0.06 * PI)
		trace.append(Vector2(screen.position.x + u * screen.size.x, y))
	draw_polyline(trace, trace_ink, 3.0)
	CellOutzType.draw_string_compat(self, screen.position + Vector2(18, 16), "BPM 212" if jolted else "BPM 000", HORIZONTAL_ALIGNMENT_LEFT, -1, int(unit * 0.04), trace_ink)
	# The jolt lands as white across the whole frame.
	if jolted:
		draw_rect(Rect2(Vector2.ZERO, size), Color(BONE, 0.35 * amount))


## The spirits warning you: long pale faces, mouths open on the words.
func _draw_spirits(centre: Vector2, unit: float, amount: float) -> void:
	for face in 4:
		var at := centre + Vector2((float(face) - 1.5) * unit * 0.24, sin(float(face) * 2.1) * unit * 0.06)
		var w := unit * 0.075
		var h := unit * 0.17
		var outline := PackedVector2Array()
		for step in 41:
			var a := TAU * float(step) / 40.0
			var ragged := 1.0 + 0.08 * sin(a * 7.0 + face * 1.7) + 0.05 * sin(a * 13.0 - face)
			# The lower half trails off, as if the face is being pulled down.
			var trail := 1.0 + 0.35 * maxf(0.0, sin(a))
			outline.append(at + Vector2(cos(a) * w * ragged, sin(a) * h * ragged * trail))
		draw_colored_polygon(outline, Color(FILM, 0.12 * amount))
		draw_polyline(outline, Color(FILM, 0.45 * amount), 2.0)
		for eye in [-1.0, 1.0]:
			var socket := PackedVector2Array()
			for step in 17:
				var a := TAU * float(step) / 16.0
				socket.append(at + Vector2(eye * w * 0.4, -h * 0.25) + Vector2(cos(a) * w * 0.22, sin(a) * w * (0.3 + 0.5 * maxf(0.0, sin(a)))))
			draw_colored_polygon(socket, Color(BLACK, amount))
		# Mouths stretched open, longer than a mouth should go.
		var mouth := PackedVector2Array([at + Vector2(-w * 0.16, h * 0.02), at + Vector2(w * 0.16, h * 0.02),
			at + Vector2(w * 0.26, h * 0.35), at + Vector2(w * 0.1, h * 0.72), at + Vector2(-w * 0.1, h * 0.72), at + Vector2(-w * 0.26, h * 0.35)])
		draw_colored_polygon(mouth, Color(BLACK, amount))


## Seconds into the flash showing now, or -1.
func flash_since() -> float:
	for flash in FLASHES:
		var since := clock - float(flash.at)
		if since >= 0.0 and since < FLASH_SECONDS:
			return since
	return -1.0


## The broadcast tears: blocks of dead signal and colour splits, then gone.
func _draw_glitch(area: Rect2, amount: float) -> void:
	var noise := RandomNumberGenerator.new()
	noise.seed = int(clock * 30.0)
	var blocks := int(18 + amount * 40)
	for block in blocks:
		var h := noise.randf_range(4.0, 40.0)
		var y := noise.randf_range(0.0, area.size.y)
		var w := noise.randf_range(area.size.x * 0.1, area.size.x * 0.9)
		var x := noise.randf_range(-w * 0.3, area.size.x - w * 0.7)
		var colour: Color = [Color(BLOOD, 0.5), Color(0.1, 0.9, 1.0, 0.25), Color(BONE, 0.35), Color(0, 0, 0, 0.9)][noise.randi() % 4]
		draw_rect(Rect2(x, y, w, h), colour)
	for line in 30:
		var y := noise.randf_range(0.0, area.size.y)
		draw_line(Vector2(0, y), Vector2(area.size.x, y), Color(BONE, 0.08 + 0.1 * amount), 1.0)


func _wave(kind: String, duration: float, looping: bool) -> AudioStreamWAV:
	var frame_count := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var low := 0.0
	var low2 := 0.0
	var phase := 0.0
	for frame in frame_count:
		var t := float(frame) / RATE
		var sample := 0.0
		match kind:
			"scream":
				# A voice straining through fluid: a wavering sawtooth,
				# heavily low-passed below so only the pressure reaches you.
				var pitch := 290.0 + 120.0 * sin(t * 2.2) + 18.0 * sin(t * 31.0) + 80.0 * minf(1.0, t * 3.0)
				phase = fmod(phase + pitch / RATE, 1.0)
				var saw := phase * 2.0 - 1.0 + (_noise(frame) - 0.5) * 0.5
				var shape := minf(1.0, t * 8.0) * clampf((duration - t) / 0.5, 0.0, 1.0)
				sample = saw * shape
				low += (sample - low) * 0.06
				low2 += (low - low2) * 0.08
				sample = low2 * 2.4
			"gag":
				# Wet rubber forced in: a squeal sliding down, and a choke.
				var slide := lerpf(210.0, 70.0, clampf(t / 0.7, 0.0, 1.0))
				phase = fmod(phase + slide / RATE, 1.0)
				var rubber := sin(TAU * phase) * exp(-t * 2.4) * 0.55
				var wet := (_noise(frame * 3) - 0.5) * exp(-t * 3.0) * 0.8
				low += (wet - low) * 0.12
				var choke := sin(TAU * 38.0 * t) * 0.4 * clampf((t - 0.55) * 4.0, 0.0, 1.0) * exp(-maxf(0.0, t - 0.55) * 4.0)
				sample = rubber + low + choke
			"breath_fluid":
				var cycle := sin(TAU * t / duration) * 0.5 + 0.5
				low += ((_noise(frame * 7) - 0.5) - low) * 0.03
				sample = low * 2.0 * cycle + sin(TAU * 44.0 * t) * 0.12 * pow(maxf(0.0, sin(TAU * t / 1.1)), 12.0)
			"breath_tube":
				# Breathing through a tube: a rasp that lives in the plastic.
				var cycle := pow(sin(PI * fmod(t, duration * 0.5) / (duration * 0.5)), 2.0)
				var rasp := (_noise(frame * 5) - 0.5)
				low += (rasp - low) * 0.22
				sample = (rasp - low) * 0.9 * cycle + sin(TAU * 112.0 * t) * 0.05 * cycle
			"broadcast":
				# A number station: a thin carrier, and syllables made of hiss.
				var syllable := pow(maxf(0.0, sin(TAU * 4.6 * t)), 2.0) * (0.6 + 0.4 * sin(TAU * 0.9 * t))
				var voice := sin(TAU * (190.0 + 30.0 * sin(TAU * 4.6 * t)) * t) * 0.35 + (_noise(frame * 13) - 0.5) * 0.4
				sample = voice * syllable * 0.8 + sin(TAU * 1020.0 * t) * 0.05 + (_noise(frame) - 0.5) * 0.08
				if int(t * 11.0) % 7 == 3:
					sample *= 0.1
			"whisper":
				# Breath shaped into syllables, high and close, no voice under it.
				var syllable := pow(maxf(0.0, sin(TAU * 3.2 * t)), 3.0) * sin(PI * t / duration)
				var hiss := _noise(frame * 17) - 0.5
				low += (hiss - low) * 0.35
				sample = (hiss - low) * syllable * 1.6
			"glitch":
				var chunk := int(t * 40.0)
				var tone := 80.0 + float(chunk % 9) * 140.0
				sample = (sin(TAU * tone * t) * 0.5 + (_noise(frame * (chunk % 5 + 1)) - 0.5) * 0.9) * (1.0 - t / duration)
				if chunk % 3 == 0:
					sample = signf(sample) * 0.5 * (1.0 - t / duration)
			_:
				sample = sin(TAU * 110.0 * t) * exp(-t * 8.0) * 0.25
		var value := clampi(roundi(clampf(sample, -1.0, 1.0) * 32760.0), -32768, 32767)
		if value < 0:
			value += 65536
		bytes[frame * 2] = value & 0xff
		bytes[frame * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frame_count
	return stream


func _noise(value: int) -> float:
	var n := value * 1103515245 + 12345
	n = (n >> 16) & 0x7fff
	return float(n) / 32767.0
