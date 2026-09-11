extends Control

# Responsive diegetic telemetry layer. It deliberately uses vectors, arcs,
# kinetic type and asymmetry instead of static rectangle panels.
const INK := Color("f1d2a3")
const COPPER := Color("f06428")
const HOT := Color("ff2b18")
const TEAL := Color("29b7a8")
const SMOKE := Color(0.025, 0.012, 0.009, 0.86)
const FAINT := Color(0.95, 0.66, 0.38, 0.22)

var speed := 0.0
var score := 0
var integrity := 100
var active_wreckers := 0
var memory_count := 0
var rival_status := "ACTIVE"
var rival_grudge := 0
var rival_elo := 1180
var elapsed := 0.0
var impact_flash := 0.0
var impact_value := 0
var event_message := "THE ROAD REMEMBERS"
var message_life := 0.0
var displayed_score := 0.0
var displayed_speed := 0.0
var displayed_integrity := 100.0
var shards: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	for index in 18:
		shards.append({
			"phase": float(index) * 0.67,
			"radius": 44.0 + float(index % 5) * 15.0,
			"speed": 0.25 + float(index % 4) * 0.09,
			"size": 2.0 + float(index % 3),
		})


func set_telemetry(values: Dictionary) -> void:
	speed = float(values.get("speed", speed))
	score = int(values.get("score", score))
	integrity = int(values.get("integrity", integrity))
	active_wreckers = int(values.get("active_wreckers", active_wreckers))
	memory_count = int(values.get("memory_count", memory_count))
	rival_status = str(values.get("rival_status", rival_status)).to_upper()
	rival_grudge = int(values.get("rival_grudge", rival_grudge))
	rival_elo = int(values.get("rival_elo", rival_elo))


func announce_impact(value: int, rival_hit: bool) -> void:
	impact_flash = 1.0
	impact_value = value
	message_life = 2.4
	event_message = "MARA REMEMBERS THIS" if rival_hit else "IMPACT RECORDED // +%d" % (value * 5)


func _process(delta: float) -> void:
	elapsed += delta
	impact_flash = move_toward(impact_flash, 0.0, delta * 2.8)
	message_life = maxf(0.0, message_life - delta)
	displayed_score = lerpf(displayed_score, float(score), 1.0 - exp(-delta * 8.0))
	displayed_speed = lerpf(displayed_speed, absf(speed), 1.0 - exp(-delta * 11.0))
	displayed_integrity = lerpf(displayed_integrity, float(integrity), 1.0 - exp(-delta * 6.0))
	queue_redraw()


## The damage portrait occupies the top-left corner in the derby, so the title
## block is suppressed there rather than drawn underneath it.
var show_title := true


func _draw() -> void:
	var viewport := size
	if viewport.x < 400 or viewport.y < 300:
		return
	_draw_edge_frame(viewport)
	if show_title:
		_draw_title(viewport)
	_draw_speed_instrument(viewport)
	_draw_integrity_instrument(viewport)
	_draw_rival_signal(viewport)
	_draw_event_feed(viewport)
	_draw_control_ribbon(viewport)
	_draw_particles(viewport)
	if impact_flash > 0.0:
		_draw_impact(viewport)


func _draw_edge_frame(viewport: Vector2) -> void:
	var breathe := 0.55 + sin(elapsed * 1.7) * 0.12
	var corner := 38.0
	var margin := 18.0
	var color := COPPER * Color(1, 1, 1, breathe)
	for top in [margin, viewport.y - margin]:
		draw_line(Vector2(margin, top), Vector2(margin + corner, top), color, 2.0)
		draw_line(Vector2(viewport.x - margin - corner, top), Vector2(viewport.x - margin, top), color, 2.0)
	for left in [margin, viewport.x - margin]:
		draw_line(Vector2(left, margin), Vector2(left, margin + corner), color, 2.0)
		draw_line(Vector2(left, viewport.y - margin - corner), Vector2(left, viewport.y - margin), color, 2.0)


func _draw_title(viewport: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var origin := Vector2(44, 48)
	draw_string(font, origin, "CELLOUTZ // BONE YARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COPPER)
	draw_string(font, origin + Vector2(0, 25), "MERCY COUNTY LIVE COLLISION FEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK * Color(1, 1, 1, 0.68))
	var pulse_width := 120.0 + sin(elapsed * 2.0) * 18.0
	draw_line(origin + Vector2(0, 36), origin + Vector2(pulse_width, 36), TEAL, 3.0)
	for index in 5:
		var x := origin.x + pulse_width + 10 + index * 8
		draw_circle(Vector2(x, origin.y + 36), 1.5 + float(index % 2), COPPER * Color(1, 1, 1, 0.55))


func _draw_speed_instrument(viewport: Vector2) -> void:
	var center := Vector2(viewport.x - 132, viewport.y - 128)
	var normalized := clampf(displayed_speed / 24.0, 0.0, 1.0)
	draw_arc(center, 72, PI * 0.8, PI * 2.2, 48, FAINT, 10.0)
	draw_arc(center, 72, PI * 0.8, lerpf(PI * 0.8, PI * 2.2, normalized), 48, TEAL.lerp(HOT, normalized), 10.0)
	for index in 13:
		var angle := lerpf(PI * 0.8, PI * 2.2, float(index) / 12.0)
		var inner := center + Vector2(cos(angle), sin(angle)) * 58
		var outer := center + Vector2(cos(angle), sin(angle)) * 68
		draw_line(inner, outer, INK * Color(1, 1, 1, 0.62), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-44, 6), "%02d" % roundi(displayed_speed), HORIZONTAL_ALIGNMENT_CENTER, 88, 34, INK)
	draw_string(font, center + Vector2(-35, 28), "VELOCITY", HORIZONTAL_ALIGNMENT_CENTER, 70, 11, COPPER)


## One plate for every readout. The HUD previously refused panels on principle
## and the result was live data floating on the sky with nothing to read it
## against. A panel is not the enemy of this look — an unshaped one is, so the
## plate is notched and stamped rather than a rounded card.
func _plate(at: Vector2, plate_size: Vector2, label: String, code: String, accent: Color) -> void:
	var notch := 13.0
	var body := PackedVector2Array([
		at + Vector2(notch, 0),
		at + Vector2(plate_size.x, 0),
		at + Vector2(plate_size.x, plate_size.y - notch),
		at + Vector2(plate_size.x - notch, plate_size.y),
		at + Vector2(0, plate_size.y),
		at + Vector2(0, notch),
	])
	draw_colored_polygon(body, SMOKE)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, accent * Color(1, 1, 1, 0.5), 1.5)
	# Title and form code sit on the accent strip so the data below never has to
	# compete with its own label for contrast.
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(notch, 0), at + Vector2(plate_size.x, 0),
		at + Vector2(plate_size.x, 18), at + Vector2(0, 18), at + Vector2(0, notch),
	]), accent * Color(1, 1, 1, 0.18))
	draw_line(at + Vector2(0, 18), at + Vector2(plate_size.x, 18), accent * Color(1, 1, 1, 0.45), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(11, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent)
	draw_string(font, at + Vector2(0, 14), code, HORIZONTAL_ALIGNMENT_RIGHT, plate_size.x - 9, 9, INK * Color(1, 1, 1, 0.38))


func _draw_integrity_instrument(viewport: Vector2) -> void:
	var plate_size := Vector2(250, 98)
	var anchor := Vector2(viewport.x - plate_size.x - 30, 32)
	var ratio := clampf(displayed_integrity / 100.0, 0, 1)
	var tone := HOT.lerp(TEAL, ratio)
	_plate(anchor, plate_size, "HULL INTEGRITY", "CZ-88/H", tone)
	var font := ThemeDB.fallback_font
	# The figure you read at a glance gets the size; everything else is legend.
	draw_string(font, anchor + Vector2(12, 52), "%03d" % roundi(displayed_integrity), HORIZONTAL_ALIGNMENT_LEFT, -1, 29, tone)
	draw_string(font, anchor + Vector2(62, 52), "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tone * Color(1, 1, 1, 0.7))
	# Segmented, because a derby hull fails in panels rather than on a smooth
	# gradient — and a segment count is readable at a glance where a bar is not.
	for index in 12:
		var x := anchor.x + 92 + index * 12.0
		var lit := float(index) / 12.0 < ratio
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, anchor.y + 34), Vector2(x + 9, anchor.y + 34),
			Vector2(x + 6, anchor.y + 54), Vector2(x - 3, anchor.y + 54),
		]), tone if lit else INK * Color(1, 1, 1, 0.11))
	draw_line(anchor + Vector2(12, 64), anchor + Vector2(plate_size.x - 12, 64), INK * Color(1, 1, 1, 0.16), 1.0)
	draw_string(font, anchor + Vector2(12, 80), "SCORE %06d    WRECKERS %02d    MEM %03d" % [roundi(displayed_score), active_wreckers, memory_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.78))


