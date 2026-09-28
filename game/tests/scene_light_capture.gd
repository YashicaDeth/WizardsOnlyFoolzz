extends Node
## Loads a scene, lets it settle, screenshots it and prints mean brightness.
## `-- --scene=res://buried_city.tscn --out=P:/GameDev/Temp/x.png`

func _ready() -> void:
	var scene_path := "res://buried_city.tscn"
	var out := "P:/GameDev/Temp/scene_light.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
		elif argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	get_tree().root.size = Vector2i(1280, 720)
	var level: Node = load(scene_path).instantiate()
	add_child(level)
	for _frame in 90:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(out)
	var sum := 0.0
	var dark := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var v := image.get_pixel(x, y).get_luminance()
			sum += v
			dark += int(v < 0.04)
	var n := float((image.get_height() / 8) * (image.get_width() / 8))
	print("LIGHT %s mean=%.1f/255 near_black=%.0f%%" % [scene_path, sum / n * 255.0, dark / n * 100.0])
	get_tree().quit()
