extends Node

## Visual proof that one discovered surface holding remains the same place when
## it moves from MAP to INDEX to the player's Board. This deliberately uses the
## production panels rather than drawing a diagram beside them.

const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")
const INDEX := preload("res://systems/world_index.gd")
const BOARD := preload("res://systems/pin_board.gd")
const CAST := preload("res://systems/cast_names.gd")


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
	})
	var definition: Dictionary = HOLDINGS.DEFINITIONS[2]
	var record_id := str(definition.record)
	HOLDINGS.observe(definition.at)
	var captain := CAST.ensure("derby_captain", {"faction_id": "ashline_wreckers", "faction": "Ashline Wreckers"})
	WorldHistory.register_subject("ashline_wreckers", {
		"name": "Ashline Wreckers", "kind": "faction", "role": "Road murder syndicate",
		"relations": {str(captain.id): {"kind": "command", "strength": 72}},
	})

	var layer := CanvasLayer.new()
	add_child(layer)
	var index: Control = INDEX.new()
	layer.add_child(index)
	index.open()
	index.open_blend = 1.0
	index.page_blend = 1.0
	index._jump_to_subject(record_id)
	for _settle in 30:
		await get_tree().process_frame
	await _capture("%s/ashbloom_holding_index.png" % out_dir)
	for job_id in ["holding_job:bone_yard:claim_crew", "holding_job:bone_yard:field_recovery"]:
		HOLDINGS.accept_work(job_id)
		HOLDINGS.complete_work(job_id, {"method": "visual_proof"})
	index.queue_redraw()
	for _settle in 12:
		await get_tree().process_frame
	await _capture("%s/holding_decision_open_index.png" % out_dir)

	index.queue_free()
	await get_tree().process_frame
	var board: Control = BOARD.new()
	layer.add_child(board)
	board.open()
	# Park the filed survey beside the place theory so the proof also shows that
	# ordinary red string can treat land as evidence without inventing a map-pin
	# subsystem beside the Board.
	board.pin(record_id, "record", Vector2(330, -210))
	board.pin("ashline_wreckers", "record", Vector2(80, -115))
	board.pin(str(captain.id), "photo", Vector2(-150, -150))
	board.lay_string(record_id, "ashline_wreckers")
	board.lay_string("ashline_wreckers", str(captain.id))
	board.lay_string(record_id, "theory_frequency")
	board.pan = Vector2(-100, 250)
	board.zoom = 1.0
	board.open_blend = 1.0
	for _settle in 30:
		await get_tree().process_frame
	await _capture("%s/ashbloom_holding_board.png" % out_dir)
	get_tree().quit()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_FAILED %s (%s)" % [path, error_string(error)])
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
