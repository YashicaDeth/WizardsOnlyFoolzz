class_name TransitionKit
extends CanvasLayer

## A full-screen wipe drawn by `transition_kit.gdshader`. `cover()` runs the
## screen from clear to fully covered; `reveal()` runs the same curve back, so
## whatever is underneath has changed by the time it opens. Interstitial uses
## it for every scene change; anything else that needs a hard seam hidden can
## own one too.

const STYLES := ["burn", "elevator", "scroll", "flesh", "crt"]
const COVER_SECONDS := 0.42
const REVEAL_SECONDS := 0.5

var style := 0
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		if _rect != null:
			_rect.material.set_shader_parameter("progress", progress)
			_rect.visible = progress > 0.0

var _rect: ColorRect


func _init() -> void:
	layer = 129
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "Wipe"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/transition_kit.gdshader")
	_rect.material = mat
	_rect.visible = false
	add_child(_rect)
	_rect.resized.connect(_sync_size)


func _sync_size() -> void:
	_rect.material.set_shader_parameter("rect_size", _rect.size)


## Picks a style by name or index; unknown names keep the current one.
func set_style(which: Variant) -> void:
	if which is int:
		style = posmod(which, STYLES.size())
	elif STYLES.has(str(which)):
		style = STYLES.find(str(which))
	_rect.material.set_shader_parameter("style", style)
	_rect.material.set_shader_parameter("seed", randf() * 10.0)


func style_name() -> String:
	return STYLES[style]


func cover(seconds: float = COVER_SECONDS) -> void:
	await _run(1.0, seconds, Tween.EASE_IN)


func reveal(seconds: float = REVEAL_SECONDS) -> void:
	await _run(0.0, seconds, Tween.EASE_OUT)


func _run(target: float, seconds: float, ease: Tween.EaseType) -> void:
	if seconds <= 0.0:
		progress = target
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "progress", target, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	await tween.finished
