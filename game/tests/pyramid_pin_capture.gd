extends Node

## AI2.4. Windowed-only visual check: does the pin tag actually clear the
## rank label and the buy-in text on a real, populated tier row, the way
## `pyramid_pin_test.gd`'s headless data check cannot show by itself.

const WORLD_INDEX := preload("res://systems/world_index.gd")
const PIN_BOARD := preload("res://systems/pin_board.gd")


func _seed() -> void:
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound",
		"elo": 1000, "status": "awake", "memory": "The derby door opened into Limbo.",
		"anatomy": {"blood_type": "unresolved"},
		"relations": {
			"ashline_wreckers": {"kind": "known", "strength": 40},
		},
	})
	WorldHistory.register_subject("mara_voss", {
		"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers",
		"elo": 1180, "grudge": 41, "status": "active", "memory": "You put her into the wall on the second lap.",
		"relations": {"player": {"kind": "hunts", "strength": 8}, "ashline_wreckers": {"kind": "command", "strength": 72}},
	})
	WorldHistory.register_subject("ashline_wreckers", {
		"name": "Ashline Wreckers", "kind": "faction", "role": "Road murder syndicate", "threat": "SEVERE",
		"territory": "Bone Yard / Burnt Highway", "doctrine": "Rank is won by remembered impact.",
	})


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	_seed()
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var board := PIN_BOARD.new()
	add_child(board)
	await get_tree().process_frame
	WorldHistory.record_event("carried_part", {"subject": "mara_voss"})
	board.pin("mara_voss", "person")
	board.lay_string("mara_voss", "theory_ownership")
	board.publish("theory_ownership")

	var layer := CanvasLayer.new()
	add_child(layer)
	var index: Control = WORLD_INDEX.new()
	layer.add_child(index)
	index.size = Vector2(1280, 720)
	index.open()
	index.page = index.PAGES.find("PYRAMID")
	for _settle in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/pyramid_pin.png" % out_dir
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)
	get_tree().quit()
