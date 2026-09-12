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
## Whoever the captain is this save. Set from the record by whoever drives
## this panel — the name is generated per save now (`cast_names.gd`), so a
## literal here would go stale the moment somebody started a new one.
var rival_name := "the captain"
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


## The space between a key and the verb it performs. `draw_condensed` returns
## a run's width without its trailing advance, so the cursor lands hard
## against the last glyph — at six pixels "LMB" and "STRIKE" printed as one
## word.
const KEY_GAP := 13.0
var lock_screen := Vector2(-1, -1)
## AD2.3. What the strip is currently allowed to offer. Set by whoever owns the
## player, because this panel has no business knowing how a cooldown works.
var bare := false
var firearm := false
var can_dodge := true
var near_something := false
var interact_verb := "act"
## 0 shows the strip in full, 1 hides it. It goes away because the player has
## plainly stopped needing it — the same rule the derby's dashboard placard
## uses — rather than after a timer somebody chose.
var familiar := 0.0


func set_state(values: Dictionary) -> void:
	health = float(values.get("health", health))
	stamina = float(values.get("stamina", stamina))
	rival_status = str(values.get("rival_status", rival_status)).to_upper()
	rival_name = str(values.get("rival_name", rival_name))
	location = str(values.get("location", location))
	if location != _location_seen:
		_location_seen = location
		location_announce = LOCATION_ANNOUNCE_TIME
	menu_open = bool(values.get("menu_open", menu_open))
	menu_mode = str(values.get("menu_mode", menu_mode)).to_upper()
	weapon = values.get("weapon", weapon)
	bare = bool(values.get("bare", bare))
	firearm = str((weapon as Dictionary).get("kind", "")) == "firearm"
	can_dodge = bool(values.get("can_dodge", can_dodge))
	near_something = bool(values.get("near_something", near_something))
	interact_verb = str(values.get("interact_verb", interact_verb))
	lock_screen = values.get("lock_screen", lock_screen)


func _process(delta: float) -> void:
	elapsed += delta
	# Familiarity is earned by playing, not by waiting: it only climbs while the
	# player is actually doing the things the strip is describing.
	if not menu_open:
		familiar = minf(1.0, familiar + delta * 0.0055)
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
	_draw_breath()
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
	var health_ratio := clampf(health / 100.0, 0, 1)
	# The strap: a worn cable, not a UI connector line — it sags and stitches
	# the same way the mouth's own edge does.
	var strap_start := origin + Vector2(58, 40)
	var strap_end := mouth_center + Vector2(-112, -8)
	var sag := 14 + sin(elapsed * 1.1) * 3
	var strap := PackedVector2Array([strap_start, strap_start.lerp(strap_end, 0.5) + Vector2(0, sag), strap_end])
	draw_polyline(strap, BONE * Color(1, 1, 1, 0.16), 3)
	for knot in 3:
		draw_circle(strap_start.lerp(strap_end, 0.22 + knot * 0.28) + Vector2(0, sag * sin(PI * (0.22 + knot * 0.28))), 2, COPPER * Color(1, 1, 1, 0.4))
	# AG4.5. The mark itself is the readout. The crown opens as the arc is
	# eaten away, the thorns snap off one at a time, and the pulse at the
	# centre goes quick and irregular — so how badly you are doing is read off
	# how wrecked your own sigil looks, not off a bar beside it.
	var heart := origin + Vector2(30, 31)
	# The crown: a closed arc at full, an open broken one as it goes.
	var span: float = lerpf(PI * 0.55, PI * 1.6, health_ratio)
	var middle := PI
	draw_arc(heart, 29, middle - span * 0.5, middle + span * 0.5, 30, BONE * Color(1, 1, 1, 0.22 + health_ratio * 0.42), 2)
	# Thorns. Four a side at full, and they break off as the body does — the
	# count is the readout and it is countable at a glance, which a bar is not.
	var thorns := int(round(health_ratio * 4.0))
	for side in [-1.0, 1.0]:
		for index in thorns:
			var lift := 13.0 - float(index) * 5.0
			var base := origin + Vector2(30 + side * (23.0 - float(index) * 4.0), lift)
			var wither: float = 1.0 - float(index) / 4.0
			draw_line(base, base + Vector2(side * 22.0 * wither, -16.0 * wither), COPPER, 2)
			draw_line(base + Vector2(side * 11, -8), base + Vector2(side * 18, 4), COPPER * Color(1, 1, 1, 0.55), 1)
	# The pulse. Slow and even when whole; fast, shallow and stumbling when not.
	var rate: float = lerpf(7.0, 2.0, health_ratio)
	var beat := sin(elapsed * rate)
	if health_ratio < 0.4:
		# A failing heart does not keep time. The second beat arrives early.
		beat = maxf(beat, sin(elapsed * rate * 1.7 + 1.1) * 0.8)
	draw_circle(heart, 7.0 + beat * (1.0 + (1.0 - health_ratio) * 2.4), BLOOD)
	if health_ratio < 0.25:
		draw_circle(heart, 13.0 + beat * 4.0, BLOOD * Color(1, 1, 1, 0.14))


