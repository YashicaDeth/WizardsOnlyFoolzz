extends Control

## Blood under the menu item you're on (Greg, 24 September: menus to match
## the re-animated logo). It pours in under the hovered item from left to
## right, and a few drips run off it and fall. Moving to another item starts
## a fresh pour there; leaving lets it fade.

const POUR_SECONDS := 0.22
const DRIPS := 4

var target: Control
var pour := 0.0
var fade := 0.0
var drips: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 6661


func point_at(control: Control) -> void:
	if control == target and fade > 0.99:
		return
	target = control
	pour = 0.0
	fade = 1.0
	drips.clear()
	for index in DRIPS:
		drips.append({"x": _rng.randf_range(0.08, 0.92), "len": 0.0, "speed": _rng.randf_range(20.0, 55.0), "max": _rng.randf_range(8.0, 26.0)})


func release(control: Control) -> void:
	if control == target:
		target = null


func step(delta: float) -> void:
	pour = minf(1.0, pour + delta / POUR_SECONDS)
	if target == null:
		fade = maxf(0.0, fade - delta * 3.0)
	for drip in drips:
		if pour >= float(drip.x):
			drip.len = minf(float(drip.max), float(drip.len) + float(drip.speed) * delta)
	queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void:
	if fade <= 0.0 or drips.is_empty():
		return
	var shown := target if target != null else null
	if shown == null or not is_instance_valid(shown):
		return
	var rect := Rect2(shown.global_position - global_position, shown.size)
	var y := rect.end.y - 3.0
	var width := rect.size.x * ease(pour, 0.4)
	var blood := Color(0.62, 0.05, 0.03, 0.9 * fade)
	draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(width, 3.0)), blood)
	draw_rect(Rect2(Vector2(rect.position.x, y - 1.0), Vector2(width, 1.0)), Color(0.95, 0.3, 0.2, 0.5 * fade))
	for drip in drips:
		var x := rect.position.x + rect.size.x * float(drip.x)
		if x > rect.position.x + width:
			continue
		var length := float(drip.len)
		draw_line(Vector2(x, y + 2.0), Vector2(x, y + 2.0 + length), blood, 2.0)
		draw_circle(Vector2(x, y + 3.0 + length), 2.4, blood)
