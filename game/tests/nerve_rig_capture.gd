extends Node

## The Nerve Rig at every state it has to read in, side by side: whole,
## wounded and bleeding, winded, in agony and fading, and ritual-lit. Each
## panel is its own rig with its own size, so the column is judged at the
## scale the Hunt draws it rather than blown up.

const STATES := [
	{"tag": "WHOLE", "health": 100.0, "blood": 1.0, "stamina": 100.0, "pain": 0.0, "consciousness": 100.0},
	{"tag": "WOUNDED + BLEEDING", "health": 45.0, "blood": 0.55, "stamina": 70.0, "pain": 40.0, "consciousness": 90.0},
	{"tag": "WINDED", "health": 90.0, "blood": 0.95, "stamina": 18.0, "pain": 10.0, "consciousness": 100.0},
	{"tag": "AGONY + FADING", "health": 20.0, "blood": 0.3, "stamina": 40.0, "pain": 92.0, "consciousness": 35.0, "wound_regions": {"head": 0.6}},
	{"tag": "MAGICK", "health": 80.0, "blood": 0.9, "stamina": 85.0, "pain": 5.0, "consciousness": 100.0, "magick_unlocked": true, "magick": 0.8},
]
const PANEL := Vector2(380, 640)


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	var name := "nerve_rig"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		if argument.begins_with("--name="):
			name = argument.trim_prefix("--name=")
	get_window().size = Vector2i(int(PANEL.x) * STATES.size(), int(PANEL.y))
	var back := ColorRect.new()
	back.color = Color("1b1d1c")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var rigs: Array = []
	for index in STATES.size():
		var state: Dictionary = STATES[index]
		var panel := Control.new()
		panel.position = Vector2(PANEL.x * index, 0)
		panel.size = PANEL
		panel.clip_contents = true
		back.add_child(panel)
		var rig := NerveRig.new()
		panel.add_child(rig)
		rig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var values := state.duplicate()
		values.erase("tag")
		values["pockets"] = [{"label": "gun", "kind": "weapon"}, {"label": "ampoule", "kind": "drug"}]
		rig.set_state(values)
		rigs.append(rig)
		var label := Label.new()
		label.text = str(state.tag)
		label.position = Vector2(12, PANEL.y - 30)
		label.add_theme_color_override("font_color", Color("e8e1d2"))
		panel.add_child(label)
	# Run the clocks forward so drips fall and pulses sit mid-cord.
	for _frame in 150:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	if image.save_png(path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
	get_tree().quit()
