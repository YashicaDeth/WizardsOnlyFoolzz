class_name DashCluster
extends SubViewport

## M2.6 / AG3.1. The instruments.
##
## The derby lost every readout it had. `_ready` in `rift_derby.gd` sets
## `status.visible = false`, `score_label.visible = false` and
## `rival_label.visible = false`, and the comment above them says the hull is
## read off the car instead — which sounded right while I0 was being applied and
## is wrong in the seat, because **you cannot see your own car from inside it.**
## The first playtester's verdict was blunt: no HUD, no hull.
##
## I0 never said the player gets no information. It said no screen is a list of
## text in a box. A gauge is not a list of text in a box: it is an object, with a
## needle, bolted into a binnacle, lit from behind, that you glance at while
## something is trying to kill you. That answers both at once.
##
## So this renders a cluster into a viewport and `vehicle_interior.gd` hangs it
## on the dash as a real surface in the world. It sits at the angle the binnacle
## sits at, it is lit by the cab, and when the glass gets filthy it gets harder
## to read — because it is glass.

const CellOutzType := preload("res://systems/celloutz_type.gd")

const FACE := Color("07090a")
const BACKLIT := Color("c98a2e")
const NEEDLE := Color("d9481f")
const LAMP_OUT := Color("1d1a16")
const LAMP_LIVE := Color("9bf01a")
const LAMP_DEAD := Color("5e1410")
const RIVAL_LAMP := Color("c81f16")
const ETCH := Color("6d6354")

## Wider than it is tall, the way a real cluster is.
const PANEL := Vector2i(420, 200)

## Where the hull needle starts and stops. A gauge that sweeps the full circle
## reads as a dial; one that sweeps about 230 degrees reads as an instrument.
const SWEEP_FROM := 2.583
const SWEEP_TO := 6.842

var face: Control

var hull := 100.0
var pace := 0.0
var impacts := 0
var wreckers_left := 8
var wreckers_total := 8
var rival_grudge := 0
var rival_here := false
var rounds := 12
var rounds_full := 12
var service_left := 0
var service_total := 0
var surveillance := 0.0
## Rises when something hits the car, so the needle kicks rather than sliding.
var jolt := 0.0
## Filth on the instrument glass. Climbs with damage taken.
var grime := 0.0
var _shown_hull := 100.0
var _shown_pace := 0.0
var _clock := 0.0
## AG3.5. Greg, in the seat: *"no direction of controls"*. The full answer is the
## tutorial web in AH; this is the part the car itself can do. Every vehicle
## built after about 1960 carries a placard telling you how to work it, screwed
## to the dash and ignored within a week, and that is exactly the right register
## and the right lifespan for this. It is etched into the face, under the
## instruments, and it fades once you have plainly stopped needing it.
var placard := 1.0


func _init() -> void:
	name = "DashCluster"
	size = PANEL
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	disable_3d = true
	var panel := Control.new()
	panel.name = "Face"
	panel.size = Vector2(PANEL)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	face = panel
	panel.draw.connect(_paint)


