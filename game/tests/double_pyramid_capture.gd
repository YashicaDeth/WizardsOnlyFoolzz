extends Node

## AI1. The double pyramid, populated on both sides: the player with real
## command standing in an Ascent faction and a real grudge/command edge into
## a Descent one, so both cones draw a real roster instead of the
## "nothing claimed yet" placeholder.

const WORLD_INDEX := preload("res://systems/world_index.gd")


func _seed() -> void:
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound",
		"elo": 1000, "status": "awake", "memory": "The derby door opened into Limbo.",
		"anatomy": {"blood_type": "unresolved"},
		"relations": {
			"wizardsonlyfoolz": {"kind": "command", "strength": 62},
			"ashline_wreckers": {"kind": "known", "strength": 40},
		},
	})
	WorldHistory.register_subject("wizardsonlyfoolz", {
		"name": "Wizards Only Fools", "kind": "faction", "role": "The Ascent's own recruiting arm", "threat": "LOW",
		"territory": "Wherever the signal reaches", "doctrine": "Climb or be climbed over.",
	})
	WorldHistory.register_subject("moth_jerrow", {
		"name": "Moth Jerrow", "kind": "person", "role": "Fungus shepherd", "faction": "Wizards Only Fools", "faction_id": "wizardsonlyfoolz",
		"elo": 1204, "status": "active", "memory": "Claims the great caps remember rain.",
		"relations": {"player": {"kind": "command", "strength": 20}},
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
	var path := "%s/double_pyramid.png" % out_dir
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)
	get_tree().quit()
