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
const VERTEBRAE := 12
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
	for index in range(seated, VERTEBRAE):
		var at := _spine_point(index) + Vector2(7, 2)
		boxes.append({"rect": Rect2(at - Vector2(16, 9), Vector2(32, 18)), "tag": "L%02d" % (index + 1), "ink": BLOOD.lightened(0.3)})
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


func _spine_point(index: int) -> Vector2:
	var top := _brain_centre() + Vector2(6, 38)
	var t := float(index) / float(VERTEBRAE - 1)
	var sway := sin(elapsed * 0.9 + t * 2.4) * (4.0 + t * 9.0)
	# A real column curves: a shallow S, not a plumb line.
	return top + Vector2(sway + sin(t * PI * 1.6) * 16.0, float(index) * 20.0)


func _draw_spine() -> void:
	var seated := intact_vertebrae()
	var lit := stamina / 100.0
	var cord := PackedVector2Array()
	for i in VERTEBRAE:
		cord.append(_spine_point(i))
	# The cord first, so the bone sits over it. Its glow runs down from the brain
	# as far as stamina reaches, with a pulse travelling along it.
	draw_polyline(cord, Color(0.2, 0.08, 0.06, 0.8), 3.0)
	var lit_count := int(round(lit * (VERTEBRAE - 1)))
	if lit_count > 0:
		var glow := cord.slice(0, lit_count + 1)
		draw_polyline(glow, COPPER * Color(1, 1, 1, 0.9), 2.0)
		var pulse_at := fposmod(elapsed * 1.6, 1.0) * float(lit_count)
		var i0 := int(pulse_at)
		if i0 < lit_count:
			draw_circle(cord[i0].lerp(cord[i0 + 1], pulse_at - float(i0)), 3.2, Color(1, 0.8, 0.5, 0.9))
	for i in VERTEBRAE:
		var at := cord[i]
		var width := 22.0 - float(i) * 0.7
		var loose := i >= seated
		var tone := BONE
		if loose:
			# A lost vertebra is still there as an outline, knocked out of line.
			at += Vector2(7.0 + sin(elapsed * 2.0 + i) * 2.0, 2.0)
			tone = BONE * Color(0.5, 0.45, 0.42, 0.35)
		# A vertebral body: waisted sides, flared end-plates, wings out to the
		# transverse processes and a spinous tip behind. Drawn as bone, not a box.
		var hw := width * 0.5
		var shape := PackedVector2Array([
			at + Vector2(-hw, -6), at + Vector2(-hw - 9, -3), at + Vector2(-hw - 10, 0),
			at + Vector2(-hw * 0.8, 1), at + Vector2(-hw, 6), at + Vector2(-3, 7),
			at + Vector2(0, 11), at + Vector2(3, 7), at + Vector2(hw, 6),
			at + Vector2(hw * 0.8, 1), at + Vector2(hw + 10, 0), at + Vector2(hw + 9, -3),
			at + Vector2(hw, -6), at + Vector2(0, -7.5),
		])
		if not loose:
			draw_colored_polygon(shape, BONE.darkened(0.18))
			draw_colored_polygon(PackedVector2Array([at + Vector2(-hw * 0.9, 1), at + Vector2(hw * 0.9, 1), at + Vector2(hw, 6), at + Vector2(-hw, 6)]), BONE.darkened(0.45))
			draw_circle(at + Vector2(0, -1), 2.4, BLOOD.lerp(Color(0.3, 0.02, 0.02), 1.0 - blood))
		var closed := shape.duplicate()
		closed.append(shape[0])
		draw_polyline(closed, Color(0.12, 0.05, 0.04, 0.9) if not loose else tone, 1.2)
	for drip in _drips:
		draw_line(drip, drip + Vector2(0, 7), BLOOD, 2.2)
		draw_circle(drip + Vector2(0, 7), 2.2, BLOOD)


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
