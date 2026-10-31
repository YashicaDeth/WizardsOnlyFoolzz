extends Node3D

## Three enemies winding up around the player: behind and nearly due, to the
## left and halfway, ahead-right and just starting. `-- --shot=PATH`.

func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := TextureRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.texture = load("res://art/derived/splash_room.png")
	back.modulate = Color(0.4, 0.38, 0.38)
	layer.add_child(back)
	var compass := ThreatCompass.new()
	compass.camera = cam
	layer.add_child(compass)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			for _f in 20:
				compass.report("behind", Vector3(0.8, 0, 5), 0.95)
				compass.report("left", Vector3(-5, 0, 0.5), 0.5)
				compass.report("ahead_right", Vector3(3, 0, -4), 0.15)
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--shot="))
			print("SHOT ", argument.trim_prefix("--shot="))
			get_tree().quit(0)
