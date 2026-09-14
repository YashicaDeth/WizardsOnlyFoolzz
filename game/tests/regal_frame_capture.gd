extends Node2D

## Renders the frame over the real backdrop, one PNG per variant, plus one with
## the frame off for comparison. Stroke data and shader maths that compile are
## not the same thing as a border that reads — and this one is entirely a
## judgement about how it looks, so it has to be looked at.

const BACKDROP := preload("res://systems/splash_backdrop.gd")
const FRAME := preload("res://systems/regal_frame.gd")

var backdrop: SplashBackdrop
var frame: RegalFrame


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)

	var layer := CanvasLayer.new()
	add_child(layer)

	backdrop = BACKDROP.new()
	backdrop.reveal = 1.0
	# Part-way through the attack, so the capture shows the frame against both of
	# Greg's pictures at once rather than only the calm one.
	backdrop.attack = 0.42
	layer.add_child(backdrop)

	frame = FRAME.new()
	frame.reveal = 1.0
	frame.fit_to_photo()
	layer.add_child(frame)

	# Frame off first, so the hard rectangular cut is on record next to the fix
	# rather than described.
	frame.visible = false
	await _shoot("res://captures/a1_8_frame_off.png")
	frame.visible = true

	for variant: String in ["reliquary", "offering", "ossuary"]:
		frame.set_variant(variant)
		await _shoot("res://captures/a1_8_frame_%s.png" % variant)

	print("REGAL_FRAME_CAPTURE_RESULT saved=4")
	get_tree().quit(0)


func _shoot(path: String) -> void:
	# Several frames: the shader animates off `clock`, and the first frame after
	# a parameter change can still carry the previous material state.
	for _settle in 6:
		await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURED: ", path)
