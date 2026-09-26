class_name BrainHack
extends Control

## Beat 10 of `DESIGN/OPENING_TORTURE_INTAKE.md`, steps 1-4 in Greg's order
## (25 September): he leaves, the muffled screaming starts, a sigil takes your
## brain (the seal's rune, demonic), it shrinks into a microscopic motherboard,
## it gets hacked (CRT blob tracking, the END ALL SUFFERING card's style), and
## the card reads BRAIN HACKED / SOUL OVERTAKEN. The hands, the cord and the
## glass that follow are the chamber's hands-on breakout.
##
## Drawn as code and effects (Greg: "make it purely look like code and
## effects"). Higgsfield's rune and die plates sit under the drawing on the
## same timeline; the code still carries the beat on its own.

signal hack_finished(skipped: bool)

const BONE := Color("e6d4ac")
const BLOOD := Color("a8281a")
const DRIED := Color("461009")
const COPPER := Color("b0552a")
const ACID := Color("b4da48")
const EMBER := Color("ff7a2a")
const BLACK := Color("030504")

## Phase 3 of DESIGN/HIGGSFIELD_ROADMAP.md, laid under the drawn rune on the
## beat the header asks for. B3 carries the baked line "THE DIE HACKED:
## TERMINAL FAILURE DETECTED", which is not one of the canon lines; Greg has
## not yet said whether to keep it, re-roll it or crop it.
const PLATE_SEAL := "res://art/higgsfield/breakout/b1_seal_in_skull.png"
const PLATE_DIE := "res://art/higgsfield/breakout/b2_seal_to_die.png"
const PLATE_HACKED := "res://art/higgsfield/breakout/b3_die_hacked.png"

## The hack, in seconds from his door shutting.
const SCREAM_AT := 0.1
const RUNE_IN := 0.5
const RUNE_FULL := 2.2
const SHRINK_END := 3.6
const HACK_END := 5.6
const HACK_SECONDS := 6.0
## Seconds each plate takes to trade places with the next.
const PLATE_FADE := 0.5
## BRAIN HACKED / SOUL OVERTAKEN holds on the chamber's mission card.
const CARD_SECONDS := 2.6


## The headless route suites predate the hack and drive the opening on
## timers; they skip it unless a test opts in, as with `TortureLoadIn`.
static var force_in_tests := false

var mode := ""
var clock := 0.0
var skipped := false
var played: Array[String] = []
var _voice: AudioStreamPlayer
var _plates: Array[Texture2D] = []


static func wanted() -> bool:
	return force_in_tests or OS.get_environment("ATG_TEST_MODE") != "1"


func _ready() -> void:
	name = "BreakoutSequence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voice = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("SFX") != -1:
		_voice.bus = "SFX"
	add_child(_voice)
	for path in [PLATE_SEAL, PLATE_DIE, PLATE_HACKED]:
		_plates.append(load(path))
	visible = false


## Start the hack: the screaming and the rune taking the brain.
func begin_hack() -> void:
	mode = "hack"
	clock = 0.0
	skipped = false
	visible = true
	set_process(true)


func skip_hack() -> void:
	if mode != "hack" or clock >= HACK_END:
		return
	skipped = true
	clock = HACK_END - 0.001


func _process(delta: float) -> void:
	step(delta)


## Advances whatever is running; tests drive it directly.
func step(delta: float) -> void:
	match mode:
		"hack":
			var before := clock
			clock += delta
			if before < SCREAM_AT and clock >= SCREAM_AT:
				_cue("scream")
			if before < RUNE_FULL and clock >= RUNE_FULL:
				_cue("glitch")
			if clock >= HACK_SECONDS:
				mode = "card"
				WorldHistory.record_event("brain_hacked", {"skipped": skipped})
				hack_finished.emit(skipped)
	queue_redraw()


func _cue(kind: String) -> void:
	played.append(kind)
	if _voice == null:
		return
	var maker = TortureLoadIn.new()
	var wave_kind := kind
	_voice.stream = maker._wave(wave_kind, {"scream": 2.4, "glitch": 0.5}.get(kind, 0.6), false)
	maker.free()
	_voice.volume_db = -8.0
	_voice.play()


