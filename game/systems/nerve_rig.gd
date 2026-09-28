class_name NerveRig
extends Control

## The player's vitals as one piece of anatomy wired into the frame, not a set of
## bars. It replaces the mask-and-ampoules corner. Every mark reads the body:
##
##   vertebrae still seated  = health       nerve glow down the cord = stamina
##   brain flushing red      = pain         brain fading, halo       = consciousness
##   drip from the column    = blood loss   crack across the brain   = head wound
##   violet aura             = magick (only once a ritual made it real)
##
## Two CRTs hang on cable from the top edge: the heart trace and the brain trace.
## A rack under them holds the three pockets `carry.gd` actually allows.
## Driven by `GothicFieldHud.set_state()`, so it has no numbers of its own.
##
## A whole, untouched body recedes to IDLE_PRESENCE and comes straight back the
## moment anything it shows drops or changes (Greg, 2026-09-24).

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("ead4ad")
const BLOOD := Color("a81716")
const COPPER := Color("dc5827")
const TEAL := Color("278f87")
const PHOSPHOR := Color("6fe0c8")
const FLESH := Color("b98287")
const VIOLET := Color("7a55c9")
const VOID := Color(0.018, 0.008, 0.012, 0.88)
## Every vertebra a person has (Greg, 24 September: "33 vertebrae accurate"),
## the same count `AnatomyComponent.SPINE_VERTEBRAE` damages.
const VERTEBRAE := 33
const GUNMETAL := Color("3b4046")
const GUNMETAL_DEEP := Color("1b1f22")
const CHROME := Color("b9c2c8")
const MARROW := Color("5a1210")
## Replaced outright in chrome, until installed cybernetics say which: the
## atlas and axis under the skull port, and the thoracolumbar junction where
## a spine breaks.
const CHROME_SEGMENTS := [0, 1, 18, 19]
const FIBRES := 5
const POCKETS := 3
const IDLE_PRESENCE := 0.18
## Seconds a change keeps the rig fully lit before it may start to recede.
const ACTIVITY_HOLD := 2.5

var health := 100.0
var blood := 1.0
var stamina := 100.0
var pain := 0.0
var consciousness := 100.0
var magick_unlocked := false
var magick := 0.0
var head_damage := 0.0
var pockets: Array = []
var mood := "STEADY"
var elapsed := 0.0
var _drips: Array[Vector2] = []
var _drip_clock := 0.0
var presence := 1.0
var _activity := ACTIVITY_HOLD
var _last_reading := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_state(values: Dictionary) -> void:
	health = clampf(float(values.get("health", health)), 0.0, 100.0)
	blood = clampf(float(values.get("blood", blood)), 0.0, 1.0)
	stamina = clampf(float(values.get("stamina", stamina)), 0.0, 100.0)
	pain = clampf(float(values.get("pain", pain)), 0.0, 100.0)
	consciousness = clampf(float(values.get("consciousness", consciousness)), 0.0, 100.0)
	magick_unlocked = bool(values.get("magick_unlocked", magick_unlocked))
	magick = clampf(float(values.get("magick", magick)), 0.0, 1.0)
	var regions: Dictionary = values.get("wound_regions", {})
	head_damage = clampf(float(regions.get("head", head_damage)), 0.0, 1.0)
	pockets = values.get("pockets", pockets)
	mood = str(values.get("mood", mood))
	visible = not bool(values.get("menu_open", false))
	var reading := [health, blood, stamina, pain, consciousness, magick, filled_pockets()]
	if not _last_reading.is_empty():
		for i in reading.size():
			if absf(float(reading[i]) - float(_last_reading[i])) > 0.001:
				_activity = ACTIVITY_HOLD
				break
	_last_reading = reading


## How much the body is asking to be seen: any shortfall, scaled so a body at
## 60% of anything is already fully lit.
func need() -> float:
	var worst := maxf(maxf(1.0 - health / 100.0, 1.0 - stamina / 100.0), maxf(1.0 - blood, maxf(pain / 100.0, 1.0 - consciousness / 100.0)))
	return clampf(worst * 2.5, 0.0, 1.0)


## Comes up fast, goes down slowly, so a hit is never read through a faded rig.
func step_presence(delta: float) -> void:
	_activity = maxf(_activity - delta, 0.0)
	var target := 1.0 if _activity > 0.0 else lerpf(IDLE_PRESENCE, 1.0, need())
	presence = move_toward(presence, target, delta * (6.0 if target > presence else 0.8))
	self_modulate.a = presence


func intact_vertebrae() -> int:
	return int(ceil(health / 100.0 * VERTEBRAE - 0.001))


func filled_pockets() -> int:
	return mini(pockets.size(), POCKETS)


func _process(delta: float) -> void:
	elapsed += delta
	step_presence(delta)
	# Blood loss drips from the lowest seated vertebra; the rate is the loss.
	var loss := 1.0 - blood
	_drip_clock += delta * loss * 3.0
	if loss > 0.08 and _drip_clock > 1.0:
		_drip_clock = 0.0
		_drips.append(_spine_point(maxi(intact_vertebrae() - 1, 0)))
	for i in range(_drips.size() - 1, -1, -1):
		_drips[i].y += delta * 160.0
		if _drips[i].y > size.y:
			_drips.remove_at(i)
	queue_redraw()


func _draw() -> void:
	_draw_monitor(Vector2(size.x - 330.0, 0.0), 0.0, true)
	_draw_monitor(Vector2(size.x - 238.0, 0.0), 1.9, false)
	_draw_spine()
	_draw_brain()
	_draw_tracking()
	_draw_pockets()


# --- blob tracking on the body (item 4) ------------------------------------

## The TouchDesigner-style tracker, turned on yourself: a box on the brain when
## the mind is off normal, boxes on every vertebra you have lost, one on the
## bleed. Nothing is drawn while you are whole, so a healthy rig stays clean.
func _draw_tracking() -> void:
	var boxes: Array = []
	var mind_off := pain > 15.0 or consciousness < 90.0 or head_damage > 0.05
	if mind_off:
		var centre := _brain_centre()
		boxes.append({"rect": Rect2(centre - Vector2(52, 40), Vector2(104, 80)), "tag": "PAIN %02d  CONSC %02d" % [roundi(pain), roundi(consciousness)], "ink": TEAL.lightened(0.3) if pain < 60.0 else BLOOD.lightened(0.25)})
	var seated := intact_vertebrae()
	if seated < VERTEBRAE:
		# One box round the whole lost run, named by its real vertebrae.
		var first := _spine_point(seated) + Vector2(7, 0)
		var last := _spine_point(VERTEBRAE - 1) + Vector2(7, 4)
		var tag := "%s-%s LOST" % [layout()[seated].label, layout()[VERTEBRAE - 1].label]
		boxes.append({"rect": Rect2(first - Vector2(22, 8), Vector2(44, last.y - first.y + 16)), "tag": tag, "ink": BLOOD.lightened(0.3)})
	if blood < 0.9:
		var bleed := _spine_point(maxi(seated - 1, 0))
		boxes.append({"rect": Rect2(bleed + Vector2(-20, 10), Vector2(40, 34)), "tag": "BLEED %02d%%" % roundi(blood * 100.0), "ink": BLOOD.lightened(0.15)})
	var previous := Vector2.INF
	for box in boxes:
		var rect: Rect2 = box.rect
		var ink: Color = box.ink
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var sx := 1.0 if corner.x <= rect.get_center().x else -1.0
			var sy := 1.0 if corner.y <= rect.get_center().y else -1.0
			draw_line(corner, corner + Vector2(6.0 * sx, 0), ink, 1.2)
			draw_line(corner, corner + Vector2(0, 6.0 * sy), ink, 1.2)
		# Tags hang to the left, off the anatomy, where the screen edge is not.
		var tag := str(box.tag)
		var width := CellOutzType.width_condensed(tag, 7.0, 0.5)
		CellOutzType.draw_condensed(self, Vector2(rect.position.x - width - 6, rect.position.y + 2), tag, 7.0, ink, 0.5)
		if previous != Vector2.INF:
			draw_line(previous, rect.get_center(), ink * Color(1, 1, 1, 0.35), 1.0)
		previous = rect.get_center()


# --- the brain and the column -------------------------------------------------

func _brain_centre() -> Vector2:
	var slip := Vector2(sin(elapsed * 7.0), cos(elapsed * 5.3)) * head_damage * 3.0
	var throb := Vector2(sin(elapsed * 31.0), 0.0) * (pain / 100.0) * 1.6
	return Vector2(size.x - 92.0, 66.0) + slip + throb


## Where each vertebra sits, top down: its name, its height down the column
## from the atlas, its body's half-width, how far its housing reaches out to
## the transverse processes, and its region. Built once; a column of 33 real
## vertebrae is ~320 px, close to the old twelve at 20 px each.
static var _layout: Array = []


static func layout() -> Array:
	if not _layout.is_empty():
		return _layout
	var y := 0.0
	for i in VERTEBRAE:
		var entry := {}
		if i < 7:
			entry = {"label": "C%d" % (i + 1), "region": "cervical", "gap": 8.0, "hw": 5.5 + i * 0.45, "reach": 4.0}
		elif i < 19:
			entry = {"label": "T%d" % (i - 6), "region": "thoracic", "gap": 11.0, "hw": 8.0 + (i - 7) * 0.35, "reach": 7.0}
		elif i < 24:
			entry = {"label": "L%d" % (i - 18), "region": "lumbar", "gap": 14.0, "hw": 12.0 + (i - 19) * 0.5, "reach": 9.0}
		elif i < 29:
			# The sacrum: five fused into one plate, narrowing to its apex.
			entry = {"label": "S%d" % (i - 23), "region": "sacral", "gap": 8.0, "hw": 15.0 - (i - 24) * 2.2, "reach": 0.0}
		else:
			entry = {"label": "Co%d" % (i - 28), "region": "coccygeal", "gap": 5.0, "hw": 4.0 - (i - 29) * 0.7, "reach": 0.0}
		entry["y"] = y
		y += float(entry.gap)
		_layout.append(entry)
	return _layout


func _spine_point(index: int) -> Vector2:
	var top := _brain_centre() + Vector2(6, 40)
	var entries := layout()
	var entry: Dictionary = entries[clampi(index, 0, VERTEBRAE - 1)]
	var t := float(entry.y) / float(entries[VERTEBRAE - 1].y)
	var sway := sin(elapsed * 0.9 + t * 2.4) * (3.0 + t * 7.0)
	# The column's real curves, seen from behind as a lean: cervical and lumbar
	# one way, thoracic and sacral the other.
	return top + Vector2(sway + sin(t * TAU) * 9.0, float(entry.y))


## Greg, 24 September: the old column read as a copy of its Garden of Giants
## reference. It is now built, not grown: 33 vertebrae (7 cervical, 12
## thoracic, 5 lumbar, the fused sacrum and coccyx), each clamped in a
## machined gunmetal housing with its bone showing between the plates, a few
## replaced outright in chrome, wired housing to housing, with a fibre-optic
## bundle up the middle carrying the stamina light. CellOutz copper and teal
## on gunmetal. What each mark means has not changed.
func _draw_spine() -> void:
	var seated := intact_vertebrae()
	var entries := layout()
	var lit_count := int(round(stamina / 100.0 * float(VERTEBRAE - 1)))
	var points := PackedVector2Array()
	for i in VERTEBRAE:
		points.append(_spine_point(i))
	_draw_skull_port(points[0])
	_draw_cables(points, seated)
	var seam := BLOOD.lerp(Color(0.25, 0.02, 0.02), 1.0 - blood)
	for i in VERTEBRAE:
		var entry: Dictionary = entries[i]
		# Exposed tissue in the gap below each seated vertebra: disc, meat, wet.
		if i < seated - 1:
			var mid := points[i].lerp(points[i + 1], 0.5)
			var hw := float(entry.hw) * 0.8
			draw_line(mid - Vector2(hw, 0), mid + Vector2(hw, 0), MARROW, 2.4)
			draw_line(mid - Vector2(hw * 0.6, 0.6), mid + Vector2(hw * 0.5, 0.6), seam, 1.0)
		_draw_vertebra(i, points[i], i >= seated, i < lit_count)
	# The bundle runs down a channel cut through the middle of every housing,
	# over the bone, so its light is the brightest thing on the column.
	_draw_fibres(points, seated, lit_count)
	if seated < VERTEBRAE:
		_draw_break(points[maxi(seated - 1, 0)], seated, seam)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for drip in _drips:
		draw_line(drip, drip + Vector2(0, 7), BLOOD, 2.2)
		draw_circle(drip + Vector2(0, 7), 2.2, BLOOD)


## Where the column plugs into the skull: a bolted gunmetal plate at the stem.
func _draw_skull_port(atlas: Vector2) -> void:
	var plate := Rect2(atlas + Vector2(-9, -9), Vector2(18, 5))
	draw_rect(plate, GUNMETAL)
	draw_line(plate.position, plate.position + Vector2(plate.size.x, 0), CHROME * Color(1, 1, 1, 0.5), 1.0)
	draw_circle(plate.position + Vector2(2.5, 2.5), 1.2, COPPER)
	draw_circle(plate.end - Vector2(2.5, 2.5), 1.2, COPPER)


## Five strands down the middle, dark glass until stamina lights them from the
## top, each with its own packet of light travelling down.
func _draw_fibres(points: PackedVector2Array, seated: int, lit_count: int) -> void:
	var entries := layout()
	var reach := mini(seated, VERTEBRAE)
	if reach < 2:
		return
	var channel := points.slice(0, reach)
	draw_polyline(channel, GUNMETAL_DEEP, 5.0)
	for f in FIBRES:
		var spread := (float(f) - float(FIBRES - 1) * 0.5) / float(FIBRES - 1)
		var strand := PackedVector2Array()
		for i in reach:
			var twist := cos(float(entries[i].y) * 0.06 + float(f) * 1.3) * 0.35
			strand.append(points[i] + Vector2(spread * 2.2 + twist * 0.8, 0))
		draw_polyline(strand, TEAL.darkened(0.55), 0.8)
		var lit_to := mini(lit_count, reach - 1)
		if lit_to < 1:
			continue
		var lit := strand.slice(0, lit_to + 1)
		draw_polyline(lit, PHOSPHOR * Color(1, 1, 1, 0.12), 6.0)
		draw_polyline(lit, TEAL.lightened(0.35), 0.8)
		var along := fposmod(elapsed * (0.55 + 0.17 * f) + f * 0.37, 1.0) * float(lit_to)
		var i0 := int(along)
		if i0 < lit_to:
			var head := lit[i0].lerp(lit[i0 + 1], along - float(i0))
			draw_circle(head, 2.6, PHOSPHOR * Color(1, 1, 1, 0.35))
			draw_circle(head, 1.2, Color(0.9, 1.0, 0.97))


## Black cable looped housing to housing down alternate sides, sagging outward.
## A cable whose lower end has gone with its vertebra hangs torn and sparks.
func _draw_cables(points: PackedVector2Array, seated: int) -> void:
	var entries := layout()
	var i := 1
	var side := 1.0
	while i + 3 < 24:
		var a: Dictionary = entries[i]
		var b: Dictionary = entries[i + 3]
		var start := points[i] + Vector2(side * (float(a.hw) + float(a.reach) * 0.7), 0)
		var finish := points[i + 3] + Vector2(side * (float(b.hw) + float(b.reach) * 0.7), 0)
		if i >= seated:
			break
		var torn := i + 3 >= seated
		if torn:
			finish = start + Vector2(side * 6.0 + sin(elapsed * 2.1 + i) * 2.0, 20.0)
		var bow := start.lerp(finish, 0.5) + Vector2(side * (9.0 + sin(elapsed * 1.3 + i) * 1.5), 0)
		var cable := PackedVector2Array()
		for s in 9:
			var t := float(s) / 8.0
			cable.append(start.lerp(bow, t).lerp(bow.lerp(finish, t), t))
		draw_polyline(cable, Color("121416"), 2.0)
		draw_polyline(cable, COPPER * Color(1, 1, 1, 0.35), 0.7)
		if torn:
			_draw_frayed(finish, side)
		i += 3
		side = -side


