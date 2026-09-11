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
	var sweep_x := fmod(elapsed * 140.0, viewport.x + 300.0) - 150.0
	draw_line(Vector2(sweep_x, 20), Vector2(sweep_x + 90, 20), Color(1, 0.35, 0.12, 0.6), 1.0)


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


func _draw_integrity_instrument(viewport: Vector2) -> void:
	var anchor := Vector2(viewport.x - 270, 42)
	var width := 220.0
	var ratio := clampf(displayed_integrity / 100.0, 0, 1)
	var tone := HOT.lerp(TEAL, ratio)
	var shape := PackedVector2Array([
		anchor, anchor + Vector2(width, 0), anchor + Vector2(width - 18, 16), anchor + Vector2(22, 16)
	])
	draw_colored_polygon(shape, SMOKE)
	draw_polyline(PackedVector2Array([anchor + Vector2(7, 8), anchor + Vector2(7 + (width - 28) * ratio, 8)]), tone, 7.0)
	var font := ThemeDB.fallback_font
	draw_string(font, anchor + Vector2(0, 36), "HULL // %03d%%" % roundi(displayed_integrity), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tone)
	draw_string(font, anchor + Vector2(0, 57), "SCORE %06d    WRECKERS %02d" % [roundi(displayed_score), active_wreckers], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	draw_string(font, anchor + Vector2(0, 75), "WORLD MEMORY %03d" % memory_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.65))


func _draw_rival_signal(viewport: Vector2) -> void:
	var anchor := Vector2(212, 34)
	var font := ThemeDB.fallback_font
	var signal_strength := float(rival_grudge) / 100.0
	var jitter := Vector2(sin(elapsed * 19) * signal_strength * 3, cos(elapsed * 23) * signal_strength * 2)
	anchor += jitter
	var diamond := PackedVector2Array([anchor + Vector2(18, 0), anchor + Vector2(36, 18), anchor + Vector2(18, 36), anchor + Vector2(0, 18)])
	draw_colored_polygon(diamond, Color(0.32, 0.035, 0.02, 0.8))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), HOT, 2.0)
	draw_circle(anchor + Vector2(18, 18), 4 + sin(elapsed * 4) * 1.5, HOT)
	draw_string(font, anchor + Vector2(49, 12), "HUNT SIGNAL // MARA VOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HOT)
	draw_string(font, anchor + Vector2(49, 34), "%s   GRUDGE %03d   ELO %04d" % [rival_status, rival_grudge, rival_elo], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	for index in 10:
		var height := 4.0 + float((rival_grudge + index * 13) % 17)
		draw_line(anchor + Vector2(49 + index * 12, 52), anchor + Vector2(49 + index * 12, 52 - height), HOT * Color(1, 1, 1, 0.48), 4.0)


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
	var text := "WASD DRIVE    [V] VISCERA    [I] WORLD INDEX    [E] EXIT VEHICLE"
	var y := viewport.y - 28.0
	draw_string(font, Vector2(viewport.x * 0.5 - 350, y), text, HORIZONTAL_ALIGNMENT_CENTER, 700, 12, INK * Color(1, 1, 1, 0.76))
	draw_line(Vector2(viewport.x * 0.5 - 370, y + 8), Vector2(viewport.x * 0.5 + 370, y + 8), Color(0.95, 0.28, 0.08, 0.32), 1)


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