## Progress through the rune: 0 far, 1 filling the frame, then shrinking.
func rune_scale() -> float:
	if clock < RUNE_IN:
		return 0.0
	if clock < RUNE_FULL:
		return ease(clampf((clock - RUNE_IN) / (RUNE_FULL - RUNE_IN), 0.0, 1.0), 0.4) * 1.15
	return lerpf(1.15, 0.55, ease(clampf((clock - RUNE_FULL) / (SHRINK_END - RUNE_FULL), 0.0, 1.0), 2.2))


## How far the acid-green path has taken the die.
func hack_amount() -> float:
	return clampf((clock - SHRINK_END) / (HACK_END - SHRINK_END), 0.0, 1.0)


## Seal, die and hacked-die weights across the existing timeline: the seal
## carries the rune, the die takes it as it shrinks, the hacked die takes it
## as the green path wins.
func plate_weights() -> PackedFloat32Array:
	var w := PackedFloat32Array([0.0, 0.0, 0.0])
	if clock < RUNE_IN:
		return w
	var rising := clampf((clock - RUNE_IN) / PLATE_FADE, 0.0, 1.0)
	var to_die := clampf((clock - RUNE_FULL) / (SHRINK_END - RUNE_FULL), 0.0, 1.0)
	var won := hack_amount()
	w[0] = rising * (1.0 - to_die)
	w[1] = rising * minf(to_die, 1.0 - won)
	w[2] = won
	return w


func _draw_plates(view: Vector2) -> void:
	var weights := plate_weights()
	for i in _plates.size():
		if weights[i] <= 0.0:
			continue
		var src := _plates[i].get_size()
		var size := src * maxf(view.x / src.x, view.y / src.y)
		draw_texture_rect(_plates[i], Rect2((view - size) * 0.5, size), false, Color(1, 1, 1, weights[i]))


func _draw() -> void:
	var view := size
	match mode:
		"hack":
			_draw_hack(view)


func _draw_hack(view: Vector2) -> void:
	var centre := view * 0.5
	var unit := minf(view.x, view.y)
	# The screaming drowns the room first.
	draw_rect(Rect2(Vector2.ZERO, view), Color(BLACK, clampf(clock / 0.6, 0.0, 0.92)))
	_draw_plates(view)
	var pulse := pow(maxf(0.0, sin(clock * TAU / 0.9)), 6.0)
	var scale := rune_scale()
	if scale <= 0.0:
		return
	var die := clampf((clock - RUNE_FULL) / (SHRINK_END - RUNE_FULL), 0.0, 1.0)
	var ring := unit * 0.42 * scale
	if die > 0.0:
		_draw_die(centre, ring, die)
	var tone := Color(BLOOD, 1.0).lerp(COPPER, die)
	var width := maxf(2.0, ring * 0.12 * (1.0 - die * 0.7))
	# The seal: four arcs broken at the cardinals, the Algiz inside.
	for quarter in 4:
		var start := quarter * PI * 0.5 + 0.2
		draw_arc(centre, ring, start, start + PI * 0.5 - 0.4, 32, tone, width)
	var stem_top := centre + Vector2(0, -ring * 0.82)
	var stem_bottom := centre + Vector2(0, ring * 0.82)
	var fork := centre + Vector2(0, -ring * 0.05)
	for segment in [[stem_top, stem_bottom], [fork, centre + Vector2(-ring * 0.58, -ring * 0.64)], [fork, centre + Vector2(ring * 0.58, -ring * 0.64)]]:
		draw_line(segment[0], segment[1], tone, width)
		# Ember cracks glowing from inside, brighter on each heartbeat.
		if die < 0.6:
			var mid: Vector2 = (segment[0] + segment[1]) * 0.5
			var along: Vector2 = (segment[1] - segment[0]).normalized()
			var across := Vector2(-along.y, along.x)
			var crack := PackedVector2Array()
			for k in 7:
				var t := float(k) / 6.0 - 0.5
				crack.append(mid + along * t * ring * 0.9 + across * sin(k * 2.3 + clock) * width * 0.25)
			draw_polyline(crack, Color(EMBER, (0.45 + pulse * 0.55) * (1.0 - die)), maxf(1.0, width * 0.12))
	# Blood drips off the lower arcs while it is still the demon.
	if die < 0.5:
		for drip in 5:
			var angle := PI * (0.2 + 0.15 * drip)
			var from := centre + Vector2(cos(angle), sin(angle)) * ring
			var fall := fmod(clock * 0.6 + drip * 0.37, 1.0) * ring * 0.4
			draw_line(from, from + Vector2(0, fall), Color(BLOOD, 0.9 * (1.0 - die * 2.0)), maxf(2.0, width * 0.25))
	var hack := hack_amount()
	if hack > 0.0:
		_draw_tracking(view, centre, ring, hack)