func _draw_rival_signal(viewport: Vector2) -> void:
	var plate_size := Vector2(272, 90)
	var anchor := Vector2(212, 30)
	var strength := clampf(float(rival_grudge) / 100.0, 0.0, 1.0)
	_plate(anchor, plate_size, "HUNT SIGNAL", "CZ-12/R", HOT)
	var font := ThemeDB.fallback_font
	# Only the lamp jitters. Shaking the whole plate made the text shimmer,
	# which is noise impersonating tension.
	var lamp := anchor + Vector2(28, 46) + Vector2(sin(elapsed * 19.0), cos(elapsed * 23.0)) * strength * 2.0
	var diamond := PackedVector2Array([lamp + Vector2(0, -13), lamp + Vector2(13, 0), lamp + Vector2(0, 13), lamp + Vector2(-13, 0)])
	draw_colored_polygon(diamond, Color(0.32, 0.035, 0.02, 0.85))
	var edge := diamond.duplicate()
	edge.append(diamond[0])
	draw_polyline(edge, HOT, 2.0)
	draw_circle(lamp, 3.5 + sin(elapsed * 4.0) * 1.4 * (0.35 + strength), HOT)
	draw_string(font, anchor + Vector2(52, 45), "MARA VOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_string(font, anchor + Vector2(52, 62), "%s    ELO %04d" % [rival_status, rival_elo], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.66))
	draw_string(font, anchor + Vector2(0, 45), "GRUDGE %03d" % rival_grudge, HORIZONTAL_ALIGNMENT_RIGHT, plate_size.x - 12, 13, HOT if strength > 0.5 else INK * Color(1, 1, 1, 0.85))
	# A real meter: twenty ticks lit in proportion to the grudge. The previous
	# bars were (grudge + index * 13) % 17 — motion shaped like data.
	for index in 20:
		var lit := float(index) / 20.0 < strength
		var x := anchor.x + 52 + index * 10.0
		draw_line(Vector2(x, anchor.y + 78), Vector2(x, anchor.y + 78 - (13.0 if lit else 5.0)), HOT if lit else INK * Color(1, 1, 1, 0.15), 3.0)


func _draw_event_feed(viewport: Vector2) -> void:
	if message_life <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var alpha := clampf(message_life, 0, 1)
	var y := viewport.y * 0.27 + sin(elapsed * 12) * impact_flash * 4
	var width := font.get_string_size(event_message, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
	var x := (viewport.x - width) * 0.5
	draw_line(Vector2(x - 36, y + 8), Vector2(x - 8, y + 8), COPPER * Color(1, 1, 1, alpha), 2)
	draw_string(font, Vector2(x, y + 15), event_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK * Color(1, 1, 1, alpha))
	draw_line(Vector2(x + width + 8, y + 8), Vector2(x + width + 36, y + 8), COPPER * Color(1, 1, 1, alpha), 2)


func _draw_control_ribbon(viewport: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var text := "WASD DRIVE        [I] WORLD INDEX        [E] EXIT VEHICLE"
	var width := 600.0
	var x := viewport.x * 0.5 - width * 0.5
	var y := viewport.y - 44.0
	# The ribbon carried no ground either, so the controls washed out against
	# whatever the pit happened to be doing behind them.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 18, y), Vector2(x + width + 18, y),
		Vector2(x + width + 4, y + 23), Vector2(x - 4, y + 23),
	]), SMOKE)
	draw_string(font, Vector2(x, y + 16), text, HORIZONTAL_ALIGNMENT_CENTER, width, 12, INK * Color(1, 1, 1, 0.84))


func _draw_particles(viewport: Vector2) -> void:
	var center := viewport * 0.5
	for shard in shards:
		var angle := elapsed * float(shard.speed) + float(shard.phase)
		var radius := minf(viewport.x, viewport.y) * 0.47 + float(shard.radius)
		var point := center + Vector2(cos(angle), sin(angle) * 0.55) * radius
		draw_circle(point, float(shard.size), COPPER * Color(1, 1, 1, 0.18))


func _draw_impact(viewport: Vector2) -> void:
	var center := viewport * 0.5
	var alpha := impact_flash * 0.5
	for index in 12:
		var angle := TAU * float(index) / 12.0 + elapsed
		var start := center + Vector2(cos(angle), sin(angle)) * (90 + (1.0 - impact_flash) * 80)
		var finish := center + Vector2(cos(angle), sin(angle)) * (140 + (1.0 - impact_flash) * 160)
		draw_line(start, finish, HOT * Color(1, 1, 1, alpha), 2.0 + float(index % 3))
	draw_arc(center, 110 + (1.0 - impact_flash) * 90, 0, TAU, 64, COPPER * Color(1, 1, 1, alpha), 4)
