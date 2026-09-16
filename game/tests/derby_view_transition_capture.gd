extends Node

## M2.7 visual proof: one live derby instance at the seat, in the physical
## crossing between shells, and at the chase destination.

const DERBY := preload("res://rift_derby.tscn")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var derby = DERBY.instantiate()
	add_child(derby)
	await get_tree().physics_frame
	derby.set_physics_process(false)
	derby.leaving = true
	derby.round_state = "active"
	derby._update_camera(1.0)
	await _settle_and_capture("res://captures/m2_7_view_cab.png")

	WorldHistory.update_subject(derby.CAST.id_for(derby.CAPTAIN_SLOT), {"grudge": 40}, "capture_unlock")
	derby._toggle_derby_view()
	derby._update_camera(derby.VIEW_TRANSITION_SECONDS * 0.5)
	await _settle_and_capture("res://captures/m2_7_view_midway.png")

	derby._update_camera(derby.VIEW_TRANSITION_SECONDS)
	await _settle_and_capture("res://captures/m2_7_view_chase.png")
	get_tree().quit()


func _settle_and_capture(path: String) -> void:
	for _frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	var error := get_viewport().get_texture().get_image().save_png(absolute)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", absolute)

