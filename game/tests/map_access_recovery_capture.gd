extends Node

const FACILITY := preload("res://systems/facility_territory.gd")

var hunt: Node


func _wait(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(5)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures/%s" % name)
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED ", path)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	FACILITY.apply_event("opening_woke")
	FACILITY.apply_event("opening_entered_pit")
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await _wait(45)
	hunt._toggle_panel("map")
	await _wait(12)
	await _shot("map_underground_facility_layer.png")
	var layer := InputEventKey.new()
	layer.keycode = KEY_L
	layer.pressed = true
	hunt._unhandled_input(layer)
	await _wait(12)
	await _shot("map_surface_satellite_layer.png")
	get_tree().quit()