func _draw_frayed(end: Vector2, side: float) -> void:
	for strand in 3:
		var tip := end + Vector2(side * (strand - 1) * 2.5, 3.0 + strand)
		draw_line(end, tip, COPPER, 0.8)
		if sin(elapsed * 23.0 + strand * 2.1 + end.y) > 0.6:
			draw_circle(tip, 1.6, Color(1.0, 0.85, 0.55, 0.9))


## One vertebra in its local frame. Seated: bone between two machined clamp
## plates bolted in copper, or all chrome where it has been replaced. Lost:
## the housing knocked out of line, cracked, the bone broken inside it.
func _draw_vertebra(index: int, at: Vector2, loose: bool, lit: bool) -> void:
	var entry: Dictionary = layout()[index]
	var hw := float(entry.hw)
	var hh := maxf(float(entry.gap) * 0.36, 1.6)
	var reach := float(entry.reach)
	var region := str(entry.region)
	var fade := 1.0
	var tilt := 0.0
	if loose:
		at += Vector2(4.0 + sin(elapsed * 2.0 + index) * 1.5, 1.5)
		tilt = sin(float(index) * 1.7) * 0.18
		fade = 0.28
	draw_set_transform(at, tilt, Vector2.ONE)
	var ink := Color(1, 1, 1, fade)
	var edge := GUNMETAL_DEEP * Color(1, 1, 1, 0.95 * fade)
	var body := PackedVector2Array([
		Vector2(-hw * 0.55, -hh), Vector2(hw * 0.55, -hh), Vector2(hw * 0.7, -hh * 0.3),
		Vector2(hw * 0.55, hh), Vector2(-hw * 0.55, hh), Vector2(-hw * 0.7, -hh * 0.3),
	])
	if region == "sacral" or region == "coccygeal":
		# Fused bone, braced: a plate across its back, foramina either side.
		draw_colored_polygon(body, BONE.darkened(0.2) * ink)
		if region == "sacral":
			draw_rect(Rect2(Vector2(-hw * 0.3, -hh), Vector2(hw * 0.6, hh * 2.0)), GUNMETAL * ink)
			draw_circle(Vector2(-hw * 0.5, 0), 1.3, MARROW * ink)
			draw_circle(Vector2(hw * 0.5, 0), 1.3, MARROW * ink)
		_close(body, edge)
	elif index in CHROME_SEGMENTS:
		var shell := PackedVector2Array([
			Vector2(-hw - reach * 0.6, -hh * 0.7), Vector2(-hw * 0.6, -hh), Vector2(hw * 0.6, -hh),
			Vector2(hw + reach * 0.6, -hh * 0.7), Vector2(hw + reach * 0.6, hh * 0.5), Vector2(hw * 0.6, hh),
			Vector2(0, hh + 2.5), Vector2(-hw * 0.6, hh), Vector2(-hw - reach * 0.6, hh * 0.5),
		])
		draw_colored_polygon(shell, CHROME.darkened(0.35) * ink)
		draw_colored_polygon(PackedVector2Array([shell[0], shell[1], shell[2], shell[3], Vector2(hw, -hh * 0.2), Vector2(-hw, -hh * 0.2)]), CHROME * ink)
		draw_line(Vector2(-hw * 0.8, hh * 0.35), Vector2(hw * 0.8, hh * 0.35), GUNMETAL_DEEP * Color(1, 1, 1, 0.6 * fade), 0.8)
		_close(shell, edge)
	else:
		# Bone in the middle, with its spinous tip behind.
		draw_colored_polygon(body, BONE.darkened(0.12) * ink)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, hh * 0.5), Vector2(2, hh * 0.5), Vector2(0, hh + 3.0)]), BONE.darkened(0.3) * ink)
		if region == "thoracic":
			# Rib heads leaving the housing, cut short.
			draw_line(Vector2(-hw - reach, 0), Vector2(-hw - reach - 5, 3), BONE.darkened(0.25) * ink, 1.4)
			draw_line(Vector2(hw + reach, 0), Vector2(hw + reach + 5, 3), BONE.darkened(0.25) * ink, 1.4)
		for side in [-1.0, 1.0]:
			var inner := hw * 0.45
			var plate := PackedVector2Array([
				Vector2(side * inner, -hh - 0.8), Vector2(side * (hw + reach), -hh * 0.55),
				Vector2(side * (hw + reach), hh * 0.35), Vector2(side * inner, hh + 0.8),
			])
			draw_colored_polygon(plate, GUNMETAL * ink)
			draw_line(plate[0], plate[1], CHROME * Color(1, 1, 1, 0.45 * fade), 0.8)
			_close(plate, edge)
			draw_circle(Vector2(side * (hw + reach - 2.0), -hh * 0.1), 1.1, COPPER * ink)
		_close(body, edge * Color(1, 1, 1, 0.6))
	if loose:
		# The crack through the housing, and the bone split inside it.
		draw_line(Vector2(-hw * 0.3, -hh), Vector2(hw * 0.1, hh), BLOOD * Color(1, 1, 1, 0.8), 1.2)
	else:
		# Its status light: teal where the bundle is carrying, dark where not.
		draw_circle(Vector2(0, -hh * 0.15), 1.1, TEAL.lightened(0.3) if lit else GUNMETAL_DEEP)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _close(shape: PackedVector2Array, color: Color) -> void:
	var closed := shape.duplicate()
	closed.append(shape[0])
	draw_polyline(closed, color, 1.0)


