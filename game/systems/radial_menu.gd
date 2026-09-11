class_name RadialMenu
extends Control

## Hold, sweep, release. The selection grammar for everything the player picks.
##
## C2. Greg's note was Prototype and GTA: a wheel that slows time so choosing a
## weapon never breaks out to a menu — *"seamless slow down of time to get
## weapons but still keeping soulslike difficulties"*. Those two halves pull
## against each other and the second one is the constraint that shapes this.
##
## **The honest answer to C2.4.** A wheel that slows the world but not you is a
## reaction advantage, and a game that hands you one on a button is not the
## difficulty target Greg named. So the dilation slows *everything, including
## the player*: it buys reading time, not reflexes. You cannot open the wheel to
## dodge. On top of that it runs off a budget that drains while held and refills
## slowly, so it cannot be leaned on. The fight stays exactly as hard; only the
## menu stops interrupting it.
##
## This is `xray_cursor.gd` grown up rather than replaced — that file was built
## deliberately as "one segment of a ring that will hold more", and the X-ray
## still lives on the wheel as a permanent segment.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const Motion := preload("res://systems/celloutz_motion.gd")

signal chosen(item: Dictionary)

const INK := Color("e6d4ac")
const COPPER := Color("b0552a")
const HOT := Color("a8281a")
const MOSS := Color("8a9a4a")
const BRASS := Color("b0552a")
const SOOT := Color(0.05, 0.036, 0.028, 0.90)

const INNER := 54.0
const OUTER := 132.0
## How slow the world runs while the wheel is up. Not zero: a paused world is a
## menu with extra steps, and the risk of standing still is the whole point.
const DILATION := 0.28
## Seconds of wheel time available, and how long a full refill takes. The budget
## is what stops the dilation becoming a free action.
const BUDGET := 2.4
const REFILL := 9.0

var items: Array = []
var is_open := false
var blend := 0.0
var highlighted := -1
var budget := BUDGET
var elapsed := 0.0
var centre := Vector2.ZERO
var pointer := Vector2.ZERO
var xray_on := false

var _committed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(true)


## `list` is [{id, label, kind, note}] — kind drives the drawn icon. The X-ray
## segment is appended by the caller like any other, so the wheel has no special
## case for it.
func open_wheel(list: Array) -> void:
	if budget <= 0.15:
		return
	items = list
	is_open = true
	visible = true
	_committed = false
	highlighted = -1
	centre = get_viewport_rect().size * 0.5
	pointer = centre


## Releasing commits whatever is under the pointer. Releasing on nothing is a
## deliberate cancel rather than an accident, which is why the dead zone in the
## middle is large.
func close_wheel() -> void:
	if is_open and not _committed and highlighted >= 0 and highlighted < items.size():
		_committed = true
		chosen.emit(items[highlighted])
	is_open = false


func _process(delta: float) -> void:
	elapsed += delta
	# Budget is spent in real time, not dilated time, or the wheel would pay for
	# itself with its own slowdown.
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	if is_open:
		budget = maxf(0.0, budget - real_delta)
		if budget <= 0.0:
			close_wheel()
	else:
		budget = minf(BUDGET, budget + real_delta * (BUDGET / REFILL))
	blend = Motion.blend(blend, real_delta, 7.0, is_open)
	# Seamless in and out per C2.3: the world eases into and out of the
	# dilation rather than snapping, so it reads as the moment stretching.
	var target := lerpf(1.0, DILATION, Motion.ease_out(blend))
	Engine.time_scale = target
	if blend <= 0.001 and not is_open:
		Engine.time_scale = 1.0
		visible = false
		return
	if is_open:
		pointer = get_global_mouse_position()
		_resolve_highlight()
	queue_redraw()


func _resolve_highlight() -> void:
	var offset := pointer - centre
	if offset.length() < INNER * 0.75 or items.is_empty():
		highlighted = -1
		return
	var step := TAU / float(items.size())
	# Segment 0 is centred at the top, which is where the eye goes first.
	var angle := fposmod(offset.angle() + PI * 0.5 + step * 0.5, TAU)
	highlighted = clampi(int(angle / step), 0, items.size() - 1)


