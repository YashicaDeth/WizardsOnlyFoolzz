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
	if "--reel" in OS.get_cmdline_user_args():
		_reel()
		return
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


## For the movie writer: one rig, twice size, taking a beating and coming
## back. `--write-movie clip.avi --fixed-fps 30 ... -- --reel`.
func _reel() -> void:
	get_window().size = Vector2i(1280, 720)
	var back := ColorRect.new()
	back.color = Color("101213")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var holder := Control.new()
	holder.size = Vector2(700, 440)
	holder.scale = Vector2(1.55, 1.55)
	holder.position = Vector2(-180, 8)
	back.add_child(holder)
	var rig := NerveRig.new()
	holder.add_child(rig)
	rig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var state := {"health": 100.0, "blood": 1.0, "stamina": 100.0, "pain": 0.0, "consciousness": 100.0}
	var beats := [
		[45, {}],
		[40, {"stamina": 25.0}],
		[30, {"health": 62.0, "pain": 45.0, "blood": 0.8}],
		[30, {"health": 30.0, "pain": 80.0, "blood": 0.5, "consciousness": 60.0}],
		[60, {"stamina": 10.0}],
		[90, {"health": 70.0, "pain": 20.0, "blood": 0.75, "stamina": 70.0, "consciousness": 95.0}],
		[60, {"health": 100.0, "pain": 0.0, "blood": 1.0, "stamina": 100.0, "consciousness": 100.0}],
	]
	for beat in beats:
		var target: Dictionary = beat[1]
		var frames: int = beat[0]
		for frame in frames:
			for key in target:
				state[key] = lerpf(float(state[key]), float(target[key]), 0.12)
			rig.set_state(state)
			await get_tree().process_frame
	get_tree().quit()
