extends Node

## I4.3v2/I10.9 visual proof in the live Hunt scene: distinct wounds mark the
## portrait, anatomy, held-object reliquary and satellite map locally.

const HUNT := preload("res://bone_yard_hunt.tscn")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.world_minute = 13.0 * WorldClock.MINUTES_PER_HOUR
	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt.set_physics_process(false)
	var zones: Dictionary = hunt.player_rig.anatomy.zones
	zones.head.health *= 0.45
	zones.torso.health *= 0.52
	zones.left_arm.health *= 0.35
	zones.left_leg.health *= 0.30
	hunt.field_interface.lung_linger = 3.0
	hunt._update_hud()
	hunt.prompt.text = "WOUNDS MISREGISTER THE INSTRUMENTS THEY FEED"
	for _frame in 20:
		WorldHistory.world_minute = 13.0 * WorldClock.MINUTES_PER_HOUR
		hunt.field_interface._process(0.05)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures/i4_3_region_wound_ui.png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
	get_tree().quit(0 if error == OK else 1)

