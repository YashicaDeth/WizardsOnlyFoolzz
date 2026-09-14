extends Node2D

## The glass over the real backdrop and frame, one PNG per register. Entirely a
## judgement about readability and feel, so it has to be looked at rather than
## reasoned about — and the "still playable" half of the brief is exactly the
## half that only a rendered frame can settle.

const BACKDROP := preload("res://systems/splash_backdrop.gd")
const FRAME := preload("res://systems/regal_frame.gd")
const GLASS := preload("res://systems/crt_glass.gd")

var glass: CrtGlass


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	var layer := CanvasLayer.new()
	add_child(layer)

	var backdrop: SplashBackdrop = BACKDROP.new()
	backdrop.reveal = 1.0
	backdrop.attack = 0.42
	layer.add_child(backdrop)

	var frame: RegalFrame = FRAME.new()
	frame.reveal = 1.0
	frame.fit_to_photo()
	layer.add_child(frame)

	glass = GLASS.new()
	glass.reveal = 1.0
	layer.add_child(glass)

	# Type over the top, at the size the menu actually sets it, because the only
	# question that matters here is whether the words survive the curve.
	var probe := Label.new()
	probe.text = "CONTINUE RUNS\nNEW GAME  //  SPLIT THE WORLD\nGORE SANDBOX\nSETTINGS"
	probe.position = Vector2(48, 200)
	probe.add_theme_font_size_override("font_size", 22)
	layer.add_child(probe)

	for variant: String in ["flat", "panel", "aperture", "failing"]:
		glass.set_variant(variant)
		glass.reveal = 1.0
		await _shoot("res://captures/a1_9_glass_%s.png" % variant)

	print("CRT_GLASS_CAPTURE_RESULT saved=4")
	get_tree().quit(0)


func _shoot(path: String) -> void:
	for _settle in 6:
		await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED: ", path)
