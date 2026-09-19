extends Node

var out_path := "P:/GameDev/Temp/lane4_captivity_procedure.png"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var filed_state: Dictionary = vat.intake.sheet.apply_to_world()
	vat.intake.filed.emit(filed_state)
	await get_tree().process_frame
	vat.queue_free()
	await get_tree().process_frame

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Look down far enough to keep the player's X-rayed body in the frame. The
	# reveal itself is still driven through the production hold path.
	hunt.pitch = -0.72
	hunt._update_camera()
	hunt._update_xray(0.2, true)
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", out_path)
	get_tree().quit(0 if error == OK else 1)
