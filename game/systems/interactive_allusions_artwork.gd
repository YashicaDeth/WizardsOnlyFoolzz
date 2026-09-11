class_name InteractiveAllusionsArtwork
extends Control

const BONE := Color("ead4ad")
const COPPER := Color("e85d2b")
const TEAL := Color("35b7a7")
const BLOOD := Color("a81716")

var pointer := Vector2.ZERO
var layer := 0
var elapsed := 0.0
var touch_count := 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	pointer = size * 0.5


func open_artwork() -> void:
	visible = true
	WorldHistory.record_event("allusions_artwork_opened", {"work": "as_above_so_below_study_001"})
	queue_redraw()


func close_artwork() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = event.position
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		layer = (layer + 1) % 4
		touch_count += 1
		WorldHistory.record_event("allusions_artwork_touched", {"work": "as_above_so_below_study_001", "layer": layer, "touch": touch_count})
		queue_redraw()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("050207"))
	var center := size * 0.5
	var history_weight := clampf(float(WorldHistory.event_count()) / 120.0, 0.0, 1.0)
	var mara := WorldHistory.subject("mara_voss")
	var grudge := float(mara.get("grudge", 0)) / 100.0
	for ring in 18:
		var radius := 38.0 + ring * 19.0 + sin(elapsed * 0.7 + ring) * 5.0
		var color := TEAL if (ring + layer) % 3 == 0 else COPPER if ring % 2 == 0 else BLOOD
		var alpha := 0.08 + float(ring % 4) * 0.035 + history_weight * 0.08
		draw_arc(center, radius, elapsed * (0.03 + ring * 0.002), PI * (1.1 + grudge * 0.8), 64, color * Color(1, 1, 1, alpha), 1.0 + layer * 0.35)
	for branch in 42:
		var angle := TAU * branch / 42.0 + sin(elapsed * 0.13 + branch) * 0.06
		var inner := center + Vector2.from_angle(angle) * (52.0 + layer * 7.0)
		var pull := (pointer - center).normalized() * minf(pointer.distance_to(center) * 0.08, 55.0)
		var outer := center + Vector2.from_angle(angle + sin(branch * 2.7) * 0.18) * (235.0 + branch % 7 * 12.0) + pull
		draw_line(inner, outer, TEAL * Color(1, 1, 1, 0.12 + grudge * 0.13), 1)
	draw_circle(center, 37.0 + sin(elapsed * 2.0) * 4.0, BLOOD * Color(1, 1, 1, 0.45))
	draw_circle(center + (pointer - center).normalized() * 14.0, 9.0, BONE)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(42, 48), "ALLUSIONS TO GRANDEUR // INTERACTIVE STUDY 001", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, BONE)
	draw_string(font, Vector2(42, 72), "AS ABOVE, SO BELOW — HISTORY %03d / MARA GRUDGE %03d" % [WorldHistory.event_count(), roundi(grudge * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COPPER)
	draw_string(font, Vector2(42, size.y - 35), "MOVE: BEND THE IMAGE   CLICK: PEEL A LAYER   J: RETURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BONE * Color(1, 1, 1, 0.64))