## The motherboard under the rune: a die, a transistor grid, copper traces
## laid along the rune's strokes, and an acid-green path eating through them.
func _draw_die(centre: Vector2, ring: float, amount: float) -> void:
	var half := ring * 1.25
	var body := Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)
	draw_rect(body, Color(0.02, 0.03, 0.03, amount))
	draw_rect(body, Color(COPPER, 0.8 * amount), false, 2.0)
	var cells := 24
	for i in cells:
		for j in cells:
			if (i * 7 + j * 13) % 5 != 0:
				continue
			var at := body.position + Vector2(i + 0.5, j + 0.5) * (body.size / cells)
			draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color(COPPER, 0.35 * amount))
	var hack := hack_amount()
	var pads := 12
	for side in 4:
		for p in pads:
			var t := (float(p) + 0.5) / pads
			var at: Vector2
			match side:
				0: at = Vector2(body.position.x + body.size.x * t, body.position.y)
				1: at = Vector2(body.end.x, body.position.y + body.size.y * t)
				2: at = Vector2(body.position.x + body.size.x * t, body.end.y)
				_: at = Vector2(body.position.x, body.position.y + body.size.y * t)
			var lit := hack > 0.0 and fmod(t + side * 0.25, 1.0) < hack
			draw_circle(at, 3.0, Color(ACID if lit else COPPER, amount))
			draw_line(at, at.lerp(centre, 0.18), Color(ACID if lit else COPPER, 0.6 * amount), 1.0)
	if hack > 0.0:
		# The green path racing along the rune's own traces.
		var path := PackedVector2Array([centre + Vector2(0, ring * 0.82), centre + Vector2(0, -ring * 0.05), centre + Vector2(-ring * 0.58, -ring * 0.64), centre + Vector2(0, -ring * 0.05), centre + Vector2(ring * 0.58, -ring * 0.64), centre + Vector2(0, -ring * 0.82)])
		var lit := PackedVector2Array()
		var reach := hack * float(path.size() - 1)
		for k in path.size():
			if float(k) <= reach:
				lit.append(path[k])
		var last := int(floor(reach))
		if last < path.size() - 1:
			lit.append(path[last].lerp(path[last + 1], reach - float(last)))
		if lit.size() >= 2:
			draw_polyline(lit, Color(ACID, 0.95), 4.0)


## CRT blob tracking, the END ALL SUFFERING card's language: boxes locking on
## hot spots with readouts, colour split, scanlines, torn bands.
func _draw_tracking(view: Vector2, centre: Vector2, ring: float, hack: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(clock * 12.0)
	var labels := ["NEURALACE", "CHIP 0C-7", "SOUL", "OVERRIDE", "OWNER: ?", "CELLOUTZ", "WILL", "ROOT"]
	for box in int(3 + hack * 6):
		var at := centre + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * ring * 1.1
		var half := Vector2(rng.randf_range(14.0, 44.0), rng.randf_range(10.0, 30.0))
		var tone := ACID if box % 3 else BLOOD
		draw_rect(Rect2(at - half, half * 2.0), Color(tone, 0.85), false, 1.5)
		CellOutzType.draw_string_compat(self, at + Vector2(-half.x, -half.y - 4.0), "%s %02d" % [labels[box % labels.size()], rng.randi_range(0, 99)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(tone, 0.9))
	for line in 40:
		var y := float(line) / 40.0 * view.y
		draw_line(Vector2(0, y), Vector2(view.x, y), Color(0, 0, 0, 0.18), 1.0)
	for band in int(hack * 5):
		var y := rng.randf_range(0.0, view.y)
		var h := rng.randf_range(4.0, 18.0)
		draw_rect(Rect2(Vector2(rng.randf_range(-40.0, 40.0), y), Vector2(view.x, h)), Color(ACID if band % 2 else BLOOD, 0.12 + 0.2 * hack))
