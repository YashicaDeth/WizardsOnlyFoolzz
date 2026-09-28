extends Control

## A locked enemy's body readout over art: left arm gone, head badly hurt,
## torso wounded. `-- --shot=PATH`.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := TextureRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.texture = load("res://art/derived/wire/collage_00.png")
	back.modulate = Color(0.45, 0.45, 0.45)
	add_child(back)
	var readout := LockReadout.new()
	add_child(readout)
	await get_tree().process_frame
	readout.show_for(size * 0.5, "Rook Sable", {"left_arm": {"health": 0.0}, "head": {"health": 12.0}, "torso": {"health": 70.0}, "right_leg": {"health": 50.0}}, AnatomyComponent.DEFAULT_ZONES)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			for _f in 30:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--shot="))
			print("SHOT ", argument.trim_prefix("--shot="))
			get_tree().quit(0)
