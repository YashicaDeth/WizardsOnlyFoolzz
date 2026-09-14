class_name EyeGlare
extends ColorRect

## The red cross-glare on the eye in Greg's room photograph.
##
## Greg: *"can you make the eye on the left of the image glow and have a glare or
## bloom like lighting effect sublty in red in the bloom of a cross"*.
##
## Bloom is the right word for the halo; the cross is a **star filter** — the
## four-pointed streak a stopped-down lens throws off a small bright source. Two
## separate optical things, so the shader draws both rather than blurring one
## blob and hoping.
##
## Sits under `CrtGlass`, deliberately. The glare then picks up the same
## curvature, bloom and aberration as everything else in the frame, which is what
## keeps it from reading as a marker pasted on top of a photograph.

const GLARE_SHADER := preload("res://shaders/eye_glare.gdshader")

## Where the eye is, in screen UV.
##
## Derived from the source photograph, not from a rendered frame. The first cut
## triangulated the position against the 3D debris visible in Greg's own crop —
## which is wrong, because that debris is live physics and sits somewhere else in
## every frame, so the answer was different depending on which capture it was
## measured from. The eye itself is a fixed feature of `splash_room.png`: it is
## the painted eye in the poster art on the left wall, at photo pixel (664, 326)
## of 1920x1536. Mapped through `splash_attack.gdshader`'s own inset — a 1.25
## photo fitted by `photo_inset` on the short axis — that lands here.
const LEFT_EYE := Vector2(0.398, 0.230)

var clock := 0.0
var reveal := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	# Above the picture and the frame, below the glass — so the glass treats it.
	z_index = -8
	_material = ShaderMaterial.new()
	_material.shader = GLARE_SHADER
	_material.set_shader_parameter("at", LEFT_EYE)
	material = _material
	_push()


## Move it. Kept as a call rather than an exported position because the only
## thing that ever sets this is "Greg said left a bit".
func look_at_uv(uv: Vector2) -> void:
	if _material != null:
		_material.set_shader_parameter("at", uv)


func set_intensity(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("intensity", value)


func _process(delta: float) -> void:
	clock += delta
	_push()


func _push() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("clock", clock)
	_material.set_shader_parameter("reveal", reveal)


## Comes up last and slowest. A glare that fades in with the picture is part of
## the picture; one that arrives after it has settled reads as something in the
## photograph noticing you.
func play(into: Node, delay := 2.2) -> Tween:
	var tween := into.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(self, "reveal", 1.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween
