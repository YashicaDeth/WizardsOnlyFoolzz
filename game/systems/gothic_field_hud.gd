extends Control

const CellOutzType := preload("res://systems/celloutz_type.gd")

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
## M1.6. The location crest was a permanent banner for information that only
## actually matters the moment it changes — I0.6 already killed the same
## fixture on the derby HUD for the identical reason ("a rival arrives when
## they change, not permanently"). This is the on-foot half of that same
## rule: the crest announces an arrival and then gets out of the way rather
## than sitting in the top corner for the rest of the session.
const LOCATION_ANNOUNCE_TIME := 4.0
var _location_seen := ""
var location_announce := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


var lock_screen := Vector2(-1, -1)


func set_state(values: Dictionary) -> void:
	health = float(values.get("health", health))
	stamina = float(values.get("stamina", stamina))
	rival_status = str(values.get("rival_status", rival_status)).to_upper()
	location = str(values.get("location", location))
	if location != _location_seen:
		_location_seen = location
		location_announce = LOCATION_ANNOUNCE_TIME
	menu_open = bool(values.get("menu_open", menu_open))
	menu_mode = str(values.get("menu_mode", menu_mode)).to_upper()
	weapon = values.get("weapon", weapon)
	lock_screen = values.get("lock_screen", lock_screen)


func _process(delta: float) -> void:
	elapsed += delta
	location_announce = maxf(0.0, location_announce - delta)
	queue_redraw()


func _draw() -> void:
	# A full-sheet panel — the chart, the dossier, the artwork — owns the screen.
	# Leaving the field furniture drawn over the top of it was the reason those
	# panels always looked like a debug overlay instead of a thing you opened.
	if menu_open:
		if menu_mode not in ["MAP", "TREE", "ARTWORK"]:
			_draw_full_archive_frame()
		return
	_draw_location_crest()
	_draw_hunt_thread()
	_draw_weapon()
	_draw_regal_vitals()
	_draw_lock_reticle()
	_draw_controls()


## M1.6. This used to be its own plate in the top-left corner — a second
## instrument with no relationship to anything else on screen, the exact
## "floating in the corner" the design rule names. It now hangs off the same
## rig as the weapon well: a strap runs from the vessel crown into the torn
## mouth, so the vitals read as a gauge built into the gear in your hand
## rather than an app widget checking in on you from outside the world.
func _draw_regal_vitals() -> void:
	var mouth_center := Vector2(size.x - 126.0, size.y - 94.0)
	var origin := mouth_center + Vector2(-540, -56)
	var font := ThemeDB.fallback_font
	var health_ratio := clampf(health / 100.0, 0, 1)
	var stamina_ratio := clampf(stamina / 100.0, 0, 1)
	# The strap: a worn cable, not a UI connector line — it sags and stitches
	# the same way the mouth's own edge does.
	var strap_start := origin + Vector2(58, 40)
	var strap_end := mouth_center + Vector2(-112, -8)
	var sag := 14 + sin(elapsed * 1.1) * 3
	var strap := PackedVector2Array([strap_start, strap_start.lerp(strap_end, 0.5) + Vector2(0, sag), strap_end])
	draw_polyline(strap, BONE * Color(1, 1, 1, 0.16), 3)
	for knot in 3:
		draw_circle(strap_start.lerp(strap_end, 0.22 + knot * 0.28) + Vector2(0, sag * sin(PI * (0.22 + knot * 0.28))), 2, COPPER * Color(1, 1, 1, 0.4))
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


