extends Node

## dec-89. The brain screen with all four disciplines on the chip: empty with
## Duelist in focus, then Duelist and Shade slotted.
## Windowed only: AgentHub/render_one.cmd brain_screen_capture --shots=DIR

var shots := "P:/GameDev/Temp/dec89"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("BRAIN_SCREEN_CAPTURE headless draws nothing; use AgentHub/render_one.cmd")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	var tree := get_tree()
	tree.create_timer(60.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var screen := BrainScreen.new()
	add_child(screen)
	screen.focus = 2
	await _settle()
	_save("brain_screen_four_empty")
	screen.confirm()
	screen.focus = 3
	screen.confirm()
	await _settle()
	_save("brain_screen_four_duelist_shade")
	print("BRAIN_SCREEN_CAPTURE_RESULT shots=%s" % shots)
	tree.quit()


func _settle() -> void:
	for _frame in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(tag: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, tag])
