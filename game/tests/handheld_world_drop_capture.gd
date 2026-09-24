extends Node

## C1.7 visual evidence: produced by calling the real drop transition in the
## Hunt, then letting its world body occupy the camera's near ground plane.

const HUNT := preload("res://bone_yard_hunt.tscn")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldClock.set_hour(6.5)
	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().process_frame
	hunt.set_process(false)

	hunt.handheld.battery = 0.72
	hunt.handheld.condition = 0.64
	hunt.handheld.save_device()
	hunt.handheld.drop()
	await get_tree().physics_frame
	var forward: Vector3 = -hunt.camera.global_transform.basis.z.normalized()
	hunt.dropped_handheld.freeze = true
	hunt.dropped_handheld.global_position = hunt.camera.global_position + forward * 0.9 + Vector3.DOWN * 0.28
	hunt.dropped_handheld.rotation_degrees = Vector3(72.0, 10.0, -12.0)
	hunt._persist_dropped_handheld()
	for _frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures/c1_7_dropped_black_mirror.png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path if result == OK else "FAILED")
	get_tree().quit(0 if result == OK else 1)
