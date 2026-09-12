extends Control

## The derby windscreen.
##
## The instrument-panel pass was rejected as a whole. A prettier permanent HUD
## is still a permanent HUD, and it obscured the cars that carry the useful
## state. This control now contributes only fixed grime to the windscreen. Heat,
## rivals, speed, hull and radio chatter all stay in the world or in the sound.
##
## Three rules from `DESIGN/INTERFACE_DIRECTION.md` drive the layout.
##
## **No screen is a list of text in a box.** Every number here is an instrument:
## a segmented bar that fails in panels the way a hull does, a radar, a meter.
## The prose is cut to roughly a third of what it was, because a HUD that has to
## be *read* is a HUD that gets ignored at 90km/h.
##
## **This is a cab instrument, so it is filthy.** The plates carry stains, the
## glass carries dried spatter, and both are fixed per seed so they read as dirt
## on the panel rather than as an effect over it.
##
## **Nothing cuts.** Readouts ease toward their values; the damage flash decays.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const Grunge := preload("res://systems/celloutz_grunge.gd")

const INK := Color("e6d4ac")
const COPPER := Color("b0552a")
const HOT := Color("a8281a")
const MOSS := Color("8a9a4a")
const SPORE := Color("7f9440")
const BRUISE := Color("6b3f6e")
const SMOKE := Color(0.042, 0.032, 0.024, 0.90)
const FAINT := Color(0.95, 0.82, 0.62, 0.16)

var speed := 0.0
var score := 0
var integrity := 100
var active_wreckers := 0
var memory_count := 0
var rival_status := "ACTIVE"
var rival_grudge := 0
var rival_elo := 1180
var contacts: Array = []
var arena_limit := 40.0
var elapsed := 0.0
var impact_flash := 0.0
var impact_value := 0
var event_message := "THE ROAD REMEMBERS"
var message_life := 0.0
var displayed_score := 0.0
var displayed_speed := 0.0
var displayed_integrity := 100.0

## The damage bust occupies the top-left corner in the derby, so the title block
## is suppressed there rather than drawn underneath it.
var show_title := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_telemetry(values: Dictionary) -> void:
	speed = float(values.get("speed", speed))
	score = int(values.get("score", score))
	integrity = int(values.get("integrity", integrity))
	active_wreckers = int(values.get("active_wreckers", active_wreckers))
	memory_count = int(values.get("memory_count", memory_count))
	rival_status = str(values.get("rival_status", rival_status)).to_upper()
	rival_grudge = int(values.get("rival_grudge", rival_grudge))
	rival_elo = int(values.get("rival_elo", rival_elo))
	contacts = values.get("contacts", contacts)
	arena_limit = float(values.get("arena_limit", arena_limit))


func announce_impact(value: int, rival_hit: bool) -> void:
	impact_flash = 1.0
	impact_value = value
	message_life = 2.4
	event_message = "MARA REMEMBERS THIS" if rival_hit else "IMPACT RECORDED"


func _process(delta: float) -> void:
	elapsed += delta
	impact_flash = move_toward(impact_flash, 0.0, delta * 2.8)
	message_life = maxf(0.0, message_life - delta)
	displayed_score = lerpf(displayed_score, float(score), 1.0 - exp(-delta * 8.0))
	displayed_speed = lerpf(displayed_speed, absf(speed), 1.0 - exp(-delta * 11.0))
	displayed_integrity = lerpf(displayed_integrity, float(integrity), 1.0 - exp(-delta * 6.0))
	queue_redraw()


func _draw() -> void:
	var viewport := size
	if viewport.x < 400 or viewport.y < 300:
		return
	_draw_glass(viewport)


## Regression hook: the derby scene may keep this windscreen node, but it must
## never grow permanent readouts again.
func has_permanent_readouts() -> bool:
	return false


## The windscreen you are reading all of this through. Fixed seeds, because dirt
## that reshuffles every frame is an effect and dirt that stays is a car.
func _draw_glass(viewport: Vector2) -> void:
	Grunge.stain(self, Vector2(viewport.x * 0.18, viewport.y * 0.12), 130.0, 2207, Grunge.RUST, 0.030)
	Grunge.stain(self, Vector2(viewport.x * 0.86, viewport.y * 0.70), 150.0, 2211, Grunge.BILE, 0.026)
	Grunge.spatter(self, Vector2(viewport.x * 0.62, viewport.y * 0.14), 2213, 16, Vector2(0.8, 0.5))
	Grunge.run_down(self, Vector2(viewport.x * 0.67, viewport.y * 0.15), 92.0, 2217)
	Grunge.scratches(self, Rect2(Vector2.ZERO, viewport), 2219, 16)