## M1.6. Announces an arrival and then clears rather than sitting in the top
## corner permanently — the same reasoning I0.6 already applied to the derby's
## HUNT SIGNAL plate. Fades out over the last second of `location_announce`
## instead of cutting, per Rule 3.
func _draw_location_crest() -> void:
	if location_announce <= 0.0:
		return
	var alpha := clampf(location_announce, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var center := Vector2(size.x * 0.5, 42)
	draw_string(font, center + Vector2(-230, 0), "—  %s  —" % location, HORIZONTAL_ALIGNMENT_CENTER, 460, 16, BONE * Color(1, 1, 1, alpha))
	var pulse := 35 + sin(elapsed * 1.2) * 8
	draw_line(center + Vector2(-pulse, 15), center + Vector2(pulse, 15), COPPER * Color(1, 1, 1, 0.5 * alpha), 1)


## M1.6. Was a permanent top-right fixture regardless of whether there was
## anything to report — the same complaint I0.6 already answered for the
## derby's own version of this exact readout ("a rival arrives when they
## change, not permanently"). This is the on-foot half of that same rule:
## nothing is drawn while the hunt is dormant, so the plate only exists while
## it is actually true.
func _draw_hunt_thread() -> void:
	if rival_status == "DORMANT" or rival_status.is_empty():
		return
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
	var weapon_id := str(weapon.get("id", "sword"))
	var center := Vector2(size.x - 126.0, size.y - 94.0)
	# A torn leather recess rather than a fourth corner panel. Its contents are
	# objects: the held weapon, live cartridges and the loose reserve beneath it.
	var mouth := PackedVector2Array([
		center + Vector2(-112, -16), center + Vector2(-93, -54),
		center + Vector2(-22, -69), center + Vector2(63, -57),
		center + Vector2(108, -21), center + Vector2(99, 34),
		center + Vector2(41, 55), center + Vector2(-55, 51),
		center + Vector2(-103, 25), center + Vector2(-112, -16),
	])
	draw_colored_polygon(mouth, Color(0.025, 0.012, 0.009, 0.68))
	draw_polyline(mouth, BONE * Color(1, 1, 1, 0.13), 1.2)
	for stitch in 9:
		var angle := lerpf(PI * 1.08, PI * 1.92, float(stitch) / 8.0)
		var stitch_at := center + Vector2.from_angle(angle) * Vector2(104, 56)
		draw_line(stitch_at - Vector2(3, 1), stitch_at + Vector2(3, 1), COPPER * Color(1, 1, 1, 0.34), 1.0)

	_draw_weapon_silhouette(center + Vector2(28, -8), weapon_id)
	var loaded := int(weapon.get("loaded", -1))
	if loaded < 0:
		# The cleaver's state is its edge. Nicks replace the meaningless MELEE row.
		for nick in 4:
			var nick_at := center + Vector2(-58 + nick * 10, 17 + nick * 2)
			draw_line(nick_at, nick_at + Vector2(4, 5), BLOOD * Color(1, 1, 1, 0.65), 1.5)
		return

	var capacity := 5 if weapon_id == "shotgun" else 10
	var reloading := bool(weapon.get("reloading", false))
	var cartridge_tone := TEAL if reloading else COPPER
	# Chambers arc around the weapon. Empty chambers remain as punched holes, so
	# the player reads what is missing without parsing a fraction.
	for chamber in capacity:
		var angle := lerpf(PI * 0.80, PI * 1.64, float(chamber) / maxf(1.0, capacity - 1.0))
		var shell_at := center + Vector2.from_angle(angle) * Vector2(78, 43)
		_draw_cartridge(shell_at, angle + PI * 0.5, cartridge_tone, chamber < loaded, weapon_id == "shotgun")

	var reserve := int(weapon.get("reserve", 0))
	var pile_count := clampi(ceili(float(reserve) / (5.0 if weapon_id == "sidearm" else 3.0)), 0, 10)
	for loose in pile_count:
		var row := loose / 5
		var loose_at := center + Vector2(-42 + (loose % 5) * 10, 34 - row * 7)
		_draw_cartridge(loose_at, -0.18 + (loose % 3) * 0.12, BONE * Color(1, 1, 1, 0.58), true, weapon_id == "shotgun", 0.68)
	var reserve_mark := "×%02d" % reserve
	CellOutzType.draw_condensed(self, center + Vector2(17, 29), reserve_mark, 9.0, BONE * Color(1, 1, 1, 0.46), 0.8)
	if reloading:
		var reload_ratio := clampf(float(weapon.get("reload_ratio", 0.0)), 0.0, 1.0)
		var lift := center + Vector2(-18, 29).lerp(center + Vector2(-9, -19), 1.0 - reload_ratio)
		_draw_cartridge(lift, -0.2, TEAL, true, weapon_id == "shotgun")


func _draw_cartridge(at: Vector2, angle: float, tone: Color, live: bool, wide: bool, scale_factor := 1.0) -> void:
	var length := (15.0 if wide else 11.0) * scale_factor
	var width := (5.2 if wide else 3.5) * scale_factor
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	if not live:
		draw_circle(at, width * 0.55, BONE * Color(1, 1, 1, 0.10))
		draw_arc(at, width * 0.75, 0, TAU, 8, BONE * Color(1, 1, 1, 0.18), 1.0)
		return
	var points := PackedVector2Array([
		at - along * length * 0.5 - across * width,
		at + along * length * 0.36 - across * width,
		at + along * length * 0.5,
		at + along * length * 0.36 + across * width,
		at - along * length * 0.5 + across * width,
	])
	draw_colored_polygon(points, tone)
	draw_line(at - along * length * 0.35 - across * width, at - along * length * 0.35 + across * width, BONE * Color(1, 1, 1, 0.38), 1.0)


func _draw_weapon_silhouette(at: Vector2, weapon_id: String) -> void:
	var dark := Color(0.02, 0.012, 0.01, 0.94)
	match weapon_id:
		"shotgun":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-52, 8), at + Vector2(-39, -5), at + Vector2(27, -9), at + Vector2(51, -4), at + Vector2(52, 2), at + Vector2(-29, 7), at + Vector2(-42, 18)]), dark)
			draw_line(at + Vector2(-22, 5), at + Vector2(-12, 24), COPPER * Color(1, 1, 1, 0.58), 5.0)
			draw_line(at + Vector2(25, -6), at + Vector2(54, -3), BONE * Color(1, 1, 1, 0.44), 2.0)
		"sidearm":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-30, -10), at + Vector2(35, -10), at + Vector2(39, 1), at + Vector2(5, 6), at + Vector2(-2, 31), at + Vector2(-23, 28), at + Vector2(-17, 4), at + Vector2(-31, 1)]), dark)
			draw_line(at + Vector2(-25, -6), at + Vector2(31, -6), BONE * Color(1, 1, 1, 0.34), 2.0)
		_:
			var blade := PackedVector2Array([at + Vector2(-53, 18), at + Vector2(24, -29), at + Vector2(51, -34), at + Vector2(29, -10), at + Vector2(-46, 25)])
			draw_colored_polygon(blade, dark)
			draw_polyline(blade, BONE * Color(1, 1, 1, 0.36), 1.2)
			draw_line(at + Vector2(-44, 24), at + Vector2(-62, 39), COPPER, 7.0)


func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	var controls := "1—3 ARMS   LMB USE   RMB HEAVY   X GUARD   SPACE DODGE   E ACT   F EYE"
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


## The lock reticle. Without a mark on the target the camera change alone leaves
## the player guessing which of three bodies the swing is going to.
func _draw_lock_reticle() -> void:
	if menu_open or lock_screen.x < 0.0 or lock_screen.y < 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(elapsed * 4.0)
	var tint := Color("c81f16")
	var radius := 15.0 + pulse * 3.0
	for quadrant in 4:
		var angle := TAU * float(quadrant) / 4.0 + PI * 0.25 + elapsed * 0.35
		var at := lock_screen + Vector2.from_angle(angle) * radius
		var tangent := Vector2.from_angle(angle + PI * 0.5) * 5.0
		draw_line(at - tangent, at + tangent, tint, 2.0)
	draw_circle(lock_screen, 2.2, tint * Color(1, 1, 1, 0.6 + pulse * 0.4))
	draw_arc(lock_screen, radius + 7.0, 0.0, TAU, 26, tint * Color(1, 1, 1, 0.18), 1.0)