## Where the column ends early: the fibres torn out of the last housing,
## splayed and sparking, over a ragged wet wound.
func _draw_break(last: Vector2, seated: int, seam: Color) -> void:
	var hw := float(layout()[maxi(seated - 1, 0)].hw)
	var base := last + Vector2(0, 5)
	# Ragged meat as overlapping blobs, not a polygon: a wavy outline at this
	# size is too thin for the triangulator and would vanish on some frames.
	for step in 7:
		var t := float(step) / 6.0
		var at := base + Vector2(lerpf(-hw, hw, t) * 0.8, 1.5 + sin(t * 11.0 + float(seated)) * 1.5)
		draw_circle(at, 2.2 + fposmod(t * 7.3, 1.0) * 1.6, MARROW)
	for step in 5:
		var t := float(step) / 4.0
		draw_circle(base + Vector2(lerpf(-hw, hw, t) * 0.7, 3.0 + sin(t * 9.0) * 1.0), 1.0, seam)
	draw_line(base + Vector2(-hw * 0.2, 0), base + Vector2(-hw * 0.35, 8), BONE, 1.6)
	for f in FIBRES:
		var spread := (float(f) - float(FIBRES - 1) * 0.5) * 2.2
		var tip := base + Vector2(spread * 1.6, 9.0 + float(f % 2) * 4.0)
		draw_line(base + Vector2(spread * 0.5, 0), tip, TEAL.darkened(0.2), 0.8)
		if sin(elapsed * 19.0 + f * 1.9) > 0.5:
			draw_circle(tip, 1.6, PHOSPHOR if f % 2 == 0 else Color(1.0, 0.8, 0.5))