## AG4.5. Breathing, rather than a meter of breath.
##
## The frame tightens and releases on a real cycle. Fresh, it is slow and you
## will not notice it. Spent, it is fast and shallow and the edges close in, and
## you know you are out of breath because the screen is. There is nothing to
## read, which is why it works while you are being attacked — the one moment a
## stamina bar is least useful.
func _draw_breath() -> void:
	var spent := 1.0 - clampf(stamina / 100.0, 0.0, 1.0)
	if spent < 0.12:
		return
	# Rate climbs and depth falls as you empty: hard breathing is fast and
	# shallow, not slow and deep.
	var rate: float = lerpf(1.1, 4.4, spent)
	var cycle := (sin(elapsed * rate) + 1.0) * 0.5
	var closed: float = spent * (0.55 + cycle * 0.45)
	# Four bands rather than a gradient: this is drawn every frame over the whole
	# screen and a real vignette here is not worth the fill rate.
	for band in 4:
		var inset: float = size.y * (0.30 - float(band) * 0.06) * (1.0 - closed * 0.55)
		var alpha: float = closed * 0.11 * (1.0 + float(band) * 0.5)
		draw_rect(Rect2(0, 0, size.x, inset * 0.5), Color(0.02, 0.01, 0.015, alpha))
		draw_rect(Rect2(0, size.y - inset * 0.5, size.x, inset * 0.5), Color(0.02, 0.01, 0.015, alpha))
	# And a catch at the top of each breath, so it reads as effort.
	if spent > 0.7 and cycle > 0.94:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.0, 0.0, (spent - 0.7) * 0.12))
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
	draw_string(font, anchor, "HUNT // %s" % rival_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COPPER)
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


## AD2.3. What you can do *right now* — not every key in the game.
##
## This was a fixed string in `ThemeDB.fallback_font`, and `bone_yard_hunt.gd`
## drew a second, different, longer one on top of it in the same font. Both are
## gone. What is left is built per frame from real state, set in the display
## face, and faded out once the player has stopped needing it.
##
## The rule for what belongs here: an affordance is listed when it would do
## something if pressed. A key that is on cooldown, a weapon you are not holding
## and a panel that is already open are not affordances.
func _draw_controls() -> void:
	if familiar >= 0.999:
		return
	var offers: Array = []
	var held := str((weapon as Dictionary).get("label", ""))
	if bare:
		offers.append(["LMB", "STRIKE"])
		offers.append(["X", "GUARD"])
	elif firearm:
		offers.append(["LMB", "FIRE"])
		if int((weapon as Dictionary).get("loaded", 1)) <= 0:
			offers.append(["R", "RELOAD"])
	else:
		offers.append(["LMB", held.to_upper() if held != "" else "STRIKE"])
		offers.append(["RMB", "HEAVY"])
		offers.append(["X", "GUARD"])
	if can_dodge:
		offers.append(["SPACE", "DODGE"])
	if near_something:
		offers.append(["E", str(interact_verb).to_upper()])
	offers.append(["G", "DEVICE"])

	# Laid out from the middle, so the strip grows symmetrically rather than
	# sliding sideways every time an affordance appears or goes.
	var gap := 26.0
	var total := 0.0
	for offer: Array in offers:
		total += CellOutzType.width_condensed(str(offer[0]), 11.0, 2.0) + KEY_GAP
		total += CellOutzType.width_condensed(str(offer[1]), 10.0, 1.6) + gap
	var cursor := size.x * 0.5 - total * 0.5
	var fade := 1.0 - familiar
	for offer: Array in offers:
		var key := str(offer[0])
		var verb := str(offer[1])
		cursor += CellOutzType.draw_condensed(self, Vector2(cursor, size.y - 26.0), key, 11.0, Color(COPPER, 0.92 * fade), 2.0) + KEY_GAP
		cursor += CellOutzType.draw_condensed(self, Vector2(cursor, size.y - 26.0), verb, 10.0, Color(BONE, 0.55 * fade), 1.6) + gap


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
