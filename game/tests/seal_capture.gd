extends Node

class SealSpecimen extends Control:
	const VOID := Color("060b09")
	const INK := Color("dce6ba")
	const ACID := Color("b4da48")
	const BLOOD := Color("c81f16")
	const SPECIMEN := [
		[[-0.72, -0.72], [0.0, -1.0], [0.72, -0.72]],
		[[-0.72, -0.72], [-0.5, 0.68], [0.0, 1.0], [0.5, 0.68], [0.72, -0.72]],
		[[-0.42, 0.02], [0.42, 0.02]],
		[[-0.24, -0.45], [0.0, -0.22], [0.24, -0.45]],
	]

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), VOID)
		var centre := size * 0.5
		draw_arc(centre, 205.0, 0.0, TAU, 48, INK * Color(1, 1, 1, 0.16), 1.0)
		for angle in 8:
			var direction := Vector2.from_angle(TAU * float(angle) / 8.0)
			draw_line(centre + direction * 188.0, centre + direction * 218.0, INK * Color(1, 1, 1, 0.26), 1.0)
		CellOutzType.draw_seal(self, centre, SPECIMEN, 176.0, ACID, 0.0, 4.0)
		CellOutzType.draw_seal(self, centre, [[[-0.12, -0.22], [0.12, 0.22]], [[0.12, -0.22], [-0.12, 0.22]]], 176.0, BLOOD, 0.0, 2.0)
		CellOutzType.draw_stamped(self, Vector2(54, 42), "RITUAL VOCABULARY", 23.0, ACID, BLOOD * Color(1, 1, 1, 0.35), 2.2)
		CellOutzType.draw_condensed(self, Vector2(54, size.y - 58), "AUTHORED STROKES / NO IMPORTED SYMBOL SET", 11.0, INK * Color(1, 1, 1, 0.6), 1.0)


func _ready() -> void:
	var out_path := "P:/GameDev/Temp/seal-vocabulary.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	var layer := CanvasLayer.new()
	add_child(layer)
	var specimen := SealSpecimen.new()
	layer.add_child(specimen)
	specimen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _settle in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", out_path, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
