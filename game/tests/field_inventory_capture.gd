extends Node

var out_path := "P:/GameDev/Temp/field-inventory.png"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt.set_physics_process(false)
	hunt.handheld.carry.take_chunk({"layer_name": "organ", "organ_id": "lung", "zone": "torso", "subject_id": "pike_murrain", "condition": 0.72})
	hunt.handheld.carry.take_chunk({"layer_name": "cybernetic", "implant": "rangefinder eye", "zone": "head", "subject_id": "pike_murrain"})
	hunt.handheld.carry.take_chunk({"layer_name": "limb", "whole_limb": true, "zone": "left_arm", "subject_id": "ash_rafter", "condition": 0.48})
	hunt.handheld.carry.take_chunk({"layer_name": "skin", "zone": "torso", "subject_id": "unknown"})
	hunt.field_inventory.selected = 2
	hunt._toggle_inventory()
	for _frame in 18:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out_path)
	print("CAPTURED " if result == OK else "CAPTURE_FAILED ", out_path)
	get_tree().quit(0 if result == OK else 1)
