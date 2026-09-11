extends Node

## Draws every site so the layouts can be compared side by side. If two of them
## look alike, I2.2 has failed and only a picture will say so.

var index := 0
var clock := 0.0
var out_dir := "P:/GameDev/Temp/web"
var canvas: Control


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var layer := CanvasLayer.new()
	add_child(layer)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_paint)
	layer.add_child(canvas)
	_run()


func _process(delta: float) -> void:
	clock += delta
	canvas.queue_redraw()


func _paint() -> void:
	var entry: Dictionary = BrokenWeb.SITES[index]
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("06080a"))
	var page := Rect2(Vector2(140, 70), canvas.size - Vector2(280, 150))
	BrokenWeb.draw_site(canvas, page, entry, clock)
	CellOutzType.draw_text(canvas, Vector2(140, 40), str(entry.url).to_upper(), 13.0, Color("b4da48"), 1.6)


func _run() -> void:
	for site in BrokenWeb.SITES.size():
		index = site
		for _settle in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/site_%s.png" % [out_dir, str(BrokenWeb.SITES[site].id)]
		image.save_png(path)
		print("CAPTURED: ", path)
	get_tree().quit()
