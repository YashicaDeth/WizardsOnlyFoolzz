extends Control

## The downed-person form, open on a sample body over real art, so its type can
## be looked at. `-- --shot=PATH` writes one PNG and quits.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := TextureRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.texture = load("res://art/derived/wire/collage_00.png")
	back.modulate = Color(0.5, 0.5, 0.5)
	add_child(back)
	var form := DownedResolution.new()
	add_child(form)
	await get_tree().process_frame
	form.open_for("Wren Ashby", {
		"blood": 2350, "blood_capacity": 5000, "consciousness": 38, "pain": 81, "bleed_rate": 3.4,
		"zones": {"head": {"health": 40}, "torso": {"health": 12}, "left_arm": {"health": 0}},
		"organs": {"heart": {}, "left_lung": {"ruptured": true}, "liver": {}, "spine": {}},
		"wounds": [{}, {}, {}],
	})
	form.set_world_anchor(Vector2(640, 250))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			for _frame in 40:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--shot="))
			print("SHOT ", argument.trim_prefix("--shot="))
			get_tree().quit(0)
