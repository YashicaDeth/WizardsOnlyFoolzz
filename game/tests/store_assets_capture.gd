extends Node

## Store art for Steamworks and itch.io.
##
## Greg is signing up to both, so these are the real required sizes rather than
## a logo somebody has to crop. Every plate is the same `WofLockup` fitted to a
## different frame — the arrangement comes from the aspect ratio, so a 460x215
## header and a 600x900 library capsule are one drawing and not two.
##
## Derived art: nothing hand-placed, the whole sheet rebuilds from this script
## and a seed, and the source photographs in `Art Collections` are untouched.

const MARK := preload("res://systems/wof_mark.gd")
const LOCKUP := preload("res://systems/wof_lockup.gd")

## Name, width, height. Steam's list first, then itch, then the square everybody
## wants for an avatar.
const PLATES := [
	["steam_header_capsule_460x215", 460, 215],
	["steam_small_capsule_231x87", 231, 87],
	["steam_main_capsule_616x353", 616, 353],
	["steam_vertical_capsule_374x448", 374, 448],
	["steam_library_capsule_600x900", 600, 900],
	["steam_library_hero_1920x620", 1920, 620],
	["itch_cover_630x500", 630, 500],
	["itch_banner_960x320", 960, 320],
	["square_1024", 1024, 1024],
]

var out_dir := "P:/GameDev/Temp/store"


class Plate extends Control:
	var ground := Color.BLACK
	var ink := Color.WHITE
	var weave := Color.WHITE
	var plate_seed := 1312

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), ground)
		var Lockup := load("res://systems/wof_lockup.gd")
		Lockup.draw_lockup(self, Rect2(Vector2.ZERO, size), ink, weave, plate_seed)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)

	for plate: Array in PLATES:
		await _shoot(str(plate[0]), int(plate[1]), int(plate[2]))
	print("STORE SHEET DONE: ", out_dir)
	get_tree().quit(0)


func _shoot(plate_name: String, width: int, height: int) -> void:
	get_window().size = Vector2i(width, height)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var view := Plate.new()
	view.ground = MARK.VOID
	view.ink = MARK.BONE
	# The weave sits in blood, under and over bone type. Two colours rather than
	# one, because a weave in the same ink as the letters reads as a smudge on
	# them at capsule size.
	view.weave = MARK.ARTERIAL
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(view)
	view.queue_redraw()

	for _settle in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, plate_name]
	if image.save_png(path) != OK:
		print("FAILED: ", path)
	else:
		print("  wrote %s  %dx%d" % [plate_name, image.get_width(), image.get_height()])
	layer.queue_free()
	await get_tree().process_frame