func _draw_brain() -> void:
	var centre := _brain_centre()
	var awake := 0.35 + 0.65 * (consciousness / 100.0)
	var hurt := pain / 100.0
	var tint := FLESH.lerp(Color("d4262a"), hurt * (0.6 + 0.4 * sin(elapsed * 9.0)))
	if magick_unlocked and magick > 0.02:
		for ring in 3:
			var r := 46.0 + ring * 7.0 + sin(elapsed * 2.0 + ring) * 3.0
			draw_arc(centre, r, 0, TAU, 40, VIOLET * Color(1, 1, 1, magick * 0.28 / (ring + 1)), 3.0)
	if consciousness < 50.0:
		var flick := 0.5 + 0.5 * sin(elapsed * 17.0)
		draw_arc(centre, 50.0, 0, TAU, 40, BONE * Color(1, 1, 1, (1.0 - consciousness / 50.0) * 0.35 * flick), 1.5)
	# Cerebellum and stem behind the cortex.
	draw_circle(centre + Vector2(16, 26), 13.0, (tint.darkened(0.25)) * Color(1, 1, 1, awake))
	draw_line(centre + Vector2(6, 26), centre + Vector2(6, 40), tint.darkened(0.3) * Color(1, 1, 1, awake), 7.0)
	var outline := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		var r := 36.0 * (1.0 + 0.05 * sin(a * 5.0) + 0.035 * sin(a * 9.0 + 1.0))
		outline.append(centre + Vector2(cos(a) * r * 1.18, sin(a) * r * 0.86))
	draw_colored_polygon(outline, tint * Color(1, 1, 1, awake))
	draw_polyline(outline, BONE * Color(1, 1, 1, 0.55 * awake), 1.4)
	# Gyri: short curling folds, fixed per fold so they do not shimmer.
	for fold in 11:
		var seed_a := float(fold) * 2.39996
		var at := centre + Vector2(cos(seed_a) * 24.0 * fmod(float(fold) * 0.37, 1.0) * 1.3, sin(seed_a) * 18.0 * fmod(float(fold) * 0.61, 1.0))
		draw_arc(at, 7.0 + fold % 3 * 2.0, seed_a, seed_a + PI * 1.2, 8, tint.darkened(0.45) * Color(1, 1, 1, awake), 1.6)
	# The longitudinal fissure.
	draw_line(centre + Vector2(-2, -30), centre + Vector2(3, 28), tint.darkened(0.55) * Color(1, 1, 1, awake), 1.6)
	if head_damage > 0.05:
		var crack := PackedVector2Array([centre + Vector2(-30, -14), centre + Vector2(-9, -3), centre + Vector2(-2, 12) + Vector2(head_damage * 20, head_damage * 8)])
		draw_polyline(crack, Color(0.05, 0.0, 0.0, 0.9), 2.0 + head_damage * 2.0)
	var width := CellOutzType.width_condensed(mood, 10.0, 0.9)
	var mood_tone := BLOOD if mood in ["HURTING", "AGONY", "CHOKING"] else (COPPER if mood in ["WINDED", "FADING"] else TEAL)
	CellOutzType.draw_condensed(self, centre + Vector2(-width - 58, -8), mood, 10.0, mood_tone, 0.9)


# --- hanging CRTs ---------------------------------------------------------------

