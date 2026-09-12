extends Node

## AR1 / AV1. Windowed-only visual check for the TREE page — headless
## capture reads back blank in this environment (index_substrate_test.gd's
## own note), so this exists purely to look at what `_draw_tree()` actually
## produces: do the 22 paths land on the 11 nodes without a stray line
## crossing where Da'ath's ring sits, do the labels clear the nodes, does
## the lit/dark split actually read at a glance.

const WORLD_INDEX := preload("res://systems/world_index.gd")


func _ready() -> void:
	get_viewport().size = Vector2i(1400, 900)
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "relations": {
		"choir_of_marrow": {"kind": "command", "strength": 55},
		"black_mile": {"kind": "command", "strength": 30},
	}})
	var index: Control = WORLD_INDEX.new()
	index.size = Vector2(1400, 900)
	add_child(index)
	await get_tree().process_frame
	index.open()
	index._go_to_page(4, 1.0)
	index.page_blend = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var image := get_viewport().get_texture().get_image()
	image.save_png("P:/GameDev/Temp/sephiroth_tree.png")
	print("CAPTURE_DONE")
