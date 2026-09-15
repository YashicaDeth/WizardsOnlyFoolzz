extends Node

## Renders the Wizards Only Fools seal to PNGs.
##
## Derived art, so it obeys the house rule: nothing is hand-placed and the whole
## sheet rebuilds from this script and a seed. Source photographs in
## `Art Collections` are read-only and are not touched — the seal is drawn from
## the sign in them, not cut out of them.
##
##   Godot --headless --path game res://tests/logo_capture.tscn -- --out=DIR

const MARK := preload("res://systems/wof_mark.gd")
const CellOutzType := preload("res://systems/celloutz_type.gd")

var out_dir := "P:/GameDev/Temp"
var _plates: Array = []


class Plate extends Control:
	var mode := "seal"
	var ink := Color.WHITE
	var ground := Color.BLACK
	var mark_seed := 1312

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), ground)
		var MarkClass := load("res://systems/wof_mark.gd")
		var Type := load("res://systems/celloutz_type.gd")
		if mode == "seal":
			MarkClass.draw_mark(self, size * 0.5, minf(size.x, size.y) * 0.40, ink, mark_seed)
			return
		# The lockup: seal above, name stacked under it. Two lines, because
		# "WIZARDS ONLY" and "FOOLS" is the joke and it only lands if the break
		# is where the sentence turns.
		var radius := size.y * 0.26
		var centre := Vector2(size.x * 0.5, size.y * 0.36)
		MarkClass.draw_mark(self, centre, radius, ink, mark_seed)
		var top := "WIZARDS ONLY"
		var bottom := "FOOLS"
		# Fit the type to the plate rather than guessing a cap height. Width is
		# linear in cap, so one measurement gives the scale exactly; guessing gave
		# a line 4% wider than the plate and clipped both ends of both words.
		var room := size.x * 0.82
		var top_cap := size.y * 0.105
		var measured: float = Type.width(top, top_cap, 2.0, 1.0)
		if measured > 0.0:
			top_cap *= minf(1.0, room / measured)
		# FOOLS is the punchline, so it is set larger — but to the same measured
		# ceiling, not to a multiplier that can overrun on its own.
		var bottom_cap := top_cap * 1.55
		var bottom_measured: float = Type.width(bottom, bottom_cap, 6.0, 1.0)
		if bottom_measured > 0.0:
			bottom_cap *= minf(1.0, room / bottom_measured)
		var top_w: float = Type.width(top, top_cap, 2.0, 1.0)
		var bottom_w: float = Type.width(bottom, bottom_cap, 6.0, 1.0)
		var y := centre.y + radius + size.y * 0.09
		Type.draw_worn(self, Vector2(size.x * 0.5 - top_w * 0.5, y), top, top_cap, ink, 0.35, 2.0)
		Type.draw_worn(self, Vector2(size.x * 0.5 - bottom_w * 0.5, y + top_cap * 1.6), bottom, bottom_cap, ink, 0.45, 6.0)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)

	_plates = [
		{"name": "wof_seal_bone", "size": Vector2i(1024, 1024), "mode": "seal", "ink": MARK.BONE, "ground": MARK.VOID, "seed": 1312},
		{"name": "wof_seal_blood", "size": Vector2i(1024, 1024), "mode": "seal", "ink": MARK.ARTERIAL, "ground": MARK.VOID, "seed": 77},
		{"name": "wof_seal_spore", "size": Vector2i(1024, 1024), "mode": "seal", "ink": MARK.SPORE, "ground": MARK.VOID, "seed": 909},
		{"name": "wof_seal_invert", "size": Vector2i(1024, 1024), "mode": "seal", "ink": MARK.VOID, "ground": MARK.BONE, "seed": 1312},
		{"name": "wof_mark_128", "size": Vector2i(128, 128), "mode": "seal", "ink": MARK.BONE, "ground": MARK.VOID, "seed": 1312},
		{"name": "wof_lockup", "size": Vector2i(1200, 1500), "mode": "lockup", "ink": MARK.BONE, "ground": MARK.VOID, "seed": 1312},
	]

	for plate in _plates:
		await _shoot(plate)
	print("LOGO SHEET DONE: ", out_dir)
	get_tree().quit(0)


func _shoot(plate: Dictionary) -> void:
	var window := get_window()
	window.size = plate["size"]
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var view := Plate.new()
	view.mode = str(plate["mode"])
	view.ink = plate["ink"]
	view.ground = plate["ground"]
	view.mark_seed = int(plate["seed"])
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(view)
	view.queue_redraw()

	for _settle in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, str(plate["name"])]
	if image.save_png(path) != OK:
		print("FAILED: ", path)
	else:
		print("  wrote ", path, "  ", image.get_width(), "x", image.get_height())
	layer.queue_free()
	await get_tree().process_frame