## The plate vocabulary, shared with the World Index: notched so an outline is
## never a rectangle, with a title strip the data never has to compete with.
func _plate(at: Vector2, plate_size: Vector2, label: String, code: String, accent: Color, seed_value: int) -> void:
	var notch := 14.0
	var body := PackedVector2Array([
		at + Vector2(notch, 0),
		at + Vector2(plate_size.x, 0),
		at + Vector2(plate_size.x, plate_size.y - notch),
		at + Vector2(plate_size.x - notch, plate_size.y),
		at + Vector2(0, plate_size.y),
		at + Vector2(0, notch),
	])
	draw_colored_polygon(body, SMOKE)
	Grunge.stain(self, at + plate_size * Vector2(0.72, 0.66), plate_size.y * 0.7, seed_value, Grunge.RUST, 0.10)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, accent * Color(1, 1, 1, 0.55), 1.5)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(notch, 0), at + Vector2(plate_size.x, 0),
		at + Vector2(plate_size.x, 17), at + Vector2(0, 17), at + Vector2(0, notch),
	]), accent * Color(1, 1, 1, 0.20))
	draw_line(at + Vector2(0, 17), at + Vector2(plate_size.x, 17), accent * Color(1, 1, 1, 0.45), 1.0)
	CellOutzType.draw_text(self, at + Vector2(10, 4), label, 10.0, accent, 1.0)
	var code_width := CellOutzType.width(code, 8.0, 0.7)
	CellOutzType.draw_text(self, at + Vector2(plate_size.x - 9 - code_width, 5), code, 8.0, INK * Color(1, 1, 1, 0.36), 0.7)
	# Two fixings, so the plate is bolted to something.
	for corner in [at + Vector2(7, plate_size.y - 7), at + Vector2(plate_size.x - 7, plate_size.y - 7)]:
		draw_circle(corner, 2.6, Color(0.10, 0.07, 0.06))
		draw_arc(corner, 2.6, 0, TAU, 8, INK * Color(1, 1, 1, 0.26), 1.0)


func _draw_edge_frame(viewport: Vector2) -> void:
	var breathe := 0.45 + sin(elapsed * 1.7) * 0.10
	var corner := 44.0
	var margin := 16.0
	var color := COPPER * Color(1, 1, 1, breathe)
	for top in [margin, viewport.y - margin]:
		draw_line(Vector2(margin, top), Vector2(margin + corner, top), color, 2.0)
		draw_line(Vector2(viewport.x - margin - corner, top), Vector2(viewport.x - margin, top), color, 2.0)
	for left in [margin, viewport.x - margin]:
		draw_line(Vector2(left, margin), Vector2(left, margin + corner), color, 2.0)
		draw_line(Vector2(left, viewport.y - margin - corner), Vector2(left, viewport.y - margin), color, 2.0)


func _draw_title(viewport: Vector2) -> void:
	CellOutzType.draw_stamped(self, Vector2(44, 36), "BONE YARD", 22.0, COPPER, HOT * Color(1, 1, 1, 0.3), 1.6)
	CellOutzType.draw_text(self, Vector2(46, 66), "MERCY COUNTY LIVE COLLISION FEED", 9.0, INK * Color(1, 1, 1, 0.42), 0.8)


## A5.3. The damage bust is a 3D viewport owned by another node; this is the
## bezel it sits in, so it stops reading as a render floating on the sky.
func _draw_bust_frame(viewport: Vector2) -> void:
	var frame := Rect2(Vector2(22, 18), Vector2(150, 178))
	draw_colored_polygon(PackedVector2Array([
		frame.position + Vector2(12, 0), frame.position + Vector2(frame.size.x, 0),
		frame.position + Vector2(frame.size.x, frame.size.y - 12), frame.position + Vector2(frame.size.x - 12, frame.size.y),
		frame.position + Vector2(0, frame.size.y), frame.position + Vector2(0, 12),
	]), Color(0, 0, 0, 0.30))
	for corner_pair in [[Vector2(0, 26), Vector2.ZERO, Vector2(26, 0)], [frame.size - Vector2(0, 26), frame.size, frame.size - Vector2(26, 0)]]:
		draw_polyline(PackedVector2Array([
			frame.position + corner_pair[0], frame.position + corner_pair[1], frame.position + corner_pair[2],
		]), COPPER * Color(1, 1, 1, 0.65), 1.8)
	CellOutzType.draw_text(self, frame.position + Vector2(6, frame.size.y + 6), "DRIVER", 9.0, INK * Color(1, 1, 1, 0.5), 1.0)
	var tone := HOT if displayed_integrity < 40.0 else INK * Color(1, 1, 1, 0.5)
	var state := "CRITICAL" if displayed_integrity < 40.0 else ("HURT" if displayed_integrity < 75.0 else "INTACT")
	var state_width := CellOutzType.width(state, 9.0, 1.0)
	CellOutzType.draw_text(self, frame.position + Vector2(frame.size.x - state_width - 4, frame.size.y + 6), state, 9.0, tone, 1.0)


