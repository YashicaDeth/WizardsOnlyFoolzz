extends Control

## The presentation slate before the player ever sees the menu: two publisher
## cards in the game's own stencil face, then the WizardsOnlyFoolz mark
## itself — the real, generated wordmark from `tools/wof_wordmark.py`
## (`art/brand/wof-wordmark-*.png`), not a placeholder — drawn on with a
## blood-drip reveal rather than a plain fade, because a mark built out of
## dripping metal deserves to arrive the same way.
##
## Skippable at any point, on purpose: a splash nobody can get past is a
## splash people learn to hate by the tenth launch.

const WOF_SEAL_PATH := "res://art/brand/wof_seal.png"
const WOF_STACKED_PATH := "res://art/brand/wof_stacked.png"
const GRANDEUR_PATH := "res://art/brand/grandeur_wordmark.png"
const MENU_SCENE := "res://country_town_menu.tscn"
const SPLASH_BACKDROP := preload("res://systems/splash_backdrop.gd")


## Loaded by reading the file directly rather than `preload()`/`load()` —
## both of those go through the resource importer, which needs a `.import`
## sidecar the editor bakes the first time it scans a new asset. These PNGs
## were dropped straight into `game/art/brand/` by a tool outside the editor,
## so `Image.load()`'s raw decode is what actually works headless, on a
## worktree that has never opened this project in the GUI.
static func _load_png(path: String) -> ImageTexture:
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

enum Stage { CELLOUTZ, GRANDEUR, MARK, DONE }

const STAGE_DURATION := {
	Stage.CELLOUTZ: 2.4,
	Stage.GRANDEUR: 2.4,
	Stage.MARK: 4.2,
}
# Fraction of a stage spent fading in and fading out; the middle holds solid.
const FADE_FRACTION := 0.30

var stage: Stage = Stage.CELLOUTZ
var stage_clock := 0.0
var finishing := false

var mark_rect: TextureRect
var seal_rect: TextureRect
var grandeur_rect: TextureRect
var reveal_material: ShaderMaterial
var grandeur_material: ShaderMaterial
var backdrop: SplashBackdrop


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Godot resolves the window size a frame late from a cold boot; without
	# this the very first _draw() lays text out against a 0x0 rect.
	custom_minimum_size = get_viewport_rect().size
	# The publisher cards belong to the same place as the front door, not to a
	# separate black void.  Put the very same composed room / cyan-rip plate
	# beneath them so the last beat cuts naturally into the live street tableau.
	backdrop = SPLASH_BACKDROP.new()
	backdrop.name = "ColdOpenRoom"
	backdrop.reveal = 1.0
	backdrop.attack = 0.18
	add_child(backdrop)
	move_child(backdrop, 0)
	_build_mark_layer()
	set_process(true)
	queue_redraw()


func _build_mark_layer() -> void:
	# The seal (the ring-and-rune icon) arrives first, small and central; the
	# full stacked wordmark takes over as it grows, the way a stamp widens
	# into the full plate it was cut from. Both share one drip-reveal shader
	# so the transition between them reads as one continuous pour rather than
	# a cut. The Grandeur card gets its own instance of the same shader —
	# same pour, independent timeline, since it plays a whole stage earlier.
	var shader := Shader.new()
	shader.code = _reveal_shader_code()
	reveal_material = ShaderMaterial.new()
	reveal_material.shader = shader
	reveal_material.set_shader_parameter("progress", 0.0)
	grandeur_material = ShaderMaterial.new()
	grandeur_material.shader = shader
	grandeur_material.set_shader_parameter("progress", 0.0)

	grandeur_rect = _build_reveal_rect(GRANDEUR_PATH, grandeur_material)
	seal_rect = _build_reveal_rect(WOF_SEAL_PATH, reveal_material)
	mark_rect = _build_reveal_rect(WOF_STACKED_PATH, reveal_material)


func _build_reveal_rect(path: String, material: ShaderMaterial) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _load_png(path)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_preset(Control.PRESET_CENTER)
	rect.material = material
	rect.modulate = Color(1, 1, 1, 0)
	add_child(rect)
	return rect


## A vertical wipe with a torn, dripping edge rather than a hard line — the
## same register as the mark's own drips, done live instead of baked into the
## texture, so the reveal direction (top down, the way blood actually runs)
## is legible as motion rather than a fade nobody would call "bleeding in".
func _reveal_shader_code() -> String:
	return """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float jitter = hash(vec2(floor(UV.x * 28.0), 0.0)) * 0.12;
	// Revealed where UV.y is above the edge (the top of the image clears
	// first), overscanned past 1.0 so the jitter can never leave a sliver of
	// the bottom row permanently hidden at progress == 1.0.
	float edge = progress * 1.20 - jitter;
	float reveal = 1.0 - smoothstep(edge - 0.02, edge + 0.06, UV.y);
	COLOR = vec4(tex.rgb, tex.a * reveal);
}
"""


func _process(delta: float) -> void:
	if finishing:
		return
	stage_clock += delta
	var duration: float = STAGE_DURATION.get(stage, 1.0)
	_update_grandeur_visibility()
	_update_mark_visibility()
	if stage_clock >= duration:
		_advance_stage()
	queue_redraw()


## Same three-beat pour as the WizardsOnlyFoolz mark, just the one image and
## one stage — Allusions to Grandeur does not need a seal-then-lockup handoff
## because it never had a separate icon to hand off from.
func _update_grandeur_visibility() -> void:
	grandeur_rect.visible = stage == Stage.GRANDEUR
	if stage != Stage.GRANDEUR:
		return
	var duration: float = STAGE_DURATION[Stage.GRANDEUR]
	var fade := duration * FADE_FRACTION
	var reveal: float = clampf(stage_clock / maxf(fade, 0.01), 0.0, 1.0)
	var hold_end := duration - fade
	var out_alpha := 1.0
	if stage_clock > hold_end:
		out_alpha = 1.0 - clampf((stage_clock - hold_end) / maxf(fade, 0.01), 0.0, 1.0)

	grandeur_rect.modulate = Color(1, 1, 1, out_alpha)
	grandeur_rect.material.set_shader_parameter("progress", reveal)
	# The cold-open mark used to fill most of the frame, which made the image
	# beneath it feel like a cropped wallpaper.  Leave a real perimeter so the
	# room, sigil and incoming 3D tableau can establish scale before the player
	# reads the company/title card.
	var target_width := size.x * 0.50
	var aspect: float = grandeur_rect.texture.get_size().y / grandeur_rect.texture.get_size().x
	grandeur_rect.size = Vector2(target_width, target_width * aspect)
	grandeur_rect.position = size * 0.5 - grandeur_rect.size * 0.5


func _update_mark_visibility() -> void:
	if stage != Stage.MARK:
		return
	var duration: float = STAGE_DURATION[Stage.MARK]
	var fade := duration * FADE_FRACTION
	# Seal first, revealing; the stacked wordmark crossfades over the top of
	# it once the seal itself has finished pouring in, so the icon is never
	# fighting the full lockup for the same few seconds of attention.
	var seal_reveal: float = clampf(stage_clock / maxf(fade, 0.01), 0.0, 1.0)
	var mark_start := fade
	var mark_reveal: float = clampf((stage_clock - mark_start) / maxf(fade, 0.01), 0.0, 1.0)
	var hold_end := duration - fade
	var out_alpha := 1.0
	if stage_clock > hold_end:
		out_alpha = 1.0 - clampf((stage_clock - hold_end) / maxf(fade, 0.01), 0.0, 1.0)

	seal_rect.modulate = Color(1, 1, 1, (1.0 - mark_reveal) * out_alpha)
	seal_rect.material.set_shader_parameter("progress", seal_reveal)
	seal_rect.size = seal_rect.texture.get_size() * lerpf(0.55, 0.85, seal_reveal)
	seal_rect.position = size * 0.5 - seal_rect.size * 0.5

	mark_rect.modulate = Color(1, 1, 1, mark_reveal * out_alpha)
	mark_rect.material.set_shader_parameter("progress", mark_reveal)
	var mark_size := size.x * 0.52
	var aspect: float = mark_rect.texture.get_size().y / mark_rect.texture.get_size().x
	mark_rect.size = Vector2(mark_size, mark_size * aspect)
	mark_rect.position = size * 0.5 - mark_rect.size * 0.5


func _advance_stage() -> void:
	stage_clock = 0.0
	match stage:
		Stage.CELLOUTZ:
			stage = Stage.GRANDEUR
		Stage.GRANDEUR:
			stage = Stage.MARK
		Stage.MARK, Stage.DONE:
			_finish()


## Fade curve shared by both text cards: in for the first slice, solid
## through the middle, out for the last — the same three-beat shape as the
## mark's own reveal, so all three cards feel like one rhythm rather than two
## registers bolted together.
func _card_alpha(duration: float) -> float:
	var fade := duration * FADE_FRACTION
	if stage_clock < fade:
		return clampf(stage_clock / maxf(fade, 0.01), 0.0, 1.0)
	if stage_clock > duration - fade:
		return clampf((duration - stage_clock) / maxf(fade, 0.01), 0.0, 1.0)
	return 1.0


func _draw() -> void:
	# Keep the first institution card legible, but never return to the old
	# disconnected blank screen: the audience can already read the same world
	# that becomes the live menu a moment later.
	var veil_alpha := 0.72 if stage == Stage.CELLOUTZ else 0.30
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.012, 0.01, veil_alpha), true)
	match stage:
		Stage.CELLOUTZ:
			_draw_card("CELLOUTZ INC.", "AN INSTITUTION, NOT A COMPANY", STAGE_DURATION[Stage.CELLOUTZ])
		Stage.GRANDEUR:
			# The wordmark itself is the title; only the small "presents" line
			# is still drawn in the plain stencil face, under the image rather
			# than fighting it for the centre of the frame.
			_draw_subtitle("PRESENTS", STAGE_DURATION[Stage.GRANDEUR], size.y * 0.5 + grandeur_rect.size.y * 0.5 + 26.0)


func _draw_card(title: String, subtitle: String, duration: float) -> void:
	var alpha := _card_alpha(duration)
	if alpha <= 0.001:
		return
	var bone := Color("f1d2a3") * Color(1, 1, 1, alpha)
	var cap := clampf(size.x * 0.052, 28.0, 64.0)
	var title_width := CellOutzType.width(title, cap, 3.0)
	CellOutzType.draw_text(self, Vector2(size.x * 0.5 - title_width * 0.5, size.y * 0.5 - cap * 0.5), title, cap, bone, 3.0)
	_draw_subtitle(subtitle, duration, size.y * 0.5 + cap * 0.7)


func _draw_subtitle(subtitle: String, duration: float, y: float) -> void:
	var alpha := _card_alpha(duration)
	if alpha <= 0.001:
		return
	var copper := Color("f06428") * Color(1, 1, 1, alpha)
	var sub_cap := clampf(size.x * 0.052, 28.0, 64.0) * 0.32
	var sub_width := CellOutzType.width_condensed(subtitle, sub_cap, 4.0)
	CellOutzType.draw_condensed(self, Vector2(size.x * 0.5 - sub_width * 0.5, y), subtitle, sub_cap, copper, 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if finishing:
		return
	var wants_skip: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if wants_skip:
		_finish()


func _finish() -> void:
	if finishing:
		return
	finishing = true
	get_tree().change_scene_to_file(MENU_SCENE)
