class_name SplashBackdrop
extends ColorRect

## Greg: *"the splash screen fades in with this as the backround image and then
## the text is glowing somewhat 3d then the sigil loads in also make the
## backround images be theese 2 the blue invertred side attacking the screen and
## then ofc the backround is from my room"*.
##
## His two reference images are one photograph of his room — the posters, the
## hands over the face, the rune — and the second is the first with a vertical
## seam down it: left half as shot, right half inverted into cyan.
##
## That second image is not a separate picture, it is a *transformation*, so it
## is done live in `shaders/splash_attack.gdshader` rather than baked. Three
## things follow from that, and they are the reason it is worth the shader:
##
##   - The seam can move. The inverted half sweeps in from the right and eats
##     the frame, which is what "attacking the screen" has to mean; a baked
##     image can only sit there.
##   - The seam can tear. It jitters per scanline and drags the colour channels
##     apart as it travels, which is the actual texture of his composite.
##   - It keeps working when the photograph is swapped. Greg has not yet named
##     which room shot he wants; the backdrop is one `--source` away and none of
##     this has to be redone.
##
## The backdrop is derived by `tools/splash_backdrop.py` from the read-only
## collection on the Desktop into `game/art/derived/`, so the repository never
## carries a binary that cannot be rebuilt.

## Both of Greg's images. `room` is his image 2; `invert` is his image 1, which
## he had already cut and inverted himself — the shader wipes between them
## rather than generating the invert, because generating it replaced his
## artwork with an approximation of it.
const ROOM_PATH := "res://art/derived/splash_room.png"
const INVERT_PATH := "res://art/derived/splash_invert.png"
const SPLASH_SHADER := preload("res://shaders/splash_attack.gdshader")

var clock := 0.0
## 0 = the photograph untouched, 1 = the inverted half has taken the screen.
var attack := 0.0
## Master fade, so the plate comes up out of black rather than cutting in.
var reveal := 0.0

## Greg: *"make a couple that variate for fun"*. Same photograph, same shader,
## different cut — each is a tint for the inverted half plus how hard the seam
## tears. They are named rather than numbered because the difference is a look,
## not a level.
## The variants used to be tints for a generated invert. There is no generated
## invert any more — the colour is Greg's, in his own file — so what is left to
## vary is the one thing the shader legitimately owns: how violently the edge
## between his two pictures tears as it crosses.
const VARIANTS := {
	"clean": {"tear": 0.006},
	"torn": {"tear": 0.020},
	"shredded": {"tear": 0.050},
}

var variant := "torn"
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	z_index = -10
	_material = ShaderMaterial.new()
	_material.shader = SPLASH_SHADER
	# Missing art is not a crash. If the derived backdrop has not been built the
	# plate simply stays black and the cold open runs exactly as it did before.
	if ResourceLoader.exists(ROOM_PATH) and ResourceLoader.exists(INVERT_PATH):
		_material.set_shader_parameter("room", load(ROOM_PATH))
		_material.set_shader_parameter("invert", load(INVERT_PATH))
	else:
		push_warning("splash backdrops missing — run tools/splash_backdrop.py")
	material = _material
	set_variant(variant)
	_push()


## Swap the cut. Safe to call at any time; unknown names fall back to his own.
func set_variant(name: String) -> void:
	variant = name if VARIANTS.has(name) else "torn"
	var v: Dictionary = VARIANTS[variant]
	if _material != null:
		_material.set_shader_parameter("tear", v["tear"])


func _process(delta: float) -> void:
	clock += delta
	_push()


func _push() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("clock", clock)
	_material.set_shader_parameter("attack", attack)
	_material.set_shader_parameter("reveal", reveal)
	_material.set_shader_parameter("face_blur", 0.72)
	_material.set_shader_parameter("photo_inset", 0.94)


## The whole sequence, as one tween the caller can hang the rest of the cold
## open off. Held deliberately slow: this is the first thing anybody sees and
## the picture is dense enough to be worth a beat before the type lands on it.
func play(into: Node, title_hold := 0.0) -> Tween:
	var tween := into.create_tween()
	tween.tween_property(self, "reveal", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Let the CellOutz/Wizards plate land before the image attacks it. The hold
	# is supplied by the title sequence; scenes using the backdrop alone retain
	# the old immediate behaviour.
	if title_hold > 0.0:
		tween.tween_interval(title_hold)
	# The invert tears in from the LEFT after the photograph has had a moment to
	# read, matching Greg's composed source rather than inventing a new direction.
	tween.tween_property(self, "attack", 1.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# and then falls back, leaving the room as shot under the logo.
	tween.tween_property(self, "attack", 0.18, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween
