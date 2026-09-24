extends "res://tests/index_capture.gd"

## One visual proof for W1.4 rather than recapturing every INDEX page. Reuses
## the production-sized population from index_capture and opens the real Wire.

func _ready() -> void:
	var out_path := "res://captures/wire_faction_hours.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	_seed()
	# Noon leaves the selected Ashline account off shift while Gate Lantern
	# voices remain live, making both the personal return time and aggregate
	# traffic register visible in one frame.
	WorldHistory.world_minute = 12.0 * WorldClock.MINUTES_PER_HOUR
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var layer := CanvasLayer.new()
	add_child(layer)
	var index: Control = WORLD_INDEX.new()
	layer.add_child(index)
	index.open()
	index.page = 2
	index.cursor_follows_mouse = false
	index.cursor_at = Vector2(760, 300)
	index.refresh()
	index.queue_redraw()
	for _settle in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(out_path)
	print("WIRE_HOURS_CAPTURE_RESULT path=", out_path, " result=", result)
	get_tree().quit(0 if result == OK else 1)
