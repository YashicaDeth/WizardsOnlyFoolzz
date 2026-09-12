extends Node

## A2.9 v2. "One plate for every page; the dossier, the Wire and the pyramid
## should not be printed on the same substrate." `_draw_plate()` drew the
## same paper grime under FILE, PYRAMID, BODY and WIRE alike - the physical
## registry (the shape, the tabs, the tape) stays one shared object on
## purpose, but WIRE now prints on `black_mirror.gd`'s glass instead of
## paper, since that page is reading the surviving internet and nothing
## else here is.
##
## Nothing about `_draw_plate()` is queryable without drawing it, so this
## renders both substrates to an Image and compares pixels directly rather
## than reading a flag - the same standard a screenshot review would use.
##
## Needs a real window: `get_viewport().get_texture().get_image()` reads
## back blank in this environment's `--headless` mode (the renderer never
## actually draws a frame to read), so run this one windowed, the same way
## the `*_capture.gd` scripts already have to be.

const WORLD_INDEX := preload("res://systems/world_index.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _average_colour(image: Image, rect: Rect2i) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	var step := 4
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			total += image.get_pixel(x, y)
			count += 1
			x += step
		y += step
	return total / float(maxi(1, count))


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var index: Control = WORLD_INDEX.new()
	layer.add_child(index)
	index.size = Vector2(1280, 720)
	index.open()

	# A patch of the plate with nothing else drawn over it on either page —
	# just under the header, left of the rail — so the comparison is the
	# substrate itself rather than whatever content happens to sit there.
	var sample := Rect2i(64, 116, 40, 40)

	index.page = index.PAGES.find("FILE")
	for _settle in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var paper := _average_colour(get_viewport().get_texture().get_image(), sample)

	index.page = index.PAGES.find("WIRE")
	for _settle in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var glass := _average_colour(get_viewport().get_texture().get_image(), sample)

	var difference := absf(paper.r - glass.r) + absf(paper.g - glass.g) + absf(paper.b - glass.b)
	_check(difference > 0.05, "the WIRE plate reads as a visibly different surface from the FILE plate (delta %.3f)" % difference)
	_check(glass.r + glass.g + glass.b < paper.r + paper.g + paper.b, "and it is darker - black glass rather than grimed paper")

	print("INDEX_SUBSTRATE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
