extends Node

## A1.6 v2. The pairs Greg named, set twice: on the grid as the face was, and
## kerned as it is now. If the difference is not visible in the capture the work
## did not happen.

const TYPE := preload("res://systems/celloutz_type.gd")

var plate: Control


func _ready() -> void:
	var out := "P:/GameDev/Temp/kerning.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	plate = Control.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.draw.connect(_paint)
	add_child(plate)
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(out) == OK else "FAILED: ", out)
	# And the numbers, because "it looks tighter" is not a measurement.
	for pair in ["AV", "TA", "AT", "VA", "LT", "WA", "HH", "OO", "MN"]:
		print("%s closes by %.3f grid units" % [pair, TYPE.kern(pair[0], pair[1])])
	get_tree().quit(0)


func _paint() -> void:
	plate.draw_rect(Rect2(Vector2.ZERO, plate.size), Color("14120d"))
	var ink := Color("ead4ad")
	var faint := Color("6d6354")
	var samples = ["AVATAR", "TAVERN", "WAVY LAW", "OSSUARY WORKS", "MARA VOSS"]
	var y := 96.0
	for line in samples:
		# Ungrided, for comparison: the same string with every kern forced to
		# zero, drawn in the dim colour above the real one.
		_flat(Vector2(80, y), line, 46.0, faint)
		TYPE.draw_text(plate, Vector2(80, y + 66.0), line, 46.0, ink, 0.0)
		y += 128.0
	TYPE.draw_condensed(plate, Vector2(80, 40), "ON THE GRID  /  KERNED", 15.0, faint, 3.0)


## The old behaviour, reproduced here rather than kept in the face: every glyph
## on the grid, no pair closed.
func _flat(at: Vector2, text: String, cap: float, color: Color) -> void:
	var scale := cap / TYPE.GRID.y
	var advance := TYPE.GRID.x * scale + cap * 0.26
	var cursor := at.x
	for index in text.length():
		var glyph := text.substr(index, 1).to_upper()
		if TYPE.GLYPHS.has(glyph):
			for stroke in TYPE.GLYPHS[glyph]:
				var points := PackedVector2Array()
				for point in stroke:
					points.append(Vector2(cursor + float(point[0]) * scale, at.y + float(point[1]) * scale))
				if points.size() == 2:
					plate.draw_line(points[0], points[1], color, maxf(1.0, cap * 0.13))
				else:
					plate.draw_polyline(points, color, maxf(1.0, cap * 0.13))
		cursor += advance
