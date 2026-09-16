extends Node

## C10.8 visual evidence generated through the same `_wound_player` entry the
## live encounter uses, rather than authoring a crack directly for a picture.

const HUNT := preload("res://bone_yard_hunt.tscn")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldClock.set_hour(20.5)
	var hunt = HUNT.instantiate()
	add_child(hunt)
	hunt.set_process(false)
	await get_tree().process_frame

	hunt.handheld.condition = 1.0
	hunt.handheld.impacts.clear()
	hunt.handheld.wear_log.clear()
	hunt.handheld.possessed = true
	hunt.handheld.open_device()
	hunt.handheld.set_mode("INDEX")
	hunt.handheld.raised = 1.0
	hunt.handheld.save_device()

	# A live blunt strike arriving from the visible upper-right of the player's
	# view. The crack origin is projected from this world point by the Hunt.
	var strike_from: Vector3 = hunt.player + Vector3(4.0, 2.0, -5.0)
	hunt._wound_player(strike_from, 28.0, "blunt")
	for _frame in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures/c10_8_live_device_wear.png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path if result == OK else "FAILED")
	get_tree().quit(0 if result == OK else 1)
