class_name CrtGlass
extends ColorRect

## The curved glass the cold open is seen through.
##
## Greg: *"curving on the screen to make a alien futuristic hud but still
## playabile and seamless"*, and *"2 images switching with slow degradation of
## crt distrortion through like stop mootiuion or moition effects"*.
##
## He has a CRT plugin for After Effects and one for TouchDesigner and said so
## in the same breath. This is live anyway, for the same reason the invert is
## live rather than baked: the curvature fits the window it is actually running
## in, the degradation is a **dial** something else can drive rather than a
## fixed timeline, and it keeps working when the picture underneath changes.
##
## The whole design is pinned by the second half of his own sentence — "still
## playabile and seamless". A faithful CRT geometry bends straight lines about
## 8% and eats the corners; that is wonderful over a photograph and hostile over
## a menu you are trying to read. So this is built to be **added to the backdrop
## layer, under the readable layer**, not over the whole screen. The picture
## curves; the words on top of it do not. That is the compromise that makes the
## effect shippable rather than a thing that gets turned off in settings.
##
## A sibling node again, like `RegalFrame`: several agents are in the cold open,
## and a pass that composites on top of whatever is beneath cannot collide with
## any of them.

const GLASS_SHADER := preload("res://shaders/crt_glass.gdshader")

## Registers, not levels. The difference between these is what the glass is
## *for* in that moment, not how much of it there is.
const VARIANTS := {
	# The default. Reads as a good tube in a dark room: you can see it is a
	# screen, nothing bends enough to argue with.
	"panel": {"degrade": 0.30, "curvature": 0.055, "scanline_depth": 0.16, "mask_depth": 0.10, "roll": 0.30, "bloom": 0.22},
	# Greg's "alien futuristic hud" end. More bow, more glow, cleaner lines —
	# a better screen showing something worse.
	"aperture": {"degrade": 0.42, "curvature": 0.095, "scanline_depth": 0.12, "mask_depth": 0.14, "roll": 0.22, "bloom": 0.34},
	# The signal going. For the beat where his invert tears across: everything
	# up, hold slipping hard.
	"failing": {"degrade": 0.85, "curvature": 0.075, "scanline_depth": 0.26, "mask_depth": 0.16, "roll": 0.90, "bloom": 0.30},
	# Effectively off, but still sampling — so a scene can tween *to* the others
	# from a genuinely flat picture rather than popping the shader on.
	"flat": {"degrade": 0.0, "curvature": 0.0, "scanline_depth": 0.0, "mask_depth": 0.0, "roll": 0.0, "bloom": 0.0},
}

var variant := "panel"
var clock := 0.0
## Cross-fades to the untouched picture rather than to black, so the glass can
## arrive without a flash.
var reveal := 0.0
## The one number worth driving from outside: ramp it and the tube degrades.
var degrade := 0.30:
	set(value):
		degrade = value
		if _material != null:
			_material.set_shader_parameter("degrade", degrade)

var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	# Above the backdrop and the frame, below anything anybody has to read.
	# `RegalFrame` sits at -9 and `SplashBackdrop` at -10.
	z_index = -8
	_material = ShaderMaterial.new()
	_material.shader = GLASS_SHADER
	material = _material
	set_variant(variant)
	_push()


func set_variant(name: String) -> void:
	variant = name if VARIANTS.has(name) else "panel"
	if _material == null:
		return
	var v: Dictionary = VARIANTS[variant]
	for key: String in v:
		_material.set_shader_parameter(key, v[key])
	degrade = float(v.get("degrade", degrade))


func _process(delta: float) -> void:
	clock += delta
	_push()


func _push() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("clock", clock)
	_material.set_shader_parameter("reveal", reveal)


## The glass coming up. Last of the three, after the picture and after the
## frame: the composition assembles, and only then does it turn out you have
## been looking at a screen the whole time.
func play(into: Node, delay := 0.9) -> Tween:
	var tween := into.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(self, "reveal", 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## AV-adjacent, and the actual answer to "slow degradation of crt distortion
## through the image switch": a surge that rises into a moment and settles after
## it, rather than a constant level. Hand it the beat the invert tears across
## and the tube struggles through it and recovers, which is information; a fixed
## amount of noise is wallpaper.
func surge(into: Node, peak := 0.9, rise := 0.7, fall := 1.8) -> Tween:
	var base := float(VARIANTS.get(variant, {}).get("degrade", 0.3))
	var tween := into.create_tween()
	tween.tween_property(self, "degrade", peak, rise).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "degrade", base, fall).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween
