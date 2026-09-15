class_name WofLockup
extends RefCounted

## The store lockup: the seal, the name, and sigils woven through the letters.
##
## Greg, signing up to Steamworks and itch: *"i need this be the wizardsonlyfoolz
## logo with the sigil hand thing with sigils intertwined in the text."*
##
## Two things separate this from `wof_mark.gd`, which draws the seal alone.
##
## **The weave.** Not a seal behind the words — a backdrop is what every band
## logo does and it reads as a sticker on a poster. The strokes are drawn in two
## passes with the letters between them: most of each sigil goes down first and
## is overprinted by the type, and a chosen few strokes are laid *over* the
## letters afterwards. That is what makes it read as threaded through rather than
## printed under, and it is the whole difference between the two.
##
## **It fits its frame.** A store capsule is 460x215 and a library capsule is
## 600x900, and the same lockup has to survive both. So the arrangement is chosen
## from the aspect ratio rather than authored per size, and every measurement is
## a fraction of the frame.

const MARK := preload("res://systems/wof_mark.gd")
const CellOutzType := preload("res://systems/celloutz_type.gd")

const NAME_TOP := "WIZARDS ONLY"
const NAME_BOTTOM := "FOOLZ"

## How many sigils are woven through the name. Five at full strength buried the
## words entirely — on a 231x87 small capsule the name has to read before
## anything else does, so the sigils are texture and the name is the subject.
const WEAVE_COUNT := 3
## What fraction of each sigil's strokes are laid over the type rather than under.
const OVER_SHARE := 0.22
## How strongly the weave prints. Under the letters it can afford to be seen;
## over them it is a thread crossing a word and nothing more.
const UNDER_ALPHA := 0.55
const OVER_ALPHA := 0.30


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## One sigil's strokes, placed and scaled into a box. Returned as screen-space
## polylines so both the under-pass and the over-pass draw the identical
## geometry and the weave cannot drift between them.
static func _sigil_lines(seed_value: int, centre: Vector2, radius: float, complexity: int) -> Array:
	var out: Array = []
	for stroke: PackedVector2Array in CellOutzType.seal_strokes(seed_value, complexity):
		var line := PackedVector2Array()
		for point: Vector2 in stroke:
			line.append(centre + point * radius)
		out.append(line)
	return out


## The weave, drawn in one pass or the other. `over` picks which share of the
## strokes this call is responsible for, so the caller can put the type between
## the two.
static func _draw_weave(canvas: CanvasItem, band: Rect2, colour: Color, seed_value: int, over: bool, width: float) -> void:
	var rng := _rng(seed_value)
	for index in WEAVE_COUNT:
		# Spread along the band, drifting off the centre line so the row of
		# sigils does not read as a dotted rule.
		var along := (float(index) + 0.5) / float(WEAVE_COUNT)
		var centre := Vector2(
			band.position.x + band.size.x * along,
			band.position.y + band.size.y * (0.42 + rng.randf_range(-0.16, 0.16))
		)
		var radius := band.size.y * rng.randf_range(0.26, 0.40)
		var lines := _sigil_lines(seed_value + index * 7919, centre, radius, 5 + (index % 3))
		var cut := int(round(float(lines.size()) * OVER_SHARE))
		for line_index in lines.size():
			# The last `cut` strokes of each sigil are the ones that cross the
			# letters. Chosen by index rather than at random so the two passes
			# agree about which is which.
			var is_over := line_index >= lines.size() - cut
			if is_over != over:
				continue
			var shade := colour
			shade.a = OVER_ALPHA if over else UNDER_ALPHA
			canvas.draw_polyline(lines[line_index], shade, width * (0.7 if over else 1.0), true)


## The whole lockup, fitted to `rect`. The arrangement comes from the shape of
## the frame: wide capsules put the seal beside the name, tall ones stack it
## above, and a square splits the difference.
static func draw_lockup(canvas: CanvasItem, rect: Rect2, ink: Color, weave_ink: Color, seed_value := 1312) -> void:
	var aspect := rect.size.x / maxf(1.0, rect.size.y)
	if aspect > 1.6:
		_draw_beside(canvas, rect, ink, weave_ink, seed_value)
	else:
		_draw_stacked(canvas, rect, ink, weave_ink, seed_value)


## Wide: seal on the left, name to the right of it. Steam's header and main
## capsules are both this shape and they are the two a person actually sees.
static func _draw_beside(canvas: CanvasItem, rect: Rect2, ink: Color, weave_ink: Color, seed_value: int) -> void:
	var pad := rect.size.y * 0.10
	var seal_radius := (rect.size.y - pad * 2.0) * 0.42
	var seal_centre := Vector2(rect.position.x + pad + seal_radius, rect.get_center().y)
	MARK.draw_mark(canvas, seal_centre, seal_radius, ink, seed_value)

	var text_left := seal_centre.x + seal_radius * 1.42
	var text_box := Rect2(
		Vector2(text_left, rect.position.y + pad),
		Vector2(rect.end.x - pad - text_left, rect.size.y - pad * 2.0)
	)
	_draw_name(canvas, text_box, ink, weave_ink, seed_value)


## Tall and square: seal above, name under it.
static func _draw_stacked(canvas: CanvasItem, rect: Rect2, ink: Color, weave_ink: Color, seed_value: int) -> void:
	var pad := rect.size.x * 0.08
	var seal_radius := minf(rect.size.x * 0.30, rect.size.y * 0.26)
	var seal_centre := Vector2(rect.get_center().x, rect.position.y + pad + seal_radius * 1.15)
	MARK.draw_mark(canvas, seal_centre, seal_radius, ink, seed_value)

	var top := seal_centre.y + seal_radius * 1.35
	var text_box := Rect2(
		Vector2(rect.position.x + pad, top),
		Vector2(rect.size.x - pad * 2.0, rect.end.y - pad - top)
	)
	_draw_name(canvas, text_box, ink, weave_ink, seed_value)


## The name, with the weave laid around it. Two lines because "WIZARDS ONLY" and
## "FOOLZ" is the joke, and it only lands if the break is where the sentence
## turns.
static func _draw_name(canvas: CanvasItem, box: Rect2, ink: Color, weave_ink: Color, seed_value: int) -> void:
	# Fit by measurement rather than by a guessed cap height: width is linear in
	# cap, so one measurement gives the scale exactly. Guessing overran the
	# frame and clipped both words the first time this was built.
	var room := box.size.x
	# The name is the subject. It takes the frame it needs and the weave fits
	# around it, rather than the other way round.
	var top_cap := box.size.y * 0.40
	var measured: float = CellOutzType.width(NAME_TOP, top_cap, 2.0, 1.0)
	if measured > 0.0:
		top_cap *= minf(1.0, room / measured)
	var bottom_cap := top_cap * 1.5
	var bottom_measured: float = CellOutzType.width(NAME_BOTTOM, bottom_cap, 6.0, 1.0)
	if bottom_measured > 0.0:
		bottom_cap *= minf(1.0, room / bottom_measured)

	var top_w: float = CellOutzType.width(NAME_TOP, top_cap, 2.0, 1.0)
	var bottom_w: float = CellOutzType.width(NAME_BOTTOM, bottom_cap, 6.0, 1.0)
	var block_height := top_cap * 1.55 + bottom_cap
	var top_y := box.position.y + (box.size.y - block_height) * 0.5
	var bottom_y := top_y + top_cap * 1.55

	var band := Rect2(box.position.x, top_y - top_cap * 0.25,
		box.size.x, block_height + top_cap * 0.5)
	var weave_width := maxf(1.0, box.size.y * 0.008)

	# Under the letters.
	_draw_weave(canvas, band, weave_ink, seed_value, false, weave_width)
	CellOutzType.draw_worn(canvas, Vector2(box.get_center().x - top_w * 0.5, top_y), NAME_TOP, top_cap, ink, 0.32, 2.0)
	CellOutzType.draw_worn(canvas, Vector2(box.get_center().x - bottom_w * 0.5, bottom_y), NAME_BOTTOM, bottom_cap, ink, 0.42, 6.0)
	# And over them. This pass is the whole point: it is what makes the sigils
	# read as threaded through the name rather than printed behind it.
	_draw_weave(canvas, band, weave_ink, seed_value, true, weave_width)
