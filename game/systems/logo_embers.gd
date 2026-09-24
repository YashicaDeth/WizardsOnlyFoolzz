extends Control

## Embers rising off the logo (Greg, 24 September: more detail on the logo at
## the same strength). Laid over whatever logo it is a child of, full-rect:
## a few small hot sparks lift off the lower half of the mark, drift, flicker
## and cool from yellow to red to nothing. Capped, cheap, drawn in 2D.

const MAX_EMBERS := 42
const RATE := 14.0

## 0 stops new embers (existing ones finish); 1 is the full rate.
var amount := 1.0
var embers: Array[Dictionary] = []
var _spawn := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 4417


## The logo it sits on is resized by hand every frame, which anchors don't
## always follow; the parent's own size is the truth.
func area() -> Vector2:
	var parent := get_parent() as Control
	if parent != null and parent.size.length_squared() > 1.0:
		return parent.size
	return size


func step(delta: float) -> void:
	var box := area()
	_spawn += delta * RATE * amount
	while _spawn >= 1.0 and embers.size() < MAX_EMBERS:
		_spawn -= 1.0
		embers.append({
			"at": Vector2(_rng.randf_range(0.15, 0.85) * box.x, _rng.randf_range(0.35, 0.75) * box.y),
			"v": Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-70.0, -30.0)),
			"life": _rng.randf_range(1.2, 2.6),
			"age": 0.0,
			"size": _rng.randf_range(2.0, 4.2),
			"phase": _rng.randf() * TAU,
		})
	_spawn = minf(_spawn, 1.0)
	for ember in embers.duplicate():
		ember.age = float(ember.age) + delta
		var sway := sin(float(ember.age) * 3.0 + float(ember.phase)) * 14.0
		ember.at = (ember.at as Vector2) + ((ember.v as Vector2) + Vector2(sway, 0.0)) * delta
		if float(ember.age) >= float(ember.life):
			embers.erase(ember)
	queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void:
	for ember in embers:
		var t := float(ember.age) / float(ember.life)
		var flicker := 0.75 + 0.25 * sin(float(ember.age) * 23.0 + float(ember.phase))
		var hot := Color(1.0, 0.85, 0.35).lerp(Color(0.85, 0.15, 0.05), t)
		hot.a = (1.0 - t) * flicker
		var at: Vector2 = ember.at
		# A glow first, then a streak along its rise, then the hot core, so it
		# reads against the busy collage as well as against black.
		draw_circle(at, float(ember.size) * 3.2, Color(hot.r, hot.g * 0.5, hot.b * 0.3, hot.a * 0.28))
		draw_line(at, at - (ember.v as Vector2).normalized() * float(ember.size) * 4.0, Color(hot.r, hot.g, hot.b, hot.a * 0.6), float(ember.size) * 0.8, true)
		draw_circle(at, float(ember.size), hot)
		draw_circle(at, float(ember.size) * 0.45, Color(1.0, 0.97, 0.8, hot.a))