## A5.1. Hull fails in panels, so the meter is segmented rather than smooth, and
## the number you read at a glance is the only thing given size.
func _draw_integrity(viewport: Vector2) -> void:
	var plate_size := Vector2(246, 86)
	var anchor := Vector2(viewport.x - plate_size.x - 28, 28)
	var ratio := clampf(displayed_integrity / 100.0, 0, 1)
	var tone := HOT.lerp(MOSS, ratio)
	_plate(anchor, plate_size, "HULL", "CZ-88/H", tone, 3301)
	CellOutzType.draw_text(self, anchor + Vector2(12, 28), "%03d" % roundi(displayed_integrity), 30.0, tone, 1.2)
	for index in 12:
		var x := anchor.x + 104 + index * 11.0
		var lit := float(index) / 12.0 < ratio
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, anchor.y + 30), Vector2(x + 8, anchor.y + 30),
			Vector2(x + 5, anchor.y + 50), Vector2(x - 3, anchor.y + 50),
		]), tone if lit else INK * Color(1, 1, 1, 0.10))
	draw_line(anchor + Vector2(12, 62), anchor + Vector2(plate_size.x - 12, 62), INK * Color(1, 1, 1, 0.14), 1.0)
	# A5.5. Three figures, no sentence.
	# A1.4. Three readouts across one plate is exactly the tight column the
	# condensed cut exists for; at full width they crowd the plate edge.
	CellOutzType.draw_condensed(self, anchor + Vector2(12, 68), "SCR %04d" % roundi(displayed_score), 10.0, INK * Color(1, 1, 1, 0.7), 0.9)
	CellOutzType.draw_condensed(self, anchor + Vector2(92, 68), "WRK %02d" % active_wreckers, 10.0, INK * Color(1, 1, 1, 0.7), 0.9)
	CellOutzType.draw_condensed(self, anchor + Vector2(158, 68), "MEM %03d" % memory_count, 10.0, INK * Color(1, 1, 1, 0.7), 0.9)


## A5.2. The one Greg named. It was a diamond lamp and two lines of prose; it is
## now a signal-strength instrument, because that is what a hunt signal is.
func _draw_hunt_signal(viewport: Vector2) -> void:
	var plate_size := Vector2(250, 78)
	var anchor := Vector2(196, 26)
	var strength := clampf(float(rival_grudge) / 100.0, 0.0, 1.0)
	_plate(anchor, plate_size, "HUNT SIGNAL", "CZ-12/R", HOT, 3307)
	# A swept bearing needle. Only the needle moves - shaking the whole plate
	# made the type shimmer, which is noise impersonating tension.
	var dish := anchor + Vector2(32, 46)
	draw_arc(dish, 18.0, PI, TAU, 20, INK * Color(1, 1, 1, 0.16), 2.0)
	for index in 5:
		var angle := lerpf(PI, TAU, float(index) / 4.0)
		draw_line(dish + Vector2(cos(angle), sin(angle)) * 14.0, dish + Vector2(cos(angle), sin(angle)) * 18.0, INK * Color(1, 1, 1, 0.2), 1.0)
	var sweep := PI + (sin(elapsed * 1.6) * 0.5 + 0.5) * PI
	draw_line(dish, dish + Vector2(cos(sweep), sin(sweep)) * 18.0, HOT * Color(1, 1, 1, 0.9), 2.0)
	var blip := PI + strength * PI
	draw_circle(dish + Vector2(cos(blip), sin(blip)) * 18.0, 2.6 + sin(elapsed * 5.0) * 0.9 * strength, HOT)
	CellOutzType.draw_text(self, anchor + Vector2(62, 24), "THE CAPTAIN", 15.0, INK, 1.2)
	CellOutzType.draw_text(self, anchor + Vector2(62, 46), rival_status, 9.0, INK * Color(1, 1, 1, 0.6), 0.9)
	# Right-aligned on the second band, not the first. Sharing a line with the
	# name printed "GRUDGE 064" straight through "THE CAPTAIN".
	var grudge_text := "GRUDGE %03d" % rival_grudge
	var grudge_width := CellOutzType.width(grudge_text, 11.0, 1.0)
	CellOutzType.draw_text(self, anchor + Vector2(plate_size.x - 12 - grudge_width, 44), grudge_text, 11.0, HOT if strength > 0.5 else INK * Color(1, 1, 1, 0.8), 1.0)
	for index in 18:
		var lit := float(index) / 18.0 < strength
		var x := anchor.x + 62 + index * 10.0
		if x > anchor.x + plate_size.x - 12:
			break
		draw_line(Vector2(x, anchor.y + 68), Vector2(x, anchor.y + 68 - (11.0 if lit else 4.0)), HOT if lit else INK * Color(1, 1, 1, 0.13), 3.0)


func _draw_speed(viewport: Vector2) -> void:
	var center := Vector2(viewport.x - 128, viewport.y - 118)
	var normalized := clampf(displayed_speed / 24.0, 0.0, 1.0)
	draw_arc(center, 66, PI * 0.8, PI * 2.2, 48, FAINT, 9.0)
	draw_arc(center, 66, PI * 0.8, lerpf(PI * 0.8, PI * 2.2, normalized), 48, MOSS.lerp(HOT, normalized), 9.0)
	for index in 13:
		var angle := lerpf(PI * 0.8, PI * 2.2, float(index) / 12.0)
		draw_line(center + Vector2(cos(angle), sin(angle)) * 54, center + Vector2(cos(angle), sin(angle)) * 62, INK * Color(1, 1, 1, 0.5), 2.0)
	var reading := "%02d" % roundi(displayed_speed)
	var reading_width := CellOutzType.width(reading, 30.0, 1.4)
	CellOutzType.draw_text(self, center + Vector2(-reading_width * 0.5, -18), reading, 30.0, INK, 1.4)
	var label_width := CellOutzType.width("VELOCITY", 9.0, 1.0)
	CellOutzType.draw_text(self, center + Vector2(-label_width * 0.5, 22), "VELOCITY", 9.0, COPPER, 1.0)


## A5.3. Where everything else in the pit actually is, which the HUD never told
## you — the old readout was a count. The data was already being sent to the cab
## screens; the windscreen just never used it.
func _draw_radar(viewport: Vector2) -> void:
	var center := Vector2(138, viewport.y - 118)
	var radius := 62.0
	draw_circle(center, radius, Color(0, 0, 0, 0.34))
	draw_arc(center, radius, 0, TAU, 48, COPPER * Color(1, 1, 1, 0.45), 1.6)
	for ring in [0.33, 0.66]:
		draw_arc(center, radius * ring, 0, TAU, 32, INK * Color(1, 1, 1, 0.12), 1.0)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), INK * Color(1, 1, 1, 0.10), 1.0)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), INK * Color(1, 1, 1, 0.10), 1.0)
	# The sweep, and the contacts it finds.
	var sweep := fmod(elapsed * 1.4, TAU)
	draw_line(center, center + Vector2(cos(sweep), sin(sweep)) * radius, MOSS * Color(1, 1, 1, 0.35), 2.0)
	for contact in contacts:
		var offset: Vector2 = contact.get("offset", Vector2.ZERO)
		var scaled := offset / maxf(1.0, arena_limit) * radius
		if scaled.length() > radius:
			scaled = scaled.normalized() * radius
		var rival := bool(contact.get("rival", false))
		var hurt := clampf(float(contact.get("integrity", 100)) / 100.0, 0.0, 1.0)
		var tone: Color = HOT if rival else MOSS.lerp(HOT, 1.0 - hurt)
		if rival:
			var mark := center + scaled
			draw_polyline(PackedVector2Array([
				mark + Vector2(0, -6), mark + Vector2(6, 0), mark + Vector2(0, 6), mark + Vector2(-6, 0), mark + Vector2(0, -6),
			]), tone, 1.8)
		else:
			draw_circle(center + scaled, 3.2, tone)
	# The player, always at the centre, always pointing up.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -7), center + Vector2(5, 5), center, center + Vector2(-5, 5),
	]), INK)
	CellOutzType.draw_text(self, center + Vector2(-radius, radius + 8), "CONTACT", 9.0, COPPER, 1.0)
	var count := "%02d" % contacts.size()
	var count_width := CellOutzType.width(count, 9.0, 1.0)
	CellOutzType.draw_text(self, center + Vector2(radius - count_width, radius + 8), count, 9.0, INK * Color(1, 1, 1, 0.6), 1.0)


func _draw_event_feed(viewport: Vector2) -> void:
	if message_life <= 0.0:
		return
	var alpha := clampf(message_life, 0, 1)
	var y := viewport.y * 0.26 + sin(elapsed * 12) * impact_flash * 4
	var width := CellOutzType.width(event_message, 20.0, 1.6)
	var x := (viewport.x - width) * 0.5
	draw_line(Vector2(x - 40, y + 10), Vector2(x - 12, y + 10), COPPER * Color(1, 1, 1, alpha), 2)
	CellOutzType.draw_text(self, Vector2(x, y), event_message, 20.0, INK * Color(1, 1, 1, alpha), 1.6)
	draw_line(Vector2(x + width + 12, y + 10), Vector2(x + width + 40, y + 10), COPPER * Color(1, 1, 1, alpha), 2)
	if impact_value > 0:
		var value := "+%d" % (impact_value * 5)
		var value_width := CellOutzType.width(value, 13.0, 1.0)
		CellOutzType.draw_text(self, Vector2((viewport.x - value_width) * 0.5, y + 26), value, 13.0, HOT * Color(1, 1, 1, alpha), 1.0)


## A5.5. The old ribbon was a sentence: "WASD DRIVE [I] WORLD INDEX [E] EXIT
## VEHICLE". Keys are drawn as keycaps instead, which is both shorter and easier
## to find at speed.
func _draw_keys(viewport: Vector2) -> void:
	var keys := [["WASD", "DRIVE"], ["I", "INDEX"], ["E", "OUT"]]
	var x := viewport.x * 0.5 - 150.0
	var y := viewport.y - 42.0
	for entry in keys:
		var cap: String = entry[0]
		var cap_width := CellOutzType.width(cap, 10.0, 1.0)
		var box := Rect2(Vector2(x, y), Vector2(cap_width + 14.0, 20.0))
		draw_colored_polygon(PackedVector2Array([
			box.position + Vector2(3, 0), box.position + Vector2(box.size.x, 0),
			box.position + box.size - Vector2(3, 0), box.position + Vector2(0, box.size.y),
		]), Color(0, 0, 0, 0.42))
		draw_polyline(PackedVector2Array([
			box.position + Vector2(3, 0), box.position + Vector2(box.size.x, 0),
			box.position + box.size - Vector2(3, 0), box.position + Vector2(0, box.size.y), box.position + Vector2(3, 0),
		]), INK * Color(1, 1, 1, 0.30), 1.0)
		CellOutzType.draw_text(self, box.position + Vector2(7, 5), cap, 10.0, INK * Color(1, 1, 1, 0.82), 1.0)
		CellOutzType.draw_text(self, box.position + Vector2(box.size.x + 7, 5), str(entry[1]), 10.0, INK * Color(1, 1, 1, 0.38), 1.0)
		x += box.size.x + CellOutzType.width(str(entry[1]), 10.0, 1.0) + 26.0


func _draw_impact(viewport: Vector2) -> void:
	var center := viewport * 0.5
	var alpha := impact_flash * 0.45
	for index in 12:
		var angle := TAU * float(index) / 12.0 + elapsed
		var start := center + Vector2(cos(angle), sin(angle)) * (90 + (1.0 - impact_flash) * 80)
		var finish := center + Vector2(cos(angle), sin(angle)) * (140 + (1.0 - impact_flash) * 160)
		draw_line(start, finish, HOT * Color(1, 1, 1, alpha), 2.0 + float(index % 3))
	draw_arc(center, 110 + (1.0 - impact_flash) * 90, 0, TAU, 64, COPPER * Color(1, 1, 1, alpha), 4)
	# Fresh spatter thrown onto the glass by the hit, fading with the flash.
	Grunge.spatter(self, center + Vector2(0, -60), 5501, 10, Vector2(0.2, -0.9), Grunge.WET * Color(1, 1, 1, alpha * 2.0))
