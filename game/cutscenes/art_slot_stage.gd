class_name ArtSlotStage
extends Control

## A cutscene stage built from replaceable art slots (Greg, 2026-09-24): scene
## areas with base textures he swaps for his own art once he has made it.
##
## Deliberately neutral. The first version echoed the composition of a
## reference clip too closely and Greg rejected it outright: "I don't want to
## copy that guy's art." So nothing here suggests content -- every slot is a
## plain labelled block or grid in a generic layer (far, mid and near
## backgrounds, a ground band, two actors, a prop, a frame). What each one
## depicts is Greg's to decide and draw.
##
## Each slot looks for `res://art/cutscene/<slot>.png` and draws it when it
## exists; otherwise it draws its placeholder and its name. See
## art/cutscene/README.md.

const ART_DIR := "res://art/cutscene/"
## Slot id -> layout. `tile` repeats across the stage; `parallax` is how fast a
## tiling layer drifts relative to the nearest one.
const SLOTS := {
	"bg_far": {"note": "Furthest background layer", "tile": true, "parallax": 0.15},
	"bg_mid": {"note": "Middle background layer", "tile": true, "parallax": 0.4},
	"bg_near": {"note": "Nearest background layer", "tile": true, "parallax": 0.7},
	"ground": {"note": "The surface actors stand on", "tile": true, "parallax": 1.0},
	"ground_under": {"note": "What is below the surface", "tile": true, "parallax": 1.0},
	"actor_a": {"note": "First character", "tile": false},
	"actor_b": {"note": "Second character", "tile": false},
	"prop": {"note": "A prop in the scene", "tile": false},
	"frame": {"note": "Border over everything, transparent middle", "tile": false},
}
## Placeholder tints: one flat grey step per layer, so depth reads and nothing
## reads as content.
const GREYS := {
	"bg_far": Color(0.14, 0.14, 0.15), "bg_mid": Color(0.2, 0.2, 0.21), "bg_near": Color(0.27, 0.27, 0.28),
	"ground": Color(0.5, 0.5, 0.5), "ground_under": Color(0.32, 0.32, 0.33),
	"actor_a": Color(0.72, 0.72, 0.7), "actor_b": Color(0.6, 0.6, 0.62), "prop": Color(0.66, 0.64, 0.6),
}

var clock := 0.0
var textures: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in SLOTS:
		var path := ART_DIR + str(slot) + ".png"
		if ResourceLoader.exists(path):
			textures[slot] = load(path)


## True when Greg's art fills the slot rather than the placeholder.
func is_authored(slot: String) -> bool:
	return textures.has(slot)


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func _stage() -> Rect2:
	return Rect2(size * Vector2(0.05, 0.07), size * Vector2(0.9, 0.86))


## Where each slot sits. Plain bands and boxes; positions only, no motion
## beyond the parallax drift that shows the layers are separate.
func slot_rect(slot: String) -> Rect2:
	var stage := _stage()
	var horizon := stage.position.y + stage.size.y * 0.7
	match slot:
		"bg_far":
			return Rect2(stage.position, Vector2(stage.size.x, stage.size.y * 0.45))
		"bg_mid":
			return Rect2(Vector2(stage.position.x, stage.position.y + stage.size.y * 0.25), Vector2(stage.size.x, stage.size.y * 0.3))
		"bg_near":
			return Rect2(Vector2(stage.position.x, stage.position.y + stage.size.y * 0.45), Vector2(stage.size.x, stage.size.y * 0.25))
		"ground":
			return Rect2(Vector2(stage.position.x, horizon), Vector2(stage.size.x, stage.size.y * 0.06))
		"ground_under":
			return Rect2(Vector2(stage.position.x, horizon + stage.size.y * 0.06), Vector2(stage.size.x, stage.size.y * 0.24))
		"actor_a":
			return Rect2(Vector2(stage.position.x + stage.size.x * 0.28, horizon - stage.size.y * 0.24), Vector2(stage.size.x * 0.07, stage.size.y * 0.24))
		"actor_b":
			return Rect2(Vector2(stage.position.x + stage.size.x * 0.62, horizon - stage.size.y * 0.2), Vector2(stage.size.x * 0.07, stage.size.y * 0.2))
		"prop":
			return Rect2(Vector2(stage.position.x + stage.size.x * 0.47, horizon - stage.size.y * 0.1), Vector2(stage.size.x * 0.06, stage.size.y * 0.1))
		_:
			return Rect2(Vector2.ZERO, size)


func _draw() -> void:
	var stage := _stage()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.055))
	for slot in ["bg_far", "bg_mid", "bg_near", "ground_under", "ground", "prop", "actor_a", "actor_b"]:
		_slot(slot, slot_rect(slot))
	# Tiling layers run past the stage; trim them to it before the frame.
	var outside := Color(0.05, 0.05, 0.055)
	draw_rect(Rect2(Vector2.ZERO, Vector2(stage.position.x, size.y)), outside)
	draw_rect(Rect2(Vector2(stage.end.x, 0), Vector2(size.x - stage.end.x, size.y)), outside)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, stage.position.y)), outside)
	draw_rect(Rect2(Vector2(0, stage.end.y), Vector2(size.x, size.y - stage.end.y)), outside)
	_slot("frame", Rect2(Vector2.ZERO, size))


func _slot(slot: String, rect: Rect2) -> void:
	var spec: Dictionary = SLOTS[slot]
	if textures.has(slot):
		var texture: Texture2D = textures[slot]
		if bool(spec.get("tile", false)):
			var scale := rect.size.y / float(texture.get_height())
			var step := float(texture.get_width()) * scale
			var x := rect.position.x - fposmod(clock * 30.0 * float(spec.get("parallax", 1.0)), step)
			while x < rect.end.x:
				draw_texture_rect(texture, Rect2(Vector2(x, rect.position.y), Vector2(step, rect.size.y)), false)
				x += step
		else:
			draw_texture_rect(texture, rect, false)
		return
	if slot == "frame":
		# A plain rule around the stage: a frame slot, not a frame design.
		draw_rect(_stage(), Color(0.55, 0.55, 0.55), false, 2.0)
		_label("frame", _stage().position + Vector2(8, -8))
		return
	_placeholder(slot, rect, spec)


## A flat grey block with a drifting grid (tiling layers) or crossed diagonals
## (single pieces), and the slot's name. Nothing that suggests what goes there.
func _placeholder(slot: String, rect: Rect2, spec: Dictionary) -> void:
	var grey: Color = GREYS.get(slot, Color(0.4, 0.4, 0.4))
	draw_rect(rect, grey)
	var line := grey.lightened(0.18)
	if bool(spec.get("tile", false)):
		var cell := 48.0
		var shift := fposmod(clock * 30.0 * float(spec.get("parallax", 1.0)), cell)
		var x := rect.position.x - shift
		while x < rect.end.x:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), line, 1.0)
			x += cell
	else:
		draw_line(rect.position, rect.end, line, 1.0)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), line, 1.0)
	draw_rect(rect, line, false, 1.0)
	_label(slot, rect.position + Vector2(6, 16))


func _label(slot: String, at: Vector2) -> void:
	draw_string(ThemeDB.fallback_font, at, "%s  //  %s" % [slot, str(SLOTS[slot].note)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
