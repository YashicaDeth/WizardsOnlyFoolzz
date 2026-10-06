class_name MateriaTrip
extends Node

## drug-70, item 5: one optional trip sequence, 40 seconds, built from the
## psychedelic shader and art already in the repo. Triggered at the materia
## station, skippable at any moment (USE again, or cancel).
##
## It is FINAL_V's Path B in miniature: a baked ground layer with the live
## shader composited over it. The ground here is one of Greg's own plates
## (`art/derived/plate/`); when a TouchDesigner flipbook exists it replaces the
## plate (DESIGN/TOUCHDESIGNER_PIPELINE.md, "A baked sequence as a trip"),
## and the dial track below stays the live layer on top.
##
## Six movements, keyed by time. Between keys each dial eases; mirror counts
## stay whole. The player is not frozen: the world keeps running under it, so
## turning your head mid-fold is part of it.

const PLATE := "res://art/derived/plate/covermeinmoss.png"
const LENGTH := 40.0
const SKIP_FADE := 0.6

## {t, dials, plate (0-1 opacity of the ground layer)}. Dials absent from a key
## are at rest there.
const KEYS := [
	{"t": 0.0, "plate": 0.0, "dials": {}},
	{"t": 5.0, "plate": 0.0, "dials": {"chromatic_offset": 0.008, "pulse_strength": 0.6, "saturation_shift": 0.2}},
	{"t": 12.0, "plate": 0.0, "dials": {"kaleidoscope_segments": 6.0, "kaleidoscope_spin": 0.2, "lut_strength": 0.6,
		"palette_cycle": 0.06, "chromatic_offset": 0.012, "pulse_strength": 0.6, "saturation_shift": 0.4}},
	{"t": 20.0, "plate": 0.25, "dials": {"feedback_strength": 0.7, "feedback_zoom": 1.025, "feedback_spin": 0.08,
		"displacement_strength": 0.06, "lut_strength": 0.5, "palette_cycle": 0.1, "saturation_shift": 0.3,
		"kaleidoscope_segments": 4.0, "kaleidoscope_spin": -0.1}},
	{"t": 28.0, "plate": 0.85, "dials": {"kaleidoscope_segments": 8.0, "kaleidoscope_spin": 0.12, "melt_strength": 0.08,
		"lut_strength": 0.4, "feedback_strength": 0.4, "feedback_zoom": 1.01, "chromatic_offset": 0.01, "pulse_strength": 0.4}},
	# The turn: the same place in its other register. Not fun, and short.
	{"t": 34.0, "plate": 0.4, "dials": {"darkness": 0.7, "edge_figures": 0.9, "saturation_shift": -0.6,
		"cut_intensity": 0.25, "cut_rate": 2.0, "displacement_strength": 0.03, "feedback_strength": 0.3}},
	{"t": 40.0, "plate": 0.0, "dials": {}},
]

signal finished(skipped: bool)

var rig: PsychedelicRig
var plate: TextureRect
## A TouchDesigner flipbook (`art/materia/trip_flipbook.png` + `.json`), when
## one has been baked; empty means Greg's plate is the ground.
var flipbook: Dictionary = {}
var _frame_view: AtlasTexture
var playing := false
var elapsed := 0.0
var _skip_left := -1.0
var _skip_from: Dictionary = {}
var _skip_plate := 0.0


## `layer` is the canvas the rig is on; the plate goes under the rig so the
## shader composites over it.
func setup(target_rig: PsychedelicRig, layer: CanvasLayer) -> void:
	rig = target_rig
	plate = TextureRect.new()
	plate.name = "TripGround"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	flipbook = MateriaBakes.flipbook("trip_flipbook")
	if flipbook.is_empty():
		plate.texture = load(PLATE) as Texture2D
	else:
		_frame_view = AtlasTexture.new()
		_frame_view.atlas = flipbook.texture
		_frame_view.region = MateriaBakes.flipbook_region(flipbook, 0)
		plate.texture = _frame_view
	plate.modulate.a = 0.0
	plate.visible = false
	layer.add_child(plate)
	layer.move_child(plate, 0)


func play() -> void:
	# The sequence's own palette, whatever a dose had set before it.
	rig.set_texture("lut_texture", Materia.palette_texture(Materia.FUN_PALETTE))
	playing = true
	elapsed = 0.0
	_skip_left = -1.0
	plate.visible = true


func skip() -> void:
	if not playing or _skip_left >= 0.0:
		return
	_skip_from = dials_at(elapsed)
	_skip_plate = plate.modulate.a
	_skip_left = SKIP_FADE


func _process(delta: float) -> void:
	if not playing:
		return
	if _skip_left >= 0.0:
		_skip_left -= delta
		var k := clampf(_skip_left / SKIP_FADE, 0.0, 1.0)
		var rest: Dictionary = PsychedelicRig.NEUTRAL
		for dial_name: String in rest:
			rig.set_dial(dial_name, lerpf(float(rest[dial_name]), float(_skip_from.get(dial_name, rest[dial_name])), k))
		plate.modulate.a = _skip_plate * k
		if _skip_left <= 0.0:
			_end(true)
		return
	elapsed += delta
	if elapsed >= LENGTH:
		_end(false)
		return
	var dials := dials_at(elapsed)
	for dial_name: String in dials:
		rig.set_dial(dial_name, float(dials[dial_name]))
	plate.modulate.a = plate_at(elapsed)
	if _frame_view != null:
		_frame_view.region = MateriaBakes.flipbook_region(flipbook, flipbook_frame(elapsed))


## Which atlas frame shows at `t` seconds: looped, or held on the last.
func flipbook_frame(t: float) -> int:
	if flipbook.is_empty():
		return 0
	var index := int(t * float(flipbook.fps))
	var frames := int(flipbook.frames)
	return index % frames if bool(flipbook.loop) else mini(index, frames - 1)


func _end(skipped: bool) -> void:
	playing = false
	rig.reset_dials()
	plate.modulate.a = 0.0
	plate.visible = false
	finished.emit(skipped)


## The dial set at `t` seconds, eased between keys. Pure, for tests.
static func dials_at(t: float) -> Dictionary:
	var rest: Dictionary = PsychedelicRig.NEUTRAL
	var span := _span(t)
	var a: Dictionary = span[0]
	var b: Dictionary = span[1]
	var k := smoothstep(0.0, 1.0, float(span[2]))
	var out := {}
	for dial_name: String in rest:
		var from := float((a.dials as Dictionary).get(dial_name, rest[dial_name]))
		var to := float((b.dials as Dictionary).get(dial_name, rest[dial_name]))
		out[dial_name] = lerpf(from, to, k)
	var segments := float(out["kaleidoscope_segments"])
	out["kaleidoscope_segments"] = 0.0 if segments < 2.0 else roundf(segments)
	return out


static func plate_at(t: float) -> float:
	var span := _span(t)
	return lerpf(float(span[0].plate), float(span[1].plate), smoothstep(0.0, 1.0, float(span[2])))


static func _span(t: float) -> Array:
	for index in range(KEYS.size() - 1):
		var a: Dictionary = KEYS[index]
		var b: Dictionary = KEYS[index + 1]
		if t <= float(b.t):
			return [a, b, clampf((t - float(a.t)) / maxf(float(b.t) - float(a.t), 0.001), 0.0, 1.0)]
	return [KEYS[KEYS.size() - 1], KEYS[KEYS.size() - 1], 1.0]
