class_name RegalFrame
extends ColorRect

## The visceral-but-regal border around the cold open, and the thing that stops
## Greg's photograph reading as a rectangle pasted onto black.
##
## Greg: *"ad a border that matches is 3d visceral organs bloody ect but regal"*
## / *"make the edges blended and more different and gamified then the orignal 2
## images"* / *"curving on the screen to make a alien futuristic hud but still
## playabile and seamless"*.
##
## Three asks, one problem — the edge of the picture — so one object rather than
## three. See `shaders/regal_frame.gdshader` for why the vasculature is mirrored
## (short version: symmetric viscera reads as heraldry, asymmetric reads as a
## wound, and "regal" is the half that was going to get lost otherwise).
##
## Deliberately a sibling of the backdrop rather than an edit to it. Several
## agents are working the cold open at the same time; a frame that paints over
## the seam composites correctly no matter what happens to the picture below it,
## and cannot collide with their edits because it shares no file with them.

const FRAME_SHADER := preload("res://shaders/regal_frame.gdshader")

## Presets, because the register is a judgement call and Greg asked for variants
## to play with on the backdrop for exactly this reason. Same ornament
## throughout; what varies is how much of it is meat and how much is regalia.
##
## `reliquary` is the intended one: enough vasculature to be unmistakably organic
## and enough bone rule to read as a frame rather than as damage.
const VARIANTS := {
	# Mostly carving. The organs are there but they are a material, not a
	# subject — closest to a straight baroque frame.
	"reliquary": {"vessel_gain": 0.80, "lobes": 4.0, "lobe_depth": 0.026, "gloss": 0.9, "thickness": 0.155, "bite": 0.090, "meat": Color(0.185, 0.028, 0.026)},
	# The meat wins. Thicker, wetter, fewer and deeper lobes, for when the picture
	# under it is calm enough to carry it.
	"offering": {"vessel_gain": 1.20, "lobes": 3.0, "lobe_depth": 0.042, "gloss": 1.15, "thickness": 0.20, "bite": 0.090, "meat": Color(0.235, 0.032, 0.028)},
	# Almost bone. For the menu, where the frame has to lose an argument with the
	# text sitting on top of it.
	#
	# Its band is thinner-*looking* rather than actually thin. The first cut gave
	# it thickness 0.115 and it leaked: the photograph's edge sits a fixed
	# distance out from the opening, so a short band puts that edge inside the
	# ragged dissolve instead of under solid ornament, and the hard rectangle
	# came straight back. Restraint here has to come from the colour and the
	# vessel gain, not from running the band short.
	"ossuary": {"vessel_gain": 0.40, "lobes": 6.0, "lobe_depth": 0.016, "gloss": 0.65, "thickness": 0.170, "bite": 0.125, "meat": Color(0.135, 0.032, 0.034)},
}

var variant := "reliquary"
var clock := 0.0
## Master fade, matching `SplashBackdrop.reveal` so the two can be driven
## together and the frame does not pop in over a picture that is still arriving.
var reveal := 0.0

var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	# Above the backdrop, below everything that has to be read. The title, the
	# menu and the sigil all sit on top of this on purpose.
	z_index = -9
	_material = ShaderMaterial.new()
	_material.shader = FRAME_SHADER
	material = _material
	set_variant(variant)
	_push()


## Match the opening to whatever the backdrop is actually showing.
## `splash_attack.gdshader` insets a 1.25 photo by `photo_inset` on the short
## axis, and `overlap` then pulls the opening in from that edge.
##
## The overlap is not a fudge, it is the mechanism. A frame whose inner lip sits
## exactly on the photograph's edge leaves the hard cut showing along the seam;
## the ornament has to lie *over* the boundary for the boundary to stop existing.
## It costs the outer few percent of the picture on each side, which is what a
## mount has always cost.
##
## It also has to be at least this much for a second reason worth stating,
## because the number is not free to choose. The photo is 0.94 of the screen's
## short axis and the frame band reaches `thickness` beyond its own opening, so
## at zero overlap the outer edge lands past 0.5 and the top and bottom runs are
## cut off by the screen — which is exactly what the first render did, leaving
## the lobes visible only on the left and right. 0.14 brings the ragged dissolve
## back inside the frame on every side.
func fit_to_photo(photo_inset := 0.94, photo_aspect := 1.25, overlap := 0.14) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("opening", Vector2(
		maxf(photo_inset * photo_aspect - overlap, 0.1),
		maxf(photo_inset - overlap, 0.1)))


func set_variant(name: String) -> void:
	variant = name if VARIANTS.has(name) else "reliquary"
	if _material == null:
		return
	var v: Dictionary = VARIANTS[variant]
	for key: String in v:
		_material.set_shader_parameter(key, v[key])


func _process(delta: float) -> void:
	clock += delta
	_push()


func _push() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("clock", clock)
	_material.set_shader_parameter("reveal", reveal)


## Arrives a beat behind the picture. The frame closing around the photograph
## after it has landed reads as the picture being *mounted*; both arriving
## together reads as one flat image fading up.
func play(into: Node, delay := 0.35) -> Tween:
	var tween := into.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(self, "reveal", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween
