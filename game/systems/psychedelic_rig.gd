class_name PsychedelicRig
extends Control

## FINAL_V.md §16, "What to build first," items 1 and 2: one shader with six
## dials (`shaders/psychedelic.gdshader`), and the loop that gives dial 3
## something real to sample. Everything downstream of this — drugs,
## meditation, the shadow realms, and AS2.1's "light warps at night" — is
## meant to be this shader at different dial values, never a system each.
##
## One `ColorRect` for the visible effect, not a pair of ping-ponged
## SubViewports. The shader's own `source_texture` is `hint_screen_texture`,
## which Godot always fills with whatever was drawn earlier in the *same*
## frame — a single, non-accumulating snapshot. `feedback_texture` is the one
## input allowed to carry the previous frame. A first attempt fed
## `get_viewport().get_texture()` into `source_texture` as well, meaning every
## dial — not just the feedback one — recompounded every frame; twenty held
## frames turned a 0.02 chromatic offset into an unreadable smear, and the LUT
## dial degenerated to a single flat colour. Keeping the two inputs strictly
## apart fixed that.
##
## Feeding `get_viewport().get_texture()` straight into `Display`'s own
## material as `feedback_texture` fixed the smear but hit a second, distinct
## fault: the GPU refuses to bind a texture as a uniform in the same draw call
## that is rendering into that same texture, since `Display` renders into the
## very viewport whose texture it would be sampling. `_echo`, a small
## `SubViewport` that exists only to hold a copy of the main view in its own,
## separate framebuffer, is what breaks that cycle — `feedback_texture` reads
## `_echo`, never the main viewport directly.
##
## Fully inert when nothing has touched a dial: the display stays hidden and
## the material is not even asked for a feedback texture, so a scene that
## never asks for any of this pays nothing for it and shows nothing over the
## real frame.

const PSYCHEDELIC_SHADER := preload("res://shaders/psychedelic.gdshader")

## Mirrors the shader's own defaults. Anything not in this table is not a
## dial this rig knows about, and `set_dial` ignores it rather than erroring —
## so wiring up a new one later means adding a line here, not hunting a typo.
const NEUTRAL := {
	"lut_strength": 0.0,
	"kaleidoscope_segments": 0.0,
	"kaleidoscope_spin": 0.0,
	"feedback_strength": 0.0,
	"feedback_zoom": 1.0,
	"feedback_spin": 0.0,
	"chromatic_offset": 0.0,
	"displacement_strength": 0.0,
	"displacement_scroll": 0.3,
	"cut_intensity": 0.0,
	"cut_seed": 0.0,
	"cut_rate": 8.0,
}

var _material: ShaderMaterial
var _display: ColorRect
var _echo: SubViewport
var _echo_rect: TextureRect
var _dials: Dictionary = NEUTRAL.duplicate()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_echo = SubViewport.new()
	_echo.name = "Echo"
	_echo.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_echo)
	_echo_rect = TextureRect.new()
	_echo_rect.name = "Copy"
	_echo_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_echo_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_echo.add_child(_echo_rect)

	_display = ColorRect.new()
	_display.name = "Display"
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.visible = false
	_material = ShaderMaterial.new()
	_material.shader = PSYCHEDELIC_SHADER
	_material.set_shader_parameter("lut_texture", _build_placeholder_lut())
	_material.set_shader_parameter("noise_texture", _build_placeholder_noise())
	_display.material = _material
	add_child(_display)
	_apply_all_dials()
	set_process(true)


## Any dial named in `NEUTRAL`; anything else is silently ignored.
func set_dial(dial_name: String, value: float) -> void:
	if not _dials.has(dial_name):
		return
	_dials[dial_name] = value
	_material.set_shader_parameter(dial_name, value)


func dial(dial_name: String) -> float:
	return float(_dials.get(dial_name, 0.0))


## Back to the shader's own no-op defaults. For a scene changing what state
## it is in (a trip ending, a night turning to day) rather than fading one
## dial at a time.
func reset_dials() -> void:
	for key in NEUTRAL:
		set_dial(key, float(NEUTRAL[key]))


func _apply_all_dials() -> void:
	for key in _dials:
		_material.set_shader_parameter(key, _dials[key])


## True once anything has moved a dial off its neutral value. Kaleidoscope's
## neutral is "off" below 2 segments rather than exactly 0, so it gets its own
## comparison; everything else is neutral at its `NEUTRAL` value.
func _is_engaged() -> bool:
	if dial("kaleidoscope_segments") >= 2.0:
		return true
	for key in ["lut_strength", "feedback_strength", "chromatic_offset", "displacement_strength", "cut_intensity"]:
		if dial(key) > 0.0:
			return true
	return false


func _process(_delta: float) -> void:
	var engaged := _is_engaged()
	_display.visible = engaged
	if not engaged:
		_echo.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# `_echo` only runs while the dial that wants it is actually on, so an
	# ordinary trip through the other five dials never pays for the extra copy.
	if dial("feedback_strength") > 0.0:
		_echo.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var size := Vector2i(get_viewport_rect().size)
		if _echo.size != size:
			_echo.size = size
		_echo_rect.texture = get_viewport().get_texture()
		_material.set_shader_parameter("feedback_texture", _echo.get_texture())
	else:
		_echo.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Stand-ins only. A real palette and flow field are what Greg's TouchDesigner
## patch (FINAL_V.md build item 3) is meant to export; these exist so the
## shader and rig are usable before that patch is built, generated the same
## way `world_look.gd`'s `_contamination()` builds its own noise rather than
## importing an authored asset for a texture nothing has designed yet.
static func _build_placeholder_lut() -> ImageTexture:
	var size := 256
	var image := Image.create(size, 1, false, Image.FORMAT_RGB8)
	var shadow := Color("1a2418")
	var mid := Color("8a9a4a")
	var high := Color("e6d4ac")
	for x in size:
		var t := float(x) / float(size - 1)
		var color := shadow.lerp(mid, clampf(t * 2.0, 0.0, 1.0))
		color = color.lerp(high, clampf(t * 2.0 - 1.0, 0.0, 1.0))
		image.set_pixel(x, 0, color)
	return ImageTexture.create_from_image(image)


static func _build_placeholder_noise() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	return texture
