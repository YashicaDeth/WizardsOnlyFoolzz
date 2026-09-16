extends Node

## Visual evidence for I3.1/I3.2: one settled page, full mechanical occlusion,
## and the destination after the shutter has left the glass.

const HANDHELD := preload("res://systems/handheld_device.gd")


func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(path) != OK:
		print("CAPTURE_FAILED ", path)
		return false
	print("CAPTURED: ", path)
	return true


func _ready() -> void:
	var out_dir := "res://captures"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor",
		"faction": "Unbound", "status": "awake",
		"memory": "The mirror remembered a route that the road denied.",
	})
	WorldHistory.register_subject("mara_voss", {
		"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain",
		"faction": "Ashline Wreckers", "status": "active",
		"memory": "You put her into the wall on the second lap.",
	})
	WorldHistory.record_event("derby_round_won", {"subject": "player", "rival": "mara_voss"})

	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	device.open_device()
	device.stand_at(Vector2(-150.0, 10.0))
	for _settle in 45:
		await get_tree().process_frame
	if not await _capture("%s/i3_1_shared_page_grammar.png" % out_dir):
		get_tree().quit(1)
		return

	device.set_process(false)
	device.set_mode("MAP")
	device._advance_page_transition(device.PAGE_TRANSITION_SECONDS * 0.5)
	device._process(0.0)
	device.queue_redraw()
	device._overlay.queue_redraw()
	await get_tree().process_frame
	if not await _capture("%s/i3_2_page_shutter.png" % out_dir):
		get_tree().quit(1)
		return

	device._advance_page_transition(device.PAGE_TRANSITION_SECONDS * 0.5)
	device._process(0.0)
	device.queue_redraw()
	device._overlay.queue_redraw()
	for _settle in 8:
		await get_tree().process_frame
	if not await _capture("%s/i3_2_page_arrival.png" % out_dir):
		get_tree().quit(1)
		return
	get_tree().quit()
