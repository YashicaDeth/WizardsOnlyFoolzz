extends Control

const BONE := Color("ead4ad")
const BLOOD := Color("a81716")
const COPPER := Color("dc5827")
const TEAL := Color("278f87")
const VOID := Color(0.018, 0.008, 0.012, 0.88)
var health := 100.0
var stamina := 100.0
var rival_status := "DORMANT"
var location := "LIMBO // ASHBLOOM EXPANSE"
var menu_open := false
var menu_mode := ""
var weapon := {}
var elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(values: Dictionary) -> void:
	health = float(values.get("health", health))
	stamina = float(values.get("stamina", stamina))
	rival_status = str(values.get("rival_status", rival_status)).to_upper()
	menu_open = bool(values.get("menu_open", menu_open))
	menu_mode = str(values.get("menu_mode", menu_mode)).to_upper()
	weapon = values.get("weapon", weapon)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	_draw_regal_vitals()
	_draw_location_crest()
	_draw_hunt_thread()
	_draw_weapon()
	_draw_controls()
	if menu_open:
		_draw_full_archive_frame()


func _draw_regal_vitals() -> void:
	var origin := Vector2(42, 44)
	var font := ThemeDB.fallback_font
	var health_ratio := clampf(health / 100.0, 0, 1)
	var stamina_ratio := clampf(stamina / 100.0, 0, 1)
	# Crown and mirrored thorns make the meters read as an artefact, not app UI.
	draw_arc(origin + Vector2(30, 31), 29, PI * 0.2, PI * 1.8, 30, BONE * Color(1, 1, 1, 0.6), 2)
	for side in [-1.0, 1.0]:
		var base := origin + Vector2(30 + side * 23, 13)
		draw_line(base, base + Vector2(side * 22, -16), COPPER, 2)
		draw_line(base + Vector2(side * 11, -8), base + Vector2(side * 18, 4), COPPER * Color(1, 1, 1, 0.55), 1)
	draw_circle(origin + Vector2(30, 31), 7 + sin(elapsed * 2.0), BLOOD)
	draw_string(font, origin + Vector2(72, 15), "VESSEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BONE * Color(1, 1, 1, 0.55))
	_draw_filament(origin + Vector2(72, 28), 245, health_ratio, BLOOD)
	draw_string(font, origin + Vector2(72, 55), "BREATH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BONE * Color(1, 1, 1, 0.55))
	_draw_filament(origin + Vector2(72, 68), 190, stamina_ratio, TEAL)


func _draw_filament(start: Vector2, width: float, ratio: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 36
	for index in steps + 1:
		var t := float(index) / steps
		var y := sin(t * PI * 6 + elapsed * 1.5) * (1.3 + (1.0 - ratio) * 2.0)
		points.append(start + Vector2(width * t, y))
	draw_polyline(points, BONE * Color(1, 1, 1, 0.18), 5)
	var active_count := maxi(2, roundi((steps + 1) * ratio))
	draw_polyline(points.slice(0, active_count), color, 3)
	draw_circle(start + Vector2(width * ratio, sin(ratio * PI * 6 + elapsed * 1.5) * 2), 3, color)


func _draw_location_crest() -> void:
	var font := ThemeDB.fallback_font
	var center := Vector2(size.x * 0.5, 42)
	draw_string(font, center + Vector2(-230, 0), "—  %s  —" % location, HORIZONTAL_ALIGNMENT_CENTER, 460, 16, BONE)
	var pulse := 35 + sin(elapsed * 1.2) * 8
	draw_line(center + Vector2(-pulse, 15), center + Vector2(pulse, 15), COPPER * Color(1, 1, 1, 0.5), 1)


func _draw_hunt_thread() -> void:
	var font := ThemeDB.fallback_font
	var anchor := Vector2(size.x - 260, 48)
	var eye := anchor + Vector2(205, 12)
	draw_arc(eye, 16, 0, TAU, 24, COPPER * Color(1, 1, 1, 0.45), 2)
	draw_circle(eye, 4 + sin(elapsed * 3.1), BLOOD)
	draw_string(font, anchor, "HUNT // MARA VOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COPPER)
	draw_string(font, anchor + Vector2(0, 21), rival_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BONE * Color(1, 1, 1, 0.65))


func _draw_weapon() -> void:
	if weapon.is_empty():
		return
	var font := ThemeDB.fallback_font
	var at := Vector2(size.x - 292, size.y - 83)
	draw_line(at, at + Vector2(236, 0), BONE * Color(1, 1, 1, 0.18), 1)
	draw_string(font, at + Vector2(0, 20), str(weapon.get("label", "UNARMED")), HORIZONTAL_ALIGNMENT_LEFT, 200, 13, COPPER)
	if int(weapon.get("loaded", -1)) >= 0:
		var rounds := "%02d / %02d" % [int(weapon.loaded), int(weapon.reserve)]
		draw_string(font, at + Vector2(160, 20), rounds, HORIZONTAL_ALIGNMENT_RIGHT, 76, 13, BONE)
		for shell in int(weapon.get("loaded", 0)):
			draw_rect(Rect2(at + Vector2(shell * 13, 31), Vector2(8, 16)), COPPER if not bool(weapon.get("reloading", false)) else TEAL)
	else:
		draw_string(font, at + Vector2(0, 42), "MELEE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BONE * Color(1, 1, 1, 0.55))


func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	var controls := "1—3 ARMS   LMB USE   RMB HEAVY   R LOAD   SPACE DODGE   E ACT   F EYE"
	draw_string(font, Vector2(size.x * 0.5 - 370, size.y - 27), controls, HORIZONTAL_ALIGNMENT_CENTER, 740, 11, BONE * Color(1, 1, 1, 0.52))


func _draw_full_archive_frame() -> void:
	var center := size * 0.5
	var half := Vector2(340, 245)
	draw_rect(Rect2(center - half, half * 2), VOID)
	var corners := [center - half, center + Vector2(half.x, -half.y), center + half, center + Vector2(-half.x, half.y)]
	for index in 4:
		var corner: Vector2 = corners[index]
		var sx := 1.0 if index in [0, 3] else -1.0
		var sy := 1.0 if index in [0, 1] else -1.0
		draw_line(corner, corner + Vector2(sx * 72, 0), COPPER, 3)
		draw_line(corner, corner + Vector2(0, sy * 72), COPPER, 3)
		for knot in 3:
			draw_circle(corner + Vector2(sx * (18 + knot * 16), sy * 8), 2, TEAL)
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-220, -half.y + 35), "ARCHIVE // %s" % menu_mode, HORIZONTAL_ALIGNMENT_CENTER, 440, 18, BONE)
	# Living Tree veins behind the data page.
	var root := center + Vector2(0, half.y - 18)
	for branch in 11:
		var end := center + Vector2((branch - 5) * 52, -half.y + 62 + abs(branch - 5) * 13)
		draw_line(root, end, TEAL * Color(1, 1, 1, 0.08), 1)
