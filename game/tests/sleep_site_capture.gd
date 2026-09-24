extends Node

## H10.8 visual proof: the bedroll as encountered in the live Hunt scene.

const HUNT := preload("res://bone_yard_hunt.tscn")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.world_minute = 19.25 * WorldClock.MINUTES_PER_HOUR
	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt.set_physics_process(false)
	hunt.player = hunt.sleep_site.global_position + Vector3(0, 1.3, 2.8)
	hunt.player_body.global_position = hunt.player - Vector3.UP * 0.6
	hunt.camera.global_position = hunt.player + Vector3.UP * 0.35
	hunt.camera.look_at(hunt.sleep_site.global_position + Vector3.UP * 0.12)
	hunt.prompt.text = "[E] REST AT THE BEDROLL // WAKE AT 07:00"
	for _frame in 16:
		WorldHistory.world_minute = 19.25 * WorldClock.MINUTES_PER_HOUR
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures/h10_8_sleep_site.png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
	get_tree().quit(0 if error == OK else 1)
