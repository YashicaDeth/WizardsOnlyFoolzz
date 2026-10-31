extends Control

## The NerveRig in three bodies side by side: whole, hurt, going. Pass
## `-- --shot=PATH` to write one PNG and quit.

const STATES := [
	{"health": 100.0, "stamina": 100.0, "blood": 1.0, "pain": 0.0, "consciousness": 100.0, "mood": "STEADY",
		"pockets": [{"label": "Marrow Dust", "kind": "substance"}]},
	{"health": 45.0, "stamina": 32.0, "blood": 0.55, "pain": 70.0, "consciousness": 70.0, "mood": "HURTING",
		"magick_unlocked": true, "magick": 0.7, "wound_regions": {"head": 0.5},
		"pockets": [{"label": "Static Hymn", "kind": "substance"}, {"label": "Liver", "kind": "organ"}, {"label": "Round", "kind": "ammo"}]},
	{"health": 9.0, "stamina": 6.0, "blood": 0.2, "pain": 95.0, "consciousness": 22.0, "mood": "FADING",
		"wound_regions": {"head": 0.85}, "pockets": []},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := TextureRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.texture = load("res://art/derived/splash_room.png")
	back.modulate = Color(0.35, 0.33, 0.33)
	add_child(back)
	await get_tree().process_frame
	var w := size.x / STATES.size()
	for i in STATES.size():
		var rig := NerveRig.new()
		add_child(rig)
		rig.set_anchors_preset(Control.PRESET_TOP_LEFT)
		rig.position = Vector2(w * i, 0)
		rig.size = Vector2(w, size.y)
		rig.set_state(STATES[i])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			for _frame in 30:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--shot="))
			print("SHOT ", argument.trim_prefix("--shot="))
			get_tree().quit(0)