func _draw_monitor(anchor: Vector2, phase: float, heart: bool) -> void:
	var cable := 58.0 + phase * 14.0
	var swing := sin(elapsed * 1.25 + phase) * (0.045 + head_damage * 0.12)
	var hang := anchor + Vector2(0, cable).rotated(swing)
	draw_line(anchor, hang, Color(0.08, 0.06, 0.06, 0.95), 2.0)
	draw_line(anchor + Vector2(3, 0), hang + Vector2(3, 0), COPPER * Color(1, 1, 1, 0.3), 1.0)
	draw_set_transform(hang, swing, Vector2.ONE)
	var box := Rect2(Vector2(-38, 0), Vector2(76, 58))
	draw_rect(box, Color("2a2626"))
	draw_rect(box, BONE * Color(1, 1, 1, 0.35), false, 1.2)
	draw_rect(Rect2(box.position + Vector2(20, -5), Vector2(36, 6)), Color("1a1717"))
	var screen := Rect2(Vector2(-31, 7), Vector2(62, 42))
	draw_rect(screen, Color(0.01, 0.05, 0.045))
	var trace := PackedVector2Array()
	var steps := 40
	for s in steps + 1:
		var x := float(s) / float(steps)
		var y := 0.0
		if heart:
			var rate := lerpf(1.0, 2.8, 1.0 - health / 100.0) + pain * 0.012
			var ph := fposmod(x * 1.6 - elapsed * rate * 0.5, 1.0)
			y = (-1.0 if ph < 0.04 else (0.55 if ph < 0.08 else 0.0)) * (0.4 + health / 170.0)
			y += 0.12 * sin(ph * TAU)
		else:
			var calm := consciousness / 100.0
			y = sin(x * 14.0 + elapsed * 5.0) * 0.25 * calm + sin(x * 37.0 - elapsed * 9.0) * 0.18 * (1.0 - calm)
			y += (fposmod(sin(x * 91.7 + floor(elapsed * 20.0)) * 43758.5, 1.0) - 0.5) * 0.5 * (1.0 - calm)
		trace.append(screen.position + Vector2(x * screen.size.x, screen.size.y * 0.5 + y * screen.size.y * 0.42))
	var colour := PHOSPHOR if not (heart and health < 35.0) else Color("ff5a4a")
	draw_polyline(trace, colour * Color(1, 1, 1, 0.35), 3.5)
	draw_polyline(trace, colour, 1.3)
	for line in range(0, int(screen.size.y), 3):
		draw_line(screen.position + Vector2(0, line), screen.position + Vector2(screen.size.x, line), Color(0, 0, 0, 0.18), 1.0)
	if head_damage > 0.08:
		var tear := screen.position.y + fposmod(elapsed * 40.0 + phase * 13.0, screen.size.y)
		draw_rect(Rect2(screen.position.x, tear, screen.size.x, 2.0 + head_damage * 5.0), Color(0.8, 0.9, 0.9, 0.35 * head_damage))
	CellOutzType.draw_condensed(self, Vector2(-31, 50), "HRT" if heart else "EEG", 6.0, BONE * Color(1, 1, 1, 0.6), 0.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- the pocket rack -------------------------------------------------------------

func _draw_pockets() -> void:
	# Left of the held-object reliquary (bottom-right) and above the control
	# strip: the first in-scene capture put the rack on top of the reliquary.
	var origin := Vector2(size.x - 400.0, size.y - 172.0)
	draw_line(origin + Vector2(-8, 52), origin + Vector2(POCKETS * 34.0 + 2, 52), BONE * Color(1, 1, 1, 0.4), 2.0)
	for i in POCKETS:
		var at := origin + Vector2(i * 34.0, 0)
		var bottle := Rect2(at + Vector2(0, 10), Vector2(24, 42))
		var item: Dictionary = pockets[i] if i < pockets.size() and pockets[i] is Dictionary else {}
		draw_rect(bottle, Color(0.03, 0.04, 0.04, 0.6))
		if not item.is_empty():
			var kind := str(item.get("kind", ""))
			var fill := VIOLET if kind in ["substance", "smokeable", "drug"] else (BLOOD if kind in ["organ", "limb", "chunk", "meat"] else BONE.darkened(0.3))
			draw_rect(Rect2(bottle.position + Vector2(2, 12), bottle.size - Vector2(4, 14)), fill * Color(1, 1, 1, 0.85))
			var label := str(item.get("label", item.get("item_id", "?"))).to_upper().left(5)
			CellOutzType.draw_condensed(self, bottle.position + Vector2(-2, bottle.size.y + 6), label, 6.5, BONE * Color(1, 1, 1, 0.75), 0.4)
		draw_rect(bottle, BONE * Color(1, 1, 1, 0.45 if not item.is_empty() else 0.18), false, 1.2)
		draw_rect(Rect2(at + Vector2(3, 2), Vector2(18, 8)), COPPER * Color(1, 1, 1, 0.8 if not item.is_empty() else 0.25))
		draw_line(bottle.position + Vector2(5, 4), bottle.position + Vector2(5, bottle.size.y - 4), Color(1, 1, 1, 0.12), 1.0)