func _draw() -> void:
	if blend <= 0.001 or items.is_empty():
		return
	var eased := Motion.ease_out(blend)
	var alpha := eased
	var inner := INNER * eased
	var outer := lerpf(INNER, OUTER, eased)
	var step := TAU / float(items.size())

	for index in items.size():
		var item: Dictionary = items[index]
		var mid := -PI * 0.5 + step * float(index)
		var from := mid - step * 0.5
		var to := mid + step * 0.5
		var active := index == highlighted
		var tint: Color = COPPER if active else INK * Color(1, 1, 1, 0.45)
		if str(item.get("id", "")) == "xray" and xray_on:
			tint = HOT

		# The segment ground, drawn as a ring wedge so the wheel is a made
		# object rather than a set of floating labels.
		var wedge := PackedVector2Array()
		var arc_steps := 10
		for point in arc_steps + 1:
			var angle := lerpf(from, to, float(point) / float(arc_steps))
			wedge.append(centre + Vector2(cos(angle), sin(angle)) * outer)
		for point in arc_steps + 1:
			var angle := lerpf(to, from, float(point) / float(arc_steps))
			wedge.append(centre + Vector2(cos(angle), sin(angle)) * inner)
		draw_colored_polygon(wedge, (COPPER * Color(1, 1, 1, 0.22) if active else SOOT) * Color(1, 1, 1, alpha))
		var edge := wedge.duplicate()
		edge.append(wedge[0])
		draw_polyline(edge, tint * Color(1, 1, 1, alpha * 0.9), 1.6 if active else 1.0)

		var seat := centre + Vector2(cos(mid), sin(mid)) * (inner + outer) * 0.5
		_draw_icon(seat, str(item.get("kind", "mode")), tint * Color(1, 1, 1, alpha), active)
		var label := str(item.get("label", "")).to_upper()
		var label_width := CellOutzType.width_condensed(label, 9.0, 0.8)
		CellOutzType.draw_condensed(self, seat + Vector2(-label_width * 0.5, 20.0), label, 9.0, (INK if active else INK * Color(1, 1, 1, 0.5)) * Color(1, 1, 1, alpha), 0.8)

	# C2.5. The cursor at the centre: a brass reticle, the same family as the
	# X-ray cursor it grew out of.
	draw_arc(centre, inner * 0.62, 0, TAU, 28, BRASS * Color(1, 1, 1, 0.55 * alpha), 1.4)
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(centre + axis * 6.0, centre + axis * 13.0, INK * Color(1, 1, 1, 0.7 * alpha), 1.4)
	draw_circle(centre, 2.0, HOT * Color(1, 1, 1, alpha))

	# The budget, drawn as the ring that is being spent. This is the piece that
	# keeps C2.4 honest and it has to be visible while it drains.
	var spent := clampf(budget / BUDGET, 0.0, 1.0)
	draw_arc(centre, outer + 10.0, -PI * 0.5, -PI * 0.5 + TAU * spent, 48, MOSS * Color(1, 1, 1, 0.55 * alpha), 3.0)
	if highlighted >= 0:
		var note := str((items[highlighted] as Dictionary).get("note", ""))
		if note != "":
			var note_width := CellOutzType.width_condensed(note.to_upper(), 10.0, 0.9)
			CellOutzType.draw_condensed(self, centre + Vector2(-note_width * 0.5, outer + 30.0), note.to_upper(), 10.0, INK * Color(1, 1, 1, 0.6 * alpha), 0.9)


## Icons are drawn rather than textured for the same reason the type is: no
## asset to author or licence, and they can carry state.
func _draw_icon(at: Vector2, kind: String, tint: Color, active: bool) -> void:
	var scale := 1.15 if active else 1.0
	match kind:
		"blade":
			draw_line(at + Vector2(-7, 8) * scale, at + Vector2(5, -9) * scale, tint, 2.4)
			draw_line(at + Vector2(-9, 6) * scale, at + Vector2(-4, 10) * scale, tint, 2.0)
		"gun":
			draw_rect(Rect2(at + Vector2(-10, -4) * scale, Vector2(17, 6) * scale), tint)
			draw_rect(Rect2(at + Vector2(-6, 2) * scale, Vector2(5, 8) * scale), tint)
		"implant":
			draw_rect(Rect2(at + Vector2(-6, -8) * scale, Vector2(12, 16) * scale), tint, false, 1.8)
			draw_line(at + Vector2(-10, -3) * scale, at + Vector2(-6, -3) * scale, tint, 1.6)
			draw_line(at + Vector2(6, 3) * scale, at + Vector2(10, 3) * scale, tint, 1.6)
		"seal":
			draw_arc(at, 9.0 * scale, 0, TAU, 20, tint, 1.6)
			draw_polyline(PackedVector2Array([
				at + Vector2(0, -9) * scale, at + Vector2(8, 5) * scale, at + Vector2(-8, 5) * scale, at + Vector2(0, -9) * scale,
			]), tint, 1.4)
		"xray":
			draw_circle(at + Vector2(0, -2) * scale, 5.0 * scale, tint)
			draw_rect(Rect2(at + Vector2(-3, 3) * scale, Vector2(6, 3) * scale), tint)
		_:
			draw_arc(at, 8.0 * scale, 0, TAU, 18, tint, 1.6)
			draw_circle(at, 2.4 * scale, tint)
