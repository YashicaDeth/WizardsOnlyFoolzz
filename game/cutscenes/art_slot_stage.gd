class_name ArtSlotStage
extends Control

## A cutscene stage built from named art slots (Greg, 2026-09-24): "in-game
## cutscene art style segment areas with textures you can replace ... once I
## make the art for, say, the skulls in the background, the wormy floor, the
## character model." A side-on diorama in an ornate frame, in the register of
## his reference clip -- the layout and motion are original, and every piece
## is a slot.
##
## Each slot looks for `res://art/cutscene/<slot>.png`. If Greg's file is there
## it is drawn; if not, a rough placeholder is drawn in code and labelled with
## the slot's name, so the stage always runs and always says what goes where.
## See art/cutscene/README.md.

const ART_DIR := "res://art/cutscene/"
## Slot id -> what it is, and how it is laid out. `tile` repeats across the
## stage; `parallax` drifts it slower or faster than the camera move.
const SLOTS := {
	"backdrop": {"note": "Deep background colour / texture behind everything", "tile": false},
	"bg_skulls": {"note": "Back row of large spiked skulls (tiles horizontally)", "tile": true, "parallax": 0.25},
	"floor_top": {"note": "The walkable ledge surface (tiles horizontally)", "tile": true, "parallax": 1.0},
	"floor_worms": {"note": "Band of worms / guts under the ledge (tiles)", "tile": true, "parallax": 1.0},
	"actor_runner": {"note": "The character: runs and leaps along the ledge", "tile": false},
	"actor_jar": {"note": "A body in a jar that rides up and down", "tile": false},
	"prop_orb": {"note": "An eye / orb that rolls along the ledge", "tile": false},
	"frame": {"note": "Ornate border drawn over everything (transparent middle)", "tile": false},
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
	return Rect2(size * Vector2(0.06, 0.08), size * Vector2(0.88, 0.84))


func _draw() -> void:
	var stage := _stage()
	draw_rect(Rect2(Vector2.ZERO, size), Color("050102"))
	_slot("backdrop", stage)
	_slot("bg_skulls", Rect2(stage.position + Vector2(0, stage.size.y * 0.04), Vector2(stage.size.x, stage.size.y * 0.6)))
	var ledge_y := stage.position.y + stage.size.y * 0.66
	_slot("floor_worms", Rect2(Vector2(stage.position.x, ledge_y + 10), Vector2(stage.size.x, stage.size.y * 0.3)))
	_slot("floor_top", Rect2(Vector2(stage.position.x, ledge_y), Vector2(stage.size.x, 14)))
	# The actors, on a loop: the runner crosses and leaps, the jar rides up
	# and down, the orb rolls the other way.
	var run := fposmod(clock * 0.16, 1.0)
	var runner_x := lerpf(stage.position.x + stage.size.x * 0.12, stage.end.x - stage.size.x * 0.12, run)
	var hop := maxf(0.0, sin(run * TAU * 3.0)) * stage.size.y * 0.16
	_slot("actor_runner", Rect2(Vector2(runner_x - 18, ledge_y - 70 - hop), Vector2(36, 70)))
	var jar_y := ledge_y - 96 - (sin(clock * 0.9) * 0.5 + 0.5) * stage.size.y * 0.3
	_slot("actor_jar", Rect2(Vector2(stage.position.x + stage.size.x * 0.46, jar_y), Vector2(58, 96)))
	var roll := fposmod(-clock * 0.11, 1.0)
	var orb_x := lerpf(stage.position.x + 40, stage.end.x - 40, roll)
	_slot("prop_orb", Rect2(Vector2(orb_x - 16, ledge_y - 32), Vector2(32, 32)), clock * -3.0)
	# Tiling layers run past the stage; trim them to it before the frame.
	var void_colour := Color("050102")
	draw_rect(Rect2(Vector2.ZERO, Vector2(stage.position.x, size.y)), void_colour)
	draw_rect(Rect2(Vector2(stage.end.x, 0), Vector2(size.x - stage.end.x, size.y)), void_colour)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, stage.position.y)), void_colour)
	draw_rect(Rect2(Vector2(0, stage.end.y), Vector2(size.x, size.y - stage.end.y)), void_colour)
	_slot("frame", Rect2(Vector2.ZERO, size))