## Fed by whoever owns the car, every frame. Nothing here reaches back out.
func report(values: Dictionary) -> void:
	var was := hull
	hull = clampf(float(values.get("hull", hull)), 0.0, 100.0)
	if hull < was - 0.5:
		# A hit is felt on the gauge, not only read off it.
		jolt = minf(1.0, jolt + (was - hull) * 0.05)
		grime = clampf(grime + (was - hull) * 0.004, 0.0, 0.72)
	pace = clampf(float(values.get("pace", pace)), 0.0, 1.0)
	# It goes away because you drove, not because a timer ran out. Somebody
	# sitting still reading it still has it.
	if pace > 0.25:
		placard = maxf(0.0, placard - 0.0022)
	impacts = int(values.get("impacts", impacts))
	wreckers_left = int(values.get("wreckers_left", wreckers_left))
	wreckers_total = maxi(1, int(values.get("wreckers_total", wreckers_total)))
	rival_grudge = int(values.get("rival_grudge", rival_grudge))
	rival_here = bool(values.get("rival_here", rival_here))
	rounds = int(values.get("rounds", rounds))
	rounds_full = maxi(1, int(values.get("rounds_full", rounds_full)))
	service_left = maxi(0, int(values.get("service_left", service_left)))
	service_total = maxi(0, int(values.get("service_total", service_total)))
	surveillance = clampf(float(values.get("surveillance", surveillance)), 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	jolt = maxf(0.0, jolt - delta * 2.2)
	# Needles have mass. Snapping to the value is what makes a gauge read as a
	# number that happens to be drawn round.
	_shown_hull = move_toward(_shown_hull, hull, delta * 62.0)
	_shown_pace = lerpf(_shown_pace, pace, minf(delta * 6.0, 1.0))
	if face != null and is_instance_valid(face):
		face.queue_redraw()


func _paint() -> void:
	var whole := Rect2(Vector2.ZERO, Vector2(PANEL))
	face.draw_rect(whole, FACE)
	# The backlight, strongest behind the dials and falling off to the corners.
	for ring in 5:
		var spread := 1.0 - float(ring) / 5.0
		face.draw_circle(Vector2(128, 96), 96.0 + float(ring) * 34.0, Color(BACKLIT, 0.028 * spread))

	_hull_dial(Vector2(128, 96), 78.0)
	_pace_dial(Vector2(300, 66), 46.0)
	_wrecker_lamps(Vector2(232, 132))
	if service_total > 0:
		_service_lamps(Vector2(232, 160))
	else:
		_impact_counter(Vector2(232, 160))
	_magazine(Vector2(356, 96))
	_rival_telltale(Vector2(388, 154))
	if placard > 0.01:
		_placard(Vector2(16, 194))

	# The instrument glass. Filthy, and filthier the longer the heat runs, which
	# is the cheapest honest way to make information cost something.
	if grime > 0.01:
		face.draw_rect(whole, Color(0.24, 0.19, 0.13, grime * 0.34))
		var rng := RandomNumberGenerator.new()
		rng.seed = 4409
		for _speck in 46:
			var at := Vector2(rng.randf() * float(PANEL.x), rng.randf() * float(PANEL.y))
			face.draw_circle(at, rng.randf_range(0.8, 3.4), Color(0.10, 0.08, 0.06, grime * 0.5))
	# A hard highlight across the top, so it reads as covered rather than open.
	face.draw_line(Vector2(8, 6), Vector2(float(PANEL.x) - 8.0, 14), Color(1, 1, 1, 0.05), 8.0)


## AG3.5. Etched, not printed: the same colour as the face, a shade lighter,
## the way a moulded warning on a dashboard is legible only when light catches
## it. Says what the car does, in the order you need it.
func _placard(at: Vector2) -> void:
	var ink := Color(ETCH, 0.34 + placard * 0.5)
	var keys := "WASD DRIVE   LMB FIRE   R RELOAD   E GET OUT   F VIEW   I INDEX"
	CellOutzType.draw_condensed(face, at, keys, 9.0, ink, 1.6)
	face.draw_line(at + Vector2(0, 4), at + Vector2(384, 4), Color(ETCH, 0.12 + placard * 0.2), 1.0)


## The hull gauge. The one thing the playtester could not find.
func _hull_dial(centre: Vector2, radius: float) -> void:
	# The red zone is printed into the face, under the ticks, the way it is on a
	# real dial — rather than lighting up once you are already in it.
	var danger_to := SWEEP_FROM + (SWEEP_TO - SWEEP_FROM) * 0.3
	face.draw_arc(centre, radius - 9.0, SWEEP_FROM, danger_to, 28, Color(NEEDLE, 0.30), 13.0, true)
	face.draw_arc(centre, radius, SWEEP_FROM, SWEEP_TO, 64, Color(ETCH, 0.55), 2.0, true)

	for tick in 11:
		var at := SWEEP_FROM + (SWEEP_TO - SWEEP_FROM) * (float(tick) / 10.0)
		var long := tick % 5 == 0
		var direction := Vector2(cos(at), sin(at))
		face.draw_line(
			centre + direction * (radius - (14.0 if long else 7.0)),
			centre + direction * radius,
			Color(BACKLIT, 0.85 if long else 0.4),
			3.0 if long else 1.6
		)
	CellOutzType.draw_condensed(face, centre + Vector2(-46, 40), "HULL", 11.0, Color(BACKLIT, 0.8), 2.4)

	# The needle, with the jolt on top so an impact visibly knocks it.
	var shown := clampf(_shown_hull + sin(_clock * 41.0) * jolt * 9.0, 0.0, 100.0)
	var angle := SWEEP_FROM + (SWEEP_TO - SWEEP_FROM) * (shown / 100.0)
	var tip := centre + Vector2(cos(angle), sin(angle)) * (radius - 12.0)
	var tail := centre - Vector2(cos(angle), sin(angle)) * 13.0
	face.draw_line(tail, tip, NEEDLE, 4.0, true)
	face.draw_circle(centre, 9.0, FACE.lightened(0.14))
	face.draw_circle(centre, 5.0, NEEDLE.darkened(0.2))

	# The number, small and under the spindle. A gauge you have to read
	# precisely while being rammed is a gauge that failed.
	var numeral := "%03d" % roundi(_shown_hull)
	var warn: Color = NEEDLE if hull <= 30.0 else BACKLIT
	if hull <= 30.0 and fmod(_clock, 0.9) < 0.45:
		warn = NEEDLE.lightened(0.35)
	CellOutzType.draw_condensed(face, centre + Vector2(-22, 62), numeral, 20.0, warn, 2.0)


func _pace_dial(centre: Vector2, radius: float) -> void:
	face.draw_arc(centre, radius, SWEEP_FROM, SWEEP_TO, 48, Color(ETCH, 0.4), 1.6, true)
	for tick in 7:
		var at := SWEEP_FROM + (SWEEP_TO - SWEEP_FROM) * (float(tick) / 6.0)
		var direction := Vector2(cos(at), sin(at))
		face.draw_line(centre + direction * (radius - 6.0), centre + direction * radius, Color(BACKLIT, 0.45), 1.6)
	var angle := SWEEP_FROM + (SWEEP_TO - SWEEP_FROM) * _shown_pace
	face.draw_line(centre, centre + Vector2(cos(angle), sin(angle)) * (radius - 8.0), Color(BACKLIT, 0.9), 2.6, true)
	face.draw_circle(centre, 5.0, FACE.lightened(0.2))
	CellOutzType.draw_condensed(face, centre + Vector2(-18, 30), "PACE", 9.0, Color(BACKLIT, 0.55), 2.0)


## Eight lamps, one per wrecker. This is the objective, and it was the other
## thing the player had no way to read: how many are left.
func _wrecker_lamps(at: Vector2) -> void:
	CellOutzType.draw_condensed(face, at - Vector2(0, 12), "STILL RUNNING", 9.0, Color(ETCH, 0.8), 2.0)
	for index in wreckers_total:
		var lamp := at + Vector2(float(index) * 17.0 + 6.0, 4.0)
		var alive := index < wreckers_left
		face.draw_circle(lamp, 6.0, LAMP_OUT)
		if alive:
			# A live lamp breathes, so the row is not a static graphic.
			var pulse := 0.82 + sin(_clock * 2.2 + float(index)) * 0.18
			face.draw_circle(lamp, 4.6, Color(LAMP_LIVE, pulse))
			face.draw_circle(lamp, 7.6, Color(LAMP_LIVE, 0.12))
		else:
			face.draw_circle(lamp, 4.6, LAMP_DEAD)
			# Struck through, because it is not off — it is finished.
			face.draw_line(lamp + Vector2(-5, -5), lamp + Vector2(5, 5), Color(ETCH, 0.6), 1.4)


## AG3.4. What is left in the gun, drawn as rounds rather than as a number,
## because you count rounds by looking at them.
func _magazine(at: Vector2) -> void:
	CellOutzType.draw_condensed(face, at + Vector2(-2, -10), "LOAD", 9.0, Color(ETCH, 0.8), 2.0)
	for index in rounds_full:
		var column := index % 6
		var row := index / 6
		var cell := Rect2(at + Vector2(float(column) * 9.0, float(row) * 13.0), Vector2(6, 10))
		if index < rounds:
			face.draw_rect(cell, Color(BACKLIT, 0.9))
			face.draw_rect(Rect2(cell.position, Vector2(6, 3)), Color(NEEDLE, 0.8))
		else:
			face.draw_rect(cell, Color(ETCH, 0.22), false, 1.0)


## The underground cab was already a physical instrument panel, so the new
## territorial objective belongs here rather than as another screen-space HUD.
## Three lamps are the three real tunnel chambers; the red strip is how much of
## the current scan the relays have on the vehicle.
func _service_lamps(at: Vector2) -> void:
	CellOutzType.draw_condensed(face, at - Vector2(0, 11), "LOCKDOWN", 9.0, Color(ETCH, 0.8), 2.0)
	var disabled := maxi(0, service_total - service_left)
	for index in service_total:
		var lamp_at := at + Vector2(12.0 + float(index) * 22.0, 3.0)
		face.draw_circle(lamp_at, 7.0, LAMP_OUT)
		if index < disabled:
			face.draw_circle(lamp_at, 5.0, LAMP_DEAD)
			face.draw_line(lamp_at + Vector2(-5, -5), lamp_at + Vector2(5, 5), Color(ETCH, 0.7), 1.4)
		else:
			var pulse := 0.76 + sin(_clock * 3.1 + float(index)) * 0.24
			face.draw_circle(lamp_at, 5.0, Color(RIVAL_LAMP, pulse))
	var scan_bar := Rect2(at + Vector2(0, 16), Vector2(82, 5))
	face.draw_rect(scan_bar, Color(ETCH, 0.18))
	face.draw_rect(Rect2(scan_bar.position, Vector2(scan_bar.size.x * surveillance, scan_bar.size.y)), Color(RIVAL_LAMP, 0.9))
	if surveillance > 0.7:
		CellOutzType.draw_condensed(face, at + Vector2(88, 20), "ACQUIRED", 8.0, RIVAL_LAMP, 1.4)


## A mechanical counter, digits on drums, so the number reads as a thing the car
## is keeping rather than a variable the game is printing.
func _impact_counter(at: Vector2) -> void:
	CellOutzType.draw_condensed(face, at - Vector2(0, 11), "IMPACT", 9.0, Color(ETCH, 0.8), 2.0)
	var text := "%06d" % impacts
	for index in text.length():
		var cell := Rect2(at + Vector2(float(index) * 16.0, 0), Vector2(14, 20))
		face.draw_rect(cell, Color(0.04, 0.04, 0.05))
		face.draw_rect(cell, Color(ETCH, 0.35), false, 1.0)
		CellOutzType.draw_condensed(face, cell.position + Vector2(3, 15), text[index], 13.0, BACKLIT, 0.0)


## The telltale. Dark when Mara is not in the pit, lit when she is, and the
## harder it burns the longer she has been carrying it.
func _rival_telltale(at: Vector2) -> void:
	var heat := clampf(float(rival_grudge) / 60.0, 0.0, 1.0)
	var glow: Color = LAMP_OUT
	if rival_here:
		glow = RIVAL_LAMP.lightened(heat * 0.4)
		var flicker := 0.7 + sin(_clock * (3.0 + heat * 6.0)) * 0.3
		face.draw_circle(at, 15.0, Color(RIVAL_LAMP, 0.14 * flicker))
	face.draw_circle(at, 9.0, glow)
	face.draw_arc(at, 9.0, 0.0, TAU, 20, Color(ETCH, 0.5), 1.4, true)
	var label_tint: Color = RIVAL_LAMP if rival_here else ETCH
	CellOutzType.draw_condensed(face, at + Vector2(-20, 24), "VOSS", 9.0, Color(label_tint, 0.9), 2.0)
