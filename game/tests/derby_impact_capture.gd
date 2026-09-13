extends Node

## G0 visual proof: hold the player's car parked until an AI impact damages it,
## then photograph the actual derby scene rather than staging a collision.

func _ready() -> void:
	var out_path := "P:/GameDev/Temp/g0_derby_impact.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var derby = load("res://rift_derby.tscn").instantiate()
	add_child(derby)
	await get_tree().physics_frame
	derby.leaving = true
	derby.round_state = "active"
	for _frame in 1800:
		await get_tree().physics_frame
		if derby.boat.integrity < 100:
			for _hold in 12:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var error := image.save_png(out_path)
			print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", out_path, " hull=", derby.boat.integrity)
			get_tree().quit(0 if error == OK else 1)
			return
	print("CAPTURE_FAILED: no player damage inside thirty seconds")
	get_tree().quit(1)