## Draws one slot into `rect`: Greg's texture if it exists, else a placeholder.
func _slot(slot: String, rect: Rect2, spin := 0.0) -> void:
	var spec: Dictionary = SLOTS[slot]
	if textures.has(slot):
		var texture: Texture2D = textures[slot]
		if bool(spec.get("tile", false)):
			var drift := fposmod(clock * 30.0 * float(spec.get("parallax", 1.0)), float(texture.get_width()))
			var x := rect.position.x - drift
			var scale := rect.size.y / float(texture.get_height())
			var step := float(texture.get_width()) * scale
			while x < rect.end.x:
				draw_texture_rect(texture, Rect2(Vector2(x, rect.position.y), Vector2(step, rect.size.y)), false)
				x += step
		else:
			if spin != 0.0:
				draw_set_transform(rect.get_center(), spin, Vector2.ONE)
				draw_texture_rect(texture, Rect2(-rect.size * 0.5, rect.size), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect(texture, rect, false)
		return
	call("_placeholder_" + slot, rect, spin)
	_tag(slot, rect)


## Placeholder art: rough on purpose, so it reads as a stand-in.
func _placeholder_backdrop(rect: Rect2, _spin: float) -> void:
	draw_rect(rect, Color("150406"))


func _placeholder_bg_skulls(rect: Rect2, _spin: float) -> void:
	var count := 3
	var drift := fposmod(clock * 30.0 * 0.25, rect.size.x / count)
	for index in count + 1:
		var centre := Vector2(rect.position.x + (float(index) + 0.5) * rect.size.x / count - drift, rect.position.y + rect.size.y * 0.42)
		var radius := rect.size.y * 0.3
		for spike in 28:
			var angle := TAU * float(spike) / 28.0
			draw_line(centre + Vector2.from_angle(angle) * radius, centre + Vector2.from_angle(angle) * radius * 1.35, Color(0.35, 0.06, 0.07, 0.7), 2.0)
		draw_circle(centre, radius, Color(0.30, 0.05, 0.06, 0.8))
		for eye in [-1.0, 1.0]:
			draw_circle(centre + Vector2(eye * radius * 0.38, -radius * 0.05), radius * 0.2, Color("150406"))
		draw_rect(Rect2(centre + Vector2(-radius * 0.4, radius * 0.45), Vector2(radius * 0.8, radius * 0.35)), Color(0.24, 0.04, 0.05, 0.8))


func _placeholder_floor_top(rect: Rect2, _spin: float) -> void:
	draw_rect(rect, Color("b9a4a0"))
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("e8dad6"), 2.0)


func _placeholder_floor_worms(rect: Rect2, _spin: float) -> void:
	draw_rect(rect, Color("3a0a0c"))
	var drift := fposmod(clock * 30.0, 60.0)
	for row in 3:
		var y := rect.position.y + rect.size.y * (0.22 + row * 0.28)
		var points := PackedVector2Array()
		var x := rect.position.x - drift
		while x < rect.end.x + 20:
			points.append(Vector2(x, y + sin((x + row * 40.0) * 0.08) * rect.size.y * 0.09))
			x += 6.0
		draw_polyline(points, Color("c47a72"), rect.size.y * 0.12)
		draw_polyline(points, Color("8a2a2a"), rect.size.y * 0.05)


func _placeholder_actor_runner(rect: Rect2, _spin: float) -> void:
	var bone := Color("e8dcd0")
	var c := rect.get_center()
	var stride := sin(clock * 12.0) * 10.0
	draw_circle(Vector2(c.x, rect.position.y + 9), 9.0, bone)
	draw_line(Vector2(c.x, rect.position.y + 18), Vector2(c.x, c.y + 8), bone, 3.0)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(c.x, c.y - 10), Vector2(c.x + side * 12, c.y + stride * side * 0.5), bone, 2.0)
		draw_line(Vector2(c.x, c.y + 8), Vector2(c.x + stride * side, rect.end.y), bone, 2.5)


func _placeholder_actor_jar(rect: Rect2, _spin: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 0), Vector2(rect.size.x - 8, 10)), Color("b9a4a0"))
	draw_rect(Rect2(rect.position + Vector2(0, 10), Vector2(rect.size.x, rect.size.y - 10)), Color(0.6, 0.3, 0.3, 0.35))
	draw_rect(Rect2(rect.position + Vector2(0, 10), Vector2(rect.size.x, rect.size.y - 10)), Color("d8c0b8"), false, 2.0)
	draw_circle(rect.get_center() + Vector2(0, -6), rect.size.x * 0.22, Color("d9a8a0"))
	draw_circle(rect.get_center() + Vector2(4, 14), rect.size.x * 0.26, Color("c99890"))


func _placeholder_prop_orb(rect: Rect2, spin: float) -> void:
	var c := rect.get_center()
	var r := rect.size.x * 0.5
	draw_circle(c, r, Color("e6dcd6"))
	draw_arc(c, r, 0, TAU, 24, Color("8a2a2a"), 1.5)
	draw_circle(c + Vector2.from_angle(spin) * r * 0.4, r * 0.3, Color("5a1418"))


func _placeholder_frame(rect: Rect2, _spin: float) -> void:
	var stage := _stage()
	var flesh := Color("6e1016")
	for i in 4:
		draw_rect(stage.grow(6.0 + i * 5.0), flesh.lightened(i * 0.08) * Color(1, 1, 1, 0.9), false, 5.0)
	for pillar in [stage.position.x - 18, stage.end.x + 18]:
		for knot in 7:
			var at := Vector2(pillar, stage.position.y + stage.size.y * (0.08 + knot * 0.14))
			draw_circle(at, 11.0, flesh.lightened(0.15))
			draw_circle(at + Vector2(-3, -3), 3.0, Color("d77a6a"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0), false)


## Every placeholder says what it is standing in for.
func _tag(slot: String, rect: Rect2) -> void:
	if slot == "frame" or slot == "backdrop":
		return
	var font := ThemeDB.fallback_font
	var text := "[%s]" % slot
	draw_string(font, rect.position + Vector2(2, -4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))
