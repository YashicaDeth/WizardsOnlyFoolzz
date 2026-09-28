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
const FLASHES := [
	{"at": 4.6, "kind": "skull"},
	{"at": 6.1, "kind": "ribs"},
	{"at": 7.9, "kind": "rune"},
	{"at": 9.4, "kind": "skull"},
]
const FLASH_SECONDS := 0.16
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
	player.stream = _wave(kind, {"scream": 1.6, "gag": 1.1, "broadcast": 1.8, "glitch": 0.9}.get(kind, 0.6), false)
	player.volume_db = {"scream": -9.0, "gag": -6.0, "broadcast": -11.0, "glitch": -7.0}.get(kind, -10.0)
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
	var line := broadcast_text()
	if line != "":
		var pass_index := broadcast_pass()
		var jitter := Vector2(_rng.randf_range(-1.0, 1.0), 0.0) * 3.0 * pass_index
		var font_size := int(clampf(unit * 0.036, 18.0, 36.0))
		var at := Vector2(0.0, size.y * 0.72) + jitter
		if pass_index > 0:
			CellOutzType.draw_string_compat(self, at + Vector2(-2.0 * pass_index, 0), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(1, 0.1, 0.1, 0.35))
			CellOutzType.draw_string_compat(self, at + Vector2(2.0 * pass_index, 0), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(0.1, 0.8, 1, 0.3))
		CellOutzType.draw_string_compat(self, at, line, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(BONE, 0.82 - 0.14 * pass_index))
	if clock >= GLITCH_AT:
		_draw_glitch(area, clamp((clock - GLITCH_AT) / GLITCH_SECONDS, 0.0, 1.0))


## One frame of failing X-ray film: pale on black, scratched.
func _draw_film(kind: String, centre: Vector2, unit: float, amount: float) -> void:
	var film := Color(FILM, 0.8 * amount)
	var dim := Color(FILM, 0.3 * amount)
	draw_rect(Rect2(centre - Vector2(unit * 0.34, unit * 0.44), Vector2(unit * 0.68, unit * 0.88)), Color(FILM, 0.06 * amount))
	match kind:
		"skull":
			# Side-on skull: cranium, the eye socket, nasal cut, jaw and teeth,
			# with the chip at the back where the spine goes in.
			var c := centre + Vector2(unit * 0.02, -unit * 0.08)
			var r := unit * 0.2
			draw_arc(c, r, PI * 0.72, TAU + PI * 0.08, 56, film, 5.0)
			var brow := c + Vector2(-r * 0.97, r * 0.2)
			var cheek := c + Vector2(-r * 0.95, r * 0.72)
			draw_polyline(PackedVector2Array([brow, brow + Vector2(-r * 0.12, r * 0.18), cheek + Vector2(-r * 0.1, 0), cheek + Vector2(-r * 0.02, r * 0.22)]), film, 4.0)
			draw_circle(c + Vector2(-r * 0.62, r * 0.36), r * 0.2, Color(BLACK, amount))
			draw_arc(c + Vector2(-r * 0.62, r * 0.36), r * 0.22, 0, TAU, 24, dim, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.92, r * 0.6), c + Vector2(-r * 0.78, r * 0.62), c + Vector2(-r * 0.86, r * 0.82)]), Color(BLACK, amount))
			var jaw := PackedVector2Array([cheek + Vector2(0, r * 0.22), c + Vector2(-r * 0.78, r * 1.22), c + Vector2(-r * 0.2, r * 1.3), c + Vector2(r * 0.12, r * 0.98), c + Vector2(r * 0.18, r * 0.66)])
			draw_polyline(jaw, film, 4.0)
			for tooth in 6:
				var x := c.x - r * 0.9 + tooth * r * 0.1
				draw_line(Vector2(x, c.y + r * 0.9), Vector2(x, c.y + r * 1.02), dim, 2.0)
			var base := c + Vector2(r * 0.55, r * 0.78)
			for bone in 4:
				draw_rect(Rect2(base + Vector2(-r * 0.12, r * (0.12 + bone * 0.24)), Vector2(r * 0.24, r * 0.16)), dim, false, 2.0)
			draw_circle(base, unit * 0.017, Color(0.5, 1.0, 0.9, amount))
			draw_line(base, base + Vector2(0, r * 1.1), Color(0.5, 1.0, 0.9, 0.6 * amount), 2.0)
		"ribs":
			draw_line(centre + Vector2(0, -unit * 0.32), centre + Vector2(0, unit * 0.3), film, 6.0)
			for rib in 8:
				var y := -unit * 0.26 + rib * unit * 0.065
				var reach := unit * (0.14 + 0.09 * sin(float(rib + 1) / 9.0 * PI))
				for side in [-1.0, 1.0]:
					draw_arc(centre + Vector2(side * reach * 0.5, y + unit * 0.04), reach * 0.55, -PI * 0.5 - side * 0.9, -PI * 0.5 + side * 0.9, 16, film, 3.0)
			draw_circle(centre + Vector2(-unit * 0.04, -unit * 0.05), unit * 0.05, Color(BLOOD, 0.5 * amount))
		"rune":
			var ring := unit * 0.26
			for quarter in 4:
				var start := quarter * PI * 0.5 + 0.18
				draw_arc(centre, ring, start, start + PI * 0.5 - 0.36, 24, Color(BLOOD, amount), 10.0)
			draw_line(centre + Vector2(0, ring * 0.8), centre + Vector2(0, -ring * 0.8), Color(BLOOD, amount), 10.0)
			draw_line(centre + Vector2(0, -ring * 0.05), centre + Vector2(-ring * 0.55, -ring * 0.62), Color(BLOOD, amount), 10.0)
			draw_line(centre + Vector2(0, -ring * 0.05), centre + Vector2(ring * 0.55, -ring * 0.62), Color(BLOOD, amount), 10.0)
	# Scratches down the film.
	for scratch in 5:
		var x := centre.x + (float(scratch) / 4.0 - 0.5) * unit * 0.6 + _rng.randf_range(-6.0, 6.0)
		draw_line(Vector2(x, centre.y - unit * 0.44), Vector2(x + _rng.randf_range(-8.0, 8.0), centre.y + unit * 0.44), Color(FILM, 0.12 * amount), 1.0)


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
